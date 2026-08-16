#!/usr/bin/env bash
set -e

echo "🚀 Building ZipMip Release Binary..."
swift build -c release

APP_DIR="build/ZipMip.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
BIN_DIR="$RESOURCES_DIR/bin"
PLUGINS_DIR="$APP_DIR/Contents/PlugIns"

echo "📦 Creating macOS App Bundle ($APP_DIR)..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$PLUGINS_DIR"

# Copy main binary
cp .build/release/ZipMip "$MACOS_DIR/ZipMip"
chmod +x "$MACOS_DIR/ZipMip"

# Copy Info.plist
cp Sources/ZipMip/Info.plist "$APP_DIR/Contents/Info.plist"

# Copy AppIcon.icns
if [ -f "Sources/ZipMip/Resources/AppIcon.icns" ]; then
    cp Sources/ZipMip/Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Copy 7zz standalone engine if present
if [ -f "Sources/ZipMip/Resources/bin/7zz" ]; then
    cp Sources/ZipMip/Resources/bin/7zz "$BIN_DIR/7zz"
    chmod +x "$BIN_DIR/7zz"
elif [ -f "/opt/homebrew/bin/7zz" ]; then
    cp /opt/homebrew/bin/7zz "$BIN_DIR/7zz"
    chmod +x "$BIN_DIR/7zz"
fi

echo "✅ App bundle successfully created at: $APP_DIR"
echo "👉 You can run it with: open $APP_DIR"
