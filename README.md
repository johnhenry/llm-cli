# llm-cli

> Your on-device LLM, everywhere you can type.

A simple, extensible command-line interface for accessing Apple's on-device Foundation Models on macOS 26 (Tahoe).

## Features

- 🔒 **100% Local & Private** - All processing happens on-device
- ⚡ **Fast Streaming** - Real-time token streaming for immediate feedback
- 🛠️ **Tool Calling** - Register custom functions the model can invoke
- 🔌 **MCP Support** - Connect to Model Context Protocol servers for extended capabilities
- 💬 **Interactive Chat** - Persistent conversation history
- 🌐 **HTTP API** - Serve model over localhost for integration
- 📝 **Templates** - Reusable prompt templates
- 🎯 **JSON Output** - Machine-readable responses
- 📂 **File & Stdin Input** - Read prompts from files or pipes
- 🔄 **Session Management** - List and monitor active processes
- 📋 **Model Discovery** - View available models and their capabilities
- 🚫 **Minimal Dependencies** - Pure Swift, only MCP SDK for protocol support

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd llm-cli

# Build the project
swift build -c release

# Create an alias (add to ~/.zshrc or ~/.bashrc)
alias llm="./.build/release/llm"

# Or install to PATH
cp ./.build/release/llm /usr/local/bin/
```

## Quick Start

### List Available Models

```bash
# See what models are available
llm ls
```

### Quick Chat

```bash
# Start chat with default model
llm run

# Start chat with specific model
llm run large
```

### Generate Text

```bash
# Simple generation
llm generate "Explain Swift concurrency in simple terms"

# From a file
llm generate -f prompt.txt

# From stdin (pipe)
echo "What is AI?" | llm generate
cat article.txt | llm generate --template summarize

# Multiline input
llm generate """
Line 1
Line 2
Line 3
"""

# Using a template
llm generate --template summarize "Long text to summarize..."

# JSON output
llm generate --json "Write a haiku about macOS"
```

### Interactive Chat

```bash
# Start chat mode
llm chat

# Chat with larger model
llm chat --model large

# Clear history
llm chat --clear
```

### Session Management

```bash
# View active sessions (chat, serve, and active generate tasks)
llm ps

# Stop a specific session by PID
llm stop 12345

# Stop all server processes
llm stop --servers

# Stop all llm sessions
llm stop --all
```

**Note:** Generate tasks appear in `llm ps` while they're running, but they're typically short-lived (completing in seconds). Chat and server sessions are long-running processes.

### HTTP API Server

```bash
# Start server (default port 8765)
llm serve

# Custom port
llm serve --port 9000

# Test with curl
curl -X POST http://127.0.0.1:8765 \
  -d "Explain quantum computing" \
  -H "Content-Type: text/plain"
```

### Tool Calling

```bash
# List available tools
llm tools --list

# Demonstrate tool usage
llm tools --demo
```

### Model Context Protocol (MCP)

Connect to MCP servers to extend the LLM with external tools and data sources.

```bash
# Add an MCP server (filesystem access example)
llm mcp add-server filesystem npx -y @modelcontextprotocol/server-filesystem /path/to/dir

# List configured servers
llm mcp list-servers

# List tools available from a server
llm mcp list-tools filesystem

# Test server connection
llm mcp test filesystem

# Call a tool directly
llm mcp call-tool filesystem read_file '{"path": "/etc/hosts"}'

# View configuration
llm mcp config
```

**Popular MCP Servers:**

```bash
# Filesystem access
llm mcp add-server fs npx -y @modelcontextprotocol/server-filesystem /path/to/dir

# GitHub integration
llm mcp add-server github npx -y @modelcontextprotocol/server-github

# SQLite database
llm mcp add-server db npx -y @modelcontextprotocol/server-sqlite path/to/db.sqlite

# Google Drive
llm mcp add-server gdrive npx -y @modelcontextprotocol/server-gdrive

# Brave Search
llm mcp add-server brave npx -y @modelcontextprotocol/server-brave-search
```

**Configuration:**
MCP servers are stored in `~/.config/llm-cli/mcp-servers.json`. You can edit this file directly or use the `llm mcp` commands.

### MCP Server Mode

Expose llm-cli's tools as an MCP server that external clients can connect to.

```bash
# Start the MCP server (communicates via stdio)
llm serve-mcp

# With verbose logging
llm serve-mcp --verbose

# Get help
llm serve-mcp --help
```

**Using llm-cli as an MCP server:**

Configure external MCP clients (like Claude Desktop) to connect:

```json
{
  "mcpServers": {
    "llm-cli": {
      "command": "llm",
      "args": ["serve-mcp"]
    }
  }
}
```

**Available Tools (17 total):**

The MCP server exposes 17 tools across 6 categories:

*File Operations (5):*
- `read_file` - Read file contents with line numbers
- `write_file` - Create or overwrite files
- `edit_file` - Replace strings in files
- `glob_files` - Find files matching glob patterns
- `grep_files` - Search file contents with regex

*Shell Operations (1):*
- `execute_bash` - Execute bash commands with sandboxing

*Git Operations (4):*
- `git_status` - Repository status
- `git_diff` - Show diffs (staged/unstaged)
- `git_log` - Commit history
- `git_commit` - Create commits

*Web Operations (2):*
- `web_search` - Search using DuckDuckGo
- `web_fetch` - Fetch web content

*LLM Operations (1):*
- `llm_generate` - Generate text with Foundation Models

*Project Operations (4):*
- `create_todo` - Create todo items
- `list_todos` - List todos with filtering
- `update_todo` - Update todo properties
- `delete_todo` - Delete todos

**Security:**

All tools are protected by a security sandbox configured in `~/.config/llm-cli/security.json`. This configuration controls:

- Allowed/denied file paths
- Allowed/denied shell commands
- Confirmation requirements for destructive operations
- File size limits
- Web request restrictions

Example security configuration:

```json
{
  "fileOperations": {
    "allowedPaths": ["$HOME/Documents", "$HOME/Projects", "$HOME/Desktop"],
    "deniedPaths": ["$HOME/.ssh", "$HOME/.aws", "/etc", "/var"],
    "requireConfirmation": ["write_file", "edit_file"],
    "maxFileSize": 10485760
  },
  "shellOperations": {
    "allowedCommands": ["git", "ls", "cat", "grep", "find"],
    "deniedCommands": ["rm", "sudo", "curl", "chmod"],
    "requireConfirmation": true,
    "timeout": 30
  },
  "webOperations": {
    "httpsOnly": true,
    "maxResponseSize": 1048576,
    "rateLimit": 10,
    "timeout": 30
  },
  "enabled": true
}
```

### Using llm-cli Tools in Chat

When you have MCP servers configured, you can use their tools directly in chat:

```bash
# Use filesystem tools in conversation
llm chat --mcp-server filesystem

# Use multiple MCP servers
llm chat --mcp-server filesystem --mcp-server github

# Generate with MCP tools
llm generate --mcp-server filesystem "Read and summarize my project README"
```

The LLM will automatically call available tools when needed to answer your questions.

## Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `run` | - | Quick start chat (optionally with model) |
| `generate` | `gen`, `g` | Generate text from a prompt |
| `chat` | `c` | Interactive conversation mode |
| `ls` | `list` | List available models |
| `ps` | - | Show active model sessions |
| `stop` | - | Stop running sessions |
| `tools` | `t` | Manage and demonstrate tools |
| `mcp` | - | Manage Model Context Protocol servers |
| `serve` | `s` | Start HTTP API server |
| `serve-mcp` | - | Start MCP server (expose llm-cli tools) |
| `templates` | - | Manage prompt templates |
| `history` | `hist` | View/clear conversation history |
| `status` | - | Check Foundation Models availability |
| `version` | `-v` | Show version information |
| `help` | `-h` | Show help message |

## Common Options

- `--model, -m <size>` - Model size: `small`, `medium`, `large`
- `--file, -f <path>` - Read prompt from file
- `--json` - Output in JSON format
- `--template, -t <name>` - Use a prompt template
- `--context, -c` - Include conversation history

## Advanced Input Methods

### File Input

Read prompts from files using the `-f` or `--file` flag:

```bash
# Create a prompt file
echo "Explain quantum computing" > prompt.txt

# Use it with generate
llm generate -f prompt.txt

# Works with templates too
llm generate -f article.txt --template summarize
```

### Stdin/Pipe Input

Pipe content directly from other commands:

```bash
# Pipe text
echo "What is Swift?" | llm generate

# Process file contents
cat README.md | llm generate --template summarize

# Chain with other tools
curl https://example.com/article.txt | llm generate "Summarize this:"

# Works with JSON output
echo "Hello world" | llm generate --json
```

### Multiline Input

Use triple quotes for multiline prompts:

```bash
llm generate """
Please analyze the following:
1. First point
2. Second point
3. Third point
"""
```

## Templates

Templates are stored in `Templates/` directory or can be managed via CLI commands.

### Template Management

```bash
# List all templates
llm templates --list
llm templates  # --list is default

# Create a new template (opens in $EDITOR or nano)
llm templates --add my-template

# View template content
llm templates --view summarize

# Edit existing template
llm templates --edit code-review

# Remove a template
llm templates --remove my-template

# Get help
llm templates --help
```

### Using Templates

```bash
# Use a template with generate
llm generate --template summarize "Long text to summarize..."

# Combine with file input
llm generate -f article.txt --template summarize

# Use with piped input
cat README.md | llm generate --template code-review
```

## Integration Examples

### Python

```python
import subprocess
import json

result = subprocess.run(
    ["llm", "generate", "--json", "Explain AI"],
    capture_output=True,
    text=True
)

data = json.loads(result.stdout)
print(data["text"])
```

### Node.js (using fetch)

```javascript
const response = await fetch("http://127.0.0.1:8765", {
  method: "POST",
  body: "Explain machine learning"
});

const data = await response.json();
console.log(data.text);
```

### Node.js (using CLI)

```javascript
import { execSync } from 'child_process';

const output = execSync('llm generate --json "Write a poem"', {
  encoding: 'utf-8'
});

const result = JSON.parse(output);
console.log(result.text);
```

## JSON Output Format

```json
{
  "tokens": ["Swift", " ", "is", " ", "a", " ", "language", "..."],
  "text": "Swift is a language...",
  "elapsed": 1.42
}
```

## Environment Variables

- `LLM_OUTPUT=json` - Enable JSON output mode globally
- `LLM_MODEL=<size>` - Set default model size (`small`, `medium`, `large`)
- `LLM_BACKEND=<backend>` - Select LLM backend (`foundationmodels` or `anthropic`)
- `ANTHROPIC_API_KEY=<key>` - API key for Anthropic backend (required when using `anthropic` backend)

**Examples:**
```bash
# Set default model to large
export LLM_MODEL=large
llm chat  # Uses large model

# Enable JSON output by default
export LLM_OUTPUT=json
llm generate "Hello"  # Returns JSON

# Use Anthropic backend with real Claude API
export LLM_BACKEND=anthropic
export ANTHROPIC_API_KEY=sk-ant-...
llm chat  # Uses Claude via Anthropic API

# Switch back to mock FoundationModels backend
export LLM_BACKEND=foundationmodels
llm chat  # Uses mock FoundationModels
```

## Backend Configuration

llm-cli supports swappable backends, allowing you to choose between different LLM providers:

### FoundationModels Backend (Default)

The default backend uses Apple's on-device FoundationModels framework. This is currently a **mock implementation** since the framework isn't available yet.

```bash
export LLM_BACKEND=foundationmodels
llm chat
```

**Features:**
- 100% local, on-device processing
- No API costs
- Privacy-focused
- Fast response times
- **Note:** Currently a mock - tools are registered but not yet functional

### Anthropic Backend

The Anthropic backend uses Claude via Anthropic's API with full tool calling support.

```bash
export LLM_BACKEND=anthropic
export ANTHROPIC_API_KEY=sk-ant-...
llm chat --mcp-server filesystem
```

**Features:**
- Real, working tool calling (calls tools automatically!)
- Uses Claude 3.5 Sonnet (medium/large) or Claude 3 Haiku (small)
- Full MCP tool integration
- Streaming responses
- Multi-turn conversations with tool use

**Model Mapping:**
- `small` → Claude 3 Haiku (`claude-3-haiku-20240307`)
- `medium` → Claude 3.5 Sonnet (`claude-3-5-sonnet-20241022`)
- `large` → Claude 3.5 Sonnet (`claude-3-5-sonnet-20241022`)

**Setup:**
1. Get an API key from https://console.anthropic.com/
2. Set environment variable: `export ANTHROPIC_API_KEY=sk-ant-...`
3. Select backend: `export LLM_BACKEND=anthropic`
4. Use llm-cli normally - tools will work automatically!

**Tool Calling Example:**
```bash
# Configure Anthropic backend
export LLM_BACKEND=anthropic
export ANTHROPIC_API_KEY=sk-ant-...

# Chat with MCP tools - Claude will automatically call them
llm chat --mcp-server filesystem

# You: "What files are in the current directory?"
# Assistant: [automatically calls glob_files tool and shows results]
```

## Model Sizes

| Size | Parameters | Memory | Performance |
|------|-----------|--------|-------------|
| `small` | ~1B | Low | Fast |
| `medium` | ~3B | Moderate | Balanced |
| `large` | ~8B | High | Best Quality |

**Note:** `large` model requires M-series Ultra chips.

## Privacy & Security

- ✅ 100% on-device processing
- ✅ No telemetry or tracking
- ✅ No network calls (unless using Private Cloud Compute)
- ✅ Localhost-only server by default
- ✅ No authentication required for local use

## Architecture

```
llm-cli/
├── Package.swift
├── Sources/llm/
│   ├── main.swift              # Command dispatcher
│   ├── Commands/
│   │   ├── Generate.swift      # Text generation
│   │   ├── Chat.swift          # Interactive chat
│   │   ├── Tools.swift         # Tool management
│   │   ├── MCP.swift           # MCP client management
│   │   ├── Serve.swift         # HTTP API server
│   │   └── ServeMCP.swift      # MCP server (expose tools)
│   ├── Backends/
│   │   ├── LLMBackend.swift    # Backend protocol & factory
│   │   ├── FoundationModelsBackend.swift  # Apple's FoundationModels (mock)
│   │   └── AnthropicBackend.swift         # Anthropic Claude API
│   ├── Models/
│   │   ├── LLM.swift           # LLM wrapper with backend abstraction
│   │   └── SampleTools.swift   # Built-in tool examples
│   ├── MCP/
│   │   ├── MCPConfig.swift     # MCP client configuration
│   │   ├── MCPClient.swift     # MCP client wrapper
│   │   ├── MCPToolAdapter.swift # Tool adapter
│   │   ├── MCPServer.swift     # MCP server infrastructure
│   │   └── ServerTools/
│   │       ├── FileOperationsTools.swift  # File I/O tools
│   │       ├── ShellTools.swift           # Bash execution
│   │       ├── GitTools.swift             # Git operations
│   │       ├── WebTools.swift             # Web search/fetch
│   │       ├── LLMTools.swift             # LLM generation
│   │       └── ProjectTools.swift         # Todo management
│   ├── Security/
│   │   ├── SecurityConfig.swift # Security configuration
│   │   └── Sandbox.swift        # Path/command validation
│   └── Util/
│       ├── Output.swift        # Output formatting
│       ├── HistoryStore.swift  # Conversation persistence
│       └── PromptTemplates.swift
└── Templates/
    ├── summarize.txt
    └── code-review.txt
```

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon (M1/M2/M3/M4)
- Swift 6.0 or later

## Current Implementation Note

llm-cli features a **backend abstraction layer** that allows swapping between different LLM providers:

**FoundationModels Backend (Default):**
This is a **mock implementation** demonstrating the architecture and API design for Apple's FoundationModels framework, which is planned for macOS 26. The actual `FoundationModels` framework is not yet available as of October 2025. Tools are registered but not functional in this backend.

**Anthropic Backend:**
This is a **real, working implementation** that uses Claude via Anthropic's API. It features full tool calling support, allowing the LLM to automatically call MCP tools to answer questions.

The implementation demonstrates:
- Complete CLI structure and command handling
- Backend abstraction with swappable implementations
- Async streaming patterns
- HTTP server architecture
- Tool calling interfaces (fully functional with Anthropic backend)
- Output formatting (human + JSON)
- MCP integration with 17 built-in tools

When Apple releases the FoundationModels framework, the mock backend can be updated to use actual API calls while keeping the same interface.

## Future Roadmap

- [ ] `llm tune` - Fine-tuning API (v1.1)
- [ ] `llm eval` - Dataset benchmarking (v1.1)
- [ ] WebSocket support (v1.2)
- [ ] Apple Shortcuts integration (v1.2)
- [ ] JSON Schema validation (v1.3)
- [ ] Plugin system (v1.4)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - See LICENSE file for details

## Author

john@iamjohnhenry.com

---

**Tagline:** *"Your on-device LLM, everywhere you can type."*
