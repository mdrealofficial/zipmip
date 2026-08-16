#!/usr/bin/env bash
set -e

echo "🚀 Building ZipMip Release Binary..."
swift build -c release

APP_DIR="build/ZipMip.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
BIN_DIR="$RESOURCES_DIR/bin"
PLUGINS_DIR="$APP_DIR/Contents/PlugIns"
APPEX_DIR="$PLUGINS_DIR/ZipMipFinderSync.appex"

echo "📦 Creating macOS App Bundle ($APP_DIR)..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$PLUGINS_DIR"
mkdir -p "$APPEX_DIR/Contents/MacOS"
mkdir -p "$APPEX_DIR/Contents/Resources"

# 1. Copy main binary
cp .build/release/ZipMip "$MACOS_DIR/ZipMip"
chmod +x "$MACOS_DIR/ZipMip"

# 2. Copy Info.plist
cp Sources/ZipMip/Info.plist "$APP_DIR/Contents/Info.plist"

# 3. Copy AppIcon.icns
if [ -f "Sources/ZipMip/Resources/AppIcon.icns" ]; then
    cp Sources/ZipMip/Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# 4. Copy 7zz standalone engine
if [ -f "Sources/ZipMip/Resources/bin/7zz" ]; then
    cp Sources/ZipMip/Resources/bin/7zz "$BIN_DIR/7zz"
    chmod +x "$BIN_DIR/7zz"
elif [ -f "/opt/homebrew/bin/7zz" ]; then
    cp /opt/homebrew/bin/7zz "$BIN_DIR/7zz"
    chmod +x "$BIN_DIR/7zz"
fi

# 5. Compile & Embed FinderSync.appex
echo "⚡️ Compiling & Embedding FinderSync Extension..."
swiftc -target arm64-apple-macosx14.0 \
  -emit-executable \
  -o "$APPEX_DIR/Contents/MacOS/ZipMipFinderSync" \
  -I .build/arm64-apple-macosx/release/Modules \
  .build/arm64-apple-macosx/release/ZipMipCore.build/*.o \
  -framework Cocoa \
  -framework FinderSync \
  Sources/ZipMipFinderSync/FinderSync.swift

cp Sources/ZipMipFinderSync/Info.plist "$APPEX_DIR/Contents/Info.plist"
chmod +x "$APPEX_DIR/Contents/MacOS/ZipMipFinderSync"

# 6. Install to /Applications
echo "🚚 Installing to /Applications/ZipMip.app..."
rm -rf "/Applications/ZipMip.app"
cp -R "$APP_DIR" "/Applications/ZipMip.app"

# 7. Register Extension and Services with macOS
echo "🔄 Registering Finder Extension & macOS Services..."
pluginkit -a "/Applications/ZipMip.app/Contents/PlugIns/ZipMipFinderSync.appex" || true
pluginkit -e use -i com.zipmip.app.findersync || true

/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f -R "/Applications/ZipMip.app" || true

# Refresh dynamic services
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

echo "✅ App bundle and Finder Extension successfully installed to /Applications/ZipMip.app"
echo "👉 You can now right-click any file in Finder to use ZipMip!"
