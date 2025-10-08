#!/bin/bash

# Build the Permission Helper GUI app

echo "🔨 Building Permission Helper..."

cd PermissionHelper

# Compile the Swift file
swiftc -o PermissionHelper PermissionHelper.swift \
    -framework Cocoa \
    -framework Speech \
    -framework AVFoundation \
    -target arm64-apple-macos26.0

if [ $? -eq 0 ]; then
    # Create app bundle
    rm -rf PermissionHelper.app
    mkdir -p PermissionHelper.app/Contents/MacOS
    mkdir -p PermissionHelper.app/Contents/Resources

    # Move executable
    mv PermissionHelper PermissionHelper.app/Contents/MacOS/

    # Copy Info.plist
    cp Info.plist PermissionHelper.app/Contents/

    echo "✅ Permission Helper built successfully!"
    echo ""
    echo "To use it:"
    echo "  1. Open: PermissionHelper/PermissionHelper.app"
    echo "  2. Click both buttons and grant permissions"
    echo "  3. Then use: llm chat --voice"
    echo ""
    echo "Opening the app now..."
    open PermissionHelper.app
else
    echo "❌ Build failed"
    exit 1
fi
