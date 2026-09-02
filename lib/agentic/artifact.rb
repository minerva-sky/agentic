# frozen_string_literal: true

module Agentic
  # Represents a generated file artifact with metadata and references
  #
  # An artifact encapsulates generated content (typically a file) along with
  # metadata about its type, relationships to other artifacts, and creation info.
  #
  # @example Creating a Ruby class artifact
  #   artifact = Artifact.new(
  #     name: "user.rb",
  #     type: :ruby_class,
  #     content: "class User\n  attr_accessor :name\nend",
  #     references: []
  #   )
  #
  # @example Creating an artifact that references another
  #   service = Artifact.new(
  #     name: "user_service.rb",
  #     type: :ruby_class,
  #     content: "require_relative 'user'\n\nclass UserService\nend",
  #     references: ["user.rb"]
  #   )
  class Artifact
    # @return [String] Filename (relative path within workspace)
    attr_reader :name

    # @return [Symbol] Artifact type (:ruby_class, :javascript_module, etc.)
    attr_reader :type

    # @return [String] File content
    attr_reader :content

    # @return [Array<String>] Names of artifacts this one references
    attr_reader :references

    # @return [Hash] Additional metadata
    attr_reader :metadata

    # @return [Time] Creation timestamp
    attr_reader :created_at

    # Initialize a new artifact
    #
    # @param name [String] Filename (relative path within workspace)
    # @param type [Symbol] Artifact type
    # @param content [String] File content
    # @param references [Array<String>] Names of artifacts this one references
    # @param metadata [Hash] Additional metadata
    def initialize(name:, type:, content:, references: [], metadata: {})
      @name = name
      @type = type
      @content = content
      @references = references
      @metadata = metadata
      @created_at = Time.now
    end

    # Automatically detect references from content based on artifact type
    #
    # Analyzes the content string to extract references to other files/modules
    # based on the programming language conventions.
    #
    # @param content [String] File content to analyze
    # @param type [Symbol] Artifact type
    # @return [Array<String>] Detected references
    #
    # @example Detecting Ruby requires
    #   Artifact.detect_references(
    #     "require_relative 'user'\nrequire_relative 'config'",
    #     :ruby_class
    #   )
    #   # => ["user", "config"]
    def self.detect_references(content, type)
      case type
      when :ruby_class
        extract_ruby_requires(content)
      when :javascript_module
        extract_js_imports(content)
      when :python_module
        extract_python_imports(content)
      else
        []
      end
    end

    # Convert artifact to hash for serialization
    #
    # @return [Hash] Artifact as hash with string keys
    def to_h
      {
        name: @name,
        type: @type,
        content: @content,
        references: @references,
        metadata: @metadata,
        created_at: @created_at.iso8601
      }
    end

    # String representation of artifact
    #
    # @return [String] Human-readable artifact description
    def to_s
      "<Artifact name=#{@name} type=#{@type} references=#{@references.size}>"
    end

    # Inspection string for debugging
    #
    # @return [String] Detailed artifact information
    def inspect
      "#<Agentic::Artifact:0x#{object_id.to_s(16)} name=\"#{@name}\" type=#{@type} size=#{@content.bytesize} references=#{@references.inspect}>"
    end

    private_class_method def self.extract_ruby_requires(content)
      # Match require_relative 'filename' or require_relative "filename"
      matches = content.scan(/require_relative\s+['"]([^'"]+)['"]/)
      matches.flatten.uniq
    end

    private_class_method def self.extract_js_imports(content)
      # Match import ... from 'filename' or import ... from "filename"
      matches = content.scan(/import\s+.+\s+from\s+['"]([^'"]+)['"]/)
      matches.flatten.uniq
    end

    private_class_method def self.extract_python_imports(content)
      # Match from module import or import module
      from_imports = content.scan(/from\s+(\S+)\s+import/).flatten
      direct_imports = content.scan(/^import\s+(\S+)/).flatten
      (from_imports + direct_imports).uniq
    end
  end
end
