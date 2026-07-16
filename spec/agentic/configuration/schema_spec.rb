# frozen_string_literal: true

RSpec.describe Agentic::Configuration::Schema do
  let(:schema) { described_class.new("test_schema") }

  describe "initialization" do
    it "creates schema with name and version" do
      schema = described_class.new("test", version: "2.0.0")
      expect(schema.name).to eq("test")
      expect(schema.version).to eq("2.0.0")
    end

    it "defaults to version 1.0.0" do
      expect(schema.version).to eq("1.0.0")
    end
  end

  describe "field definition" do
    it "defines basic fields" do
      schema.field(:name, type: :string, required: true)
      schema.field(:age, type: :integer, required: false, default: 0)

      config = {name: "Test"}
      validated_config = schema.apply_defaults(config)

      expect(validated_config[:name]).to eq("Test")
      expect(validated_config[:age]).to eq(0)
    end

    it "supports constraints" do
      schema.field(:score, type: :integer,
        constraints: [->(v) { v >= 0 && v <= 100 }])

      expect { schema.validate!({score: 50}) }.not_to raise_error
      expect { schema.validate!({score: -1}) }.to raise_error(described_class::ValidationError)
      expect { schema.validate!({score: 101}) }.to raise_error(described_class::ValidationError)
    end

    it "supports callable defaults" do
      schema.field(:timestamp, type: :time, default: -> { Time.now })

      config = schema.apply_defaults({})
      expect(config[:timestamp]).to be_a(Time)
    end

    it "stores field documentation" do
      schema.field(:email, type: :string,
        description: "User email address",
        example: "user@example.com")

      doc = schema.documentation
      expect(doc[:fields][:email][:description]).to eq("User email address")
      expect(doc[:fields][:email][:example]).to eq("user@example.com")
    end
  end

  describe "type validation" do
    it "validates string fields" do
      schema.field(:name, type: :string)

      expect { schema.validate!({name: "valid"}) }.not_to raise_error
      expect { schema.validate!({name: 123}) }.to raise_error(described_class::ValidationError, /must be of type string/)
    end

    it "validates integer fields" do
      schema.field(:count, type: :integer)

      expect { schema.validate!({count: 42}) }.not_to raise_error
      expect { schema.validate!({count: "42"}) }.to raise_error(described_class::ValidationError)
    end

    it "validates boolean fields" do
      schema.field(:enabled, type: :boolean)

      expect { schema.validate!({enabled: true}) }.not_to raise_error
      expect { schema.validate!({enabled: false}) }.not_to raise_error
      expect { schema.validate!({enabled: "true"}) }.to raise_error(described_class::ValidationError)
    end

    it "validates array fields" do
      schema.field(:tags, type: :array)

      expect { schema.validate!({tags: ["a", "b", "c"]}) }.not_to raise_error
      expect { schema.validate!({tags: "not an array"}) }.to raise_error(described_class::ValidationError)
    end

    it "validates custom class types" do
      schema.field(:timestamp, type: Time)

      time = Time.now
      expect { schema.validate!({timestamp: time}) }.not_to raise_error
      expect { schema.validate!({timestamp: "not a time"}) }.to raise_error(described_class::ValidationError)
    end

    it "validates with custom type procs" do
      positive_number = ->(v) { v.is_a?(Numeric) && v > 0 }
      schema.field(:amount, type: positive_number)

      expect { schema.validate!({amount: 10}) }.not_to raise_error
      expect { schema.validate!({amount: -5}) }.to raise_error(described_class::ValidationError)
      expect { schema.validate!({amount: "10"}) }.to raise_error(described_class::ValidationError)
    end
  end

  describe "required field validation" do
    it "enforces required fields" do
      schema.field(:required_field, type: :string, required: true)
      schema.field(:optional_field, type: :string, required: false)

      expect { schema.validate!({required_field: "present"}) }.not_to raise_error
      expect { schema.validate!({optional_field: "present"}) }.to raise_error(described_class::ValidationError, /Missing required fields/)
    end

    it "lists all missing required fields" do
      schema.field(:field1, type: :string, required: true)
      schema.field(:field2, type: :string, required: true)
      schema.field(:field3, type: :string, required: false)

      expect { schema.validate!({field3: "present"}) }
        .to raise_error(described_class::ValidationError, /Missing required fields: field1, field2/)
    end
  end

  describe "nested schemas" do
    let(:nested_schema) do
      described_class.new("nested").tap do |s|
        s.field(:nested_field, type: :string, required: true)
        s.field(:nested_number, type: :integer, default: 42)
      end
    end

    it "validates nested object schemas" do
      schema.nested(:nested_config, nested_schema, required: true)

      valid_config = {
        nested_config: {
          nested_field: "test",
          nested_number: 100
        }
      }

      expect { schema.validate!(valid_config) }.not_to raise_error
    end

    it "validates nested array schemas" do
      schema.nested(:nested_array, nested_schema, array: true)

      valid_config = {
        nested_array: [
          {nested_field: "first"},
          {nested_field: "second", nested_number: 200}
        ]
      }

      expect { schema.validate!(valid_config) }.not_to raise_error
    end

    it "reports nested validation errors with context" do
      schema.nested(:nested_config, nested_schema)

      invalid_config = {
        nested_config: {
          nested_number: "not a number"
        }
      }

      expect { schema.validate!(invalid_config) }
        .to raise_error(described_class::ValidationError, /nested_config.*Missing required fields: nested_field/)
    end
  end

  describe "computed fields" do
    it "computes fields based on dependencies" do
      schema.field(:first_name, type: :string, required: true)
      schema.field(:last_name, type: :string, required: true)

      schema.computed(:full_name, dependencies: [:first_name, :last_name]) do |config, first, last|
        "#{first} #{last}"
      end

      config = {first_name: "John", last_name: "Doe"}
      result = schema.apply_defaults(config)

      expect(result[:full_name]).to eq("John Doe")
    end

    it "raises error for missing dependencies" do
      schema.field(:base, type: :integer)
      schema.computed(:doubled, dependencies: [:base]) { |config, base| base * 2 }

      expect { schema.apply_defaults({}) }
        .to raise_error(described_class::ValidationError, /Cannot compute doubled.*missing dependencies/)
    end
  end

  describe "cross-field validation" do
    it "validates relationships between fields" do
      schema.field(:start_date, type: Time)
      schema.field(:end_date, type: Time)

      schema.validate("End date must be after start date") do |config|
        !config[:start_date] || !config[:end_date] || config[:end_date] > config[:start_date]
      end

      start_time = Time.new(2024, 1, 1)
      end_time = Time.new(2024, 12, 31)

      expect { schema.validate!({start_date: start_time, end_date: end_time}) }.not_to raise_error
      expect { schema.validate!({start_date: end_time, end_date: start_time}) }
        .to raise_error(described_class::ValidationError, "End date must be after start date")
    end
  end

  describe "strict mode validation" do
    it "rejects unknown fields in strict mode" do
      schema.field(:known_field, type: :string)

      config = {known_field: "value", unknown_field: "unexpected"}

      expect { schema.validate!(config, strict: false) }.not_to raise_error
      expect { schema.validate!(config, strict: true) }
        .to raise_error(described_class::ValidationError, /Unknown fields: unknown_field/)
    end
  end

  describe "configuration instance creation" do
    it "creates validated configuration instance" do
      schema.field(:name, type: :string, required: true)
      schema.field(:count, type: :integer, default: 1)

      config_instance = schema.create({name: "test"})

      expect(config_instance).to be_a(Agentic::Configuration::ConfigurationInstance)
      expect(config_instance[:name]).to eq("test")
      expect(config_instance[:count]).to eq(1)
      expect(config_instance.valid?).to be true
    end

    it "raises error for invalid configuration" do
      schema.field(:required_field, type: :string, required: true)

      expect { schema.create({}) }
        .to raise_error(described_class::ValidationError)
    end
  end

  describe "documentation generation" do
    it "generates comprehensive documentation" do
      schema.field(:name, type: :string, required: true, description: "The name", example: "test")
      schema.field(:count, type: :integer, default: 1)

      nested_schema = described_class.new("nested")
      schema.nested(:nested, nested_schema)

      schema.computed(:computed_field, dependencies: [:name]) { |c, name| name.upcase }
      schema.validate("Test validation") { |c| true }

      doc = schema.documentation

      expect(doc[:name]).to eq("test_schema")
      expect(doc[:version]).to eq("1.0.0")
      expect(doc[:fields][:name]).to include(type: :string, required: true, description: "The name")
      expect(doc[:nested_schemas][:nested]).to include(schema_name: "nested")
      expect(doc[:computed_fields]).to include(:computed_field)
      expect(doc[:validations]).to include("Test validation")
    end
  end
end

RSpec.describe Agentic::Configuration::ConfigurationInstance do
  let(:schema) do
    Agentic::Configuration::Schema.new("test").tap do |s|
      s.field(:name, type: :string, required: true)
      s.field(:count, type: :integer, default: 10)
      s.field(:metadata, type: :hash, default: {})
    end
  end

  let(:config_data) { {name: "test", count: 5, metadata: {key: "value"}} }
  let(:instance) { described_class.new(config_data, schema) }

  describe "data access" do
    it "provides hash-like access" do
      expect(instance[:name]).to eq("test")
      expect(instance[:count]).to eq(5)
    end

    it "supports get with default" do
      expect(instance.get(:name)).to eq("test")
      expect(instance.get(:nonexistent, "default")).to eq("default")
    end

    it "checks for key existence" do
      expect(instance.key?(:name)).to be true
      expect(instance.key?(:nonexistent)).to be false
    end

    it "provides keys and values" do
      expect(instance.keys).to include(:name, :count, :metadata)
      expect(instance.values).to include("test", 5, {key: "value"})
    end
  end

  describe "data conversion" do
    it "converts to hash" do
      hash = instance.to_h
      expect(hash).to eq(config_data)
      expect(hash).not_to be(instance.data) # Should be a copy
    end

    it "converts to JSON" do
      json = instance.to_json
      expect(JSON.parse(json)).to eq(config_data.stringify_keys)
    end
  end

  describe "merging" do
    it "creates new instance with merged data" do
      new_instance = instance.merge({count: 15, extra: "data"})

      expect(new_instance).to be_a(described_class)
      expect(new_instance[:count]).to eq(15)
      expect(new_instance[:extra]).to eq("data")
      expect(instance[:count]).to eq(5) # Original unchanged
    end
  end

  describe "validation" do
    it "validates current configuration" do
      expect(instance.valid?).to be true
    end
  end
end
