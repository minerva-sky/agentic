# frozen_string_literal: true

module Agentic
  class CLI < Thor
    # Observer that provides real-time feedback during plan execution
    class ExecutionObserver
      # Initialize a new execution observer
      # @param options [Hash] CLI options
      def initialize(options = {})
        @options = options
        @output_format = options[:output_format] || :text
        @start_time = Time.now
        @completed_tasks = 0
        @failed_tasks = 0
        @total_tasks = 0
        @task_spinners = {}
        @agent_spinners = {}
        @cancellation_requested = false

        # Holistic task display state
        @holistic_display = options.fetch(:holistic_display, false)
        @task_states = {}
        @display_lines = 0
        @table_rendered = false

        # Summary panel state
        @summary_lines = 0
        @summary_rendered = false

        # Agent display state
        @built_agents = {}
        @progress_summary_lines = 0
        @display_mutex = Mutex.new
      end

      # Builds lifecycle hooks for the plan orchestrator
      # @return [Hash] The lifecycle hooks
      def lifecycle_hooks
        {
          before_agent_build: method(:before_agent_build),
          after_agent_build: method(:after_agent_build),
          before_task_execution: method(:before_task_execution),
          after_task_success: method(:after_task_success),
          after_task_failure: method(:after_task_failure),
          plan_completed: method(:plan_completed)
        }
      end

      # Called before an agent is built for a task
      # @param task_id [String] The ID of the task
      # @param task [Task] The task needing an agent
      def before_agent_build(task_id:, task:)
        return if @options[:quiet]
        return if @cancellation_requested # Don't start new agents if cancellation requested

        if @holistic_display
          # Initialize task state for holistic display
          @task_states[task_id] = {
            status: :building_agent,
            description: task.description,
            start_time: Time.now,
            task: task
          }
          update_holistic_display
        else
          # Create a spinner for agent building (fallback)
          spinner = TTY::Spinner.new(
            "[:spinner] #{UI.colorize("🤖", :blue)} Building agent...",
            format: :dots
          )

          @agent_spinners[task_id] = spinner
          spinner.auto_spin
        end
      end

      # Called after an agent is built for a task
      # @param task_id [String] The ID of the task
      # @param task [Task] The task that got an agent
      # @param agent [Agent] The built agent
      # @param build_duration [Float] The time taken to build the agent
      def after_agent_build(task_id:, task:, agent:, build_duration:)
        return if @options[:quiet]

        if @holistic_display
          # Track built agents
          @built_agents[task_id] = {
            role: agent.role,
            build_duration: build_duration,
            task_description: task.description
          }

          # Update task state for holistic display
          @task_states[task_id]&.merge!({
            status: @cancellation_requested ? :canceled : :agent_ready,
            agent_duration: build_duration,
            agent_role: agent.role
          })
          update_holistic_display
        elsif @agent_spinners[task_id]
          # Handle agent spinner (fallback)
          if @cancellation_requested
            @agent_spinners[task_id].error("#{UI.colorize("⚠", :yellow)} Agent building cancelled")
          else
            @agent_spinners[task_id].success(
              "#{UI.colorize("✓", :green)} Agent built: #{agent.role} (#{UI.format_duration(build_duration)})"
            )
          end
          @agent_spinners.delete(task_id)
        end
      end

      # Called before a task is executed
      # @param task_id [String] The ID of the task
      # @param task [Task] The task to execute
      def before_task_execution(task_id:, task:)
        return if @options[:quiet]
        return if @cancellation_requested # Don't start new tasks if cancellation requested

        @total_tasks += 1 unless @task_spinners.key?(task_id) || @task_states.key?(task_id)

        if @holistic_display
          # Update task state for holistic display
          if @task_states[task_id]
            # Preserve existing data (like agent info) and update status
            @task_states[task_id].merge!({
              status: :in_progress,
              execution_start_time: Time.now
            })
          else
            # Create new state if it doesn't exist
            @task_states[task_id] = {
              status: :in_progress,
              description: task.description,
              start_time: Time.now,
              task: task
            }
          end
          update_holistic_display
        else
          # Fallback to original spinner behavior
          create_task_spinner(task_id, task)
        end
      end

      # Called after a task is successfully executed
      # @param task_id [String] The ID of the task
      # @param task [Task] The task that was executed
      # @param result [TaskResult] The result of the task
      # @param duration [Float] The duration of the task execution
      def after_task_success(task_id:, task:, result:, duration:)
        return if @options[:quiet]

        @completed_tasks += 1

        if @holistic_display
          # Update task state for holistic display
          @task_states[task_id]&.merge!({
            status: @cancellation_requested ? :canceled : :completed,
            duration: duration,
            output: result.output
          })
          update_holistic_display
        else
          # Fallback to original spinner behavior
          handle_task_spinner_success(task_id, result, duration)
          display_progress
        end
      end

      # Called after a task fails
      # @param task_id [String] The ID of the task
      # @param task [Task] The task that failed
      # @param failure [TaskFailure] The failure details
      # @param duration [Float] The duration of the task execution
      def after_task_failure(task_id:, task:, failure:, duration:)
        return if @options[:quiet]

        @failed_tasks += 1

        if @holistic_display
          # Update task state for holistic display
          @task_states[task_id]&.merge!({
            status: @cancellation_requested ? :canceled : :failed,
            duration: duration,
            error: failure.message
          })
          update_holistic_display
        else
          # Fallback to original spinner behavior
          handle_task_spinner_failure(task_id, failure, duration)
          display_progress
        end
      end

      # Called when the plan execution is completed
      # @param plan_id [String] The ID of the plan
      # @param status [Symbol] The status of the plan execution
      # @param execution_time [Float] The execution time in seconds
      # @param tasks [Hash] The tasks that were executed
      # @param results [Hash] The results of the task executions
      def plan_completed(plan_id:, status:, execution_time:, tasks:, results:)
        return if @options[:quiet]

        # Always save to file now - determine the output path
        save_path = determine_save_path(@options[:file])
        absolute_path = File.expand_path(save_path)

        # Show initial summary panel with progress
        show_initial_summary(status, execution_time, absolute_path)

        # Generate and display final preview with callback support
        preview = generate_output_preview(results, tasks, status, execution_time, absolute_path)
        show_final_summary(status, execution_time, absolute_path, preview)
      end

      # Generates file content for saving based on the specified format
      # @param result [PlanExecutionResult] The plan execution result
      # @param format [Symbol] The target format
      # @return [String] The formatted content
      def generate_file_content(result, format)
        if format == :json
          JSON.pretty_generate(result.to_h)
        else
          # Use LLM to generate format-specific content
          generate_formatted_output(
            result.results.values.select(&:successful?),
            result.tasks,
            format
          )
        end
      end

      # Shows the initial summary panel with progress information
      # @param status [Symbol] The execution status
      # @param execution_time [Float] The execution time in seconds
      # @param absolute_path [String] The output file path
      def show_initial_summary(status, execution_time, absolute_path)
        total_time = UI.format_duration(execution_time)

        result_color = case status
        when :completed
          :green
        when :partial_failure
          :yellow
        else
          :red
        end

        # Build initial summary content
        summary_content = [
          "Status: #{UI.status_text(status, status)}",
          "Tasks: #{@total_tasks} total, " \
          "#{UI.colorize(@completed_tasks.to_s, :green)} completed, " \
          "#{UI.colorize(@failed_tasks.to_s, :red)} failed",
          "Time: #{total_time}",
          "",
          "Output: #{UI.colorize(absolute_path, :blue)}",
          "",
          "Generating output preview..."
        ]

        summary = UI.box(
          "Execution Summary",
          summary_content.join("\n"),
          style: {border: {fg: result_color}}
        )

        puts "\n#{summary}" if !summary.empty?

        # Track summary state
        @summary_lines = summary.lines.count + 1 # +1 for the newline before
        @summary_rendered = true
      end

      # Shows the final summary panel with complete preview
      # @param status [Symbol] The execution status
      # @param execution_time [Float] The execution time in seconds
      # @param absolute_path [String] The output file path
      # @param preview [String] The generated preview content
      def show_final_summary(status, execution_time, absolute_path, preview)
        total_time = UI.format_duration(execution_time)

        result_color = case status
        when :completed
          :green
        when :partial_failure
          :yellow
        else
          :red
        end

        # Build final summary content
        summary_content = [
          "Status: #{UI.status_text(status, status)}",
          "Tasks: #{@total_tasks} total, " \
          "#{UI.colorize(@completed_tasks.to_s, :green)} completed, " \
          "#{UI.colorize(@failed_tasks.to_s, :red)} failed",
          "Time: #{total_time}",
          "",
          "Output: #{UI.colorize(absolute_path, :blue)}",
          "",
          "Preview:",
          preview
        ]

        summary = UI.box(
          "Execution Summary",
          summary_content.join("\n"),
          style: {border: {fg: result_color}}
        )

        # Clear previous summary if it was rendered
        if @summary_rendered && @summary_lines > 0
          UI.clear_and_reposition(@summary_lines)
        end

        puts "\n#{summary}" if !summary.empty?
      end

      # Updates the summary panel with a specific message
      # @param status [Symbol] The execution status
      # @param execution_time [Float] The execution time in seconds
      # @param absolute_path [String] The output file path
      # @param message [String] The message to display
      def update_summary_with_message(status, execution_time, absolute_path, message)
        total_time = UI.format_duration(execution_time)

        result_color = case status
        when :completed
          :green
        when :partial_failure
          :yellow
        else
          :red
        end

        # Build summary content with the custom message
        summary_content = [
          "Status: #{UI.status_text(status, status)}",
          "Tasks: #{@total_tasks} total, " \
          "#{UI.colorize(@completed_tasks.to_s, :green)} completed, " \
          "#{UI.colorize(@failed_tasks.to_s, :red)} failed",
          "Time: #{total_time}",
          "",
          "Output: #{UI.colorize(absolute_path, :blue)}",
          "",
          message
        ]

        summary = UI.box(
          "Execution Summary",
          summary_content.join("\n"),
          style: {border: {fg: result_color}}
        )

        # Clear previous summary if it was rendered
        if @summary_rendered && @summary_lines > 0
          UI.clear_and_reposition(@summary_lines)
        end

        puts "\n#{summary}" if !summary.empty

        # Update tracking
        @summary_lines = summary.lines.count + 1 # +1 for the newline before
        @summary_rendered = true
      end

      # Handles cancellation by setting a flag (safe to call from signal context)
      def handle_cancellation
        @cancellation_requested = true
      end

      private

      # Determines the save path for output file
      # @param file_option [String] The file option from CLI
      # @return [String] The resolved file path
      def determine_save_path(file_option)
        if file_option
          # User specified a file path
          file_option
        else
          # Default filename with timestamp
          timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
          "result-#{timestamp}.json"
        end
      end

      # Generates a preview of the output (first 2-3 lines)
      # @param results [Hash] The task results
      # @param tasks [Hash] The task data
      # @param status [Symbol] The execution status for summary panel updates
      # @param execution_time [Float] The execution time for summary panel updates
      # @param absolute_path [String] The output file path for summary panel updates
      # @return [String] Preview text
      def generate_output_preview(results, tasks, status = nil, execution_time = nil, absolute_path = nil)
        # Create callback to update summary panel if we have the required parameters
        update_callback = if status && execution_time && absolute_path
          proc { |message| update_summary_with_message(status, execution_time, absolute_path, message) }
        end

        consolidated = format_consolidated_output(results, tasks, update_callback)

        # Split into lines and take first 3 lines
        lines = consolidated.lines
        preview_lines = lines.first(3)

        # Add ellipsis if there are more lines
        if lines.length > 3
          preview_lines << "..."
        end

        # Join and ensure proper indentation for the box
        preview_lines.map { |line| "  #{line.chomp}" }.join("\n")
      end

      # Updates the holistic task display table
      def update_holistic_display
        return if @options[:quiet] || @task_states.empty?

        # Use mutex to prevent concurrent display updates
        @display_mutex.synchronize do
          update_display_synchronized
        end
      end

      # Synchronized display update using standard table rendering
      def update_display_synchronized
        # Clear previous display if it was rendered
        if @table_rendered && @display_lines > 0
          UI.clear_and_reposition(@display_lines)
        end

        # Format task data for display
        tasks_for_display = @task_states.map do |task_id, task_data|
          # Get agent info if available
          agent_info = @built_agents[task_id]

          # Merge task data with agent info for display
          display_task = task_data.dup
          if agent_info
            display_task[:agent_role] = agent_info[:role]
            display_task[:agent_duration] = agent_info[:build_duration]
          end

          display_task
        end

        # Create table display
        table_output = UI.task_display_table(tasks_for_display, show_agent_column: true)
        puts table_output if !table_output.empty?

        # Display progress summary
        display_progress_summary

        # Track display state
        @display_lines = table_output.lines.count + @progress_summary_lines
        @table_rendered = true
      end

      # Displays progress summary below the table
      def display_progress_summary
        if @total_tasks > 0
          total = @completed_tasks + @failed_tasks
          if total > 0
            elapsed = Time.now - @start_time
            progress = (total / @total_tasks.to_f * 100).round
            summary = "Progress: #{progress}% (#{total}/#{@total_tasks}) - " \
                     "Elapsed: #{UI.format_duration(elapsed)}"

            puts UI.colorize(summary, :blue) if !summary.empty?
            @progress_summary_lines = 1
          else
            @progress_summary_lines = 0
          end
        else
          @progress_summary_lines = 0
        end
      end

      # Displays a summary box of built agents
      # @return [String] The formatted agent summary box
      def display_agent_summary_box
        return "" if @built_agents.empty?

        # Create agent summary content
        agent_lines = @built_agents.map do |task_id, agent_info|
          duration_text = UI.format_duration(agent_info[:build_duration])
          "#{UI.colorize("🤖", :blue)} #{agent_info[:role]} (#{duration_text}) → #{agent_info[:task_description]}"
        end

        # Add header
        summary_content = [
          UI.colorize("Agents Built:", :green),
          "",
          *agent_lines
        ]

        UI.box(
          "Agent Summary",
          summary_content.join("\n"),
          style: {border: {fg: :blue}}
        )
      end

      # Creates a task spinner (fallback for non-holistic display)
      def create_task_spinner(task_id, task)
        # Truncate very long descriptions to prevent UI issues
        max_length = 80
        display_description = if task.description.length > max_length
          "#{task.description[0..max_length - 4]}..."
        else
          task.description
        end

        # Create a spinner for the task execution
        spinner = TTY::Spinner.new(
          "[:spinner] #{UI.colorize("▶", :blue)} #{display_description}",
          format: :dots
        )

        @task_spinners[task_id] = {
          spinner: spinner,
          task: task,
          start_time: Time.now
        }

        spinner.auto_spin
      end

      # Handles task spinner success (fallback for non-holistic display)
      def handle_task_spinner_success(task_id, result, duration)
        if @task_spinners[task_id]
          spinner = @task_spinners[task_id][:spinner]

          if @cancellation_requested
            spinner.error("#{UI.colorize("⚠", :yellow)} Cancelled")
          else
            # Display task output if available and not too long
            output_preview = ""
            if result.output && !result.output.to_s.empty?
              output_text = result.output.to_s.strip
              output_preview = if output_text.length > 100
                " → #{output_text[0..97]}..."
              else
                " → #{output_text}"
              end
            end

            task_info = @task_spinners[task_id][:task]
            task_description = task_info&.description || "Task"

            spinner.success(
              "#{UI.colorize("✓", :green)} #{task_description} completed#{output_preview} " \
              "(#{UI.format_duration(duration)})"
            )
          end
        end
      end

      # Handles task spinner failure (fallback for non-holistic display)
      def handle_task_spinner_failure(task_id, failure, duration)
        if @task_spinners[task_id]
          spinner = @task_spinners[task_id][:spinner]
          if @cancellation_requested
            spinner.error("#{UI.colorize("⚠", :yellow)} Cancelled")
          else
            task_info = @task_spinners[task_id][:task]
            task_description = task_info&.description || "Task"

            spinner.error(
              "#{UI.colorize("✗", :red)} #{task_description} failed - " \
              "#{failure.message} (#{UI.format_duration(duration)})"
            )
          end
        end
      end

      # Displays progress information
      def display_progress
        return if @options[:quiet]

        total = @completed_tasks + @failed_tasks
        elapsed = Time.now - @start_time

        if @total_tasks > 0
          progress = (total / @total_tasks.to_f * 100).round
          if total > 0 && total < @total_tasks
            # Use carriage return to overwrite the previous progress line
            print "\r#{UI.colorize(
              "Progress: #{progress}% (#{total}/#{@total_tasks}) - " \
              "Elapsed: #{UI.format_duration(elapsed)}",
              :blue
            )}"
            $stdout.flush
          elsif total > 0
            # All tasks accounted for - terminate the carriage-return progress line
            puts
          end
        end
      end

      # Formats consolidated output from all task results
      # @param results [Hash] Hash of task_id => TaskExecutionResult
      # @param tasks [Hash] Hash of task_id => Task data
      # @param update_callback [Proc, nil] Optional callback to update summary panel
      # @return [String] Formatted output
      def format_consolidated_output(results, tasks, update_callback = nil)
        # Convert hash values to array and filter successful results
        result_objects = results.values
        successful_results = result_objects.select(&:successful?)

        if successful_results.empty?
          UI.colorize("No successful task outputs", :yellow)
        elsif @output_format == :text
          # Simple text format (existing behavior)
          outputs = successful_results.map.with_index do |result, index|
            output = result.output.to_s.strip
            if output.empty?
              "#{index + 1}. (no output)"
            else
              "#{index + 1}. #{output}"
            end
          end
          outputs.join("\n")
        else
          # Use LLM to generate format-specific output
          generate_formatted_output(successful_results, tasks, @output_format, update_callback)
        end
      end

      # Generates format-specific output using LLM
      # @param successful_results [Array<TaskExecutionResult>] The successful task results
      # @param tasks [Hash] Hash of task_id => Task data
      # @param format [Symbol] The target format (:markdown, :html, :json, :yaml)
      # @param update_summary_callback [Proc, nil] Optional callback to update summary panel
      # @return [String] Formatted output
      def generate_formatted_output(successful_results, tasks, format, update_summary_callback = nil)
        return simple_format_fallback(successful_results) if successful_results.empty?

        # Prepare task data for LLM
        task_summaries = successful_results.map.with_index do |result, index|
          task_id = result.respond_to?(:task_id) ? result.task_id : "task_#{index + 1}"
          task_info = tasks[task_id] || {}

          {
            index: index + 1,
            description: task_info[:description] || "Task #{index + 1}",
            output: result.output.to_s.strip
          }
        end

        # Generate format-specific prompt
        prompt = build_formatting_prompt(task_summaries, format)
        format_name = format.to_s.capitalize

        # Use LLM to generate formatted output
        begin
          llm_config = Agentic::LlmConfig.new
          llm_client = Agentic::LlmClient.new(llm_config)

          # Update summary panel to show generation in progress
          update_summary_callback&.call("Generating #{format_name} summary...")

          response = llm_client.complete([
            {role: "user", content: prompt}
          ])

          if response.successful?
            response.content
          else
            simple_format_fallback(successful_results)
          end
        rescue => e
          Agentic.logger.warn("Failed to generate formatted output: #{e.message}")
          simple_format_fallback(successful_results)
        end
      end

      # Builds a prompt for LLM to format the output
      # @param task_summaries [Array<Hash>] Array of task summary data
      # @param format [Symbol] The target format
      # @return [String] The formatting prompt
      def build_formatting_prompt(task_summaries, format)
        case format
        when :markdown
          build_markdown_prompt(task_summaries)
        when :html
          build_html_prompt(task_summaries)
        when :json
          build_json_prompt(task_summaries)
        when :yaml
          build_yaml_prompt(task_summaries)
        else
          build_generic_prompt(task_summaries, format)
        end
      end

      # Builds markdown formatting prompt
      def build_markdown_prompt(task_summaries)
        task_data = task_summaries.map do |task|
          "#{task[:index]}. **#{task[:description]}**\n   Result: #{task[:output]}"
        end.join("\n\n")

        <<~PROMPT
          Please format the following task execution results as a clean, professional Markdown document:

          #{task_data}

          Requirements:
          - Use appropriate headings and structure
          - Make it readable and well-organized
          - Include a summary section
          - Use proper Markdown formatting
          - Keep the content concise but informative
        PROMPT
      end

      # Builds HTML formatting prompt
      def build_html_prompt(task_summaries)
        task_data = task_summaries.map do |task|
          "#{task[:index]}. #{task[:description]} → #{task[:output]}"
        end.join("\n")

        <<~PROMPT
          Please format the following task execution results as clean HTML:

          #{task_data}

          Requirements:
          - Use semantic HTML elements
          - Include basic styling for readability
          - Structure with headings and lists
          - Make it professional and clean
          - Include a summary section
        PROMPT
      end

      # Builds JSON formatting prompt
      def build_json_prompt(task_summaries)
        <<~PROMPT
          Please format the following task execution results as a well-structured JSON document:

          #{task_summaries.map { |t| "#{t[:index]}. #{t[:description]} → #{t[:output]}" }.join("\n")}

          Requirements:
          - Create a structured JSON with summary, tasks array, and metadata
          - Include task descriptions, outputs, and indices
          - Make it easy to parse programmatically
          - Add relevant metadata like timestamp, total tasks, etc.
        PROMPT
      end

      # Builds YAML formatting prompt
      def build_yaml_prompt(task_summaries)
        <<~PROMPT
          Please format the following task execution results as clean YAML:

          #{task_summaries.map { |t| "#{t[:index]}. #{t[:description]} → #{t[:output]}" }.join("\n")}

          Requirements:
          - Use proper YAML structure with summary and tasks
          - Include task descriptions and outputs
          - Make it readable and well-organized
          - Add metadata section
        PROMPT
      end

      # Builds generic formatting prompt
      def build_generic_prompt(task_summaries, format)
        task_data = task_summaries.map do |task|
          "#{task[:index]}. #{task[:description]} → #{task[:output]}"
        end.join("\n")

        <<~PROMPT
          Please format the following task execution results in #{format} format:

          #{task_data}

          Make it well-structured, professional, and appropriate for the #{format} format.
        PROMPT
      end

      # Simple fallback formatting when LLM is unavailable
      def simple_format_fallback(successful_results)
        outputs = successful_results.map.with_index do |result, index|
          output = result.output.to_s.strip
          if output.empty?
            "#{index + 1}. (no output)"
          else
            "#{index + 1}. #{output}"
          end
        end
        outputs.join("\n")
      end
    end
  end
end
