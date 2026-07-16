# frozen_string_literal: true

RSpec.describe Agentic::Observability::EventContext do
  let(:workflow_context) { described_class.new(context_type: described_class::TYPE_WORKFLOW, name: "test_workflow") }

  describe "initialization" do
    it "creates context with required attributes" do
      expect(workflow_context.context_id).to be_a(String)
      expect(workflow_context.correlation_id).to be_a(String)
      expect(workflow_context.context_type).to eq(described_class::TYPE_WORKFLOW)
      expect(workflow_context.name).to eq("test_workflow")
      expect(workflow_context.state).to eq(described_class::STATE_CREATED)
      expect(workflow_context.created_at).to be_a(Float)
      expect(workflow_context.updated_at).to be_a(Float)
    end

    it "generates unique context and correlation IDs" do
      context1 = described_class.new
      context2 = described_class.new

      expect(context1.context_id).not_to eq(context2.context_id)
      expect(context1.correlation_id).not_to eq(context2.correlation_id)
    end

    it "accepts initial metadata and tags" do
      context = described_class.new(
        metadata: {priority: "high", owner: "system"},
        tags: ["critical", "automated"]
      )

      expect(context.get_metadata("priority")).to eq("high")
      expect(context.get_metadata("owner")).to eq("system")
      expect(context.has_tag?("critical")).to be true
      expect(context.has_tag?("automated")).to be true
    end
  end

  describe "hierarchical relationships" do
    let(:plan_context) { workflow_context.create_child(context_type: described_class::TYPE_PLAN, name: "test_plan") }
    let(:task_context) { plan_context.create_child(context_type: described_class::TYPE_TASK, name: "test_task") }

    it "creates parent-child relationships" do
      expect(plan_context.parent_context).to eq(workflow_context)
      expect(workflow_context.children).to include(plan_context)
      expect(task_context.parent_context).to eq(plan_context)
      expect(plan_context.children).to include(task_context)
    end

    it "shares correlation ID across hierarchy" do
      expect(plan_context.correlation_id).to eq(workflow_context.correlation_id)
      expect(task_context.correlation_id).to eq(workflow_context.correlation_id)
    end

    it "builds correct hierarchy paths" do
      expect(workflow_context.hierarchy_path).to eq([workflow_context.context_id])
      expect(plan_context.hierarchy_path).to eq([workflow_context.context_id, plan_context.context_id])
      expect(task_context.hierarchy_path).to eq([workflow_context.context_id, plan_context.context_id, task_context.context_id])
    end

    it "calculates correct depth" do
      expect(workflow_context.depth).to eq(0)
      expect(plan_context.depth).to eq(1)
      expect(task_context.depth).to eq(2)
    end

    it "identifies root context" do
      expect(workflow_context.root).to eq(workflow_context)
      expect(plan_context.root).to eq(workflow_context)
      expect(task_context.root).to eq(workflow_context)
    end

    it "finds siblings correctly" do
      sibling_task = plan_context.create_child(context_type: described_class::TYPE_TASK, name: "sibling_task")

      expect(task_context.siblings).to include(sibling_task)
      expect(sibling_task.siblings).to include(task_context)
      expect(task_context.siblings).not_to include(task_context)
    end

    it "identifies ancestor and descendant relationships" do
      expect(workflow_context.ancestor_of?(task_context)).to be true
      expect(task_context.descendant_of?(workflow_context)).to be true
      expect(task_context.ancestor_of?(workflow_context)).to be false
      expect(workflow_context.descendant_of?(task_context)).to be false
    end

    it "retrieves children recursively" do
      agent_context = task_context.create_child(context_type: described_class::TYPE_AGENT, name: "test_agent")

      direct_children = workflow_context.children(recursive: false)
      all_children = workflow_context.children(recursive: true)

      expect(direct_children).to include(plan_context)
      expect(direct_children).not_to include(task_context)
      expect(all_children).to include(plan_context, task_context, agent_context)
    end
  end

  describe "state management" do
    it "transitions through states correctly" do
      expect(workflow_context.created?).to be true

      workflow_context.activate
      expect(workflow_context.active?).to be true
      expect(workflow_context.created?).to be false

      workflow_context.suspend
      expect(workflow_context.suspended?).to be true

      workflow_context.resume
      expect(workflow_context.active?).to be true

      workflow_context.complete
      expect(workflow_context.completed?).to be true
      expect(workflow_context.terminal_state?).to be true
    end

    it "records state history" do
      workflow_context.activate
      workflow_context.suspend
      workflow_context.resume
      workflow_context.complete

      state_history = workflow_context.instance_variable_get(:@state_history)
      expect(state_history.size).to eq(5) # created, activated, suspended, resumed, completed
      expect(state_history.map { |h| h[:state] }).to eq([
        described_class::STATE_CREATED,
        described_class::STATE_ACTIVE,
        described_class::STATE_SUSPENDED,
        described_class::STATE_ACTIVE,
        described_class::STATE_COMPLETED
      ])
    end

    it "activates child contexts when parent is activated" do
      child_context = workflow_context.create_child(context_type: described_class::TYPE_PLAN)

      workflow_context.activate

      expect(child_context.active?).to be true
    end

    it "completes child contexts when parent is completed" do
      child_context = workflow_context.create_child(context_type: described_class::TYPE_PLAN)

      workflow_context.complete

      expect(child_context.completed?).to be true
    end

    it "fails child contexts when parent fails" do
      child_context = workflow_context.create_child(context_type: described_class::TYPE_PLAN)

      workflow_context.fail(metadata: {error: "system failure"})

      expect(child_context.failed?).to be true
    end

    it "allows selective child failure behavior" do
      child_context = workflow_context.create_child(context_type: described_class::TYPE_PLAN)

      workflow_context.fail(metadata: {error: "system failure", fail_children: false})

      expect(workflow_context.failed?).to be true
      expect(child_context.failed?).to be false
    end
  end

  describe "metadata management" do
    it "stores and retrieves metadata" do
      workflow_context.set_metadata("priority", "high")
      workflow_context.set_metadata("deadline", "2024-12-31")

      expect(workflow_context.get_metadata("priority")).to eq("high")
      expect(workflow_context.get_metadata("deadline")).to eq("2024-12-31")
      expect(workflow_context.get_metadata("nonexistent", default: "default_value")).to eq("default_value")
    end

    it "merges metadata" do
      workflow_context.set_metadata("existing", "value")
      workflow_context.merge_metadata({new_key: "new_value", another_key: "another_value"})

      expect(workflow_context.get_metadata("existing")).to eq("value")
      expect(workflow_context.get_metadata("new_key")).to eq("new_value")
      expect(workflow_context.get_metadata("another_key")).to eq("another_value")
    end

    it "deletes metadata" do
      workflow_context.set_metadata("to_delete", "value")
      expect(workflow_context.get_metadata("to_delete")).to eq("value")

      workflow_context.delete_metadata("to_delete")
      expect(workflow_context.get_metadata("to_delete")).to be_nil
    end
  end

  describe "tag management" do
    it "manages tags" do
      expect(workflow_context.has_tag?("test")).to be false

      workflow_context.add_tag("test")
      expect(workflow_context.has_tag?("test")).to be true

      workflow_context.add_tags("priority", "automated")
      expect(workflow_context.has_tag?("priority")).to be true
      expect(workflow_context.has_tag?("automated")).to be true

      workflow_context.remove_tag("test")
      expect(workflow_context.has_tag?("test")).to be false
    end

    it "prevents duplicate tags" do
      workflow_context.add_tag("test")
      workflow_context.add_tag("test")

      tags = workflow_context.instance_variable_get(:@tags)
      expect(tags.count("test")).to eq(1)
    end

    it "clears all tags" do
      workflow_context.add_tags("tag1", "tag2", "tag3")
      expect(workflow_context.instance_variable_get(:@tags).size).to eq(3)

      workflow_context.clear_tags
      expect(workflow_context.instance_variable_get(:@tags)).to be_empty
    end
  end

  describe "extension system" do
    let(:test_extension) { double("TestExtension", process: "result") }

    it "registers and retrieves extensions" do
      workflow_context.register_extension("test_ext", test_extension)

      expect(workflow_context.has_extension?("test_ext")).to be true
      expect(workflow_context.get_extension("test_ext")).to eq(test_extension)
    end

    it "removes extensions" do
      workflow_context.register_extension("test_ext", test_extension)
      expect(workflow_context.has_extension?("test_ext")).to be true

      workflow_context.remove_extension("test_ext")
      expect(workflow_context.has_extension?("test_ext")).to be false
    end
  end

  describe "metrics tracking" do
    it "records and retrieves custom metrics" do
      workflow_context.record_metric("processing_time", 1.5)
      workflow_context.record_metric("processing_time", 2.0)
      workflow_context.record_metric("memory_usage", 100)

      processing_times = workflow_context.get_metric("processing_time")
      expect(processing_times.size).to eq(2)
      expect(processing_times.map { |m| m[:value] }).to eq([1.5, 2.0])

      expect(workflow_context.get_latest_metric("processing_time")).to eq(2.0)
      expect(workflow_context.get_latest_metric("memory_usage")).to eq(100)
    end

    it "calculates duration for terminal states" do
      Time.now.to_f
      workflow_context.activate
      sleep(0.01) # Small delay
      workflow_context.complete

      duration = workflow_context.duration
      expect(duration).to be > 0
      expect(duration).to be < 1.0 # Should be very small
    end

    it "calculates time spent in each state" do
      workflow_context.activate
      sleep(0.01)
      workflow_context.suspend
      sleep(0.01)
      workflow_context.resume
      sleep(0.01)
      workflow_context.complete

      active_time = workflow_context.time_in_state(described_class::STATE_ACTIVE)
      suspended_time = workflow_context.time_in_state(described_class::STATE_SUSPENDED)

      expect(active_time).to be > 0
      expect(suspended_time).to be > 0
      expect(active_time).to be > suspended_time # Was active longer (twice)
    end
  end

  describe "context queries" do
    let(:plan_context) { workflow_context.create_child(context_type: described_class::TYPE_PLAN, name: "test_plan") }
    let(:task_context) { plan_context.create_child(context_type: described_class::TYPE_TASK, name: "test_task") }
    let(:agent_context) { plan_context.create_child(context_type: described_class::TYPE_AGENT, name: "test_agent") }

    before do
      task_context.add_tag("important")
      agent_context.add_tag("automated")
      task_context.activate
      agent_context.complete
    end

    it "finds children by type" do
      task_contexts = plan_context.find_children_by_type(described_class::TYPE_TASK)
      agent_contexts = plan_context.find_children_by_type(described_class::TYPE_AGENT)

      expect(task_contexts).to include(task_context)
      expect(agent_contexts).to include(agent_context)
    end

    it "finds children by tag" do
      important_contexts = plan_context.find_children_by_tag("important")
      automated_contexts = plan_context.find_children_by_tag("automated")

      expect(important_contexts).to include(task_context)
      expect(automated_contexts).to include(agent_context)
    end

    it "finds children by state" do
      active_contexts = plan_context.find_children_by_state(described_class::STATE_ACTIVE)
      completed_contexts = plan_context.find_children_by_state(described_class::STATE_COMPLETED)

      expect(active_contexts).to include(task_context)
      expect(completed_contexts).to include(agent_context)
    end

    it "finds descendants by ID" do
      found_task = workflow_context.find_descendant_by_id(task_context.context_id)
      found_agent = workflow_context.find_descendant_by_id(agent_context.context_id)

      expect(found_task).to eq(task_context)
      expect(found_agent).to eq(agent_context)
    end
  end

  describe "serialization" do
    let(:complex_context) do
      context = described_class.new(
        context_type: described_class::TYPE_WORKFLOW,
        name: "complex_workflow",
        metadata: {priority: "high", deadline: "2024-12-31"},
        tags: ["important", "automated"]
      )

      child = context.create_child(context_type: described_class::TYPE_PLAN, name: "child_plan")
      child.add_tag("child_tag")
      child.set_metadata("child_key", "child_value")

      context.activate
      child.complete

      context
    end

    it "serializes to hash without children" do
      hash = complex_context.to_hash(include_children: false)

      expect(hash).to include(
        :context_id,
        :correlation_id,
        :context_type,
        :name,
        :state,
        :hierarchy_path,
        :created_at,
        :updated_at,
        :metadata,
        :tags
      )

      expect(hash[:children]).to be_nil
    end

    it "serializes to hash with children" do
      hash = complex_context.to_hash(include_children: true)

      expect(hash[:children]).to be_an(Array)
      expect(hash[:children].size).to eq(1)

      child_hash = hash[:children].first
      expect(child_hash[:name]).to eq("child_plan")
      expect(child_hash[:context_type]).to eq(described_class::TYPE_PLAN)
      expect(child_hash[:tags]).to include("child_tag")
    end

    it "serializes to JSON" do
      json = complex_context.to_json(include_children: true)
      expect(json).to be_a(String)

      parsed = JSON.parse(json, symbolize_names: true)
      expect(parsed[:name]).to eq("complex_workflow")
      expect(parsed[:children]).to be_an(Array)
    end

    it "deserializes from hash" do
      original_hash = complex_context.to_hash(include_children: true)
      deserialized = described_class.from_hash(original_hash)

      expect(deserialized.name).to eq(complex_context.name)
      expect(deserialized.context_id).to eq(complex_context.context_id)
      expect(deserialized.correlation_id).to eq(complex_context.correlation_id)
      expect(deserialized.children.size).to eq(1)
      expect(deserialized.children.first.name).to eq("child_plan")
    end

    it "deserializes from JSON" do
      original_json = complex_context.to_json(include_children: true)
      deserialized = described_class.from_json(original_json)

      expect(deserialized.name).to eq(complex_context.name)
      expect(deserialized.children.size).to eq(1)
    end
  end

  describe "Domain Expert requirements (Jamie Chen)" do
    it "supports agent hierarchy tracking" do
      # Create orchestrator -> planner -> worker hierarchy
      orchestrator = described_class.new(
        context_type: described_class::TYPE_AGENT,
        name: "orchestrator_agent",
        metadata: {role: "coordinator", capabilities: ["planning", "delegation"]},
        tags: ["primary", "coordinator"]
      )

      planner = orchestrator.create_child(
        context_type: described_class::TYPE_AGENT,
        name: "planner_agent",
        metadata: {role: "planner", parent_agent: orchestrator.context_id},
        tags: ["planner", "child"]
      )

      worker = planner.create_child(
        context_type: described_class::TYPE_AGENT,
        name: "worker_agent",
        metadata: {role: "executor", parent_agent: planner.context_id},
        tags: ["worker", "leaf"]
      )

      # Verify hierarchy tracking
      expect(orchestrator.depth).to eq(0)
      expect(planner.depth).to eq(1)
      expect(worker.depth).to eq(2)

      # Verify parent-child relationships
      expect(planner.get_metadata("parent_agent")).to eq(orchestrator.context_id)
      expect(worker.get_metadata("parent_agent")).to eq(planner.context_id)

      # Verify correlation across hierarchy
      expect([orchestrator, planner, worker].map(&:correlation_id).uniq.size).to eq(1)

      # Test ancestor/descendant queries
      expect(orchestrator.ancestor_of?(worker)).to be true
      expect(worker.descendant_of?(orchestrator)).to be true
    end

    it "enables workflow stage coordination" do
      workflow = described_class.new(
        context_type: described_class::TYPE_WORKFLOW,
        name: "multi_stage_workflow",
        metadata: {total_stages: 3}
      )

      # Create workflow stages
      planning_stage = workflow.create_child(
        context_type: described_class::TYPE_PLAN,
        name: "planning_stage",
        metadata: {stage_number: 1, stage_type: "planning"},
        tags: ["stage", "planning"]
      )

      execution_stage = workflow.create_child(
        context_type: described_class::TYPE_TASK,
        name: "execution_stage",
        metadata: {stage_number: 2, stage_type: "execution"},
        tags: ["stage", "execution"]
      )

      verification_stage = workflow.create_child(
        context_type: described_class::TYPE_VERIFICATION,
        name: "verification_stage",
        metadata: {stage_number: 3, stage_type: "verification"},
        tags: ["stage", "verification"]
      )

      # Simulate stage progression
      workflow.activate
      planning_stage.complete
      execution_stage.activate
      execution_stage.complete
      verification_stage.activate
      verification_stage.complete
      workflow.complete

      # Verify stage coordination
      expect(workflow.find_children_by_tag("stage").size).to eq(3)
      expect(workflow.find_children_by_state(described_class::STATE_COMPLETED).size).to eq(3)

      # Test workflow completion tracking
      expect(workflow.completed?).to be true
      expect(workflow.duration).to be > 0
    end

    it "supports complex multi-agent decision processes" do
      # Create decision-making context
      decision_context = described_class.new(
        context_type: described_class::TYPE_WORKFLOW,
        name: "multi_agent_decision",
        metadata: {decision_type: "consensus", required_agents: 3}
      )

      # Create participating agents
      agents = 3.times.map do |i|
        agent = decision_context.create_child(
          context_type: described_class::TYPE_AGENT,
          name: "decision_agent_#{i}",
          metadata: {agent_role: "voter", vote: nil},
          tags: ["decision_maker", "agent_#{i}"]
        )
        agent.activate
        agent
      end

      # Simulate decision process
      agents[0].set_metadata("vote", "approve")
      agents[0].record_metric("confidence", 0.8)

      agents[1].set_metadata("vote", "approve")
      agents[1].record_metric("confidence", 0.9)

      agents[2].set_metadata("vote", "reject")
      agents[2].record_metric("confidence", 0.6)

      # Complete agents after voting
      agents.each(&:complete)

      # Analyze decision outcome
      votes = agents.map { |agent| agent.get_metadata("vote") }
      approvals = votes.count("approve")
      rejections = votes.count("reject")

      expect(approvals).to eq(2)
      expect(rejections).to eq(1)

      # Verify all agents completed their decision process
      completed_agents = decision_context.find_children_by_state(described_class::STATE_COMPLETED)
      expect(completed_agents.size).to eq(3)
    end
  end

  describe "Agent Systems Engineer requirements (Taylor Kim)" do
    it "supports plugin architecture through extensions" do
      # Create context with domain-specific extensions
      task_context = described_class.new(
        context_type: described_class::TYPE_TASK,
        name: "extensible_task"
      )

      # Mock extensions for different capabilities
      data_processor = double("DataProcessor", process: "processed_data", validate: true)
      security_validator = double("SecurityValidator", scan: "clean", authorize: true)
      performance_monitor = double("PerformanceMonitor", track: "metrics", analyze: "report")

      # Register extensions
      task_context.register_extension("data_processor", data_processor)
      task_context.register_extension("security_validator", security_validator)
      task_context.register_extension("performance_monitor", performance_monitor)

      # Verify extensions are accessible
      expect(task_context.has_extension?("data_processor")).to be true
      expect(task_context.get_extension("data_processor")).to eq(data_processor)

      # Test extension functionality
      expect(task_context.get_extension("data_processor").process).to eq("processed_data")
      expect(task_context.get_extension("security_validator").authorize).to be true

      # Verify extensions don't interfere with serialization
      serialized = task_context.to_hash
      expect(serialized[:extensions]).to eq(["data_processor", "security_validator", "performance_monitor"])
    end

    it "provides extensible metadata system for domain adaptation" do
      # Create agent context with domain-specific metadata structure
      agent_context = described_class.new(
        context_type: described_class::TYPE_AGENT,
        name: "domain_specific_agent"
      )

      # Add nested domain metadata
      agent_context.merge_metadata({
        "domain" => {
          "type" => "financial_analysis",
          "regulations" => ["SOX", "GDPR", "PCI-DSS"],
          "risk_level" => "high"
        },
        "capabilities" => {
          "analysis_types" => ["trend", "risk", "compliance"],
          "data_sources" => ["internal", "external", "regulatory"],
          "output_formats" => ["report", "dashboard", "alert"]
        },
        "compliance" => {
          "required_approvals" => ["security", "legal", "finance"],
          "audit_trail" => true,
          "data_retention" => "7_years"
        }
      })

      # Verify nested metadata accessibility
      expect(agent_context.get_metadata("domain")["type"]).to eq("financial_analysis")
      expect(agent_context.get_metadata("capabilities")["analysis_types"]).to include("trend", "risk", "compliance")
      expect(agent_context.get_metadata("compliance")["audit_trail"]).to be true

      # Test metadata extensibility
      agent_context.set_metadata("runtime_config", {
        "performance_mode" => "optimized",
        "cache_enabled" => true,
        "parallel_processing" => 4
      })

      expect(agent_context.get_metadata("runtime_config")["performance_mode"]).to eq("optimized")
    end

    it "supports serialization for distributed agent systems" do
      # Create distributed workflow context
      workflow = described_class.new(
        context_type: described_class::TYPE_WORKFLOW,
        name: "distributed_workflow",
        metadata: {
          "distribution" => {
            "nodes" => ["node-1", "node-2", "node-3"],
            "replication" => "3x",
            "consistency" => "eventual"
          }
        }
      )

      # Create distributed tasks
      workflow.create_child(
        context_type: described_class::TYPE_TASK,
        name: "remote_task_node_1",
        metadata: {
          "execution" => {
            "node" => "node-1",
            "remote" => true,
            "endpoint" => "https://node-1.example.com/execute"
          }
        },
        tags: ["remote", "node-1"]
      )

      workflow.create_child(
        context_type: described_class::TYPE_TASK,
        name: "remote_task_node_2",
        metadata: {
          "execution" => {
            "node" => "node-2",
            "remote" => true,
            "endpoint" => "https://node-2.example.com/execute"
          }
        },
        tags: ["remote", "node-2"]
      )

      # Simulate serialization for remote transmission
      serialized_workflow = workflow.to_json(include_children: true)
      expect(serialized_workflow).to be_a(String)

      # Verify deserialization preserves structure
      deserialized_workflow = described_class.from_json(serialized_workflow)
      expect(deserialized_workflow.children.size).to eq(2)

      remote_tasks = deserialized_workflow.find_children_by_tag("remote")
      expect(remote_tasks.size).to eq(2)

      node_1_tasks = deserialized_workflow.find_children_by_tag("node-1")
      expect(node_1_tasks.first.get_metadata("execution")["endpoint"]).to include("node-1.example.com")
    end

    it "provides lifecycle management for long-running agent workflows" do
      # Create long-running workflow
      long_workflow = described_class.new(
        context_type: described_class::TYPE_WORKFLOW,
        name: "long_running_workflow",
        metadata: {"expected_duration" => "hours", "checkpoint_interval" => 300}
      )

      # Create phases with different lifecycle requirements
      phases = ["initialization", "data_collection", "processing", "analysis", "reporting"].map do |phase_name|
        phase = long_workflow.create_child(
          context_type: described_class::TYPE_PLAN,
          name: "#{phase_name}_phase",
          metadata: {"phase_type" => phase_name, "can_suspend" => true},
          tags: ["phase", phase_name]
        )
        phase
      end

      # Simulate workflow execution with suspensions and resumptions
      long_workflow.activate

      # Complete first two phases
      phases[0].activate
      phases[0].complete

      phases[1].activate
      phases[1].complete

      # Suspend during processing phase (e.g., for maintenance)
      phases[2].activate
      phases[2].suspend

      # Verify suspension state
      expect(phases[2].suspended?).to be true
      expect(phases[2].time_in_state(described_class::STATE_SUSPENDED)).to be >= 0

      # Resume and complete
      phases[2].resume
      expect(phases[2].active?).to be true

      phases[2].complete
      phases[3].activate
      phases[3].complete
      phases[4].activate
      phases[4].complete

      # Complete workflow
      long_workflow.complete

      # Verify lifecycle tracking
      expect(long_workflow.completed?).to be true
      expect(phases.all?(&:completed?)).to be true

      # Verify state history preservation
      processing_phase = phases[2]
      state_history = processing_phase.instance_variable_get(:@state_history)
      states_experienced = state_history.map { |h| h[:state] }

      expect(states_experienced).to include(
        described_class::STATE_CREATED,
        described_class::STATE_ACTIVE,
        described_class::STATE_SUSPENDED,
        described_class::STATE_ACTIVE,
        described_class::STATE_COMPLETED
      )
    end
  end
end

RSpec.describe Agentic::Observability::EventContextRegistry do
  let(:registry) { described_class.new }
  let(:workflow_context) { Agentic::Observability::EventContext.new(context_type: Agentic::Observability::EventContext::TYPE_WORKFLOW, name: "test_workflow") }
  let(:task_context) { workflow_context.create_child(context_type: Agentic::Observability::EventContext::TYPE_TASK, name: "test_task") }

  before do
    task_context.add_tags("important", "automated")
  end

  describe "context registration and lookup" do
    it "registers and finds contexts" do
      registry.register(workflow_context)
      registry.register(task_context)

      expect(registry.find(workflow_context.context_id)).to eq(workflow_context)
      expect(registry.find(task_context.context_id)).to eq(task_context)
    end

    it "finds contexts by correlation ID" do
      registry.register(workflow_context)
      registry.register(task_context)

      correlated_contexts = registry.find_by_correlation(workflow_context.correlation_id)
      expect(correlated_contexts).to include(workflow_context, task_context)
    end

    it "finds contexts by type" do
      registry.register(workflow_context)
      registry.register(task_context)

      workflow_contexts = registry.find_by_type(Agentic::Observability::EventContext::TYPE_WORKFLOW)
      task_contexts = registry.find_by_type(Agentic::Observability::EventContext::TYPE_TASK)

      expect(workflow_contexts).to include(workflow_context)
      expect(task_contexts).to include(task_context)
    end

    it "finds contexts by tag" do
      registry.register(task_context)

      important_contexts = registry.find_by_tag("important")
      automated_contexts = registry.find_by_tag("automated")

      expect(important_contexts).to include(task_context)
      expect(automated_contexts).to include(task_context)
    end
  end

  describe "context cleanup" do
    it "cleans up old completed contexts" do
      old_context = Agentic::Observability::EventContext.new(name: "old_context")
      old_context.complete

      # Make context appear old
      old_updated_at = Time.now.to_f - 7200 # 2 hours ago
      old_context.instance_variable_set(:@updated_at, old_updated_at)

      new_context = Agentic::Observability::EventContext.new(name: "new_context")
      new_context.complete

      registry.register(old_context)
      registry.register(new_context)

      # Cleanup contexts older than 1 hour
      cleaned_count = registry.cleanup(max_age_seconds: 3600)

      expect(cleaned_count).to eq(1)
      expect(registry.find(old_context.context_id)).to be_nil
      expect(registry.find(new_context.context_id)).to eq(new_context)
    end
  end

  describe "registry statistics" do
    it "provides comprehensive statistics" do
      registry.register(workflow_context)
      registry.register(task_context)

      stats = registry.statistics

      expect(stats[:total_contexts]).to eq(2)
      expect(stats[:correlations]).to eq(1) # Both contexts share correlation ID
      expect(stats[:types]).to include(
        Agentic::Observability::EventContext::TYPE_WORKFLOW,
        Agentic::Observability::EventContext::TYPE_TASK
      )
      expect(stats[:tags]).to eq(2) # "important" and "automated"
    end
  end
end
