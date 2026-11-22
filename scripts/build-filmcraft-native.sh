#!/bin/sh
# Build the pinned FilmCraft native binary from source with the patches in
# filmcraft/patches/ and filmcraft/patches-native/ applied, into
# desktop/craft/filmcraft-<target>/wfm-filmcraft.
# Linux needs: libasound2-dev libxkbcommon-dev libwayland-dev libxcb1-dev.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$ROOT/filmcraft/VERSION")"
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "usage: $0 --target <rust-triple>" >&2; exit 2 ;;
  esac
done
[ -n "$TARGET" ] || { echo "usage: $0 --target <rust-triple>" >&2; exit 2; }
DEST="$ROOT/desktop/craft/filmcraft-$TARGET"
SRC="${FILMCRAFT_SRC:-}"
if [ -z "$SRC" ]; then
  SRC="$(mktemp -d)/filmcraft"
  git -c core.autocrlf=false clone --depth 1 --branch "v${VER}" https://github.com/storytold/filmcraft "$SRC"
fi
cd "$SRC"
git restore .
for p in "$ROOT"/filmcraft/patches/*.patch "$ROOT"/filmcraft/patches-native/*.patch; do
  git apply "$p"
done
cargo build --release --target "$TARGET" -p filmcraft
BIN=filmcraft
OUT=wfm-filmcraft
case "$TARGET" in
  *windows*) BIN=filmcraft.exe; OUT=wfm-filmcraft.exe ;;
esac
mkdir -p "$DEST"
cp "target/$TARGET/release/$BIN" "$DEST/$OUT"
echo "FilmCraft $VER (patched, native) installed to $DEST/$OUT"
