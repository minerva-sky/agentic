# frozen_string_literal: true

require "tty-spinner"
require "tty-progressbar"
require "tty-box"
require "tty-table"
require "tty-cursor"
require "pastel"

module Agentic
  # UI helpers for the CLI
  module UI
    # Creates and returns a new spinner
    # @param message [String] The message to display with the spinner
    # @param format [Symbol] The spinner format
    # @return [TTY::Spinner] The spinner object
    def self.spinner(message, format: :dots)
      TTY::Spinner.new("[:spinner] #{message}", format: format)
    end

    # Creates and returns a new progress bar
    # @param title [String] The progress bar title
    # @param total [Integer] The total number of steps
    # @param options [Hash] Additional options for the progress bar
    # @return [TTY::ProgressBar] The progress bar object
    def self.progress_bar(title, total, options = {})
      TTY::ProgressBar.new("[:bar] #{title} :percent",
        total: total,
        width: 40,
        **options)
    end

    # Creates a colored text box
    # @param title [String] The box title
    # @param content [String] The box content
    # @param options [Hash] Additional options for the box
    # @return [String] The formatted box
    def self.box(title, content, options = {})
      # Calculate width based on visible characters (strip ANSI codes)
      visible_lines = content.lines.map { |line| line.gsub(/\e\[[0-9;]*m/, "") }
      max_line_length = visible_lines.map(&:length).max || 0

      TTY::Box.frame(
        title: {top_left: title},
        width: [100, max_line_length + 4].min,
        padding: 1,
        **options
      ) { content }
    end

    # Returns a pastel instance for colorizing text
    # @return [Pastel] The pastel instance
    def self.pastel
      @pastel ||= Pastel.new
    end

    # Returns colored text
    # @param text [String] The text to colorize
    # @param color [Symbol] The color to use
    # @return [String] The colorized text
    def self.colorize(text, color)
      pastel.send(color, text)
    end

    # Returns a text with a colored status indicator
    # @param text [String] The text to display
    # @param status [Symbol] The status
    # @return [String] The text with colored status
    def self.status_text(text, status)
      status_color = case status
      when :success, :completed
        :green
      when :failure, :failed, :error
        :red
      when :warning, :pending
        :yellow
      when :info, :in_progress
        :blue
      else
        :white
      end

      pastel.send(status_color, text)
    end

    # Formats a duration in seconds to a human-readable string
    # @param seconds [Float] The duration in seconds
    # @return [String] The formatted duration
    def self.format_duration(seconds)
      if seconds < 1
        "#{(seconds * 1000).round}ms"
      elsif seconds < 60
        "#{seconds.round(2)}s"
      elsif seconds < 3600
        minutes = (seconds / 60).floor
        remaining_seconds = (seconds % 60).round
        "#{minutes}m #{remaining_seconds}s"
      else
        hours = (seconds / 3600).floor
        minutes = ((seconds % 3600) / 60).floor
        "#{hours}h #{minutes}m"
      end
    end

    # Handles a long-running operation with a spinner
    # @param message [String] The message to display
    # @param quiet [Boolean] Whether to suppress output
    # @yield The block to execute
    # @return [Object] The return value of the block
    def self.with_spinner(message, quiet: false)
      return yield if quiet

      spinner = self.spinner(message)
      spinner.auto_spin

      begin
        result = yield
        spinner.success("(#{colorize("✓", :green)}) #{message}")
        result
      rescue => e
        spinner.error("(#{colorize("✗", :red)}) #{message}: #{e.message}")
        raise
      end
    end

    # Returns a task status indicator
    # @param status [Symbol] The status
    # @return [String] The status indicator
    def self.task_status_indicator(status)
      case status
      when :completed
        colorize("✓", :green)
      when :failed
        colorize("✗", :red)
      when :in_progress
        colorize("↻", :blue)
      when :building_agent, :agent_ready
        colorize("○", :yellow)  # Pending task execution
      when :pending
        colorize("○", :yellow)
      when :canceled
        colorize("⨯", :yellow)
      else
        colorize("?", :white)
      end
    end

    # Creates a holistic task display table
    # @param tasks [Array<Hash>] Array of task data with status, description, etc.
    # @param options [Hash] Display options
    # @return [String] The formatted table
    def self.task_display_table(tasks, options = {})
      return "" if tasks.empty?

      # Use simplified headers when show_agent_column is false
      show_agent_column = options.fetch(:show_agent_column, true)
      headers = if show_agent_column
        ["Status", "Task", "Agent", "Duration", "Output"]
      else
        ["Status", "Task", "Duration", "Output"]
      end

      table = TTY::Table.new(
        header: headers,
        rows: tasks.map { |task| format_task_row(task, show_agent_column: show_agent_column) }
      )

      table.render(:unicode,
        padding: [0, 1],
        **options)
    end

    # Returns a cursor instance for terminal positioning
    # @return [TTY::Cursor] The cursor instance
    def self.cursor
      @cursor ||= TTY::Cursor
    end

    # Clears lines and repositions cursor for table updates
    # @param line_count [Integer] Number of lines to clear
    def self.clear_and_reposition(line_count)
      print cursor.up(line_count) + cursor.clear_lines(line_count, :down)
    end

    # Formats a single task row for the display table
    # @param task [Hash] Task data including status, description, duration, output
    # @param show_agent_column [Boolean] Whether to include agent information in the row
    # @return [Array] Formatted row data
    def self.format_task_row(task, show_agent_column: true)
      status_indicator = task_status_indicator(task[:status])

      # Truncate description for display
      description = truncate_text(task[:description] || "Unknown task", 35)

      # Format agent information
      agent_info = if task[:status] == :building_agent
        colorize("🤖 Building...", :blue)
      elsif task[:agent_role]
        if task[:agent_duration]
          colorize("✓ #{task[:agent_role]} (#{format_duration(task[:agent_duration])})", :green)
        else
          colorize("✓ #{task[:agent_role]}", :green)
        end
      else
        "-"
      end

      # Format duration
      duration = if task[:duration]
        format_duration(task[:duration])
      elsif [:in_progress, :building_agent, :agent_ready].include?(task[:status]) && task[:start_time]
        format_duration(Time.now - task[:start_time])
      else
        "-"
      end

      # Format output preview
      output = if task[:output] && !task[:output].to_s.empty?
        truncate_text(task[:output].to_s.strip, 25)
      elsif task[:status] == :failed && task[:error]
        colorize(truncate_text(task[:error], 25), :red)
      else
        "-"
      end

      if show_agent_column
        [status_indicator, description, agent_info, duration, output]
      else
        [status_indicator, description, duration, output]
      end
    end

    # Truncates text to specified length with ellipsis
    # @param text [String] Text to truncate
    # @param max_length [Integer] Maximum length
    # @return [String] Truncated text
    def self.truncate_text(text, max_length)
      return text if text.length <= max_length
      "#{text[0..max_length - 4]}..."
    end

    private_class_method :format_task_row, :truncate_text
  end
end
