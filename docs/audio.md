# Audio: the sounds and music the game needs

The list for E, who makes the game's sound, and for E's Claude. Every entry is a thing the game already does or will do in the first release, with what the sound has to say. **Status: proposed** (Ben's Claude, 2026-10-18, from Ben's request). The team changes it at a meeting; E adds, drops and renames freely.

Read `docs/game-bible.md` ("Look and sound") first. Decided there: the music is energetic orchestral and gothic, in the direction of Castlevania and The Witcher, and AI tools are welcome for music. The setting is the Hundred Years' War with magic, dragons, English elves and some steampunk, at a tone of 3 to 5 out of 10, so the sound can be grand and a little grim without being solemn.

## How it works today

Every cue is a short OGG in `assets/sfx/`, played by `systems/audio/sounds.gd` from one pool of players. The cue table there (`Sounds.CUES`) maps a name to a file, a volume and how far its pitch wanders each time; replacing a sound is replacing the file, or adding a row and a call. Today's ten cues and the loop are synthesized placeholders from `tools/audio/make_placeholders.py` (`docs/design/2026-10-18-placeholder-sound.md`). F9 mutes.

## How to deliver

- **Formats:** OGG Vorbis in the repository (`CLAUDE.md`, Assets), 44.1 kHz, mono for cues and stereo for music. Cues short and trimmed to the attack, with no silence at the start; music loops that join seamlessly at the loop point, or with a separate intro.
- **Sources** (WAV masters, stems, project files) go in the team's shared Drive folder, linked from the issue, never in the repository.
- **Licences:** anything not made by the team must be CC0 or CC BY and get a row in `CREDITS.md`; check that a tool's terms allow redistribution before using it. Nothing from other games.
- **Loudness:** cues peak around -6 dB and the music sits under them; the mix is tuned in `Sounds.CUES`, so deliver at a sensible level and the game sets the balance.
- **Variations:** where a sound plays often (hits, swings, deaths), two or three takes stop it from grating; the player picks one at random and wanders the pitch a little.
- Propose a set as a comment on the issue with the files in Drive; Ben assigns the issue and the files come in by pull request, named as the cue table names them.

## Sound effects

Names in `code` are today's cue names; the rest are new cues to add.

### The knight (the player, a tank)

| Cue | What it says |
|---|---|
| `swing` (two or three takes) | A light sword swing: quick, dry, a blade through air. |
| heavy swing | The launcher: heavier, slower, more wind-up. |
| running attack | The lunge out of a dash: a swing with a step in it. |
| `hit` (two or three takes) | A light hit landing on flesh and leather: a thud with a little edge. |
| `hit_heavy` | A launcher landing: deeper, with crunch; the thing that makes a juggle feel earned. |
| `block` | A shield or blade taking a hit: a clang, short, bright. |
| `guard_break` | The guard breaking: a shatter and a low thump, the worst thing that can happen to a tank. |
| guard raise, guard lower | Small: the shield coming up and going down, so holding the guard reads in sound. |
| taunt | While the knight holds its guard, the crowd is drawn to it: a low hum or a magnetic drone that rises while the guard is held, to go with the attracting-force animation Ben wants (issue #72). |
| `dash` | The dash's start: a whoosh with a footfall. |
| run (loop or steps) | Footfalls while the dash is held into a run. |
| lane hop | The hop between lanes: a short jump and a landing. |
| jump, land | The full jump and its landing, heavier than the hop. |
| hurt (two takes) | A grunt on taking a hit. |
| knockdown, get up | Hitting the ground, and rising. |
| death | Going down for good. |
| `fireball` cast, fireball loop, fireball impact | The light fireball: a flash of fire leaving the hand, a crackle while it flies, a burst on landing. |
| heavy fireball | The same family, bigger and lower: twice as big and twice as hard in the game. |
| missiles launch, missile loop, missile impact | The homing missiles: a release, a whistle or hiss while they turn, a crack on landing; three at once for the heavy version. |
| blast | The every-lane burst around the knight: a ring of force, with a bigger version for the heavy. |
| super: charge, release, impact | The super fireball: a build-up during the long motion, a huge release, and an impact that goes through everyone. |
| mana full | A chime when the bar fills, once. |
| no mana | A dull click when a heavy spell falls back to its light version (the bar flashes red). |

### Small fry

| Cue | What it says |
|---|---|
| enemy swing | A club swing, rougher than the knight's. |
| enemy jab hit | Their jab landing on the knight: lighter than the knight's hits. |
| enemy hurt (two takes) | A grunt on taking a hit. |
| `death` (three takes) | A death cry; with dozens of enemies this plays constantly, so it must be short and varied. |
| fast one: knife swish | The quick weak one's knife, a flick. |
| shield: block, crack, break | The shielded one's shield taking a hit, cracking, and breaking into planks. |
| shield bash: wind-up, impact | The telegraphed bash: a rising wind-up during the 36-tick tell (the red mark), then a heavy slam that breaks a guard. The wind-up is the sound the player learns to dodge on. |
| thrower: throw, rock whoosh, rock impact | The rock leaving the sling, flying, and landing. |
| crowd arriving | A war cry or a murmur when a wave comes in from off screen, so the player hears it before seeing it. |

### The world and the level

| Cue | What it says |
|---|---|
| `barrel` crack, `barrel` break | A barrel taking a hit, then breaking into planks. |
| `pickup` | A potion taken: a small bright swallow or chime. |
| wave incoming | A horn or a drum hit as a wave is sent, with the crowd arriving above it. |
| arena clear, GO | A sting when an arena's last wave falls, and a cue for the GO arrow. |
| level clear | A short fanfare for the results screen. |
| down | A sting when the last player goes down. |
| camera lock | Optional: a subtle thump when an arena locks the camera. |

### Menus

| Cue | What it says |
|---|---|
| menu move, menu confirm, menu back | The main menu and the pause menu. |
| pause, unpause | Tab in a fight. |
| player joins | A pad joining in co-op: a short welcome. |

## Music

Loops of two to three minutes with a seamless join, or an intro plus a loop. Orchestral and gothic with energy: brass, low strings, choir and drums, with period colour (fiddle, shawm, drums) and a little steampunk clank where the setting asks for it.

| Track | What it says |
|---|---|
| Main menu | The theme at rest: the setting in a minute, grand and a little grim, so the game's tone is clear before a fight. |
| Level 1, "The camp" | The first level (`data/levels/melee.tres`): an English camp in France under attack. Driving, for a crowd fight; it must bear ten minutes of play. Optional: a quieter layer between arenas, when the player walks on. |
| Boss fight | A 1v1 under a fighting-game camera (issues #66 and #67): intense, with a second phase in it if the boss has one. |
| Level clear | A short victory jingle, ten seconds, for the results screen. |
| Down | A short defeat jingle. |
| Later levels and bosses | One track per level and per boss as they come; the plan has one of each for the first release's vertical slices. |

## Ambience (later)

A bed under the music per level, quiet: camp at night, a battlefield, a town. Not for the first pass.
