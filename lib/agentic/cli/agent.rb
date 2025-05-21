# frozen_string_literal: true

module Agentic
  class CLI < Thor
    # CLI commands for managing agents
    class Agent < Thor
      desc "list", "List available agents"
      def list
        puts "Available agents:"
        # In a future implementation, this would list agents from a registry
        puts "  - No custom agents registered yet"
      end

      desc "create NAME", "Create a new agent"
      option :role, type: :string, required: true, desc: "Role of the agent"
      option :instructions, type: :string, required: true, desc: "Instructions for the agent"
      def create(name)
        puts "Creating agent: #{name}"
        # In a future implementation, this would create and register an agent
        puts "Agent created successfully."
      end

      desc "delete NAME", "Delete an agent"
      def delete(name)
        puts "Deleting agent: #{name}"
        # In a future implementation, this would delete an agent from a registry
        puts "Agent deleted successfully."
      end
    end
  end
end
