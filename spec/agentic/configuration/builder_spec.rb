# frozen_string_literal: true

RSpec.describe Agentic::Configuration::Builder do
  # Register schemas for testing
  before(:all) do
    Agentic::Configuration::Schemas.register_all!
  end

  describe "initialization" do
    it "accepts schema name" do
      builder = described_class.new("llm_config")
      expect(builder.schema.name).to eq("llm_config")
    end

    it "accepts schema object" do
      schema = Agentic::Configuration::Schema.new("test")
      builder = described_class.new(schema)
      expect(builder.schema).to be(schema)
    end

    it "raises error for unknown schema name" do
      expect { described_class.new("unknown_schema") }
        .to raise_error(ArgumentError, /Unknown schema/)
    end
  end

  describe "basic configuration building" do
    let(:builder) { described_class.new("llm_config") }

    it "sets and gets configuration values" do
      builder.set(:model, "gpt-4")
      expect(builder.get(:model)).to eq("gpt-4")
    end

    it "supports method chaining" do
      result = builder.set(:model, "gpt-4").set(:temperature, 0.8)
      expect(result).to be(builder)
      expect(builder.get(:model)).to eq("gpt-4")
      expect(builder.get(:temperature)).to eq(0.8)
    end

    it "merges configuration hashes" do
      builder.merge({model: "gpt-4", temperature: 0.8, max_tokens: 1000})

      expect(builder.get(:model)).to eq("gpt-4")
      expect(builder.get(:temperature)).to eq(0.8)
      expect(builder.get(:max_tokens)).to eq(1000)
    end

    it "checks for key existence" do
      builder.set(:model, "gpt-4")

      expect(builder.key?(:model)).to be true
      expect(builder.key?(:temperature)).to be false
    end

    it "unsets configuration values" do
      builder.set(:model, "gpt-4")
      expect(builder.key?(:model)).to be true

      builder.unset(:model)
      expect(builder.key?(:model)).to be false
    end
  end

  describe "validation" do
    let(:builder) { described_class.new("llm_config") }

    it "validates current configuration" do
      builder.set(:model, "gpt-4") # Required field
      expect(builder.valid?).to be true
    end

    it "detects invalid configuration" do
      # Missing required field 'model'
      expect(builder.valid?).to be false
    end

    it "returns validation errors" do
      errors = builder.validation_errors
      expect(errors).to include(/Missing required fields: model/)
    end

    it "validates with strict mode" do
      builder.set(:model, "gpt-4")
      builder.set(:unknown_field, "value")

      expect(builder.valid?(strict: false)).to be true
      expect(builder.valid?(strict: true)).to be false
    end
  end

  describe "building configuration instances" do
    let(:builder) { described_class.new("llm_config") }

    it "builds valid configuration instance" do
      builder.set(:model, "gpt-4")
      instance = builder.build

      expect(instance).to be_a(Agentic::Configuration::ConfigurationInstance)
      expect(instance[:model]).to eq("gpt-4")
      expect(instance[:temperature]).to eq(0.7) # Default value
    end

    it "raises error for invalid configuration" do
      # Missing required field
      expect { builder.build }.to raise_error(Agentic::Configuration::Schema::ValidationError)
    end

    it "applies defaults during building" do
      builder.set(:model, "gpt-4")
      instance = builder.build

      expect(instance[:temperature]).to eq(0.7)
      expect(instance[:max_tokens]).to eq(1000)
      expect(instance[:timeout]).to eq(120)
    end
  end

  describe "nested configuration support" do
    let(:builder) { described_class.new("agent_config") }

    it "creates nested builders" do
      nested_builder = builder.nested(:llm_config)
      expect(nested_builder).to be_a(described_class)
      expect(nested_builder.schema.name).to eq("llm_config")
    end

    it "configures nested fields with blocks" do
      builder.set(:name, "test_agent")
      builder.set(:capabilities, ["analysis"])

      builder.configure_nested(:llm_config) do |llm|
        llm.set(:model, "gpt-4")
        llm.set(:temperature, 0.5)
      end

      instance = builder.build
      expect(instance[:llm_config][:model]).to eq("gpt-4")
      expect(instance[:llm_config][:temperature]).to eq(0.5)
    end

    it "raises error for non-existent nested field" do
      expect { builder.nested(:non_existent) }
        .to raise_error(ArgumentError, /No nested schema found/)
    end
  end

  describe "convenience factory methods" do
    it "creates LLM config builder" do
      builder = described_class.llm_config
      expect(builder.schema.name).to eq("llm_config")
    end

    it "creates agent config builder" do
      builder = described_class.agent_config
      expect(builder.schema.name).to eq("agent_config")
    end

    it "creates task config builder" do
      builder = described_class.task_config
      expect(builder.schema.name).to eq("task_config")
    end

    it "creates security config builder" do
      builder = described_class.security_config
      expect(builder.schema.name).to eq("security_config")
    end
  end

  describe "fluent convenience methods" do
    context "LLM configuration" do
      let(:builder) { described_class.llm_config }

      it "provides model convenience method" do
        builder.model("gpt-4")
        expect(builder.get(:model)).to eq("gpt-4")
      end

      it "provides temperature convenience method" do
        builder.temperature(0.8)
        expect(builder.get(:temperature)).to eq(0.8)
      end

      it "provides max_tokens convenience method" do
        builder.max_tokens(2000)
        expect(builder.get(:max_tokens)).to eq(2000)
      end

      it "supports method chaining" do
        instance = builder
          .model("gpt-4")
          .temperature(0.8)
          .max_tokens(2000)
          .build

        expect(instance[:model]).to eq("gpt-4")
        expect(instance[:temperature]).to eq(0.8)
        expect(instance[:max_tokens]).to eq(2000)
      end
    end

    context "Agent configuration" do
      let(:builder) { described_class.agent_config }

      it "provides name convenience method" do
        builder.name("test_agent")
        expect(builder.get(:name)).to eq("test_agent")
      end

      it "provides description convenience method" do
        builder.description("A test agent")
        expect(builder.get(:description)).to eq("A test agent")
      end

      it "provides capabilities convenience method" do
        builder.capabilities("analysis", "reporting")
        expect(builder.get(:capabilities)).to eq(["analysis", "reporting"])
      end

      it "provides metadata convenience method" do
        meta = {domain: "finance"}
        builder.metadata(meta)
        expect(builder.get(:metadata)).to eq(meta)
      end
    end

    context "Task configuration" do
      let(:builder) { described_class.task_config }

      it "provides task_description convenience method" do
        builder.task_description("Analyze data")
        expect(builder.get(:description)).to eq("Analyze data")
      end

      it "provides input convenience method" do
        input_data = {file: "data.csv"}
        builder.input(input_data)
        expect(builder.get(:input)).to eq(input_data)
      end

      it "provides priority convenience method" do
        builder.priority(:high)
        expect(builder.get(:priority)).to eq(:high)
      end

      it "provides tags convenience method" do
        builder.tags("urgent", "analytics")
        expect(builder.get(:tags)).to eq(["urgent", "analytics"])
      end

      it "provides deadline convenience method" do
        deadline = Time.new(2024, 12, 31)
        builder.deadline(deadline)
        expect(builder.get(:deadline)).to eq(deadline)
      end
    end

    context "Security configuration" do
      let(:builder) { described_class.security_config }

      it "provides sanitization_level convenience method" do
        builder.sanitization_level(:strict)
        expect(builder.get(:sanitization_level)).to eq(:strict)
      end

      it "provides enable_pii_detection convenience method" do
        builder.enable_pii_detection(false)
        expect(builder.get(:enable_pii_detection)).to be false
      end

      it "provides log_security_events convenience method" do
        builder.log_security_events(true)
        expect(builder.get(:log_security_events)).to be true
      end
    end
  end

  describe "data conversion" do
    let(:builder) { described_class.llm_config.model("gpt-4").temperature(0.8) }

    it "converts to hash" do
      hash = builder.to_h
      expect(hash).to eq({model: "gpt-4", temperature: 0.8})
    end

    it "provides inspect method" do
      inspect_str = builder.inspect
      expect(inspect_str).to include("llm_config")
      expect(inspect_str).to include("gpt-4")
    end
  end

  describe "real-world usage patterns" do
    it "builds complete LLM configuration" do
      config = described_class.llm_config
        .model("gpt-4")
        .temperature(0.8)
        .max_tokens(2000)
        .timeout(60)
        .build

      expect(config[:model]).to eq("gpt-4")
      expect(config[:temperature]).to eq(0.8)
      expect(config[:max_tokens]).to eq(2000)
      expect(config[:timeout]).to eq(60)
    end

    it "builds agent configuration with nested LLM config" do
      config = described_class.agent_config
        .name("data_analyst")
        .description("Analyzes datasets")
        .capabilities("data_analysis", "visualization")
        .configure_nested(:llm_config) do |llm|
          llm.model("gpt-4").temperature(0.3)
        end
        .build

      expect(config[:name]).to eq("data_analyst")
      expect(config[:capabilities]).to eq(["data_analysis", "visualization"])
      expect(config[:llm_config][:model]).to eq("gpt-4")
      expect(config[:llm_config][:temperature]).to eq(0.3)
    end

    it "builds task configuration with computed fields" do
      config = described_class.task_config
        .task_description("Generate quarterly report")
        .priority(:high)
        .tags("quarterly", "finance")
        .input({quarter: "Q4", year: 2024})
        .build

      expect(config[:description]).to eq("Generate quarterly report")
      expect(config[:priority]).to eq(:high)
      expect(config[:estimated_duration]).to eq(7200) # 2 hours for high priority
    end
  end
end
