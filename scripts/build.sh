#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${WIPEHUSH_OUTPUT_DIR:-$ROOT/dist}"
CACHE="${WIPEHUSH_MODULE_CACHE:-$ROOT/.build/module-cache}"
STAGE="$(mktemp -d /tmp/wipehush-build.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT" "$CACHE" "$STAGE/WipeHush.app/Contents/MacOS"
mkdir -p "$STAGE/WipeHush.app/Contents/Resources"
cp "$ROOT/LICENSE" "$STAGE/WipeHush.app/Contents/Resources/LICENSE.txt"
cp "$ROOT/LEGAL.md" "$STAGE/WipeHush.app/Contents/Resources/LEGAL.md"
cp "$ROOT/Resources/Info.plist" "$STAGE/WipeHush.app/Contents/Info.plist"
for ARCH in arm64 x86_64; do
    xcrun swiftc -O -module-cache-path "$CACHE" \
        -target "$ARCH-apple-macosx13.0" \
        "$ROOT/Sources/CleaningSession.swift" "$ROOT/Sources/main.swift" \
        -framework AppKit -framework ApplicationServices -o "$STAGE/WipeHush-$ARCH"
done
xcrun lipo -create "$STAGE/WipeHush-arm64" "$STAGE/WipeHush-x86_64" -output "$STAGE/WipeHush.app/Contents/MacOS/WipeHush"
# Sign on a local temporary volume before packaging to avoid File Provider metadata.
xattr -cr "$STAGE/WipeHush.app"
codesign --force --sign - "$STAGE/WipeHush.app"
codesign --verify --deep --strict "$STAGE/WipeHush.app"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$STAGE/WipeHush.app" "$OUT/WipeHush.zip"
(cd "$OUT" && shasum -a 256 WipeHush.zip > SHA256SUMS.txt)
printf 'Built %s/WipeHush.zip (Apple Silicon + Intel)\n' "$OUT"
