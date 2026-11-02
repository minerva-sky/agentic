# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Agentic::PlanOrchestrator, "resuming from an ExecutionJournal" do
  around do |example|
    Dir.mktmpdir("agentic-resume") do |dir|
      @path = File.join(dir, "plan.journal.jsonl")
      example.run
    end
  end

  let(:journal) { Agentic::ExecutionJournal.new(path: @path) }
  let(:runs) { Hash.new(0) }
  let(:failing) { [] }

  # A per-task worker that counts executions per description and fails a
  # description once if it's listed in `failing`
  let(:worker) do
    ->(task) {
      runs[task.description] += 1
      raise "#{task.description} blew up" if failing.delete(task.description)
      {"text" => "#{task.description} output #{runs[task.description]}"}
    }
  end

  def task(description)
    Agentic::Task.new(description: description, agent_spec: {"instructions" => "test"}, input: {})
  end

  def orchestrator(hooks = {})
    described_class.new(lifecycle_hooks: journal.lifecycle_hooks(hooks))
  end

  # A -> B -> C, with C reading B by name. Fresh Task objects (fresh ids)
  # on every call, the way a rerun in a new process would build them.
  def build_plan(orch = orchestrator)
    a, b, c = task("Task A"), task("Task B"), task("Task C")
    orch.add_task(a, agent: worker)
    orch.add_task(b, [a], agent: worker)
    orch.add_task(c, needs: {report: b}, agent: worker)
    [orch, a, b, c]
  end

  def replayed
    Agentic::ExecutionJournal.replay(path: @path)
  end

  it "re-runs only what the failed run left undone" do
    failing << "Task C"
    first, * = build_plan
    expect(first.execute_plan.status).to eq(:partial_failure)
    expect(runs).to eq("Task A" => 1, "Task B" => 1, "Task C" => 1)

    second, a, b, c = build_plan
    result = second.execute_plan(resume_from: replayed)

    expect(result.status).to eq(:completed)
    expect(runs).to eq("Task A" => 1, "Task B" => 1, "Task C" => 2)
    expect(result.task_result(a.id).status).to eq(:completed)
    expect(result.task_result(b.id).output).to eq("text" => "Task B output 1")
    expect(result.task_result(c.id).output).to eq("text" => "Task C output 2")
  end

  it "seeds restored outputs into dependents and needs: in the shape the task produced them" do
    failing << "Task C"
    build_plan.first.execute_plan

    second, _a, b, c = build_plan
    second.execute_plan(resume_from: replayed)

    expect(c.needs.report).to eq("text" => "Task B output 1")
    expect(c.previous_output).to eq("text" => "Task B output 1")
    expect(b.output).to eq("text" => "Task B output 1")
    expect(b.status).to eq(:completed)
  end

  it "resumes a run that died without a plan_completed event" do
    failing << "Task C"
    build_plan.first.execute_plan
    lines = File.readlines(@path)
    File.write(@path, lines.reject { |l| l.include?('"plan_completed"') }.join)

    second, * = build_plan
    result = second.execute_plan(resume_from: replayed)

    expect(result.status).to eq(:completed)
    expect(runs).to eq("Task A" => 1, "Task B" => 1, "Task C" => 2)
  end

  it "starts fresh when the journal's last run completed" do
    build_plan.first.execute_plan

    second, * = build_plan
    result = second.execute_plan(resume_from: replayed)

    expect(result.status).to eq(:completed)
    expect(runs).to eq("Task A" => 2, "Task B" => 2, "Task C" => 2)
  end

  it "resumes the unfinished run of a journal that also holds an earlier completed run" do
    build_plan.first.execute_plan
    failing << "Task B"
    build_plan.first.execute_plan

    third, a, * = build_plan
    result = third.execute_plan(resume_from: replayed)

    expect(result.status).to eq(:completed)
    expect(runs).to eq("Task A" => 2, "Task B" => 3, "Task C" => 2)
    expect(result.task_result(a.id).output).to eq("text" => "Task A output 2")
  end

  it "matches by id when the same Task objects are reused" do
    failing << "Task C"
    first, a, b, c = build_plan
    first.execute_plan

    second = orchestrator
    second.add_task(a, agent: worker)
    second.add_task(b, [a], agent: worker)
    second.add_task(c, needs: {report: b}, agent: worker)
    result = second.execute_plan(resume_from: replayed)

    expect(result.status).to eq(:completed)
    expect(runs).to eq("Task A" => 1, "Task B" => 1, "Task C" => 2)
  end

  it "journals only the work a resumed run actually does" do
    failing << "Task C"
    build_plan.first.execute_plan
    build_plan.first.execute_plan(resume_from: replayed)

    events = File.readlines(@path).map { |line| JSON.parse(line) }
    started = events.select { |e| e["event"] == "task_started" }.map { |e| e["description"] }
    expect(started.tally).to eq("Task A" => 1, "Task B" => 1, "Task C" => 2)
    expect(events.count { |e| e["event"] == "plan_completed" }).to eq(2)
  end

  it "does not fire task hooks for restored tasks" do
    failing << "Task C"
    build_plan.first.execute_plan

    before = []
    second, * = build_plan(orchestrator(before_task_execution: ->(task_id:, task:) { before << task.description }))
    second.execute_plan(resume_from: replayed)

    expect(before).to eq(["Task C"])
  end

  it "re-runs a task the journal records as failed, not just missing" do
    failing << "Task B"
    build_plan.first.execute_plan

    second, _a, b, _c = build_plan
    result = second.execute_plan(resume_from: replayed)

    expect(result.status).to eq(:completed)
    expect(runs["Task B"]).to eq(2)
    expect(result.task_result(b.id).output).to eq("text" => "Task B output 2")
  end

  it "re-runs tasks whose description repeats, and their dependents, rather than guess" do
    first = orchestrator
    d1, d2 = task("Dup"), task("Dup")
    first.add_task(d1, agent: worker)
    first.add_task(d2, agent: worker)
    first.add_task(task("Task B"), [d1], agent: worker)
    first.add_task(task("Task C"), agent: worker)
    failing << "Task C"
    first.execute_plan
    expect(runs).to eq("Dup" => 2, "Task B" => 1, "Task C" => 1)

    second = orchestrator
    e1, e2 = task("Dup"), task("Dup")
    second.add_task(e1, agent: worker)
    second.add_task(e2, agent: worker)
    second.add_task(task("Task B"), [e1], agent: worker)
    second.add_task(task("Task C"), agent: worker)
    result = second.execute_plan(resume_from: replayed)

    expect(result.status).to eq(:completed)
    expect(runs).to eq("Dup" => 4, "Task B" => 2, "Task C" => 2)
  end

  it "treats a description as ambiguous when the run also holds a failed task carrying it" do
    first = orchestrator
    first.add_task(task("Summarize section"), agent: worker)
    first.add_task(task("Summarize section"), agent: worker)
    failing << "Summarize section"
    expect(first.execute_plan.status).to eq(:partial_failure)

    second = orchestrator
    second.add_task(task("Summarize section"), agent: worker)
    second.execute_plan(resume_from: replayed)

    expect(runs["Summarize section"]).to eq(3)
  end

  it "needs no agent for tasks it restores" do
    failing << "Task C"
    build_plan.first.execute_plan

    second = described_class.new
    a, b = task("Task A"), task("Task B")
    second.add_task(a)
    second.add_task(b, [a])
    second.add_task(task("Task C"), [b], agent: worker)

    expect { second.execute_plan(resume_from: replayed) }.not_to raise_error
    expect(second.execution_state[:completed]).to include(a.id, b.id)
  end

  it "resumes through a torn journal in tolerant mode" do
    failing << "Task C"
    build_plan.first.execute_plan
    File.open(@path, "a") { |f| f.write('{"event":"task_succeeded","task_id":"t-torn","descr') }

    state = replayed
    expect(state).to be_damaged
    second, * = build_plan
    result = second.execute_plan(resume_from: state)

    expect(result.status).to eq(:completed)
    expect(runs).to eq("Task A" => 1, "Task B" => 1, "Task C" => 2)
  end

  describe "redoing from a task (from:)" do
    before do
      failing << "Task C"
      build_plan.first.execute_plan
    end

    # The input was fixed between runs; the journal can't tell, the caller can
    it "re-runs the named task and everything downstream despite recorded successes" do
      second, a, b, c = build_plan
      result = second.execute_plan(resume_from: replayed, from: "Task A")

      expect(result.status).to eq(:completed)
      expect(runs).to eq("Task A" => 2, "Task B" => 2, "Task C" => 2)
      expect(result.task_result(a.id).output).to eq("text" => "Task A output 2")
      expect(c.needs.report).to eq(result.task_result(b.id).output)
    end

    it "still restores what lies upstream of the named task" do
      second, _a, b, * = build_plan
      second.execute_plan(resume_from: replayed, from: b.id)

      expect(runs).to eq("Task A" => 1, "Task B" => 2, "Task C" => 2)
    end

    it "refuses a description that names no task, or several" do
      second, * = build_plan
      expect { second.execute_plan(resume_from: replayed, from: "Task Z") }
        .to raise_error(ArgumentError, /names no task/)

      third = orchestrator
      third.add_task(task("Dup"), agent: worker)
      third.add_task(task("Dup"), agent: worker)
      expect { third.execute_plan(resume_from: replayed, from: "Dup") }
        .to raise_error(ArgumentError, /matches 2 tasks/)
      expect(runs).to eq("Task A" => 1, "Task B" => 1, "Task C" => 1)
    end

    it "does not bring the invalidated outputs back if the redo dies mid-flight" do
      # The redo got as far as starting a fresh "Task A", then the process died
      File.open(@path, "a") do |f|
        f.puts(JSON.generate(event: "task_started", task_id: "t-redo", description: "Task A"))
      end

      third, * = build_plan
      third.execute_plan(resume_from: replayed)

      expect(runs).to eq("Task A" => 2, "Task B" => 2, "Task C" => 2)
    end

    it "does not restore a dependent whose success predates its redone dependency" do
      _second, a, b, c = build_plan
      # The redo of A finished and was journaled, then the process died
      File.open(@path, "a") do |f|
        f.puts(JSON.generate(event: "task_succeeded", task_id: a.id, description: "Task A", output: {"text" => "fixed"}))
      end

      third = orchestrator
      third.add_task(a, agent: worker)
      third.add_task(b, [a], agent: worker)
      third.add_task(c, needs: {report: b}, agent: worker)
      third.execute_plan(resume_from: replayed)

      expect(runs).to eq("Task A" => 1, "Task B" => 2, "Task C" => 2)
    end

    it "does not restore a reused task whose redo failed" do
      second, a, b, c = build_plan
      failing << "Task A"
      second.execute_plan(resume_from: replayed, from: a.id)

      third = orchestrator
      third.add_task(a, agent: worker)
      third.add_task(b, [a], agent: worker)
      third.add_task(c, needs: {report: b}, agent: worker)
      expect(third.execute_plan(resume_from: replayed).status).to eq(:completed)

      expect(runs).to eq("Task A" => 3, "Task B" => 2, "Task C" => 2)
    end

    it "refuses from: without resume_from:" do
      second, * = build_plan
      expect { second.execute_plan(from: "Task A") }.to raise_error(ArgumentError, /resume_from:/)
    end
  end

  describe Agentic::Task, "#restore" do
    it "marks the task completed with the output and tells observers" do
      t = task("Restored")
      seen = []
      observer = Object.new
      observer.define_singleton_method(:update) { |event, source, *args| seen << [event, source, *args] }
      t.add_observer(observer)

      t.restore({"text" => "earlier"})

      expect(t.status).to eq(:completed)
      expect(t.output).to eq("text" => "earlier")
      expect(seen).to eq([[:status_change, t, :pending, :completed]])
    end

    it "refuses while the task is executing" do
      t = task("Busy")
      t.instance_variable_set(:@status, :in_progress)

      expect { t.restore({}) }.to raise_error(ArgumentError, /in progress/)
    end
  end
end
