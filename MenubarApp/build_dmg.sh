#!/bin/bash
# Builds IGDL.app (via build_app.sh) then packages it into a drag-to-Applications
# .dmg at dist/IGDL.dmg, for distribution outside this machine.
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:-1.0.0}"
APP_NAME="IGDL"
APP_PATH="../$APP_NAME.app"
DIST_DIR="../dist"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
STAGING="$(mktemp -d)"

./build_app.sh

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

cp -R "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo "Built $DMG_PATH"
