# frozen_string_literal: true

require "json"

module Agentic
  class CLI < Thor
    # Manages line-by-line progress updates without flushing stdout
    # Each async process notifies start/end with clear visual indicators
    class ProgressTracker
      attr_reader :sections, :active_processes

      def initialize(options = {})
        @options = options
        @quiet = options[:quiet] || false
        @no_color = options[:no_color] || false

        # Core tracking state
        @sections = {}  # section_id => section_data
        @active_processes = {}  # process_id => process_data
        @completed_processes = {}  # process_id => process_data
        @section_order = []  # maintains display order
        @process_order = {}  # section_id => [process_ids]

        # Display state - buffer output until section completes
        @section_displayed = {}  # section_id => boolean
        @last_update = Time.now

        # Visual indicators
        @start_symbol = "▶"
        @success_symbol = "✓"
        @failure_symbol = "✗"
        @pending_symbol = "⋯"
      end

      # Creates a new section (panel) for grouping related actions
      # @param section_id [String] Unique identifier for the section
      # @param title [String] Display title for the section
      # @param description [String, nil] Optional description
      def create_section(section_id, title, description = nil)
        return if @quiet

        # Only create if it doesn't already exist
        unless @sections.key?(section_id)
          @sections[section_id] = {
            title: title,
            description: description,
            status: :active,
            created_at: Time.now,
            process_count: 0,
            completed_count: 0,
            failed_count: 0
          }

          @section_order << section_id
          @process_order[section_id] = []
          @section_displayed[section_id] = false
        end

        # Don't display header immediately - wait until section completes
      end

      # Starts tracking a new process within a section
      # @param section_id [String] The section this process belongs to
      # @param process_id [String] Unique identifier for the process
      # @param description [String] What this process is doing
      # @param metadata [Hash] Optional metadata for the process
      def start_process(section_id, process_id, description, metadata = {})
        return if @quiet

        # Ensure section exists
        create_section(section_id, format_section_title(section_id)) unless @sections.key?(section_id)

        @active_processes[process_id] = {
          section_id: section_id,
          description: description,
          metadata: metadata,
          status: :running,
          started_at: Time.now,
          updated_at: Time.now
        }

        @sections[section_id][:process_count] += 1
        @process_order[section_id] << process_id unless @process_order[section_id].include?(process_id)

        # Don't display process start immediately - wait until section completes
      end

      # Marks a process as completed successfully
      # @param process_id [String] The process identifier
      # @param result [String, nil] Optional success message or result
      # @param duration [Float, nil] Optional duration in seconds
      def complete_process(process_id, result = nil, duration = nil)
        return if @quiet
        return unless @active_processes.key?(process_id)

        process = @active_processes[process_id]
        section_id = process[:section_id]

        process.merge!({
          status: :completed,
          result: result,
          duration: duration || (Time.now - process[:started_at]),
          completed_at: Time.now
        })

        @sections[section_id][:completed_count] += 1

        # Move to completed processes
        @completed_processes[process_id] = process
        @active_processes.delete(process_id)

        check_section_completion(section_id)
      end

      # Marks a process as failed
      # @param process_id [String] The process identifier
      # @param error [String] Error message
      # @param duration [Float, nil] Optional duration in seconds
      def fail_process(process_id, error, duration = nil)
        return if @quiet
        return unless @active_processes.key?(process_id)

        process = @active_processes[process_id]
        section_id = process[:section_id]

        process.merge!({
          status: :failed,
          error: error,
          duration: duration || (Time.now - process[:started_at]),
          failed_at: Time.now
        })

        @sections[section_id][:failed_count] += 1

        # Move to completed processes
        @completed_processes[process_id] = process
        @active_processes.delete(process_id)

        check_section_completion(section_id)
      end

      # Updates the status of a running process (for intermediate steps)
      # @param process_id [String] The process identifier
      # @param status_message [String] Current status message
      def update_process(process_id, status_message)
        return if @quiet
        return unless @active_processes.key?(process_id)

        @active_processes[process_id][:current_status] = status_message
        @active_processes[process_id][:updated_at] = Time.now

        # Don't redisplay for updates - just track state
        # Only show start/completion to avoid spam
      end

      # Displays the current summary of all sections
      def display_summary
        return if @quiet || @sections.empty?

        puts "\n" + colorize_text("═" * 60, :blue)
        puts colorize_text(" EXECUTION SUMMARY", :blue)
        puts colorize_text("═" * 60, :blue)

        @section_order.each do |section_id|
          section = @sections[section_id]
          status_symbol = section_status_symbol(section)

          total = section[:process_count]
          completed = section[:completed_count]
          failed = section[:failed_count]

          # Fix the counter logic
          if failed > 0
            puts "#{status_symbol} #{section[:title]}: #{completed}/#{total} completed, #{failed} failed"
          else
            puts "#{status_symbol} #{section[:title]}: #{completed}/#{total} completed"
          end
        end

        puts colorize_text("═" * 60, :blue)
      end

      # Gets the appropriate status symbol for a section
      # @param section [Hash] Section data
      # @return [String] Colored status symbol
      def section_status_symbol(section)
        case section[:status]
        when :completed
          colorize_symbol(@success_symbol, :green)
        when :partial_failure
          colorize_symbol(@failure_symbol, :yellow)
        when :failed
          colorize_symbol(@failure_symbol, :red)
        else
          colorize_symbol(@pending_symbol, :blue)
        end
      end

      private

      # Displays a complete section with all its processes after completion
      def display_complete_section(section_id)
        section = @sections[section_id]

        # Check if there are any completed processes to display
        completed_processes_in_section = @process_order[section_id].select { |pid| @completed_processes.key?(pid) }

        # Don't display empty sections
        return if completed_processes_in_section.empty?

        # Display section header
        title = colorize_text(section[:title], :cyan)

        if section[:description]
          puts "\n#{title} - #{section[:description]}"
        else
          puts "\n#{title}"
        end
        puts colorize_text("─" * [section[:title].length + (section[:description]&.length || 0) + 3, 40].min, :dark)

        # Display all processes in this section in order
        completed_processes_in_section.each do |process_id|
          display_completed_process(@completed_processes[process_id])
        end

        puts # Add spacing after section
      end

      # Displays a completed process
      def display_completed_process(process)
        case process[:status]
        when :completed
          symbol = colorize_symbol(@success_symbol, :green)
          # Smarter truncation for descriptions
          description = smart_truncate(process[:description], 60)
          # Smarter result display
          result_text = format_result_text(process[:result])
          duration = process[:duration] ? " (#{format_duration(process[:duration])})" : ""
          puts "#{symbol} #{description}#{result_text}#{duration}"

        when :failed
          symbol = colorize_symbol(@failure_symbol, :red)
          description = smart_truncate(process[:description], 60)
          error = process[:error] ? " → #{smart_truncate(process[:error], 40)}" : ""
          duration = process[:duration] ? " (#{format_duration(process[:duration])})" : ""
          puts "#{symbol} #{description}#{error}#{duration}"
        end
      end

      # Checks if a section is completed and updates its status
      def check_section_completion(section_id)
        section = @sections[section_id]
        total = section[:process_count]
        completed = section[:completed_count]
        failed = section[:failed_count]

        if completed + failed >= total && !@section_displayed[section_id]
          section[:status] = (failed > 0) ? :partial_failure : :completed
          section[:completed_at] = Time.now

          # Now display the entire section with all its processes
          display_complete_section(section_id)
          @section_displayed[section_id] = true
        end
      end

      # Smart truncation that preserves meaning
      # @param text [String] Text to truncate
      # @param max_length [Integer] Maximum length
      # @return [String] Truncated text
      def smart_truncate(text, max_length)
        return text if text.length <= max_length

        # Try to truncate at word boundaries
        truncated = text[0..max_length - 4]
        last_space = truncated.rindex(" ")

        if last_space && last_space > max_length * 0.7
          "#{text[0..last_space - 1]}..."
        else
          "#{text[0..max_length - 4]}..."
        end
      end

      # Format result text for display
      # @param result [Object] The result object
      # @return [String] Formatted result text
      def format_result_text(result)
        return "" if result.nil? || result.to_s.strip.empty?

        # If result looks like JSON, try to extract meaningful info
        if result.is_a?(String) && result.strip.start_with?("{")
          begin
            parsed = JSON.parse(result)
            if parsed.is_a?(Hash)
              # Extract first meaningful key-value pair
              meaningful_keys = parsed.keys.select { |k| !k.to_s.empty? && parsed[k] }
              if meaningful_keys.any?
                key = meaningful_keys.first
                value = parsed[key]
                if value.is_a?(Array)
                  return " → #{key.capitalize}: #{value.length} items"
                elsif value.is_a?(Hash)
                  return " → #{key.capitalize} generated"
                elsif value.is_a?(String) && value.length > 50
                  return " → #{key.capitalize} created"
                else
                  return " → #{key.capitalize}: #{value}"
                end
              end
            end
          rescue JSON::ParserError
            # Fall through to simple text handling
          end
        end

        # Simple text result
        result_text = result.to_s.strip
        if result_text.length > 40
          " → #{smart_truncate(result_text, 40)}"
        else
          " → #{result_text}"
        end
      end

      # Colorizes a symbol unless no_color is set
      def colorize_symbol(symbol, color)
        @no_color ? symbol : UI.colorize(symbol, color)
      end

      # Colorizes text unless no_color is set
      def colorize_text(text, color)
        @no_color ? text : UI.colorize(text, color)
      end

      # Formats a duration in a human-readable way
      def format_duration(seconds)
        if seconds < 1
          "#{(seconds * 1000).round}ms"
        elsif seconds < 60
          "#{seconds.round(1)}s"
        else
          "#{(seconds / 60).round(1)}m"
        end
      end

      # Formats a section title from an ID
      # @param section_id [String] The section identifier
      # @return [String] Human-readable title
      def format_section_title(section_id)
        section_id.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end
