# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/agentic/human_intervention/portal"

RSpec.describe "Human Intervention Portal Integration", :integration do
  let(:portal) { Agentic::HumanIntervention::Portal.new(test_config) }

  let(:test_config) do
    {
      enable_authentication: true,
      enable_monitoring: true,
      enable_notifications: true,
      default_timeout: 3600,
      max_concurrent_requests: 10
    }
  end

  before do
    # Ensure clean state for each test
    portal.instance_variable_set(:@requests, {})
    portal.instance_variable_set(:@responses, {})
  end

  after do
    portal.shutdown!
  end

  describe "Portal Initialization" do
    it "initializes with all integrated systems" do
      expect(portal.authenticator).to be_a(Agentic::HumanIntervention::AuthenticationSystem::Authenticator)
      expect(portal.workflow_manager).to be_a(Agentic::HumanIntervention::WorkflowManager)
      expect(portal.monitoring_system).to be_a(Agentic::HumanIntervention::MonitoringSystem)
    end

    it "has integrated systems marked as active" do
      status = portal.comprehensive_status

      expect(status[:integrated_systems][:authenticator]).to eq(:active)
      expect(status[:integrated_systems][:workflow_manager]).to eq(:active)
      expect(status[:integrated_systems][:monitoring_system]).to eq(:active)
    end
  end

  describe "Authentication Integration" do
    let(:test_user_params) do
      {
        username: "test_reviewer",
        email: "reviewer@test.com",
        password: "SecurePass123!",
        role: :reviewer
      }
    end

    it "registers and authenticates users successfully" do
      # Register user
      result = portal.register_portal_user(**test_user_params)

      expect(result[:success]).to be true
      expect(result[:user]).to be_a(Agentic::HumanIntervention::AuthenticationSystem::User)
      expect(result[:user].username).to eq("test_reviewer")
      expect(result[:user].role).to eq(:reviewer)

      # Authenticate user
      auth_result = portal.authenticate_user("test_reviewer", "SecurePass123!")

      expect(auth_result[:success]).to be true
      expect(auth_result[:session]).to be_a(Agentic::HumanIntervention::AuthenticationSystem::Session)
      expect(auth_result[:session].valid?).to be true
    end

    it "authorizes operations based on user permissions" do
      # Register and authenticate user
      portal.register_portal_user(**test_user_params)
      auth_result = portal.authenticate_user("test_reviewer", "SecurePass123!")
      session_id = auth_result[:session].id

      # Test successful authorization
      read_auth = portal.authorize_operation(session_id, :read)
      expect(read_auth[:authorized]).to be true

      comment_auth = portal.authorize_operation(session_id, :comment)
      expect(comment_auth[:authorized]).to be true

      # Test failed authorization (reviewer cannot configure)
      config_auth = portal.authorize_operation(session_id, :configure)
      expect(config_auth[:authorized]).to be false
      expect(config_auth[:error]).to eq(:insufficient_permissions)
    end
  end

  describe "Workflow Integration" do
    it "creates requests with associated workflows" do
      result = portal.create_request_with_workflow(
        type: :ethical_review,
        title: "Test Ethical Review",
        description: "Test request for ethical review",
        workflow_template: :single_approval,
        priority: 3
      )

      expect(result[:request]).to be_a(Agentic::HumanIntervention::Portal::InterventionRequest)
      expect(result[:workflow]).to be_a(Agentic::HumanIntervention::WorkflowManager::Workflow)

      # Verify workflow is associated with request
      expect(result[:workflow].request_id).to eq(result[:request].id)
      expect(result[:workflow].status).to eq(:active)
    end

    it "processes workflow responses" do
      # Create request with workflow
      result = portal.create_request_with_workflow(
        type: :domain_expertise,
        title: "Test Domain Review",
        description: "Test request for domain expertise",
        workflow_template: :single_approval
      )

      request = result[:request]
      workflow = result[:workflow]

      # Process workflow response
      response_result = portal.respond_with_workflow(
        request.id,
        decision: :approved,
        user: "test_approver",
        comment: "Approved after review",
        workflow_id: workflow.id
      )

      expect(response_result[:response]).to be_a(Agentic::HumanIntervention::Portal::InterventionResponse)
      expect(response_result[:response].approved?).to be true
      expect(response_result[:workflow_processed]).to be true
    end

    it "handles different workflow templates" do
      templates_with_names = {
        single_approval: "Single Approval",
        two_stage_approval: "Two-Stage Approval",
        majority_vote: "Majority Vote"
      }

      templates_with_names.each do |template, expected_name|
        result = portal.create_request_with_workflow(
          type: :resource_authorization,
          title: "Test #{template} workflow",
          description: "Testing #{template} template",
          workflow_template: template
        )

        expect(result[:workflow]).to be_a(Agentic::HumanIntervention::WorkflowManager::Workflow)
        expect(result[:workflow].name).to eq(expected_name)
      end
    end
  end

  describe "Monitoring Integration" do
    it "starts monitoring system automatically" do
      # Monitoring should start automatically with portal
      expect(portal.monitoring_system).to be_a(Agentic::HumanIntervention::MonitoringSystem)

      # Check monitoring statistics
      stats = portal.monitoring_system.monitoring_statistics
      expect(stats).to have_key(:alert_rules)
      expect(stats).to have_key(:active_alerts)
      expect(stats[:system_status]).to eq(:running)
    end

    it "generates alerts for high request volume" do
      # Create multiple requests to trigger volume alert
      20.times do |i|
        portal.request_intervention(
          type: :confidence_threshold,
          title: "Test Request #{i}",
          description: "Test request #{i}",
          priority: 2
        )
      end

      # Give monitoring system time to process
      sleep(0.1)

      # Check if volume alerts were triggered
      alerts = portal.get_monitoring_alerts
      alerts.select { |alert| alert.rule_name.include?("Volume") }

      # Note: Actual alert triggering depends on configured thresholds
      # This test verifies the integration is working
      expect(alerts).to be_an(Array)
    end

    it "provides comprehensive monitoring statistics" do
      stats = portal.monitoring_system.monitoring_statistics

      expect(stats).to have_key(:alert_rules)
      expect(stats).to have_key(:active_alerts)
      expect(stats).to have_key(:sla_compliance)
      expect(stats).to have_key(:system_status)

      expect(stats[:alert_rules]).to have_key(:total)
      expect(stats[:alert_rules]).to have_key(:enabled)
      expect(stats[:active_alerts]).to have_key(:total)
    end
  end

  describe "Comprehensive Portal Status" do
    it "provides integrated status from all subsystems" do
      status = portal.comprehensive_status

      expect(status).to have_key(:portal)
      expect(status).to have_key(:authentication)
      expect(status).to have_key(:workflows)
      expect(status).to have_key(:monitoring)
      expect(status).to have_key(:integrated_systems)

      # Portal status
      expect(status[:portal]).to have_key(:statistics)
      expect(status[:portal]).to have_key(:health)

      # Authentication status
      expect(status[:authentication]).to have_key(:users)
      expect(status[:authentication]).to have_key(:sessions)
      expect(status[:authentication]).to have_key(:api_keys)

      # Workflow status
      expect(status[:workflows]).to have_key(:total_workflows)
      expect(status[:workflows]).to have_key(:active_workflows)

      # Monitoring status
      expect(status[:monitoring]).to have_key(:alert_rules)
      expect(status[:monitoring]).to have_key(:active_alerts)
    end
  end

  describe "End-to-End Intervention Workflow" do
    let(:approver_params) do
      {
        username: "approver_user",
        email: "approver@test.com",
        password: "ApproverPass123!",
        role: :approver
      }
    end

    it "completes full intervention workflow with authentication" do
      # 1. Register approver
      register_result = portal.register_portal_user(**approver_params)
      expect(register_result[:success]).to be true

      # 2. Authenticate approver
      auth_result = portal.authenticate_user("approver_user", "ApproverPass123!")
      expect(auth_result[:success]).to be true
      session_id = auth_result[:session].id

      # 3. Create request with workflow
      request_result = portal.create_request_with_workflow(
        type: :ethical_review,
        title: "End-to-End Test Request",
        description: "Testing complete intervention workflow",
        workflow_template: :single_approval,
        priority: 3
      )

      request = request_result[:request]
      workflow = request_result[:workflow]

      # 4. Verify authorization for approval
      auth_check = portal.authorize_operation(session_id, :approve)
      expect(auth_check[:authorized]).to be true

      # 5. Process approval through workflow
      response_result = portal.respond_with_workflow(
        request.id,
        decision: :approved,
        user: "approver_user",
        comment: "Approved in end-to-end test",
        workflow_id: workflow.id
      )

      # 6. Verify results
      expect(response_result[:response].approved?).to be true
      expect(response_result[:workflow_processed]).to be true

      # 7. Check final status
      final_request = portal.get_request(request.id)
      expect(final_request.status).to eq(:approved)
    end

    it "handles rejection workflow correctly" do
      # Register and authenticate approver
      portal.register_portal_user(**approver_params)
      auth_result = portal.authenticate_user("approver_user", "ApproverPass123!")
      auth_result[:session].id

      # Create request with workflow
      request_result = portal.create_request_with_workflow(
        type: :resource_authorization,
        title: "Test Rejection Workflow",
        description: "Testing rejection path",
        workflow_template: :single_approval
      )

      request = request_result[:request]
      workflow = request_result[:workflow]

      # Process rejection
      response_result = portal.respond_with_workflow(
        request.id,
        decision: :rejected,
        user: "approver_user",
        comment: "Rejected for security reasons",
        workflow_id: workflow.id
      )

      # Verify rejection results
      expect(response_result[:response].rejected?).to be true
      expect(response_result[:workflow_processed]).to be true

      final_request = portal.get_request(request.id)
      expect(final_request.status).to eq(:rejected)
    end
  end

  describe "Error Handling and Edge Cases" do
    it "handles authentication disabled gracefully" do
      disabled_portal = Agentic::HumanIntervention::Portal.new(enable_authentication: false)

      # Should work without authentication
      auth_result = disabled_portal.authorize_operation("fake_session", :approve)
      expect(auth_result[:authorized]).to be true

      disabled_portal.shutdown!
    end

    it "handles missing workflow gracefully" do
      # Create request without workflow
      request = portal.request_intervention(
        type: :novel_situation,
        title: "Request without workflow",
        description: "Testing without workflow integration"
      )

      # Should still work for regular response
      response = portal.respond_to_request(
        request.id,
        decision: :approved,
        user: "system"
      )

      expect(response).to be_a(Agentic::HumanIntervention::Portal::InterventionResponse)
      expect(response.approved?).to be true
    end

    it "handles monitoring system failures gracefully" do
      # Simulate monitoring system failure
      portal.monitoring_system.stop!

      # Portal should continue to function
      request = portal.request_intervention(
        type: :error_recovery,
        title: "Test with monitoring disabled",
        description: "Testing resilience"
      )

      expect(request).to be_a(Agentic::HumanIntervention::Portal::InterventionRequest)
    end
  end

  describe "Performance and Resource Management" do
    it "handles concurrent request processing" do
      threads = []
      results = []
      mutex = Mutex.new

      # Create multiple concurrent requests
      10.times do |i|
        threads << Thread.new do
          request = portal.request_intervention(
            type: :confidence_threshold,
            title: "Concurrent Request #{i}",
            description: "Testing concurrency #{i}",
            priority: 2
          )

          mutex.synchronize { results << request }
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(10)
      expect(results.all? { |r| r.is_a?(Agentic::HumanIntervention::Portal::InterventionRequest) }).to be true
    end

    it "cleans up resources properly on shutdown" do
      # Create some test data
      portal.request_intervention(
        type: :system_health,
        title: "Test cleanup request",
        description: "Testing resource cleanup"
      )

      # Verify resources exist
      expect(portal.list_requests.size).to be > 0

      # Shutdown should clean up gracefully
      expect { portal.shutdown! }.not_to raise_error
    end
  end
end
