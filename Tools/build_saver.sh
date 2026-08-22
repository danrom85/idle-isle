#!/bin/bash
#
# Builds Idle Isle.saver — a macOS screen saver plug-in hosting the same
# island scene as the app.
#
# SwiftPM has no .saver product type, so this script compiles the engine,
# world, and saver sources directly into a bundle with swiftc. The result
# lands in build/Idle Isle.saver; double-click it (or drop it in
# ~/Library/Screen Savers) to install.

set -euo pipefail
cd "$(dirname "$0")/.."

SAVER_NAME="Idle Isle.saver"
CONTENTS="build/${SAVER_NAME}/Contents"

mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources/en.lproj"
cp Sources/IdleSaver/Info.plist "${CONTENTS}/Info.plist"
printf '/* Localized versions of Info.plist keys */\n' > "${CONTENTS}/Resources/en.lproj/InfoPlist.strings"

echo "Compiling ${SAVER_NAME}..."

# The package sources import IdleEngine as a separate module; in the saver
# everything compiles into one module, so strip those imports from a
# temporary copy.
TMP_SRC="$(mktemp -d)"
trap 'rm -rf "$TMP_SRC"' EXIT
cp Sources/IdleEngine/*.swift Sources/IdleWorld/*.swift Sources/IdleSaver/*.swift "$TMP_SRC/"
sed -i '' -e '/^import IdleEngine$/d' -e '/^import IdleWorld$/d' "$TMP_SRC"/*.swift

xcrun swiftc \
    -O \
    -parse-as-library \
    -emit-library \
    -module-name IdleIsleSaver \
    -framework AppKit \
    -framework SpriteKit \
    -framework ScreenSaver \
    "$TMP_SRC"/*.swift \
    -o "${CONTENTS}/MacOS/IdleIsle"

# Ad-hoc signature keeps Gatekeeper happy when installing locally.
codesign --force -s - "${CONTENTS}/MacOS/IdleIsle"

echo "Built build/${SAVER_NAME}"
echo ""
echo "To install:"
echo "  1. Double-click build/${SAVER_NAME}"
echo "  2. Or copy it to ~/Library/Screen Savers/"
