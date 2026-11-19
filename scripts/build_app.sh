#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

python3 scripts/generate_xcodeproj.py

DERIVED_DATA="$ROOT_DIR/build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

echo "Building TikTokDesktop (Release, arm64)..."
xcodebuild \
  -project TikTokDesktop.xcodeproj \
  -scheme TikTokDesktop \
  -configuration Release \
  -arch arm64 \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/TikTokDesktop.app"
rm -rf "$DIST_DIR/TikTokDesktop.app"
cp -R "$BUILT_APP" "$DIST_DIR/TikTokDesktop.app"

# Ad-hoc sign cleanly for local Apple Silicon launch
codesign --force --deep --sign - "$DIST_DIR/TikTokDesktop.app"

echo "Standalone macOS app bundle ready at: $DIST_DIR/TikTokDesktop.app"
