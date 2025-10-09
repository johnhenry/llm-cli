# LLM GUI App

A native macOS application for interacting with Apple's Foundation Models, featuring a menu bar icon and beautiful SwiftUI interface.

## Features

### 🎨 Native macOS Experience
- **Menu Bar Icon** - Quick access from the menu bar with a brain icon
- **Quick Chat Popover** - Click the menu bar icon for instant chat access
- **Main Window** - Full-featured chat interface with conversation management
- **Native UI** - Built with SwiftUI for a smooth, native macOS experience

### 💬 Chat Interface
- **Multiple Conversations** - Manage multiple chat sessions
- **Conversation History** - Persistent storage of all conversations
- **Streaming Responses** - Real-time response generation
- **Message Bubbles** - Clean, modern chat interface
- **Sidebar Navigation** - Easy switching between conversations

### ⚙️ Settings
- **Model Selection** - Choose between small, medium, and large models
- **Temperature Control** - Adjust response creativity (0.0 - 2.0)
- **System Prompt** - Customize the AI's behavior
- **Status Monitoring** - Real-time Foundation Models availability status

### 🔒 Privacy First
- **100% On-Device** - All processing happens locally
- **No Network Calls** - Works completely offline
- **Data Stays Local** - Conversations stored on your Mac only

## Building

```bash
# Build the GUI app
swift build --product LLMApp

# Run the app
open .build/arm64-apple-macosx/debug/LLMApp
```

Or build in release mode for better performance:

```bash
swift build -c release --product LLMApp
open .build/arm64-apple-macosx/release/LLMApp
```

## Usage

### Main Window
1. Launch the app - a main window will appear
2. Click the sidebar to view conversations
3. Click the pencil icon to start a new conversation
4. Type your message and press Return or click the send button

### Menu Bar Quick Chat
1. Click the brain icon in the menu bar
2. A popover will appear with a quick chat interface
3. Type and send messages for instant responses
4. Click outside the popover or press Escape to close it

### Settings
1. From the menu bar, select **LLMApp > Settings** (or press ⌘,)
2. Adjust model size, temperature, and system prompt
3. View Foundation Models status
4. Settings are saved automatically

## Keyboard Shortcuts

- **⌘N** - New conversation
- **⌘,** - Open settings
- **⌘W** - Close window (app stays running in menu bar)
- **⌘Q** - Quit app
- **Return** - Send message (in chat input)

## Menu Bar Icon

The app includes a persistent menu bar icon that provides:
- Quick access to chat via popover
- App doesn't quit when window is closed
- Always accessible from the menu bar

## Architecture

```
Sources/LLMApp/
├── LLMAppMain.swift          # App entry point
├── AppDelegate.swift         # Menu bar icon & app lifecycle
├── ContentView.swift         # Main window with sidebar
├── ChatView.swift            # Chat interface
├── QuickChatView.swift       # Menu bar popover chat
├── SettingsView.swift        # Settings panel
├── ChatViewModel.swift       # Main chat logic
├── QuickChatViewModel.swift  # Quick chat logic
└── Models.swift              # Data models
```

## Data Storage

Conversations are stored at:
```
~/Library/Application Support/com.llm-cli.app/conversations.json
```

Settings are stored in UserDefaults:
```
~/Library/Preferences/com.llm-cli.app.plist
```

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon (M1/M2/M3/M4)
- Apple Intelligence enabled
- Foundation Models available

## Troubleshooting

### App Won't Launch
- Ensure you're running macOS 26+
- Check that you have Apple Silicon
- Verify Apple Intelligence is enabled in System Settings

### "Model Unavailable" Status
1. Open **System Settings > Apple Intelligence**
2. Enable Apple Intelligence
3. Wait for model download to complete
4. Restart the app

### Menu Bar Icon Not Appearing
- The app may need permissions to display in the menu bar
- Try quitting and relaunching the app
- Check System Settings > Privacy & Security

### Conversations Not Saving
- Check disk space availability
- Ensure the app has permission to write to Application Support
- View Console.app for any error messages

## Comparison with CLI

| Feature | GUI App | CLI |
|---------|---------|-----|
| Interface | Native macOS SwiftUI | Terminal |
| Conversations | Persistent sidebar | History file |
| Menu Bar Access | ✅ Yes | ❌ No |
| Quick Chat | ✅ Popover | ❌ No |
| Settings UI | ✅ Visual panel | ⚙️ Command flags |
| Streaming | ✅ Real-time | ✅ Real-time |
| Tools/Functions | 🚧 Coming soon | ✅ Yes |
| HTTP Server | ❌ No | ✅ Yes |

Both interfaces use the same underlying Foundation Models API.

## Future Features

- [ ] Tool/function calling support
- [ ] Export conversations
- [ ] Search conversations
- [ ] Dark mode toggle
- [ ] Custom themes
- [ ] Keyboard shortcuts customization
- [ ] Conversation templates
- [ ] Voice input (dictation)
- [ ] Code syntax highlighting

## License

MIT License - See LICENSE file for details
