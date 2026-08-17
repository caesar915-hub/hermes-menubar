#!/usr/bin/env bash
# ==============================================================================
# Hermes Menu Bar - Apple Developer ID Codesign & Notarization Script
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-${SCRIPT_DIR}/HermesMenuBar.app}"
DMG_PATH="${2:-${SCRIPT_DIR}/dist/HermesMenuBar-1.0.0.dmg}"
ENTITLEMENTS="${SCRIPT_DIR}/entitlements.plist"

DEVELOPER_ID="${DEVELOPER_ID:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-AC_PASSWORD}"

echo "======================================================"
echo "  🔏 Apple Codesign & Notarization Pipeline"
echo "======================================================"

if [ -z "${DEVELOPER_ID}" ]; then
    echo "⚠️  DEVELOPER_ID environment variable not set."
    echo "    Looking for existing Developer ID Application certificate..."
    DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk -F '"' '{print $2}' || true)
fi

if [ -z "${DEVELOPER_ID}" ]; then
    echo "ℹ️  No Developer ID Application certificate found."
    echo "    Applying local ad-hoc signature for development..."
    codesign --force --deep --sign - "${APP_PATH}"
    echo "✅ Ad-hoc signing complete."
    exit 0
fi

echo "▶ Signing app bundle with: ${DEVELOPER_ID}"
codesign --force --deep --options runtime \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${DEVELOPER_ID}" \
    --timestamp \
    "${APP_PATH}"

echo "✅ App bundle signed."

# If DMG exists, sign and submit to Apple Notary Service
if [ -f "${DMG_PATH}" ]; then
    echo "▶ Signing DMG..."
    codesign --force --sign "${DEVELOPER_ID}" --timestamp "${DMG_PATH}"

    if [ -n "${APPLE_API_KEY_ID}" ] && [ -n "${APPLE_API_ISSUER}" ]; then
        echo "▶ Submitting DMG to Apple Notary Service (API Key)..."
        xcrun notarytool submit "${DMG_PATH}" \
            --key "${APPLE_API_KEY_PATH}" \
            --key-id "${APPLE_API_KEY_ID}" \
            --issuer "${APPLE_API_ISSUER}" \
            --wait
    elif xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" &>/dev/null; then
        echo "▶ Submitting DMG to Apple Notary Service (Keychain Profile: ${KEYCHAIN_PROFILE})..."
        xcrun notarytool submit "${DMG_PATH}" \
            --keychain-profile "${KEYCHAIN_PROFILE}" \
            --wait
    else
        echo "⚠️  Notarization credentials not configured."
        echo "    To configure notary credentials, run:"
        echo "    xcrun notarytool store-credentials \"${KEYCHAIN_PROFILE}\" --apple-id <your-apple-id> --team-id <team-id> --password <app-specific-password>"
        exit 0
    fi

    echo "▶ Stapling notarization ticket to DMG and App..."
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler staple "${APP_PATH}"
    echo "✅ Notarization & Stapling complete!"
fi
