# frozen_string_literal: true

require "securerandom"
require "json"

module Agentic
  module Observability
    # EventContext provides hierarchical correlation and tracing capabilities for
    # multi-agent orchestration workflows. It enables sophisticated tracking of
    # events across parent-child agent relationships, task dependencies, and
    # complex workflow stages.
    #
    # Design Goals:
    # 1. Support complex agent orchestration patterns with parent-child relationships
    # 2. Enable distributed tracing across agent boundaries and async operations
    # 3. Provide extensible metadata system for domain-specific requirements
    # 4. Support serialization for distributed agent systems
    # 5. Enable efficient correlation and lookup across large workflows
    #
    # Architect Team Guidance:
    # - Jamie Chen (Domain Expert): Agent hierarchy tracking and workflow stage correlation
    # - Taylor Kim (Agent Systems Engineer): Plugin architecture and extensibility patterns
    class EventContext
      # Context types for different orchestration patterns
      TYPE_WORKFLOW = :workflow        # Overall workflow coordination
      TYPE_PLAN = :plan               # Plan execution context
      TYPE_TASK = :task               # Individual task context
      TYPE_AGENT = :agent             # Agent-specific context
      TYPE_CAPABILITY = :capability    # Capability execution context
      TYPE_VERIFICATION = :verification # Verification process context

      # Context states for lifecycle management
      STATE_CREATED = :created
      STATE_ACTIVE = :active
      STATE_SUSPENDED = :suspended
      STATE_COMPLETED = :completed
      STATE_FAILED = :failed
      STATE_ARCHIVED = :archived

      attr_reader :correlation_id, :context_id, :parent_context, :context_type, :state
      attr_reader :created_at, :updated_at, :metadata, :tags, :hierarchy_path
      attr_accessor :name, :description

      # Create a new EventContext
      # @param correlation_id [String] Correlation ID for grouping related contexts
      # @param context_type [Symbol] Type of context (workflow, task, agent, etc.)
      # @param name [String] Human-readable name for the context
      # @param parent_context [EventContext, nil] Parent context for hierarchy
      # @param metadata [Hash] Initial metadata for the context
      # @param tags [Array<String>] Tags for categorization and filtering
      def initialize(correlation_id: nil, context_type: TYPE_WORKFLOW, name: nil,
        parent_context: nil, metadata: {}, tags: [])
        @context_id = SecureRandom.uuid
        @correlation_id = correlation_id || parent_context&.correlation_id || SecureRandom.uuid
        @context_type = context_type
        @name = name || "#{context_type}_#{@context_id[0..7]}"
        @description = nil
        @parent_context = parent_context
        @state = STATE_CREATED

        # Hierarchical tracking
        @hierarchy_path = build_hierarchy_path
        @depth = @hierarchy_path.size - 1
        @child_contexts = []

        # Metadata and extensibility
        # Stringify keys to ensure consistent access via get_metadata
        @metadata = metadata.transform_keys(&:to_s)
        @tags = Array(tags).dup
        @extensions = {}

        # Lifecycle tracking
        @created_at = Time.now.to_f
        @updated_at = @created_at
        @state_history = [{state: STATE_CREATED, timestamp: @created_at, metadata: {}}]

        # Performance tracking
        @metrics = initialize_metrics

        # Register with parent if provided
        @parent_context&.add_child(self)

        Agentic.logger&.debug("Created EventContext #{@context_id} (#{@context_type})")
      end

      # Create a child context
      # @param context_type [Symbol] Type of child context
      # @param name [String] Name for the child context
      # @param metadata [Hash] Metadata for the child context
      # @param tags [Array<String>] Tags for the child context
      # @return [EventContext] New child context
      def create_child(context_type:, name: nil, metadata: {}, tags: [])
        child = self.class.new(
          correlation_id: @correlation_id,
          context_type: context_type,
          name: name,
          parent_context: self,
          metadata: metadata,
          tags: tags
        )

        child.activate if @state == STATE_ACTIVE
        child
      end

      # Add a child context (used internally)
      # @param child_context [EventContext] Child context to add
      def add_child(child_context)
        @child_contexts << child_context unless @child_contexts.include?(child_context)
        touch
      end

      # Remove a child context
      # @param child_context [EventContext] Child context to remove
      def remove_child(child_context)
        @child_contexts.delete(child_context)
        touch
      end

      # Get all child contexts
      # @param recursive [Boolean] Whether to include grandchildren
      # @return [Array<EventContext>] Child contexts
      def children(recursive: false)
        if recursive
          @child_contexts + @child_contexts.flat_map { |child| child.children(recursive: true) }
        else
          @child_contexts.dup
        end
      end

      # Get all sibling contexts
      # @return [Array<EventContext>] Sibling contexts
      def siblings
        return [] unless @parent_context

        @parent_context.children.reject { |child| child == self }
      end

      # Get root context (top of hierarchy)
      # @return [EventContext] Root context
      def root
        current = self
        current = current.parent_context while current.parent_context
        current
      end

      # Check if this context is an ancestor of another context
      # @param other_context [EventContext] Context to check
      # @return [Boolean] True if this is an ancestor
      def ancestor_of?(other_context)
        other_context.hierarchy_path.include?(@context_id)
      end

      # Check if this context is a descendant of another context
      # @param other_context [EventContext] Context to check
      # @return [Boolean] True if this is a descendant
      def descendant_of?(other_context)
        other_context.ancestor_of?(self)
      end

      # Get context depth in hierarchy
      # @return [Integer] Depth (0 for root context)
      attr_reader :depth

      # Activate the context (transition to active state)
      def activate
        transition_to_state(STATE_ACTIVE)

        # Activate child contexts as well
        @child_contexts.each(&:activate)
      end

      # Suspend the context (pause execution)
      def suspend
        transition_to_state(STATE_SUSPENDED)
      end

      # Resume suspended context
      def resume
        return unless @state == STATE_SUSPENDED

        transition_to_state(STATE_ACTIVE)
      end

      # Complete the context (successful completion)
      # @param metadata [Hash] Completion metadata
      def complete(metadata: {})
        transition_to_state(STATE_COMPLETED, metadata: metadata)

        # Complete child contexts as well
        @child_contexts.each { |child| child.complete unless child.completed? }
      end

      # Fail the context (unsuccessful completion)
      # @param metadata [Hash] Failure metadata (error details, etc.)
      def fail(metadata: {})
        transition_to_state(STATE_FAILED, metadata: metadata)

        # Optionally fail child contexts (configurable behavior)
        if metadata[:fail_children] != false
          @child_contexts.each { |child| child.fail unless child.terminal_state? }
        end
      end

      # Archive the context (move to archived state)
      def archive
        transition_to_state(STATE_ARCHIVED)
      end

      # State predicate methods
      def created?
        @state == STATE_CREATED
      end

      def active?
        @state == STATE_ACTIVE
      end

      def suspended?
        @state == STATE_SUSPENDED
      end

      def completed?
        @state == STATE_COMPLETED
      end

      def failed?
        @state == STATE_FAILED
      end

      def archived?
        @state == STATE_ARCHIVED
      end

      def terminal_state?
        completed? || failed? || archived?
      end

      # Metadata management
      def get_metadata(key, default: nil)
        @metadata.fetch(key.to_s, default)
      end

      def set_metadata(key, value)
        @metadata[key.to_s] = value
        touch
      end

      def merge_metadata(new_metadata)
        @metadata.merge!(new_metadata.transform_keys(&:to_s))
        touch
      end

      def delete_metadata(key)
        @metadata.delete(key.to_s)
        touch
      end

      # Tag management
      def has_tag?(tag)
        @tags.include?(tag.to_s)
      end

      def add_tag(tag)
        tag_str = tag.to_s
        @tags << tag_str unless @tags.include?(tag_str)
        touch
      end

      def add_tags(*tags)
        tags.flatten.each { |tag| add_tag(tag) }
      end

      def remove_tag(tag)
        @tags.delete(tag.to_s)
        touch
      end

      def clear_tags
        @tags.clear
        touch
      end

      # Extension system for domain-specific capabilities
      def register_extension(name, extension_object)
        @extensions[name.to_s] = extension_object
        touch
      end

      def get_extension(name)
        @extensions[name.to_s]
      end

      def has_extension?(name)
        @extensions.key?(name.to_s)
      end

      def remove_extension(name)
        @extensions.delete(name.to_s)
        touch
      end

      # Metrics and performance tracking
      def record_metric(name, value, timestamp: Time.now.to_f)
        @metrics[:custom][name.to_s] ||= []
        @metrics[:custom][name.to_s] << {value: value, timestamp: timestamp}

        # Keep metrics manageable (last 100 entries per metric)
        @metrics[:custom][name.to_s] = @metrics[:custom][name.to_s].last(100)

        touch
      end

      def get_metric(name)
        @metrics[:custom][name.to_s] || []
      end

      def get_latest_metric(name)
        metric_data = get_metric(name)
        metric_data.last&.dig(:value)
      end

      # Performance metrics
      def duration
        return nil unless terminal_state?

        completion_time = @state_history.last[:timestamp]
        completion_time - @created_at
      end

      def time_in_state(state)
        state_entries = @state_history.select { |entry| entry[:state] == state }
        return 0 if state_entries.empty?

        total_time = 0
        state_entries.each_with_index do |entry, index|
          start_time = entry[:timestamp]
          end_time = if index == state_entries.size - 1 && @state == state
            Time.now.to_f
          elsif index < state_entries.size - 1
            state_entries[index + 1][:timestamp]
          else
            @state_history.find { |h| h[:timestamp] > start_time }&.dig(:timestamp) || Time.now.to_f
          end

          total_time += end_time - start_time
        end

        total_time
      end

      # Context queries and filtering
      def find_children_by_type(context_type)
        children.select { |child| child.context_type == context_type }
      end

      def find_children_by_tag(tag)
        children.select { |child| child.has_tag?(tag) }
      end

      def find_children_by_state(state)
        children.select { |child| child.state == state }
      end

      def find_descendant_by_id(context_id)
        return self if @context_id == context_id

        children(recursive: true).find { |child| child.context_id == context_id }
      end

      # Serialization for distributed systems
      def to_hash(include_children: false)
        hash = {
          context_id: @context_id,
          correlation_id: @correlation_id,
          context_type: @context_type,
          name: @name,
          description: @description,
          state: @state,
          hierarchy_path: @hierarchy_path,
          depth: @depth,
          created_at: @created_at,
          updated_at: @updated_at,
          metadata: @metadata,
          tags: @tags,
          extensions: @extensions.keys, # Don't serialize extension objects
          metrics: @metrics,
          state_history: @state_history
        }

        hash[:children] = @child_contexts.map { |child| child.to_hash(include_children: true) } if include_children
        hash[:parent_context_id] = @parent_context.context_id if @parent_context

        hash
      end

      def to_json(include_children: false)
        JSON.pretty_generate(to_hash(include_children: include_children))
      end

      # Create context from serialized data
      def self.from_hash(hash, parent_context: nil)
        context = allocate
        context.instance_variable_set(:@context_id, hash[:context_id])
        context.instance_variable_set(:@correlation_id, hash[:correlation_id])
        context.instance_variable_set(:@context_type, hash[:context_type])
        context.instance_variable_set(:@name, hash[:name])
        context.instance_variable_set(:@description, hash[:description])
        context.instance_variable_set(:@state, hash[:state])
        context.instance_variable_set(:@hierarchy_path, hash[:hierarchy_path])
        context.instance_variable_set(:@depth, hash[:depth])
        context.instance_variable_set(:@created_at, hash[:created_at])
        context.instance_variable_set(:@updated_at, hash[:updated_at])
        context.instance_variable_set(:@metadata, hash[:metadata])
        context.instance_variable_set(:@tags, hash[:tags])
        context.instance_variable_set(:@extensions, {})
        context.instance_variable_set(:@metrics, hash[:metrics])
        context.instance_variable_set(:@state_history, hash[:state_history])
        context.instance_variable_set(:@parent_context, parent_context)
        context.instance_variable_set(:@child_contexts, [])

        # Reconstruct child contexts if present
        hash[:children]&.each do |child_hash|
          child_context = from_hash(child_hash, parent_context: context)
          context.add_child(child_context)
        end

        context
      end

      def self.from_json(json_string, parent_context: nil)
        hash = JSON.parse(json_string, symbolize_names: true)
        from_hash(hash, parent_context: parent_context)
      end

      # Context inspection and debugging
      def inspect
        "#<#{self.class.name}:#{object_id} id=#{@context_id[0..7]} type=#{@context_type} state=#{@state} children=#{@child_contexts.size}>"
      end

      def pretty_print
        lines = []
        lines << "EventContext: #{@name} (#{@context_id[0..7]})"
        lines << "  Type: #{@context_type}"
        lines << "  State: #{@state}"
        lines << "  Correlation: #{@correlation_id[0..7]}"
        lines << "  Hierarchy: #{@hierarchy_path.map { |id| id[0..7] }.join(" -> ")}"
        lines << "  Created: #{Time.at(@created_at).strftime("%Y-%m-%d %H:%M:%S")}"
        lines << "  Updated: #{Time.at(@updated_at).strftime("%Y-%m-%d %H:%M:%S")}"
        lines << "  Tags: [#{@tags.join(", ")}]" unless @tags.empty?
        lines << "  Extensions: [#{@extensions.keys.join(", ")}]" unless @extensions.empty?
        lines << "  Children: #{@child_contexts.size}"

        if @child_contexts.any?
          @child_contexts.each do |child|
            child_lines = child.pretty_print.split("\n")
            lines << "    #{child_lines.first}"
          end
        end

        lines.join("\n")
      end

      # Context tree visualization
      def print_tree(indent: 0, show_details: false)
        prefix = "  " * indent
        details = show_details ? " [#{@state}, #{@tags.join(",")}]" : ""

        puts "#{prefix}#{@name} (#{@context_type})#{details}"

        @child_contexts.each do |child|
          child.print_tree(indent: indent + 1, show_details: show_details)
        end
      end

      private

      # Build hierarchy path from root to current context
      def build_hierarchy_path
        path = []
        current = self

        while current
          path.unshift(current.context_id)
          current = current.parent_context
        end

        path
      end

      # Initialize metrics structure
      def initialize_metrics
        {
          system: {
            state_transitions: 0,
            child_contexts_created: 0,
            metadata_updates: 0
          },
          custom: {}
        }
      end

      # Transition to a new state
      def transition_to_state(new_state, metadata: {})
        return if @state == new_state

        old_state = @state
        @state = new_state
        @updated_at = Time.now.to_f

        # Record state transition
        @state_history << {
          state: new_state,
          timestamp: @updated_at,
          metadata: metadata,
          previous_state: old_state
        }

        @metrics[:system][:state_transitions] += 1

        Agentic.logger&.debug("EventContext #{@context_id[0..7]} transitioned #{old_state} -> #{new_state}")
      end

      # Update the updated_at timestamp
      def touch
        @updated_at = Time.now.to_f
        @metrics[:system][:metadata_updates] += 1
      end
    end

    # Context registry for efficient lookup and management
    class EventContextRegistry
      def initialize
        @contexts = {}
        @correlation_index = {}
        @type_index = {}
        @tag_index = {}
        @mutex = Mutex.new
      end

      # Register a context
      def register(context)
        @mutex.synchronize do
          @contexts[context.context_id] = context

          # Update indices
          correlation_contexts = @correlation_index[context.correlation_id] ||= []
          correlation_contexts << context unless correlation_contexts.include?(context)

          type_contexts = @type_index[context.context_type] ||= []
          type_contexts << context unless type_contexts.include?(context)

          context.tags.each do |tag|
            tag_contexts = @tag_index[tag] ||= []
            tag_contexts << context unless tag_contexts.include?(context)
          end
        end
      end

      # Unregister a context
      def unregister(context_id)
        @mutex.synchronize do
          context = @contexts.delete(context_id)
          return nil unless context

          # Clean up indices
          @correlation_index[context.correlation_id]&.delete(context)
          @type_index[context.context_type]&.delete(context)
          context.tags.each { |tag| @tag_index[tag]&.delete(context) }

          context
        end
      end

      # Find context by ID
      def find(context_id)
        @contexts[context_id]
      end

      # Find contexts by correlation ID
      def find_by_correlation(correlation_id)
        @correlation_index[correlation_id] || []
      end

      # Find contexts by type
      def find_by_type(context_type)
        @type_index[context_type] || []
      end

      # Find contexts by tag
      def find_by_tag(tag)
        @tag_index[tag] || []
      end

      # Get all registered contexts
      def all
        @contexts.values
      end

      # Get registry statistics
      def statistics
        @mutex.synchronize do
          {
            total_contexts: @contexts.size,
            correlations: @correlation_index.size,
            types: @type_index.keys,
            tags: @tag_index.keys.size
          }
        end
      end

      # Clean up completed/failed contexts older than specified age
      def cleanup(max_age_seconds: 3600)
        cutoff_time = Time.now.to_f - max_age_seconds

        contexts_to_remove = @contexts.values.select do |context|
          context.terminal_state? && context.updated_at < cutoff_time
        end

        contexts_to_remove.each { |context| unregister(context.context_id) }

        contexts_to_remove.size
      end
    end
  end
end
