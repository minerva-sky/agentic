# frozen_string_literal: true

require "rgl/adjacency"
require "rgl/traversal"
require "rgl/topsort"

module Agentic
  # Manages graph of artifact relationships using RGL (Ruby Graph Library)
  #
  # ArtifactGraph maintains a directed graph where nodes are artifacts and
  # edges represent "references" relationships. For example, if UserService.rb
  # requires User.rb, there's an edge from UserService -> User.
  #
  # The graph provides:
  # - Dependency resolution (what does X depend on?)
  # - Dependent tracking (what depends on X?)
  # - Circular dependency detection
  # - Topological sorting (build order)
  #
  # @example Building a graph
  #   graph = ArtifactGraph.new
  #   graph.add_node(user_artifact)
  #   graph.add_node(service_artifact) # references user_artifact
  #   deps = graph.dependencies_of(service_artifact) # => [user_artifact]
  #
  # @example Detecting cycles
  #   cycles = graph.detect_cycles
  #   if cycles.any?
  #     puts "Circular dependencies detected!"
  #   end
  class ArtifactGraph
    include Enumerable

    def initialize
      @graph = RGL::DirectedAdjacencyGraph.new
      @artifacts = {} # artifact_name => Artifact object
    end

    # Add an artifact node to the graph
    #
    # Creates a vertex for the artifact and edges for each of its references.
    # If referenced artifacts don't exist yet, vertices are still created for them
    # (they'll be populated when those artifacts are added).
    #
    # Edges are directed as: reference -> artifact (dependency -> dependent)
    # This ensures topological sort returns dependencies before dependents.
    #
    # @param artifact [Artifact] The artifact to add
    # @return [void]
    #
    # @example
    #   artifact = Artifact.new(
    #     name: "service.rb",
    #     type: :ruby_class,
    #     content: "...",
    #     references: ["user.rb"]
    #   )
    #   graph.add_node(artifact)
    def add_node(artifact)
      @artifacts[artifact.name] = artifact
      @graph.add_vertex(artifact.name)

      # Add edges for each reference: ref -> artifact
      # (This means ref must come before artifact in topological sort)
      artifact.references.each do |ref_name|
        # Ensure referenced vertex exists (even if artifact not added yet)
        @graph.add_vertex(ref_name) unless @graph.has_vertex?(ref_name)
        @graph.add_edge(ref_name, artifact.name)
      end
    end

    # Get artifacts that the given artifact depends on (direct dependencies)
    #
    # With edges as ref -> artifact, dependencies are incoming edges.
    #
    # @param artifact [Artifact, String] Artifact object or artifact name
    # @return [Array<Artifact>] Artifacts this one directly references
    #
    # @example
    #   service = graph.find_node(name: "service.rb")
    #   deps = graph.dependencies_of(service) # => [user_artifact]
    def dependencies_of(artifact)
      artifact_name = artifact.is_a?(String) ? artifact : artifact.name
      return [] unless @graph.has_vertex?(artifact_name)

      # Find vertices that have edges pointing TO this artifact (incoming edges)
      @graph.vertices.select { |v| @graph.has_edge?(v, artifact_name) }
        .map { |name| @artifacts[name] }
        .compact
    end

    # Get artifacts that depend on the given artifact (reverse dependencies)
    #
    # With edges as ref -> artifact, dependents are outgoing edges.
    #
    # @param artifact [Artifact, String] Artifact object or artifact name
    # @return [Array<Artifact>] Artifacts that reference this one
    #
    # @example
    #   user = graph.find_node(name: "user.rb")
    #   dependents = graph.dependents_of(user) # => [service_artifact]
    def dependents_of(artifact)
      artifact_name = artifact.is_a?(String) ? artifact : artifact.name
      return [] unless @graph.has_vertex?(artifact_name)

      # Find vertices that this artifact has edges pointing TO (outgoing edges)
      @graph.adjacent_vertices(artifact_name).map { |name| @artifacts[name] }.compact
    end

    # Detect circular dependencies in the graph
    #
    # Attempts to perform topological sort - if it fails or returns fewer vertices
    # than the graph contains, cycles exist.
    #
    # @return [Array<Array<String>>] Arrays of artifact names forming cycles
    #
    # @example
    #   cycles = graph.detect_cycles
    #   if cycles.any?
    #     cycles.each do |cycle|
    #       puts "Cycle: #{cycle.join(' -> ')}"
    #     end
    #   end
    def detect_cycles
      # Try topsort
      sorted = @graph.topsort_iterator.to_a

      # If sorted result has fewer vertices than the graph, there's a cycle
      if sorted.size < @graph.vertices.size
        # Return all vertices as a single cycle (exact cycle determination is complex)
        [@graph.vertices.to_a]
      else
        [] # No cycles
      end
    rescue
      # If topsort fails for any reason, assume cycle
      [@graph.vertices.to_a]
    end

    # Check if graph has circular dependencies
    #
    # @return [Boolean] True if cycles exist
    def has_cycles?
      detect_cycles.any?
    end

    # Get artifacts in topological order (dependencies before dependents)
    #
    # Returns artifacts sorted such that if A depends on B, B appears before A.
    # This is useful for determining build/generation order.
    #
    # @return [Array<Artifact>] Sorted artifacts
    # @raise [CircularDependencyError] If circular dependencies exist
    #
    # @example
    #   sorted = graph.topological_sort
    #   sorted.each { |a| puts "Generate: #{a.name}" }
    def topological_sort
      # Check for cycles first
      cycles = detect_cycles
      if cycles.any?
        raise CircularDependencyError, "Circular dependency detected: #{cycles.first.join(" -> ")}"
      end

      sorted_names = @graph.topsort_iterator.to_a
      sorted_names.map { |name| @artifacts[name] }.compact
    end

    # Find artifact by name and optionally type
    #
    # @param name [String] Artifact name
    # @param type [Symbol, nil] Optional type filter
    # @return [Artifact, nil] Found artifact or nil
    #
    # @example
    #   artifact = graph.find_node(name: "user.rb")
    #   ruby_artifact = graph.find_node(name: "user.rb", type: :ruby_class)
    def find_node(name:, type: nil)
      artifact = @artifacts[name]
      return nil unless artifact
      return artifact if type.nil? || artifact.type == type
      nil
    end

    # Get all artifacts in the graph
    #
    # @return [Array<Artifact>] All artifacts
    def all_nodes
      @artifacts.values
    end

    # Get count of artifacts in graph
    #
    # @return [Integer] Number of artifacts
    def size
      @artifacts.size
    end

    # Check if graph is empty
    #
    # @return [Boolean] True if no artifacts
    def empty?
      @artifacts.empty?
    end

    # Enumerate all artifacts
    #
    # Makes ArtifactGraph work with Enumerable methods like map, select, etc.
    #
    # @yieldparam artifact [Artifact] Each artifact in the graph
    #
    # @example
    #   graph.each { |artifact| puts artifact.name }
    #   ruby_files = graph.select { |a| a.type == :ruby_class }
    def each(&block)
      @artifacts.values.each(&block)
    end

    # String representation of graph
    #
    # @return [String] Human-readable graph description
    def to_s
      "<ArtifactGraph nodes=#{size} edges=#{@graph.edges.size}>"
    end

    # Inspection string for debugging
    #
    # @return [String] Detailed graph information
    def inspect
      artifacts_summary = @artifacts.keys.first(5).join(", ")
      artifacts_summary += ", ..." if @artifacts.size > 5

      "#<Agentic::ArtifactGraph:0x#{object_id.to_s(16)} nodes=#{size} edges=#{@graph.edges.size} artifacts=[#{artifacts_summary}]>"
    end
  end

  # Error raised when circular dependencies are detected in artifact graph
  #
  # @example
  #   begin
  #     sorted = graph.topological_sort
  #   rescue CircularDependencyError => e
  #     puts "Cannot proceed: #{e.message}"
  #   end
  class CircularDependencyError < StandardError; end
end
