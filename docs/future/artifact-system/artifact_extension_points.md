# Artifact Generation Extension Points

## Overview

The artifact generation system is designed with extensibility as a core principle. This document outlines the extension points that allow developers to add new artifact types, generators, verification strategies, and domain-specific templates while maintaining system consistency and quality.

## Extension Architecture

Following the established Agentic extension patterns, the artifact system provides these extension points:

1. **ArtifactTypeProvider**: Register new artifact types and their specifications
2. **ArtifactGenerator**: Custom generation strategies for specific artifact types
3. **WorkspaceTemplate**: Predefined project structures and scaffolding
4. **VerificationStrategy**: Custom validation approaches for artifact types
5. **DomainAdapter**: Domain-specific artifact generation behaviors

## Core Extension Interfaces

### 1. ArtifactTypeProvider Interface

```ruby
module Agentic
  module Extension
    # Base interface for artifact type providers
    # Providers define new types of artifacts that can be generated
    class ArtifactTypeProvider
      # @return [String] Unique identifier for the artifact type
      attr_reader :type_name
      
      # @return [String] Human-readable description
      attr_reader :description
      
      # @return [Hash] Configuration options for this type
      attr_reader :config

      # Initialize a new artifact type provider
      # @param type_name [String] Unique identifier for the artifact type
      # @param description [String] Human-readable description
      # @param config [Hash] Configuration options
      def initialize(type_name, description, config = {})
        @type_name = type_name
        @description = description
        @config = config
      end

      # Define the specification for this artifact type
      # @return [ArtifactSpecification] The artifact specification
      def specification
        raise NotImplementedError, "Subclasses must implement specification"
      end

      # Create a generator for this artifact type
      # @param context [Hash] Generation context (task, agent, etc.)
      # @return [ArtifactGenerator] The generator instance
      def create_generator(context = {})
        raise NotImplementedError, "Subclasses must implement create_generator"
      end

      # Create a verification strategy for this artifact type  
      # @param config [Hash] Verification configuration
      # @return [VerificationStrategy] The verification strategy
      def create_verifier(config = {})
        raise NotImplementedError, "Subclasses must implement create_verifier"
      end

      # Check if this provider can handle a specific requirement
      # @param requirement [Hash] The artifact requirement
      # @return [Boolean] True if this provider can handle the requirement
      def can_handle?(requirement)
        requirement[:type] == @type_name ||
        (requirement[:file_extension] && 
         specification.supported_extensions.include?(requirement[:file_extension]))
      end
    end
  end
end
```

### 2. ArtifactGenerator Interface

```ruby
module Agentic
  module Extension
    # Base interface for artifact generators
    # Generators handle the actual content creation for specific artifact types
    class ArtifactGenerator
      # @return [ArtifactSpecification] The artifact specification this generator handles
      attr_reader :specification
      
      # @return [Hash] Configuration options for generation
      attr_reader :config

      # Initialize a new artifact generator
      # @param specification [ArtifactSpecification] The artifact specification
      # @param config [Hash] Configuration options
      def initialize(specification, config = {})
        @specification = specification
        @config = config
      end

      # Generate content for an artifact
      # @param input [Hash] Input data for generation (task description, requirements, etc.)
      # @param context [Hash] Generation context (agent, workspace, etc.)
      # @return [String] The generated content
      def generate_content(input, context = {})
        raise NotImplementedError, "Subclasses must implement generate_content"
      end

      # Determine the output filename for the artifact
      # @param input [Hash] Input data
      # @param context [Hash] Generation context
      # @return [String] The filename (without path)
      def determine_filename(input, context = {})
        base_name = extract_name_from_input(input) || "artifact"
        "#{base_name}#{@specification.default_extension}"
      end

      # Post-process generated content (formatting, cleanup, etc.)
      # @param content [String] The raw generated content
      # @param context [Hash] Processing context
      # @return [String] The processed content
      def post_process(content, context = {})
        content # Default: no post-processing
      end

      # Validate generation requirements before attempting generation
      # @param input [Hash] Input data
      # @return [Array<String>] Array of validation errors (empty if valid)
      def validate_requirements(input)
        [] # Default: no validation errors
      end

      protected

      # Extract a meaningful name from input data
      # @param input [Hash] Input data
      # @return [String, nil] Extracted name or nil
      def extract_name_from_input(input)
        input[:name] || 
        input[:class_name] || 
        input[:function_name] ||
        extract_from_description(input[:description])
      end

      # Extract name from description text
      # @param description [String] Description text
      # @return [String, nil] Extracted name or nil
      def extract_from_description(description)
        return nil unless description
        
        # Look for patterns like "Create a UserService class"
        if match = description.match(/create\s+(?:a\s+)?(\w+)/i)
          match[1].downcase
        end
      end
    end
  end
end
```

### 3. WorkspaceTemplate Interface

```ruby
module Agentic
  module Extension
    # Base interface for workspace templates
    # Templates define project structures and provide scaffolding
    class WorkspaceTemplate
      # @return [String] Unique identifier for the template
      attr_reader :name
      
      # @return [String] Human-readable description
      attr_reader :description
      
      # @return [Hash] Template configuration
      attr_reader :config

      # Initialize a new workspace template
      # @param name [String] Unique identifier
      # @param description [String] Human-readable description
      # @param config [Hash] Template configuration
      def initialize(name, description, config = {})
        @name = name
        @description = description
        @config = config
      end

      # Define the directory structure for this template
      # @return [Hash] Directory structure definition
      def directory_structure
        raise NotImplementedError, "Subclasses must implement directory_structure"
      end

      # Get template files (scaffolding, boilerplate, etc.)
      # @return [Hash] Map of relative paths to file contents
      def template_files
        {}
      end

      # Get artifact specifications for this template
      # @return [Array<ArtifactSpecification>] Required artifacts
      def artifact_specifications
        []
      end

      # Apply template to a workspace directory
      # @param workspace_path [String] Path to workspace directory
      # @param context [Hash] Template application context
      # @return [Hash] Metadata about applied template
      def apply_to_workspace(workspace_path, context = {})
        create_directory_structure(workspace_path)
        create_template_files(workspace_path, context)
        
        {
          template: @name,
          applied_at: Time.now,
          directories_created: count_directories_created(workspace_path),
          files_created: count_files_created(workspace_path)
        }
      end

      # Check if this template is suitable for given requirements
      # @param requirements [Hash] Project requirements
      # @return [Boolean] True if template is suitable
      def suitable_for?(requirements)
        return false unless requirements[:project_type]
        
        supported_types = @config[:supported_project_types] || []
        supported_types.include?(requirements[:project_type])
      end

      protected

      # Create directory structure in workspace
      # @param workspace_path [String] Workspace directory path
      def create_directory_structure(workspace_path)
        structure = directory_structure
        create_directories_recursive(workspace_path, structure)
      end

      # Create template files in workspace
      # @param workspace_path [String] Workspace directory path
      # @param context [Hash] Template context for file processing
      def create_template_files(workspace_path, context)
        template_files.each do |relative_path, content|
          full_path = File.join(workspace_path, relative_path)
          processed_content = process_template_content(content, context)
          
          FileUtils.mkdir_p(File.dirname(full_path))
          File.write(full_path, processed_content)
        end
      end

      # Process template content with context variables
      # @param content [String] Template content
      # @param context [Hash] Context variables
      # @return [String] Processed content
      def process_template_content(content, context)
        # Simple template variable substitution
        # In a real implementation, this would use a proper template engine
        result = content.dup
        context.each do |key, value|
          result.gsub!("{{#{key}}}", value.to_s)
        end
        result
      end

      # Create directories recursively
      # @param base_path [String] Base directory path
      # @param structure [Hash] Directory structure hash
      def create_directories_recursive(base_path, structure)
        structure.each do |dir_name, sub_structure|
          dir_path = File.join(base_path, dir_name.to_s)
          FileUtils.mkdir_p(dir_path)
          
          if sub_structure.is_a?(Hash)
            create_directories_recursive(dir_path, sub_structure)
          end
        end
      end
    end
  end
end
```

## Built-in Extension Implementations

### 1. Ruby Source Code Provider

```ruby
class RubySourceProvider < ArtifactTypeProvider
  def initialize
    super("ruby_source", "Ruby source code files", {
      supported_extensions: [".rb"],
      requires_syntax_check: true,
      supports_testing: true
    })
  end

  def specification
    @specification ||= ArtifactSpecification.new(
      type: @type_name,
      default_extension: ".rb",
      supported_extensions: [".rb"],
      validation_rules: [
        "syntax_check",
        "rubocop_compliance", 
        "yard_documentation"
      ],
      dependencies: [],
      metadata: {
        language: "ruby",
        paradigm: "object_oriented",
        runtime: "ruby"
      }
    )
  end

  def create_generator(context = {})
    RubySourceGenerator.new(specification, context)
  end

  def create_verifier(config = {})
    RubySourceVerificationStrategy.new(config)
  end
end

class RubySourceGenerator < ArtifactGenerator
  def generate_content(input, context = {})
    agent = context[:agent]
    prompt = build_ruby_generation_prompt(input)
    
    response = agent.execute_prompt(prompt)
    extract_code_from_response(response)
  end

  def determine_filename(input, context = {})
    if input[:class_name]
      "#{input[:class_name].downcase}.rb"
    elsif input[:module_name]
      "#{input[:module_name].downcase}.rb"
    else
      super
    end
  end

  def post_process(content, context = {})
    # Apply RuboCop auto-corrections if available
    if system('which rubocop > /dev/null 2>&1')
      apply_rubocop_autocorrect(content)
    else
      content
    end
  end

  def validate_requirements(input)
    errors = []
    errors << "Missing description" unless input[:description]
    errors << "No clear class or module intent" unless has_clear_intent?(input)
    errors
  end

  private

  def build_ruby_generation_prompt(input)
    <<~PROMPT
      Generate Ruby code based on the following requirements:
      
      Description: #{input[:description]}
      #{"Class Name: #{input[:class_name]}" if input[:class_name]}
      #{"Module Name: #{input[:module_name]}" if input[:module_name]}
      #{"Include Tests: Yes" if input[:include_tests]}
      
      Requirements:
      - Follow Ruby style guide conventions
      - Include appropriate documentation
      - Use meaningful variable and method names
      - Include error handling where appropriate
      
      Return only the Ruby code, properly formatted.
    PROMPT
  end

  def extract_code_from_response(response)
    # Extract code from markdown code blocks or plain text
    if response.include?("```ruby")
      response[/```ruby\n(.*?)```/m, 1]
    elsif response.include?("```")
      response[/```\n(.*?)```/m, 1]
    else
      response
    end
  end

  def has_clear_intent?(input)
    description = input[:description]&.downcase
    return false unless description
    
    ruby_keywords = %w[class module method function def initialize]
    ruby_keywords.any? { |keyword| description.include?(keyword) }
  end
end
```

### 2. React Application Template

```ruby
class ReactAppTemplate < WorkspaceTemplate
  def initialize
    super("react_app", "React web application", {
      supported_project_types: ["web_app", "spa", "react_app"],
      requires_node: true,
      package_manager: "npm"
    })
  end

  def directory_structure
    {
      src: {
        components: {},
        hooks: {},
        utils: {},
        styles: {}
      },
      public: {},
      tests: {
        components: {},
        integration: {}
      },
      docs: {}
    }
  end

  def template_files
    {
      "package.json" => package_json_template,
      "src/App.js" => app_component_template,
      "src/index.js" => index_template,
      "public/index.html" => html_template,
      "README.md" => readme_template,
      ".gitignore" => gitignore_template
    }
  end

  def artifact_specifications
    [
      ArtifactSpecification.new(
        type: "react_component",
        default_extension: ".js",
        supported_extensions: [".js", ".jsx", ".ts", ".tsx"]
      ),
      ArtifactSpecification.new(
        type: "css_styles",
        default_extension: ".css",
        supported_extensions: [".css", ".scss", ".less"]
      )
    ]
  end

  private

  def package_json_template
    <<~JSON
    {
      "name": "{{project_name}}",
      "version": "1.0.0",
      "description": "{{project_description}}",
      "main": "src/index.js",
      "scripts": {
        "start": "react-scripts start",
        "build": "react-scripts build",
        "test": "react-scripts test",
        "eject": "react-scripts eject"
      },
      "dependencies": {
        "react": "^18.2.0",
        "react-dom": "^18.2.0",
        "react-scripts": "5.0.1"
      },
      "devDependencies": {
        "@testing-library/jest-dom": "^5.16.4",
        "@testing-library/react": "^13.3.0",
        "@testing-library/user-event": "^13.5.0"
      }
    }
    JSON
  end

  def app_component_template
    <<~JAVASCRIPT
    import React from 'react';
    import './App.css';

    function App() {
      return (
        <div className="App">
          <header className="App-header">
            <h1>{{project_name}}</h1>
            <p>{{project_description}}</p>
          </header>
        </div>
      );
    }

    export default App;
    JAVASCRIPT
  end

  def readme_template
    <<~MARKDOWN
    # {{project_name}}

    {{project_description}}

    ## Getting Started

    This project was created with Create React App.

    ### Available Scripts

    - `npm start` - Runs the app in development mode
    - `npm test` - Launches the test runner
    - `npm run build` - Builds the app for production

    ## Features

    - Modern React with hooks
    - Component-based architecture
    - Responsive design
    - Testing setup included

    MARKDOWN
  end
end
```

### 3. JSON Configuration Provider

```ruby
class JsonConfigProvider < ArtifactTypeProvider
  def initialize
    super("json_config", "JSON configuration files", {
      supported_extensions: [".json"],
      requires_schema_validation: true,
      supports_comments: false
    })
  end

  def specification
    @specification ||= ArtifactSpecification.new(
      type: @type_name,
      default_extension: ".json",
      supported_extensions: [".json"],
      validation_rules: [
        "json_syntax_check",
        "schema_validation",
        "required_fields_check"
      ],
      dependencies: [],
      metadata: {
        format: "json",
        structured: true,
        human_readable: true
      }
    )
  end

  def create_generator(context = {})
    JsonConfigGenerator.new(specification, context)
  end

  def create_verifier(config = {})
    JsonConfigVerificationStrategy.new(config)
  end
end
```

## Extension Registration System

### ArtifactTypeRegistry

```ruby
module Agentic
  # Registry for artifact type providers and extensions
  class ArtifactTypeRegistry
    include Singleton

    def initialize
      @providers = {}
      @templates = {}
      @domain_adapters = {}
      register_builtin_providers
    end

    # Register an artifact type provider
    # @param provider [ArtifactTypeProvider] The provider to register
    def register_provider(provider)
      @providers[provider.type_name] = provider
      Agentic.logger.info("Registered artifact type provider: #{provider.type_name}")
    end

    # Register a workspace template
    # @param template [WorkspaceTemplate] The template to register
    def register_template(template)
      @templates[template.name] = template
      Agentic.logger.info("Registered workspace template: #{template.name}")
    end

    # Register a domain adapter
    # @param domain [String] Domain identifier
    # @param adapter [DomainAdapter] The domain adapter
    def register_domain_adapter(domain, adapter)
      @domain_adapters[domain] = adapter
      Agentic.logger.info("Registered domain adapter: #{domain}")
    end

    # Get provider for artifact type
    # @param type_name [String] The artifact type name
    # @return [ArtifactTypeProvider, nil] The provider or nil
    def get_provider(type_name)
      @providers[type_name]
    end

    # Get template by name
    # @param template_name [String] The template name
    # @return [WorkspaceTemplate, nil] The template or nil
    def get_template(template_name)
      @templates[template_name]
    end

    # Find suitable template for requirements
    # @param requirements [Hash] Project requirements
    # @return [WorkspaceTemplate, nil] Suitable template or nil
    def find_template(requirements)
      @templates.values.find { |template| template.suitable_for?(requirements) }
    end

    # Get domain adapter
    # @param domain [String] Domain identifier
    # @return [DomainAdapter, nil] The adapter or nil
    def get_domain_adapter(domain)
      @domain_adapters[domain]
    end

    # List all registered providers
    # @return [Hash] Map of type names to providers
    def list_providers
      @providers.dup
    end

    # List all registered templates
    # @return [Hash] Map of template names to templates
    def list_templates
      @templates.dup
    end

    private

    def register_builtin_providers
      register_provider(RubySourceProvider.new)
      register_provider(JsonConfigProvider.new)
      register_provider(JavaScriptSourceProvider.new)
      register_provider(PythonSourceProvider.new)
      register_provider(MarkdownDocProvider.new)
      
      register_template(ReactAppTemplate.new)
      register_template(RubyGemTemplate.new)
      register_template(NodeJsAppTemplate.new)
      register_template(PythonPackageTemplate.new)
    end
  end
end
```

## Plugin Discovery and Auto-Registration

```ruby
# Example plugin file: plugins/custom_artifact_types.rb
module CustomArtifactTypes
  # Plugin initialization hook
  def self.initialize_plugin
    registry = Agentic::ArtifactTypeRegistry.instance
    
    # Register custom providers
    registry.register_provider(DockerfileProvider.new)
    registry.register_provider(KubernetesManifestProvider.new)
    
    # Register custom templates
    registry.register_template(MicroserviceTemplate.new)
    registry.register_template(DockerizedAppTemplate.new)
  end

  # Plugin entry point
  def self.call(event, data)
    case event
    when :before_artifact_generation
      apply_custom_preprocessing(data)
    when :after_artifact_generation
      apply_custom_postprocessing(data)
    end
  end
end

# Auto-register the plugin
Agentic::Extension::PluginManager.instance.register!(
  "custom_artifact_types",
  CustomArtifactTypes,
  {
    version: "1.0.0",
    description: "Custom artifact types for containerized applications",
    author: "Your Name"
  }
)
```

## Domain-Specific Artifact Adaptation

```ruby
# Healthcare domain adapter for artifact generation
class HealthcareArtifactAdapter < Agentic::Extension::DomainAdapter
  def initialize
    super("healthcare", {
      compliance_frameworks: ["HIPAA", "FDA"],
      required_documentation: ["privacy_policy", "security_audit"],
      code_standards: ["secure_coding", "data_encryption"]
    })
    
    register_artifact_adapters
  end

  private

  def register_artifact_adapters
    # Adapt Ruby code generation for healthcare compliance
    register_adapter(:ruby_source, lambda do |generator, context|
      generator.add_compliance_requirements([
        "data_encryption",
        "audit_logging", 
        "access_controls"
      ])
      generator
    end)
    
    # Adapt configuration generation for HIPAA compliance
    register_adapter(:json_config, lambda do |generator, context|
      generator.add_required_fields([
        "encryption_settings",
        "audit_configuration",
        "access_policies"
      ])
      generator
    end)
  end
end
```

This extension system provides comprehensive customization capabilities while maintaining consistency with the existing Agentic architecture. Developers can easily add new artifact types, generation strategies, workspace templates, and domain-specific behaviors through well-defined interfaces and automatic discovery mechanisms.