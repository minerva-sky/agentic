# frozen_string_literal: true

require "spec_helper"

RSpec.describe "EventContext Integration", type: :integration do
  let(:observability_engine) do
    Agentic::ObservabilityEngine.new(
      enable_advanced_dispatching: true,
      dispatcher_config: {
        enable_priority_routing: false,
        enable_pipeline_integration: false
      }
    )
  end
  let(:context_registry) { Agentic::Observability::EventContextRegistry.new }

  describe "hierarchical correlation tracking" do
    it "tracks events across complex agent hierarchies" do
      # Create hierarchical context structure
      workflow_context = Agentic::Observability::EventContext.new(
        context_type: Agentic::Observability::EventContext::TYPE_WORKFLOW,
        name: "complex_agent_workflow"
      )

      orchestrator_context = workflow_context.create_child(
        context_type: Agentic::Observability::EventContext::TYPE_AGENT,
        name: "orchestrator_agent",
        metadata: {role: "coordinator"},
        tags: ["primary", "orchestrator"]
      )

      planner_context = orchestrator_context.create_child(
        context_type: Agentic::Observability::EventContext::TYPE_AGENT,
        name: "planner_agent",
        metadata: {role: "planner", parent: orchestrator_context.context_id},
        tags: ["secondary", "planner"]
      )

      worker_contexts = 3.times.map do |i|
        planner_context.create_child(
          context_type: Agentic::Observability::EventContext::TYPE_AGENT,
          name: "worker_agent_#{i}",
          metadata: {role: "executor", worker_id: i, parent: planner_context.context_id},
          tags: ["worker", "executor"]
        )
      end

      # Register all contexts
      [workflow_context, orchestrator_context, planner_context, *worker_contexts].each do |context|
        context_registry.register(context)
      end

      # Track events with correlation
      correlated_events = []
      observer = double("CorrelationObserver")
      allow(observer).to receive(:update) do |type, source, event|
        correlated_events << {
          type: type,
          context_id: event[:correlation_context][:context_id],
          context_name: event[:correlation_context][:context_name],
          context_depth: event[:correlation_context][:context_depth],
          hierarchy_path: event[:correlation_context][:hierarchy_path],
          parent_context_id: event[:correlation_context][:parent_context_id]
        }
      end

      observability_engine.event_dispatcher.add_observer(observer)

      # Simulate complex workflow execution with hierarchical events
      workflow_context.activate
      observability_engine.notify(
        :workflow_started,
        data: {workflow_type: "complex_coordination"},
        event_context: workflow_context
      )

      orchestrator_context.activate
      observability_engine.notify(
        :orchestrator_initialized,
        data: {capabilities: ["planning", "delegation", "monitoring"]},
        event_context: orchestrator_context
      )

      planner_context.activate
      observability_engine.notify(
        :planning_started,
        data: {strategy: "divide_and_conquer", tasks: 3},
        event_context: planner_context
      )

      # Workers execute tasks
      worker_contexts.each_with_index do |worker_context, i|
        worker_context.activate
        observability_engine.notify(
          :task_assigned,
          data: {task_id: "task_#{i}", complexity: "medium"},
          event_context: worker_context
        )

        observability_engine.notify(
          :task_progress,
          data: {task_id: "task_#{i}", progress: 50},
          event_context: worker_context
        )

        worker_context.complete
        observability_engine.notify(
          :task_completed,
          data: {task_id: "task_#{i}", result: "success", duration: 1.5},
          event_context: worker_context
        )
      end

      # Complete hierarchy
      planner_context.complete
      observability_engine.notify(
        :planning_completed,
        data: {total_tasks: 3, success_rate: 1.0},
        event_context: planner_context
      )

      orchestrator_context.complete
      observability_engine.notify(
        :orchestration_completed,
        data: {agents_coordinated: 4, total_duration: 5.2},
        event_context: orchestrator_context
      )

      workflow_context.complete
      observability_engine.notify(
        :workflow_completed,
        data: {status: "success", total_agents: 5},
        event_context: workflow_context
      )

      # Validate hierarchical correlation
      # Events: 1 workflow_started + 1 orchestrator + 1 planner_started + 9 worker + 1 planner_completed + 1 orchestrator_completed + 1 workflow_completed = 15
      expect(correlated_events.size).to eq(15)

      # All events should share the same correlation ID (from workflow root)
      correlation_ids = correlated_events.map { |e| e[:context_id] }.uniq
      expect(correlation_ids.size).to be > 1 # Different context IDs

      # Verify hierarchy paths are properly tracked
      workflow_events = correlated_events.select { |e| e[:context_depth] == 0 }
      orchestrator_events = correlated_events.select { |e| e[:context_depth] == 1 }
      planner_events = correlated_events.select { |e| e[:context_depth] == 2 }
      worker_events = correlated_events.select { |e| e[:context_depth] == 3 }

      expect(workflow_events.size).to eq(2) # start + complete
      expect(orchestrator_events.size).to eq(2) # init + complete
      expect(planner_events.size).to eq(2) # start + complete
      expect(worker_events.size).to eq(9) # 3 workers × 3 events each

      # Verify parent-child relationships in events
      worker_events.each do |worker_event|
        expect(worker_event[:parent_context_id]).to eq(planner_context.context_id)
      end
    end

    it "supports workflow stage coordination through context transitions" do
      # Create workflow with stage-based contexts
      pipeline_workflow = Agentic::Observability::EventContext.new(
        context_type: Agentic::Observability::EventContext::TYPE_WORKFLOW,
        name: "data_pipeline_workflow",
        metadata: {pipeline_type: "etl", stages: 5}
      )

      stages = [
        {name: "ingestion", type: Agentic::Observability::EventContext::TYPE_TASK},
        {name: "validation", type: Agentic::Observability::EventContext::TYPE_VERIFICATION},
        {name: "transformation", type: Agentic::Observability::EventContext::TYPE_TASK},
        {name: "analysis", type: Agentic::Observability::EventContext::TYPE_CAPABILITY},
        {name: "output", type: Agentic::Observability::EventContext::TYPE_TASK}
      ].map do |stage_info|
        pipeline_workflow.create_child(
          context_type: stage_info[:type],
          name: "#{stage_info[:name]}_stage",
          metadata: {stage_name: stage_info[:name], dependencies: []},
          tags: ["pipeline_stage", stage_info[:name]]
        )
      end

      # Track stage transitions
      stage_events = []
      observer = double("StageObserver")
      allow(observer).to receive(:update) do |type, source, event|
        stage_events << {
          event_type: type,
          stage_name: event[:correlation_context][:context_name],
          stage_state: event[:correlation_context][:context_state],
          stage_type: event[:correlation_context][:context_type]
        }
      end

      observability_engine.event_dispatcher.add_observer(observer)

      # Execute pipeline stages sequentially
      pipeline_workflow.activate
      observability_engine.notify(
        :pipeline_started,
        data: {input_size: 10000, expected_duration: 300},
        event_context: pipeline_workflow
      )

      stages.each_with_index do |stage_context, index|
        # Stage activation
        stage_context.activate
        observability_engine.notify(
          :stage_started,
          data: {stage_index: index, input_ready: true},
          event_context: stage_context
        )

        # Stage processing
        observability_engine.notify(
          :stage_processing,
          data: {stage_index: index, progress: 50},
          event_context: stage_context
        )

        # Stage completion
        stage_context.complete
        observability_engine.notify(
          :stage_completed,
          data: {stage_index: index, output_records: 10000 - (index * 100)},
          event_context: stage_context
        )
      end

      # Complete pipeline
      pipeline_workflow.complete
      observability_engine.notify(
        :pipeline_completed,
        data: {total_stages: 5, final_output: 9500},
        event_context: pipeline_workflow
      )

      # Validate stage coordination
      expect(stage_events.size).to eq(17) # 1 pipeline start + 15 stage events + 1 pipeline complete

      # Verify stage progression
      stage_started_events = stage_events.select { |e| e[:event_type] == :stage_started }
      expect(stage_started_events.size).to eq(5)

      stage_completed_events = stage_events.select { |e| e[:event_type] == :stage_completed }
      expect(stage_completed_events.size).to eq(5)

      # Verify stage types are properly tracked
      verification_events = stage_events.select do |e|
        e[:stage_type] == Agentic::Observability::EventContext::TYPE_VERIFICATION
      end
      expect(verification_events.size).to eq(3) # validation stage events
    end
  end

  describe "distributed tracing capabilities" do
    it "enables tracing across distributed agent boundaries" do
      # Simulate distributed system with multiple nodes
      nodes = ["node-1", "node-2", "node-3"]

      # Create distributed workflow context
      distributed_workflow = Agentic::Observability::EventContext.new(
        context_type: Agentic::Observability::EventContext::TYPE_WORKFLOW,
        name: "distributed_computation",
        metadata: {
          distribution: {nodes: nodes, strategy: "scatter_gather"}
        }
      )

      # Create node-specific contexts
      node_contexts = nodes.map do |node|
        distributed_workflow.create_child(
          context_type: Agentic::Observability::EventContext::TYPE_AGENT,
          name: "#{node}_agent",
          metadata: {
            node_id: node,
            endpoint: "https://#{node}.cluster.local/api",
            capabilities: ["compute", "storage"]
          },
          tags: ["distributed", "compute_node", node]
        )
      end

      # Track distributed events
      distributed_events = []
      observer = double("DistributedObserver")
      allow(observer).to receive(:update) do |type, source, event|
        distributed_events << {
          event_type: type,
          node_id: event[:data][:node_id],
          context_hierarchy: event[:correlation_context][:hierarchy_path],
          correlation_id: event[:correlation_context][:correlation_id],
          parent_context: event[:correlation_context][:parent_context_id]
        }
      end

      observability_engine.event_dispatcher.add_observer(observer)

      # Simulate distributed execution
      distributed_workflow.activate
      observability_engine.notify(
        :distributed_job_started,
        data: {job_type: "parallel_computation", nodes: nodes.size},
        event_context: distributed_workflow
      )

      # Each node processes independently
      node_contexts.each_with_index do |node_context, index|
        node_id = nodes[index]

        node_context.activate
        observability_engine.notify(
          :node_job_started,
          data: {node_id: node_id, partition: index, data_size: 1000},
          event_context: node_context
        )

        # Simulate processing steps
        observability_engine.notify(
          :node_processing,
          data: {node_id: node_id, progress: 25, stage: "data_loading"},
          event_context: node_context
        )

        observability_engine.notify(
          :node_processing,
          data: {node_id: node_id, progress: 75, stage: "computation"},
          event_context: node_context
        )

        node_context.complete
        observability_engine.notify(
          :node_job_completed,
          data: {node_id: node_id, result_size: 500, duration: 2.1},
          event_context: node_context
        )
      end

      # Aggregate results
      observability_engine.notify(
        :results_aggregation,
        data: {nodes_completed: nodes.size, total_results: 1500},
        event_context: distributed_workflow
      )

      distributed_workflow.complete
      observability_engine.notify(
        :distributed_job_completed,
        data: {status: "success", total_duration: 6.3, efficiency: 0.89},
        event_context: distributed_workflow
      )

      # Validate distributed tracing
      # Events: 1 job_started + 12 node events (3 nodes × 4 events) + 1 aggregation + 1 job_completed = 15
      expect(distributed_events.size).to eq(15)

      # All events should share the same correlation ID
      correlation_ids = distributed_events.map { |e| e[:correlation_id] }.uniq
      expect(correlation_ids.size).to eq(1)

      # Verify node-specific events can be traced
      node1_events = distributed_events.select { |e| e[:node_id] == "node-1" }
      node2_events = distributed_events.select { |e| e[:node_id] == "node-2" }
      node3_events = distributed_events.select { |e| e[:node_id] == "node-3" }

      expect(node1_events.size).to eq(4) # start + 2 processing + complete
      expect(node2_events.size).to eq(4)
      expect(node3_events.size).to eq(4)

      # Verify hierarchy paths enable distributed tracing
      node_events = distributed_events.select { |e| !e[:node_id].nil? }
      node_events.each do |event|
        expect(event[:context_hierarchy]).to be_an(Array)
        expect(event[:context_hierarchy].size).to eq(2) # workflow -> node
        expect(event[:parent_context]).to eq(distributed_workflow.context_id)
      end
    end
  end

  describe "Domain Expert requirements (Jamie Chen)" do
    it "supports complex agent orchestration patterns" do
      # Create multi-level agent hierarchy for complex coordination
      command_center = Agentic::Observability::EventContext.new(
        context_type: Agentic::Observability::EventContext::TYPE_AGENT,
        name: "command_center",
        metadata: {role: "supreme_coordinator", clearance: "top_secret"},
        tags: ["command", "coordination", "primary"]
      )

      # Regional coordinators
      regional_coordinators = ["north", "south", "east", "west"].map do |region|
        command_center.create_child(
          context_type: Agentic::Observability::EventContext::TYPE_AGENT,
          name: "#{region}_coordinator",
          metadata: {role: "regional_coordinator", region: region, reports_to: command_center.context_id},
          tags: ["coordinator", "regional", region]
        )
      end

      # Operational teams under each coordinator
      operational_teams = regional_coordinators.flat_map do |coordinator|
        ["alpha", "beta"].map do |team|
          coordinator.create_child(
            context_type: Agentic::Observability::EventContext::TYPE_AGENT,
            name: "#{coordinator.get_metadata("region")}_team_#{team}",
            metadata: {
              role: "operational_team",
              team_id: team,
              coordinator: coordinator.context_id,
              specialization: (team == "alpha") ? "reconnaissance" : "execution"
            },
            tags: ["operational", "team", team]
          )
        end
      end

      # Individual agents in each team
      field_agents = operational_teams.flat_map do |team|
        3.times.map do |i|
          team.create_child(
            context_type: Agentic::Observability::EventContext::TYPE_AGENT,
            name: "agent_#{team.get_metadata("team_id")}_#{i}",
            metadata: {
              role: "field_agent",
              agent_id: i,
              team: team.context_id,
              specialization: team.get_metadata("specialization")
            },
            tags: ["field_agent", "operational"]
          )
        end
      end

      # Track complex orchestration
      orchestration_events = []
      observer = double("OrchestrationObserver")
      allow(observer).to receive(:update) do |type, source, event|
        orchestration_events << {
          event_type: type,
          agent_role: event[:data][:agent_role] || event[:correlation_context][:context_name],
          hierarchy_level: event[:correlation_context][:context_depth],
          coordination_data: event[:data]
        }
      end

      observability_engine.event_dispatcher.add_observer(observer)

      # Simulate complex mission coordination
      command_center.activate
      observability_engine.notify(
        :mission_initiated,
        data: {mission_type: "complex_coordination", priority: "high", agent_role: "command"},
        event_context: command_center
      )

      # Regional coordinators receive mission briefing
      regional_coordinators.each do |coordinator|
        coordinator.activate
        observability_engine.notify(
          :mission_briefing_received,
          data: {
            region: coordinator.get_metadata("region"),
            teams_assigned: 2,
            agent_role: "regional_coordinator"
          },
          event_context: coordinator
        )
      end

      # Operational teams receive assignments
      operational_teams.each do |team|
        team.activate
        observability_engine.notify(
          :team_assignment_received,
          data: {
            team_specialization: team.get_metadata("specialization"),
            field_agents_count: 3,
            agent_role: "operational_team"
          },
          event_context: team
        )
      end

      # Field agents execute tasks
      field_agents.each do |agent|
        agent.activate
        observability_engine.notify(
          :field_operation_started,
          data: {
            agent_specialization: agent.get_metadata("specialization"),
            operation_type: (agent.get_metadata("specialization") == "reconnaissance") ? "intel_gathering" : "target_engagement",
            agent_role: "field_agent"
          },
          event_context: agent
        )

        agent.complete
        observability_engine.notify(
          :field_operation_completed,
          data: {
            agent_specialization: agent.get_metadata("specialization"),
            operation_type: (agent.get_metadata("specialization") == "reconnaissance") ? "intel_gathering" : "target_engagement",
            status: "success",
            intel_gathered: (agent.get_metadata("specialization") == "reconnaissance") ? 100 : 0,
            agent_role: "field_agent"
          },
          event_context: agent
        )
      end

      # Complete mission hierarchy
      operational_teams.each(&:complete)
      regional_coordinators.each(&:complete)
      command_center.complete

      observability_engine.notify(
        :mission_completed,
        data: {status: "success", total_agents: field_agents.size + operational_teams.size + regional_coordinators.size + 1},
        event_context: command_center
      )

      # Validate complex orchestration tracking
      expect(orchestration_events).not_to be_empty

      # Verify hierarchy levels
      command_events = orchestration_events.select { |e| e[:hierarchy_level] == 0 }
      regional_events = orchestration_events.select { |e| e[:hierarchy_level] == 1 }
      team_events = orchestration_events.select { |e| e[:hierarchy_level] == 2 }
      field_events = orchestration_events.select { |e| e[:hierarchy_level] == 3 }

      expect(command_events.size).to eq(2) # initiate + complete
      expect(regional_events.size).to eq(4) # 4 regions
      expect(team_events.size).to eq(8) # 4 regions × 2 teams
      expect(field_events.size).to eq(48) # 8 teams × 3 agents × 2 events

      # Verify role-based coordination
      reconnaissance_events = orchestration_events.select do |e|
        e[:coordination_data] && (
          e[:coordination_data][:agent_specialization] == "reconnaissance" ||
            e[:coordination_data][:operation_type] == "intel_gathering"
        )
      end

      execution_events = orchestration_events.select do |e|
        e[:coordination_data] && (
          e[:coordination_data][:agent_specialization] == "execution" ||
            e[:coordination_data][:operation_type] == "target_engagement"
        )
      end

      expect(reconnaissance_events.size).to eq(24) # Half the field agents
      expect(execution_events.size).to eq(24) # Other half
    end
  end

  describe "Agent Systems Engineer requirements (Taylor Kim)" do
    it "supports extensible domain-specific correlation patterns" do
      # Create financial compliance workflow with domain extensions
      compliance_workflow = Agentic::Observability::EventContext.new(
        context_type: Agentic::Observability::EventContext::TYPE_WORKFLOW,
        name: "financial_compliance_audit",
        metadata: {
          compliance_framework: "SOX",
          audit_period: "Q4_2024",
          risk_level: "high"
        },
        tags: ["compliance", "financial", "audit"]
      )

      # Register compliance-specific extensions
      compliance_extension = double("ComplianceExtension",
        validate_transaction: true,
        generate_audit_trail: "audit_trail_data",
        assess_risk: "medium")

      security_extension = double("SecurityExtension",
        scan_for_fraud: "clean",
        encrypt_sensitive_data: "encrypted_data",
        verify_authorization: true)

      compliance_workflow.register_extension("compliance", compliance_extension)
      compliance_workflow.register_extension("security", security_extension)

      # Create compliance process contexts
      data_ingestion = compliance_workflow.create_child(
        context_type: Agentic::Observability::EventContext::TYPE_TASK,
        name: "financial_data_ingestion",
        metadata: {data_sources: ["trading_system", "accounting", "risk_management"]},
        tags: ["data_ingestion", "compliance"]
      )

      risk_assessment = compliance_workflow.create_child(
        context_type: Agentic::Observability::EventContext::TYPE_VERIFICATION,
        name: "risk_assessment",
        metadata: {assessment_criteria: ["market_risk", "credit_risk", "operational_risk"]},
        tags: ["risk_assessment", "verification"]
      )

      audit_trail_generation = compliance_workflow.create_child(
        context_type: Agentic::Observability::EventContext::TYPE_CAPABILITY,
        name: "audit_trail_generation",
        metadata: {retention_period: "7_years", encryption: "AES_256"},
        tags: ["audit_trail", "compliance"]
      )

      # Track domain-specific events with extensions
      compliance_events = []
      observer = double("ComplianceObserver")
      allow(observer).to receive(:update) do |type, source, event|
        compliance_events << {
          event_type: type,
          process_name: event[:correlation_context][:context_name],
          compliance_metadata: event[:data][:compliance_data],
          context_extensions: event[:event_context]&.instance_variable_get(:@extensions)&.keys || []
        }
      end

      observability_engine.event_dispatcher.add_observer(observer)

      # Execute compliance workflow
      compliance_workflow.activate
      observability_engine.notify(
        :compliance_audit_started,
        data: {
          compliance_data: {
            framework: "SOX",
            scope: "full_audit",
            duration_estimate: "30_days"
          }
        },
        event_context: compliance_workflow
      )

      # Data ingestion with compliance validation
      data_ingestion.activate
      observability_engine.notify(
        :data_ingestion_started,
        data: {
          compliance_data: {
            data_classification: "sensitive",
            sources_validated: true,
            encryption_applied: true
          }
        },
        event_context: data_ingestion
      )

      data_ingestion.complete
      observability_engine.notify(
        :data_ingestion_completed,
        data: {
          compliance_data: {
            records_processed: 1000000,
            validation_passed: true,
            anomalies_detected: 0
          }
        },
        event_context: data_ingestion
      )

      # Risk assessment with extensions
      risk_assessment.activate
      observability_engine.notify(
        :risk_assessment_started,
        data: {
          compliance_data: {
            assessment_type: "comprehensive",
            risk_models: ["VaR", "stress_testing", "scenario_analysis"]
          }
        },
        event_context: risk_assessment
      )

      risk_assessment.complete
      observability_engine.notify(
        :risk_assessment_completed,
        data: {
          compliance_data: {
            overall_risk_score: 7.2,
            high_risk_items: 3,
            mitigation_required: true
          }
        },
        event_context: risk_assessment
      )

      # Audit trail generation
      audit_trail_generation.activate
      observability_engine.notify(
        :audit_trail_generation_started,
        data: {
          compliance_data: {
            trail_type: "comprehensive",
            encryption_level: "AES_256",
            retention_policy: "7_years"
          }
        },
        event_context: audit_trail_generation
      )

      audit_trail_generation.complete
      observability_engine.notify(
        :audit_trail_completed,
        data: {
          compliance_data: {
            trail_size: "500MB",
            integrity_verified: true,
            backup_created: true
          }
        },
        event_context: audit_trail_generation
      )

      # Complete compliance workflow
      compliance_workflow.complete
      observability_engine.notify(
        :compliance_audit_completed,
        data: {
          compliance_data: {
            audit_result: "PASS",
            violations_found: 0,
            recommendations: 5
          }
        },
        event_context: compliance_workflow
      )

      # Validate domain-specific correlation
      expect(compliance_events.size).to eq(8)

      # Verify compliance metadata is properly tracked
      compliance_metadata = compliance_events.map { |e| e[:compliance_metadata] }.compact
      expect(compliance_metadata).not_to be_empty

      audit_events = compliance_events.select { |e| e[:event_type].to_s.include?("audit") }
      expect(audit_events.size).to eq(4) # compliance_audit_started, audit_trail_generation_started, audit_trail_completed, compliance_audit_completed

      # Verify extensions are tracked (even though not serialized)
      workflow_events = compliance_events.select { |e| e[:process_name] == "financial_compliance_audit" }
      expect(workflow_events.first[:context_extensions]).to include("compliance", "security")

      # Test extension functionality
      expect(compliance_workflow.get_extension("compliance").validate_transaction).to be true
      expect(compliance_workflow.get_extension("security").verify_authorization).to be true
    end
  end
end
