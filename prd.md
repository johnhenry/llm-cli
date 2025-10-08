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

Command	Purpose
llm generate	Stream or output a single completion for a prompt
llm chat	Interactive conversation with memory
llm tools	Register and call app-provided functions/tools
llm serve	Expose an HTTP/WebSocket server for remote API access
llm templates	Manage prompt templates
llm history	View or reset conversation history
llm eval (future)	Benchmark prompts/datasets
llm tune (future)	Fine-tune or specialize on local data


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
│       ├── main.swift
│       ├── Commands/
│       │   ├── Generate.swift
│       │   ├── Chat.swift
│       │   ├── Tools.swift
│       │   └── Serve.swift
│       ├── Models/
│       │   └── LLM.swift
│       └── Util/
│           ├── Output.swift
│           ├── HistoryStore.swift
│           └── PromptTemplates.swift
└── Templates/
    ├── summarize.txt
    └── code-review.txt


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
Reliability	Graceful error handling, no panics
Portability	macOS 26 +, Apple Silicon
Maintainability	Modular, one command per file
Extensibility	Easy to add new commands
Offline-first	All functionality available offline
No network dependency	Unless explicitly using “Private Cloud Compute”


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

🧩 Future Roadmap

Feature	Description	Target
llm tune	Fine-tuning API for small on-device personalization	v1.1
llm eval	Dataset benchmarking via JSONL input	v1.1
llm serve --ws	Full WebSocket streaming API	v1.2
Apple Shortcuts Integration	Native automation bridge	v1.2
JSON Schema Registration	Validate structured tool calls	v1.3
Plugin System	Load .swiftplugin bundles	v1.4


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
Interfaces	CLI, JSON, HTTP, WebSocket, Python, Node
License	MIT (proposed)
Goal	Local, scriptable, privacy-preserving AI access
Tagline	“Your on-device LLM, everywhere you can type.”
