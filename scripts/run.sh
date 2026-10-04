#!/usr/bin/env bash
# Runs the game from the project, without the editor and without a build.
# Usage: scripts/run.sh                                         the main scene
#        scripts/run.sh res://scenes/stress_test/stress_test.tscn    another scene
# Anything else on the command line is passed to Godot.
set -u
cd "$(dirname "$0")/.." || exit 1
source scripts/godot.sh || exit 1
# The first run after a clone has to import the project once.
[ -d .godot ] || "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1
exec "$GODOT_BIN" --path . "$@"
