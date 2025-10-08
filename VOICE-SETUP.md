# Voice Feature Setup Guide

## The Problem

macOS CLI apps cannot automatically request Speech Recognition permissions due to security restrictions. The permission dialog can only be triggered by GUI apps.

## Solution: Manual Permission Grant

### Step 1: Enable Speech Recognition System-Wide

1. Open **System Settings**
2. Go to **Privacy & Security** > **Speech Recognition**
3. **Toggle ON** the main switch at the top if it's off

### Step 2: Grant Permission to Your Terminal App

**Option A: Let macOS detect it automatically (Recommended)**

1. In System Settings > Privacy & Security > Speech Recognition
2. Keep that window open
3. Run this command in your terminal:
   ```bash
   llm chat --voice
   ```
4. The command will fail, BUT your terminal app should now appear in the Speech Recognition list
5. Enable the checkbox next to your terminal app (iTerm, Terminal, etc.)
6. Try `llm chat --voice` again - it should work now!

**Option B: If your terminal doesn't appear in the list**

Some terminal apps don't appear automatically. In this case:

1. Build and run the Permission Helper:
   ```bash
   ./build-permission-helper.sh
   ```
2. Click both buttons in the GUI app
3. Close the GUI app
4. The permissions are now granted system-wide

### Step 3: Verify

Run:
```bash
llm chat --voice
```

You should see:
```
Current authorization status: 3
✅ Authorization granted
```

## Troubleshooting

### Status shows 0 (Not Determined)
- Terminal app hasn't tried to access speech recognition yet
- Follow Step 2 Option A above

### Status shows 1 (Denied)
- You previously denied permission
- Go to System Settings > Privacy & Security > Speech Recognition
- Find your terminal app and enable it
- May need to restart terminal

### Status shows 2 (Restricted)
- Speech Recognition is disabled system-wide
- Go to System Settings > Privacy & Security > Speech Recognition
- Toggle ON the main switch

### Still not working?

1. Restart your terminal completely (quit and reopen)
2. Try:
   ```bash
   tccutil reset SpeechRecognition
   ```
3. Then repeat the setup steps

## Alternative: Text-Only Mode

Voice features are optional. You can use all LLM features without voice:

```bash
llm chat           # Text-based chat
llm generate       # Text generation
llm serve          # HTTP API
```

## Why is this so complicated?

macOS requires GUI apps to request microphone/speech permissions because they can show proper permission dialogs. CLI apps run in the terminal, which can't display native macOS permission dialogs. This is a security feature to prevent malicious scripts from accessing your microphone without your knowledge.

The workaround is to manually grant permissions in System Settings, which gives you full control over what has access to your microphone and speech recognition.
