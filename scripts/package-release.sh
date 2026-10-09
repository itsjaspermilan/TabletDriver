#!/bin/bash
set -euo pipefail

# Builds a copy of TabletDriver.app that other people can install, and
# wraps it in a .dmg and a .zip under build/.
#
# Signing, in order of preference:
#   1. "Developer ID Application" identity in your keychain (and, if
#      NOTARY_PROFILE names a `notarytool store-credentials` profile, the
#      result is notarized + stapled, so it opens with no warnings).
#   2. Ad-hoc signing. Works on any Apple Silicon Mac, but Gatekeeper makes
#      the recipient approve it once (see README "Sharing a build").
#
# An "Apple Development" identity is deliberately NOT used here: it only
# means something on machines registered to your developer account.
#
# Usage: VERSION=1.1 scripts/package-release.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TabletDriver"
VERSION="${VERSION:-1.0}"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$BUILD_DIR/$APP_NAME-$VERSION.zip"

SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | awk -F'"' '{print $2}' || true)"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
    echo "==> No Developer ID identity found; building ad-hoc signed"
else
    echo "==> Signing with: $SIGN_IDENTITY"
fi

SIGN_IDENTITY="$SIGN_IDENTITY" VERSION="$VERSION" "$ROOT_DIR/scripts/package-app.sh"

if [ "$SIGN_IDENTITY" != "-" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "==> Notarizing"
    NOTARY_ZIP="$BUILD_DIR/notarize.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
    rm -f "$NOTARY_ZIP"
fi

echo "==> Creating $ZIP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> Creating $DMG_PATH"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH" >/dev/null

if [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

echo
echo "==> Done. Share either of:"
ls -lh "$DMG_PATH" "$ZIP_PATH"
