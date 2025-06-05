# Artifact Verification Strategies

## Overview

The artifact generation system requires comprehensive verification strategies that go beyond the existing text/JSON verification. This document outlines verification approaches for different types of generated artifacts, integrating with the existing `VerificationHub` architecture.

## Existing Verification System

The current system uses:
- **VerificationHub**: Coordinates multiple verification strategies
- **VerificationStrategy**: Base class for verification implementations  
- **VerificationResult**: Standardized result format with verification status, confidence, and messages
- **SchemaVerificationStrategy**: Validates JSON output against schemas

## Artifact-Specific Verification Strategies

### 1. Base Artifact Verification Strategy

```ruby
module Agentic
  module Verification
    class ArtifactVerificationStrategy < VerificationStrategy
      # Verifies artifact results using file-based validation
      # @param task [ArtifactTask] The artifact task to verify
      # @param result [ArtifactResult] The artifact result to verify  
      # @return [VerificationResult] The verification result
      def verify(task, result)
        unless result.successful?
          return VerificationResult.new(
            task_id: task.id,
            verified: false,
            confidence: 0.0,
            messages: ["Artifact task failed, skipping verification"]
          )
        end

        # Verify each artifact according to its type
        artifact_results = result.artifacts.map do |artifact|
          verify_single_artifact(artifact, task)
        end

        # Combine verification results
        combine_artifact_results(task.id, artifact_results)
      end

      private

      def verify_single_artifact(artifact, task)
        strategy = get_strategy_for_artifact_type(artifact.type)
        strategy.verify_artifact(artifact, task)
      end

      def get_strategy_for_artifact_type(type)
        case type
        when "ruby_source" then RubySourceVerificationStrategy.new
        when "javascript_source" then JavaScriptSourceVerificationStrategy.new
        when "python_source" then PythonSourceVerificationStrategy.new
        when "json_config" then JsonConfigVerificationStrategy.new
        when "yaml_config" then YamlConfigVerificationStrategy.new
        when "markdown_doc" then MarkdownDocVerificationStrategy.new
        when "html_file" then HtmlFileVerificationStrategy.new
        when "css_file" then CssFileVerificationStrategy.new
        else GenericFileVerificationStrategy.new
        end
      end

      def combine_artifact_results(task_id, artifact_results)
        verified = artifact_results.all? { |r| r[:verified] }
        confidence = artifact_results.map { |r| r[:confidence] }.sum / artifact_results.size
        messages = artifact_results.flat_map { |r| r[:messages] }

        VerificationResult.new(
          task_id: task_id,
          verified: verified,
          confidence: confidence,
          messages: messages
        )
      end
    end
  end
end
```

### 2. Source Code Verification Strategies

#### Ruby Source Verification
```ruby
class RubySourceVerificationStrategy
  def verify_artifact(artifact, task)
    checks = [
      verify_syntax(artifact),
      verify_rubocop_compliance(artifact),
      verify_functionality(artifact, task)
    ]
    
    combine_checks("Ruby source", checks)
  end

  private

  def verify_syntax(artifact)
    begin
      RubyVM::InstructionSequence.compile(artifact.content)
      { verified: true, confidence: 1.0, message: "Ruby syntax is valid" }
    rescue SyntaxError => e
      { verified: false, confidence: 0.0, message: "Syntax error: #{e.message}" }
    end
  end

  def verify_rubocop_compliance(artifact)
    # Run RuboCop programmatically
    require 'rubocop'
    
    config = RuboCop::ConfigLoader.load_file('.rubocop.yml')
    team = RuboCop::Cop::Team.new(config)
    
    offenses = team.inspect_file(RuboCop::ProcessedSource.new(
      artifact.content,
      RUBY_VERSION.to_f,
      artifact.path
    ))

    if offenses.empty?
      { verified: true, confidence: 0.9, message: "RuboCop compliance verified" }
    else
      warnings = offenses.map(&:message).join("; ")
      severity = offenses.any?(&:error?) ? 0.3 : 0.7
      { verified: offenses.none?(&:error?), confidence: severity, message: "RuboCop issues: #{warnings}" }
    end
  rescue => e
    { verified: true, confidence: 0.5, message: "RuboCop check failed: #{e.message}" }
  end

  def verify_functionality(artifact, task)
    # Basic functionality verification based on task requirements
    if task.input["test_cases"]
      verify_against_test_cases(artifact, task.input["test_cases"])
    else
      { verified: true, confidence: 0.7, message: "No test cases provided for functionality verification" }
    end
  end

  def verify_against_test_cases(artifact, test_cases)
    # Create a safe evaluation environment
    passed_tests = 0
    
    test_cases.each do |test_case|
      begin
        # Safely evaluate the code with test inputs
        result = evaluate_ruby_safely(artifact.content, test_case["input"])
        if result == test_case["expected_output"]
          passed_tests += 1
        end
      rescue => e
        # Test failed due to runtime error
      end
    end

    confidence = passed_tests.to_f / test_cases.size
    verified = confidence >= 0.8

    { 
      verified: verified, 
      confidence: confidence, 
      message: "#{passed_tests}/#{test_cases.size} test cases passed" 
    }
  end

  def evaluate_ruby_safely(code, input)
    # Implement safe Ruby evaluation with restricted environment
    # This would use techniques like:
    # - Restricted binding
    # - Timeout protection  
    # - IO restrictions
    # - Method whitelisting
  end
end
```

#### JavaScript Source Verification
```ruby
class JavaScriptSourceVerificationStrategy
  def verify_artifact(artifact, task)
    checks = [
      verify_syntax(artifact),
      verify_eslint_compliance(artifact),
      verify_type_safety(artifact)
    ]
    
    combine_checks("JavaScript source", checks)
  end

  private

  def verify_syntax(artifact)
    # Use Node.js to check syntax
    temp_file = Tempfile.new(['verify', '.js'])
    temp_file.write(artifact.content)
    temp_file.close

    result = `node --check #{temp_file.path} 2>&1`
    temp_file.unlink

    if $?.success?
      { verified: true, confidence: 1.0, message: "JavaScript syntax is valid" }
    else
      { verified: false, confidence: 0.0, message: "Syntax error: #{result}" }
    end
  rescue => e
    { verified: false, confidence: 0.0, message: "Syntax check failed: #{e.message}" }
  end

  def verify_eslint_compliance(artifact)
    # Run ESLint if available
    if system('which eslint > /dev/null 2>&1')
      run_eslint_check(artifact)
    else
      { verified: true, confidence: 0.5, message: "ESLint not available, skipping check" }
    end
  end

  def verify_type_safety(artifact)
    # Check for TypeScript or JSDoc type annotations
    if artifact.content.include?('@type') || artifact.content.include?('/**')
      { verified: true, confidence: 0.8, message: "Type annotations found" }
    else
      { verified: true, confidence: 0.6, message: "No type annotations detected" }
    end
  end
end
```

### 3. Configuration File Verification Strategies

#### JSON Configuration Verification
```ruby
class JsonConfigVerificationStrategy
  def verify_artifact(artifact, task)
    checks = [
      verify_json_syntax(artifact),
      verify_schema_compliance(artifact, task),
      verify_required_fields(artifact, task)
    ]
    
    combine_checks("JSON configuration", checks)
  end

  private

  def verify_json_syntax(artifact)
    begin
      JSON.parse(artifact.content)
      { verified: true, confidence: 1.0, message: "JSON syntax is valid" }
    rescue JSON::ParserError => e
      { verified: false, confidence: 0.0, message: "JSON syntax error: #{e.message}" }
    end
  end

  def verify_schema_compliance(artifact, task)
    schema = task.input["config_schema"]
    return { verified: true, confidence: 0.5, message: "No schema provided" } unless schema

    begin
      json_data = JSON.parse(artifact.content)
      # Use JSON Schema validation library
      errors = JSON::Validator.fully_validate(schema, json_data)
      
      if errors.empty?
        { verified: true, confidence: 0.9, message: "Schema validation passed" }
      else
        { verified: false, confidence: 0.2, message: "Schema errors: #{errors.join('; ')}" }
      end
    rescue => e
      { verified: false, confidence: 0.0, message: "Schema validation failed: #{e.message}" }
    end
  end

  def verify_required_fields(artifact, task)
    required_fields = task.input["required_fields"] || []
    return { verified: true, confidence: 1.0, message: "No required fields specified" } if required_fields.empty?

    begin
      json_data = JSON.parse(artifact.content)
      missing_fields = required_fields - json_data.keys
      
      if missing_fields.empty?
        { verified: true, confidence: 1.0, message: "All required fields present" }
      else
        { verified: false, confidence: 0.3, message: "Missing required fields: #{missing_fields.join(', ')}" }
      end
    rescue => e
      { verified: false, confidence: 0.0, message: "Field verification failed: #{e.message}" }
    end
  end
end
```

### 4. Documentation Verification Strategies

#### Markdown Documentation Verification
```ruby
class MarkdownDocVerificationStrategy
  def verify_artifact(artifact, task)
    checks = [
      verify_markdown_syntax(artifact),
      verify_link_validity(artifact),
      verify_content_completeness(artifact, task),
      verify_code_block_syntax(artifact)
    ]
    
    combine_checks("Markdown documentation", checks)
  end

  private

  def verify_markdown_syntax(artifact)
    # Use kramdown or similar parser
    begin
      require 'kramdown'
      doc = Kramdown::Document.new(artifact.content)
      
      if doc.warnings.empty?
        { verified: true, confidence: 1.0, message: "Markdown syntax is valid" }
      else
        warnings = doc.warnings.join('; ')
        { verified: true, confidence: 0.7, message: "Markdown warnings: #{warnings}" }
      end
    rescue => e
      { verified: false, confidence: 0.0, message: "Markdown parsing failed: #{e.message}" }
    end
  end

  def verify_link_validity(artifact)
    links = extract_links(artifact.content)
    broken_links = []
    
    links.each do |link|
      unless link_valid?(link)
        broken_links << link
      end
    end
    
    if broken_links.empty?
      { verified: true, confidence: 0.9, message: "All links are valid" }
    else
      { verified: false, confidence: 0.4, message: "Broken links: #{broken_links.join(', ')}" }
    end
  end

  def verify_content_completeness(artifact, task)
    required_sections = task.input["required_sections"] || []
    return { verified: true, confidence: 1.0, message: "No required sections specified" } if required_sections.empty?

    content = artifact.content.downcase
    missing_sections = required_sections.reject { |section| content.include?(section.downcase) }
    
    if missing_sections.empty?
      { verified: true, confidence: 1.0, message: "All required sections present" }
    else
      { verified: false, confidence: 0.5, message: "Missing sections: #{missing_sections.join(', ')}" }
    end
  end

  def verify_code_block_syntax(artifact)
    code_blocks = extract_code_blocks(artifact.content)
    syntax_errors = []
    
    code_blocks.each do |block|
      if block[:language] && !verify_code_syntax(block[:code], block[:language])
        syntax_errors << "#{block[:language]} block at line #{block[:line]}"
      end
    end
    
    if syntax_errors.empty?
      { verified: true, confidence: 0.8, message: "All code blocks have valid syntax" }
    else
      { verified: false, confidence: 0.3, message: "Code syntax errors: #{syntax_errors.join(', ')}" }
    end
  end
end
```

### 5. Multi-File Project Verification Strategy

```ruby
class ProjectVerificationStrategy < ArtifactVerificationStrategy
  def verify(task, result)
    checks = [
      verify_project_structure(result),
      verify_file_dependencies(result),
      verify_build_system(result, task),
      verify_integration(result, task)
    ]
    
    # Combine project-level checks with individual file checks
    individual_checks = super(task, result)
    all_checks = checks + [individual_checks.to_h]
    
    combine_project_checks(task.id, all_checks)
  end

  private

  def verify_project_structure(result)
    expected_structure = get_expected_structure(result.workspace_metadata["template"])
    actual_files = result.artifacts.map { |a| File.basename(a.path) }
    
    missing_files = expected_structure - actual_files
    
    if missing_files.empty?
      { verified: true, confidence: 0.9, message: "Project structure is complete" }
    else
      { verified: false, confidence: 0.4, message: "Missing files: #{missing_files.join(', ')}" }
    end
  end

  def verify_file_dependencies(result)
    dependency_errors = []
    
    result.artifacts.each do |artifact|
      dependencies = extract_dependencies(artifact)
      dependencies.each do |dep|
        unless dependency_satisfied?(dep, result.artifacts)
          dependency_errors << "#{artifact.path}: missing dependency #{dep}"
        end
      end
    end
    
    if dependency_errors.empty?
      { verified: true, confidence: 0.8, message: "All dependencies satisfied" }
    else
      { verified: false, confidence: 0.3, message: "Dependency errors: #{dependency_errors.join('; ')}" }
    end
  end

  def verify_build_system(result, task)
    build_files = result.artifacts.select { |a| build_file?(a.path) }
    
    if build_files.empty?
      { verified: true, confidence: 0.6, message: "No build system detected" }
    else
      verify_build_execution(build_files, result.workspace_metadata["workspace_path"])
    end
  end

  def verify_integration(result, task)
    if task.input["integration_tests"]
      run_integration_tests(result, task.input["integration_tests"])
    else
      { verified: true, confidence: 0.7, message: "No integration tests specified" }
    end
  end
end
```

### 6. Security-Focused Verification Strategy

```ruby
class SecurityVerificationStrategy < VerificationStrategy
  def verify(task, result)
    return super unless result.is_a?(ArtifactResult)
    
    security_checks = result.artifacts.map do |artifact|
      check_artifact_security(artifact)
    end
    
    combine_security_checks(task.id, security_checks)
  end

  private

  def check_artifact_security(artifact)
    checks = [
      scan_for_secrets(artifact),
      check_dangerous_patterns(artifact),
      verify_permissions(artifact),
      scan_for_vulnerabilities(artifact)
    ]
    
    combine_checks("Security", checks)
  end

  def scan_for_secrets(artifact)
    secret_patterns = [
      /api[_-]?key[s]?\s*[:=]\s*["'][\w\-]{20,}["']/i,
      /password\s*[:=]\s*["'][\w\-]{8,}["']/i,
      /token\s*[:=]\s*["'][\w\-]{20,}["']/i,
      /secret\s*[:=]\s*["'][\w\-]{20,}["']/i
    ]
    
    found_secrets = secret_patterns.any? { |pattern| artifact.content.match?(pattern) }
    
    if found_secrets
      { verified: false, confidence: 0.0, message: "Potential secrets detected in #{artifact.path}" }
    else
      { verified: true, confidence: 0.9, message: "No secrets detected" }
    end
  end

  def check_dangerous_patterns(artifact)
    dangerous_patterns = [
      /eval\s*\(/,
      /exec\s*\(/,
      /system\s*\(/,
      /`[^`]+`/,
      /File\.delete/,
      /rm\s+-rf/
    ]
    
    found_dangerous = dangerous_patterns.any? { |pattern| artifact.content.match?(pattern) }
    
    if found_dangerous
      { verified: false, confidence: 0.2, message: "Dangerous patterns detected in #{artifact.path}" }
    else
      { verified: true, confidence: 0.8, message: "No dangerous patterns detected" }
    end
  end
end
```

## Integration with Existing System

### 1. Enhanced VerificationHub Configuration
```ruby
# In PlanOrchestrator or CLI setup
def setup_artifact_verification
  hub = VerificationHub.new(
    strategies: [
      # Existing strategies
      SchemaVerificationStrategy.new,
      LlmVerificationStrategy.new,
      
      # New artifact strategies
      ArtifactVerificationStrategy.new,
      SecurityVerificationStrategy.new,
      ProjectVerificationStrategy.new
    ],
    config: {
      artifact_verification_enabled: true,
      security_scanning_enabled: true,
      build_verification_enabled: true
    }
  )
end
```

### 2. Conditional Strategy Application
```ruby
class EnhancedVerificationHub < VerificationHub
  def verify(task, result)
    # Use artifact-specific strategies for ArtifactTasks
    if task.is_a?(ArtifactTask) && result.is_a?(ArtifactResult)
      artifact_strategies = @strategies.select { |s| s.responds_to_artifacts? }
      apply_strategies(artifact_strategies, task, result)
    else
      # Use existing logic for regular tasks
      super(task, result)
    end
  end
end
```

## Quality Metrics and Reporting

### Artifact Quality Dashboard
```ruby
class ArtifactQualityReporter
  def generate_report(verification_results)
    {
      overall_quality: calculate_overall_quality(verification_results),
      security_score: calculate_security_score(verification_results),
      code_quality: calculate_code_quality(verification_results),
      documentation_score: calculate_documentation_score(verification_results),
      project_structure_score: calculate_structure_score(verification_results),
      recommendations: generate_recommendations(verification_results)
    }
  end
end
```

This comprehensive verification system ensures that generated artifacts meet quality, security, and functional requirements while integrating seamlessly with the existing Agentic verification architecture.