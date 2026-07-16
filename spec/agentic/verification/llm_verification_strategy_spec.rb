# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Verification::LlmVerificationStrategy do
  let(:llm_client) { double("LlmClient") }
  let(:task) { double("Task", id: "task_123") }
  let(:successful_result) { double("TaskResult", successful?: true, failed?: false) }
  let(:failed_result) { double("TaskResult", successful?: false, failed?: true) }

  describe ".new" do
    context "with valid llm_client" do
      it "initializes with default configuration" do
        strategy = described_class.new(llm_client)

        expect(strategy.llm_client).to eq(llm_client)
        expect(strategy.config[:confidence_threshold]).to eq(0.7)
        expect(strategy.config[:max_retries]).to eq(1)
        expect(strategy.config[:timeout_seconds]).to eq(30)
      end
    end

    context "with custom configuration" do
      let(:config) { {confidence_threshold: 0.9, max_retries: 3} }

      it "merges custom config with defaults" do
        strategy = described_class.new(llm_client, config)

        expect(strategy.config[:confidence_threshold]).to eq(0.9)
        expect(strategy.config[:max_retries]).to eq(3)
        expect(strategy.config[:timeout_seconds]).to eq(30) # default preserved
      end
    end

    context "with nil llm_client" do
      it "raises ArgumentError" do
        expect { described_class.new(nil) }
          .to raise_error(ArgumentError, "LLM client cannot be nil")
      end
    end
  end

  describe "#verify" do
    subject { described_class.new(llm_client) }

    context "when task result is successful" do
      before do
        # Stub the random behavior for consistent testing
        allow(subject).to receive(:rand).and_return(0.5) # Will generate verified=true, confidence ~0.9
      end

      it "performs LLM verification" do
        result = subject.verify(task, successful_result)

        expect(result).to be_a(Agentic::Verification::VerificationResult)
        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be true
        expect(result.confidence).to be > 0.8
        expect(result.messages.first).to eq("Result meets task requirements")
      end

      context "with low confidence result" do
        let(:config) { {confidence_threshold: 0.9} }
        subject { described_class.new(llm_client, config) }

        before do
          # Generate confidence below threshold
          allow(subject).to receive(:rand).and_return(0.5, 0.1) # verified=true, confidence ~0.85
        end

        it "fails verification when confidence below threshold" do
          result = subject.verify(task, successful_result)

          expect(result.verified).to be false
          expect(result.messages.first).to match(/Verification confidence below threshold/)
        end
      end
    end

    context "when task result failed" do
      it "returns failed task result without LLM verification" do
        result = subject.verify(task, failed_result)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages).to include("Task failed, skipping LLM verification")
      end
    end

    context "when LLM verification raises exception" do
      before do
        allow(subject).to receive(:perform_llm_verification).and_raise(StandardError, "API error")
        allow(Agentic.logger).to receive(:warn)
        allow(Agentic.logger).to receive(:error)
      end

      context "with retries available" do
        let(:config) { {max_retries: 2} }
        subject { described_class.new(llm_client, config) }

        it "retries on failure" do
          expect(subject).to receive(:perform_llm_verification).exactly(3).times.and_raise(StandardError, "API error")

          result = subject.verify(task, successful_result)

          expect(result.verified).to be false
          expect(result.messages.first).to match(/LLM verification error/)
        end

        context "when retry succeeds" do
          it "returns successful result after retry" do
            call_count = 0
            allow(subject).to receive(:perform_llm_verification) do
              call_count += 1
              if call_count == 1
                raise StandardError, "API error"
              else
                Agentic::Verification::VerificationResult.new(
                  task_id: task.id,
                  verified: true,
                  confidence: 0.8,
                  messages: ["Success on retry"]
                )
              end
            end

            result = subject.verify(task, successful_result)

            expect(result.verified).to be true
            expect(result.messages).to include("Success on retry")
          end
        end
      end

      context "without retries" do
        let(:config) { {max_retries: 0} }
        subject { described_class.new(llm_client, config) }

        it "returns error result immediately" do
          result = subject.verify(task, successful_result)

          expect(result.verified).to be false
          expect(result.messages.first).to match(/LLM verification error/)
        end
      end
    end

    context "with simulated failing verification" do
      before do
        # Generate verified=false with high confidence (above threshold)
        allow(subject).to receive(:rand).and_return(0.05, 0.1) # verified=false, confidence ~0.8
      end

      it "returns failed verification result" do
        result = subject.verify(task, successful_result)

        expect(result.verified).to be false
        expect(result.confidence).to be > 0.7
        expect(result.messages.first).to eq("Result does not fully satisfy task requirements")
      end
    end
  end

  describe "private methods" do
    subject { described_class.new(llm_client) }

    describe "#failed_task_result" do
      it "creates appropriate failure result" do
        result = subject.send(:failed_task_result, task)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages).to include("Task failed, skipping LLM verification")
      end
    end

    describe "#error_result" do
      let(:error) { StandardError.new("Test error") }

      it "creates appropriate error result" do
        result = subject.send(:error_result, task, error)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages.first).to eq("LLM verification error: Test error")
      end
    end

    describe "#perform_llm_verification" do
      before do
        # Use real random for this test to verify the simulation works
        allow(subject).to receive(:rand).and_call_original
      end

      it "returns verification result with random simulation" do
        result = subject.send(:perform_llm_verification, task, successful_result)

        expect(result).to be_a(Agentic::Verification::VerificationResult)
        expect(result.task_id).to eq(task.id)
        expect(result.confidence).to be_between(0.3, 1.0)
        expect(result.messages).not_to be_empty
      end

      it "generates results consistent with verification outcome" do
        # Test verified=true case
        allow(subject).to receive(:rand).and_return(0.5, 0.1) # verified=true, confidence ~0.9
        result = subject.send(:perform_llm_verification, task, successful_result)

        expect(result.verified).to be true
        expect(result.confidence).to be >= 0.8
        expect(result.messages.first).to eq("Result meets task requirements")

        # Test verified=false case
        allow(subject).to receive(:rand).and_return(0.05, 0.1) # verified=false, confidence ~0.8
        result = subject.send(:perform_llm_verification, task, successful_result)

        expect(result.verified).to be false
        expect(result.confidence).to be >= 0.7
        expect(result.messages.first).to eq("Result does not fully satisfy task requirements")
      end
    end
  end

  describe "inheritance" do
    it "inherits from VerificationStrategy" do
      expect(described_class.ancestors).to include(Agentic::Verification::VerificationStrategy)
    end
  end
end
