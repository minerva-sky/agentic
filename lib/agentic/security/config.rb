# frozen_string_literal: true

module Agentic
  module Security
    # Security configuration management for sanitization and error handling
    #
    # Provides centralized configuration for security settings including
    # sanitization levels, custom patterns, and environment-specific settings.
    class Config
      # Default configuration values
      DEFAULT_CONFIG = {
        sanitization_level: ENV.fetch("AGENTIC_SECURITY_LEVEL", "standard").to_sym,
        enable_pii_detection: ENV.fetch("AGENTIC_ENABLE_PII_DETECTION", "true") == "true",
        log_security_events: ENV.fetch("AGENTIC_LOG_SECURITY_EVENTS", "false") == "true",
        custom_patterns: {},
        custom_replacements: {},
        performance_cache_enabled: true,
        backtrace_sanitization: ENV.fetch("AGENTIC_SANITIZE_BACKTRACES", "true") == "true"
      }.freeze

      # Security level mapping
      SECURITY_LEVELS = {
        none: Sanitizer::SECURITY_LEVEL_NONE,
        basic: Sanitizer::SECURITY_LEVEL_BASIC,
        standard: Sanitizer::SECURITY_LEVEL_STANDARD,
        strict: Sanitizer::SECURITY_LEVEL_STRICT,
        paranoid: Sanitizer::SECURITY_LEVEL_PARANOID
      }.freeze

      class << self
        # Initialize security configuration
        def configure(config = {})
          # Build default config fresh to pick up ENV changes
          default_config = {
            sanitization_level: ENV.fetch("AGENTIC_SECURITY_LEVEL", "standard").to_sym,
            enable_pii_detection: ENV.fetch("AGENTIC_ENABLE_PII_DETECTION", "true") == "true",
            log_security_events: ENV.fetch("AGENTIC_LOG_SECURITY_EVENTS", "false") == "true",
            custom_patterns: {},
            custom_replacements: {},
            performance_cache_enabled: true,
            backtrace_sanitization: ENV.fetch("AGENTIC_SANITIZE_BACKTRACES", "true") == "true"
          }

          @current_config = default_config.dup.tap do |c|
            c[:custom_patterns] = c[:custom_patterns].dup
            c[:custom_replacements] = c[:custom_replacements].dup
          end.merge(config)

          # Validate security level
          unless SECURITY_LEVELS.key?(@current_config[:sanitization_level])
            raise ArgumentError, "Invalid security level: #{@current_config[:sanitization_level]}"
          end

          # Create sanitizer instance
          @sanitizer = create_sanitizer

          Agentic.logger&.info("Security configuration initialized: level=#{@current_config[:sanitization_level]}")
        end

        # Get current sanitizer instance
        def sanitizer
          @sanitizer ||= create_sanitizer
        end

        # Get security level as integer
        def security_level
          SECURITY_LEVELS[current_config[:sanitization_level]] || Sanitizer::SECURITY_LEVEL_STANDARD
        end

        # Check if PII detection is enabled
        def pii_detection_enabled?
          current_config[:enable_pii_detection]
        end

        # Check if security events should be logged
        def log_security_events?
          current_config[:log_security_events]
        end

        # Check if backtrace sanitization is enabled
        def backtrace_sanitization_enabled?
          current_config[:backtrace_sanitization]
        end

        # Add custom PII pattern
        def add_custom_pattern(pattern_type, pattern, replacement: nil)
          # Initialize config if needed
          configure unless @current_config

          @current_config[:custom_patterns][pattern_type] ||= []
          @current_config[:custom_patterns][pattern_type] << pattern

          if replacement
            @current_config[:custom_replacements][pattern_type] = replacement
          end

          # Recreate sanitizer with new patterns
          @sanitizer = create_sanitizer
        end

        # Environment-specific configuration
        def configure_for_environment(env = nil)
          env ||= ENV.fetch("AGENTIC_ENV", "development")

          config = case env.to_s
          when "development", "test"
            {
              sanitization_level: :basic,
              log_security_events: true,
              backtrace_sanitization: false
            }
          when "staging"
            {
              sanitization_level: :standard,
              log_security_events: true,
              backtrace_sanitization: true
            }
          when "production"
            {
              sanitization_level: :strict,
              log_security_events: false,
              backtrace_sanitization: true
            }
          else
            DEFAULT_CONFIG
          end

          configure(config)
        end

        # Production-ready configuration
        def production_config
          {
            sanitization_level: :strict,
            enable_pii_detection: true,
            log_security_events: false,
            performance_cache_enabled: true,
            backtrace_sanitization: true,
            custom_patterns: {
              # Organization-specific patterns
              internal_id: [/\b(?:ID|id)[-_]?\d{8,}\b/],
              project_code: [/\b[A-Z]{2,}-\d{4,}\b/]
            },
            custom_replacements: {
              internal_id: "[REDACTED_ID]",
              project_code: "[REDACTED_CODE]"
            }
          }
        end

        # Get configuration status for debugging
        def status
          {
            security_level: current_config[:sanitization_level],
            security_level_int: security_level,
            pii_detection: pii_detection_enabled?,
            log_events: log_security_events?,
            backtrace_sanitization: backtrace_sanitization_enabled?,
            custom_patterns: current_config[:custom_patterns].keys,
            sanitizer_stats: sanitizer&.statistics
          }
        end

        # Get current configuration with lazy initialization
        def current_config
          @current_config ||= DEFAULT_CONFIG
        end

        private

        def create_sanitizer
          Sanitizer.new(
            security_level: security_level,
            custom_patterns: current_config[:custom_patterns],
            replacements: current_config[:custom_replacements]
          )
        end
      end

      # Reset configuration (mainly for testing)
      def self.reset!
        @current_config = nil
        @sanitizer = nil
      end
    end
  end
end
