# Character sprites: sheets, skins and anchoring

**Status: Proposed.** These are the rules the proof of concept (`docs/design/2026-10-04-poc-1080p-player.md`) works by. They came out of fixing a placeholder whose frames had no anchor points. Follow them for new character art until the team changes them.

A character's art is a **skin**: one sprite sheet and a `skin.json` that names its animations. The file format is in the proof-of-concept spec, section "Skins". This page is about how to draw or prepare the frames so they sit right in the game.

## The feet point

The game knows one point per fighter: the **feet point**, on the ground between the feet. Every frame of the sheet is drawn so that one fixed pixel of its cell lands on that point. That pixel is `feet` in `skin.json`.

If the feet point drifts from frame to frame, the character slides, hops or pops when an animation plays or when one animation gives way to another. Press F1 in the game to see the feet point as a yellow dot.

## The rule for new art: draw on a fixed canvas

**Draw every frame of a character on the same canvas size, with the feet point at the same pixel, and export the frames without cropping them.**

Then the sheet is the frames laid out in a grid, `cell` is the canvas size, `feet` is that pixel, and nothing has to be worked out afterwards. This is the whole rule for hand-drawn sprites and for PixelLab output: keep the canvas, don't trim.

Choose the canvas for the widest and tallest frame, not for the standing pose. A sword swing can be as wide as the character is tall.

## Where the feet point goes in each kind of frame

| Kind of frame | Where the feet point sits |
|---|---|
| Standing, walking, crouching | Under the chest, on the sole line. The feet take turns in a walk, so don't follow a foot: keep the upper body steady and let the legs move under it. |
| An attack or any move on the ground | The first frame matches the standing pose. After that, the foot that stays planted must not move on the canvas. The body lunges away from the feet point and comes back. |
| In the air | The feet point follows the body's centre, not the feet. When the legs tuck, the feet rise above the feet point and the body stays on its arc. The feet never go below the feet point. |
| Take-off and landing | Soles on the feet point, like a standing frame. |

The game adds the jump's height itself. Never draw height into the frames: an airborne frame sits at the same place on the canvas as a standing one.

## Loops

- A looping animation lists each frame of the cycle once. Don't repeat the first frame at the end: the game goes from the last frame back to the first.
- A walk cycle is two steps, left and right. If a loop hitches, the usual cause is a frame list that runs past the end of the cycle.
- Check the feet against the ground. If they skate, change the walk speed on the fighter or the walk's `ticks` in `skin.json`, not the drawing.

## Other rules

- **One facing.** Draw the character facing one way and say which in `faces`. The game mirrors it.
- **Effects are not part of the character.** A big slash arc or a fireball should be its own sprite, spawned by the move, so that it can be reused, sized and timed in the move's data. A small trail drawn into the frame is fine.
- **No half-transparent pixels and no anti-aliasing** against the background, so the edges stay hard at any scale.
- **Name animations** as the game asks for them: `idle`, `walk`, `crouch`, `jump`, and one per move, matching the move's `animation` field.

## Art that comes without anchors

Frames that arrive cropped, with no fixed canvas, have lost their feet point. It can be rebuilt, frame by frame, with the rules in the table above:

- **Standing, walking, crouching:** take x from the middle of the chest and shoulders (the rows from about 12% to 40% of the frame's height), and y from the sole of the lower shoe.
- **Moves on the ground:** place the first frame like a standing frame. Slide each later frame sideways until the pixels just above the ground match the frame before. That follows whichever foot is planted.
- **In the air:** take x and y from the centre of all the frame's pixels, shifted by the distance from that centre to the feet point in the standing pose. Then make sure the soles are not below the feet point.

This is slow, and it is a repair. It is the reason for the fixed-canvas rule.

## Checking a skin

1. Run the game and press F1. The yellow dot is the feet point: it should stay under the character through every animation.
2. Go from standing into each move and back. The body must not jump sideways on the first or the last frame.
3. Walk across the stage and watch a foot while it is on the ground. It should stay on the same spot of the floor.
4. Jump. The body should rise and fall in a smooth arc, with no dip at the top.
