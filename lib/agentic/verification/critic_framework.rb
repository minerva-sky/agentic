# frozen_string_literal: true

module Agentic
  module Verification
    # Framework for multi-perspective evaluation of task results
    class CriticFramework
      # @return [Array<Critic>] The critics registered with this framework
      attr_reader :critics
      
      # @return [Hash] Configuration options for the framework
      attr_reader :config
      
      # Initializes a new CriticFramework
      # @param critics [Array<Critic>] The critics to register
      # @param config [Hash] Configuration options for the framework
      def initialize(critics: [], config: {})
        @critics = critics
        @config = config
      end
      
      # Adds a critic to the framework
      # @param critic [Critic] The critic to add
      # @return [void]
      def add_critic(critic)
        @critics << critic
      end
      
      # Evaluates a task result using all registered critics
      # @param task [Task] The task to evaluate
      # @param result [TaskResult] The result to evaluate
      # @return [CriticResult] The combined evaluation result
      def evaluate(task, result)
        evaluations = @critics.map { |critic| critic.critique(task, result) }
        
        # Aggregate critic evaluations
        positive_critiques = evaluations.count(&:positive?)
        total_critiques = evaluations.size
        confidence = total_critiques > 0 ? positive_critiques.to_f / total_critiques : 0.5
        
        comments = evaluations.flat_map(&:comments)
        
        CriticResult.new(
          task_id: task.id,
          confidence: confidence,
          verdict: confidence >= 0.7, # Pass if 70% or more critics give positive evaluation
          comments: comments
        )
      end
    end
    
    # Represents the result of a critic's evaluation
    class CriticResult
      # @return [String] The ID of the task that was evaluated
      attr_reader :task_id
      
      # @return [Float] The confidence of the evaluation (0.0-1.0)
      attr_reader :confidence
      
      # @return [Boolean] The verdict of the evaluation (true = pass, false = fail)
      attr_reader :verdict
      
      # @return [Array<String>] Comments from the critic
      attr_reader :comments
      
      # Initializes a new CriticResult
      # @param task_id [String] The ID of the task that was evaluated
      # @param confidence [Float] The confidence of the evaluation (0.0-1.0)
      # @param verdict [Boolean] The verdict of the evaluation (true = pass, false = fail)
      # @param comments [Array<String>] Comments from the critic
      def initialize(task_id:, confidence:, verdict:, comments: [])
        @task_id = task_id
        @confidence = confidence
        @verdict = verdict
        @comments = comments
      end
      
      # Checks if the evaluation is positive
      # @return [Boolean] Whether the evaluation is positive
      def positive?
        @verdict
      end
      
      # Converts the critic result to a hash
      # @return [Hash] The critic result as a hash
      def to_h
        {
          task_id: @task_id,
          confidence: @confidence,
          verdict: @verdict,
          comments: @comments
        }
      end
    end
    
    # Base class for critics
    class Critic
      # @return [Hash] Configuration options for the critic
      attr_reader :config
      
      # Initializes a new Critic
      # @param config [Hash] Configuration options for the critic
      def initialize(config = {})
        @config = config
      end
      
      # Critiques a task result
      # @param task [Task] The task to critique
      # @param result [TaskResult] The result to critique
      # @return [CriticResult] The critique result
      # @raise [NotImplementedError] This method must be implemented by subclasses
      def critique(task, result)
        raise NotImplementedError, "Subclasses must implement critique"
      end
    end
  end
end