# frozen_string_literal: true

module Agentic
  # Handles the task planning process for Agentic using LLM
  #
  # This class follows separation of concerns by:
  # 1. Focusing on core planning logic and data generation
  # 2. Returning structured data (ExecutionPlan) instead of formatted strings
  # 3. Delegating presentation concerns to the ExecutionPlan class
  class TaskPlanner
    # @return [String] The goal to be accomplished
    attr_reader :goal

    # @return [Array<TaskDefinition>] The list of tasks to accomplish the goal
    attr_reader :tasks

    # @return [ExpectedAnswerFormat] The expected answer format
    attr_reader :expected_answer

    # @return [LlmConfig] The configuration for the LLM
    attr_reader :llm_config

    # @return [Proc] Optional stream callback for real-time progress
    attr_reader :stream_callback

    # @return [Object] Optional observer for planning progress
    attr_reader :observer

    # Initializes a new TaskPlanner
    # @param goal [String] The goal to be accomplished
    # @param llm_config [LlmConfig] The configuration for the LLM
    # @param stream_callback [Proc] Optional callback for streaming progress
    # @param observer [Object] Optional observer for planning progress
    def initialize(goal, llm_config = LlmConfig.new, stream_callback: nil, observer: nil)
      @goal = goal
      @tasks = []
      @expected_answer = ExpectedAnswerFormat.new(
        format: "Undetermined",
        sections: [],
        length: "Undetermined"
      )
      @llm_config = llm_config
      @stream_callback = stream_callback
      @observer = observer
    end

    # Analyzes the goal and breaks it down into tasks using LLM
    # @return [void]
    def analyze_goal
      @observer&.phase_started(:analyze_goal, "Breaking down goal into actionable tasks")

      system_message = "You are an expert project planner. Your task is to break down complex goals into actionable tasks."
      user_message = "Goal: #{@goal}\n\nBreak this goal down into a series of tasks. For each task:\n1. Specify the type of agent best suited to complete it.\n2. Include a brief description of the agent\n3. Include a set of instructions that the agent can follow to perform this task."

      schema = StructuredOutputs::Schema.new("tasks") do |s|
        s.array :tasks, items: {
          type: "object",
          properties: {
            description: {type: "string"},
            agent: {
              type: "object",
              properties: {
                name: {type: "string"},
                description: {type: "string"},
                instructions: {type: "string"}
              },
              required: %w[name description instructions]
            }
          },
          required: %w[description agent]
        }
      end

      response = llm_request(system_message, user_message, schema)

      if response.successful?
        tasks_data = response.content["tasks"]

        # Validate the response structure before processing
        unless tasks_data.is_a?(Array)
          Agentic.logger.error("Invalid response structure: 'tasks' should be an array, got #{tasks_data.class}")
          @tasks = []
          return
        end

        @tasks = tasks_data.map.with_index do |task_data, index|
          # Validate each task data structure
          unless task_data.is_a?(Hash)
            Agentic.logger.error("Invalid task data at index #{index}: expected Hash, got #{task_data.class}")
            next
          end

          unless task_data["description"] && task_data["agent"]
            Agentic.logger.error("Missing required fields in task data at index #{index}")
            next
          end

          agent_data = task_data["agent"]
          unless agent_data.is_a?(Hash) && agent_data["name"] && agent_data["description"] && agent_data["instructions"]
            Agentic.logger.error("Invalid agent data in task at index #{index}")
            next
          end

          TaskDefinition.new(
            description: task_data["description"],
            agent: AgentSpecification.new(
              name: agent_data["name"],
              description: agent_data["description"],
              instructions: agent_data["instructions"]
            )
          )
        end.compact

        @observer&.phase_completed(:analyze_goal, "#{@tasks.length} tasks identified")
      else
        error_message = response.error&.message || response.refusal || "Unknown error"
        Agentic.logger.error("Failed to analyze goal: #{error_message}")
        @observer&.planning_failed("Goal analysis failed: #{error_message}")
        @tasks = []
      end
    end

    # Determines the expected answer format using LLM
    # @return [void]
    def determine_expected_answer
      @observer&.phase_started(:determine_format, "Determining optimal output structure")

      system_message = "You are an expert in report structuring and formatting. Your task is to determine the best format for a given report goal."
      user_message = "Goal: #{@goal}\n\nDetermine the optimal format, sections, and length for a report addressing this goal."

      schema = StructuredOutputs::Schema.new("answer_format") do |s|
        s.string :format
        s.array :sections, items: {type: "string"}
        s.string :length
      end

      response = llm_request(system_message, user_message, schema)

      if response.successful?
        @expected_answer = ExpectedAnswerFormat.new(
          format: response.content["format"],
          sections: response.content["sections"],
          length: response.content["length"]
        )

        format_summary = "#{@expected_answer.format} format with #{@expected_answer.sections.length} sections"
        @observer&.phase_completed(:determine_format, format_summary)
      else
        error_message = response.error&.message || response.refusal || "Unknown error"
        Agentic.logger.error("Failed to determine expected answer format: #{error_message}")
        @observer&.planning_failed("Format determination failed: #{error_message}")
        @expected_answer = ExpectedAnswerFormat.new(
          format: "Undetermined",
          sections: [],
          length: "Undetermined"
        )
      end
    end

    # Returns an ExecutionPlan object representing the execution plan
    # @return [ExecutionPlan] The structured execution plan
    def execution_plan
      ExecutionPlan.new(@tasks, @expected_answer)
    end

    # Executes the entire planning process
    # @return [ExecutionPlan] The structured execution plan
    def plan
      analyze_goal
      determine_expected_answer
      execution_plan
    end

    private

    # Makes a request to the LLM
    # @param system_message [String] The system message for the LLM
    # @param user_message [String] The user message for the LLM
    # @param schema [StructuredOutputs::Schema] The schema for structured output
    # @return [Hash] The LLM's response
    def llm_request(system_message, user_message, schema)
      messages = [
        {role: "system", content: system_message},
        {role: "user", content: user_message}
      ]

      # Create observer-aware stream callback
      enhanced_stream_callback = if @observer && @stream_callback
        proc do |event_type, data|
          @observer.token_received(data) if event_type == :token_received
          @stream_callback.call(event_type, data)
        end
      elsif @observer
        proc do |event_type, data|
          @observer.token_received(data) if event_type == :token_received
        end
      else
        @stream_callback
      end

      llm_client.complete(messages, output_schema: schema, stream_callback: enhanced_stream_callback)
    end

    def llm_client
      @llm_client ||= Agentic.client(@llm_config)
    end
  end
end
