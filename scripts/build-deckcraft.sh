#!/bin/sh
# Build the pinned DeckCraft web bundle from source with the patches in
# deckcraft/patches/ applied, into deckcraft/dist.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(cat "$ROOT/deckcraft/VERSION")"
DEST="$ROOT/deckcraft/dist"
SRC="${DECKCRAFT_SRC:-}"
if [ -z "$SRC" ]; then
  SRC="$(mktemp -d)/deckcraft"
  git clone --depth 1 --branch "v${VER}" https://github.com/storytold/deckcraft "$SRC"
fi
cd "$SRC"
git restore .
for p in "$ROOT"/deckcraft/patches/*.patch; do
  [ -e "$p" ] || continue
  git apply "$p"
done
(cd apps/deckcraft-web && trunk build --release)
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a dist/web/. "$DEST/"
echo "DeckCraft $VER installed to $DEST"
