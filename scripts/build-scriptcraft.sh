#!/bin/sh
# Build the pinned ScriptCraft web bundle from source with the patches in
# scriptcraft/patches/ applied, into scriptcraft/dist.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$ROOT/scriptcraft/VERSION")"
DEST="$ROOT/scriptcraft/dist"
SRC="${SCRIPTCRAFT_SRC:-}"
if [ -z "$SRC" ]; then
  SRC="$(mktemp -d)/scriptcraft"
  git clone --depth 1 --branch "v${VER}" https://github.com/NoJuanNobody/scriptcraft "$SRC"
fi
cd "$SRC"
git restore .
for p in "$ROOT"/scriptcraft/patches/*.patch; do
  git apply "$p"
done
cargo xtask web
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a apps/scriptcraft-web/dist/. "$DEST/"
echo "ScriptCraft $VER (patched) installed to $DEST"
