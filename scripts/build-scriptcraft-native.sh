#!/bin/sh
# Build the pinned ScriptCraft native binary from source with the patches in
# scriptcraft/patches/ and scriptcraft/patches-native/ applied, into
# desktop/craft/scriptcraft-<target>/wfm-scriptcraft.
# Linux needs: libasound2-dev libxkbcommon-dev libwayland-dev libxcb1-dev.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$ROOT/scriptcraft/VERSION")"
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "usage: $0 --target <rust-triple>" >&2; exit 2 ;;
  esac
done
[ -n "$TARGET" ] || { echo "usage: $0 --target <rust-triple>" >&2; exit 2; }
DEST="$ROOT/desktop/craft/scriptcraft-$TARGET"
SRC="${SCRIPTCRAFT_SRC:-}"
if [ -z "$SRC" ]; then
  SRC="$(mktemp -d)/scriptcraft"
  git -c core.autocrlf=false clone --depth 1 --branch "v${VER}" https://github.com/NoJuanNobody/scriptcraft "$SRC"
fi
cd "$SRC"
git restore .
for p in "$ROOT"/scriptcraft/patches/*.patch "$ROOT"/scriptcraft/patches-native/*.patch; do
  git apply "$p"
done
cargo build --release --target "$TARGET" -p scriptcraft
BIN=scriptcraft
OUT=wfm-scriptcraft
case "$TARGET" in
  *windows*) BIN=scriptcraft.exe; OUT=wfm-scriptcraft.exe ;;
esac
mkdir -p "$DEST"
cp "target/$TARGET/release/$BIN" "$DEST/$OUT"
echo "ScriptCraft $VER (patched, native) installed to $DEST/$OUT"
