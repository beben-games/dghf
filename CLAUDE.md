# Project guide for Claude

Three friends (Ben, T and E) are building this game in their spare time, each with their own Claude. This file is the set of rules every one of those Claudes follows, so the work fits together. Keep it short and current: when the team changes a rule, change it here.

## The game

A 2D side-scrolling beat 'em up with fighting-game controls. The player fights huge crowds of enemies and chains spells into combos. Three playable characters, solo or local co-op. Setting: the Hundred Years' War with magic, dragons, English elves and some steampunk. Free and open source.

Read `docs/game-bible.md` before any design, story, level or art work, and `docs/architecture.md` before any code. Both mark each point as Decided, Proposed or Open.

## Decided, proposed and open

The docs in this repository are starting points, not a specification. Treat each point by its marker:

- **Decided:** the team agreed on it, and the marker gives the date or meeting. Build on it. If you think it's wrong, say so and explain why, rather than quietly working around it.
- **Proposed:** a suggestion, often written by Claude before the team discussed it. All of `docs/architecture.md` starts this way. When brainstorming or designing, question it: ask the person what they think, offer alternatives, and point out where it doesn't fit what they want. Never present a proposal as a requirement.
- **Open:** an unanswered question. Don't answer it yourself: ask the person, or note that it needs the team.
- Anything without a marker counts as proposed.

When a brainstorm settles something:

1. Write the design spec in `docs/design/YYYY-MM-DD-<topic>.md`.
2. Change the point's marker in the source doc to **Decided** with the date, and link the spec.
3. Decisions that change what the team agreed together go to the next weekly meeting before they count as decided. Say so to the person.

## Before you start a task

1. Work from a GitHub issue. If there is none, ask the person you're working with whether to create one.
2. Read the issue, `docs/game-bible.md`, and the most recent file in `docs/meetings/`. Decisions from the last meeting override older ones.
3. Assign the issue to the person you're working with, make sure it has its area label (`code`, `art`, `audio`, `writing`, `design` or `level-design`) and a milestone, and move it to **In progress** on the project board.

## Git

- Never push to `main`. Work on a branch named `<type>/<issue number>-<short-name>`, for example `code/12-player-movement` or `art/18-knight-idle`.
- Open a pull request whose description says `Closes #<issue number>`.
- Ben owns the build. He (or his Claude) merges pull requests into `main`, and `main` must always open and run in Godot.
- Keep pull requests small: one issue each.

## Secrets

- Never commit tokens, API keys or `.env` files. This repository is public.
- The PixelLab MCP server is configured in each person's own user-level Claude settings, never in a `.mcp.json` in this repository, so each person uses their own PixelLab account.
- Never commit meeting recordings or raw transcripts. Only the written notes in `docs/meetings/` go in the repository.

## Godot

- Engine: Godot 4, version pinned in `project.godot`. Everyone uses that exact version.
- GDScript with static typing (`var speed: float = 200.0`).
- File and folder names in `snake_case`. One scene per folder when a scene has its own scripts or assets.
- Folder layout (the code folders are proposed in `docs/architecture.md`, section 10, until decided):
  - `scenes/` for scenes and their scripts (`scenes/fighter/`, `scenes/player/`, `scenes/enemies/`, `scenes/levels/`)
  - `systems/` for code shared by many scenes (combat, input, camera, enemies)
  - `data/` for game data such as moves (`data/moves/<character>/`)
  - `assets/sprites/<character or enemy>/`, `assets/tiles/`, `assets/ui/`
  - `assets/music/`, `assets/sfx/`
- **Crowds.** The core of the game is dozens of enemies on screen at once. Keep enemies cheap: pool them instead of creating and freeing them, avoid a node per bullet or effect where a shared system can do it, and check the frame rate with a large crowd before calling an enemy feature done.
- **Co-op.** Every input goes through a player index (player 1, 2 or 3) from day one, never straight to a single device. The camera follows all active players.

## Assets

- **Licences.** This repository is public, so committing a file publishes it. Only add assets released as CC0 or CC BY, or made by the team. Never add "free to use" assets whose licence forbids redistribution, and never sprites, music or sounds taken from other games. If the licence isn't clear, don't add it: ask.
- Record every asset the team didn't make in `CREDITS.md`: what it is, the author, the source link and the licence.
- Placeholder art comes from CC0 packs until the team replaces it.
- Final art is pixel art made with PixelLab. Before generating, check the style and size rules in `docs/game-bible.md` so every sprite matches.
- Commit only game-ready files: PNG for sprites and tiles, OGG for music and sound effects. Keep source files (WAV masters, stems, project files) in the team's shared Drive folder and link them from the issue.
- Name sprites `<subject>_<action>.png`, for example `knight_attack.png`, and sprite sheets the same way.
- Character sprite sheets follow `docs/skins.md` (proposed): every frame on the same canvas with the feet at the same pixel, exported without cropping.
- Note in the pull request which tool made each asset and with what prompt, so it can be regenerated.

## Writing

- Story, dialogue and lore are written by the team. Help with structure, consistency and editing, but don't write story text unless the person asks for a draft, and label drafts as drafts.
- Code, issues, pull requests and docs are in English.

## After a task

- If the work showed that something in `docs/game-bible.md` or `docs/architecture.md` doesn't hold up, say so and propose the change. Don't mark anything **Decided** on your own: that takes the person's agreement, and the team's for anything they agreed together.
- Move the issue to **In review** and ask the person to request Ben's review.
