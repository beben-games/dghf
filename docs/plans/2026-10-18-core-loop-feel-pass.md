# Plan: the core-loop feel pass

**Date:** 2026-10-18. **Written by:** Ben's Claude, from Ben's play of both vertical slices for issue #92 ("Find the fun") on 2026-10-18, with his reactions quoted on the issues they belong to. **Status: proposed.** Ben chose this plan over a new slice or a change of direction; the team can change it at the weekly meeting. Each step is an issue; a fresh session picks the first open one in order.

## What the review found

Both slices of `docs/plans/2026-10-17-vertical-slices.md` were played end to end by Ben, the only person who has played anything since Milestone 1.

**The shapes pass.** The boss fight is "the right size and feel", only too weak for now, as expected (#67). The level and its kinds are "nice" (#61, #62). The swing is "reactive enough, and feels OK fighting an army alone" (#80): the combat-feel change of 2026-10-17 took the Double Dragon rigidity out.

**The core loop does not pay off yet.** The game bible's decided core is fighting huge crowds and chaining spells into combos. Ben's reactions, and why the specs explain them:

| What Ben said | Why, in the build | Issue |
|---|---|---|
| "Too difficult and frustrating to get out once you're surrounded." | Since #75 the player is a wall, so the crowd packs both sides of it: three a side, three swinging at once, two more coming round. The ways out are a 200-pixel dash with ten invincible ticks and a lane hop, neither of which clears space; the guard covers the front only. Being surrounded is the melee's normal state, and nothing in the kit answers it. | #75, #94 |
| "Spells could be more powerful or at least wide, to clear up in a satisfying way." | The light blast does 12 against small fry with 30 health; the heavy blast does 24 and costs 40 mana, about two combos. The spell meant to clear a pile tickles it, and nothing carries a launched body into its neighbours (#63 waits on effects). | #60, #95, #63 |
| "Spells could be a little easier to cast." | The heavy motions must fit in 16 to 18 ticks, in a pile, where any hit taken drops the motion. Ben's written position since 2026-10-11 is spells on their own pad buttons; the motions came first for want of keys. | #60, #96 |
| "The casters flee too much and are hard to reach." | The thrower backs off whenever the player is within 320 pixels; the knight's light reaches 265. | #61, #97 |
| "Taunt is more of a multiplayer mechanic. As a solo player it's tough to do crowd control." | The knight is a tank built for a team. Solo is decided for the first release, so every character must be fun alone. | #72, #98 |

So the next work is a **feel pass on the core loop**: make being in the crowd survivable and make the spells the payoff. Not a new slice (the shapes are right) and not a change of direction (nothing decided is contradicted; the loop is under-built).

## The steps, in order

Sizes are in sessions, as in the vertical-slices plan: a day with Ben at the keyboard playing and steering. Ben's way of working holds: a step is built on a branch with a proposed spec and tests, Ben plays it there and says what feels off, the fix lands on the same pull request, then he asks for the merge.

| # | Step | Issue | Milestone | Size | Needs |
|---|---|---|---|---|---|
| 1 | **A way out of the pile that always works.** The light blast becomes the get-off-me move: free, out at once, launching everything around the player in every lane. If that isn't enough on its own, a cap on how long the crowd can chain a player, and invincible ticks on the lane hop. | #94 | 2 | 0.5 to 1 | nothing |
| 2 | **Spells that clear.** A heavy spell kills a plain small fry and launches the rest; a super clears the screen's lanes; mana retuned so a combo into a heavy spell is the loop. With it, the knock-ons and launches that carry neighbours from #63, which need none of Ben's effects. | #95 | 2 | 1 | 1 |
| 3 | **Spells on their own buttons**, motions kept as the alternative. Touches the button layout the team agreed on, so it goes to the meeting with the build to play. | #96 | 2 | 0.5 | nothing |
| 4 | **Throwers back off less, and the knight reaches them.** Numbers only. | #97 | 2 | 0.5 | nothing |

About three sessions. Steps 3 and 4 need nothing and can go first when Ben wants a quick win.

## What goes to the meeting, not into the plan

- **Every character must work solo** (#98): the knight gets a crowd-control tool of its own, or the caster is the next character and the knight stays the co-op anchor. With who the three characters are (#33) and the classes-through-bars idea.
- **Spells on buttons** (#96), once built: the layout is the team's decision (Ben and T agree in writing; E to confirm).
- **The spell economy** (#60) after step 2, with the new numbers.
- **The boss's strength** waits on the shape of boss fights (#90): tuning a 1v1 boss is wasted if the fight becomes 3v1.

## What the review did not do

- The sandbox test that would separate the kit from the crowd rules on being surrounded (place six, F5, try hop, dash, blast in turn). Step 1 starts with it.
- Co-op with real pads, the Windows build, the stress-test numbers from E and T: still waiting on people, as `docs/STATUS.md` lists.
- T and E have not played the slices. Their reactions, when they take the tour, are posted on the same issues.

## How a fresh session picks this up

1. Read `CLAUDE.md`, then `docs/STATUS.md`, then this plan.
2. Take the lowest-numbered open issue of the table whose "needs" are done, assign it, move it to In progress, branch `code/<issue>-<name>`.
3. Design choices a player feels go in `docs/design/` marked proposed. Every number is data to tune with the move preview tool or in the inspector.
4. Tests in `tests/` for the rules; `docs/STATUS.md` updated; a pull request "Closes #n" when the issue's "done when" is met, Ben having played it on the branch.
5. Ben merges, and builds the private build himself.
