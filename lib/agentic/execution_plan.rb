# frozen_string_literal: true

module Agentic
  # Value object representing an execution plan with tasks and expected answer
  #
  # This class is part of the data-presentation separation pattern:
  # 1. TaskPlanner generates the core plan data
  # 2. ExecutionPlan serves as a structured value object to hold this data
  # 3. The to_s method provides presentation capabilities when needed
  #
  # Using a value object instead of raw hashes provides:
  # - Type safety
  # - Domain-specific methods
  # - Encapsulation of presentation logic
  # - Clearer interfaces between components
  class ExecutionPlan
    # @return [Array<TaskDefinition>] The list of tasks to accomplish the goal
    attr_reader :tasks

    # @return [ExpectedAnswerFormat] The expected answer format
    attr_reader :expected_answer

    # @param tasks [Array<TaskDefinition>] The list of tasks to accomplish the goal
    # @param expected_answer [ExpectedAnswerFormat] The expected answer format
    def initialize(tasks, expected_answer)
      @tasks = tasks
      @expected_answer = expected_answer
    end

    # Returns a hash representation of the execution plan
    # @return [Hash] The execution plan as a hash
    def to_h
      {
        tasks: @tasks.map(&:to_h),
        expected_answer: @expected_answer.to_h
      }
    end

    # Returns a formatted string representation of the execution plan
    # @return [String] The formatted execution plan
    def to_s
      plan = "Execution Plan:\n\n"
      @tasks.each_with_index do |task, index|
        plan += "#{index + 1}. #{task.description} (Agent: #{task.agent.name})\n"
      end
      plan += "\nExpected Answer:\n"
      plan += "Format: #{@expected_answer.format}\n"
      plan += "Sections: #{@expected_answer.sections.join(", ")}\n"
      plan += "Length: #{@expected_answer.length}\n"
      plan
    end
  end
end
