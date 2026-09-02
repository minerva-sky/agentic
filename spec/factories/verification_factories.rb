# frozen_string_literal: true

module VerificationFactories
  # Factory for creating test tasks with verification metadata
  def build_task(id: "test_task_#{rand(1000)}", input: {}, metadata: {})
    double("Task", id: id, input: input, metadata: metadata).tap do |task|
      allow(task).to receive(:respond_to?).with(:metadata).and_return(!metadata.empty?)
    end
  end

  # Factory for creating test task results
  def build_task_result(successful: true, failed: false, output: "test output")
    double("TaskResult", successful?: successful, failed?: failed, output: output)
  end

  # Factory for creating verification results
  def build_verification_result(task_id:, verified: true, confidence: 0.85, messages: ["Test verification"])
    Agentic::Verification::VerificationResult.new(
      task_id: task_id,
      verified: verified,
      confidence: confidence,
      messages: messages
    )
  end

  # Factory for creating mock verification strategies
  def build_mock_strategy(verification_result: nil)
    double("VerificationStrategy").tap do |strategy|
      allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
      if verification_result
        allow(strategy).to receive(:verify).and_return(verification_result)
      end
    end
  end

  # Factory for creating tasks with schema
  def build_task_with_schema(schema:, id: "schema_task_#{rand(1000)}")
    build_task(id: id, input: {output_schema: schema})
  end

  # Factory for creating tasks with metadata schema
  def build_task_with_metadata_schema(schema:, id: "metadata_task_#{rand(1000)}")
    build_task(id: id, metadata: {output_schema: schema})
  end

  # Factory for creating LLM clients
  def build_llm_client
    double("LlmClient")
  end

  # Common test schemas
  def simple_object_schema
    {"type" => "object", "properties" => {"name" => {"type" => "string"}}}
  end

  def string_schema
    {"type" => "string"}
  end

  def complex_schema
    {
      "type" => "object",
      "properties" => {
        "result" => {"type" => "string"},
        "confidence" => {"type" => "number", "minimum" => 0, "maximum" => 1},
        "metadata" => {
          "type" => "object",
          "properties" => {
            "timestamp" => {"type" => "string", "format" => "date-time"}
          }
        }
      },
      "required" => ["result"]
    }
  end
end
