#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${WIPEHUSH_MODULE_CACHE:-$ROOT/.build/module-cache}"
TEST_DIR="$(mktemp -d /tmp/wipehush-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$CACHE"
xcrun swiftc -module-cache-path "$CACHE" "$ROOT/Sources/CleaningSession.swift" "$ROOT/Tests/main.swift" -o "$TEST_DIR/session-tests"
"$TEST_DIR/session-tests"
/usr/libexec/PlistBuddy -c 'Print CFBundleDevelopmentRegion' "$ROOT/Resources/Info.plist" | /usr/bin/grep -qx en
