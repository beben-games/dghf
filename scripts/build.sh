#!/usr/bin/env bash
# Builds the game for Windows x64 and Linux x64, as one zip each.
# Usage: scripts/build.sh [version] [--skin <folder>]    (version defaults to the current git commit)
# Needs the Godot 4.7.2 export templates (in the editor: Editor > Manage Export Templates).
# Output goes to builds/, which git ignores. Exits 1 if an export fails.
#
# The game itself contains only what is in the repository's game folders. The presets in
# export_presets.cfg leave out builds/, local/, tests/, docs/ and scripts/, so nothing in
# local/ is ever packed into the executable.
#
# --skin <folder> copies a skin (skin.json and its sheet, see docs/skins.md) into a
# skins/player folder beside each executable, where the built game looks for one. This is
# for playtesting art that is not in the repository. Those zips are named "-private":
# only publish one if everything in the skin folder may be published. A build made without
# --skin is the one for a GitHub release.
set -u
cd "$(dirname "$0")/.." || exit 1
source scripts/godot.sh || exit 1
version=""
skin=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skin)
      skin="${2:-}"
      [ -n "$skin" ] || { echo "build: --skin needs a folder"; exit 1; }
      shift 2 ;;
    *) version="$1"; shift ;;
  esac
done
[ -n "$version" ] || version="$(git describe --always --dirty 2>/dev/null || echo dev)"
name="dghf"
suffix=""
if [ -n "$skin" ]; then
  if [ ! -f "$skin/skin.json" ] || ! ls "$skin"/*.png >/dev/null 2>&1; then
    echo "build: $skin has no skin.json and sheet"; exit 1
  fi
  suffix="-private"
fi

rm -rf builds/windows-x64 builds/linux-x64
mkdir -p builds/windows-x64 builds/linux-x64
if ! "$GODOT_BIN" --headless --path . --import </dev/null >/dev/null 2>&1; then
  echo "build: the import failed"; exit 1
fi

export_one() {
  local preset="$1" out="$2" log
  log="$(mktemp)"
  "$GODOT_BIN" --headless --path . --export-release "$preset" "$out" </dev/null >"$log" 2>&1
  if [ ! -s "$out" ] || grep -q "ERROR" "$log"; then
    echo "build: the export '$preset' failed:"; tail -25 "$log"; rm -f "$log"; exit 1
  fi
  rm -f "$log"
  echo "build: $preset -> $out ($(du -h "$out" | cut -f1))"
}
export_one "Windows x64" "builds/windows-x64/$name.exe"
export_one "Linux x64" "builds/linux-x64/$name.x86_64"

for dir in builds/windows-x64 builds/linux-x64; do
  cp CREDITS.md "$dir/"
  if [ -n "$skin" ]; then
    mkdir -p "$dir/skins/player"
    cp "$skin/skin.json" "$skin"/*.png "$dir/skins/player/"
  fi
done
(
  cd builds || exit 1
  rm -f "$name-$version$suffix-windows-x64.zip" "$name-$version$suffix-linux-x64.zip"
  zip -qr "$name-$version$suffix-windows-x64.zip" windows-x64 && zip -qr "$name-$version$suffix-linux-x64.zip" linux-x64
) || { echo "build: the zip failed"; exit 1; }
ls -la builds/*.zip
if [ -n "$skin" ]; then
  echo "build: these zips carry the skin from $skin beside the executable. They are named -private: don't publish them unless that art may be published."
fi
echo "build: done ($version)"
