#!/bin/sh
# Build the pinned DeckCraft native binary from source with the patches in
# deckcraft/patches/ and deckcraft/patches-native/ applied, into
# desktop/craft/deckcraft-<target>/wfm-deckcraft.
# Linux needs: libasound2-dev libxkbcommon-dev libwayland-dev libxcb1-dev.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$ROOT/deckcraft/VERSION")"
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "usage: $0 --target <rust-triple>" >&2; exit 2 ;;
  esac
done
[ -n "$TARGET" ] || { echo "usage: $0 --target <rust-triple>" >&2; exit 2; }
DEST="$ROOT/desktop/craft/deckcraft-$TARGET"
SRC="${DECKCRAFT_SRC:-}"
if [ -z "$SRC" ]; then
  SRC="$(mktemp -d)/deckcraft"
  git -c core.autocrlf=false clone --depth 1 --branch "v${VER}" https://github.com/storytold/deckcraft "$SRC"
fi
cd "$SRC"
git restore .
for p in "$ROOT"/deckcraft/patches/*.patch "$ROOT"/deckcraft/patches-native/*.patch; do
  git apply "$p"
done
cargo build --release --target "$TARGET" -p deckcraft
BIN=deckcraft
OUT=wfm-deckcraft
case "$TARGET" in
  *windows*) BIN=deckcraft.exe; OUT=wfm-deckcraft.exe ;;
esac
mkdir -p "$DEST"
cp "target/$TARGET/release/$BIN" "$DEST/$OUT"
echo "DeckCraft $VER (patched, native) installed to $DEST/$OUT"
