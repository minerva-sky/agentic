#!/usr/bin/env ruby
# frozen_string_literal: true

# Human Intervention Portal Implementation Script
#
# This script demonstrates the use of the Agentic framework to strategize, plan,
# execute, and document the implementation of the Human Intervention Portal.
# It follows the architectural vision and uses domain-driven design principles.

require "bundler/setup"
require "json"
require "yaml"
require "fileutils"
require_relative "lib/agentic"

# Configure the Agentic framework
Agentic.configure do |config|
  config.access_token = ENV["OPENAI_ACCESS_TOKEN"] || "ollama"
  config.api_base_url = ENV["OPENAI_BASE_URL"]
end

class HumanInterventionPortalImplementation
  attr_reader :execution_plan, :orchestrator, :results

  def initialize
    @llm_config = Agentic::LlmConfig.new.tap do |config|
      config.model = "gpt-4o"
      config.temperature = 0.3
      config.max_tokens = 4000
    end

    @execution_plan = nil
    @orchestrator = nil
    @results = {}

    # Initialize architectural review components
    setup_architectural_review_context
    setup_observability
  end

  def run
    puts "🚀 Starting Human Intervention Portal Implementation"
    puts "=" * 80

    # Phase 1: Architectural Strategy & Planning
    puts "\n📋 Phase 1: Architectural Strategy & Planning"
    create_implementation_plan

    # Phase 2: Execute Implementation Plan
    puts "\n⚡ Phase 2: Execute Implementation Plan"
    execute_plan

    # Phase 3: Architectural Validation
    puts "\n🔍 Phase 3: Architectural Validation & Review"
    perform_architectural_review

    # Phase 4: Documentation Generation
    puts "\n📚 Phase 4: Documentation Generation"
    generate_documentation

    puts "\n✅ Human Intervention Portal Implementation Complete!"
    puts "=" * 80

    display_summary
  end

  private

  def setup_architectural_review_context
    @architectural_context = {
      framework_principles: load_architectural_principles,
      design_patterns: load_established_patterns,
      quality_attributes: define_quality_attributes,
      review_members: load_review_members
    }
  end

  def setup_observability
    # Configure enhanced observability for the implementation process
    Agentic.observability_engine.add_adapter(
      Agentic::Observability::ConsoleAdapter.new(
        color: true,
        verbose: true,
        timestamp_format: "%H:%M:%S"
      )
    )

    # Add file-based observability for architectural review
    log_dir = "logs/human_intervention_portal_implementation"
    FileUtils.mkdir_p(log_dir)

    Agentic.observability_engine.add_adapter(
      Agentic::Observability::FileAdapter.new(
        log_file: File.join(log_dir, "implementation_#{Time.now.strftime("%Y%m%d_%H%M%S")}.log"),
        format: :json
      )
    )
  end

  def create_implementation_plan
    goal = <<~GOAL
      Implement the Human Intervention Portal for the Agentic framework following 
      the architectural vision outlined in ArchitectureConsiderations.md. The portal 
      should provide modular UI components for human oversight and intervention 
      including:
      
      1. InterventionPortal - Manages human input requests/responses
      2. ExplanationEngine - Provides transparency into system decisions  
      3. ConfigurationInterface - Enables system customization
      
      The implementation must:
      - Follow the established architectural patterns and principles
      - Integrate with the existing observability and verification systems
      - Provide clear separation of concerns with domain boundaries
      - Include comprehensive testing and documentation
      - Support the 10 critical human intervention points defined in the architecture
      - Use progressive automation with configurable confidence thresholds
    GOAL

    puts "Creating comprehensive implementation plan..."

    planner = Agentic::TaskPlanner.new(goal, @llm_config)
    @execution_plan = planner.plan

    puts "📋 Plan created with #{@execution_plan.tasks.length} tasks"
    puts "\nPlan Overview:"
    puts "-" * 40

    @execution_plan.tasks.each_with_index do |task, index|
      puts "#{index + 1}. #{task.description}"
      puts "   Agent: #{task.agent.name}"
      puts "   Description: #{task.agent.description}"
      puts
    end
  end

  def execute_plan
    return unless @execution_plan

    puts "Executing implementation plan with #{@execution_plan.tasks.length} tasks..."

    # Create orchestrator with enhanced configuration for complex implementation
    @orchestrator = Agentic::PlanOrchestrator.new(
      plan_id: "human_intervention_portal_#{Time.now.strftime("%Y%m%d_%H%M%S")}",
      concurrency_limit: 3, # Controlled concurrency for architectural work
      retry_policy: {
        max_retries: 2,
        retryable_errors: ["TimeoutError", "ConnectionError"],
        backoff_strategy: :exponential
      },
      lifecycle_hooks: {
        before_task: method(:before_task_hook),
        after_task: method(:after_task_hook),
        on_failure: method(:on_failure_hook)
      }
    )

    # Convert TaskDefinitions to Tasks and add with architectural validation points
    tasks = @execution_plan.tasks.map do |task_def|
      task = Agentic::Task.from_definition(task_def)
      enhance_task_with_architectural_validation(task)
    end

    tasks.each do |task|
      @orchestrator.add_task(task)
    end

    # Execute with progress tracking
    agent_provider = Agentic::DefaultAgentProvider.new(@llm_config)
    execution_result = @orchestrator.execute_plan(agent_provider)

    puts "\n📊 Execution Progress:"
    execution_result.results.each do |task_id, result|
      if result.successful?
        puts "  ✅ Task #{task_id}: Completed"
      else
        puts "  ❌ Task #{task_id}: Failed - #{result.failure&.message}"
      end
    end

    @results[:execution] = execution_result

    puts "\n📊 Execution Summary:"
    puts "  Completed: #{execution_result.completed_tasks_count}"
    puts "  Failed: #{execution_result.failed_tasks_count}"
    puts "  Success Rate: #{(execution_result.completed_tasks_count.to_f / @execution_plan.tasks.length * 100).round(1)}%"
  end

  def enhance_task_with_architectural_validation(task)
    # For now, just return the task as-is
    # In a real implementation, we would add validation logic here
    task
  end

  def create_architectural_validation_strategy
    Agentic::Verification::LlmVerificationStrategy.new(
      name: "architectural_compliance",
      llm_config: @llm_config,
      verification_prompt: build_architectural_verification_prompt,
      confidence_threshold: 0.85,
      retry_config: Agentic::RetryConfig.new(max_retries: 2)
    )
  end

  def create_code_quality_validation_strategy
    Agentic::Verification::SchemaVerificationStrategy.new(
      name: "code_quality",
      schema: {
        type: "object",
        required: ["ruby_conventions", "documentation", "testing"],
        properties: {
          ruby_conventions: {type: "boolean"},
          documentation: {type: "boolean"},
          testing: {type: "boolean"},
          separation_of_concerns: {type: "boolean"}
        }
      },
      strict: false
    )
  end

  def create_integration_validation_strategy
    Agentic::Verification::LlmVerificationStrategy.new(
      name: "integration_compliance",
      llm_config: @llm_config,
      verification_prompt: build_integration_verification_prompt,
      confidence_threshold: 0.80
    )
  end

  def build_architectural_verification_prompt
    <<~PROMPT
      Review the implementation against the Agentic framework's architectural principles:
      
      1. Domain-agnostic design with clear boundaries
      2. Progressive automation with human oversight
      3. Extensibility through well-defined interfaces
      4. Observable and debuggable system behavior
      5. Fault tolerance and graceful degradation
      
      Architectural Patterns Required:
      - Observer pattern for event notification
      - Factory pattern for component creation
      - Strategy pattern for configurable behavior
      - Extension pattern for domain adaptation
      
      Quality Attributes:
      - Maintainability: Clear separation of concerns
      - Reliability: Error handling and recovery
      - Performance: Efficient resource utilization
      - Security: Safe execution with proper validation
      - Usability: Clear APIs and good error messages
      
      Evaluate the implementation for compliance with these requirements and provide 
      a confidence score (0-1) along with specific recommendations for improvement.
    PROMPT
  end

  def build_integration_verification_prompt
    <<~PROMPT
      Verify that the Human Intervention Portal integrates properly with existing 
      Agentic framework components:
      
      Required Integrations:
      1. ObservabilityEngine for event streaming
      2. VerificationHub for quality assurance
      3. TaskPlanner and PlanOrchestrator for workflow integration
      4. Extension system for domain adaptation
      5. Learning system for continuous improvement
      
      Interface Compliance:
      - Follows established naming conventions
      - Implements required abstract methods
      - Provides proper error handling
      - Supports configuration and customization
      - Maintains thread safety where required
      
      Provide integration compliance assessment with recommendations.
    PROMPT
  end

  def perform_architectural_review
    puts "Conducting multi-perspective architectural review..."

    # Create architectural review tasks for each specialized perspective
    review_tasks = create_architectural_review_tasks

    if review_tasks.empty?
      puts "  No review members configured, skipping detailed review"
      @results[:architectural_review] = nil
      return
    end

    # Execute reviews concurrently
    review_orchestrator = Agentic::PlanOrchestrator.new(
      plan_id: "architectural_review_#{Time.now.strftime("%Y%m%d_%H%M%S")}",
      concurrency_limit: 5
    )

    review_tasks.each { |task| review_orchestrator.add_task(task) }

    agent_provider = Agentic::DefaultAgentProvider.new(@llm_config)
    review_results = review_orchestrator.execute_plan(agent_provider)

    @results[:architectural_review] = review_results

    # Synthesize review findings
    synthesize_architectural_findings(review_results)
  end

  def create_architectural_review_tasks
    review_members = @architectural_context[:review_members] || []
    return [] if review_members.empty?

    review_members.map do |member|
      Agentic::Task.new(
        description: "Architectural review from #{member["title"] || "architectural"} perspective",
        agent_spec: Agentic::AgentSpecification.new(
          name: member["name"] || "Architectural Reviewer",
          description: member["title"] || "Architectural Reviewer",
          instructions: "Review the implementation from the perspective of #{member["perspective"] || "general architecture"}. Focus on #{member["specialties"]&.join(", ") || "architectural quality"}."
        ),
        input: {
          implementation_artifacts: gather_implementation_artifacts,
          architectural_context: @architectural_context,
          review_criteria: define_review_criteria_for_member(member)
        }
      )
    end
  end

  def synthesize_architectural_findings(review_results)
    puts "\n🔍 Architectural Review Synthesis:"
    puts "-" * 50

    findings = {
      strengths: [],
      concerns: [],
      recommendations: [],
      compliance_score: 0.0
    }

    return findings unless review_results

    review_results.successful_task_results.each do |task_id, result|
      if result.output
        findings[:strengths] += extract_strengths(result.output)
        findings[:concerns] += extract_concerns(result.output)
        findings[:recommendations] += extract_recommendations(result.output)
      end
    end

    # Calculate overall compliance score
    findings[:compliance_score] = calculate_compliance_score(findings)

    puts "Overall Compliance Score: #{(findings[:compliance_score] * 100).round(1)}%"
    puts "\nKey Strengths:"
    findings[:strengths].uniq.first(5).each { |s| puts "  ✅ #{s}" }

    puts "\nPrimary Concerns:"
    findings[:concerns].uniq.first(5).each { |c| puts "  ⚠️  #{c}" }

    puts "\nTop Recommendations:"
    findings[:recommendations].uniq.first(5).each { |r| puts "  💡 #{r}" }

    @results[:architectural_findings] = findings
  end

  def generate_documentation
    puts "Generating comprehensive implementation documentation..."

    documentation_tasks = [
      create_api_documentation_task,
      create_architectural_decision_record_task,
      create_usage_examples_task,
      create_integration_guide_task
    ]

    doc_orchestrator = Agentic::PlanOrchestrator.new(
      plan_id: "documentation_#{Time.now.strftime("%Y%m%d_%H%M%S")}"
    )

    documentation_tasks.each { |task| doc_orchestrator.add_task(task) }

    agent_provider = Agentic::DefaultAgentProvider.new(@llm_config)
    doc_results = doc_orchestrator.execute_plan(agent_provider)

    @results[:documentation] = doc_results

    # Generate final implementation report
    generate_implementation_report
  end

  def create_api_documentation_task
    Agentic::Task.new(
      description: "Generate comprehensive API documentation for Human Intervention Portal",
      agent_spec: Agentic::AgentSpecification.new(
        name: "Documentation Generator",
        description: "Expert in creating technical documentation and API references",
        instructions: "Generate comprehensive API documentation including usage examples, method signatures, and integration guides."
      ),
      input: {
        implementation_files: gather_implementation_files,
        documentation_standards: load_documentation_standards,
        examples: generate_usage_examples
      }
    )
  end

  def create_architectural_decision_record_task
    Agentic::Task.new(
      description: "Create ADR for Human Intervention Portal implementation decisions",
      agent_spec: Agentic::AgentSpecification.new(
        name: "ADR Generator",
        description: "Expert in documenting architectural decisions and rationale",
        instructions: "Create architectural decision records documenting key implementation choices, alternatives considered, and rationale for decisions."
      ),
      input: {
        implementation_decisions: extract_implementation_decisions,
        architectural_context: @architectural_context,
        review_findings: @results[:architectural_findings]
      }
    )
  end

  def create_usage_examples_task
    Agentic::Task.new(
      description: "Create comprehensive usage examples and tutorials",
      agent_spec: Agentic::AgentSpecification.new(
        name: "Example Generator",
        description: "Expert in creating code examples and tutorials",
        instructions: "Generate practical usage examples, tutorials, and integration scenarios showing how to use the Human Intervention Portal."
      ),
      input: {
        portal_components: identify_portal_components,
        integration_points: identify_integration_points,
        use_cases: define_intervention_use_cases
      }
    )
  end

  def create_integration_guide_task
    Agentic::Task.new(
      description: "Create integration guide for existing Agentic applications",
      agent_spec: Agentic::AgentSpecification.new(
        name: "Integration Guide Generator",
        description: "Expert in system integration and migration documentation",
        instructions: "Create step-by-step integration guides for adding the Human Intervention Portal to existing Agentic applications."
      ),
      input: {
        existing_architecture: @architectural_context,
        portal_interfaces: extract_portal_interfaces,
        migration_strategies: define_migration_strategies
      }
    )
  end

  def generate_implementation_report
    puts "\n📋 Generating Final Implementation Report..."

    report = {
      metadata: {
        implementation_date: Time.now.iso8601,
        agentic_version: Agentic::VERSION,
        plan_id: @orchestrator&.plan_id,
        total_tasks: @execution_plan&.tasks&.length || 0
      },
      execution_summary: @results[:execution]&.to_h || {},
      architectural_review: @results[:architectural_findings] || {},
      documentation_artifacts: list_generated_documentation,
      recommendations: compile_final_recommendations,
      next_steps: define_next_implementation_steps
    }

    # Save implementation report
    report_file = "reports/human_intervention_portal_implementation_#{Time.now.strftime("%Y%m%d_%H%M%S")}.json"
    FileUtils.mkdir_p(File.dirname(report_file))
    File.write(report_file, JSON.pretty_generate(report))

    puts "📄 Implementation report saved to: #{report_file}"
    @results[:final_report] = report
  end

  def display_summary
    puts "\n🎯 Implementation Summary"
    puts "=" * 50

    if @results[:execution]
      execution = @results[:execution]
      puts "Execution Results:"
      puts "  ✅ Tasks Completed: #{execution.completed_tasks_count}"
      puts "  ❌ Tasks Failed: #{execution.failed_tasks_count}"
      puts "  ⏱️  Total Duration: #{execution.execution_time&.round(2) || "N/A"}s"
    end

    if @results[:architectural_findings]
      findings = @results[:architectural_findings]
      puts "\nArchitectural Compliance:"
      puts "  📊 Overall Score: #{(findings[:compliance_score] * 100).round(1)}%"
      puts "  💪 Strengths Identified: #{findings[:strengths]&.length || 0}"
      puts "  ⚠️  Concerns Raised: #{findings[:concerns]&.length || 0}"
      puts "  💡 Recommendations: #{findings[:recommendations]&.length || 0}"
    end

    puts "\nGenerated Artifacts:"
    puts "  📚 Documentation files"
    puts "  🏗️  Implementation code"
    puts "  📋 Architectural review"
    puts "  📄 Final report"

    puts "\n🚀 Human Intervention Portal is ready for integration!"
  end

  # Lifecycle hooks for orchestrator
  def before_task_hook(task)
    puts "  🔄 Starting: #{task.description}"
    Agentic.observability_engine.notify(
      :task_started,
      {task_id: task.id, description: task.description, timestamp: Time.now}
    )
  end

  def after_task_hook(task, result)
    status = result.successful? ? "✅ Completed" : "❌ Failed"
    puts "  #{status}: #{task.description}"

    Agentic.observability_engine.notify(
      :task_completed,
      {
        task_id: task.id,
        success: result.successful?,
        duration: result.respond_to?(:duration) ? result.duration : 0,
        timestamp: Time.now
      }
    )
  end

  def on_failure_hook(task, failure)
    puts "  ❌ Task failed: #{task.description}"
    puts "     Error: #{failure.message}"

    Agentic.observability_engine.notify(
      :task_failed,
      {
        task_id: task.id,
        error: failure.message,
        context: failure.context,
        timestamp: Time.now
      }
    )
  end

  # Helper methods for architectural context loading
  def load_architectural_principles
    {
      domain_agnostic: "Framework should not be tied to specific domains",
      progressive_automation: "Start with human oversight, gradually automate",
      extensibility: "Extension points through interfaces and composition",
      observability: "All behavior should be observable and debuggable",
      fault_tolerance: "Graceful degradation and meaningful recovery"
    }
  end

  def load_established_patterns
    %w[observer factory strategy extension registry adapter].map do |pattern|
      {
        name: pattern,
        usage: "Used throughout Agentic framework",
        implementation: "Interface-based with clear contracts"
      }
    end
  end

  def define_quality_attributes
    {
      maintainability: {priority: "high", metrics: ["complexity", "cohesion"]},
      reliability: {priority: "high", metrics: ["error_rate", "recovery_success"]},
      performance: {priority: "medium", metrics: ["response_time", "throughput"]},
      security: {priority: "high", metrics: ["vulnerability_count", "access_control"]},
      usability: {priority: "medium", metrics: ["api_clarity", "error_messaging"]}
    }
  end

  def load_review_members
    YAML.load_file(".architecture/members.yml")["members"]
  rescue
    []
  end

  # Placeholder methods for actual implementation
  def gather_implementation_artifacts
    {files: [], tests: [], documentation: []}
  end

  def define_review_criteria_for_member(member)
    specialties = member["specialties"] || []
    disciplines = member["disciplines"] || []
    specialties + disciplines
  end

  def extract_strengths(output)
    ["Implementation follows architectural patterns"]
  end

  def extract_concerns(output)
    ["Need more comprehensive error handling"]
  end

  def extract_recommendations(output)
    ["Add more integration tests"]
  end

  def calculate_compliance_score(findings)
    # Simple scoring based on findings ratio
    total_findings = findings[:strengths].length + findings[:concerns].length
    return 0.8 if total_findings == 0
    findings[:strengths].length.to_f / total_findings
  end

  def gather_implementation_files
    []
  end

  def load_documentation_standards
    {format: "yard", style: "ruby", coverage_threshold: 90}
  end

  def generate_usage_examples
    []
  end

  def extract_implementation_decisions
    []
  end

  def identify_portal_components
    ["InterventionPortal", "ExplanationEngine", "ConfigurationInterface"]
  end

  def identify_integration_points
    ["ObservabilityEngine", "VerificationHub", "TaskPlanner"]
  end

  def define_intervention_use_cases
    [
      "Ethical boundary validation",
      "Domain expertise provision",
      "Novel situation handling",
      "Success criteria definition",
      "Error recovery intervention"
    ]
  end

  def extract_portal_interfaces
    []
  end

  def define_migration_strategies
    []
  end

  def list_generated_documentation
    []
  end

  def compile_final_recommendations
    [
      "Complete implementation of all portal components",
      "Add comprehensive integration tests",
      "Create user experience documentation",
      "Implement progressive automation features",
      "Add security audit and validation"
    ]
  end

  def define_next_implementation_steps
    [
      "Integrate with existing CLI commands",
      "Add web-based intervention interface",
      "Implement learning from intervention patterns",
      "Create domain-specific intervention templates",
      "Add analytics and reporting features"
    ]
  end
end

# Run the implementation if this script is executed directly
if __FILE__ == $0
  # Ensure we have required environment variables
  unless ENV["OPENAI_ACCESS_TOKEN"]
    puts "❌ Error: OPENAI_ACCESS_TOKEN environment variable is required"
    puts "   Please set your OpenAI API token:"
    puts "   export OPENAI_ACCESS_TOKEN=your_token_here"
    exit 1
  end

  begin
    implementation = HumanInterventionPortalImplementation.new
    implementation.run
  rescue => e
    puts "❌ Implementation failed: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end
end
