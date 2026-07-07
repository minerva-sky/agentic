# frozen_string_literal: true

module Agentic
  # Defines the specification for an agent capability
  # @attr_reader [String] name The name of the capability
  # @attr_reader [String] description Description of the capability
  # @attr_reader [String] version The version of the capability
  # @attr_reader [Hash] inputs The required inputs for the capability
  # @attr_reader [Hash] outputs The expected outputs from the capability
  # @attr_reader [Array<Hash>] dependencies The dependencies of the capability
  class CapabilitySpecification
    attr_reader :name, :description, :version, :inputs, :outputs, :dependencies

    # Initialize a new capability specification
    # @param name [String] The name of the capability
    # @param description [String] Description of the capability
    # @param version [String] The version of the capability
    # @param inputs [Hash] The required inputs for the capability
    # @param outputs [Hash] The expected outputs from the capability
    # @param dependencies [Array<Hash>] The dependencies of the capability
    def initialize(name:, description:, version:, inputs: {}, outputs: {}, dependencies: [], rules: {})
      @name = name
      @description = description
      @version = version
      @inputs = inputs
      @outputs = outputs
      @dependencies = dependencies
      @rules = rules
    end

    # Cross-field input rules: description => predicate over the full
    # (symbolized) inputs hash. Checked after per-key validation passes:
    #
    #   rules: {"express orders max 10 items" => ->(i) { i[:speed] != "express" || i[:quantity] <= 10 }}
    #
    # @return [Hash{String=>#call}]
    attr_reader :rules

    # Check if this capability is compatible with another capability
    # @param other [CapabilitySpecification] The other capability
    # @return [Boolean] True if compatible
    def compatible_with?(other)
      return false unless other.is_a?(CapabilitySpecification)
      return false unless name == other.name

      # Compare versions using semantic versioning rules
      # For now, just check for exact match or higher minor version
      return true if version == other.version

      begin
        my_parts = version.split(".").map(&:to_i)
        other_parts = other.version.split(".").map(&:to_i)

        # Major version must match
        return false unless my_parts[0] == other_parts[0]

        # Our minor version should be >= other's minor version
        my_parts[1] >= other_parts[1]
      rescue
        # If version parsing fails, require exact match
        false
      end
    end

    # Convert to a hash representation
    # @return [Hash] The hash representation
    def to_h
      {
        name: @name,
        description: @description,
        version: @version,
        inputs: @inputs,
        outputs: @outputs,
        dependencies: @dependencies
      }
    end

    # Create from a hash representation
    # @param hash [Hash] The hash representation
    # @return [CapabilitySpecification] The capability specification
    def self.from_h(hash)
      new(
        name: hash[:name] || hash["name"],
        description: hash[:description] || hash["description"],
        version: hash[:version] || hash["version"],
        inputs: hash[:inputs] || hash["inputs"] || {},
        outputs: hash[:outputs] || hash["outputs"] || {},
        dependencies: hash[:dependencies] || hash["dependencies"] || []
      )
    end

    # Emits the declared contract as a JSON Schema object, so capability
    # contracts plug into OpenAPI tooling, JSON validators, and every
    # schema-aware toolchain without a bespoke exporter
    # @param side [Symbol] :inputs or :outputs
    # @return [Hash] A JSON Schema (draft-07 compatible) as a plain hash
    def to_json_schema(side = :inputs)
      declared = (side == :outputs) ? outputs : inputs

      properties = declared.to_h do |name, decl|
        schema = {}
        schema["type"] = JSON_SCHEMA_TYPES.fetch(decl[:type], nil) if decl[:type]
        schema.delete("type") if schema["type"].nil?
        schema["description"] = decl[:description] if decl[:description]
        schema["enum"] = decl[:enum] if decl[:enum]
        schema["minimum"] = decl[:min] if decl[:min]
        schema["maximum"] = decl[:max] if decl[:max]
        if decl[:non_empty]
          schema[(decl[:type] == "array") ? "minItems" : "minLength"] = 1
        end
        [name.to_s, schema]
      end

      schema = {
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "title" => "#{name} #{side}",
        "type" => "object",
        "required" => declared.select { |_, decl| decl[:required] }.keys.map(&:to_s),
        "properties" => properties,
        "additionalProperties" => true
      }

      # Cross-field rules are lambdas and cannot project into JSON Schema
      # keywords, but structured rules carry declarable metadata - emit it
      # as an extension so schema consumers can at least SEE the policies
      if side == :inputs && !rules.empty?
        structured = rules.filter_map do |key, definition|
          next if definition.respond_to?(:call)

          {"rule" => key.to_s, "message" => definition[:message] || key.to_s,
           "fields" => (definition[:fields] || []).map(&:to_s)}
        end
        schema["x-agentic-rules"] = structured unless structured.empty?
      end

      schema
    end

    # Contract type names to JSON Schema type names
    JSON_SCHEMA_TYPES = {
      "string" => "string",
      "number" => "number",
      "integer" => "integer",
      "boolean" => "boolean",
      "array" => "array",
      "object" => "object",
      "hash" => "object"
    }.freeze

    # Get the capability requirements as a human-readable string
    # @return [String] The capability requirements
    def requirements_description
      result = "Capability: #{name} (v#{version})\n"
      result += "Description: #{description}\n"

      unless inputs.empty?
        result += "\nInputs:\n"
        inputs.each do |name, spec|
          result += "  #{name}: #{spec[:type] || "any"}"
          result += " (required)" if spec[:required]
          result += " - #{spec[:description]}" if spec[:description]
          result += "\n"
        end
      end

      unless outputs.empty?
        result += "\nOutputs:\n"
        outputs.each do |name, spec|
          result += "  #{name}: #{spec[:type] || "any"}"
          result += " - #{spec[:description]}" if spec[:description]
          result += "\n"
        end
      end

      unless dependencies.empty?
        result += "\nDependencies:\n"
        dependencies.each do |dep|
          result += "  #{dep[:name]} (v#{dep[:version] || "any"})\n"
        end
      end

      result
    end
  end
end
