🧭 Product Requirements Document

Project Name: llm-cli
Version: 1.0 (macOS 26 / Tahoe)
Author: john@iamjohnhenry.com
Date: October 2025

⸻

🎯 Purpose & Vision

The goal of llm-cli is to provide a simple, extensible command-line interface for accessing Apple’s on-device Foundation Models introduced in macOS 26.

It enables:
	•	Local, private interaction with Apple’s LLMs
	•	Streaming, structured text generation
	•	Integration with Python, Node.js, or HTTP clients
	•	Git-style modular subcommands (generate, chat, serve, tools, etc.)
	•	A foundation for local AI workflows, automations, and developer experiments — no network, no API keys

Ultimately, this CLI acts as the local, scriptable bridge between Apple Intelligence and your terminal, scripts, or external services.

⸻

🧩 Functional Overview

Command	Status	Purpose
llm generate	✅ IMPLEMENTED	Stream or output a single completion for a prompt
llm chat	✅ IMPLEMENTED	Interactive conversation with memory
llm tools	✅ IMPLEMENTED	Register and call app-provided functions/tools
llm serve	✅ IMPLEMENTED	Expose an HTTP/WebSocket server for remote API access
llm templates	✅ IMPLEMENTED	Manage prompt templates (CRUD operations)
llm history	✅ IMPLEMENTED	View or reset conversation history
llm mcp	✅ IMPLEMENTED	Manage Model Context Protocol servers
llm serve-mcp	🚧 IN PROGRESS	Expose llm-cli as MCP server
llm ls	✅ IMPLEMENTED	List available models
llm ps	✅ IMPLEMENTED	Show active sessions
llm stop	✅ IMPLEMENTED	Stop running sessions
llm run	✅ IMPLEMENTED	Quick start chat (shortcut)
llm eval	📋 PLANNED	Benchmark prompts/datasets (v1.1)
llm tune	📋 PLANNED	Fine-tune or specialize on local data (v1.1)


⸻

🔌 Model Context Protocol (MCP) Integration

llm-cli is both an MCP **client** and **server**, enabling bidirectional tool integration.

MCP Client Features (✅ IMPLEMENTED)
	•	Connect to external MCP servers for extended capabilities
	•	Register MCP tools as FoundationModels Tools (LLM can invoke them)
	•	Configuration stored in ~/.config/llm-cli/mcp-servers.json
	•	Commands:
		○	llm mcp add-server <name> <command> [args...]
		○	llm mcp list-servers / ls
		○	llm mcp list-tools <server>
		○	llm mcp call-tool <server> <tool> [json]
		○	llm mcp test <server>
		○	llm mcp config
		○	llm mcp remove-server <name>

MCP Server Features (🚧 IN PROGRESS)
	•	Expose llm-cli capabilities as MCP tools for other clients
	•	Other MCP clients (Claude Desktop, Claude Code, etc.) can use llm-cli
	•	Tools exposed via MCP:
		○	File Operations: read_file, write_file, edit_file, glob_files, grep_files
		○	Shell Operations: execute_bash (sandboxed)
		○	Git Operations: git_status, git_diff, git_log, git_commit
		○	Web Operations: web_search, web_fetch
		○	LLM Operations: llm_generate, llm_chat (expose Foundation Models!)
		○	Project Management: create_todo, list_todos, update_todo
	•	Security: Sandboxed execution with allowlists and confirmations
	•	Command: llm serve-mcp [--stdio | --port <n>]

Tool Integration Priority (for Chat/Generate)
	1	🎯 File Operations (read, write, edit, glob, grep)
	2	🎯 Shell Execution (bash commands, git operations)
	3	🎯 Web Tools (search, fetch for research)
	4	🎯 Project Management (todo lists, task tracking)
	5	⏸️ Voice Tools (deferred - available via external MCP)

Security Model
	•	**Sandbox Mode**: File operations restricted to allowed directories
	•	**Confirmation Prompts**: Destructive operations require user approval
	•	**Allowlists**: Configurable allowed commands/paths
	•	**Size Limits**: Tool results truncated to prevent context overflow
	•	**Timeouts**: Long-running operations cancelled automatically
	•	Config: ~/.config/llm-cli/security.json

Usage Examples

# MCP Client: Connect to filesystem server
llm mcp add-server fs npx -y @modelcontextprotocol/server-filesystem ~/Documents

# Use MCP tools during chat
llm chat --mcp-server fs
> Can you read my resume and suggest improvements?
[LLM uses fs.read_file tool automatically]

# MCP Server: Expose llm-cli to other clients
llm serve-mcp --stdio
# Other MCP clients can now use llm-cli's tools

⸻

🧠 Core Capabilities

1. On-Device Model Access
	•	Uses FoundationModels framework (FMModel) to load:
	•	foundation-small (~1B)
	•	foundation-medium (~3B)
	•	foundation-large (~8B, M-series Ultra)
	•	Fully local execution — no network required unless explicitly opting into “Private Cloud Compute”.

2. Text Generation
	•	generateText(from:) for complete responses.
	•	streamText(from:) for token streaming.
	•	Returns results either as:
	•	Human-readable console stream
	•	JSON payload for machine consumption (--json or LLM_OUTPUT=json).

3. Tool Calling
	•	Developers can register “tools” (FMTool) that can be called by the model for contextual actions.
	•	CLI command llm tools demonstrates built-in examples.

4. Context Memory
	•	Conversation history persisted in ~/.local/share/llm/history.json.
	•	Supports resuming context in chat mode or via --context flag.

5. Prompt Templates
	•	Templates stored under /usr/local/share/llm-cli/templates/.
	•	Accessible by name (e.g. llm generate --template summarize).

6. Structured Output

{
  "tokens": ["Swift", " ", "is", " ", "a", " ", "language", ...],
  "text": "Swift is a language...",
  "elapsed": 1.42
}

7. Multi-Language Integration
	•	Python and Node.js wrappers provided using subprocess (llm --json ...).
	•	Serve mode provides native HTTP and WebSocket interface.

⸻

🧱 Architecture

🗂 Directory Layout

llm-cli/
├── Package.swift
├── Sources/
│   └── llm/
│       ├── main.swift                      # Command dispatcher
│       ├── Commands/
│       │   ├── Generate.swift              # Text generation
│       │   ├── Chat.swift                  # Interactive chat
│       │   ├── Tools.swift                 # Built-in tools demo
│       │   ├── MCP.swift                   # MCP client commands
│       │   └── Serve.swift                 # HTTP server
│       ├── Models/
│       │   ├── LLM.swift                   # FoundationModels wrapper
│       │   └── SampleTools.swift           # Example tools
│       ├── MCP/
│       │   ├── MCPConfig.swift             # Server configuration (✅)
│       │   ├── MCPClient.swift             # Client wrapper (✅)
│       │   ├── MCPToolAdapter.swift        # Tool adapter (✅)
│       │   ├── MCPServer.swift             # Server implementation (🚧)
│       │   └── ServerTools/                # MCP server tools (🚧)
│       │       ├── FileOperationsTools.swift
│       │       ├── ShellTools.swift
│       │       ├── GitTools.swift
│       │       ├── WebTools.swift
│       │       ├── LLMTools.swift
│       │       └── ProjectTools.swift
│       ├── Security/                       # Sandboxing (🚧)
│       │   ├── Sandbox.swift               # Path/command restrictions
│       │   └── SecurityConfig.swift        # Security settings
│       └── Util/
│           ├── Output.swift                # Output formatting
│           ├── HistoryStore.swift          # Conversation persistence
│           └── PromptTemplates.swift       # Template management
├── Templates/
│   ├── summarize.txt
│   └── code-review.txt
└── Config/
    ├── mcp-servers.json                    # MCP client config
    └── security.json                       # Security settings


⸻

🔧 MCP Implementation Specifications

Phase 1: Enhanced MCP Client (Priority 1)

Chat/Generate Integration
	•	Add --mcp-server flag to chat and generate commands
	•	Load MCP tools on startup and register with LLM instance
	•	LLM can invoke tools during generation
	•	Tool results injected back into conversation context

# Example usage
llm chat --mcp-server filesystem --mcp-server github
> Can you read my README and create a GitHub issue for the bug I mentioned?
[LLM automatically uses filesystem.read_file and github.create_issue tools]

Multiple Server Support
	•	Load tools from multiple MCP servers simultaneously
	•	Namespace tools by server (e.g., fs.read_file vs db.query)
	•	Conflict resolution for duplicate tool names

Phase 2: MCP Server Implementation (Priority 2)

Server Architecture
	•	MCP Server class implementing stdio transport
	•	Tool registry with capability discovery
	•	Request/response handling with streaming support
	•	Error handling and graceful degradation

Tool Categories & Specifications

1. File Operations (FileOperationsTools.swift)
	•	read_file(path: String, offset?: Int, limit?: Int) -> String
		○	Reads file contents with optional line range
		○	Returns: File content with line numbers
		○	Security: Path must be in allowlist
	•	write_file(path: String, content: String) -> String
		○	Creates or overwrites file
		○	Returns: Success message with file path
		○	Security: Requires confirmation, path allowlist
	•	edit_file(path: String, old: String, new: String) -> String
		○	String replacement in file
		○	Returns: Success message with changes made
		○	Security: Confirmation prompt, diff preview
	•	glob_files(pattern: String, path?: String) -> [String]
		○	Find files matching glob pattern
		○	Returns: Array of matching file paths
		○	Security: Path restrictions apply
	•	grep_files(pattern: String, path?: String, options?: Object) -> String
		○	Search file contents with regex
		○	Returns: Matching lines with context
		○	Security: Path restrictions apply

2. Shell Operations (ShellTools.swift)
	•	execute_bash(command: String, timeout?: Int) -> String
		○	Execute shell command with timeout
		○	Returns: stdout + stderr
		○	Security: Command allowlist, confirmation required
	•	Environment: Sanitized, no sensitive vars

3. Git Operations (GitTools.swift)
	•	git_status() -> String
	•	git_diff(path?: String) -> String
	•	git_log(limit?: Int) -> String
	•	git_commit(message: String, files?: [String]) -> String
		○	All operations use git CLI
		○	Security: Read operations safe, write require confirmation

4. Web Operations (WebTools.swift)
	•	web_search(query: String, num_results?: Int) -> String
		○	Search using DuckDuckGo or similar
		○	Returns: Titles, snippets, URLs
		○	Rate limiting: Max 10/minute
	•	web_fetch(url: String) -> String
		○	Fetch and parse webpage
		○	Returns: Markdown-converted content
		○	Security: HTTPS only, size limits

5. LLM Operations (LLMTools.swift)
	•	llm_generate(prompt: String, model?: String) -> String
		○	Generate text using Foundation Models
		○	Returns: Generated text
		○	This exposes llm-cli's LLM to other MCP clients!
	•	llm_chat(message: String, model?: String) -> String
		○	Chat with conversation history
		○	Returns: Response text

6. Project Management (ProjectTools.swift)
	•	create_todo(description: String, priority?: String) -> String
	•	list_todos(filter?: String) -> String
	•	update_todo(id: String, status: String) -> String
	•	delete_todo(id: String) -> String
		○	Stored in ~/.local/share/llm/todos.json

Phase 3: Security & Sandboxing (Priority 3)

Security Configuration (~/.config/llm-cli/security.json)

{
  "file_operations": {
    "allowed_paths": [
      "$HOME/Documents",
      "$HOME/Projects"
    ],
    "denied_paths": [
      "$HOME/.ssh",
      "$HOME/.aws"
    ],
    "require_confirmation": ["write_file", "edit_file"],
    "max_file_size": 10485760  // 10MB
  },
  "shell_operations": {
    "allowed_commands": ["git", "ls", "cat", "grep"],
    "denied_commands": ["rm", "sudo", "curl"],
    "require_confirmation": true,
    "timeout": 30
  },
  "web_operations": {
    "https_only": true,
    "max_response_size": 1048576,  // 1MB
    "rate_limit": 10  // requests per minute
  }
}

Confirmation Prompts
	•	Interactive CLI prompts for destructive operations
	•	Show preview of changes before execution
	•	Allow --yes flag to skip prompts (dangerous!)

Path Validation
	•	Resolve symlinks and relative paths
	•	Check against allowlist/denylist
	•	Prevent directory traversal attacks

Command Filtering
	•	Allowlist approach for shell commands
	•	Block dangerous patterns (sudo, rm -rf, etc.)
	•	Argument sanitization

Result Truncation
	•	Limit tool results to prevent context overflow
	•	Default: 10,000 characters
	•	Configurable per tool type
	•	Smart truncation (beginning + end)

⸻

⚙️ Technical Design

1. LLM Wrapper

Encapsulates FMModel, handles loading, streaming, tool registration, and JSON output.

2. Commands
	•	Each subcommand is an independent async struct with a .run() entry.
	•	main.swift dispatches based on first argument (generate, chat, serve, etc.).

3. Output System
	•	OutputMode detects --json flag or LLM_OUTPUT=json.
	•	JSON encoding handled via Codable.

4. Persistence
	•	Simple JSON file for conversation history.
	•	Templates are text files; easy to modify or share.

5. Serve Command

llm serve exposes a minimal local API:
	•	HTTP on localhost:8765
	•	WebSocket at /ws
	•	JSON protocol compatible with the CLI schema.

Example Serve.swift

import Foundation
import Network
import FoundationModels

struct ServeCommand {
    static func run() async {
        let port: UInt16 = 8765
        print("🧠 Serving LLM API at http://127.0.0.1:\(port)")
        
        let listener = try! NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { conn in
            conn.start(queue: .global())
            Task {
                do {
                    let data = try await conn.receive(minimumIncompleteLength: 1, maximumLength: 4096)
                    guard let request = String(data: data.0 ?? Data(), encoding: .utf8) else { return }
                    let llm = try LLM(size: .medium)
                    let response = try await llm.streamJSON(from: request)
                    let json = try JSONEncoder().encode(response)
                    conn.send(content: json, completion: .contentProcessed { _ in conn.cancel() })
                } catch { conn.cancel() }
            }
        }
        listener.start(queue: .global())
        dispatchMain()
    }
}

✅ Fully local
✅ Zero dependencies
✅ Compatible with curl, fetch, requests, or WebSocket libraries

⸻

🌐 API Examples

HTTP POST

curl -X POST http://127.0.0.1:8765 \
  -d 'Explain the benefits of Swift Concurrency' \
  -H "Content-Type: text/plain"

Python

import requests
resp = requests.post("http://127.0.0.1:8765", data="Explain quantum tunneling")
print(resp.json()["text"])

Node.js

const r = await fetch("http://127.0.0.1:8765", {
  method: "POST",
  body: "Explain quantum tunneling"
});
const data = await r.json();
console.log(data.text);


⸻

🔐 Privacy & Security
	•	100% on-device by default (Apple Foundation Models run locally)
	•	No telemetry or remote calls
	•	Optional Private Cloud Compute integration via system settings
	•	Serve mode binds to localhost only by default
	•	No authentication required for local usage; can add token file for network usage later

⸻

🧩 Non-Functional Requirements

Requirement	Detail
Performance	Initial token latency < 300 ms (M3 Max, local model)
	Tool call overhead < 100ms per invocation
Reliability	Graceful error handling, no panics
	Tool failures don't crash CLI
	MCP server disconnections handled gracefully
Portability	macOS 26 +, Apple Silicon
Maintainability	Modular, one command per file
	MCP tools isolated in separate modules
Extensibility	Easy to add new commands and tools
	Plugin architecture for custom tools (future)
Offline-first	All functionality available offline
	MCP servers optional, degrades gracefully
Security	Sandboxed file operations (allowlist/denylist)
	Command execution filtering
	Confirmation prompts for destructive operations
	No arbitrary code execution
Privacy	100% local by default
	MCP servers run locally (no remote connections)
	No telemetry or analytics
Scalability	Handle multiple MCP servers simultaneously
	Tool result caching for performance
	Background task management


⸻

🚀 Example End-to-End Usage

# 1. Install
swift build -c release
alias llm="./.build/release/llm"

# 2. Generate
llm generate "Summarize macOS 26 features"

# 3. Chat interactively
llm chat

# 4. Serve as local API
llm serve &
curl -X POST http://127.0.0.1:8765 -d "Write a Swift haiku"

# 5. Use from Python
python llm_client.py "Write a limerick about Objective-C"


⸻

🧩 Development Roadmap

Current Version: v1.0 (✅ RELEASED)
	✅	Core text generation (generate, chat)
	✅	HTTP API server
	✅	Tool calling framework
	✅	Template management (CRUD)
	✅	Session management (ps, stop, run)
	✅	MCP client (connect to external servers)

In Progress: v1.1 (🚧 ACTIVE)
	🚧	MCP Server implementation
		○	File operations tools
		○	Shell execution tools
		○	Git operations tools
		○	Web tools (search, fetch)
		○	LLM tools (expose Foundation Models)
		○	Project management tools
	🚧	Chat/Generate MCP integration
		○	--mcp-server flag for tool loading
		○	Automatic tool registration
		○	Tool result handling
	🚧	Security & Sandboxing
		○	Path allowlists/denylists
		○	Command filtering
		○	Size limits & timeouts
		○	Confirmation prompts

Planned: v1.2 (📋 NEXT)
	📋	Enhanced MCP Features
		○	Multiple simultaneous MCP servers
		○	MCP resource support (not just tools)
		○	MCP prompt templates
	📋	Background Process Management
		○	--background flag for long operations
		○	llm logs <task-id> command
		○	Process status tracking
	📋	Full WebSocket Support
		○	Streaming API via WebSocket
		○	Bidirectional communication

Future: v1.3+ (🔮 LATER)
	🔮	llm tune - Fine-tuning API
	🔮	llm eval - Dataset benchmarking
	🔮	Apple Shortcuts Integration
	🔮	JSON Schema validation for tools
	🔮	Plugin system (.swiftplugin bundles)
	🔮	Multi-agent orchestration


⸻

🧩 Developer Experience Goals
	•	Familiar command syntax (like git or brew)
	•	Human + JSON dual-mode output
	•	Works offline
	•	Streamed responses for immediacy
	•	Built on official Apple APIs — future-proof, no reverse-engineering
	•	Minimal dependencies (pure Swift)

⸻

🧾 Summary

Property	Value
Name	llm-cli
Type	Local AI Command-Line Interface
Primary API	Apple Foundation Models (macOS 26)
Interfaces	CLI, JSON, HTTP, MCP (Client & Server), Python, Node
License	MIT (proposed)
Goal	Local, scriptable, privacy-preserving AI access with extensible tool integration
Tagline	"Your on-device LLM, everywhere you can type."

⸻

🧪 Testing Strategy

Unit Tests
	✅	MCP client connection/disconnection
	✅	Tool registration and invocation
	🚧	Security sandbox path validation
	🚧	Security command filtering
	🚧	Tool result truncation
	🚧	Each MCP server tool independently

Integration Tests
	🚧	Chat with MCP tools end-to-end
	🚧	Multiple MCP servers simultaneously
	🚧	MCP server with external clients
	🚧	Security prompts and confirmations
	🚧	Error handling and recovery

Security Tests
	🚧	Directory traversal attempts
	🚧	Command injection attempts
	🚧	Symlink attacks
	🚧	Path normalization edge cases
	🚧	Oversized result handling

Performance Tests
	🚧	Tool invocation latency
	🚧	Multiple concurrent tool calls
	🚧	Large file operations
	🚧	Context window with tool results

Compatibility Tests
	🚧	Connect to official MCP servers (filesystem, github, sqlite)
	🚧	Expose to Claude Desktop/Code
	🚧	Cross-tool interactions

Test Coverage Goals
	•	Core functionality: 90%+
	•	Security critical paths: 100%
	•	MCP integration: 85%+

⸻
