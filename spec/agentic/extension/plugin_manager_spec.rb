# frozen_string_literal: true

RSpec.describe Agentic::Extension::PluginManager do
  let(:plugin_manager) { described_class.new(auto_discovery: false) }

  # Create a mock plugin for testing
  let(:valid_plugin) do
    Class.new do
      def initialize_plugin(config = {})
        # Initialize plugin with config
      end

      def call(*args)
        "plugin called with #{args.inspect}"
      end
    end
  end

  # Create an invalid plugin that doesn't match the contract
  let(:invalid_plugin) do
    Class.new do
      def call(*args)
        "plugin called with #{args.inspect}"
      end
    end
  end

  describe "#initialize" do
    it "initializes with default values" do
      manager = described_class.new
      expect(manager.instance_variable_get(:@plugins)).to be_empty
      expect(manager.instance_variable_get(:@hooks)).to be_a(Hash)
      expect(manager.instance_variable_get(:@auto_discovery)).to be true
    end

    it "accepts custom configuration" do
      custom_paths = ["/custom/path"]
      manager = described_class.new(
        auto_discovery: false,
        plugin_paths: custom_paths
      )

      expect(manager.instance_variable_get(:@auto_discovery)).to be false
      expect(manager.instance_variable_get(:@plugin_paths)).to include("/custom/path")
    end
  end

  describe "#register" do
    it "registers a valid plugin" do
      result = plugin_manager.register("test_plugin", valid_plugin.new)
      expect(result).to be true
      expect(plugin_manager.list.keys).to include("test_plugin")
    end

    it "rejects duplicate plugin names" do
      plugin_manager.register("test_plugin", valid_plugin.new)
      result = plugin_manager.register("test_plugin", valid_plugin.new)
      expect(result).to be false
    end

    it "rejects plugins that don't match the contract" do
      result = plugin_manager.register("invalid_plugin", invalid_plugin.new)
      expect(result).to be false
      expect(plugin_manager.list.keys).not_to include("invalid_plugin")
    end

    it "stores plugin metadata" do
      metadata = {version: "1.0.0", author: "Test Author"}
      plugin_manager.register("test_plugin", valid_plugin.new, metadata)

      plugin_data = plugin_manager.list["test_plugin"]
      expect(plugin_data[:metadata][:version]).to eq("1.0.0")
      expect(plugin_data[:metadata][:author]).to eq("Test Author")
      expect(plugin_data[:metadata]).to include(:registered_at)
    end
  end

  describe "#register!" do
    it "overwrites existing plugins" do
      plugin1 = valid_plugin.new
      plugin2 = valid_plugin.new

      plugin_manager.register("test_plugin", plugin1)
      result = plugin_manager.register!("test_plugin", plugin2)

      expect(result).to be true
      expect(plugin_manager.get("test_plugin")).to eq(plugin2)
    end
  end

  describe "#enable and #disable" do
    before do
      plugin_manager.register("test_plugin", valid_plugin.new)
    end

    it "disables a plugin" do
      result = plugin_manager.disable("test_plugin")
      expect(result).to be true
      expect(plugin_manager.get("test_plugin")).to be_nil
      expect(plugin_manager.list["test_plugin"][:enabled]).to be false
    end

    it "enables a disabled plugin" do
      plugin_manager.disable("test_plugin")
      result = plugin_manager.enable("test_plugin")

      expect(result).to be true
      expect(plugin_manager.get("test_plugin")).not_to be_nil
      expect(plugin_manager.list["test_plugin"][:enabled]).to be true
    end

    it "returns false when enabling/disabling non-existent plugins" do
      expect(plugin_manager.enable("non_existent")).to be false
      expect(plugin_manager.disable("non_existent")).to be false
    end
  end

  describe "#get" do
    before do
      plugin_manager.register("test_plugin", valid_plugin.new)
    end

    it "returns a registered plugin" do
      plugin = plugin_manager.get("test_plugin")
      expect(plugin).to be_a(valid_plugin)
    end

    it "returns nil for non-existent plugins" do
      expect(plugin_manager.get("non_existent")).to be_nil
    end

    it "returns nil for disabled plugins" do
      plugin_manager.disable("test_plugin")
      expect(plugin_manager.get("test_plugin")).to be_nil
    end
  end

  describe "#list" do
    before do
      plugin_manager.register("plugin1", valid_plugin.new)
      plugin_manager.register("plugin2", valid_plugin.new)
      plugin_manager.disable("plugin2")
    end

    it "lists all plugins" do
      plugins = plugin_manager.list
      expect(plugins.keys).to contain_exactly("plugin1", "plugin2")
    end

    it "can filter to only enabled plugins" do
      plugins = plugin_manager.list(only_enabled: true)
      expect(plugins.keys).to contain_exactly("plugin1")
    end
  end

  describe "#register_hook" do
    it "registers a callback for an event" do
      callback = proc { |plugin| "Hook called for #{plugin}" }
      result = plugin_manager.register_hook(:after_register, &callback)

      expect(result).to be true
      hooks = plugin_manager.instance_variable_get(:@hooks)
      expect(hooks[:after_register]).to include(callback)
    end

    it "returns false if no callback is provided" do
      result = plugin_manager.register_hook(:after_register)
      expect(result).to be false
    end
  end
end
