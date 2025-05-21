# frozen_string_literal: true

RSpec.describe Agentic::Extension::ProtocolHandler do
  let(:handler) { described_class.new }
  
  # Create a mock protocol implementation
  let(:mock_protocol) do
    Class.new do
      def send_request(endpoint, options = {})
        {
          status: 200,
          body: "Response from #{endpoint}",
          options: options
        }
      end
    end
  end
  
  # Create an invalid protocol implementation
  let(:invalid_protocol) do
    Class.new do
      def invalid_method(endpoint, options = {})
        "This won't work"
      end
    end
  end
  
  describe "#initialize" do
    it "initializes with empty protocols" do
      expect(handler.instance_variable_get(:@protocols)).to be_empty
    end
    
    it "accepts custom default headers" do
      headers = { "User-Agent" => "AgenticTest" }
      custom_handler = described_class.new(default_headers: headers)
      
      expect(custom_handler.instance_variable_get(:@default_headers)).to eq(headers)
    end
  end
  
  describe "#register_protocol" do
    it "registers a valid protocol" do
      protocol = mock_protocol.new
      result = handler.register_protocol(:http, protocol)
      
      expect(result).to be true
      expect(handler.protocol_registered?(:http)).to be true
    end
    
    it "rejects invalid protocols" do
      protocol = invalid_protocol.new
      result = handler.register_protocol(:invalid, protocol)
      
      expect(result).to be false
      expect(handler.protocol_registered?(:invalid)).to be false
    end
    
    it "stores protocol configuration" do
      protocol = mock_protocol.new
      config = { timeout: 30, retries: 3 }
      
      handler.register_protocol(:http, protocol, config)
      stored_config = handler.protocol_config(:http)
      
      expect(stored_config).to eq(config)
    end
  end
  
  describe "#send_request" do
    before do
      handler.register_protocol(:http, mock_protocol.new, timeout: 30)
    end
    
    it "successfully sends requests through registered protocols" do
      response = handler.send_request(:http, "/api/test", method: "GET")
      
      expect(response).to include(
        status: 200,
        body: "Response from /api/test"
      )
    end
    
    it "merges default headers with request headers" do
      handler = described_class.new(default_headers: { "User-Agent" => "AgenticTest" })
      handler.register_protocol(:http, mock_protocol.new)
      
      response = handler.send_request(:http, "/api/test", 
                                     headers: { "Content-Type" => "application/json" })
      
      expect(response[:options][:headers]).to include(
        "User-Agent" => "AgenticTest",
        "Content-Type" => "application/json"
      )
    end
    
    it "returns nil for unregistered protocols" do
      response = handler.send_request(:unregistered, "/api/test")
      expect(response).to be_nil
    end
    
    it "handles protocol errors" do
      error_protocol = Class.new do
        def send_request(*)
          raise "Protocol error"
        end
      end
      
      handler.register_protocol(:error, error_protocol.new)
      response = handler.send_request(:error, "/api/test")
      
      expect(response).to be_nil
    end
  end
  
  describe "#protocol_config and #update_protocol_config" do
    before do
      handler.register_protocol(:http, mock_protocol.new, timeout: 30, retries: 3)
    end
    
    it "retrieves protocol configuration" do
      config = handler.protocol_config(:http)
      
      expect(config).to include(timeout: 30, retries: 3)
    end
    
    it "returns nil for unregistered protocols" do
      expect(handler.protocol_config(:unregistered)).to be_nil
    end
    
    it "updates protocol configuration" do
      result = handler.update_protocol_config(:http, timeout: 60, new_option: true)
      
      expect(result).to be true
      
      updated_config = handler.protocol_config(:http)
      expect(updated_config).to include(
        timeout: 60,
        retries: 3,
        new_option: true
      )
    end
    
    it "returns false when updating unregistered protocols" do
      result = handler.update_protocol_config(:unregistered, timeout: 60)
      expect(result).to be false
    end
  end
  
  describe "#list_protocols" do
    before do
      handler.register_protocol(:http, mock_protocol.new)
      handler.register_protocol(:websocket, mock_protocol.new)
    end
    
    it "lists all registered protocols" do
      protocols = handler.list_protocols
      expect(protocols).to contain_exactly(:http, :websocket)
    end
    
    it "returns an empty array when no protocols are registered" do
      empty_handler = described_class.new
      expect(empty_handler.list_protocols).to be_empty
    end
  end
end