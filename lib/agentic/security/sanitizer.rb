# frozen_string_literal: true

module Agentic
  module Security
    # Security-aware sanitizer for error messages and log content
    #
    # Provides configurable PII detection and sanitization to prevent
    # sensitive information from being logged or exposed in error messages.
    #
    # Design Goals:
    # 1. Detect common PII patterns (emails, phone numbers, SSNs, API keys)
    # 2. Support configurable sanitization rules per security level
    # 3. Context-aware filtering for different error types
    # 4. Performance-optimized for production logging
    # 5. Extensible pattern matching for domain-specific sensitive data
    #
    # Architect Team Guidance:
    # - Morgan Taylor (Security Specialist): Comprehensive PII pattern coverage
    # - Sam Rodriguez (Maintainability Expert): Clear configuration and testing
    class Sanitizer
      # Security levels for different environments
      SECURITY_LEVEL_NONE = 0      # No sanitization (development only)
      SECURITY_LEVEL_BASIC = 1     # Basic PII patterns
      SECURITY_LEVEL_STANDARD = 2  # Standard production sanitization
      SECURITY_LEVEL_STRICT = 3    # Strict sanitization for sensitive environments
      SECURITY_LEVEL_PARANOID = 4  # Maximum sanitization

      # Default sanitization patterns by security level
      PII_PATTERNS = {
        # API Keys and Tokens (all levels)
        api_key: [
          /\b(?:api[_-]?key|token|secret|password|passwd|pwd)\s*[:=]\s*["']?([a-zA-Z0-9\-_]{8,})["']?/i,
          /\bBearer\s+([a-zA-Z0-9\-._~+\/]+={0,2})/i,
          /\b(?:sk-|pk-|rk-)[a-zA-Z0-9]{20,}/i,
          /\b[a-zA-Z0-9]{32,}\b/ # Generic 32+ char strings that might be keys
        ],

        # Email addresses (BASIC+)
        email: [
          /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
        ],

        # Phone numbers (BASIC+)
        phone: [
          /\b(?:\+?1[-.\s]?)?(?:\(?[0-9]{3}\)?[-.\s]?){1}[0-9]{3}[-.\s]?[0-9]{4}\b/,
          /\b(?:\+?[1-9]{1}[0-9]{0,3}[-.\s]?)?(?:\(?[0-9]{1,4}\)?[-.\s]?){1,3}[0-9]{4,}\b/
        ],

        # Social Security Numbers (STANDARD+)
        ssn: [
          /\b\d{3}[-.\s]?\d{2}[-.\s]?\d{4}\b/
        ],

        # Credit Card Numbers (STANDARD+)
        credit_card: [
          /\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3[0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b/
        ],

        # IP Addresses (STRICT+)
        ip_address: [
          /\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/,
          /\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b/
        ],

        # File paths that might contain sensitive info (STRICT+)
        file_path: [
          %r((?:/[a-zA-Z0-9._-]+){3,}),
          %r([A-Za-z]:\\(?:[^\\/:*?"<>|\r\n]+\\){2,})
        ],

        # Database connection strings (PARANOID+)
        connection_string: [
          /(?:jdbc:|mongodb:|postgres:|mysql:)\/\/[^\s"']+/i,
          /(?:user|username|uid)\s*=\s*[^;\s"']+/i
        ]
      }.freeze

      # Default replacement text for different pattern types
      DEFAULT_REPLACEMENTS = {
        api_key: "[REDACTED_API_KEY]",
        email: "[REDACTED_EMAIL]",
        phone: "[REDACTED_PHONE]",
        ssn: "[REDACTED_SSN]",
        credit_card: "[REDACTED_CARD]",
        ip_address: "[REDACTED_IP]",
        file_path: "[REDACTED_PATH]",
        connection_string: "[REDACTED_CONNECTION]"
      }.freeze

      # Security level to pattern type mapping
      SECURITY_LEVEL_PATTERNS = {
        SECURITY_LEVEL_NONE => [],
        SECURITY_LEVEL_BASIC => [:api_key, :email, :phone],
        SECURITY_LEVEL_STANDARD => [:api_key, :email, :phone, :ssn, :credit_card],
        SECURITY_LEVEL_STRICT => [:api_key, :email, :phone, :ssn, :credit_card, :ip_address, :file_path],
        SECURITY_LEVEL_PARANOID => [:api_key, :email, :phone, :ssn, :credit_card, :ip_address, :file_path, :connection_string]
      }.freeze

      attr_reader :security_level, :custom_patterns, :replacements

      def initialize(security_level: SECURITY_LEVEL_STANDARD, custom_patterns: {}, replacements: {})
        @security_level = security_level
        @custom_patterns = custom_patterns
        @replacements = DEFAULT_REPLACEMENTS.merge(replacements)
        @active_patterns = build_active_patterns
        @performance_cache = {}
      end

      # Sanitize text content based on configured security level
      # @param content [String, Hash, Array] Content to sanitize
      # @param context [Symbol] Context type (:error, :log, :api_response, etc.)
      # @return [String, Hash, Array] Sanitized content
      def sanitize(content, context: :default)
        case content
        when String
          sanitize_string(content, context)
        when Hash
          sanitize_hash(content, context)
        when Array
          sanitize_array(content, context)
        else
          content.to_s # Convert to string and sanitize
        end
      end

      # Sanitize error message specifically
      # @param error [Exception, String] Error or error message to sanitize
      # @param include_backtrace [Boolean] Whether to sanitize backtrace
      # @return [String] Sanitized error message
      def sanitize_error(error, include_backtrace: false)
        case error
        when Exception
          message = sanitize_string(error.message, :error)

          if include_backtrace && error.backtrace
            backtrace = sanitize_backtrace(error.backtrace)
            "#{message}\nBacktrace: #{backtrace.first(5).join("\n")}"
          else
            message
          end
        when String
          sanitize_string(error, :error)
        else
          sanitize_string(error.to_s, :error)
        end
      end

      # Context-aware sanitization for API responses
      # @param response_data [Hash, String] API response data
      # @return [Hash, String] Sanitized response data
      def sanitize_api_response(response_data)
        # More aggressive sanitization for API responses
        case response_data
        when Hash
          sanitized = sanitize_hash(response_data, :api_response)

          # Additional API-specific sanitization
          if sanitized.is_a?(Hash)
            # Remove common sensitive API fields
            sanitized.reject { |k, _| sensitive_api_field?(k) }
          else
            sanitized
          end
        else
          sanitize_string(response_data.to_s, :api_response)
        end
      end

      # Sanitize LLM request/response content
      # @param llm_content [Hash, String] LLM request or response content
      # @return [Hash, String] Sanitized content safe for logging
      def sanitize_llm_content(llm_content)
        case llm_content
        when Hash
          sanitized = {}

          llm_content.each do |key, value|
            sanitized[key] = case key.to_s
            when "messages", "content", "text", "input"
              # Truncate and sanitize user content
              sanitize_and_truncate(value, max_length: 200)
            when "model", "temperature", "max_tokens"
              # Safe metadata
              value
            when "api_key", "authorization", "bearer"
              # Always redact auth info
              "[REDACTED_AUTH]"
            else
              sanitize(value, context: :llm_content)
            end
          end

          sanitized
        else
          sanitize_and_truncate(llm_content.to_s, max_length: 200)
        end
      end

      # Check if content contains potentially sensitive information
      # @param content [String] Content to check
      # @return [Boolean] True if potentially sensitive
      def potentially_sensitive?(content)
        return false if content.nil? || content.empty?

        @active_patterns.any? do |pattern_type, patterns|
          patterns.any? { |pattern| content.match?(pattern) }
        end
      end

      # Get sanitization statistics
      # @return [Hash] Statistics about sanitization operations
      def statistics
        {
          security_level: @security_level,
          active_pattern_types: @active_patterns.keys,
          total_patterns: @active_patterns.values.sum(&:size),
          cache_size: @performance_cache.size
        }
      end

      # Class method: Validate file content for security threats
      #
      # Checks artifact content for malicious patterns before writing to workspace.
      # Raises SecurityError if threats are detected.
      #
      # @param content [String] File content to validate
      # @param artifact_type [Symbol] Type of artifact (:ruby_class, :javascript_module, etc.)
      # @raise [SecurityError] If malicious patterns detected
      # @return [void]
      #
      # @example
      #   Security::Sanitizer.sanitize_file_content("class User; end", :ruby_class)
      #   Security::Sanitizer.sanitize_file_content("eval(params[:code])", :ruby_class) # raises SecurityError
      def self.sanitize_file_content(content, artifact_type)
        return if content.nil? || content.empty?

        # Check valid encoding before attempting regex matching
        unless content.valid_encoding?
          raise SecurityError, "Content has invalid encoding (#{content.encoding.name})"
        end

        # Check for command injection patterns
        dangerous_patterns = {
          command_injection: [
            /`[^`]*`/,                              # Backticks
            /system\s*\(/,                          # system() calls
            /exec\s*\(/,                            # exec() calls
            /%x\{/,                                 # %x{} syntax
            /IO\.popen/,                            # IO.popen
            /Open3\./                               # Open3 module
          ],
          code_injection: [
            /\beval\s*\(/,                          # eval() calls
            /instance_eval/,                        # instance_eval
            /class_eval/,                           # class_eval
            /module_eval/,                          # module_eval
            /binding\.eval/                         # binding.eval
          ],
          sql_injection: [
            /;\s*DROP\s+TABLE/i,                    # DROP TABLE
            /;\s*DELETE\s+FROM/i,                   # DELETE FROM
            /UNION\s+SELECT/i,                      # UNION SELECT
            /'--/,                                  # SQL comment injection
            /'\s*OR\s+'1'\s*=\s*'1/i               # Classic SQL injection
          ],
          file_system_manipulation: [
            /File\.delete/,                         # File deletion
            /FileUtils\.rm_rf/,                     # Recursive deletion
            /File\.chmod\s*\(\s*0777/              # Overly permissive permissions
          ]
        }

        # Check each pattern category
        dangerous_patterns.each do |category, patterns|
          patterns.each do |pattern|
            if content.match?(pattern)
              raise SecurityError, "Potentially malicious #{category} pattern detected in artifact content"
            end
          end
        end

        # Type-specific validation
        case artifact_type
        when :ruby_class
          validate_ruby_content(content)
        when :javascript_module
          validate_javascript_content(content)
        when :python_module
          validate_python_content(content)
        end
      end

      # Validate Ruby-specific security concerns
      # @param content [String] Ruby code content
      # @raise [SecurityError] If Ruby-specific threats detected
      def self.validate_ruby_content(content)
        # Additional Ruby-specific checks
        ruby_dangerous_patterns = [
          /Kernel\.system/,
          /__FILE__.*eval/,
          /require\s+['"]fiddle['"]/,              # FFI access
          /DL\./                                    # Foreign function interface
        ]

        ruby_dangerous_patterns.each do |pattern|
          if content.match?(pattern)
            raise SecurityError, "Potentially dangerous Ruby pattern detected in artifact content"
          end
        end
      end

      # Validate JavaScript-specific security concerns
      # @param content [String] JavaScript code content
      # @raise [SecurityError] If JavaScript-specific threats detected
      def self.validate_javascript_content(content)
        js_dangerous_patterns = [
          /eval\s*\(/,
          /Function\s*\(/,
          /setTimeout\s*\(\s*["'`]/,               # setTimeout with string
          /setInterval\s*\(\s*["'`]/,              # setInterval with string
          /innerHTML\s*=/,                         # DOM manipulation (XSS vector)
          /document\.write/                        # Direct document writing
        ]

        js_dangerous_patterns.each do |pattern|
          if content.match?(pattern)
            raise SecurityError, "Potentially dangerous JavaScript pattern detected in artifact content"
          end
        end
      end

      # Validate Python-specific security concerns
      # @param content [String] Python code content
      # @raise [SecurityError] If Python-specific threats detected
      def self.validate_python_content(content)
        python_dangerous_patterns = [
          /\beval\s*\(/,
          /\bexec\s*\(/,
          /__import__\s*\(\s*["']os["']\)/,       # Dynamic os import
          /subprocess\./,                          # Subprocess calls
          /os\.system/                             # Shell execution
        ]

        python_dangerous_patterns.each do |pattern|
          if content.match?(pattern)
            raise SecurityError, "Potentially dangerous Python pattern detected in artifact content"
          end
        end
      end

      private

      # Build active patterns based on security level and custom patterns
      def build_active_patterns
        patterns = {}

        # Add custom patterns FIRST to give them precedence
        @custom_patterns.each do |pattern_type, custom_patterns|
          patterns[pattern_type] = Array(custom_patterns)
        end

        # Then add built-in patterns
        active_types = SECURITY_LEVEL_PATTERNS[@security_level] || []
        active_types.each do |pattern_type|
          if patterns[pattern_type]
            # Custom patterns exist for this type, append built-in after them
            patterns[pattern_type] += PII_PATTERNS[pattern_type] || []
          else
            # No custom patterns, use built-in only
            patterns[pattern_type] = PII_PATTERNS[pattern_type] || []
          end
        end

        patterns
      end

      # Sanitize string content
      def sanitize_string(content, context)
        return content if @security_level == SECURITY_LEVEL_NONE
        return "" if content.nil?

        # Use performance cache for repeated content
        cache_key = "#{content.hash}_#{context}"
        return @performance_cache[cache_key] if @performance_cache[cache_key]

        sanitized = content.dup

        @active_patterns.each do |pattern_type, patterns|
          replacement = @replacements[pattern_type] || "[REDACTED]"

          patterns.each do |pattern|
            sanitized = sanitized.gsub(pattern, replacement)
          end
        end

        # Cache result for performance (limit cache size)
        if @performance_cache.size < 1000
          @performance_cache[cache_key] = sanitized
        end

        sanitized
      end

      # Sanitize hash content recursively
      def sanitize_hash(hash, context)
        return {} if hash.nil?

        sanitized = {}

        hash.each do |key, value|
          sanitized_key = sanitize_string(key.to_s, context)

          sanitized[sanitized_key] = case value
          when String
            sanitize_string(value, context)
          when Hash
            sanitize_hash(value, context)
          when Array
            sanitize_array(value, context)
          else
            value
          end
        end

        sanitized
      end

      # Sanitize array content
      def sanitize_array(array, context)
        return [] if array.nil?

        array.map do |item|
          case item
          when String
            sanitize_string(item, context)
          when Hash
            sanitize_hash(item, context)
          when Array
            sanitize_array(item, context)
          else
            item
          end
        end
      end

      # Sanitize backtrace information
      def sanitize_backtrace(backtrace)
        return [] if backtrace.nil?

        backtrace.map do |trace_line|
          sanitize_string(trace_line, :backtrace)
        end
      end

      # Sanitize and truncate content
      def sanitize_and_truncate(content, max_length: 100)
        sanitized = sanitize_string(content.to_s, :truncated)

        if sanitized.length > max_length
          "#{sanitized[0, max_length]}... [TRUNCATED]"
        else
          sanitized
        end
      end

      # Check if API field is sensitive
      def sensitive_api_field?(field_name)
        sensitive_fields = %w[
          api_key token secret password passwd pwd
          authorization bearer access_token refresh_token
          private_key public_key certificate cert
          session_id session_token
        ]

        field_str = field_name.to_s.downcase
        sensitive_fields.any? { |sensitive| field_str.include?(sensitive) }
      end
    end
  end
end
