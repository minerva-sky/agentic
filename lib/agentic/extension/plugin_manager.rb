# frozen_string_literal: true

module Agentic
  module Extension
    # The PluginManager coordinates third-party extension loading, registration,
    # and lifecycle management. It provides a central registry for all extensions
    # and ensures they conform to the extension contracts.
    class PluginManager
      # Initialize a new PluginManager
      #
      # @param [Hash] options Configuration options for the plugin manager
      # @option options [Logger] :logger Custom logger instance
      # @option options [Boolean] :auto_discovery Whether to automatically discover plugins
      # @option options [Array<String>] :plugin_paths Additional paths to search for plugins
      def initialize(options = {})
        @logger = options[:logger] || Agentic.logger
        @auto_discovery = options.fetch(:auto_discovery, true)
        @plugin_paths = options[:plugin_paths] || []
        @plugin_paths << default_plugin_path
        @plugins = {}
        @hooks = Hash.new { |h, k| h[k] = [] }

        discover_plugins if @auto_discovery
      end

      # Register a plugin with the manager
      #
      # @param [String] name The unique name of the plugin
      # @param [Object] plugin The plugin instance
      # @param [Hash] metadata Additional information about the plugin
      # @return [Boolean] True if registration was successful
      def register(name, plugin, metadata = {})
        if @plugins.key?(name)
          @logger.warn("Plugin '#{name}' is already registered. Use force: true to override.")
          return false
        end

        unless valid_plugin?(plugin)
          @logger.error("Plugin '#{name}' does not conform to the plugin contract")
          return false
        end

        @plugins[name] = {
          instance: plugin,
          metadata: metadata.merge(registered_at: Time.now),
          enabled: true
        }

        @logger.info("Plugin '#{name}' registered successfully")
        true
      end

      # Register a plugin with the manager, overriding any existing plugin with the same name
      #
      # @param [String] name The unique name of the plugin
      # @param [Object] plugin The plugin instance
      # @param [Hash] metadata Additional information about the plugin
      # @return [Boolean] True if registration was successful
      def register!(name, plugin, metadata = {})
        @plugins.delete(name) if @plugins.key?(name)
        register(name, plugin, metadata)
      end

      # Enable a registered plugin
      #
      # @param [String] name The name of the plugin to enable
      # @return [Boolean] True if the plugin was enabled
      def enable(name)
        return false unless @plugins.key?(name)

        @plugins[name][:enabled] = true
        @logger.info("Plugin '#{name}' enabled")
        true
      end

      # Disable a registered plugin
      #
      # @param [String] name The name of the plugin to disable
      # @return [Boolean] True if the plugin was disabled
      def disable(name)
        return false unless @plugins.key?(name)

        @plugins[name][:enabled] = false
        @logger.info("Plugin '#{name}' disabled")
        true
      end

      # Get a registered plugin by name
      #
      # @param [String] name The name of the plugin to retrieve
      # @return [Object, nil] The plugin or nil if not found or disabled
      def get(name)
        return nil unless @plugins.key?(name) && @plugins[name][:enabled]

        @plugins[name][:instance]
      end

      # List all registered plugins
      #
      # @param [Boolean] only_enabled Only return enabled plugins
      # @return [Hash] A hash of all registered plugins and their metadata
      def list(only_enabled: false)
        if only_enabled
          @plugins.select { |_, data| data[:enabled] }
        else
          @plugins
        end
      end

      # Register a hook for plugin events
      #
      # @param [Symbol] event The event to hook into (:after_register, :before_enable, :after_enable, :before_disable, :after_disable)
      # @yield [name, plugin] The callback to execute when the event occurs
      # @yieldparam [String] name The name of the plugin
      # @yieldparam [Object] plugin The plugin instance
      # @return [Boolean] True if the hook was registered
      def register_hook(event, &callback)
        return false unless callback

        @hooks[event] << callback
        true
      end

      # Discover plugins in configured paths
      #
      # @return [Integer] The number of plugins discovered
      def discover_plugins
        return 0 unless @auto_discovery

        discovered = 0
        @plugin_paths.each do |path|
          Dir.glob(File.join(path, "*.rb")).each do |file|
            require file
            discovered += 1
          rescue => e
            @logger.error("Failed to load plugin from #{file}: #{e.message}")
          end
        end

        @logger.info("Discovered #{discovered} plugins")
        discovered
      end

      private

      # Get the default plugin path
      #
      # @return [String] The default path for plugins
      def default_plugin_path
        File.join(File.dirname(__FILE__), "../../../plugins")
      end

      # Check if a plugin conforms to the plugin contract
      #
      # @param [Object] plugin The plugin to validate
      # @return [Boolean] True if the plugin is valid
      def valid_plugin?(plugin)
        # Check that the plugin implements both required methods
        plugin.respond_to?(:initialize_plugin) && plugin.respond_to?(:call)
      end
    end
  end
end
