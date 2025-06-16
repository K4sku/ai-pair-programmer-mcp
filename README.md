# AI Pair Programmer MCP Server (Ruby)

A Ruby implementation of an AI Pair Programmer MCP (Model Context Protocol) server that provides AI-powered tools for code review, brainstorming, performance analysis, and security review.

## Features

This server provides 5 AI-powered tools:

1. **pair** - General collaboration and problem-solving
2. **review** - Comprehensive code review with actionable feedback  
3. **brainstorm** - Creative ideation and solution exploration
4. **review_performance** - Performance analysis and optimization suggestions
5. **review_security** - Security-focused code review and vulnerability detection

## Installation & Setup

### Prerequisites

- Ruby 3.0+ 
- An OpenRouter API key

### Automatic Installation

The server uses inline bundler for automatic gem installation. Required gems:
- `fast-mcp` - Ruby MCP server framework
- `ruby_llm` - Unified AI model interface

### Configuration

1. Set your OpenRouter API key:
```bash
export OPENROUTER_API_KEY="your_api_key_here"
```

### Running the Server

```bash
ruby ./server.rb
```

The server will:
- Automatically install missing gems on first run
- Start with STDIO transport for MCP clients
- Log to `~/.claude-mcp-servers/ai-pair-programmer-mcp/`

###

If the MCP fails to start when lunching Claude Code it's probably due to timeout.
The bundler is installing dependecies. To fix that either set an envvar `MCP_TIMEOUT=10000` (10s) or start the MCP server in the terminal first.

## Configuration

### Models

The server supports these AI models via OpenRouter:

- **Gemini** (default) - `google/gemini-2.5-pro-preview`
- **O3** - `openai/o3` 
- **Grok** - `x-ai/grok-3-beta`
- **DeepSeek** - `deepseek/deepseek-r1-0528`
- **Opus** - `anthropic/claude-opus-4`

## MCP Client Configuration

### Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "AiPairProgrammer": {
      "command": "ruby",
      "args": ["/path/to/server.rb"]
    }
  }
}
```

## Usage Examples

Once connected to an MCP client:

### Code Review
```
Please review this Ruby code for best practices and potential issues:

def process_data(items)
  items.map { |item| item.upcase }
end
```

### Performance Analysis  
```
Can you analyze this code for performance bottlenecks?

def find_duplicates(array)
  duplicates = []
  array.each do |item|
    if array.count(item) > 1 && !duplicates.include?(item)
      duplicates << item
    end
  end
  duplicates
end
```

### Security Review
```
Please check this authentication code for security vulnerabilities:

def authenticate(username, password)
  user = User.find_by(username: username)
  if user && user.password == password
    session[:user_id] = user.id
    true
  else
    false
  end
end
```

### Brainstorming
```
I need ideas for improving user onboarding in my Ruby on Rails app. The current flow has a 60% drop-off rate.
```

### General Collaboration  
```
I'm struggling with this algorithm problem. Can you help me think through it step by step?
```

## Development

### Debugging

Enable debug logging:

```bash
DEBUG=1 ./server.rb
```

This will log detailed information about:
- Tool calls and arguments
- API requests and responses  
- Error details

### Log Files

Logs are written to:
```
~/.claude-mcp-servers/ai-pair-programmer-mcp/server.log
~/.claude-mcp-servers/ai-pair-programmer-mcp/ruby_llm.log
```

## Architecture

The server is built with:

- **FastMcp** - Ruby MCP server framework with STDIO transport
- **RubyLLM** - Unified interface to AI models via OpenRouter
- **Inline Bundler** - Automatic gem installation for easy deployment

## License

MIT License

## Prior work:

AI Assistant MCP Server by Eduard
https://github.com/eduardm/ai_pairs_with_ai

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `ruby test_server.rb`
5. Submit a pull request