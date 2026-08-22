#!/bin/bash
#
# Builds Idle Isle.app — a standalone, double-clickable macOS application.
#
# Uses a release build of the IdleIsle executable and wraps it in a proper
# bundle. The result lands in build/Idle Isle.app; drag it to Applications
# to install.

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Idle Isle.app"
CONTENTS="build/${APP_NAME}/Contents"

echo "Building release binary..."
swift build -c release

mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"
cp Tools/App-Info.plist "${CONTENTS}/Info.plist"
cp .build/release/IdleIsle "${CONTENTS}/MacOS/IdleIsle"

# SwiftPM packages bundled resources as a separate .bundle beside the
# executable; bring it along so hand-authored art loads at runtime.
if [ -d .build/release/IdleIsle_IdleWorld.bundle ]; then
    cp -R .build/release/IdleIsle_IdleWorld.bundle "${CONTENTS}/Resources/"
fi

# Ad-hoc signature so Gatekeeper accepts a locally built copy.
codesign --force -s - "${CONTENTS}/MacOS/IdleIsle"

echo "Built build/${APP_NAME}"
