#!/usr/bin/env bash
# ==============================================================================
# Hermes Menu Bar App - Build & Installer Script
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="HermesMenuBar"
BUNDLE_NAME="${APP_NAME}.app"
TARGET_DIR="${SCRIPT_DIR}/.build/release"
APP_BUNDLE="${SCRIPT_DIR}/${BUNDLE_NAME}"
INSTALL_DIR="${HOME}/Applications"

echo "======================================================"
echo "  🔨 Building Hermes Telegram Menu Bar App"
echo "======================================================"

cd "${SCRIPT_DIR}"

# 1. Compile release binary with SwiftPM
swift build -c release

# 2. Recreate App Bundle
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3. Copy binary
cp "${TARGET_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# 4. Copy App Icon
if [ -f "${SCRIPT_DIR}/Assets/AppIcon.icns" ]; then
    cp "${SCRIPT_DIR}/Assets/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
elif [ -f "/tmp/hermes_icon.icns" ]; then
    cp "/tmp/hermes_icon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# 5. Write Info.plist
cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HermesMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>ai.hermes.menubar</string>
    <key>CFBundleName</key>
    <string>HermesMenuBar</string>
    <key>CFBundleDisplayName</key>
    <string>Hermes Telegram Menu Bar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 6. Ad-hoc Codesign
codesign -s - --force --deep "${APP_BUNDLE}" 2>/dev/null || true

# 7. Install to ~/Applications
mkdir -p "${INSTALL_DIR}"
rm -rf "${INSTALL_DIR}/${BUNDLE_NAME}"
cp -R "${APP_BUNDLE}" "${INSTALL_DIR}/${BUNDLE_NAME}"

# Also install/link to /Applications if writable
if [ -w "/Applications" ]; then
    rm -rf "/Applications/${BUNDLE_NAME}"
    cp -R "${APP_BUNDLE}" "/Applications/${BUNDLE_NAME}" 2>/dev/null || true
fi

echo "======================================================"
echo "  ✅ Installed to ${INSTALL_DIR}/${BUNDLE_NAME}"
echo "======================================================"

# 8. Restart running instance if any
killall "${APP_NAME}" 2>/dev/null || true
sleep 0.5
open "${INSTALL_DIR}/${BUNDLE_NAME}"

echo "  🚀 Hermes Telegram Menu Bar launched successfully!"
echo "======================================================"
