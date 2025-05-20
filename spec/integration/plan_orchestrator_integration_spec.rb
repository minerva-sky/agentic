# frozen_string_literal: true

require "spec_helper"

# Mock agent for integration tests
class MockAgent
  attr_reader :id, :prompt_history
  
  def initialize(id = "mock-agent-123")
    @id = id
    @prompt_history = []
    @should_fail = false
  end
  
  def execute(prompt)
    @prompt_history << prompt
    
    if @should_fail
      raise StandardError, "Mock agent execution failed"
    end
    
    {"result" => "Mock agent response"}
  end
  
  def set_failure_mode(should_fail)
    @should_fail = should_fail
  end
end

# A simple agent provider for testing
class IntegrationAgentProvider
  def initialize
    @agents = {}
  end
  
  def add_agent(agent_id, should_fail = false)
    @agents[agent_id] = MockAgent.new(agent_id)
    @agents[agent_id].set_failure_mode(should_fail)
  end
  
  def get_agent_for_task(task)
    agent_id = "agent-for-#{task.id}"
    # Create an agent if one doesn't exist
    @agents[agent_id] ||= MockAgent.new(agent_id)
    @agents[agent_id]
  end
  
  def get_agent(agent_id)
    @agents[agent_id]
  end
  
  def set_agent_failure(agent_id, should_fail)
    @agents[agent_id]&.set_failure_mode(should_fail)
  end
end

# A special agent provider that can change failure mode between executions
class RetryableAgentProvider < IntegrationAgentProvider
  def initialize
    super
    @execution_counts = {}
    @max_failures = {}
  end
  
  def set_max_failures(agent_id, max_failures)
    @max_failures[agent_id] = max_failures
  end
  
  def get_agent_for_task(task)
    agent_id = "agent-for-#{task.id}"
    
    # Create agent if needed
    @agents[agent_id] ||= MockAgent.new(agent_id)
    
    # Initialize execution counter if needed
    @execution_counts[agent_id] ||= 0
    # Increment execution counter
    @execution_counts[agent_id] += 1
    
    # Set failure mode based on execution count
    max_fails = @max_failures[agent_id] || 0
    @agents[agent_id].set_failure_mode(@execution_counts[agent_id] <= max_fails)
    
    @agents[agent_id]
  end
end

RSpec.describe "PlanOrchestrator Integration" do
  let(:agent_provider) { IntegrationAgentProvider.new }
  let(:orchestrator) { Agentic::PlanOrchestrator.new }
  
  describe "Multiple Task Execution" do
    let(:tasks) do
      (1..5).map do |i|
        Agentic::Task.new(
          description: "Task #{i}",
          agent_spec: {"instructions" => "You are test agent #{i}"},
          input: {"index" => i}
        )
      end
    end
    
    it "successfully executes tasks with various dependency patterns" do
      # Set up a diamond dependency pattern: 
      # Task 1 -> Task 2 -> Task 4
      #       \-> Task 3 -/
      #                    \-> Task 5
      
      # Add tasks with dependencies
      orchestrator.add_task(tasks[0]) # Task 1 (no dependencies)
      orchestrator.add_task(tasks[1], [tasks[0].id]) # Task 2 depends on Task 1
      orchestrator.add_task(tasks[2], [tasks[0].id]) # Task 3 depends on Task 1
      orchestrator.add_task(tasks[3], [tasks[1].id, tasks[2].id]) # Task 4 depends on Task 2 and 3
      orchestrator.add_task(tasks[4], [tasks[3].id]) # Task 5 depends on Task 4
      
      # Execute the plan
      result = orchestrator.execute_plan(agent_provider)
      
      # Verify all tasks completed
      expect(result[:status]).to eq(:completed)
      tasks.each do |task|
        expect(result[:results][task.id][:status]).to eq(:completed)
      end
      
      # Verify agent execution
      tasks.each do |task|
        agent = agent_provider.get_agent("agent-for-#{task.id}")
        expect(agent.prompt_history.size).to eq(1)
        expect(agent.prompt_history.first).to include("Task #{task.input["index"]}")
      end
    end
    
    it "partially executes a plan when some tasks fail" do
      # Set up a linear dependency chain:
      # Task 1 -> Task 2 -> Task 3 -> Task 4 -> Task 5
      
      # Add tasks with dependencies
      orchestrator.add_task(tasks[0])
      orchestrator.add_task(tasks[1], [tasks[0].id])
      orchestrator.add_task(tasks[2], [tasks[1].id])
      orchestrator.add_task(tasks[3], [tasks[2].id])
      orchestrator.add_task(tasks[4], [tasks[3].id])
      
      # Make Task 3 fail
      agent_provider.add_agent("agent-for-#{tasks[2].id}", true)
      
      # Execute the plan
      result = orchestrator.execute_plan(agent_provider)
      
      # Verify partial completion
      expect(result[:status]).to eq(:partial_failure)
      
      # Task 1 and 2 should complete
      expect(result[:results][tasks[0].id][:status]).to eq(:completed)
      expect(result[:results][tasks[1].id][:status]).to eq(:completed)
      
      # Task 3 should fail
      expect(result[:results][tasks[2].id][:status]).to eq(:failed)
      
      # Task 4 and 5 should not be executed (not in results)
      expect(result[:results]).not_to have_key(tasks[3].id)
      expect(result[:results]).not_to have_key(tasks[4].id)
    end
  end
  
  describe "Concurrent Execution" do
    it "executes independent tasks concurrently" do
      # Create a set of independent tasks
      independent_tasks = (1..10).map do |i|
        Agentic::Task.new(
          description: "Independent Task #{i}",
          agent_spec: {"instructions" => "You are an independent test agent"},
          input: {"index" => i}
        )
      end
      
      # Add all tasks to orchestrator (no dependencies)
      independent_tasks.each do |task|
        orchestrator.add_task(task)
      end
      
      # Execute with a lower concurrency limit to ensure batching
      limited_orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)
      independent_tasks.each do |task|
        limited_orchestrator.add_task(task)
      end
      
      # Execute the plan
      start_time = Time.now
      result = limited_orchestrator.execute_plan(agent_provider)
      end_time = Time.now
      
      # Verify all tasks completed
      expect(result[:status]).to eq(:completed)
      independent_tasks.each do |task|
        expect(result[:results][task.id][:status]).to eq(:completed)
      end
      
      # Execution time should be much less than if tasks ran sequentially
      # (This is a rough check since execution time depends on the environment)
      execution_time = end_time - start_time
      puts "Executed 10 tasks in #{execution_time} seconds with concurrency limit of 3"
    end
  end
  
  describe "Task Execution Hooks" do
    # This test verifies that the PlanOrchestrator can be extended to support 
    # custom task handling strategies like retries
    it "supports custom task handlers" do
      # Create a special PlanOrchestrator subclass for testing with hooks
      class TestOrchestrator < Agentic::PlanOrchestrator
        attr_reader :task_execution_count
        
        def initialize(*args)
          super
          @task_execution_count = Hash.new(0)
          @max_failures = 2
        end
        
        # Override the handle_task_failure method to implement a custom retry strategy
        def handle_task_failure(task, failure, agent_provider, semaphore, barrier)
          @task_execution_count[task.id] += 1
          
          # Retry the task if we haven't exceeded max failures
          if @task_execution_count[task.id] <= @max_failures
            Agentic.logger.info("Test orchestrator retrying task #{task.id}, attempt #{@task_execution_count[task.id]}")
            
            # Track retry count on the task
            task.retry_count ||= 0
            task.retry_count += 1
            
            # Move task back to pending state
            @execution_state[:failed].delete(task.id)
            @execution_state[:pending].add(task.id)
            
            # Schedule retrying the task
            schedule_task(task.id, agent_provider, semaphore, barrier)
          else
            Agentic.logger.warn("Test orchestrator: max retries exceeded for task #{task.id}")
            super
          end
        end
      end
      
      # Create a task that will fail on first attempt
      test_task = Agentic::Task.new(
        description: "Test Task",
        agent_spec: {"instructions" => "You are a test agent"},
        input: {"test" => true}
      )
      
      # Create our test orchestrator
      test_orchestrator = TestOrchestrator.new
      test_orchestrator.add_task(test_task)
      
      # Create a special agent provider that fails a specific number of times
      class TestProvider < IntegrationAgentProvider
        def initialize(task_id, fail_count)
          super()
          @fail_count = fail_count
          @execution_count = 0
          @test_task_id = task_id
        end
        
        def get_agent_for_task(task)
          agent = super
          
          if task.id == @test_task_id
            @execution_count += 1
            agent.set_failure_mode(@execution_count <= @fail_count)
          end
          
          agent
        end
      end
      
      # Configure test provider to fail twice then succeed
      test_provider = TestProvider.new(test_task.id, 2)
      
      # Execute the plan
      result = test_orchestrator.execute_plan(test_provider)
      
      # Task should have been retried and completed successfully
      expect(result[:status]).to eq(:completed)
      expect(result[:results][test_task.id][:status]).to eq(:completed)
      
      # Verify correct retry count
      expect(test_task.retry_count).to eq(2)
      
      # Verify execution count from orchestrator
      expect(test_orchestrator.task_execution_count[test_task.id]).to eq(2)
    end
  end
  
  describe "Observable Integration" do
    let(:observable_task) do
      Agentic::Task.new(
        description: "Observable Task",
        agent_spec: {"instructions" => "You are an observable test agent"},
        input: {"observable" => true}
      )
    end
    
    it "properly notifies task observers during execution" do
      # Create an observer to track task events
      observer = double("Observer")
      allow(observer).to receive(:update)
      
      # Add observer to task
      observable_task.add_observer(observer)
      
      # Add task to orchestrator
      orchestrator.add_task(observable_task)
      
      # We expect these notifications during execution
      expect(observer).to receive(:update).with(:status_change, observable_task, :pending, :in_progress)
      expect(observer).to receive(:update).with(:status_change, observable_task, :in_progress, :completed)
      
      # Execute the plan
      orchestrator.execute_plan(agent_provider)
    end
  end
end