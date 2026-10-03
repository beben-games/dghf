#!/usr/bin/env bash
# Creates the labels and milestones for the project.
# Run once from inside the cloned repository, after `gh auth login`.
# Safe to run again: existing labels are updated, existing milestones are skipped.
set -euo pipefail

repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Setting up $repo"

label() {
  gh label create "$1" --color "$2" --description "$3" --force >/dev/null
  echo "  label: $1"
}

# Areas of work
label "code"         "1f6feb" "Godot scenes, scripts and systems"
label "art"          "d4a72c" "Sprites, tiles, UI and effects"
label "audio"        "8250df" "Music and sound effects"
label "writing"      "bf3989" "Story, dialogue and lore"
label "design"       "1a7f37" "Game design: mechanics, combat, spells, balance"
label "level-design" "0e8a16" "Stages, enemy waves and layout"

# Status and type
label "bug"          "d73a4a" "Something doesn't work"
label "blocked"      "b60205" "Waiting on something or someone"
label "question"     "c5def5" "Needs a team decision"

milestone() {
  if gh api "repos/$repo/milestones?state=all" --paginate -q '.[].title' | grep -Fxq "$1"; then
    echo "  milestone exists: $1"
  else
    gh api "repos/$repo/milestones" -f title="$1" -f description="$2" >/dev/null
    echo "  milestone: $1"
  fi
}

milestone "Setup"       "Repository, Godot project, project board, CLAUDE.md and game bible"
milestone "Milestone 1" "One character on an empty stage, moving and attacking, one punchable enemy, placeholder art"
milestone "Milestone 2" "The horde: dozens of simple enemies at once, and a first spell combo"
milestone "Milestone 3" "Three characters and local co-op with a shared camera"
milestone "Milestone 4" "One complete level with PixelLab art and music, released"

echo "Done."
