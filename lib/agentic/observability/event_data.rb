# frozen_string_literal: true

module Agentic
  module Observability
    # Standardized event structure for all observability events
    class EventData
      attr_reader :type, :timestamp, :source, :data, :metadata

      def initialize(type:, data: {}, source: nil, metadata: {})
        @type = type.to_sym
        @timestamp = Time.now.iso8601
        @source = source
        @data = data || {}
        @metadata = metadata || {}
      end

      def to_h
        {
          type: @type,
          timestamp: @timestamp,
          source: format_source(@source),
          data: @data,
          metadata: @metadata
        }
      end

      private

      def format_source(source)
        return "unknown" if source.nil?
        source.class.name
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def ==(other)
        return false unless other.is_a?(EventData)

        type == other.type &&
          source == other.source &&
          data == other.data &&
          metadata == other.metadata
      end
    end
  end
end
