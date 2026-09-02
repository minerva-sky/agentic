# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Security::Config do
  after(:each) do
    described_class.reset!
  end

  describe "initialization and configuration" do
    it "uses default configuration" do
      described_class.configure

      expect(described_class.current_config[:sanitization_level]).to be_a(Symbol)
      expect(described_class.pii_detection_enabled?).to be true
      expect(described_class.sanitizer).to be_an(Agentic::Security::Sanitizer)
    end

    it "accepts custom configuration" do
      custom_config = {
        sanitization_level: :strict,
        enable_pii_detection: false,
        log_security_events: true
      }

      described_class.configure(custom_config)

      expect(described_class.current_config[:sanitization_level]).to eq(:strict)
      expect(described_class.pii_detection_enabled?).to be false
      expect(described_class.log_security_events?).to be true
    end

    it "validates security levels" do
      expect {
        described_class.configure(sanitization_level: :invalid_level)
      }.to raise_error(ArgumentError, /Invalid security level/)
    end

    it "creates appropriate sanitizer instance" do
      described_class.configure(sanitization_level: :strict)
      sanitizer = described_class.sanitizer

      expect(sanitizer.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_STRICT)
    end
  end

  describe "environment-specific configuration" do
    it "configures for development environment" do
      described_class.configure_for_environment("development")

      expect(described_class.current_config[:sanitization_level]).to eq(:basic)
      expect(described_class.log_security_events?).to be true
      expect(described_class.backtrace_sanitization_enabled?).to be false
    end

    it "configures for production environment" do
      described_class.configure_for_environment("production")

      expect(described_class.current_config[:sanitization_level]).to eq(:strict)
      expect(described_class.log_security_events?).to be false
      expect(described_class.backtrace_sanitization_enabled?).to be true
    end

    it "configures for staging environment" do
      described_class.configure_for_environment("staging")

      expect(described_class.current_config[:sanitization_level]).to eq(:standard)
      expect(described_class.log_security_events?).to be true
      expect(described_class.backtrace_sanitization_enabled?).to be true
    end
  end

  describe "custom patterns management" do
    before do
      described_class.configure
    end

    it "adds custom patterns" do
      described_class.add_custom_pattern(:internal_id, /ID-\d{6}/, replacement: "[REDACTED_INTERNAL_ID]")

      sanitizer = described_class.sanitizer
      text = "Reference ID-123456 for tracking"
      sanitized = sanitizer.sanitize(text)

      expect(sanitized).to include("[REDACTED_INTERNAL_ID]")
      expect(sanitized).not_to include("ID-123456")
    end

    it "recreates sanitizer when patterns are added" do
      original_sanitizer = described_class.sanitizer
      described_class.add_custom_pattern(:test_pattern, /test-\d+/)
      new_sanitizer = described_class.sanitizer

      expect(new_sanitizer).not_to be(original_sanitizer)
    end
  end

  describe "production configuration" do
    it "provides secure production defaults" do
      config = described_class.production_config

      expect(config[:sanitization_level]).to eq(:strict)
      expect(config[:enable_pii_detection]).to be true
      expect(config[:log_security_events]).to be false
      expect(config[:backtrace_sanitization]).to be true
      expect(config[:custom_patterns]).to be_a(Hash)
      expect(config[:custom_replacements]).to be_a(Hash)
    end
  end

  describe "security level mapping" do
    it "maps security level symbols to integers" do
      described_class.configure(sanitization_level: :none)
      expect(described_class.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_NONE)

      described_class.configure(sanitization_level: :basic)
      expect(described_class.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_BASIC)

      described_class.configure(sanitization_level: :standard)
      expect(described_class.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_STANDARD)

      described_class.configure(sanitization_level: :strict)
      expect(described_class.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_STRICT)

      described_class.configure(sanitization_level: :paranoid)
      expect(described_class.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_PARANOID)
    end
  end

  describe "status reporting" do
    before do
      described_class.configure(
        sanitization_level: :standard,
        enable_pii_detection: true,
        log_security_events: false
      )
    end

    it "provides comprehensive status information" do
      status = described_class.status

      expect(status).to include(
        :security_level,
        :security_level_int,
        :pii_detection,
        :log_events,
        :backtrace_sanitization,
        :custom_patterns,
        :sanitizer_stats
      )

      expect(status[:security_level]).to eq(:standard)
      expect(status[:pii_detection]).to be true
      expect(status[:log_events]).to be false
      expect(status[:sanitizer_stats]).to be_a(Hash)
    end
  end

  describe "environment variable integration" do
    before do
      # Store original values
      @original_security_level = ENV["AGENTIC_SECURITY_LEVEL"]
      @original_pii_detection = ENV["AGENTIC_ENABLE_PII_DETECTION"]
      @original_log_events = ENV["AGENTIC_LOG_SECURITY_EVENTS"]
    end

    after do
      # Restore original values
      ENV["AGENTIC_SECURITY_LEVEL"] = @original_security_level
      ENV["AGENTIC_ENABLE_PII_DETECTION"] = @original_pii_detection
      ENV["AGENTIC_LOG_SECURITY_EVENTS"] = @original_log_events
    end

    it "reads configuration from environment variables" do
      ENV["AGENTIC_SECURITY_LEVEL"] = "strict"
      ENV["AGENTIC_ENABLE_PII_DETECTION"] = "false"
      ENV["AGENTIC_LOG_SECURITY_EVENTS"] = "true"

      # Reset and reconfigure to pick up env vars
      described_class.reset!
      described_class.configure

      expect(described_class.current_config[:sanitization_level]).to eq(:strict)
      expect(described_class.pii_detection_enabled?).to be false
      expect(described_class.log_security_events?).to be true
    end
  end

  describe "sanitizer integration" do
    before do
      described_class.configure(sanitization_level: :standard)
    end

    it "provides working sanitizer through class methods" do
      sanitizer = described_class.sanitizer

      text = "api_key=secret123 user@example.com"
      sanitized = sanitizer.sanitize(text)

      expect(sanitized).to include("[REDACTED_API_KEY]", "[REDACTED_EMAIL]")
      expect(sanitized).not_to include("secret123", "user@example.com")
    end

    it "sanitizer respects configuration changes" do
      # Configure for basic level
      described_class.configure(sanitization_level: :basic)
      basic_sanitizer = described_class.sanitizer

      # Configure for strict level
      described_class.configure(sanitization_level: :strict)
      strict_sanitizer = described_class.sanitizer

      expect(basic_sanitizer.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_BASIC)
      expect(strict_sanitizer.security_level).to eq(Agentic::Security::Sanitizer::SECURITY_LEVEL_STRICT)
    end
  end
end
