#!/bin/bash
set -euo pipefail

# Builds TabletDriverApp for arm64 only (no Rosetta) and wraps it into a
# proper .app bundle with a stable bundle identifier, signed with a real
# Team-ID-bearing identity when available. Ad-hoc signing (Team ID "not
# set") is unreliable for Input Monitoring/Accessibility TCC grants, so we
# prefer any "Apple Development" identity already in the login keychain
# (created by Xcode against the user's Apple ID) over ad-hoc "-" signing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.itsjaspermilan.TabletDriver"
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

# SwiftPM stamps the binary with sdk 14.0 (the deployment target), and macOS
# gives apps linked against an older SDK the old window chrome (small
# traffic lights, no Liquid Glass). Record the real SDK so the new design applies.
echo "==> Stamping build SDK $(xcrun --show-sdk-version) (new macOS window chrome)"
vtool -set-build-version macos 14.0 "$(xcrun --show-sdk-version)" -replace \
    -output "$APP_BUNDLE/Contents/MacOS/TabletDriverApp" "$APP_BUNDLE/Contents/MacOS/TabletDriverApp"

echo "==> Compiling Liquid Glass icon (Resources/AppIcon.icon)"
xcrun actool "$ROOT_DIR/Resources/AppIcon.icon" \
    --compile "$APP_BUNDLE/Contents/Resources" \
    --platform macosx --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist /dev/null >/dev/null

# Resources/Info.plist is the one Info.plist shared with the Xcode project;
# fill in the build-setting placeholders Xcode would normally substitute.
PLIST_PATH="$APP_BUNDLE/Contents/Info.plist"
sed -e 's/$(DEVELOPMENT_LANGUAGE)/en/' \
    -e 's/$(EXECUTABLE_NAME)/TabletDriverApp/' \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/" \
    "$ROOT_DIR/Resources/Info.plist" > "$PLIST_PATH"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$PLIST_PATH"
plutil -replace CFBundleVersion -string "$VERSION" "$PLIST_PATH"
plutil -replace CFBundleIconFile -string AppIcon "$PLIST_PATH"
plutil -replace CFBundleIconName -string AppIcon "$PLIST_PATH"
plutil -lint "$PLIST_PATH" >/dev/null

echo "==> Codesigning with stable identifier"
codesign --force --options runtime --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"

echo "==> Gatekeeper assessment"
spctl -a -vv "$APP_BUNDLE" || echo "(rejected -- expected for a non-notarized personal build; launching it directly still works)"

echo "==> Verifying packaged app architecture"
file "$APP_BUNDLE/Contents/MacOS/TabletDriverApp"

echo "==> Done: $APP_BUNDLE"
echo "Move it to /Applications and launch it to install permissions + the login item."
