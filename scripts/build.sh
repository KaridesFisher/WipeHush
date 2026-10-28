#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${CLEANMAC_OUTPUT_DIR:-$ROOT/dist}"
CACHE="${CLEANMAC_MODULE_CACHE:-$ROOT/.build/module-cache}"
STAGE="$(mktemp -d /tmp/cleanmac-build.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT" "$CACHE" "$STAGE/CleanMac.app/Contents/MacOS"
mkdir -p "$STAGE/CleanMac.app/Contents/Resources"
cp "$ROOT/LICENSE" "$STAGE/CleanMac.app/Contents/Resources/LICENSE.txt"
cp "$ROOT/LEGAL.md" "$STAGE/CleanMac.app/Contents/Resources/LEGAL.md"
cp "$ROOT/Resources/Info.plist" "$STAGE/CleanMac.app/Contents/Info.plist"
for ARCH in arm64 x86_64; do
    xcrun swiftc -O -module-cache-path "$CACHE" \
        -target "$ARCH-apple-macosx13.0" \
        "$ROOT/Sources/CleaningSession.swift" "$ROOT/Sources/main.swift" \
        -framework AppKit -framework ApplicationServices -o "$STAGE/CleanMac-$ARCH"
done
xcrun lipo -create "$STAGE/CleanMac-arm64" "$STAGE/CleanMac-x86_64" -output "$STAGE/CleanMac.app/Contents/MacOS/CleanMac"
# Sign on a local temporary volume before packaging to avoid File Provider metadata.
xattr -cr "$STAGE/CleanMac.app"
codesign --force --sign - "$STAGE/CleanMac.app"
codesign --verify --deep --strict "$STAGE/CleanMac.app"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$STAGE/CleanMac.app" "$OUT/CleanMac.zip"
(cd "$OUT" && shasum -a 256 CleanMac.zip > SHA256SUMS.txt)
printf 'Built %s/CleanMac.zip (Apple Silicon + Intel)\n' "$OUT"
