#!/bin/bash
set -euo pipefail

# Builds TabletDriverApp for arm64 only (no Rosetta) and wraps it into a
# proper .app bundle with a stable bundle identifier, signed with a real
# Team-ID-bearing identity when available. Ad-hoc signing (Team ID "not
# set") is unreliable for Input Monitoring/Accessibility TCC grants, so we
# prefer any "Apple Development" identity already in the login keychain
# (created by Xcode against the user's Apple ID) over ad-hoc "-" signing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.tabletdriver.app"
APP_NAME="TabletDriver"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"

VERSION="${VERSION:-1.0}"

# SIGN_IDENTITY can be set by the caller (scripts/package-release.sh does);
# "-" means ad-hoc.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -m1 'Apple Development' | awk -F'"' '{print $2}' || true)"
fi
if [ -z "$SIGN_IDENTITY" ]; then
    echo "WARNING: no 'Apple Development' identity found; falling back to ad-hoc signing." >&2
    echo "         Input Monitoring/Accessibility grants may not persist. Open Xcode once" >&2
    echo "         and sign in with an Apple ID to create one." >&2
    SIGN_IDENTITY="-"
else
    echo "==> Using signing identity: $SIGN_IDENTITY"
fi

cd "$ROOT_DIR"

echo "==> Building for arm64 (release)"
swift build -c release --arch arm64

BINARY_PATH="$(swift build -c release --arch arm64 --show-bin-path)/TabletDriverApp"

echo "==> Verifying arm64-only binary (no x86_64 slice)"
if lipo -info "$BINARY_PATH" | grep -q "x86_64"; then
    echo "ERROR: built binary contains an x86_64 slice; refusing to package." >&2
    exit 1
fi
file "$BINARY_PATH"

echo "==> Assembling app bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/TabletDriverApp"

if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TabletDriverApp</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Codesigning with stable identifier"
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"

echo "==> Gatekeeper assessment"
spctl -a -vv "$APP_BUNDLE" || echo "(rejected -- expected for a non-notarized personal build; launching it directly still works)"

echo "==> Verifying packaged app architecture"
file "$APP_BUNDLE/Contents/MacOS/TabletDriverApp"

echo "==> Done: $APP_BUNDLE"
echo "Move it to /Applications and launch it to install permissions + the login item."
