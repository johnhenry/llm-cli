# Quick Start Guide

## Choose Your Interface

### 🎨 GUI App (Recommended for most users)

**Best for:** Interactive conversations, exploring features, daily use

```bash
# Build and launch
./run-gui.sh

# Or manually
swift build --product LLMApp
open .build/arm64-apple-macosx/debug/LLMApp
```

**What you get:**
- Beautiful native macOS interface
- Menu bar icon with quick chat
- Persistent conversations
- Visual settings panel

### 🖲️ CLI Tool (For power users & automation)

**Best for:** Scripting, automation, integration with other tools

```bash
# Build
swift build --product llm

# Quick test
.build/arm64-apple-macosx/debug/llm status

# Start chatting
.build/arm64-apple-macosx/debug/llm chat
```

**What you get:**
- Terminal-based interface
- Scriptable commands
- HTTP server mode
- Tool calling support

## First Time Setup

### 1. Check System Requirements

```bash
# Using CLI
.build/arm64-apple-macosx/debug/llm status

# Or use GUI Settings panel
```

You need:
- ✅ macOS 26 (Tahoe) or later
- ✅ Apple Silicon (M1/M2/M3/M4)
- ✅ Apple Intelligence enabled

### 2. Enable Apple Intelligence

If status shows "unavailable":

1. Open **System Settings**
2. Go to **Apple Intelligence**
3. Enable Apple Intelligence
4. Wait for model download
5. Restart the app

### 3. First Conversation

**GUI:**
1. Launch app (it opens automatically)
2. Type your message in the input box
3. Press Return or click the send button
4. Watch the response stream in real-time!

**CLI:**
```bash
# Start chat mode
.build/arm64-apple-macosx/debug/llm chat

# Or single generation
.build/arm64-apple-macosx/debug/llm generate "Tell me a joke"
```

## Key Features to Try

### GUI Features

#### Menu Bar Quick Chat
1. Look for the brain icon in your menu bar (top right)
2. Click it
3. Type a quick question
4. Get instant response!

#### Multiple Conversations
1. Click the pencil icon (top right) for new conversation
2. View all conversations in the sidebar
3. Click any conversation to switch to it
4. Swipe left on a conversation to delete

#### Customize Settings
1. Press ⌘, or go to LLMApp > Settings
2. Adjust temperature for creativity
3. Change model size
4. Customize system prompt

### CLI Features

#### Templates
```bash
# List templates
.build/arm64-apple-macosx/debug/llm templates --list

# Use a template
.build/arm64-apple-macosx/debug/llm generate --template summarize "Text here"
```

#### HTTP Server
```bash
# Start server
.build/arm64-apple-macosx/debug/llm serve

# Test from another terminal
curl -X POST http://127.0.0.1:8765 -d "Hello, LLM!"
```

#### Tool Calling
```bash
# List available tools
.build/arm64-apple-macosx/debug/llm tools --list

# Demo tools
.build/arm64-apple-macosx/debug/llm tools --demo

# Interactive mode
.build/arm64-apple-macosx/debug/llm tools --interactive
```

## Common Issues

### "Model Unavailable"
**Problem:** Red status indicator or error message

**Solution:**
1. Check macOS version (must be 26+)
2. Enable Apple Intelligence in System Settings
3. Ensure you have Apple Silicon
4. Wait for model download to complete

### GUI Window Won't Open
**Problem:** App launches but no window appears

**Solution:**
1. Check the menu bar for the brain icon
2. Click it to open quick chat
3. Or use Window menu to show main window
4. If still stuck, quit (⌘Q) and relaunch

### CLI Command Not Found
**Problem:** `llm: command not found`

**Solution:**
```bash
# Use full path
.build/arm64-apple-macosx/debug/llm

# Or create alias
alias llm="$(pwd)/.build/arm64-apple-macosx/debug/llm"

# Or install globally
cp .build/arm64-apple-macosx/debug/llm /usr/local/bin/
```

### Conversations Not Saving (GUI)
**Problem:** Conversations disappear after restart

**Solution:**
1. Check disk space
2. Look for errors in Console.app
3. Check permissions for ~/Library/Application Support/

## Next Steps

### Learn More
- [Full GUI Documentation](GUI_README.md)
- [CLI README](README.md)
- [Feature Comparison](FEATURES.md)

### Customize
- Adjust temperature in settings (0.7 is balanced)
- Try different model sizes
- Create custom templates
- Set your own system prompt

### Integrate
- Use CLI in shell scripts
- Call HTTP server from Python/Node
- Create Shortcuts with CLI commands
- Add to your development workflow

## Tips & Tricks

### GUI
- **⌘N** for new conversation (faster than clicking)
- **Menu bar icon** is always accessible, even when window is hidden
- **Close window** (⌘W) keeps app running in menu bar
- **Quick chat popover** perfect for one-off questions

### CLI
- **Pipe text** to generate: `cat file.txt | llm generate "Summarize"`
- **JSON output** for scripting: `llm generate --json "text"`
- **Background server** for APIs: `llm serve &`
- **Context flag** for continuity: `llm generate --context "follow up"`

## Getting Help

### In-App
- GUI: Check Settings > Status tab
- CLI: Run `llm help` for command list

### Documentation
- This guide for quick start
- GUI_README.md for GUI details
- README.md for CLI details
- FEATURES.md for complete feature list

### Troubleshooting
- Check `llm status` or Settings panel
- View Console.app for errors
- Ensure Apple Intelligence is enabled
- Verify macOS 26+ and Apple Silicon

## Example Workflows

### Research Assistant (GUI)
1. Create new conversation
2. Set system prompt: "You are a research assistant..."
3. Ask questions about your topic
4. Conversation auto-saves for later reference

### Code Review (CLI)
```bash
cat MyCode.swift | llm generate --template code-review
```

### Quick Questions (Menu Bar)
1. Click brain icon
2. Ask question
3. Get answer
4. Close popover
5. Continue working

### API Integration (CLI Server)
```bash
# Terminal 1: Start server
llm serve

# Terminal 2: Make requests
curl -X POST http://127.0.0.1:8765 -d "Your question"
```

---

**Ready to start?** Choose your interface and start chatting! 🎉
