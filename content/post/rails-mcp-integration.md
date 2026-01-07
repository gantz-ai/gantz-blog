+++
title = "Rails MCP Integration: Ruby AI Applications"
image = "/images/rails-mcp-integration.png"
date = 2025-11-27
description = "Integrate MCP tools with Ruby on Rails. Build AI-powered web applications with Active Job, Action Cable, and Rails conventions."
draft = false
tags = ['mcp', 'rails', 'ruby', 'web']
voice = false

[howto]
name = "Integrate MCP with Rails"
totalTime = 30
[[howto.steps]]
name = "Set up Rails project"
text = "Create Rails app with MCP gem dependencies."
[[howto.steps]]
name = "Create tool service"
text = "Build service objects for tool execution."
[[howto.steps]]
name = "Add API controllers"
text = "Create API endpoints for tools."
[[howto.steps]]
name = "Implement background jobs"
text = "Use Active Job for async execution."
[[howto.steps]]
name = "Add real-time features"
text = "Stream with Action Cable."
+++


Rails makes web development joyful. MCP adds AI intelligence.

Together, they build elegant AI applications.

## Why Rails + MCP

Rails provides:
- Convention over configuration
- Active Record ORM
- Active Job background processing
- Action Cable real-time

MCP provides:
- AI tool execution
- LLM integration
- Agent orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: rails-mcp-app

tools:
  - name: generate_content
    description: Generate AI content
    parameters:
      - name: prompt
        type: string
        required: true
    script:
      command: ruby
      args: ["tools/generate.rb"]
```

Gemfile additions:

```ruby
# Gemfile
gem 'anthropic', '~> 0.1'
gem 'sidekiq', '~> 7.0'
gem 'redis', '~> 5.0'

group :development, :test do
  gem 'rspec-rails', '~> 6.0'
end
```

Configuration:

```ruby
# config/initializers/anthropic.rb
require 'anthropic'

Anthropic.configure do |config|
  config.api_key = ENV['ANTHROPIC_API_KEY']
end
```

```ruby
# config/application.rb
module RailsMcpApp
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true

    # Active Job adapter
    config.active_job.queue_adapter = :sidekiq
  end
end
```

## Step 2: MCP service

Service object for tool execution:

```ruby
# app/services/mcp/tool_service.rb
module MCP
  class ToolService
    TOOLS = {
      'generate_content' => 'MCP::Tools::GenerateContent',
      'summarize' => 'MCP::Tools::Summarize',
      'analyze' => 'MCP::Tools::Analyze',
      'classify' => 'MCP::Tools::Classify'
    }.freeze

    class << self
      def execute(tool_name, params = {})
        tool_class = TOOLS[tool_name]
        raise ToolNotFoundError, "Unknown tool: #{tool_name}" unless tool_class

        tool = tool_class.constantize.new(params)
        tool.execute
      end

      def list_tools
        TOOLS.map do |name, klass|
          {
            name: name,
            description: klass.constantize.description
          }
        end
      end
    end
  end

  class ToolNotFoundError < StandardError; end
end
```

Base tool class:

```ruby
# app/services/mcp/tools/base.rb
module MCP
  module Tools
    class Base
      attr_reader :params

      def initialize(params = {})
        @params = params.with_indifferent_access
        @client = Anthropic::Client.new
      end

      def execute
        validate_params!
        perform
      rescue Anthropic::Error => e
        Result.failure(e.message)
      end

      def self.description
        raise NotImplementedError
      end

      private

      def validate_params!
        # Override in subclasses
      end

      def perform
        raise NotImplementedError
      end

      def client
        @client
      end
    end

    class Result
      attr_reader :data, :error

      def initialize(success:, data: nil, error: nil)
        @success = success
        @data = data
        @error = error
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def self.success(data)
        new(success: true, data: data)
      end

      def self.failure(error)
        new(success: false, error: error)
      end

      def to_h
        if success?
          { success: true, data: data }
        else
          { success: false, error: error }
        end
      end
    end
  end
end
```

Tool implementations:

```ruby
# app/services/mcp/tools/generate_content.rb
module MCP
  module Tools
    class GenerateContent < Base
      def self.description
        'Generate AI content based on a prompt'
      end

      private

      def validate_params!
        raise ArgumentError, 'prompt is required' unless params[:prompt].present?
      end

      def perform
        response = client.messages(
          model: 'claude-sonnet-4-20250514',
          max_tokens: params[:max_tokens] || 500,
          messages: [{ role: 'user', content: params[:prompt] }]
        )

        Result.success(
          content: response.content.first.text,
          usage: {
            input_tokens: response.usage.input_tokens,
            output_tokens: response.usage.output_tokens
          }
        )
      end
    end
  end
end

# app/services/mcp/tools/summarize.rb
module MCP
  module Tools
    class Summarize < Base
      def self.description
        'Summarize text content'
      end

      private

      def validate_params!
        raise ArgumentError, 'text is required' unless params[:text].present?
      end

      def perform
        response = client.messages(
          model: 'claude-sonnet-4-20250514',
          max_tokens: params[:max_length] || 200,
          messages: [{
            role: 'user',
            content: "Summarize this text concisely:\n\n#{params[:text]}"
          }]
        )

        Result.success(
          summary: response.content.first.text,
          original_length: params[:text].length
        )
      end
    end
  end
end

# app/services/mcp/tools/analyze.rb
module MCP
  module Tools
    class Analyze < Base
      def self.description
        'Analyze content for insights'
      end

      private

      def validate_params!
        raise ArgumentError, 'content is required' unless params[:content].present?
      end

      def perform
        response = client.messages(
          model: 'claude-sonnet-4-20250514',
          max_tokens: 1000,
          messages: [{
            role: 'user',
            content: "Analyze this content and provide insights:\n\n#{params[:content]}"
          }]
        )

        Result.success(
          analysis: response.content.first.text
        )
      end
    end
  end
end
```

## Step 3: API controllers

Rails API controllers:

```ruby
# app/controllers/api/v1/tools_controller.rb
module Api
  module V1
    class ToolsController < ApplicationController
      before_action :authenticate_api_key!

      def index
        render json: { tools: MCP::ToolService.list_tools }
      end

      def execute
        result = MCP::ToolService.execute(
          params[:tool_name],
          tool_params
        )

        render json: result.to_h, status: result.success? ? :ok : :bad_request
      rescue MCP::ToolNotFoundError => e
        render json: { success: false, error: e.message }, status: :not_found
      rescue ArgumentError => e
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end

      def show
        result = MCP::ToolService.execute(params[:id], tool_params)
        render json: result.to_h, status: result.success? ? :ok : :bad_request
      rescue MCP::ToolNotFoundError => e
        render json: { success: false, error: e.message }, status: :not_found
      end

      private

      def tool_params
        params.except(:controller, :action, :tool_name, :id).permit!.to_h
      end

      def authenticate_api_key!
        api_key = request.headers['X-API-Key']
        return if api_key.present? && valid_api_key?(api_key)

        render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      def valid_api_key?(key)
        valid_keys = ENV['API_KEYS']&.split(',') || []
        valid_keys.include?(key)
      end
    end
  end
end
```

Routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :tools, only: [:index, :show] do
        collection do
          post :execute
        end
      end

      resources :chat, only: [:create]
      post 'chat/stream', to: 'chat#stream'
    end
  end

  # Action Cable
  mount ActionCable.server => '/cable'
end
```

## Step 4: Background jobs

Active Job for async execution:

```ruby
# app/jobs/tool_execution_job.rb
class ToolExecutionJob < ApplicationJob
  queue_as :tools

  def perform(execution_id)
    execution = ToolExecution.find(execution_id)
    execution.update!(status: :running)

    start_time = Time.current

    result = MCP::ToolService.execute(
      execution.tool_name,
      execution.parameters
    )

    duration = ((Time.current - start_time) * 1000).to_i

    if result.success?
      execution.update!(
        status: :completed,
        result: result.data,
        duration_ms: duration
      )
    else
      execution.update!(
        status: :failed,
        error: result.error,
        duration_ms: duration
      )
    end
  rescue StandardError => e
    execution.update!(status: :failed, error: e.message)
    raise
  end
end
```

Execution model:

```ruby
# app/models/tool_execution.rb
class ToolExecution < ApplicationRecord
  enum status: {
    pending: 'pending',
    running: 'running',
    completed: 'completed',
    failed: 'failed'
  }

  validates :tool_name, presence: true
  validates :status, presence: true

  def execute_async!
    update!(status: :pending)
    ToolExecutionJob.perform_later(id)
  end
end
```

```ruby
# db/migrate/20250101000000_create_tool_executions.rb
class CreateToolExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :tool_executions, id: :uuid do |t|
      t.string :tool_name, null: false
      t.jsonb :parameters, default: {}
      t.jsonb :result
      t.text :error
      t.string :status, default: 'pending'
      t.integer :duration_ms

      t.timestamps
    end

    add_index :tool_executions, :status
    add_index :tool_executions, :tool_name
  end
end
```

Async controller:

```ruby
# app/controllers/api/v1/executions_controller.rb
module Api
  module V1
    class ExecutionsController < ApplicationController
      before_action :authenticate_api_key!

      def create
        execution = ToolExecution.create!(
          tool_name: params[:tool_name],
          parameters: execution_params
        )

        execution.execute_async!

        render json: {
          execution_id: execution.id,
          status: execution.status
        }, status: :accepted
      end

      def show
        execution = ToolExecution.find(params[:id])

        render json: {
          id: execution.id,
          status: execution.status,
          result: execution.result,
          error: execution.error,
          duration_ms: execution.duration_ms
        }
      end

      private

      def execution_params
        params.except(:controller, :action, :tool_name, :id).permit!.to_h
      end
    end
  end
end
```

## Step 5: Action Cable streaming

Real-time streaming:

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end

  def receive(data)
    ChatStreamJob.perform_later(
      params[:room],
      data['prompt'],
      data['max_tokens'] || 500
    )
  end

  def unsubscribed
    # Cleanup
  end
end
```

```ruby
# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  queue_as :chat

  def perform(room, prompt, max_tokens)
    client = Anthropic::Client.new

    ActionCable.server.broadcast(
      "chat_#{room}",
      { type: 'stream_start' }
    )

    client.messages_stream(
      model: 'claude-sonnet-4-20250514',
      max_tokens: max_tokens,
      messages: [{ role: 'user', content: prompt }]
    ) do |event|
      if event.type == 'content_block_delta'
        ActionCable.server.broadcast(
          "chat_#{room}",
          { type: 'chunk', text: event.delta.text }
        )
      end
    end

    ActionCable.server.broadcast(
      "chat_#{room}",
      { type: 'stream_end' }
    )
  rescue StandardError => e
    ActionCable.server.broadcast(
      "chat_#{room}",
      { type: 'error', message: e.message }
    )
  end
end
```

SSE streaming controller:

```ruby
# app/controllers/api/v1/chat_controller.rb
module Api
  module V1
    class ChatController < ApplicationController
      include ActionController::Live

      def create
        result = MCP::ToolService.execute('generate_content', {
          prompt: params[:prompt],
          max_tokens: params[:max_tokens] || 500
        })

        render json: result.to_h
      end

      def stream
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'

        client = Anthropic::Client.new

        client.messages_stream(
          model: 'claude-sonnet-4-20250514',
          max_tokens: params[:max_tokens] || 500,
          messages: [{ role: 'user', content: params[:prompt] }]
        ) do |event|
          if event.type == 'content_block_delta'
            response.stream.write "data: #{event.delta.text.to_json}\n\n"
          end
        end

        response.stream.write "data: [DONE]\n\n"
      rescue StandardError => e
        response.stream.write "data: #{({ error: e.message }).to_json}\n\n"
      ensure
        response.stream.close
      end
    end
  end
end
```

## Step 6: Caching

Rails caching for tools:

```ruby
# app/services/mcp/cached_tool_service.rb
module MCP
  class CachedToolService
    CACHE_TTL = 1.hour

    class << self
      def execute(tool_name, params = {})
        cache_key = generate_cache_key(tool_name, params)

        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          ToolService.execute(tool_name, params).to_h
        end
      end

      def execute_uncached(tool_name, params = {})
        ToolService.execute(tool_name, params)
      end

      def invalidate(tool_name, params = {})
        cache_key = generate_cache_key(tool_name, params)
        Rails.cache.delete(cache_key)
      end

      private

      def generate_cache_key(tool_name, params)
        param_hash = Digest::MD5.hexdigest(params.to_json)
        "mcp:tool:#{tool_name}:#{param_hash}"
      end
    end
  end
end
```

## Summary

Rails + MCP integration:

1. **Service objects** - Clean tool execution
2. **API controllers** - RESTful endpoints
3. **Active Job** - Background processing
4. **Action Cable** - Real-time streaming
5. **Models** - Execution tracking
6. **Caching** - Performance optimization

Build apps with [Gantz](https://gantz.run), power them with Rails.

Convention meets intelligence.

## Related reading

- [Django MCP Integration](/post/django-mcp-integration/) - Python framework
- [MCP Caching](/post/mcp-caching/) - Cache strategies
- [Agent Task Queues](/post/agent-task-queues/) - Background jobs

---

*How do you build AI apps with Rails? Share your patterns.*
