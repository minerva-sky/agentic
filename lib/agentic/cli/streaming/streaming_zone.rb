# frozen_string_literal: true

require "tty-spinner"
require "tty-progressbar"
require "tty-cursor"

module Agentic
  class CLI < Thor
    module Streaming
      # Handles real-time token streaming display with intelligent progress indicators
      class StreamingZone
        attr_reader :token_count, :start_time, :current_message

        def initialize(options = {})
          @options = options
          @cursor = TTY::Cursor
          @token_count = 0
          @start_time = Time.now
          @current_message = ""
          @estimated_total = nil
          @last_update_time = Time.now
          @accumulated_content = ""

          # Initialize spinner with custom format
          @spinner = TTY::Spinner.new(
            "[:spinner] :message",
            format: :dots,
            success_mark: "✓",
            error_mark: "✗"
          )

          @progress_bar = nil
          @zone_height = 3
          @is_active = false
        end

        # Starts the streaming zone display
        def start(initial_message = "🚀 Initializing response generation...")
          return if @options[:quiet]

          @is_active = true
          @start_time = Time.now
          @spinner.auto_spin
          update_message(initial_message)
        end

        # Updates the streaming progress with a new token
        # @param token [String] The new token received
        # @param intelligent_message [String] Context-aware progress message
        # @param estimated_total [Integer, nil] Estimated total tokens (optional)
        def update_token_progress(token, intelligent_message, estimated_total = nil)
          return if @options[:quiet] || !@is_active

          @token_count += 1
          @accumulated_content += token
          @estimated_total = estimated_total if estimated_total
          @current_message = intelligent_message

          # Throttle updates to prevent excessive screen refreshes
          now = Time.now
          return unless should_update?(now)
          @last_update_time = now

          # Update progress bar if we have an estimate
          update_progress_bar if @estimated_total

          # Update spinner with intelligent message and metrics
          update_message_with_metrics(intelligent_message)
        end

        # Updates the streaming status message
        # @param message [String] The new status message
        def update_message(message)
          return if @options[:quiet] || !@is_active

          @current_message = message
          @spinner.update(title: message)
        end

        # Marks the streaming as successful and completes
        # @param final_message [String] Final completion message
        def complete(final_message = "Response generation completed")
          return if @options[:quiet] || !@is_active

          @spinner.success(final_message)
          @progress_bar&.finish
          @is_active = false

          # Show final metrics
          duration = Time.now - @start_time
          rate = @token_count / duration
          puts "  📊 Generated #{@token_count} tokens in #{format_duration(duration)} (#{rate.round(1)} tokens/sec)"
        end

        # Marks the streaming as failed
        # @param error_message [String] Error message to display
        def fail(error_message = "Response generation failed")
          return if @options[:quiet] || !@is_active

          @spinner.error(error_message)
          @progress_bar&.finish
          @is_active = false
        end

        # Stops the streaming display (for cancellation)
        def stop
          return if @options[:quiet] || !@is_active

          @spinner.stop
          @progress_bar&.finish
          @is_active = false
          puts "  ⚠️  Response generation cancelled"
        end

        # Gets current streaming statistics
        # @return [Hash] Current statistics
        def stats
          duration = Time.now - @start_time
          rate = (duration > 0) ? @token_count / duration : 0

          {
            token_count: @token_count,
            duration: duration,
            rate: rate,
            estimated_progress: estimated_progress,
            current_message: @current_message
          }
        end

        # Estimates response length based on content analysis
        # @param goal [String] The planning goal
        # @return [Integer] Estimated token count
        def self.estimate_response_length(goal)
          # Simple heuristic based on goal complexity
          base_tokens = 200  # Base JSON structure

          # Add tokens based on goal length and complexity
          goal_complexity = goal.length / 10
          task_estimate = [goal_complexity / 20, 1].max * 150  # Tasks section
          format_estimate = 100  # Expected answer format section

          (base_tokens + task_estimate + format_estimate).to_i
        end

        private

        # Determines if we should update the display based on time throttling
        # @param now [Time] Current time
        # @return [Boolean] Whether to update
        def should_update?(now)
          # Update every 10 tokens or every 0.5 seconds, whichever comes first
          (@token_count % 10 == 0) || (now - @last_update_time) >= 0.5
        end

        # Updates the progress bar display
        def update_progress_bar
          @progress_bar ||= TTY::ProgressBar.new(
            "  Progress: [:bar] :percent (:current/:total tokens)",
            total: @estimated_total,
            width: 40,
            bar_format: :block,
            head: "█",
            incomplete: "░"
          )

          @progress_bar.current = [@token_count, @estimated_total].min
        end

        # Updates spinner message with token metrics
        # @param base_message [String] The intelligent progress message
        def update_message_with_metrics(base_message)
          duration = Time.now - @start_time
          rate = (duration > 0) ? @token_count / duration : 0

          # Enhanced message with metrics
          if @estimated_total
            progress_percent = ((@token_count.to_f / @estimated_total) * 100).round(1)
            enhanced_message = "#{base_message} (#{@token_count}/#{@estimated_total} tokens, #{progress_percent}%)"
          else
            enhanced_message = "#{base_message} (#{@token_count} tokens, #{rate.round(1)}/sec)"
          end

          @spinner.update(title: enhanced_message)
        end

        # Calculates current progress percentage
        # @return [Float] Progress percentage (0-100)
        def estimated_progress
          return 0.0 unless @estimated_total && @estimated_total > 0
          ((@token_count.to_f / @estimated_total) * 100).round(1)
        end

        # Formats duration in a human-readable way
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
      end
    end
  end
end
