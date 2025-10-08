# llm-cli

> Your on-device LLM, everywhere you can type.

A simple, extensible command-line interface for accessing Apple's on-device Foundation Models on macOS 26 (Tahoe).

## Features

- 🔒 **100% Local & Private** - All processing happens on-device
- ⚡ **Fast Streaming** - Real-time token streaming for immediate feedback
- 🛠️ **Tool Calling** - Register custom functions the model can invoke
- 💬 **Interactive Chat** - Persistent conversation history
- 🌐 **HTTP API** - Serve model over localhost for integration
- 📝 **Templates** - Reusable prompt templates
- 🎯 **JSON Output** - Machine-readable responses
- 🚫 **Zero Dependencies** - Pure Swift, no external packages

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

### Generate Text

```bash
# Simple generation
llm generate "Explain Swift concurrency in simple terms"

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

## Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `generate` | `gen`, `g` | Generate text from a prompt |
| `chat` | `c` | Interactive conversation mode |
| `tools` | `t` | Manage and demonstrate tools |
| `serve` | `s` | Start HTTP API server |
| `templates` | - | Manage prompt templates |
| `history` | `hist` | View/clear conversation history |
| `version` | `-v` | Show version information |
| `help` | `-h` | Show help message |

## Common Options

- `--model, -m <size>` - Model size: `small`, `medium`, `large`
- `--json` - Output in JSON format
- `--template, -t <name>` - Use a prompt template
- `--context, -c` - Include conversation history

## Templates

Templates are stored in `Templates/` or `/usr/local/share/llm-cli/templates/`.

### Create a Template

```bash
echo "Translate the following to French:" > Templates/translate-french.txt
```

### Use a Template

```bash
llm generate --template translate-french "Hello, world!"
```

### List Templates

```bash
llm templates --list
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
│   │   └── Serve.swift         # HTTP server
│   ├── Models/
│   │   └── LLM.swift           # FoundationModels wrapper
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

This is a **mock implementation** demonstrating the architecture and API design for Apple's FoundationModels framework, which is planned for macOS 26. The actual `FoundationModels` framework is not yet available as of October 2025.

The implementation shows:
- Complete CLI structure and command handling
- Async streaming patterns
- HTTP server architecture
- Tool calling interfaces
- Output formatting (human + JSON)

When Apple releases the FoundationModels framework, the mock `LLM.swift` can be replaced with actual API calls.

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
