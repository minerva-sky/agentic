# Agentic Plugins

This directory contains plugins for the Agentic framework. Plugins provide additional functionality that can be loaded by the `Agentic::Extension::PluginManager`.

## Creating a Plugin

A valid plugin must implement the following interface:

```ruby
class ExamplePlugin
  # Initialize the plugin with configuration options
  def initialize_plugin(config = {})
    # Initialize plugin with config
  end
  
  # Execute the plugin functionality
  def call(*args)
    # Plugin functionality
  end
end
```

## Loading Plugins

Plugins in this directory are automatically discovered and loaded by the `PluginManager` if auto-discovery is enabled (which is the default behavior).

You can also manually register plugins:

```ruby
plugin_manager = Agentic::Extension.plugin_manager
plugin_manager.register("my_plugin", MyPlugin.new, { version: "1.0.0" })
```

## Using Plugins

To use a registered plugin:

```ruby
plugin = Agentic::Extension.plugin_manager.get("my_plugin")
plugin.call(arg1, arg2) if plugin
```