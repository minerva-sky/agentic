# frozen_string_literal: true

RSpec.describe Agentic::AdaptationEngine do
  let(:engine) { described_class.new }
  let(:mock_strategy) { ->(feedback) { {adapted: true, details: feedback} } }
  
  describe "#initialize" do
    it "initializes with default values" do
      expect(engine.instance_variable_get(:@adaptation_threshold)).to eq(75)
      expect(engine.instance_variable_get(:@auto_adapt)).to eq(false)
    end
    
    it "accepts custom configuration" do
      custom_engine = described_class.new(
        adaptation_threshold: 50,
        auto_adapt: true
      )
      
      expect(custom_engine.instance_variable_get(:@adaptation_threshold)).to eq(50)
      expect(custom_engine.instance_variable_get(:@auto_adapt)).to eq(true)
    end
  end
  
  describe "#register_adaptation_strategy" do
    it "registers a valid strategy" do
      result = engine.register_adaptation_strategy(:agent, mock_strategy)
      expect(result).to eq(true)
      expect(engine.instance_variable_get(:@adaptation_registry)).to include(:agent)
    end
    
    it "rejects non-callable objects" do
      result = engine.register_adaptation_strategy(:agent, "not a strategy")
      expect(result).to eq(false)
      expect(engine.instance_variable_get(:@adaptation_registry)).not_to include(:agent)
    end
  end
  
  describe "#process_feedback" do
    before do
      engine.register_adaptation_strategy(:agent, mock_strategy)
    end
    
    context "when adaptation is not needed" do
      it "returns without adapting" do
        feedback = {
          component: :agent,
          target: double("Agent"),
          metrics: {confidence: 90},
          outcome: :success
        }
        
        result = engine.process_feedback(feedback)
        expect(result[:adapted]).to eq(false)
      end
    end
    
    context "when adaptation is needed but auto-adapt is off" do
      it "suggests but does not apply adaptation" do
        feedback = {
          component: :agent,
          target: double("Agent"),
          metrics: {confidence: 50},
          outcome: :failure,
          suggestion: "Improve agent prompting"
        }
        
        result = engine.process_feedback(feedback)
        expect(result[:adapted]).to eq(false)
        expect(result[:adaptation_suggested]).to eq(true)
      end
    end
    
    context "when adaptation is needed and auto-adapt is on" do
      let(:engine) { described_class.new(auto_adapt: true) }
      
      before do
        engine.register_adaptation_strategy(:agent, mock_strategy)
      end
      
      it "applies the adaptation" do
        feedback = {
          component: :agent,
          target: double("Agent"),
          metrics: {confidence: 50},
          outcome: :failure
        }
        
        result = engine.process_feedback(feedback)
        expect(result[:adapted]).to eq(true)
      end
    end
  end
  
  describe "#apply_adaptation" do
    before do
      engine.register_adaptation_strategy(:agent, mock_strategy)
    end
    
    it "applies registered adaptation strategies" do
      feedback = {
        component: :agent,
        target: double("Agent"),
        metrics: {confidence: 50}
      }
      
      result = engine.apply_adaptation(feedback)
      expect(result[:adapted]).to eq(true)
    end
    
    it "handles missing adaptation strategies" do
      feedback = {
        component: :unknown,
        target: double("Unknown"),
        metrics: {confidence: 50}
      }
      
      result = engine.apply_adaptation(feedback)
      expect(result[:adapted]).to eq(false)
      expect(result[:reason]).to include("No adaptation strategy registered")
    end
    
    it "handles adaptation errors" do
      error_strategy = ->(_) { raise "Adaptation failed" }
      engine.register_adaptation_strategy(:task, error_strategy)
      
      feedback = {
        component: :task,
        target: double("Task"),
        metrics: {confidence: 50}
      }
      
      result = engine.apply_adaptation(feedback)
      expect(result[:adapted]).to eq(false)
      expect(result[:error]).to eq("Adaptation failed")
    end
  end
  
  describe "#adaptation_history" do
    before do
      engine.register_adaptation_strategy(:agent, mock_strategy)
      engine.register_adaptation_strategy(:task, mock_strategy)
      
      # Add some feedback to history
      engine.process_feedback({
        component: :agent,
        target: double("Agent"),
        metrics: {confidence: 50},
        outcome: :failure
      })
      
      engine.process_feedback({
        component: :task,
        target: double("Task"),
        metrics: {confidence: 40},
        outcome: :failure
      })
    end
    
    it "returns full history when no component is specified" do
      history = engine.adaptation_history
      expect(history.size).to eq(2)
    end
    
    it "filters history by component" do
      agent_history = engine.adaptation_history(:agent)
      expect(agent_history.size).to eq(1)
      expect(agent_history.first[:component]).to eq(:agent)
      
      task_history = engine.adaptation_history(:task)
      expect(task_history.size).to eq(1)
      expect(task_history.first[:component]).to eq(:task)
    end
  end
end