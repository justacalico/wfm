#!/bin/sh
# Build the pinned FilmCraft web bundle from source with the patches in
# filmcraft/patches/ applied, into filmcraft/dist.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$ROOT/filmcraft/VERSION")"
DEST="$ROOT/filmcraft/dist"
SRC="${FILMCRAFT_SRC:-}"
if [ -z "$SRC" ]; then
  SRC="$(mktemp -d)/filmcraft"
  git clone --depth 1 --branch "v${VER}" https://github.com/storytold/filmcraft "$SRC"
fi
cd "$SRC"
git restore .
for p in "$ROOT"/filmcraft/patches/*.patch; do
  git apply "$p"
done
cargo xtask web
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a target/web/dist/. "$DEST/"
echo "FilmCraft $VER (patched) installed to $DEST"
