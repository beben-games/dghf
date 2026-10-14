# Untitled beat 'em up

A 2D side-scrolling beat 'em up set in a Hundred Years' War with magic: huge crowds of enemies, spell combos, three playable characters, solo or local co-op. Made in Godot by Ben, T and E.

- `docs/STATUS.md`: where the project stands right now
- `docs/game-bible.md`: what the game is, and the decisions so far
- `docs/art.md`: how the team makes visual assets, and the pipeline tools in `tools/art/`
- `docs/meetings/`: notes from the weekly meetings
- `CLAUDE.md`: the rules every contributor's Claude follows

## Try it

What there is to play today, in about fifteen minutes. If you work with Claude, ask it to "show me around the game": it follows the same tour from `docs/STATUS.md` and runs the commands for you.

1. **Run the game:** `scripts/run.sh`. A menu offers two fights: **Boss fight** (the big red dummy fights back, with the lanes closer) and **Melee** (ten small fry at a time, endlessly). Pick with up, down and Enter. Without a skin your character is a plain blue figure: that is expected. In a fight, Tab opens the pause menu, which lists every control and key below.
2. **Move around:** walk, jump, crouch, and change lane with Q and E. The controls are in the table below.
3. **Hit the dummy:** light (J), heavy (L), and a fireball from a distance. Press F1 to see the hitboxes.
4. **Do the combo:** stand next to the dummy and press J, J, L, each press after the hit before lands. As the L lands, hold W to jump after the dummy, then press J and L in the air. That is five hits.
5. **Look inside a move:** `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`. Step through a move with the left and right arrows, and change move with up and down.
6. **Change a move yourself:** see "Tuning a move without code" below.
7. **Fight it:** press F5 and the dummy walks up, attacks and sometimes guards. Guard (hold K) and dodge (Shift) against it.
8. **Fight a crowd:** press F6 a few times for ten small fry at a time (up to 48). They surround you and jab; you have a health bar now, and R starts over when you go down.
9. **Say what you think:** which parts felt good and which felt off. Comment on the issue for that part (the list is in `docs/STATUS.md`), or tell Ben.

## Tuning a move without code

1. Start the move preview tool (step 5 above) and leave it running.
2. Open the project in the Godot editor. In the FileSystem panel, open `data/moves/poc/` and double-click a move, for example `light.tres`. Its values appear in the Inspector.
3. Change a number and press Ctrl+S (Cmd+S on a Mac). The preview tool shows the new version within half a second.
4. To play the change, close the game and run it again: the game reads the moves when it starts.

What the numbers mean:

- **Total Frames:** how long the move lasts. One frame is one sixtieth of a second.
- **Hit Boxes:** each has the frames it is out on (First Frame to Last Frame), its rectangle measured from the character's feet (up is negative), and what it does: Damage, Hitstun (how long the target is stuck), Hitstop (the freeze when it lands), Knockback (the push), Launch (above 0 sends the target into the air) and Shake (screen shake).
- **Cancels:** the frames during which the move can be cut short by another one, and by which. This is what makes combos.

Your changes stay on your machine until you commit them. To throw them away, run `git checkout -- data/moves/poc`. To keep them, work from an issue on a branch as usual.

## Running and building

- `scripts/run.sh` runs the game from the project, without opening the editor.
- `scripts/build.sh` builds Windows x64 and Linux x64 zips into `builds/`. It needs the Godot 4.7.2 export templates. With `--skin <folder>` it adds a character skin beside the executable, for playtesting art that is not in the repository: those zips are named `-private` and are not for publishing.

To tune a move without code, run `scripts/run.sh res://scenes/tools/move_preview/move_preview.tscn`: it shows a move frame by frame with its hitboxes, and reloads it when you save the move file in the editor.

Both are Bash scripts (on Windows, use Git Bash) and need Godot 4.7.2 on the `PATH` as `godot`, or its path in `GODOT_BIN`.

## Controls

The game is a sandbox for now: one character against the big dummy or a crowd of small fry on an empty stage. These controls are being tried out and are not final. Tab shows them all in the game.

| Action | Keyboard | Gamepad |
|---|---|---|
| Walk | A, D or the left and right arrows | Stick or d-pad |
| Jump | W, Space or the up arrow | Up, or A |
| Crouch | S or the down arrow | Down |
| Change lane | Q (back), E (front) | Left and right shoulder |
| Light attack | J | X |
| Heavy attack (launches) | L | Y |
| Air attacks | J or L during a jump | X or Y during a jump |
| Guard | Hold K | Hold B |
| Dodge | Shift, with a direction held, or alone for a step back | Right trigger |
| Fireball | Down, down-forward, forward, then J (light) or L (heavy: twice as big, twice as hard, needs a cleaner motion) | The same with X or Y |
| Homing missiles, across lanes | Forward, down, down-forward, then J (one) or L (three, bigger) | The same |
| Blast around you, every lane | Down, down-back, back, then J or L (bigger, launches) | The same |
| Super fireball | The fireball motion twice, then L: huge, and goes through everyone | The same |
| Combo | Light, light, heavy: each press after the hit before lands. Then hold up to jump after the target, and light, heavy in the air | The same |
| Pause menu, with every control and key | Tab (Esc closes it) | |
| Back to the main menu, from the pause menu | M | |
| Show hitboxes and hurtboxes | F1 | |
| Try another lane spacing and depth (fighters smaller further back) | F2 | |
| Shade the back lanes | F3 | |
| The dummy guards | F4 | |
| The dummy fights back | F5 | |
| Ten more small-fry enemies | F6 | |
| Start over (after going down, or any time) | R | |

## Contributing

1. Pick an issue on the project board, or open one from a template.
2. Work on a branch named `<type>/<issue number>-<short-name>`.
3. Open a pull request that says `Closes #<issue number>`. Ben reviews and merges.

## Licence

Not chosen yet: the team is deciding between MIT and GPL. Until a `LICENSE` file is added, the code is public but not legally open source.
