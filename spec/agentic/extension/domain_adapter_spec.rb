# frozen_string_literal: true

RSpec.describe Agentic::Extension::DomainAdapter do
  let(:domain) { "healthcare" }
  let(:adapter) { described_class.new(domain) }
  
  describe "#initialize" do
    it "initializes with the specified domain" do
      expect(adapter.domain).to eq(domain)
    end
    
    it "initializes default adapters" do
      expect(adapter.supports?(:prompt)).to be true
      expect(adapter.supports?(:task)).to be true
      expect(adapter.supports?(:verification)).to be true
    end
    
    it "accepts custom configuration" do
      domain_config = { terminology: "medical" }
      custom_adapter = described_class.new(domain, domain_config: domain_config)
      
      expect(custom_adapter.configuration).to eq(domain_config)
    end
  end
  
  describe "#register_adapter" do
    it "registers a valid adapter" do
      custom_adapter = ->(target, context) { "#{target} adapted for #{context[:domain]}" }
      result = adapter.register_adapter(:custom, custom_adapter)
      
      expect(result).to be true
      expect(adapter.supports?(:custom)).to be true
    end
    
    it "rejects non-callable adapters" do
      result = adapter.register_adapter(:invalid, "not a callable")
      expect(result).to be false
    end
  end
  
  describe "#add_knowledge and #get_knowledge" do
    it "stores and retrieves domain knowledge" do
      knowledge = { terms: ["patient", "diagnosis", "treatment"] }
      adapter.add_knowledge(:terminology, knowledge)
      
      result = adapter.get_knowledge(:terminology)
      expect(result).to eq(knowledge)
    end
    
    it "returns nil for non-existent knowledge" do
      expect(adapter.get_knowledge(:non_existent)).to be_nil
    end
  end
  
  describe "#adapt" do
    context "with default adapters" do
      it "returns the input unchanged" do
        input = "This is a medical prompt"
        output = adapter.adapt(:prompt, input)
        
        expect(output).to eq(input)
      end
    end
    
    context "with custom adapters" do
      let(:custom_prompt_adapter) do
        ->(prompt, context) { "#{prompt} [Adapted for #{context[:domain]}]" }
      end
      
      before do
        adapter.register_adapter(:prompt, custom_prompt_adapter)
      end
      
      it "applies the adaptation to the input" do
        input = "Describe the symptoms"
        output = adapter.adapt(:prompt, input)
        
        expect(output).to eq("Describe the symptoms [Adapted for healthcare]")
      end
      
      it "passes domain knowledge to the adapter" do
        adapter.add_knowledge(:terminology, { specialty: "cardiology" })
        
        custom_adapter_with_knowledge = lambda do |prompt, context|
          specialty = context[:domain_knowledge][:terminology][:specialty]
          "#{prompt} [Adapted for #{context[:domain]} #{specialty}]"
        end
        
        adapter.register_adapter(:prompt, custom_adapter_with_knowledge)
        
        input = "Describe the symptoms"
        output = adapter.adapt(:prompt, input)
        
        expect(output).to eq("Describe the symptoms [Adapted for healthcare cardiology]")
      end
    end
    
    context "with error-raising adapters" do
      let(:error_adapter) do
        ->(_, _) { raise "Adaptation error" }
      end
      
      before do
        adapter.register_adapter(:prompt, error_adapter)
      end
      
      it "returns the original input on error" do
        input = "Original prompt"
        output = adapter.adapt(:prompt, input)
        
        expect(output).to eq(input)
      end
    end
  end
  
  describe "#supports?" do
    it "returns true for supported components" do
      expect(adapter.supports?(:prompt)).to be true
    end
    
    it "returns false for unsupported components" do
      expect(adapter.supports?(:non_existent)).to be false
    end
  end
end