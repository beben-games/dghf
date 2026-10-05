# Untitled beat 'em up

A 2D side-scrolling beat 'em up set in a Hundred Years' War with magic: huge crowds of enemies, spell combos, three playable characters, solo or local co-op. Made in Godot by Ben, T and E.

- `docs/STATUS.md`: where the project stands right now
- `docs/game-bible.md`: what the game is, and the decisions so far
- `docs/meetings/`: notes from the weekly meetings
- `CLAUDE.md`: the rules every contributor's Claude follows

## Running and building

- `scripts/run.sh` runs the game from the project, without opening the editor.
- `scripts/build.sh` builds Windows x64 and Linux x64 zips into `builds/`. It needs the Godot 4.7.2 export templates.

Both are Bash scripts (on Windows, use Git Bash) and need Godot 4.7.2 on the `PATH` as `godot`, or its path in `GODOT_BIN`.

## Controls

The game is a proof of concept for now: one character and a training dummy on an empty stage. These controls are being tried out and are not final.

| Action | Keyboard | Gamepad |
|---|---|---|
| Walk | A, D or the left and right arrows | Stick or d-pad |
| Jump | W, K, Space or the up arrow | Up, or B |
| Crouch | S or the down arrow | Down |
| Change lane | Q (back), E (front) | Left and right shoulder |
| Light attack | J | X |
| Heavy attack (launches) | L | Y |
| Air attacks | J or L during a jump | X or Y during a jump |
| Fireball | Down, down-forward, forward, then light attack | The same |
| Show hitboxes and hurtboxes | F1 | |

## Contributing

1. Pick an issue on the project board, or open one from a template.
2. Work on a branch named `<type>/<issue number>-<short-name>`.
3. Open a pull request that says `Closes #<issue number>`. Ben reviews and merges.

## Licence

Not chosen yet: the team is deciding between MIT and GPL. Until a `LICENSE` file is added, the code is public but not legally open source.
