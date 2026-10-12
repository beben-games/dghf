# Making art for the game

How the team makes visual assets: characters, floors, backgrounds, props, destructible items and pickups. For T and E, and for their Claudes. **Status: proposed** (Ben's Claude, 2026-10-11, from Ben's direction on issue #11). The team changes it at a meeting.

Read `docs/game-bible.md` ("Look and sound") first. Two things there are decided: the final art is pixel art, and the team makes it with AI tools. Two are not: the sprite size and the screen resolution, which the weekly meeting settles with the probe described at the end of this page. Until then, make placeholders and probes, not final sets.

## The rules that always hold

- **What goes in the repository is finished, game-ready and publishable.** PNG only, under `assets/`. Generated candidates, working files and contact sheets stay on your machine (`art/raw/`, `art/work/` and `reports/` are git-ignored).
- **Every asset says how it was made.** The pull request names the tool, the prompt, and any reference image it was steered with, so it can be regenerated. An asset the team didn't make goes in `CREDITS.md` with its licence (CC0 or CC BY only).
- **The tool's terms must allow redistribution.** PixelLab's do for a subscriber's own generations. Before using another generator, check that its terms let us publish the output in a free, open-source game, and write the answer in the pull request. Nothing ripped from another game, ever.
- **The team judges the look, not Claude.** Claude writes prompts, runs tools, lays candidates side by side and points out faults it can name (wrong size, cut off, off the palette). The person picks.
- **Tools are open.** PixelLab is the default for sprites and tiles. For what it does badly (large painted backgrounds, parallax layers), anything with acceptable terms can be tried: Leonardo.ai, a diffusion model, Aseprite by hand, or code (Godot shaders and particles for effects). Compare on one small piece before committing to a tool for a whole set.

## Who does what

- **Everyone may generate with their own stack** (Ben, 2026-10-11): PixelLab through the MCP server in your own Claude settings, or any other tool with acceptable terms, with your own account and keys. What makes it one game is the art direction on this page and in the game bible, the style sentence, the sizes, and the palette once there is one. Keys stay in your own settings or keychain, never in the repository (`CLAUDE.md`, Secrets).
- **Ben's PixelLab account and the pipeline in `tools/art/`** are there for anyone who has no account: ask on an issue and Ben's session runs it. The pipeline is also the record for production sets: every call logged, every reference approved.
- **Budget.** Spending grows with the project, staggered over months. `tools/art/budget.py` paces Ben's account; a concept still gets a budget range before anything is generated for it, so a whole set is not spent on a look nobody has approved.

## What each kind of asset needs

Sizes are given for both candidate resolutions. Pick the column once the meeting has decided; until then, probes at both.

| Kind | At 1080p native | At 960 by 540, scaled 2x | Notes |
|---|---|---|---|
| Playable character, boss | about 200 px tall on a 256 canvas | about 110 px tall on a 128 canvas | Side view. Animations: idle, walk, jump, land, crouch, hurt, launched, knockdown, getup, one per move (`docs/skins.md`). The first three come from templates; attacks are custom. |
| Crowd enemy | about 180 px | about 100 px | Fewer animations: idle, walk, one attack, hurt, death. Recolours give variety for free. |
| Floor | tiles of 128 px | tiles of 64 px | Three lanes in perspective: the floor art narrows toward the back. Two or three ground types per level, plus edges. |
| Background | parallax layers, each the stage's width or more, 1920 by 1080 | 960 by 540 | Two to four layers: sky, far, mid, near. The one kind PixelLab may not do well: try a painted generator and pixelate, or hand-make. |
| Prop, destructible | 128 to 256 px | 64 to 128 px | Three states: whole, damaged, broken, plus debris pieces. One object call per state, or one call and the damage painted. |
| Pickup, power-up | 64 px | 32 px | A still plus a 4-frame bob or spin. Readable at a glance against the floor. |
| Effects | any | any | Code first: Godot particles and shaders (the hit flash and sparks already are). Generated only if code can't. |
| UI | 1080p | 1080p | Not pixel art necessarily; decided later. |

**The art direction is Ben's knight** (`art/refs/user/knight_idle_frame.png`, made in PixelLab's web character creator on a 256 canvas, about 227 pixels tall, realistic proportions, a three-quarter side view, steel with cool highlights and a dark outline). It is the approved reference in `art/refs/refs.json`: every character is generated to match it in size, proportions and rendering, and compared beside it before it is accepted.

Style rules for everything: one light direction (top left), one outline rule, one palette once the team has approved one (`tools/art/palette.py` measures how well an image fits a palette and can extract one from approved images). Write the same style sentence into every prompt.

## Making a character: one workflow

A character is one piece of work, not art plus code plus story done apart. In order:

1. **Concept.** Who they are (one paragraph of backstory, from the team's writing), how they fight in one sentence, their signature spell, and their role: playable from the start, or a boss first and unlocked when beaten (#33). Silhouette and colour notes. Approved on an issue with a budget range.
2. **Gameplay on paper.** Their move list: each move's button and motion, startup, active and recovery frames, damage and reactions, cancels. Written as the move data format in `docs/architecture.md`, section 3.
3. **Moves as data.** The `.tres` files in `data/moves/<character>/`, playable with the plain figure. Tuned in the move preview tool before any art exists, so timing is settled on the figure.
4. **Visuals.** The character generated at the chosen size: a still first, approved, then animations one at a time from that still, each checked in the preview tool against its move's frames. The sheet and `skin.json` follow `docs/skins.md`.
5. **Balance and feel.** Played against the dummy, then in a crowd. Numbers tuned in the inspector.
6. **Boss and unlock.** If they appear as a boss, the same data drives them under AI. Unlocking makes the same character playable: nothing is built twice.

The first character to go through all six steps sets the template for the other two.

## The pipeline tools

Ported from `beben-games/2d-game` (`tools/art/`). Python 3 with Pillow. The PixelLab key is in the macOS keychain or `PIXELLAB_API_KEY`; nothing secret enters the repository, and `tools/hooks/pre-commit` (enable it once with `git config core.hooksPath tools/hooks`) refuses a commit that contains the key.

| Tool | What it does |
|---|---|
| `tools/art/pixellab.py balance` | The plan and the generations left. |
| `tools/art/budget.py` | What a session may spend of this project's share, paced over the period (`art/budget.json`). |
| `tools/art/gen.py plan` / `run art/jobs/<batch>.json` | Runs a batch of PixelLab calls from a job file within the allowance, saves outputs under `art/raw/<concept>/<id>/`, keeps a ledger. Reference images must be listed and approved in `art/refs/refs.json`. |
| `tools/art/sheet.py <concept>` | A contact sheet of a concept's outputs, every candidate side by side, for the person to judge. |
| `tools/art/preview.py <concept>` | Animated GIFs of a concept's animations. |
| `tools/art/palette.py fit` / `extract` / `extend` | How well images hold to a palette; a palette drawn from approved images. |

A job file names the concept, and each call's endpoint, body and estimate. Claude writes them; the person approves the concept and its range.

**How this fits the MCP rule in `CLAUDE.md`:** the MCP server in each person's own settings, with their own account, is the normal way to generate; the pipeline is the same thing with a record, for Ben's account and for production sets. Both follow this page.

**What the API does and costs, measured on 2026-10-11** (`art/ledger.jsonl` has every call):

- `create-character-v3` at 256: 8 rotations of a character about 240 pixels tall for 9 generations. The path that matches Ben's knight; `view: "low top-down"` gives the three-quarter angle, `"side"` a flat profile. The character id it returns is what animations are made from.
- `create-character-pro`: capped at 168 pixels (about 140 tall), 25 generations, and a stockier, bigger-headed look at that size. Not the path for this game's characters.
- Every character endpoint returns 8 rotations; there is no way to ask for one. A side-scroller uses `east` (and `west` by flipping, or `south-east` for a three-quarter look). Animations are made for one direction only.
- `animate-character` with a template (`walking-8-frames`, `running-8-frames`, `jumping-1`, `falling-back-death`, `getting-up`, `taking-punch`, `cross-punch`, `roundhouse-kick` and the rest of the mannequin's list in the API's error message when an id is wrong): 1 generation a direction, 8 frames, good walks at 128 and 168. There is no sword template: attacks are custom.
- `animate-character` with `mode: "pro"` and an `action_description`: 15 to 20 generations a direction, but only 4 frames at 128 and above. A sword slash reads, with a slash arc at 168, but 4 frames is thin for a move that lasts 30 ticks.
- `animate-character` with `mode: "pixminimax"`, an `action_description` and a `subject_description`: **12 frames of a two-handed overhead slash at 256 for 2 generations** (`art/jobs/probe3_slash.json`, `docs/probes/2026-10-11-size-probe/round3_slash_pixminimax.gif`). Raise, swing, step, recover, all readable; one frame bends the blade. This is the path for attacks and every other custom animation: up to 40 frames, a multiple of 4, cheap enough to reroll.
- `generate-with-style-v2` with Ben's knight as the style image: one 256 image for 10 generations, and the closest match of the probe (the same pose, size and rendering, with the surcoat). The way to make a character's first still. It is an image, not a character: to animate it, make a character from it (`create-character-v3` with it as `reference_image`, untried) or animate the still directly (`animate-with-text-v2`, 4 frames at this size).
- The sprite-size probe's results are in `docs/probes/2026-10-11-size-probe/` and on issue #11.

**How this fits the MCP rule in `CLAUDE.md`:** the MCP server in each person's own settings, with their own account, is the normal way to generate; the pipeline is the same thing with a record, for Ben's account and for production sets. Both follow this page.

## The sprite-size probe (run on 2026-10-11)

A French man-at-arms of about 1430 at three sizes, with a template walk and a custom sword attack at the two smaller ones. Job files: `art/jobs/probe_sizes.json` (128 and 168, the Pro creator) and `art/jobs/probe2_style.json` (256, v3, in the look of Ben's knight). Images: `docs/probes/2026-10-11-size-probe/`. Ben's verdict on round one: wrong direction and wrong size; the 256 v3 character beside his knight is the candidate for the meeting, shown on a 1080p stage mock-up with the depth presets.
