# Testing the LLM GUI App

## Current Status

✅ **App is Running**
- Process ID: Active
- Memory Usage: ~102 MB
- Build: Debug configuration
- Platform: arm64-apple-macosx

## What You Should See

### 1. Main Window
When launched, you should see:
- A window titled "LLMApp" (or untitled)
- Left sidebar showing "Conversations"
- Empty conversation list (first launch)
- Main chat area with input field at bottom
- Toolbar with sidebar toggle and new conversation button

### 2. Menu Bar Icon
Look at the top-right of your screen:
- Brain icon (🧠) in the menu bar
- Click it to open the quick chat popover
- 400x500 pixel popover window appears below icon

### 3. Quick Chat Popover
When you click the menu bar icon:
- "Quick Chat" header with brain icon
- Scrollable message area
- Text input field at bottom
- Send button (arrow icon)
- Trash icon to clear conversation

## Testing Checklist

### Basic Functionality
- [ ] App launches without errors
- [ ] Main window appears
- [ ] Menu bar icon is visible
- [ ] Clicking menu bar icon opens popover
- [ ] Can type in input field
- [ ] Send button is enabled when text is entered
- [ ] Messages appear after sending

### Conversation Management (Main Window)
- [ ] Can create new conversation (pencil icon)
- [ ] Conversations appear in sidebar
- [ ] Can switch between conversations
- [ ] Can delete conversations (swipe left or right-click)
- [ ] Conversation titles auto-generate from first message

### Settings Panel
- [ ] Can open settings (⌘, or menu)
- [ ] Model size picker works
- [ ] Temperature slider works (0.0 - 2.0)
- [ ] System prompt text editor works
- [ ] Status tab shows availability
- [ ] Links to documentation work

### Streaming & Real-time
- [ ] Typing indicator appears while generating
- [ ] Messages stream in real-time (word by word)
- [ ] Auto-scroll to latest message
- [ ] UI remains responsive during generation

### Persistence
- [ ] Close app (⌘Q) and relaunch
- [ ] Conversations are still there
- [ ] Settings are preserved
- [ ] Last selected conversation is active

### Menu Bar Behavior
- [ ] App stays running when main window closed
- [ ] Menu bar icon remains visible
- [ ] Can reopen main window from menu
- [ ] Popover closes when clicking outside

## Manual Testing Steps

### Test 1: Basic Chat
1. Launch app: `open .build/arm64-apple-macosx/debug/LLMApp`
2. Wait for main window to appear
3. Type "Hello" in the input field
4. Press Return or click send button
5. **Expected:** Typing indicator appears, then response streams in

### Test 2: Menu Bar Quick Chat
1. Click the brain icon in menu bar
2. Popover should appear
3. Type "Tell me a joke"
4. Press Return
5. **Expected:** Response appears in popover
6. Click outside to close
7. **Expected:** Popover closes, icon remains

### Test 3: Multiple Conversations
1. In main window, click pencil icon (new conversation)
2. Type "Conversation 1"
3. Click pencil icon again
4. Type "Conversation 2"
5. Check sidebar
6. **Expected:** Two conversations listed
7. Click first conversation
8. **Expected:** Switches to that conversation

### Test 4: Settings
1. Press ⌘,
2. Settings window appears
3. Move temperature slider
4. Change model size
5. Close settings
6. Reopen settings
7. **Expected:** Changes are saved

### Test 5: Persistence
1. Create a conversation with a few messages
2. Quit app (⌘Q)
3. Relaunch app
4. **Expected:** Conversation is still there

### Test 6: Status Check
1. Open Settings
2. Click "Status" tab
3. **Expected:** Shows availability status
   - If macOS 26+, Apple Silicon, AI enabled: Green dot, "Available"
   - Otherwise: Red dot with specific reason

## Known Limitations

### Current Implementation
- **No actual AI responses** (requires macOS 26 + Foundation Models)
- Mock streaming will show placeholder text
- Model availability check works but actual generation needs the framework
- Settings save but model size doesn't affect behavior yet (all use default)

### Expected Behavior on macOS < 26
- Status will show "Device not eligible" or "Apple Intelligence not enabled"
- Attempting to chat will show error message
- App will still launch and UI will work
- This is expected and correct behavior

### Development Mode
- Running debug build (slower, larger)
- Console may show warnings (normal)
- SwiftUI canvas previews not included
- No code signing (can't distribute yet)

## Debugging

### Check Console
```bash
# Open Console.app
open -a Console

# Filter for LLMApp
# Look for any error messages
```

### Check Logs
```bash
# View system logs
log stream --predicate 'process == "LLMApp"' --level debug
```

### Force Quit
If app freezes:
```bash
# Find process
ps aux | grep LLMApp

# Kill it
killall LLMApp

# Or use Activity Monitor
open -a "Activity Monitor"
```

### Rebuild
If something seems broken:
```bash
# Clean build
swift package clean

# Rebuild
swift build --product LLMApp

# Relaunch
open .build/arm64-apple-macosx/debug/LLMApp
```

## Performance Metrics

### Startup Time
- **Expected:** 1-3 seconds to main window
- **Menu bar:** Icon appears immediately

### Memory Usage
- **Initial:** ~95 MB
- **With conversations:** ~100-150 MB
- **Idle:** Should stay stable

### CPU Usage
- **Idle:** 0-1%
- **Generating:** Depends on Foundation Models
- **UI updates:** Minimal

## Success Criteria

✅ App launches
✅ Main window appears
✅ Menu bar icon visible
✅ Can type messages
✅ UI is responsive
✅ Settings can be accessed
✅ App stays running in menu bar
✅ Conversations persist across launches

## Next Steps

### For Development
1. Test on macOS 26 beta when available
2. Verify Foundation Models integration
3. Add error handling improvements
4. Implement tool calling UI
5. Add export functionality

### For Distribution
1. Create release build with optimizations
2. Add code signing
3. Create app bundle with icon
4. Notarize for distribution
5. Create installer or DMG

## Feedback

If you encounter any issues:
1. Check this testing guide
2. Review console logs
3. Try rebuilding
4. Check system requirements
5. Report unexpected behavior

---

**Testing completed?** Check off the items above and note any issues!
