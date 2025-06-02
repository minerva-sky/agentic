# frozen_string_literal: true

module Agentic
  class CLI < Thor
    # Command-line interface for managing capabilities
    class Capabilities < Thor
      desc "list", "List available capabilities"
      option :detailed, type: :boolean, aliases: "-d",
        desc: "Show detailed information"
      def list
        # Initialize agent assembly system
        Agentic.initialize_agent_assembly
        registry = Agentic.agent_capability_registry

        capabilities = registry.list(include_providers: options[:detailed])

        if capabilities.empty?
          puts UI.box(
            "Available Capabilities",
            "No capabilities registered yet.\n\n" \
            "You can register capabilities programmatically via Agentic.register_capability.",
            padding: [1, 2, 1, 2],
            style: {border: {fg: :blue}}
          )
          return
        end

        output = ""
        capabilities.each do |name, info|
          output += "#{UI.colorize(name, :blue)}:\n"
          output += "  Available versions: #{info[:versions].join(", ")}\n"
          output += "  Latest version: #{UI.colorize(info[:latest], :green)}\n"

          if options[:detailed] && info[:providers]
            # Get a capability to show more details
            capability = registry.get(name, info[:latest])
            if capability
              output += "  Description: #{capability.description}\n"

              unless capability.inputs.empty?
                output += "  Inputs:\n"
                capability.inputs.each do |input_name, input_spec|
                  required = input_spec[:required] ? " (required)" : ""
                  output += "    - #{input_name}#{required}: #{input_spec[:type] || "any"}\n"
                  output += "      #{input_spec[:description]}\n" if input_spec[:description]
                end
              end

              unless capability.outputs.empty?
                output += "  Outputs:\n"
                capability.outputs.each do |output_name, output_spec|
                  output += "    - #{output_name}: #{output_spec[:type] || "any"}\n"
                  output += "      #{output_spec[:description]}\n" if output_spec[:description]
                end
              end

              unless capability.dependencies.empty?
                output += "  Dependencies:\n"
                capability.dependencies.each do |dep|
                  output += "    - #{dep[:name]} (#{dep[:version] || "any version"})\n"
                end
              end
            end
          end

          output += "\n"
        end

        puts UI.box(
          "Available Capabilities",
          output,
          padding: [1, 2, 1, 2],
          style: {border: {fg: :blue}}
        )
      end

      desc "show NAME", "Show details of a specific capability"
      option :version, type: :string, aliases: "-v",
        desc: "Capability version (defaults to latest)"
      def show(name)
        # Initialize agent assembly system
        Agentic.initialize_agent_assembly
        registry = Agentic.agent_capability_registry

        capability = registry.get(name, options[:version])

        unless capability
          available = registry.list.keys.join(", ")
          available_text = available.empty? ? "No capabilities registered yet." : "Available: #{available}"

          puts UI.box(
            "Error",
            "Capability '#{UI.colorize(name, :yellow)}' not found.\n\n#{available_text}",
            padding: [1, 2, 1, 2],
            style: {border: {fg: :red}}
          )
          exit 1
        end

        output = ""
        output += "Name: #{UI.colorize(capability.name, :blue)}\n"
        output += "Version: #{UI.colorize(capability.version, :green)}\n"
        output += "Description: #{capability.description}\n\n"

        unless capability.inputs.empty?
          output += "Inputs:\n"
          capability.inputs.each do |input_name, input_spec|
            required = input_spec[:required] ? " (required)" : ""
            output += "  - #{UI.colorize(input_name, :yellow)}#{required}: #{input_spec[:type] || "any"}\n"
            output += "    #{input_spec[:description]}\n" if input_spec[:description]
          end
          output += "\n"
        end

        unless capability.outputs.empty?
          output += "Outputs:\n"
          capability.outputs.each do |output_name, output_spec|
            output += "  - #{UI.colorize(output_name, :yellow)}: #{output_spec[:type] || "any"}\n"
            output += "    #{output_spec[:description]}\n" if output_spec[:description]
          end
          output += "\n"
        end

        unless capability.dependencies.empty?
          output += "Dependencies:\n"
          capability.dependencies.each do |dep|
            output += "  - #{UI.colorize(dep[:name], :magenta)} (#{dep[:version] || "any version"})\n"
          end
        end

        puts UI.box(
          "Capability Details",
          output,
          padding: [1, 2, 1, 2],
          style: {border: {fg: :blue}}
        )
      end

      desc "search QUERY", "Search for capabilities"
      def search(query)
        # Initialize agent assembly system
        Agentic.initialize_agent_assembly
        registry = Agentic.agent_capability_registry

        # Search by name and description
        capabilities = registry.list
        results = {}

        capabilities.each do |name, info|
          # Check if query matches capability name
          if name.downcase.include?(query.downcase)
            results[name] = info
            next
          end

          # Check if query matches capability description
          capability = registry.get(name, info[:latest])
          if capability && capability.description.downcase.include?(query.downcase)
            results[name] = info
          end
        end

        if results.empty?
          puts UI.box(
            "Search Results",
            "No capabilities found matching '#{UI.colorize(query, :yellow)}'.",
            padding: [1, 2, 1, 2],
            style: {border: {fg: :blue}}
          )
          return
        end

        output = ""
        results.each do |name, info|
          capability = registry.get(name, info[:latest])

          output += "#{UI.colorize(name, :blue)}:\n"
          output += "  Latest version: #{UI.colorize(info[:latest], :green)}\n"
          output += "  Description: #{capability.description}\n\n"
        end

        puts UI.box(
          "Search Results",
          output,
          padding: [1, 2, 1, 2],
          style: {border: {fg: :blue}}
        )
      end
    end
  end
end
