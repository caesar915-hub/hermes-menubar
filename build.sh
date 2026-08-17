#!/usr/bin/env bash
# ==============================================================================
# Hermes Menu Bar App - Universal Build, Package & Installer Script
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="HermesMenuBar"
BUNDLE_NAME="${APP_NAME}.app"
APP_BUNDLE="${SCRIPT_DIR}/${BUNDLE_NAME}"
INSTALL_DIR="${HOME}/Applications"
BUILD_UNIVERSAL=false
CREATE_DMG=false
AUTO_LAUNCH=true

for arg in "$@"; do
    case $arg in
        --universal)
            BUILD_UNIVERSAL=true
            shift
            ;;
        --dmg)
            CREATE_DMG=true
            shift
            ;;
        --no-launch)
            AUTO_LAUNCH=false
            shift
            ;;
    esac
done

echo "======================================================"
echo "  🔨 Building Hermes Telegram Menu Bar App"
echo "======================================================"

cd "${SCRIPT_DIR}"

# 1. Compile release binary with SwiftPM
if [ "$BUILD_UNIVERSAL" = true ]; then
    echo "▶ Building Universal binary (arm64 + x86_64)..."
    swift build -c release --arch arm64 --arch x86_64
    BINARY_SOURCE="${SCRIPT_DIR}/.build/apple/Products/Release/${APP_NAME}"
else
    echo "▶ Building native binary..."
    swift build -c release
    BINARY_SOURCE="${SCRIPT_DIR}/.build/release/${APP_NAME}"
fi

# 2. Recreate App Bundle
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3. Copy binary
cp "${BINARY_SOURCE}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
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

# 6. Codesign (Hardened Runtime if certificate present, or ad-hoc)
if [ -f "${SCRIPT_DIR}/scripts/notarize.sh" ]; then
    chmod +x "${SCRIPT_DIR}/scripts/notarize.sh"
    "${SCRIPT_DIR}/scripts/notarize.sh" "${APP_BUNDLE}" "" || codesign -s - --force --deep "${APP_BUNDLE}" 2>/dev/null || true
else
    codesign -s - --force --deep "${APP_BUNDLE}" 2>/dev/null || true
fi

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

# 8. Install CLI launcher script to ~/.local/bin/hermes-menubar
mkdir -p "${HOME}/.local/bin"
cat << 'CLI_EOF' > "${HOME}/.local/bin/hermes-menubar"
#!/usr/bin/env bash
if pgrep -x "HermesMenuBar" >/dev/null 2>&1; then
    echo "⚡️ Hermes Menu Bar is already running (PID $(pgrep -x HermesMenuBar))."
else
    echo "🚀 Launching Hermes Menu Bar..."
    open -a "HermesMenuBar" 2>/dev/null || open "$HOME/Applications/HermesMenuBar.app" 2>/dev/null || open "/Applications/HermesMenuBar.app"
    sleep 0.5
    if pgrep -x "HermesMenuBar" >/dev/null 2>&1; then
        echo "✅ Hermes Menu Bar running (PID $(pgrep -x HermesMenuBar))."
    fi
fi
CLI_EOF
chmod +x "${HOME}/.local/bin/hermes-menubar"

# 9. Create DMG if requested
if [ "$CREATE_DMG" = true ]; then
    chmod +x "${SCRIPT_DIR}/scripts/create_dmg.sh"
    "${SCRIPT_DIR}/scripts/create_dmg.sh" "${APP_BUNDLE}" "1.1.0"
fi

# 9. Restart running instance if requested
if [ "$AUTO_LAUNCH" = true ]; then
    killall "${APP_NAME}" 2>/dev/null || true
    sleep 0.5
    open "${INSTALL_DIR}/${BUNDLE_NAME}"
    echo "  🚀 Hermes Telegram Menu Bar launched successfully!"
    echo "======================================================"
fi
