#!/usr/bin/env bash
#
# build.sh — build MDE into a runnable, ad-hoc-signed .app using ONLY the
# Xcode Command Line Tools (no full Xcode required). It compiles via SwiftPM
# and hand-assembles the .app bundle that `swift build` doesn't produce.
#
# Usage:  ./build.sh            # release build -> build/MDE.app
#         open build/MDE.app
#
set -euo pipefail

CONFIG="release"
APP_NAME="MDE"
BUNDLE_ID="ohffs.MDE"
DEPLOY_TARGET="14.0"
DEV_LANG="en"
SRC_PLIST="MDE/MDE/Info.plist"     # authoritative plist (registers the .md association)
OUT_DIR="build"
APP="${OUT_DIR}/${APP_NAME}.app"

cd "$(dirname "$0")"

echo "==> Compiling ($CONFIG)…"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# The executable.
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# Any SwiftPM resource bundles (e.g. SwiftTerm's Shaders.metal). Bundle.module
# resolves these from the .app's Resources directory at runtime.
shopt -s nullglob
for bundle in "$BIN_PATH"/*.bundle; do
    cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

# Classic package-type marker.
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Resolve the Xcode build variables the source plist still contains.
sed -e "s/\$(EXECUTABLE_NAME)/${APP_NAME}/g" \
    -e "s/\$(PRODUCT_NAME)/${APP_NAME}/g" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/${BUNDLE_ID}/g" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/${DEPLOY_TARGET}/g" \
    -e "s/\$(DEVELOPMENT_LANGUAGE)/${DEV_LANG}/g" \
    "$SRC_PLIST" > "$APP/Contents/Info.plist"

# Ad-hoc sign (no Developer ID needed; locally-built apps aren't quarantined).
echo "==> Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"
echo "    open $APP"
