# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Artifact do
  describe "#initialize" do
    it "creates an artifact with required attributes" do
      artifact = described_class.new(
        name: "user.rb",
        type: :ruby_class,
        content: "class User; end"
      )

      expect(artifact.name).to eq("user.rb")
      expect(artifact.type).to eq(:ruby_class)
      expect(artifact.content).to eq("class User; end")
      expect(artifact.references).to eq([])
      expect(artifact.metadata).to eq({})
      expect(artifact.created_at).to be_a(Time)
    end

    it "accepts optional references" do
      artifact = described_class.new(
        name: "service.rb",
        type: :ruby_class,
        content: "class Service; end",
        references: ["user.rb", "config.rb"]
      )

      expect(artifact.references).to eq(["user.rb", "config.rb"])
    end

    it "accepts optional metadata" do
      artifact = described_class.new(
        name: "user.rb",
        type: :ruby_class,
        content: "class User; end",
        metadata: {author: "test", version: "1.0"}
      )

      expect(artifact.metadata).to eq({author: "test", version: "1.0"})
    end
  end

  describe ".detect_references" do
    context "with Ruby code" do
      it "detects require_relative with single quotes" do
        content = <<~RUBY
          require_relative 'user'
          require_relative 'config'

          class Service; end
        RUBY

        refs = described_class.detect_references(content, :ruby_class)
        expect(refs).to eq(["user", "config"])
      end

      it "detects require_relative with double quotes" do
        content = <<~RUBY
          require_relative "user"
          require_relative "models/base"
        RUBY

        refs = described_class.detect_references(content, :ruby_class)
        expect(refs).to eq(["user", "models/base"])
      end

      it "returns unique references" do
        content = <<~RUBY
          require_relative 'user'
          require_relative 'user'
        RUBY

        refs = described_class.detect_references(content, :ruby_class)
        expect(refs).to eq(["user"])
      end

      it "ignores regular require statements" do
        content = <<~RUBY
          require 'json'
          require_relative 'user'
        RUBY

        refs = described_class.detect_references(content, :ruby_class)
        expect(refs).to eq(["user"])
      end
    end

    context "with JavaScript code" do
      it "detects ES6 imports with single quotes" do
        content = <<~JS
          import User from './user'
          import { Config } from './config'
        JS

        refs = described_class.detect_references(content, :javascript_module)
        expect(refs).to match_array(["./user", "./config"])
      end

      it "detects ES6 imports with double quotes" do
        content = <<~JS
          import User from "./user"
          import * as Utils from "./utils"
        JS

        refs = described_class.detect_references(content, :javascript_module)
        expect(refs).to match_array(["./user", "./utils"])
      end

      it "returns unique references" do
        content = <<~JS
          import User from './user'
          import { Admin } from './user'
        JS

        refs = described_class.detect_references(content, :javascript_module)
        expect(refs).to eq(["./user"])
      end
    end

    context "with Python code" do
      it "detects from...import statements" do
        content = <<~PYTHON
          from models.user import User
          from config import settings
        PYTHON

        refs = described_class.detect_references(content, :python_module)
        expect(refs).to match_array(["models.user", "config"])
      end

      it "detects import statements" do
        content = <<~PYTHON
          import os
          import json
          import models.user
        PYTHON

        refs = described_class.detect_references(content, :python_module)
        expect(refs).to match_array(["os", "json", "models.user"])
      end

      it "returns unique references" do
        content = <<~PYTHON
          import user
          from user import Admin
        PYTHON

        refs = described_class.detect_references(content, :python_module)
        expect(refs).to eq(["user"])
      end
    end

    context "with unknown type" do
      it "returns empty array" do
        refs = described_class.detect_references("some content", :unknown_type)
        expect(refs).to eq([])
      end
    end
  end

  describe "#to_h" do
    it "converts artifact to hash" do
      artifact = described_class.new(
        name: "user.rb",
        type: :ruby_class,
        content: "class User; end",
        references: ["base.rb"],
        metadata: {version: "1.0"}
      )

      hash = artifact.to_h

      expect(hash[:name]).to eq("user.rb")
      expect(hash[:type]).to eq(:ruby_class)
      expect(hash[:content]).to eq("class User; end")
      expect(hash[:references]).to eq(["base.rb"])
      expect(hash[:metadata]).to eq({version: "1.0"})
      expect(hash[:created_at]).to be_a(String) # ISO8601 format
    end

    it "includes ISO8601 formatted timestamp" do
      artifact = described_class.new(
        name: "test.rb",
        type: :ruby_class,
        content: "# test"
      )

      hash = artifact.to_h
      expect { Time.iso8601(hash[:created_at]) }.not_to raise_error
    end
  end

  describe "#to_s" do
    it "returns readable string representation" do
      artifact = described_class.new(
        name: "user.rb",
        type: :ruby_class,
        content: "class User; end",
        references: ["base.rb", "module.rb"]
      )

      expect(artifact.to_s).to eq("<Artifact name=user.rb type=ruby_class references=2>")
    end
  end

  describe "#inspect" do
    it "returns detailed inspection string" do
      artifact = described_class.new(
        name: "user.rb",
        type: :ruby_class,
        content: "class User; end",
        references: ["base.rb"]
      )

      inspection = artifact.inspect
      expect(inspection).to include("Agentic::Artifact")
      expect(inspection).to include('name="user.rb"')
      expect(inspection).to include("type=ruby_class")
      expect(inspection).to include("size=")
      expect(inspection).to include('references=["base.rb"]')
    end
  end
end
