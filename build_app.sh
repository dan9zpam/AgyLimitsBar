#!/bin/bash
# Build and package AGY Limits Bar as a macOS .app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AGY Limits Bar"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"
BINARY_NAME="AgyLimitsBar"

echo "🔨 Building..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BINARY_PATH="$(swift build -c release --show-bin-path 2>/dev/null)/${BINARY_NAME}"

echo "📦 Creating .app bundle at: ${APP_BUNDLE}"

# Clean old bundle
rm -rf "${APP_BUNDLE}"

# Create structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BINARY_PATH}" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"

# Copy plist
cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Code sign (ad-hoc)
echo "🔏 Ad-hoc signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Done! App bundle created at:"
echo "   ${APP_BUNDLE}"
echo ""
echo "Launch with:"
echo "   open '${APP_BUNDLE}'"
echo ""
echo "Or add to Login Items via System Preferences for auto-start."
