# frozen_string_literal: true

require "yaml"
require "fileutils"

module Agentic
  class CLI < Thor
    # CLI commands for managing configuration
    class Config < Thor
      CONFIG_FILE_NAME = ".agentic.yml"
      USER_CONFIG_PATH = File.join(Dir.home, CONFIG_FILE_NAME)
      PROJECT_CONFIG_PATH = File.join(Dir.pwd, CONFIG_FILE_NAME)

      desc "list", "List configuration settings"
      def list
        user_config = load_config(USER_CONFIG_PATH)
        project_config = load_config(PROJECT_CONFIG_PATH)

        puts "User configuration (#{USER_CONFIG_PATH}):"
        print_config(user_config)

        puts "\nProject configuration (#{PROJECT_CONFIG_PATH}):"
        print_config(project_config)

        puts "\nActive configuration:"
        print_config(active_config)

        puts "\nEnvironment variables:"
        puts "  OPENAI_ACCESS_TOKEN: #{ENV["OPENAI_ACCESS_TOKEN"] ? "[SET]" : "[NOT SET]"}"
      end

      desc "get KEY", "Get a configuration setting"
      def get(key)
        config = active_config
        value = config[key]

        if value
          puts value
        else
          puts "Key '#{key}' not found in configuration"
          exit 1
        end
      end

      desc "set KEY=VALUE", "Set a configuration setting"
      option :global, type: :boolean, aliases: "-g",
        desc: "Set in global user config instead of project config"
      def set(key_value)
        key, value = key_value.split("=", 2)

        unless value
          puts "Error: Invalid format. Use KEY=VALUE"
          exit 1
        end

        path = options[:global] ? USER_CONFIG_PATH : PROJECT_CONFIG_PATH
        config = load_config(path) || {}

        # Convert string values to appropriate types
        value = case value.downcase
        when "true" then true
        when "false" then false
        when /^\d+$/ then value.to_i
        when /^\d+\.\d+$/ then value.to_f
        else value
        end

        config[key] = value
        save_config(path, config)

        puts "Configuration updated successfully."
      end

      desc "init", "Initialize configuration"
      option :global, type: :boolean, aliases: "-g",
        desc: "Initialize global user config instead of project config"
      def init
        path = options[:global] ? USER_CONFIG_PATH : PROJECT_CONFIG_PATH

        if File.exist?(path)
          puts "Configuration already exists at #{path}"
          return
        end

        config = {
          "model" => "gpt-4o-mini"
          # Add other default configuration options here
        }

        save_config(path, config)
        puts "Configuration initialized at #{path}"
      end

      private

      def load_config(path)
        return unless File.exist?(path)

        begin
          YAML.load_file(path)
        rescue => e
          puts "Error loading configuration from #{path}: #{e.message}"
          nil
        end
      end

      def save_config(path, config)
        # Create directory if it doesn't exist
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)

        File.write(path, YAML.dump(config))
      end

      def active_config
        # Combine user and project configs, with project taking precedence
        user_config = load_config(USER_CONFIG_PATH) || {}
        project_config = load_config(PROJECT_CONFIG_PATH) || {}

        user_config.merge(project_config)
      end

      def print_config(config)
        if config.nil? || config.empty?
          puts "  [empty]"
        else
          config.each do |key, value|
            puts "  #{key}: #{value}"
          end
        end
      end
    end
  end
end
