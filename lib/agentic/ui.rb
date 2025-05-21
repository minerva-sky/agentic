# frozen_string_literal: true

require "tty-spinner"
require "tty-progressbar"
require "tty-box"
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
      TTY::Box.frame(
        title: {top_left: title},
        width: [80, content.lines.map(&:length).max + 4].min,
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
      when :pending
        colorize("○", :yellow)
      when :canceled
        colorize("⨯", :yellow)
      else
        colorize("?", :white)
      end
    end
  end
end
