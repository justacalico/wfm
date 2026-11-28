#!/bin/sh
# Build the embedded webview helper (ScriptCraft / DeckCraft windows) into
# desktop/craft/wfm-webview. Linux needs webkit2gtk dev packages.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"
cd "$ROOT/desktop/webview"
if [ -n "$TARGET" ]; then
  cargo build --release --target "$TARGET"
  BIN="target/$TARGET/release/wfm-webview"
else
  cargo build --release
  BIN="target/release/wfm-webview"
fi
OUT=wfm-webview
case "${TARGET:-}" in
  *windows*) BIN="$BIN.exe"; OUT=wfm-webview.exe ;;
esac
mkdir -p "$ROOT/desktop/craft"
cp "$BIN" "$ROOT/desktop/craft/$OUT"
echo "wfm-webview installed to desktop/craft/$OUT"
