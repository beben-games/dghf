#!/usr/bin/env bash
# Creates the Setup and Milestone 1 issues, plus one Milestone 2 issue.
# Run once from inside the cloned repository, after scripts/setup-github.sh.
# Issues that already exist (same title) are skipped.
set -euo pipefail

exists() {
  gh issue list --state all --search "\"$1\" in:title" --json title -q '.[].title' | grep -Fxq "$1"
}

# issue <title> <labels> <milestone>, with the body on stdin (a heredoc).
# Sets last_issue to the issue number.
last_issue=""
issue() {
  local body
  body=$(cat)
  if exists "$1"; then
    echo "  exists: $1" >&2
    last_issue=$(gh issue list --state all --search "\"$1\" in:title" --json number,title \
      -q ".[] | select(.title == \"$1\") | .number" | head -n1)
    return
  fi
  local url
  url=$(gh issue create --title "$1" --label "$2" --milestone "$3" --body "$body")
  echo "  created: $1" >&2
  last_issue="${url##*/}"
}

echo "Creating issues" >&2

# ---------------------------------------------------------------- Setup

issue "Create the Godot project" "code" "Setup" <<'EOF'
Suggested owner: Ben.

- Use Godot 4.7.2 stable (decided 2026-10-03, see `docs/design/2026-10-03-setup.md`).
- Create the project in the repository root and commit `project.godot`.
- Create the folder layout from `CLAUDE.md` and `docs/architecture.md` (section 10).
- Set the window and internal resolution. `docs/architecture.md` proposes 480 by 270, scaled by whole numbers; this can change after the combat-core brainstorm.

**Done when:** T and E can clone the repository and open the project in the agreed version without errors.
EOF

# ---------------------------------------------------------------- Milestone 1

issue "Brainstorm and settle the combat core" "design,question" "Milestone 1" <<'EOF'
Suggested owner: Ben, with T and E at the weekly meeting.

`docs/architecture.md` is a proposal Claude wrote before any code existed. Nothing in it is decided.

- Brainstorm it with Claude one section at a time, and challenge it: the questions at the end of each section are the starting point.
- Bring the questions that need the whole team to the weekly meeting (input style, lanes or free depth, enemy count on screen).
- Write what's settled in `docs/design/` and mark those sections **Decided** in `docs/architecture.md`.

**Done when:** the sections Milestone 1 needs are decided: 1 (frames), 2 (2.5D world), 3 (moves as data), 4 (fighter states), 5 (input), 7 (hits and feel) and 9 (camera and screen). Section 6 (crowds) is decided after the stress test. Section 8 (spells) can wait until Milestone 2.
EOF
brainstorm=$last_issue

issue "Crowd stress test" "code" "Milestone 1" <<'EOF'
Throwaway code: nothing gets built on top of it. It can start before the brainstorm, and its results feed section 6 of `docs/architecture.md`.

- A test scene that spawns 100, 200 and 500 enemies using a placeholder sprite. They walk toward a moving target, avoid overlapping, and think every 6 frames, staggered.
- An on-screen readout of the frame rate and enemy count.
- Try the proposed approach (light pooled scenes, no physics bodies). If it can't hold 60 frames per second at the count we want, try the faster one (arrays drawn with `RenderingServer` or `MultiMesh`).

**Done when:** all three of us have run it, a table of frame rate per machine and enemy count is posted in this issue, and there's a recommendation for section 6.
EOF

issue "Placeholder art" "art" "Milestone 1" <<'EOF'
Suggested owner: E. Can start right away.

CC0 packs that fit the setting (check each page's licence before adding anything):
- Playable placeholders: LuizMelo's Medieval Warrior Pack 3 and Evil Wizard 2 (itch.io).
- Enemies: LuizMelo's Monsters Creatures Fantasy (skeleton, goblin, mushroom, flying eye).
- A knight with full get-hit animations: Puffolotti's "Basic knight for platformers and scrolling beat 'em up" (OpenGameArt).

Steps:
- Import them into `assets/sprites/<name>/`.
- Set up `SpriteFrames` for one playable character (idle, run, attacks, hit, death) and one enemy.
- Add a row per pack to `CREDITS.md`.

**Done when:** the sprites play their animations in Godot, and `CREDITS.md` lists every pack.
EOF

issue "Placeholder stage" "level-design" "Milestone 1" <<'EOF'
Suggested owner: T. Can start right away.

- Build a stage scene from ansimuz's Gothicvania Town (CC0, OpenGameArt): parallax background layers and ground.
- Mark the walkable area: the range of depth (up and down the screen) characters can move in.
- One arena where the camera would lock until enemies are cleared (just marked for now).
- Add the pack to `CREDITS.md`. Its music needs credit to Pascal Belisle if we use it.

**Done when:** the stage scene opens and runs, and a sprite placed in it sits on the ground.
EOF

issue "2.5D movement" "code" "Milestone 1" <<EOF
Waits on #$brainstorm (sections 1, 2 and 4).

- The player walks left, right, up and down the screen, runs and jumps.
- Position follows the decided model (proposed: x, depth and height), draw order follows depth, and the player stays inside the stage's walkable area.

**Done when:** a placeholder character moves around the placeholder stage and passes correctly in front of and behind other sprites.
EOF

issue "Input router and buffer" "code" "Milestone 1" <<EOF
Waits on #$brainstorm (section 5).

- Devices are assigned to players 1, 2 and 3. Game code only ever asks about a player, never a device.
- Each player has an input buffer, and an attack pressed a few frames early still comes out.
- Motion inputs only if the brainstorm decides on them for Milestone 1.

**Done when:** two gamepads drive two characters independently, and buffered attacks work.
EOF

issue "Moves from data and a first combo" "code,design" "Milestone 1" <<EOF
Waits on #$brainstorm (sections 3 and 4).

- Moves are defined as data, following the decided design (proposed: \`.tres\` resources with frames, hitboxes and cancel windows).
- One character has a three-hit ground combo built entirely from data.
- A debug overlay, on a key, shows hitboxes, hurtboxes and each move's frame counter.

**Done when:** someone who doesn't code can change a move's timing or hitbox in the editor and see the difference in game.
EOF

issue "Hits that feel good" "code,design" "Milestone 1" <<EOF
Waits on #$brainstorm (section 7).

- A training dummy that takes hits: hitstop, hitstun, knockback, white flash, screen shake on heavy hits, knockdown and getting up.
- A combo counter.
- Every value can be tuned in the editor.

**Done when:** the team plays it at a weekly meeting and agrees the hits feel solid.
EOF

issue "Milestone 1 build" "code" "Milestone 1" <<'EOF'
Suggested owner: Ben.

- Export for Windows, macOS and Linux.
- Publish it as a pre-release on GitHub, with a short list of what to try.

**Done when:** T and E have played it and opened issues for what they'd change.
EOF

# ---------------------------------------------------------------- Milestone 2

issue "Port the PixelLab art pipeline" "art,code" "Milestone 2" <<'EOF'
Suggested owner: Ben.

`beben-games/2d-game` has a working PixelLab pipeline in `tools/art/` (REST client, job files, budget check, palette enforcement, sheets, previews), with its rules in `docs/ART.md`. Ben's tier 2 subscription (5,000 generations a period) is shared between that project and this one.

- Port `tools/art/` and the parts of `docs/ART.md` that apply here.
- The API key stays in the macOS keychain or an environment variable. Nothing secret enters this repository.
- Split the generation budget between the two projects.
- Propose how this fits with the PixelLab MCP rule in `CLAUDE.md`, for the weekly meeting.
- First use: a style probe at the proposed sprite size (about 26 by 38 pixels), so the team can judge the size on real images.

**Done when:** `tools/art/budget.py` reports the balance from this repository, and the style probe is posted in this issue.
EOF

echo "Done." >&2
