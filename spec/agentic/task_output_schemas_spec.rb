# frozen_string_literal: true

RSpec.describe Agentic::TaskOutputSchemas do
  before do
    # Reset schemas before each test to ensure clean state
    described_class.reset!
    described_class.register_defaults!
  end

  after do
    # Reset after tests to avoid affecting other tests
    described_class.reset!
    described_class.register_defaults!
  end

  describe ".register" do
    it "registers a new schema" do
      schema = Agentic::StructuredOutputs::Schema.new("test_schema") do |s|
        s.string(:name)
      end

      described_class.register(:test, schema)

      expect(described_class.exists?(:test)).to be true
      expect(described_class.get(:test)).to eq schema
    end
  end

  describe ".get" do
    it "returns a registered schema" do
      schema = Agentic::StructuredOutputs::Schema.new("test_schema") do |s|
        s.string(:name)
      end
      described_class.register(:test, schema)

      result = described_class.get(:test)

      expect(result).to eq schema
    end

    it "returns the default schema for :default" do
      result = described_class.get(:default)

      expect(result).to be_a(Agentic::StructuredOutputs::Schema)
      expect(result.to_hash[:name]).to eq "task_output"
    end

    it "returns nil for non-existent schema" do
      result = described_class.get(:non_existent)

      expect(result).to be_nil
    end
  end

  describe ".list_schemas" do
    it "lists all registered schemas including default" do
      schema1 = Agentic::StructuredOutputs::Schema.new("test1") { |s| s.string(:name) }
      schema2 = Agentic::StructuredOutputs::Schema.new("test2") { |s| s.string(:title) }

      described_class.register(:test1, schema1)
      described_class.register(:test2, schema2)

      schemas = described_class.list_schemas

      expect(schemas).to include(:default, :simple_object, :code_generation, :analysis, :test1, :test2)
      expect(schemas.uniq.length).to eq schemas.length # No duplicates
    end
  end

  describe ".exists?" do
    it "returns true for registered schemas" do
      schema = Agentic::StructuredOutputs::Schema.new("test") { |s| s.string(:name) }
      described_class.register(:test, schema)

      expect(described_class.exists?(:test)).to be true
    end

    it "returns true for :default" do
      expect(described_class.exists?(:default)).to be true
    end

    it "returns false for non-existent schemas" do
      expect(described_class.exists?(:non_existent)).to be false
    end
  end

  describe ".default_task_schema" do
    it "returns a properly structured default schema" do
      schema = described_class.default_task_schema

      expect(schema).to be_a(Agentic::StructuredOutputs::Schema)

      schema_hash = schema.to_hash
      expect(schema_hash[:name]).to eq "task_output"
      expect(schema_hash[:schema][:type]).to eq "object"

      properties = schema_hash[:schema][:properties]
      expect(properties).to have_key(:status)
      expect(properties).to have_key(:result)
      expect(properties).to have_key(:steps)

      # Check status enum
      expect(properties[:status][:enum]).to eq ["completed", "partial", "failed"]

      # Check result object structure
      expect(properties[:result][:type]).to eq "object"
      expect(properties[:result][:properties]).to have_key(:summary)

      # Check steps array
      expect(properties[:steps][:type]).to eq "array"
      expect(properties[:steps][:items][:type]).to eq "string"
    end
  end

  describe ".simple_object_schema" do
    it "returns a simple flexible schema" do
      schema = described_class.simple_object_schema

      expect(schema).to be_a(Agentic::StructuredOutputs::Schema)

      schema_hash = schema.to_hash
      expect(schema_hash[:name]).to eq "simple_object"

      properties = schema_hash[:schema][:properties]
      expect(properties).to have_key(:type)
      expect(properties).to have_key(:data)
      expect(properties[:data][:type]).to eq "object"
    end
  end

  describe ".code_generation_schema" do
    it "returns a code generation schema" do
      schema = described_class.code_generation_schema

      expect(schema).to be_a(Agentic::StructuredOutputs::Schema)

      schema_hash = schema.to_hash
      expect(schema_hash[:name]).to eq "code_generation"

      properties = schema_hash[:schema][:properties]
      expect(properties).to have_key(:language)
      expect(properties).to have_key(:filename)
      expect(properties).to have_key(:code)
      expect(properties).to have_key(:description)
      expect(properties).to have_key(:dependencies)
    end
  end

  describe ".analysis_schema" do
    it "returns an analysis schema" do
      schema = described_class.analysis_schema

      expect(schema).to be_a(Agentic::StructuredOutputs::Schema)

      schema_hash = schema.to_hash
      expect(schema_hash[:name]).to eq "analysis_result"

      properties = schema_hash[:schema][:properties]
      expect(properties).to have_key(:summary)
      expect(properties).to have_key(:key_findings)
      expect(properties).to have_key(:data)
      expect(properties).to have_key(:recommendations)
      expect(properties).to have_key(:confidence_level)
    end
  end

  describe ".register_defaults!" do
    it "registers all default schemas" do
      described_class.reset!

      # Note: :default always exists due to the special case in exists? method
      expect(described_class.exists?(:simple_object)).to be false
      expect(described_class.exists?(:code_generation)).to be false
      expect(described_class.exists?(:analysis)).to be false

      described_class.register_defaults!

      expect(described_class.exists?(:default)).to be true
      expect(described_class.exists?(:simple_object)).to be true
      expect(described_class.exists?(:code_generation)).to be true
      expect(described_class.exists?(:analysis)).to be true
    end
  end

  describe ".reset!" do
    it "clears all registered schemas and cached instances" do
      # Register a custom schema
      schema = Agentic::StructuredOutputs::Schema.new("test") { |s| s.string(:name) }
      described_class.register(:test, schema)

      # Access default schema to cache it
      described_class.default_task_schema

      expect(described_class.exists?(:test)).to be true

      described_class.reset!

      expect(described_class.exists?(:test)).to be false
      # Note: :default always exists due to the special case in exists? method
      expect(described_class.exists?(:default)).to be true
      expect(described_class.list_schemas).to eq([:default])
    end
  end
end
