#!/bin/bash
set -uo pipefail

# Standalone cleanup for when TabletDriver.app has already been deleted
# (or won't launch) and its own in-app "Uninstall..." button can't run.
# Safe to run repeatedly / when nothing is installed.

BUNDLE_ID="com.tabletdriver.app"
APP_SUPPORT_DIR="$HOME/Library/Application Support/TabletDriver"

echo "==> Unregistering login item (if registered)"
osascript -e "
try
    tell application \"System Events\" to delete login item \"$BUNDLE_ID\"
end try
" >/dev/null 2>&1

# SMAppService-registered items also show up via launchctl's per-user domain;
# this is a best-effort removal in case the app registered a helper service
# under this identifier.
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" >/dev/null 2>&1

echo "==> Removing Application Support files ($APP_SUPPORT_DIR)"
rm -rf "$APP_SUPPORT_DIR"

echo "==> Resetting TCC permission grants for $BUNDLE_ID"
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1
tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1

cat <<EOF

Done. If TabletDriver.app still exists (e.g. in /Applications), drag it to
the Trash. If it still appears under System Settings -> General -> Login
Items, remove it there manually -- macOS can leave an orphaned entry if the
app bundle was deleted before it was unregistered.
EOF
