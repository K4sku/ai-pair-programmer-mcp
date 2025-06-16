#!/usr/bin/env ruby
# frozen_string_literal: true

# Inline bundler setup - automatically installs gems if missing
begin
  require 'fast_mcp'
  require 'ruby_llm'
  require 'json'
  require 'logger'
  require 'fileutils'
rescue LoadError => e
  missing_gem = e.message.match(/cannot load such file -- (.+)/)[1]
  puts "Installing missing gem: #{missing_gem}"
  
  case missing_gem
  when 'fast_mcp'
    system('gem install fast-mcp') || exit(1)
  when 'ruby_llm'
    system('gem install ruby_llm') || exit(1)
  else
    puts "Unknown gem: #{missing_gem}"
    exit(1)
  end
  
  retry
end

# Set up logging as global variable
log_dir = File.expand_path('~/.claude-mcp-servers/ai-pair-programmer-mcp')
FileUtils.mkdir_p(log_dir)
log_file = File.join(log_dir, 'server.log')

$logger = Logger.new(log_file)
$logger.level = ENV['DEBUG'] == '1' ? Logger::DEBUG : Logger::INFO
$logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} - #{severity} - #{msg}\n"
end

MODELS_CONFIG = {
  default_model: "Gemini",
  api_key_env: "OPENROUTER_API_KEY",
  models: {
    "O3" => {
      model_id: "openai/o3",
      temperature: 0.3,
    },
    "Gemini" => {
      model_id: "google/gemini-2.5-pro-preview",
      temperature: 0.3,
    },
    "Grok" => {
      model_id: "x-ai/grok-3-beta",
      temperature: 0.3,
    },
    "DeepSeek" => {
      model_id: "deepseek/deepseek-r1-0528",
      temperature: 0.3,
    },
    "Opus" => {
      model_id: "anthropic/claude-opus-4",
      temperature: 0.3,
    }
  }
}.freeze

# Initialize configuration
api_key = ENV['OPENROUTER_API_KEY']
unless api_key
  $logger.error("API key not found in environment variable: OPENROUTER_API_KEY")
  exit 1
end
$logger.info("API key loaded from environment variable: OPENROUTER_API_KEY")

# Configure RubyLLM
RubyLLM.configure do |llm_config|
  llm_config.openrouter_api_key = api_key
  llm_config.default_model = MODELS_CONFIG[:models][MODELS_CONFIG[:default_model]][:model_id]
  llm_config.log_file = File.join(log_dir, 'ruby_llm.log')
  llm_config.log_level = :debug
end

$logger.info("AI Pair Programmer MCP Server initialized with RubyLLM")

# Create MCP server
server = FastMcp::Server.new(
  name: 'ai-pair-programmer',
  version: '1.0.0'
)

# Helper method to validate model and get model info
def validate_model(model_name)
  # Convert model_name to symbol for lookup since config keys are symbols
  model_key = model_name
  unless MODELS_CONFIG[:models].key?(model_key)
    available = MODELS_CONFIG[:models].keys.map(&:to_s).join(', ')
    error_msg = "Model '#{model_name}' not available. Available models: #{available}"
    $logger.error(error_msg)
    return { error: error_msg }
  end
  
  MODELS_CONFIG[:models][model_key]
end

# Helper method to call RubyLLM with proper error handling
def call_ruby_llm(prompt, model_name, temperature: 0.3)
  model_info = validate_model(model_name)
  return model_info if model_info.is_a?(Hash) && model_info[:error]

  model_id = model_info[:model_id]
  $logger.debug("RubyLLM request - Model: #{model_name} (#{model_id}), Temperature: #{temperature}")

  begin
    # Create a chat instance with the specific model
    chat = RubyLLM.chat(model: model_id, provider: :openrouter)
    chat = chat.with_temperature(temperature)
    
    response = chat.ask(prompt)
    
    $logger.debug("RubyLLM response received - Length: #{response.content.length}")
    response.content
  rescue => e
    error_msg = "RubyLLM API error: #{e.message}"
    $logger.error(error_msg)
    { error: error_msg }
  end
end

# Tool: Pair Programming / General Collaboration
class PairTool < FastMcp::Tool
  tool_name 'pair'
  description "Collaborate with AI on any topic - ask questions, brainstorm ideas, or work through problems together"
  
  arguments do
    required(:prompt).filled(:string).description("Your question or topic to discuss")
    optional(:model).filled(:string).description("Model to use: O3, Gemini, Grok, DeepSeek, Opus")
    optional(:temperature).filled(:float).description("Response creativity (0.0-1.0)")
  end

  def call(prompt:, model: 'Gemini', temperature: 0.5)
    $logger.info("Tool called: pair with model: #{model}")
    
    result = call_ruby_llm(prompt, model, temperature: temperature)
    return result if result.is_a?(Hash) && result[:error]
    
    $logger.info("Tool pair completed successfully using model #{model}")
    result
  end
end

# Tool: Code Review
class ReviewTool < FastMcp::Tool
  tool_name 'review'
  description "Get comprehensive code review with actionable feedback"
  
  arguments do
    required(:code).filled(:string).description("Code to review")
    optional(:context).filled(:string).description("Additional context about the code")
    optional(:model).filled(:string).description("Model to use: O3, Gemini, Grok, DeepSeek, Opus")
  end

  def call(code:, context: '', model: 'Gemini')   
    $logger.info("Tool called: review with model: #{model}")
    
    prompt = build_review_prompt(code, context)
    result = call_ruby_llm(prompt, model, temperature: 0.3)
    return result if result.is_a?(Hash) && result[:error]
    
    $logger.info("Tool review completed successfully using model #{model}")
    result
  end

  private

  def build_review_prompt(code, context)
    <<~PROMPT
      Please provide a comprehensive code review for the following code.

      Context: #{context.empty? ? 'No additional context provided' : context}

      Code to review:
      ```
      #{code}
      ```

      Please analyze:
      1. Code quality and readability
      2. Potential bugs or issues
      3. Performance considerations
      4. Security concerns
      5. Best practices and improvements
      6. Overall architecture and design

      Provide specific, actionable feedback with examples where appropriate.
    PROMPT
  end
end

# Tool: Brainstorming
class BrainstormTool < FastMcp::Tool
  tool_name 'brainstorm'
  description "Brainstorm creative solutions and explore ideas"
  
  arguments do
    required(:topic).filled(:string).description("Topic to brainstorm about")
    optional(:constraints).filled(:string).description("Any constraints or requirements")
    optional(:model).filled(:string).description("Model to use: O3, Gemini, Grok, DeepSeek, Opus")
  end

  def call(topic:, constraints: '', model: 'Gemini')    
    $logger.info("Tool called: brainstorm with model: #{model}")
    
    prompt = build_brainstorm_prompt(topic, constraints)
    result = call_ruby_llm(prompt, model, temperature: 0.7)
    return result if result.is_a?(Hash) && result[:error]
    
    $logger.info("Tool brainstorm completed successfully using model #{model}")
    result
  end

  private

  def build_brainstorm_prompt(topic, constraints)
    <<~PROMPT
      Let's brainstorm creative ideas and solutions for: #{topic}

      #{constraints.empty? ? '' : "Constraints/Requirements: #{constraints}"}

      Please provide:
      1. Multiple creative approaches or solutions
      2. Pros and cons of each approach
      3. Unconventional or innovative ideas
      4. Practical implementation considerations
      5. Potential challenges and how to address them

      Be creative and think outside the box!
    PROMPT
  end
end

# Tool: Performance Review
class ReviewPerformanceTool < FastMcp::Tool
  tool_name 'review_performance'
  description "Analyze code for performance issues and optimization opportunities"
  
  arguments do
    required(:code).filled(:string).description("Code to analyze for performance")
    optional(:context).filled(:string).description("Context about expected usage patterns")
    optional(:model).filled(:string).description("Model to use: O3, Gemini, Grok, DeepSeek, Opus")
  end

  def call(code:, context: '', model: 'Gemini')    
    $logger.info("Tool called: review_performance with model: #{model}")
    
    prompt = build_performance_prompt(code, context)
    result = call_ruby_llm(prompt, model, temperature: 0.3)
    return result if result.is_a?(Hash) && result[:error]
    
    $logger.info("Tool review_performance completed successfully using model #{model}")
    result
  end

  private

  def build_performance_prompt(code, context)
    <<~PROMPT
      Please analyze the following code for performance issues and optimization opportunities.

      Usage context: #{context.empty? ? 'General purpose usage' : context}

      Code to analyze:
      ```
      #{code}
      ```

      Please identify:
      1. Performance bottlenecks
      2. Time complexity analysis
      3. Space complexity concerns
      4. Optimization opportunities
      5. Caching strategies
      6. Algorithm improvements
      7. Resource usage concerns

      Provide specific recommendations with code examples where applicable.
    PROMPT
  end
end

# Tool: Security Review
class ReviewSecurityTool < FastMcp::Tool
  tool_name 'review_security'
  description "Security-focused code review to identify vulnerabilities"
  
  arguments do
    required(:code).filled(:string).description("Code to analyze for security issues")
    optional(:context).filled(:string).description("Security context or requirements")
    optional(:model).filled(:string).description("Model to use: O3, Gemini, Grok, DeepSeek, Opus")
  end

  def call(code:, context: '', model: 'Gemini')    
    $logger.info("Tool called: review_security with model: #{model}")
    
    prompt = build_security_prompt(code, context)
    result = call_ruby_llm(prompt, model, temperature: 0.2)
    return result if result.is_a?(Hash) && result[:error]
    
    $logger.info("Tool review_security completed successfully using model #{model}")
    result
  end

  private

  def build_security_prompt(code, context)
    <<~PROMPT
      Please perform a security-focused review of the following code.

      Security context: #{context.empty? ? 'Standard security requirements' : context}

      Code to analyze:
      ```
      #{code}
      ```

      Please identify:
      1. Security vulnerabilities (injection, XSS, etc.)
      2. Authentication/authorization issues
      3. Data validation concerns
      4. Cryptographic weaknesses
      5. Information disclosure risks
      6. OWASP Top 10 considerations
      7. Security best practices violations

      Provide specific vulnerabilities with severity levels and remediation recommendations.
    PROMPT
  end
end

# Register all tools with the server
server.register_tools(
  PairTool,
  ReviewTool,
  BrainstormTool,
  ReviewPerformanceTool,
  ReviewSecurityTool
)

# Start the server
begin
  $logger.info("Starting AI Assistant MCP Server...")
  available_models = MODELS_CONFIG[:models].keys.map(&:to_s).join(', ')
  $logger.info("Available models: #{available_models}")
  $logger.info("Default model: #{MODELS_CONFIG[:default_model]}")
  
  server.start
rescue Interrupt
  $logger.info("Server stopped by user")
rescue => e
  $logger.error("Fatal error: #{e.message}")
  $logger.error(e.backtrace.join("\n"))
  exit(1)
end