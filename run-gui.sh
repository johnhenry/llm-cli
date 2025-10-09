#!/bin/bash

# LLM GUI App Launcher Script

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧠 LLM GUI App Launcher${NC}"
echo ""

# Detect build configuration
if [ "$1" = "debug" ] || [ "$1" = "-d" ]; then
    BUILD_CONFIG="debug"
    echo -e "${YELLOW}Building in debug mode...${NC}"
else
    BUILD_CONFIG="release"
    echo -e "${GREEN}Building in release mode...${NC}"
fi

# Build the app
echo -e "${BLUE}Building LLMApp...${NC}"
if [ "$BUILD_CONFIG" = "debug" ]; then
    swift build --product LLMApp
else
    swift build -c release --product LLMApp
fi

# Get the binary path
BIN_PATH=".build/arm64-apple-macosx/${BUILD_CONFIG}/LLMApp"

# Check if build was successful
if [ ! -f "$BIN_PATH" ]; then
    echo -e "${YELLOW}Build failed or binary not found at $BIN_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build complete!${NC}"
echo ""

# Launch the app
echo -e "${BLUE}Launching LLMApp...${NC}"
open "$BIN_PATH"

echo -e "${GREEN}✅ App launched successfully!${NC}"
echo ""
echo "The app should now appear with:"
echo "  • A main window for chatting"
echo "  • A brain icon in your menu bar"
echo ""
echo "Click the menu bar icon for quick chat access!"
