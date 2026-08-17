#!/usr/bin/env bash
# ==============================================================================
# Hermes Menu Bar - DMG Disk Image Creator
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-${SCRIPT_DIR}/HermesMenuBar.app}"
VERSION="${2:-1.0.0}"
DIST_DIR="${SCRIPT_DIR}/dist"
DMG_NAME="HermesMenuBar-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
VOL_NAME="Hermes Menu Bar"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: App bundle not found at ${APP_PATH}"
    echo "Run ./build.sh first."
    exit 1
fi

echo "======================================================"
echo "  📦 Creating macOS Disk Image (${DMG_NAME})"
echo "======================================================"

mkdir -p "${DIST_DIR}"
rm -f "${DMG_PATH}"

# Temporary staging area
TMP_DIR=$(mktemp -d /tmp/hermes_dmg.XXXXXX)
trap 'rm -rf "${TMP_DIR}"' EXIT

# Copy app bundle to staging
cp -R "${APP_PATH}" "${TMP_DIR}/HermesMenuBar.app"

# Create symlink to /Applications
ln -s /Applications "${TMP_DIR}/Applications"

# Build DMG using hdiutil
hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${TMP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo "======================================================"
echo "  ✅ Disk Image created: ${DMG_PATH}"
echo "======================================================"

# Print SHA-256 Checksum
SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')
echo "  🔑 SHA-256: ${SHA256}"
echo "======================================================"

# Write SHA256 file
echo "${SHA256}  ${DMG_NAME}" > "${DIST_DIR}/${DMG_NAME}.sha256"
