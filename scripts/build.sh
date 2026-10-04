#!/usr/bin/env bash
# Builds the game for Windows x64 and Linux x64, as one zip each.
# Usage: scripts/build.sh [version]    (default: the current git commit)
# Needs the Godot 4.7.2 export templates (in the editor: Editor > Manage Export Templates).
# Output goes to builds/, which git ignores. Exits 1 if an export fails.
#
# The builds contain only what is in the repository's game folders. The presets in
# export_presets.cfg leave out builds/, local/, tests/, docs/ and scripts/, so private
# placeholder art in local/ can never end up in a build.
set -u
cd "$(dirname "$0")/.." || exit 1
source scripts/godot.sh || exit 1
version="${1:-$(git describe --always --dirty 2>/dev/null || echo dev)}"
name="dghf"

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
done
(
  cd builds || exit 1
  rm -f "$name-$version-windows-x64.zip" "$name-$version-linux-x64.zip"
  zip -qr "$name-$version-windows-x64.zip" windows-x64 && zip -qr "$name-$version-linux-x64.zip" linux-x64
) || { echo "build: the zip failed"; exit 1; }
ls -la builds/*.zip
echo "build: done ($version)"
