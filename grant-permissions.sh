#!/bin/bash

echo "🎤 Voice Permissions Setup for LLM CLI"
echo "======================================="
echo ""
echo "This script will help you grant microphone and speech recognition"
echo "permissions to your terminal app."
echo ""

# Detect terminal app
TERMINAL_APP=""
if [ -n "$ITERM_SESSION_ID" ]; then
    TERMINAL_APP="iTerm"
    TERMINAL_PATH="/Applications/iTerm.app"
elif [ "$TERM_PROGRAM" = "Apple_Terminal" ]; then
    TERMINAL_APP="Terminal"
    TERMINAL_PATH="/System/Applications/Utilities/Terminal.app"
else
    echo "⚠️  Could not detect your terminal app."
    echo "Please manually grant permissions to your terminal in System Settings."
    exit 1
fi

echo "Detected terminal: $TERMINAL_APP"
echo ""

# Use tccutil to reset and request permissions
echo "📋 Step 1: Microphone Permission"
echo "--------------------------------"
echo "We'll trigger a microphone permission request..."
echo ""

# Try to access microphone - this should trigger the permission dialog
osascript <<EOF 2>/dev/null
tell application "System Events"
    try
        set volume input volume 50
        delay 0.5
        set currentVolume to input volume of (get volume settings)
    end try
end tell
EOF

echo "If you saw a permission dialog, great!"
echo "If not, manually grant microphone permission:"
echo "  1. Open System Settings"
echo "  2. Go to Privacy & Security > Microphone"
echo "  3. Enable '$TERMINAL_APP'"
echo ""
echo "Press Enter to continue..."
read

echo ""
echo "📋 Step 2: Speech Recognition Permission"
echo "----------------------------------------"
echo ""
echo "⚠️  IMPORTANT: Speech recognition permissions CANNOT be automatically"
echo "requested for command-line apps due to macOS security restrictions."
echo ""
echo "You must grant this permission manually:"
echo ""
echo "  1. Open System Settings"
echo "  2. Go to Privacy & Security > Speech Recognition"
echo "  3. Toggle ON the main switch at the top"
echo "  4. In the list below, find '$TERMINAL_APP'"
echo "  5. If it's not in the list, it will appear after you try to use voice features"
echo "  6. Enable the checkbox next to '$TERMINAL_APP'"
echo ""
echo "After granting permission, you may need to:"
echo "  - Restart your terminal"
echo "  - Or run: tccutil reset SpeechRecognition"
echo ""
echo "Press Enter when you've completed these steps..."
read

echo ""
echo "📋 Step 3: Testing"
echo "------------------"
echo "Testing if permissions are granted..."
echo ""

# Test with llm status
if command -v .build/release/llm &> /dev/null; then
    .build/release/llm chat --voice &
    sleep 2
    kill $! 2>/dev/null
    echo ""
else
    echo "⚠️  llm binary not found. Please build first:"
    echo "  swift build -c release"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "If you see authorization errors, the speech recognition permission"
echo "may not have been granted yet. Please follow Step 2 above carefully."
echo ""
echo "Then try: llm chat --voice"
echo ""
