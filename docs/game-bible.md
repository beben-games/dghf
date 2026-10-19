# Game bible

What the game is. Each point is marked **Decided** (the team agreed, with the date), **Proposed** (a suggestion to discuss) or **Open** (a question nobody has answered). See `CLAUDE.md` for how to treat each. When the team changes something, update the marker and note the meeting it came from.

Working title: **Open.**

## Core

- **Decided (2026-09-27 questionnaire).** 2D side-scrolling beat 'em up with fighting-game controls.
- **Decided (2026-09-27).** The core of the first release: fighting huge crowds of enemies, and chaining spells into combos.
- **Decided (2026-09-27).** Later versions, not the first release: RPG progression, branching story, lanes and team synergy.
- **Decided (2026-09-27).** References: Guardian Heroes (all three), Dragon Force, Marvel vs Capcom, Dynasty Warriors, Heroes of Hammerwatch II. It must not feel as rigid as Double Dragon.

## Players

- **Decided (2026-09-27).** 3 playable characters in the first release.
- **Open.** Who the three characters are, how each fights, and their signature spells.
- **Proposed (Ben, 2026-10-17).** The characters differ as classes through their bars as much as their moves: a tank has a much bigger guard bar and its guard taunts (the crowd nearby comes to its lane and piles on it), to keep a swarm or a boss busy while the rest of the team blasts. The guard bar is built (`docs/design/2026-10-17-guard-bar.md`); which classes the three are goes with the question above.
- **Proposed (Ben, 2026-10-18).** Boss fights feel like a fighting game, but asymmetric: the boss is much stronger than any one character, like the final bosses of Marvel vs Capcom, and all three characters are needed to beat it. Not best-of-three rounds. **Open:** how the three take part (tag team, 3v1 or another mechanism), issue #90, for the meeting.
- **Decided (2026-09-27).** Solo and local co-op in the first release. Online play is out of scope.
- **Open (Ben, 2026-10-18, after playing the melee alone).** Since solo is in, every character must be fun alone. The knight's tank kit (a guard that taunts) is a team kit and gives a solo player no crowd control: does the knight get a clearing tool of its own, or is the caster the next character and the knight the co-op anchor? Issue #98, for the meeting with the question above.
- **Proposed.** For remote sessions, the team streams one machine's game, for example with Parsec.

## Setting and tone

- **Decided (2026-09-27).** The Hundred Years' War with magic, plus dragons, English elves and some steampunk.
- **Decided (2026-09-27).** Tone: 3 to 5 out of 10, where 1 is dead serious and 10 is pure parody.

## Story

- **Proposed.** Jeanne d'Arc is held by the English in Rouen and sentenced to burn. The player fights across English-held France to reach Rouen, burns the city, defeats the final boss and saves her from the stake. The last act, or a sequel, is the counter-invasion of Great Britain. Claude drafted this by combining the three answers to "what is the player trying to achieve". Ben and T want to work on story and may rewrite it entirely.

## Look and sound

- **Decided (2026-09-27).** Final art is pixel art made with PixelLab, at the best quality it can produce.
- **Proposed.** Placeholder art from CC0 packs until then (see `CREDITS.md`).
- **Proposed (Ben, 2026-10-03).** Character sprites about 26 by 38 pixels, the size of LuizMelo's [Medieval Warrior Pack 3](https://luizmelo.itch.io/medieval-warrior-pack-3). T prefers larger sprites, so this is in round three of the questionnaire.
- **Open.** Palette, and the game's internal resolution (`docs/architecture.md` proposes 480 by 270).
- **Decided (2026-09-27).** Music: energetic orchestral and gothic, in the direction of Castlevania and The Witcher.
- **Decided (2026-09-27).** No voice-over.

## AI use

- **Decided (2026-09-27).** Yes for code, and as a tool for art and music.
- **Decided (2026-09-27).** No AI voices.
- **Decided (2026-09-27).** Story written by the team, with AI only assisting.

## Tools

- **Decided (2026-10-03, Ben as build owner).** Godot 4.7.2 stable. See `docs/design/2026-10-03-setup.md`.
- **Proposed.** Ben's PixelLab tier 2 subscription generates the team's assets, with the art pipeline ported from `beben-games/2d-game`.

## Release

- **Decided (2026-09-27).** Standalone, free, code open source on GitHub.
- **Open.** Store: itch.io, Steam, or itch.io first and Steam later.
- **Open.** Code licence: MIT or GPL.

## Out of scope

- **Decided (2026-09-27).** Online play, voice-over, 3D.

## Milestones

- **Proposed.** Each milestone takes two to four weeks and ends with something playable:
  1. **Setup:** repository, Godot project, project board, this file and `CLAUDE.md`. Spec: `docs/design/2026-10-03-setup.md`.
  2. **Milestone 1:** one character on an empty stage, moving and attacking, one punchable enemy, placeholder art. Includes a crowd stress test to choose how enemies are built.
  3. **Milestone 2:** the horde: dozens of simple enemies at once, and a first spell combo. Built as the melee slice (`docs/plans/2026-10-17-vertical-slices.md`); Ben's review of 2026-10-18 found the crowd-into-spells loop under-built, so the milestone ends with the core-loop feel pass of `docs/plans/2026-10-18-core-loop-feel-pass.md`.
  4. **Milestone 3:** three characters and local co-op with a shared camera.
  5. **Milestone 4:** one complete level with PixelLab art and music, released.
