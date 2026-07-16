# frozen_string_literal: true

module Agentic
  class CLI < Thor
    module Streaming
      # Simple, robust streaming observer for plan command
      # Follows architectural principles with clear separation of concerns
      class StreamingPlanObserver
        attr_reader :options, :start_time

        def initialize(options = {})
          @options = options
          @start_time = Time.now
          @current_phase = nil
          @token_count = 0
          @last_update = Time.now
        end

        # Called when planning starts
        def planning_started(goal)
          return if @options[:quiet]

          puts UI.colorize("🧠 Analyzing goal: #{goal}", :blue)
          puts UI.colorize("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", :dark)
          puts
        end

        # Called when a planning phase begins
        def phase_started(phase_name, description)
          return if @options[:quiet]

          @current_phase = phase_name
          @token_count = 0

          puts UI.colorize("#{phase_icon(phase_name)} #{description}", :cyan)
          print "   "
        end

        # Called when tokens are received during streaming
        def token_received(token)
          return if @options[:quiet]

          @token_count += 1

          # Show progress indicators every 10 tokens or every second
          now = Time.now
          if @token_count % 10 == 0 || (now - @last_update) >= 1.0
            print UI.colorize(".", :green)
            $stdout.flush
            @last_update = now
          end
        end

        # Called when a phase completes
        def phase_completed(phase_name, result_summary = nil)
          return if @options[:quiet]

          puts UI.colorize(" ✓", :green)

          if result_summary && !result_summary.empty?
            puts UI.colorize("   → #{result_summary}", :dark)
          end

          puts
        end

        # Called when planning fails
        def planning_failed(error_message)
          return if @options[:quiet]

          puts UI.colorize(" ✗", :red)
          puts UI.colorize("   Error: #{error_message}", :red)
          puts
        end

        # Called when planning completes successfully
        def planning_completed(execution_plan)
          return if @options[:quiet]

          duration = Time.now - @start_time

          puts UI.colorize("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", :dark)
          puts UI.colorize("✅ Plan created successfully in #{format_duration(duration)}", :green)
          puts UI.colorize("   Tasks: #{execution_plan.tasks.length}", :blue)
          puts UI.colorize("   Format: #{execution_plan.expected_answer.format}", :blue)
          puts
        end

        # Called when cancellation is requested
        def planning_cancelled
          return if @options[:quiet]

          puts UI.colorize(" ⚠", :yellow)
          puts UI.colorize("   Planning cancelled by user", :yellow)
          puts
        end

        private

        # Returns an appropriate emoji for each phase
        def phase_icon(phase_name)
          case phase_name.to_s
          when "analyze_goal"
            "🔍"
          when "determine_format"
            "📋"
          when "generate_tasks"
            "⚙️"
          else
            "📝"
          end
        end

        # Formats duration in a human-readable way
        def format_duration(seconds)
          if seconds < 1
            "#{(seconds * 1000).round}ms"
          elsif seconds < 60
            "#{seconds.round(1)}s"
          else
            "#{(seconds / 60).round(1)}m"
          end
        end
      end
    end
  end
end
