#!/bin/bash

# Build script for SyncSaves

set -e

echo "Building SyncSaves..."

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "Error: Swift not found. Please install Xcode command line tools."
    exit 1
fi

# Build the package
echo "Building package..."
swift build

# Run tests
echo "Running tests..."
swift test

echo "Build completed successfully!"

# To create an Xcode project:
# swift package generate-xcodeproj

echo ""
echo "To open in Xcode:"
echo "1. swift package generate-xcodeproj"
echo "2. open SyncSaves.xcodeproj"
echo ""
echo "Or build and run directly:"
echo "swift run SyncSaves"

echo ""
echo "Platforms supported:"
echo "- macOS 14.0+"
echo "- iOS 17.0+"
echo ""
echo "Features:"
echo "- DS, GBA, GBC save synchronization"
echo "- Multiplatform SwiftUI app"
echo "- WidgetKit widgets for both platforms"
echo "- FTP support for 3DS (DS only)"