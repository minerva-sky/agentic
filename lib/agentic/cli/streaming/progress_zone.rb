# frozen_string_literal: true

require "tty-table"
require "tty-progressbar"
require "tty-cursor"

module Agentic
  class CLI < Thor
    module Streaming
      # Handles live section progress display with real-time updates
      class ProgressZone
        attr_reader :sections, :active_sections

        def initialize(options = {})
          @options = options
          @cursor = TTY::Cursor
          @sections = {}
          @active_sections = {}
          @zone_start_line = nil
          @zone_height = 8
          @table_rendered = false
          @last_render_lines = 0
        end

        # Creates a new section for progress tracking
        # @param section_id [String] Unique identifier for the section
        # @param title [String] Display title for the section
        # @param description [String] Description of what this section does
        def create_section(section_id, title, description)
          return if @options[:quiet]

          @sections[section_id] = {
            title: title,
            description: description,
            status: :pending,
            processes: {},
            process_count: 0,
            completed_count: 0,
            failed_count: 0,
            start_time: nil,
            end_time: nil,
            progress_bar: nil
          }

          refresh_display
        end

        # Starts a process within a section
        # @param section_id [String] The section this process belongs to
        # @param process_id [String] Unique identifier for the process
        # @param description [String] What this process does
        # @param metadata [Hash] Additional process metadata
        def start_process(section_id, process_id, description, metadata = {})
          return if @options[:quiet]

          section = @sections[section_id]
          return unless section

          # Mark section as active if it's the first process
          if section[:processes].empty?
            section[:status] = :in_progress
            section[:start_time] = Time.now
            @active_sections[section_id] = section
          end

          section[:processes][process_id] = {
            description: description,
            status: :in_progress,
            start_time: Time.now,
            metadata: metadata,
            progress_message: "Starting..."
          }

          section[:process_count] += 1
          refresh_display
        end

        # Updates a process with new progress information
        # @param process_id [String] The process to update
        # @param progress_message [String] Current progress message
        def update_process(process_id, progress_message)
          return if @options[:quiet]

          # Find the process across all sections
          _section_id, process = find_process(process_id)
          return unless process

          process[:progress_message] = progress_message
          process[:last_update] = Time.now

          refresh_display
        end

        # Completes a process successfully
        # @param process_id [String] The process to complete
        # @param result_message [String] Final result message
        # @param duration [Float] Process duration in seconds
        def complete_process(process_id, result_message, duration)
          return if @options[:quiet]

          section_id, process = find_process(process_id)
          return unless process && section_id

          section = @sections[section_id]

          process[:status] = :completed
          process[:end_time] = Time.now
          process[:duration] = duration
          process[:result_message] = result_message
          process[:progress_message] = "✓ Completed"

          section[:completed_count] += 1

          # Check if section is complete
          if section[:completed_count] + section[:failed_count] >= section[:process_count]
            complete_section(section_id)
          end

          refresh_display
        end

        # Marks a process as failed
        # @param process_id [String] The process that failed
        # @param error_message [String] Error description
        # @param duration [Float] Process duration in seconds
        def fail_process(process_id, error_message, duration)
          return if @options[:quiet]

          section_id, process = find_process(process_id)
          return unless process && section_id

          section = @sections[section_id]

          process[:status] = :failed
          process[:end_time] = Time.now
          process[:duration] = duration
          process[:error_message] = error_message
          process[:progress_message] = "✗ Failed"

          section[:failed_count] += 1

          # Check if section is complete (even with failures)
          if section[:completed_count] + section[:failed_count] >= section[:process_count]
            complete_section(section_id)
          end

          refresh_display
        end

        # Gets a summary of all section progress
        # @return [Hash] Progress summary
        def progress_summary
          summary = {
            total_sections: @sections.size,
            active_sections: @active_sections.size,
            sections: {}
          }

          @sections.each do |section_id, section|
            summary[:sections][section_id] = {
              title: section[:title],
              status: section[:status],
              progress: (section[:process_count] > 0) ?
                (section[:completed_count].to_f / section[:process_count] * 100).round(1) : 0,
              completed: section[:completed_count],
              failed: section[:failed_count],
              total: section[:process_count]
            }
          end

          summary
        end

        # Clears the progress zone display
        def clear
          return if @options[:quiet] || !@table_rendered

          print @cursor.up(@last_render_lines) if @last_render_lines > 0
          print @cursor.clear_lines(@last_render_lines)
          @table_rendered = false
          @last_render_lines = 0
        end

        private

        # Finds a process by ID across all sections
        # @param process_id [String] The process ID to find
        # @return [Array] [section_id, process] or [nil, nil] if not found
        def find_process(process_id)
          @sections.each do |section_id, section|
            if section[:processes].key?(process_id)
              return [section_id, section[:processes][process_id]]
            end
          end
          [nil, nil]
        end

        # Completes a section when all its processes are done
        # @param section_id [String] The section to complete
        def complete_section(section_id)
          section = @sections[section_id]
          return unless section

          section[:status] = (section[:failed_count] > 0) ? :partial_failure : :completed
          section[:end_time] = Time.now
          @active_sections.delete(section_id)
        end

        # Refreshes the entire progress display
        def refresh_display
          return if @options[:quiet]

          # Clear previous table if it exists
          if @table_rendered
            print @cursor.up(@last_render_lines) if @last_render_lines > 0
            print @cursor.clear_lines(@last_render_lines)
          end

          # Build the table
          table = build_progress_table
          rendered_table = table.render(:unicode, padding: [0, 1])

          puts rendered_table

          # Track rendered lines for future clearing
          @last_render_lines = rendered_table.lines.size
          @table_rendered = true
        end

        # Builds the progress table showing all sections and their status
        # @return [TTY::Table] The formatted progress table
        def build_progress_table
          headers = ["Section", "Status", "Progress", "Activity", "Time"]
          rows = []

          @sections.each do |section_id, section|
            # Section row
            status_symbol = section_status_symbol(section[:status])
            progress_text = build_progress_text(section)
            current_activity = build_current_activity(section)
            duration_text = format_section_duration(section)

            rows << [
              "#{status_symbol} #{truncate_text(section[:title], 15)}",
              format_status(section[:status]),
              progress_text,
              truncate_text(current_activity, 25),
              duration_text
            ]

            # Add active process rows (indented)
            if section[:status] == :in_progress
              section[:processes].each do |process_id, process|
                next unless process[:status] == :in_progress

                process_progress = "  └─ #{process[:progress_message]}"
                process_duration = process[:start_time] ?
                  format_duration(Time.now - process[:start_time]) : "-"

                rows << [
                  "",
                  "",
                  "",
                  process_progress,
                  process_duration
                ]
              end
            end
          end

          TTY::Table.new(header: headers, rows: rows)
        end

        # Builds progress text for a section
        # @param section [Hash] Section data
        # @return [String] Progress display text
        def build_progress_text(section)
          return "-" if section[:process_count] == 0

          completed = section[:completed_count]
          failed = section[:failed_count]
          total = section[:process_count]

          if total > 0
            percentage = ((completed.to_f / total) * 100).round(1)
            bar_width = 8
            filled = (bar_width * completed / total).round

            bar = "█" * filled + "░" * (bar_width - filled)
            if failed > 0
              "#{bar} #{percentage}% (#{failed} failed)"
            else
              "#{bar} #{percentage}%"
            end
          else
            "Pending"
          end
        end

        # Builds current activity text for a section
        # @param section [Hash] Section data
        # @return [String] Current activity description
        def build_current_activity(section)
          case section[:status]
          when :pending
            section[:description]
          when :in_progress
            active_processes = section[:processes].values.select { |p| p[:status] == :in_progress }
            if active_processes.any?
              latest = active_processes.max_by { |p| p[:start_time] }
              truncate_text(latest[:progress_message], 40)
            else
              "Processing..."
            end
          when :completed
            "All tasks completed successfully"
          when :partial_failure
            "Completed with #{section[:failed_count]} failures"
          when :failed
            "Section failed"
          else
            "-"
          end
        end

        # Gets status symbol for a section
        # @param status [Symbol] Section status
        # @return [String] Unicode symbol for the status
        def section_status_symbol(status)
          case status
          when :pending then "⏳"
          when :in_progress then "🔄"
          when :completed then "✅"
          when :partial_failure then "⚠️"
          when :failed then "❌"
          else "?"
          end
        end

        # Formats section status with color
        # @param status [Symbol] Section status
        # @return [String] Colored status text
        def format_status(status)
          case status
          when :pending then colorize_text("Pending", :yellow)
          when :in_progress then colorize_text("Active", :blue)
          when :completed then colorize_text("Done", :green)
          when :partial_failure then colorize_text("Partial", :yellow)
          when :failed then colorize_text("Failed", :red)
          else status.to_s
          end
        end

        # Formats section duration
        # @param section [Hash] Section data
        # @return [String] Formatted duration
        def format_section_duration(section)
          return "-" unless section[:start_time]

          end_time = section[:end_time] || Time.now
          duration = end_time - section[:start_time]
          format_duration(duration)
        end

        # Formats duration in human-readable format
        # @param seconds [Float] Duration in seconds
        # @return [String] Formatted duration
        def format_duration(seconds)
          if seconds < 1
            "#{(seconds * 1000).round}ms"
          elsif seconds < 60
            "#{seconds.round(1)}s"
          else
            "#{(seconds / 60).round(1)}m"
          end
        end

        # Truncates text to specified length
        # @param text [String] Text to truncate
        # @param max_length [Integer] Maximum length
        # @return [String] Truncated text
        def truncate_text(text, max_length)
          return text if text.length <= max_length
          "#{text[0..max_length - 4]}..."
        end

        # Colorizes text unless no_color option is set
        # @param text [String] Text to colorize
        # @param color [Symbol] Color to apply
        # @return [String] Colorized or plain text
        def colorize_text(text, color)
          @options[:no_color] ? text : UI.colorize(text, color)
        end
      end
    end
  end
end
