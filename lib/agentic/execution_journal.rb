# frozen_string_literal: true

require "json"
require "fileutils"

module Agentic
  # Durable, append-only journal of plan execution.
  #
  # Wires into PlanOrchestrator's lifecycle hooks and writes one JSON line
  # per event - locked, flushed, and fsynced - so a crashed or killed
  # process leaves a complete record of every task that started, finished,
  # or failed, and of what each success cost to obtain. LLM calls are the
  # expensive part of a plan; the journal is what lets you not pay for
  # them twice.
  #
  # @example Journal a plan and resume after a crash
  #   journal = Agentic::ExecutionJournal.new(path: "orders.journal.jsonl")
  #   orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: journal.lifecycle_hooks)
  #   # ... process dies mid-plan, rerun:
  #   state = Agentic::ExecutionJournal.replay(path: "orders.journal.jsonl")
  #   state.completed_task_ids # => tasks you already paid for
  #   state.outputs["task-1"]  # => their outputs, ready to reuse
  class ExecutionJournal
    # Replayed journal state: everything a resuming process needs to know
    ReplayedState = Struct.new(
      :plan_id, :status, :completed_task_ids, :failed_task_ids, :outputs, :failures, :events, :descriptions, :durations, :duration_samples,
      keyword_init: true
    ) do
      # Task durations keyed by description - the natural baseline source
      # for performance regression tooling
      # @return [Hash{String=>Float}] Description => seconds (latest wins)
      def durations_by_description
        durations
      end

      # A percentile over a task's recorded durations, for baselines that
      # resist single-run noise (a journal may hold many runs)
      # @param description [String] The task's description
      # @param percentile [Numeric] 0-100
      # @param last [Integer, nil] Consider only the most recent N samples
      # @return [Float, nil] The percentile duration, or nil if unrecorded
      def duration_percentile(description, percentile, last: nil)
        samples = duration_samples[description]
        return nil if samples.nil? || samples.empty?

        samples = samples.last(last) if last
        sorted = samples.sort
        rank = (percentile / 100.0) * (sorted.size - 1)
        lower = sorted[rank.floor]
        upper = sorted[rank.ceil]
        lower + (upper - lower) * (rank - rank.floor)
      end

      # @param key [String] A task id or a task description (descriptions
      #   act as idempotency keys across runs, since ids are per-run)
      # @return [Boolean] True if the journal records a success for the task
      def completed?(key)
        completed_task_ids.include?(key) || completed_descriptions.include?(key)
      end

      # Descriptions of every task the journal proves completed - the
      # resume set for a rerun, where task ids are freshly generated
      # @return [Array<String>]
      def completed_descriptions
        completed_task_ids.filter_map { |task_id| descriptions[task_id] }
      end
    end

    # @return [String] Absolute path of the journal file
    attr_reader :path

    # @param path [String] Where to write the journal (created on first event)
    def initialize(path:)
      @path = File.expand_path(path)
      @mutex = Mutex.new
      FileUtils.mkdir_p(File.dirname(@path))
    end

    # Lifecycle hooks for PlanOrchestrator, optionally chaining existing hooks
    # @param hooks [Hash] Hooks to invoke after journaling (e.g. a CLI observer's)
    # @return [Hash] Hooks that journal each event, then delegate
    def lifecycle_hooks(hooks = {})
      {
        before_task_execution: chain(hooks[:before_task_execution]) do |task_id:, task:|
          record(:task_started, task_id: task_id, description: task.description)
        end,
        after_task_success: chain(hooks[:after_task_success]) do |task_id:, task:, result:, duration:|
          record(:task_succeeded, task_id: task_id, description: task.description, duration: duration, output: result.output)
        end,
        after_task_failure: chain(hooks[:after_task_failure]) do |task_id:, task:, failure:, duration:|
          record(:task_failed, task_id: task_id, description: task.description, duration: duration,
            error: failure.message, error_type: failure.type,
            retryable: failure.respond_to?(:retryable?) ? failure.retryable? : nil)
        end,
        plan_completed: chain(hooks[:plan_completed]) do |plan_id:, status:, execution_time:, tasks:, results:|
          record(:plan_completed, plan_id: plan_id, status: status, execution_time: execution_time)
        end
      }
    end

    # Appends an event to the journal - locked, flushed, and fsynced
    # @param event [Symbol, String] The event name
    # @param payload [Hash] Event data (must be JSON-serializable)
    # @return [void]
    def record(event, payload = {})
      line = JSON.generate({event: event, at: Time.now.utc.iso8601(3)}.merge(payload))

      @mutex.synchronize do
        File.open(@path, "a") do |file|
          file.flock(File::LOCK_EX)
          file.puts(line)
          file.flush
          file.fsync
        end
      end
    end

    # Replays a journal file into resumable state
    # @param path [String] The journal file to replay
    # @return [ReplayedState] What completed, what failed, and what it produced
    def self.replay(path:)
      state = ReplayedState.new(
        plan_id: nil,
        status: nil,
        completed_task_ids: [],
        failed_task_ids: [],
        outputs: {},
        failures: {},
        events: [],
        descriptions: {},
        durations: {},
        duration_samples: Hash.new { |h, k| h[k] = [] }
      )

      return state unless File.exist?(path)

      File.foreach(path) do |line|
        line = line.strip
        next if line.empty?

        entry = JSON.parse(line, symbolize_names: true)
        state.events << entry
        if entry[:task_id] && entry[:description]
          state.descriptions[entry[:task_id]] = entry[:description]
        end

        case entry[:event]
        when "task_succeeded"
          task_id = entry[:task_id]
          state.completed_task_ids << task_id unless state.completed_task_ids.include?(task_id)
          state.failed_task_ids.delete(task_id)
          state.failures.delete(task_id)
          state.outputs[task_id] = entry[:output]
          if entry[:description] && entry[:duration]
            state.durations[entry[:description]] = entry[:duration]
            state.duration_samples[entry[:description]] << entry[:duration]
          end
        when "task_failed"
          task_id = entry[:task_id]
          unless state.completed_task_ids.include?(task_id)
            state.failed_task_ids << task_id unless state.failed_task_ids.include?(task_id)
            state.failures[task_id] = {message: entry[:error], type: entry[:error_type], retryable: entry[:retryable]}
          end
        when "plan_completed"
          state.plan_id = entry[:plan_id]
          state.status = entry[:status]&.to_sym
        end
      end

      state
    end

    private

    # Wraps a journaling block so an existing hook still runs afterwards
    def chain(existing, &journal_block)
      return journal_block unless existing

      ->(**kwargs) {
        journal_block.call(**kwargs)
        existing.call(**kwargs)
      }
    end
  end
end
