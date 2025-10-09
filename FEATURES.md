# LLM-CLI Features Overview

## 🖥️ GUI Application Features

### Menu Bar Integration
- **Persistent Menu Bar Icon** - Brain icon always visible in macOS menu bar
- **Quick Chat Popover** - Click icon for instant chat access (400x500 popover)
- **Always Available** - App stays running even when main window is closed
- **Native macOS** - Built with SwiftUI and AppKit

### Main Window
- **Split View Interface** - Sidebar with conversation list, main chat area
- **Conversation Management**
  - Create new conversations with ⌘N or toolbar button
  - View all conversations in sidebar
  - Delete conversations with swipe or right-click
  - Auto-generated titles from first message
- **Clean Chat Interface**
  - Message bubbles (blue for user, gray for assistant)
  - Timestamps on each message
  - Typing indicator during generation
  - Auto-scroll to latest message

### Settings Panel
- **Model Configuration**
  - Choose between small, medium, large models
  - Temperature slider (0.0 - 2.0) with real-time preview
  - Visual explanation of temperature effects
- **System Prompt** - Customize AI behavior with text editor
- **Status Monitoring**
  - Real-time Foundation Models availability check
  - Color-coded status indicator (green/red)
  - Detailed error messages and solutions
  - Direct links to Apple documentation

### Data Persistence
- **Automatic Saving** - Conversations saved after each message
- **JSON Storage** - Clean, readable format
- **Application Support** - Stored in standard macOS location
- **UserDefaults** - Settings synced via macOS preferences

## 🖲️ CLI Features

### Commands
- `generate` - Single-shot text generation
- `chat` - Interactive conversation mode
- `tools` - Tool/function calling demonstrations
- `serve` - HTTP API server (localhost:8765)
- `templates` - Manage reusable prompts
- `history` - View/clear conversation history
- `status` - Check Foundation Models availability

### Advanced Features
- **Streaming Output** - Real-time token generation
- **JSON Mode** - Machine-readable output format
- **Temperature Control** - Via command-line flags
- **Context Management** - Maintain conversation history
- **Tool Calling** - Sample tools included (time, weather, file search)

## 🔧 Technical Implementation

### GUI Stack
```
SwiftUI          → Modern declarative UI
AppKit           → Menu bar integration
FoundationModels → Apple's LLM API
Combine          → Reactive state management
```

### Architecture
```
┌─────────────────────────────────────┐
│         Menu Bar Icon               │
│      (NSStatusItem)                 │
└─────────────┬───────────────────────┘
              │
    ┌─────────┴─────────┐
    │                   │
┌───▼────┐      ┌──────▼────────┐
│Popover │      │  Main Window  │
│Quick   │      │  (Split View) │
│Chat    │      │               │
└────────┘      └───────────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
    ┌────▼───┐    ┌────▼────┐   ┌────▼────┐
    │Sidebar │    │  Chat   │   │Settings │
    │        │    │  View   │   │  Panel  │
    └────────┘    └─────────┘   └─────────┘
                        │
                ┌───────┴────────┐
                │                │
         ┌──────▼─────┐   ┌─────▼──────┐
         │ViewModel   │   │   Models   │
         │            │   │            │
         └──────┬─────┘   └────────────┘
                │
         ┌──────▼─────────────┐
         │LanguageModelSession│
         │  (FoundationModels)│
         └────────────────────┘
```

### State Management
- **@StateObject** - ViewModels for each view
- **@Published** - Reactive properties
- **@AppStorage** - Persistent settings
- **ObservableObject** - Two-way data binding

### Concurrency
- **async/await** - Modern Swift concurrency
- **AsyncStream** - Streaming responses
- **@MainActor** - UI thread safety
- **Task** - Background operations

## 🎯 Unique Features

### Quick Chat Popover
Unlike most chat apps, LLM-CLI provides instant access via menu bar:
1. Click brain icon
2. Type message
3. Get response
4. Continue conversation or close

No need to switch windows or apps!

### Dual Interface
- **GUI** - For interactive exploration and conversation
- **CLI** - For automation, scripting, and integration
- **Shared Backend** - Same Foundation Models API
- **Complementary** - Use the right tool for the task

### Privacy-First Design
- **No network calls** - Everything on-device
- **No telemetry** - No usage tracking
- **Local storage** - Data never leaves your Mac
- **Apple's API** - Leverages system-level privacy

### Native Integration
- **System Settings** - Links to Apple Intelligence settings
- **Menu Bar** - Standard macOS pattern
- **Keyboard Shortcuts** - Native macOS shortcuts
- **Dark Mode** - Respects system appearance

## 🚀 Performance

### Streaming
- **Real-time updates** - Tokens appear as generated
- **Non-blocking UI** - Interface remains responsive
- **Efficient rendering** - Only updates changed content

### Memory
- **Lazy loading** - Conversations loaded on demand
- **Efficient storage** - Compressed JSON format
- **Automatic cleanup** - Old conversations can be deleted

### Responsiveness
- **60 FPS UI** - Smooth animations
- **Instant feedback** - Immediate visual response
- **Background processing** - LLM runs off main thread

## 📊 Comparison

| Feature | GUI App | CLI | Web UI |
|---------|---------|-----|--------|
| On-device | ✅ | ✅ | ❌ |
| Menu bar | ✅ | ❌ | ❌ |
| Streaming | ✅ | ✅ | ⚠️ |
| Automation | ❌ | ✅ | ❌ |
| Conversations | ✅ | ✅ | ✅ |
| Settings UI | ✅ | ⚙️ | ✅ |
| Native | ✅ | ✅ | ❌ |
| HTTP Server | ❌ | ✅ | N/A |

## 🎨 Design Philosophy

### GUI
- **Minimal** - Clean, uncluttered interface
- **Familiar** - Standard macOS patterns
- **Accessible** - Keyboard navigation, VoiceOver support
- **Consistent** - Follows Apple HIG

### CLI
- **Composable** - Unix philosophy
- **Scriptable** - Easy integration
- **Flexible** - Many output formats
- **Powerful** - Advanced features available

## 🔮 Future Enhancements

### Planned GUI Features
- [ ] Code syntax highlighting in messages
- [ ] Markdown rendering
- [ ] Voice input via dictation
- [ ] Export conversations (PDF, Markdown)
- [ ] Search across conversations
- [ ] Conversation folders/tags
- [ ] Custom keyboard shortcuts
- [ ] Themes and appearance options
- [ ] Tool calling UI
- [ ] Multi-window support

### Planned CLI Features
- [ ] Plugin system for custom commands
- [ ] Advanced tool calling
- [ ] Batch processing mode
- [ ] Configuration file support
- [ ] Shell completion scripts
- [ ] Performance profiling
- [ ] Model fine-tuning interface

### Integration Ideas
- [ ] Raycast extension
- [ ] Alfred workflow
- [ ] Shortcuts.app actions
- [ ] Quick Look plugin
- [ ] Finder extension
- [ ] Mail.app plugin
