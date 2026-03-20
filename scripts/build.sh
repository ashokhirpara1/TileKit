#!/bin/bash
# TileKit release build + DMG packager
# Usage: bash scripts/build.sh [version]
# Example: bash scripts/build.sh 1.0

set -e

VERSION=${1:-1.0}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_OUT="$DIST_DIR/TileKit.app"

echo "🔨 Building TileKit $VERSION..."

# 1. Compile release binary (Fix #9: use swift build, not xcodebuild)
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -3

BUILT_BINARY="$PROJECT_DIR/.build/release/TileKit"
if [ ! -f "$BUILT_BINARY" ]; then
    echo "❌ Build failed — binary not found at $BUILT_BINARY"
    exit 1
fi

# 2. Construct .app bundle from scratch (Fix #9: don't rely on pre-existing bundle)
echo "📦 Assembling app bundle..."
rm -rf "$APP_OUT"
mkdir -p "$APP_OUT/Contents/MacOS"
mkdir -p "$APP_OUT/Contents/Resources"

# Binary
cp "$BUILT_BINARY" "$APP_OUT/Contents/MacOS/TileKit"

# Icon
if [ -f "$PROJECT_DIR/TileKit/TileKit/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/TileKit/TileKit/Resources/AppIcon.icns" "$APP_OUT/Contents/Resources/AppIcon.icns"
fi

# Entitlements (stored alongside binary for reference; actual enforcement is at signing time)
cp "$PROJECT_DIR/TileKit/TileKit.entitlements" "$APP_OUT/Contents/TileKit.entitlements"

# Info.plist (written fresh so version is always correct)
cat > "$APP_OUT/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TileKit</string>
    <key>CFBundleIdentifier</key>
    <string>com.tilekit.app</string>
    <key>CFBundleName</key>
    <string>TileKit</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# 3. Clear quarantine for local testing
xattr -cr "$APP_OUT" 2>/dev/null || true

# 4. Package as DMG using hdiutil (built into macOS — no extra tools needed)
echo "💿 Creating DMG..."
DMG_STAGING="$DIST_DIR/dmg_staging"
DMG_PATH="$DIST_DIR/TileKit-$VERSION.dmg"

rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -r "$APP_OUT" "$DMG_STAGING/TileKit.app"
ln -s /Applications "$DMG_STAGING/Applications"

cat > "$DMG_STAGING/README.txt" << 'EOF'
TileKit — macOS Window Tiling

INSTALL: Drag TileKit.app to the Applications folder.

FIRST LAUNCH: macOS may show a security warning because this app is
not notarized. To open it:
  • Right-click TileKit.app → Open → Open

Or run in Terminal:
  xattr -dr com.apple.quarantine /Applications/TileKit.app
EOF

hdiutil create \
    -volname "TileKit $VERSION" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" > /dev/null

rm -rf "$DMG_STAGING"

echo ""
echo "✅ Done!"
echo "   App bundle: $APP_OUT"
echo "   DMG:        $DMG_PATH"
echo "   Size:       $(du -sh "$DMG_PATH" | cut -f1)"
