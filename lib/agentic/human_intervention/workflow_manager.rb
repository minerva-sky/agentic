# frozen_string_literal: true

require "securerandom"
require "json"

module Agentic
  module HumanIntervention
    # Workflow management system for multi-step approval processes
    #
    # Provides comprehensive workflow orchestration including:
    # - Multi-stage approval chains with role-based escalation
    # - Conditional branching based on request attributes
    # - Template-driven workflows for common scenarios
    # - Parallel and sequential approval patterns
    # - Audit trail and compliance tracking
    #
    # Design Goals:
    # 1. Flexible workflow definition and execution
    # 2. Role-based access control and escalation
    # 3. Template system for reusable approval patterns
    # 4. Integration with Portal for request lifecycle
    # 5. Comprehensive audit and compliance features
    #
    # Architecture follows the established patterns with:
    # - Observer pattern for workflow state changes
    # - Factory pattern for workflow creation
    # - Strategy pattern for different approval logic
    class WorkflowManager
      # Workflow execution states
      module State
        PENDING = :pending
        ACTIVE = :active
        WAITING = :waiting
        APPROVED = :approved
        REJECTED = :rejected
        ESCALATED = :escalated
        CANCELLED = :cancelled
        TIMEOUT = :timeout
      end

      # Workflow step types
      module StepType
        APPROVAL = :approval          # Single user approval
        MULTI_APPROVAL = :multi_approval  # Multiple users must approve
        REVIEW = :review             # Review step (no approval required)
        ESCALATION = :escalation     # Automatic escalation
        CONDITIONAL = :conditional   # Conditional branching
        NOTIFICATION = :notification # Notification step
        DELAY = :delay              # Time-based delay
        CUSTOM = :custom            # Custom step logic
      end

      # Approval patterns
      module ApprovalPattern
        ALL_REQUIRED = :all_required    # All approvers must approve
        ANY_REQUIRED = :any_required    # Any approver can approve
        MAJORITY = :majority            # Majority must approve
        CONSENSUS = :consensus          # Unanimous approval required
        ESCALATION_CHAIN = :escalation_chain  # Sequential escalation
      end

      # Workflow step definition
      class WorkflowStep
        attr_reader :id, :name, :type, :description, :config, :created_at
        attr_accessor :status, :result, :assigned_users, :approvals, :rejections, :started_at, :completed_at

        def initialize(name:, type:, description: nil, config: {})
          @id = SecureRandom.uuid
          @name = name
          @type = type
          @description = description
          @config = config.freeze
          @status = State::PENDING
          @assigned_users = []
          @approvals = []
          @rejections = []
          @result = nil
          @created_at = Time.now
          @started_at = nil
          @completed_at = nil
        end

        # Check if step is ready to execute
        # @return [Boolean] True if step can be started
        def ready_to_start?
          @status == State::PENDING && prerequisites_met?
        end

        # Start step execution
        # @param assigned_users [Array<String>] Users assigned to this step
        def start!(assigned_users = [])
          @status = State::ACTIVE
          @assigned_users = assigned_users
          @started_at = Time.now
        end

        # Record approval from a user
        # @param user [String] User providing approval
        # @param comment [String] Optional comment
        def add_approval(user, comment: nil)
          return false unless @status == State::ACTIVE
          return false if @approvals.any? { |a| a[:user] == user }

          @approvals << {
            user: user,
            timestamp: Time.now,
            comment: comment
          }

          check_completion
          true
        end

        # Record rejection from a user
        # @param user [String] User providing rejection
        # @param comment [String] Optional comment
        def add_rejection(user, comment: nil)
          return false unless @status == State::ACTIVE
          return false if @rejections.any? { |r| r[:user] == user }

          @rejections << {
            user: user,
            timestamp: Time.now,
            comment: comment
          }

          check_completion
          true
        end

        # Mark step as completed with result
        # @param result [Symbol] Step result (:approved, :rejected, :escalated, etc.)
        def complete!(result)
          @status = result
          @result = result
          @completed_at = Time.now
        end

        # Check if step is completed
        # @return [Boolean] True if step is in a final state
        def completed?
          [State::APPROVED, State::REJECTED, State::ESCALATED, State::CANCELLED, State::TIMEOUT].include?(@status)
        end

        # Get step duration
        # @return [Float] Duration in seconds, or nil if not completed
        def duration
          return nil unless completed? && @started_at
          @completed_at - @started_at
        end

        # Convert to hash for serialization
        # @return [Hash] Hash representation
        def to_h
          {
            id: @id,
            name: @name,
            type: @type,
            description: @description,
            config: @config,
            status: @status,
            result: @result,
            assigned_users: @assigned_users,
            approvals: @approvals,
            rejections: @rejections,
            created_at: @created_at.iso8601,
            started_at: @started_at&.iso8601,
            completed_at: @completed_at&.iso8601,
            duration: duration
          }
        end

        private

        # Check if step prerequisites are met
        def prerequisites_met?
          # Default implementation - can be overridden by specific step types
          true
        end

        # Check if step should be completed based on approvals/rejections
        def check_completion
          pattern = @config[:approval_pattern] || ApprovalPattern::ALL_REQUIRED
          @config[:required_approvals] || @assigned_users.size

          case pattern
          when ApprovalPattern::ALL_REQUIRED
            if @approvals.size >= @assigned_users.size
              complete!(State::APPROVED)
            elsif @rejections.size > 0
              complete!(State::REJECTED)
            end
          when ApprovalPattern::ANY_REQUIRED
            if @approvals.size > 0
              complete!(State::APPROVED)
            elsif @rejections.size >= @assigned_users.size
              complete!(State::REJECTED)
            end
          when ApprovalPattern::MAJORITY
            @approvals.size
            @rejections.size
            majority_needed = (@assigned_users.size / 2.0).ceil

            if @approvals.size >= majority_needed
              complete!(State::APPROVED)
            elsif @rejections.size >= majority_needed
              complete!(State::REJECTED)
            end
          when ApprovalPattern::CONSENSUS
            if @approvals.size >= @assigned_users.size && @rejections.size == 0
              complete!(State::APPROVED)
            elsif @rejections.size > 0
              complete!(State::REJECTED)
            end
          end
        end
      end

      # Workflow definition and execution engine
      class Workflow
        include Agentic::Observable

        attr_reader :id, :name, :description, :request_id, :steps, :current_step_index, :status, :created_at, :metadata

        def initialize(name:, description: nil, request_id: nil, metadata: {})
          @id = SecureRandom.uuid
          @name = name
          @description = description
          @request_id = request_id
          @steps = []
          @current_step_index = 0
          @status = State::PENDING
          @created_at = Time.now
          @started_at = nil
          @completed_at = nil
          @metadata = metadata.freeze
        end

        # Add a workflow step
        # @param step [WorkflowStep] Step to add
        # @return [WorkflowStep] The added step
        def add_step(step)
          @steps << step
          notify_observers(:step_added, step)
          step
        end

        # Add multiple steps at once
        # @param steps [Array<WorkflowStep>] Steps to add
        # @return [Array<WorkflowStep>] The added steps
        def add_steps(steps)
          steps.each { |step| add_step(step) }
        end

        # Start workflow execution
        def start!
          return false unless @status == State::PENDING

          @status = State::ACTIVE
          @started_at = Time.now
          notify_observers(:workflow_started, self)

          execute_next_step
          true
        end

        # Get current step
        # @return [WorkflowStep, nil] Current step or nil if completed
        def current_step
          return nil if @current_step_index >= @steps.size
          @steps[@current_step_index]
        end

        # Process user response for current step
        # @param user [String] User providing response
        # @param decision [Symbol] Decision (:approved or :rejected)
        # @param comment [String] Optional comment
        # @return [Boolean] True if response was processed
        def process_response(user, decision:, comment: nil)
          step = current_step
          return false unless step && step.status == State::ACTIVE

          success = case decision
          when :approved
            step.add_approval(user, comment: comment)
          when :rejected
            step.add_rejection(user, comment: comment)
          else
            false
          end

          if success
            notify_observers(:response_received, step, user, decision, comment)
            check_workflow_progression if step.completed?
          end

          success
        end

        # Cancel workflow execution
        # @param reason [String] Cancellation reason
        def cancel!(reason = nil)
          @status = State::CANCELLED
          @completed_at = Time.now

          # Cancel current step if active
          current_step&.complete!(State::CANCELLED) if current_step&.status == State::ACTIVE

          notify_observers(:workflow_cancelled, self, reason)
        end

        # Check if workflow is completed
        # @return [Boolean] True if workflow is in final state
        def completed?
          [State::APPROVED, State::REJECTED, State::ESCALATED, State::CANCELLED, State::TIMEOUT].include?(@status)
        end

        # Get workflow duration
        # @return [Float] Duration in seconds, or nil if not completed
        def duration
          return nil unless completed? && @started_at
          @completed_at - @started_at
        end

        # Get workflow progress as percentage
        # @return [Float] Progress percentage (0.0 to 100.0)
        def progress_percentage
          return 0.0 if @steps.empty?
          return 100.0 if completed?

          completed_steps = @steps.take(@current_step_index).size
          (completed_steps.to_f / @steps.size) * 100.0
        end

        # Convert to hash for serialization
        # @return [Hash] Hash representation
        def to_h
          {
            id: @id,
            name: @name,
            description: @description,
            request_id: @request_id,
            status: @status,
            current_step_index: @current_step_index,
            progress_percentage: progress_percentage,
            steps: @steps.map(&:to_h),
            created_at: @created_at.iso8601,
            started_at: @started_at&.iso8601,
            completed_at: @completed_at&.iso8601,
            duration: duration,
            metadata: @metadata
          }
        end

        private

        # Execute the next step in the workflow
        def execute_next_step
          step = current_step
          return complete_workflow unless step

          if step.ready_to_start?
            # Assign users based on step configuration
            assigned_users = determine_step_assignees(step)
            step.start!(assigned_users)
            notify_observers(:step_started, step)
          end
        end

        # Check if workflow should progress to next step
        def check_workflow_progression
          step = current_step
          return unless step&.completed?

          case step.result
          when State::APPROVED
            # Move to next step or complete workflow
            @current_step_index += 1
            if @current_step_index >= @steps.size
              complete_workflow_with_approval
            else
              execute_next_step
            end
          when State::REJECTED
            # Workflow rejected
            @status = State::REJECTED
            @completed_at = Time.now
            notify_observers(:workflow_completed, self)
          when State::ESCALATED
            # Handle escalation
            handle_escalation(step)
          end
        end

        # Complete workflow with approval
        def complete_workflow_with_approval
          @status = State::APPROVED
          @completed_at = Time.now
          notify_observers(:workflow_completed, self)
        end

        # Complete workflow (generic)
        def complete_workflow
          @status = @steps.empty? ? State::APPROVED : State::REJECTED
          @completed_at = Time.now
          notify_observers(:workflow_completed, self)
        end

        # Handle step escalation
        def handle_escalation(step)
          # Implementation for escalation logic
          # This could involve creating new steps, reassigning users, etc.
          notify_observers(:step_escalated, step)
        end

        # Determine which users should be assigned to a step
        # @param step [WorkflowStep] Step to assign users to
        # @return [Array<String>] List of user identifiers
        def determine_step_assignees(step)
          # Default implementation - can be customized based on step configuration
          step.config[:assigned_users] || []
        end
      end

      # Workflow template system for common approval patterns
      class WorkflowTemplate
        TEMPLATES = {
          single_approval: {
            name: "Single Approval",
            description: "Simple single-user approval workflow",
            steps: [
              {name: "Review and Approve", type: StepType::APPROVAL, config: {approval_pattern: ApprovalPattern::ANY_REQUIRED}}
            ]
          },

          two_stage_approval: {
            name: "Two-Stage Approval",
            description: "Initial review followed by final approval",
            steps: [
              {name: "Initial Review", type: StepType::REVIEW, config: {}},
              {name: "Final Approval", type: StepType::APPROVAL, config: {approval_pattern: ApprovalPattern::ANY_REQUIRED}}
            ]
          },

          multi_user_consensus: {
            name: "Multi-User Consensus",
            description: "Requires consensus from all assigned reviewers",
            steps: [
              {name: "Team Review", type: StepType::MULTI_APPROVAL, config: {approval_pattern: ApprovalPattern::CONSENSUS}}
            ]
          },

          escalation_chain: {
            name: "Escalation Chain",
            description: "Sequential escalation through different approval levels",
            steps: [
              {name: "Level 1 Approval", type: StepType::APPROVAL, config: {approval_pattern: ApprovalPattern::ANY_REQUIRED, timeout: 3600}},
              {name: "Level 2 Escalation", type: StepType::ESCALATION, config: {escalation_delay: 3600}},
              {name: "Level 2 Approval", type: StepType::APPROVAL, config: {approval_pattern: ApprovalPattern::ANY_REQUIRED}}
            ]
          },

          majority_vote: {
            name: "Majority Vote",
            description: "Requires majority approval from assigned reviewers",
            steps: [
              {name: "Group Vote", type: StepType::MULTI_APPROVAL, config: {approval_pattern: ApprovalPattern::MAJORITY}}
            ]
          },

          conditional_approval: {
            name: "Conditional Approval",
            description: "Different approval paths based on request attributes",
            steps: [
              {name: "Route Decision", type: StepType::CONDITIONAL, config: {condition_field: "priority"}},
              {name: "High Priority Approval", type: StepType::APPROVAL, config: {condition: "priority > 3"}},
              {name: "Standard Approval", type: StepType::APPROVAL, config: {condition: "priority <= 3"}}
            ]
          }
        }.freeze

        class << self
          # Get list of available templates
          # @return [Hash] Hash of template definitions
          def available_templates
            TEMPLATES
          end

          # Create workflow from template
          # @param template_name [Symbol] Name of template to use
          # @param name [String] Custom workflow name
          # @param description [String] Custom workflow description
          # @param request_id [String] Associated request ID
          # @param config [Hash] Template configuration overrides
          # @return [Workflow] Created workflow instance
          def create_workflow(template_name, name: nil, description: nil, request_id: nil, config: {})
            template = TEMPLATES[template_name]
            raise ArgumentError, "Unknown template: #{template_name}" unless template

            workflow = Workflow.new(
              name: name || template[:name],
              description: description || template[:description],
              request_id: request_id
            )

            # Create steps from template
            template[:steps].each do |step_def|
              step_config = step_def[:config].merge(config[step_def[:name]] || {})

              step = WorkflowStep.new(
                name: step_def[:name],
                type: step_def[:type],
                description: step_def[:description],
                config: step_config
              )

              workflow.add_step(step)
            end

            workflow
          end

          # Get template definition
          # @param template_name [Symbol] Template name
          # @return [Hash] Template definition
          def get_template(template_name)
            TEMPLATES[template_name]
          end
        end
      end

      attr_reader :workflows, :active_workflows

      def initialize(portal = nil)
        @portal = portal
        @workflows = {}
        @active_workflows = {}
        @templates = WorkflowTemplate
      end

      # Create new workflow from template
      # @param template_name [Symbol] Template to use
      # @param request_id [String] Associated intervention request ID
      # @param config [Hash] Workflow configuration
      # @return [Workflow] Created workflow
      def create_workflow(template_name, request_id: nil, config: {})
        workflow = @templates.create_workflow(
          template_name,
          request_id: request_id,
          config: config
        )

        @workflows[workflow.id] = workflow
        workflow
      end

      # Start workflow execution
      # @param workflow_id [String] Workflow ID
      # @return [Boolean] True if workflow was started
      def start_workflow(workflow_id)
        workflow = @workflows[workflow_id]
        return false unless workflow

        success = workflow.start!
        @active_workflows[workflow_id] = workflow if success
        success
      end

      # Process user response to workflow step
      # @param workflow_id [String] Workflow ID
      # @param user [String] User providing response
      # @param decision [Symbol] Decision (:approved or :rejected)
      # @param comment [String] Optional comment
      # @return [Boolean] True if response was processed
      def process_workflow_response(workflow_id, user:, decision:, comment: nil)
        workflow = @active_workflows[workflow_id]
        return false unless workflow

        success = workflow.process_response(user, decision: decision, comment: comment)

        # Remove from active workflows if completed
        if workflow.completed?
          @active_workflows.delete(workflow_id)
        end

        success
      end

      # Get workflow by ID
      # @param workflow_id [String] Workflow ID
      # @return [Workflow, nil] Workflow instance or nil
      def get_workflow(workflow_id)
        @workflows[workflow_id]
      end

      # List workflows with optional filtering
      # @param status [Symbol] Status filter
      # @param request_id [String] Request ID filter
      # @param active_only [Boolean] Show only active workflows
      # @return [Array<Workflow>] Filtered workflows
      def list_workflows(status: nil, request_id: nil, active_only: false)
        workflows = active_only ? @active_workflows.values : @workflows.values

        workflows = workflows.select { |w| w.status == status } if status
        workflows = workflows.select { |w| w.request_id == request_id } if request_id

        workflows.sort_by(&:created_at).reverse
      end

      # Cancel workflow
      # @param workflow_id [String] Workflow ID
      # @param reason [String] Cancellation reason
      # @return [Boolean] True if workflow was cancelled
      def cancel_workflow(workflow_id, reason: nil)
        workflow = @workflows[workflow_id]
        return false unless workflow && !workflow.completed?

        workflow.cancel!(reason)
        @active_workflows.delete(workflow_id)
        true
      end

      # Get workflow statistics
      # @return [Hash] Workflow statistics
      def workflow_statistics
        total = @workflows.size
        active = @active_workflows.size
        completed = @workflows.values.count(&:completed?)

        status_counts = @workflows.values.group_by(&:status).transform_values(&:size)

        {
          total_workflows: total,
          active_workflows: active,
          completed_workflows: completed,
          status_breakdown: status_counts,
          average_completion_time: calculate_average_completion_time
        }
      end

      private

      # Calculate average completion time for completed workflows
      def calculate_average_completion_time
        completed_workflows = @workflows.values.select(&:completed?)
        return 0.0 if completed_workflows.empty?

        durations = completed_workflows.map(&:duration).compact
        return 0.0 if durations.empty?

        durations.sum / durations.size
      end
    end
  end
end
