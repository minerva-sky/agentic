# frozen_string_literal: true

module Agentic
  # Result object for artifact generation operations
  #
  # Encapsulates the outcome of an artifact generation request, including
  # the generated artifacts, workspace information, and any errors that occurred.
  #
  # @example Successful generation
  #   result = ArtifactGenerationResult.new(
  #     artifacts: [user_artifact, service_artifact],
  #     workspace: workspace,
  #     success: true
  #   )
  #   result.successful? # => true
  #   result.artifacts   # => [user_artifact, service_artifact]
  #
  # @example Failed generation
  #   result = ArtifactGenerationResult.new(
  #     artifacts: [],
  #     workspace: workspace,
  #     success: false,
  #     errors: ["Failed to parse LLM response"]
  #   )
  #   result.successful? # => false
  #   result.errors      # => ["Failed to parse LLM response"]
  class ArtifactGenerationResult
    # @return [Array<Artifact>] Generated artifacts
    attr_reader :artifacts

    # @return [Workspace] Workspace where artifacts were generated
    attr_reader :workspace

    # @return [Boolean] Whether generation was successful
    attr_reader :success

    # @return [Array<String>] Error messages if generation failed
    attr_reader :errors

    # @return [Hash] Additional metadata about the generation
    attr_reader :metadata

    # Initialize a new generation result
    #
    # @param artifacts [Array<Artifact>] Generated artifacts (default: [])
    # @param workspace [Workspace] Workspace instance
    # @param success [Boolean] Whether generation succeeded
    # @param errors [Array<String>] Error messages (default: [])
    # @param metadata [Hash] Additional metadata (default: {})
    def initialize(artifacts: [], workspace: nil, success: true, errors: [], metadata: {})
      @artifacts = artifacts || []
      @workspace = workspace
      @success = success
      @errors = errors || []
      @metadata = metadata || {}
    end

    # Check if the generation was successful
    #
    # @return [Boolean] True if success flag is true and no errors
    def successful?
      @success && @errors.empty?
    end

    # Check if the generation failed
    #
    # @return [Boolean] True if not successful
    def failed?
      !successful?
    end

    # Get the count of generated artifacts
    #
    # @return [Integer] Number of artifacts
    def artifact_count
      @artifacts.size
    end

    # Check if any artifacts were generated
    #
    # @return [Boolean] True if artifacts array is not empty
    def has_artifacts?
      @artifacts.any?
    end

    # Get workspace ID if workspace is present
    #
    # @return [String, nil] Workspace ID or nil
    def workspace_id
      @workspace&.id
    end

    # Get workspace path if workspace is present
    #
    # @return [String, nil] Workspace path or nil
    def workspace_path
      @workspace&.path
    end

    # Convert to hash for serialization
    #
    # @return [Hash] Result as hash with all details
    def to_h
      {
        success: @success,
        artifacts: @artifacts.map(&:to_h),
        artifact_count: artifact_count,
        workspace_id: workspace_id,
        workspace_path: workspace_path,
        errors: @errors,
        metadata: @metadata
      }
    end

    # String representation
    #
    # @return [String] Human-readable result description
    def to_s
      status = successful? ? "success" : "failed"
      "<ArtifactGenerationResult status=#{status} artifacts=#{artifact_count}>"
    end

    # Inspection string for debugging
    #
    # @return [String] Detailed result information
    def inspect
      "#<Agentic::ArtifactGenerationResult:0x#{object_id.to_s(16)} " \
        "success=#{@success} artifacts=#{artifact_count} errors=#{@errors.size}>"
    end

    # Create a successful result
    #
    # @param artifacts [Array<Artifact>] Generated artifacts
    # @param workspace [Workspace] Workspace instance
    # @param metadata [Hash] Additional metadata
    # @return [ArtifactGenerationResult] Successful result
    def self.success(artifacts:, workspace:, metadata: {})
      new(
        artifacts: artifacts,
        workspace: workspace,
        success: true,
        errors: [],
        metadata: metadata
      )
    end

    # Create a failed result
    #
    # @param errors [Array<String>] Error messages
    # @param workspace [Workspace, nil] Workspace instance
    # @param artifacts [Array<Artifact>] Any partial artifacts generated
    # @param metadata [Hash] Additional metadata
    # @return [ArtifactGenerationResult] Failed result
    def self.failure(errors:, workspace: nil, artifacts: [], metadata: {})
      new(
        artifacts: artifacts,
        workspace: workspace,
        success: false,
        errors: Array(errors),
        metadata: metadata
      )
    end
  end
end
