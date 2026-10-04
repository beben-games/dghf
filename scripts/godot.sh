#!/usr/bin/env bash
# Source this file to get GODOT_BIN, the Godot 4.7.2 binary.
# Set GODOT_BIN yourself to override, for example on Windows (Git Bash):
#   export GODOT_BIN="/c/Tools/Godot_v4.7.2-stable_win64.exe"
if [ -z "${GODOT_BIN:-}" ] || [ ! -x "$GODOT_BIN" ]; then
  GODOT_BIN="$(command -v godot 2>/dev/null || command -v godot4 2>/dev/null || true)"
fi
if [ ! -x "$GODOT_BIN" ] && [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
  GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
fi
if [ ! -x "$GODOT_BIN" ]; then
  echo "Godot not found. Put it on your PATH as 'godot', or export GODOT_BIN." >&2
  return 1 2>/dev/null || exit 1
fi
export GODOT_BIN
