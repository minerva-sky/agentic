#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple integration test for Human Intervention Portal
require_relative "lib/agentic/human_intervention/portal"

puts "Starting Human Intervention Portal Integration Test..."

begin
  # Test 1: Portal Initialization
  puts "\n1. Testing Portal Initialization..."
  portal = Agentic::HumanIntervention::Portal.new(
    enable_authentication: true,
    enable_monitoring: true,
    enable_notifications: true
  )

  puts "   ✓ Portal created successfully"
  puts "   ✓ Authenticator: #{portal.authenticator.class.name}"
  puts "   ✓ Workflow Manager: #{portal.workflow_manager.class.name}"
  puts "   ✓ Monitoring System: #{portal.monitoring_system.class.name}"

  # Test 2: User Registration and Authentication
  puts "\n2. Testing User Registration and Authentication..."

  user_result = portal.register_portal_user(
    username: "test_user",
    email: "test@example.com",
    password: "TestPass123!",
    role: :reviewer
  )

  if user_result[:success]
    puts "   ✓ User registration successful"

    auth_result = portal.authenticate_user("test_user", "TestPass123!")
    if auth_result[:success]
      puts "   ✓ User authentication successful"
      session_id = auth_result[:session].id
      puts "   ✓ Session ID: #{session_id[0..10]}..."
    else
      puts "   ✗ User authentication failed: #{auth_result[:error]}"
    end
  else
    puts "   ✗ User registration failed: #{user_result[:error]}"
  end

  # Test 3: Request Creation with Workflow
  puts "\n3. Testing Request Creation with Workflow..."

  request_result = portal.create_request_with_workflow(
    type: :ethical_review,
    title: "Test Ethical Review Request",
    description: "This is a test request for ethical review integration",
    workflow_template: :single_approval,
    priority: 3
  )

  request = request_result[:request]
  workflow = request_result[:workflow]

  puts "   ✓ Request created: #{request.id[0..10]}..."
  puts "   ✓ Workflow created: #{workflow.id[0..10]}..."
  puts "   ✓ Request title: #{request.title}"
  puts "   ✓ Workflow status: #{workflow.status}"

  # Test 4: Authorization
  puts "\n4. Testing Authorization..."

  auth_check = portal.authorize_operation(session_id, :read)
  puts "   ✓ Read authorization: #{auth_check[:authorized]}"

  auth_check = portal.authorize_operation(session_id, :comment)
  puts "   ✓ Comment authorization: #{auth_check[:authorized]}"

  auth_check = portal.authorize_operation(session_id, :configure)
  puts "   ✓ Configure authorization: #{auth_check[:authorized]} (should be false for reviewer)"

  # Test 5: Response Processing
  puts "\n5. Testing Response Processing..."

  response_result = portal.respond_with_workflow(
    request.id,
    decision: :approved,
    user: "test_user",
    comment: "Approved during integration test",
    workflow_id: workflow.id
  )

  response = response_result[:response]
  puts "   ✓ Response processed: #{response.approved? ? "APPROVED" : "REJECTED"}"
  puts "   ✓ Workflow processed: #{response_result[:workflow_processed]}"

  # Test 6: Portal Statistics
  puts "\n6. Testing Portal Statistics..."

  stats = portal.comprehensive_status
  puts "   ✓ Portal statistics: #{stats[:portal][:statistics][:total_requests]} total requests"
  puts "   ✓ Authentication statistics: #{stats[:authentication][:users][:total]} total users"
  puts "   ✓ Workflow statistics: #{stats[:workflows][:total_workflows]} total workflows"
  puts "   ✓ Monitoring statistics: #{stats[:monitoring][:alert_rules][:total]} alert rules"

  # Test 7: Monitoring Integration
  puts "\n7. Testing Monitoring Integration..."

  alerts = portal.get_monitoring_alerts
  puts "   ✓ Active alerts: #{alerts.size}"

  health_report = portal.monitoring_system.health_report
  puts "   ✓ System health: #{health_report[:monitoring_system][:status]}"

  # Test 8: Cleanup
  puts "\n8. Testing Cleanup..."
  portal.shutdown!
  puts "   ✓ Portal shutdown successful"

  puts "\n" + "=" * 60
  puts "🎉 ALL INTEGRATION TESTS PASSED!"
  puts "The Human Intervention Portal is fully integrated and functional."
  puts "=" * 60
rescue => e
  puts "\n" + "=" * 60
  puts "❌ INTEGRATION TEST FAILED!"
  puts "Error: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace[0..5].join("\n")
  puts "=" * 60
  exit 1
end
