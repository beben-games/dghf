#!/usr/bin/env python3
"""A review page of a concept's stills and characters for the user to pick from.

    tools/art/concept_review.py jeanne_concepts --prefixes still_knightstyle_,still_,char_v3_,char_flash_
        [--directions south,south-east,east] [--scale 2] [--out reports/concepts_<concept>.html]

One section per look: a call's id with its method prefix removed (still_a_bowl -> a_bowl), so the
same look made by several methods sits side by side. A card per call: its loose images (a still, a
Pro call's candidates) and, for a character, the rotations asked for (the south view shows the face,
the east view is the in-game sprite). Images are embedded, so the file stands alone, and drawn at
whole-number scale with hard pixels. Each card carries its prompt. Nothing is judged here.
"""

import argparse
import base64
import html
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art" / "raw"

STYLE = """
body { margin: 0; padding: 24px; background: #2a242c; color: #ebe1cd; font: 15px/1.4 system-ui, sans-serif; }
h1 { font-size: 22px; margin: 0 0 4px; }
h2 { font-size: 18px; margin: 32px 0 8px; border-bottom: 1px solid #4a424c; padding-bottom: 4px; }
.cards { display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start; }
.card { background: #352e38; border-radius: 8px; padding: 12px; }
.shots { display: flex; gap: 8px; flex-wrap: wrap; }
figure { margin: 0; } figcaption { font-size: 12px; color: #c9bfae; text-align: center; }
img { display: block; image-rendering: pixelated; background: repeating-conic-gradient(#4e4652 0% 25%, #3e3741 0% 50%) 0 0 / 16px 16px; }
body.dark img { background: #111; } body.light img { background: #c8c0b0; }
.meta { font-size: 13px; color: #c9bfae; margin-top: 8px; max-width: 560px; }
details { font-size: 12px; color: #a99f8e; max-width: 560px; margin-top: 4px; }
.controls { margin: 8px 0 16px; font-size: 13px; }
"""


def embed(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def size_of(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def shots_of(call_dir: Path, directions: list[str]) -> list[tuple[str, Path]]:
    shots = [(p.stem if len(list(call_dir.glob("[0-9][0-9].png"))) > 1 else "still", p)
             for p in sorted(call_dir.glob("[0-9][0-9].png"))]
    # A character's rotations: saved by name beside the call's files, or inside its download.
    character = [(d, call_dir / f"{d}.png") for d in directions if (call_dir / f"{d}.png").exists()]
    meta_path = call_dir / "character" / "metadata.json"
    if not character and meta_path.exists():
        rotations = json.loads(meta_path.read_text())["states"][0]["frames"]["rotations"]
        character = [(d, call_dir / "character" / rotations[d]) for d in directions if d in rotations]
    # A character call's loose images repeat its rotations: show the named ones only.
    return character or shots


def card(call_dir: Path, directions: list[str], scale: int) -> str:
    request = json.loads((call_dir / "request.json").read_text())
    body = request.get("body", {})
    figures = []
    for label, path in shots_of(call_dir, directions):
        width, height = size_of(path)
        figures.append(f'<figure><img src="{embed(path)}" width="{width * scale}" height="{height * scale}" '
                       f'alt="{html.escape(call_dir.name)} {html.escape(label)}"><figcaption>{html.escape(label)}</figcaption></figure>')
    if not figures:
        figures.append('<div class="meta">no image</div>')
    styled = " · with a style image" if "style_image" in body or "style_images" in body else ""
    return f"""<div class="card"><b>{html.escape(call_dir.name)}</b>
  <span class="meta">({html.escape(request.get("endpoint", "?").lstrip("/"))}{styled})</span>
  <div class="shots">{''.join(figures)}</div>
  <details><summary>prompt</summary>{html.escape(body.get("description", ""))}</details></div>"""


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("concept")
    parser.add_argument("--prefixes", default="", help="method prefixes to strip from ids, longest first")
    parser.add_argument("--directions", default="south,south-east,east")
    parser.add_argument("--scale", type=int, default=2)
    parser.add_argument("--out")
    args = parser.parse_args(argv)
    concept_dir = RAW / args.concept
    if not concept_dir.is_dir():
        print(f"no outputs under {concept_dir.relative_to(ROOT)}", file=sys.stderr)
        return 1
    prefixes = [p for p in args.prefixes.split(",") if p]
    directions = [d for d in args.directions.split(",") if d]
    groups: dict[str, list[Path]] = {}
    for call_dir in sorted(p for p in concept_dir.iterdir() if (p / "request.json").exists()):
        look = next((call_dir.name[len(p):] for p in prefixes if call_dir.name.startswith(p)), call_dir.name)
        groups.setdefault(look, []).append(call_dir)
    sections = [f'<h2>{html.escape(look)}</h2>\n<div class="cards">\n' + "\n".join(card(d, directions, args.scale) for d in dirs) + "\n</div>"
                for look, dirs in sorted(groups.items())]
    page = f"""<!doctype html><html><head><meta charset="utf-8"><title>{html.escape(args.concept)} review</title>
<style>{STYLE}</style></head><body>
<h1>{html.escape(args.concept)}: the candidates</h1>
<div class="controls">Background:
 <label><input type="radio" name="bg" value="" checked> checker</label>
 <label><input type="radio" name="bg" value="dark"> dark</label>
 <label><input type="radio" name="bg" value="light"> light</label>
 · drawn at {args.scale}x, one art pixel as {args.scale} screen pixels; every one is proposed, the person picks.</div>
{chr(10).join(sections)}
<script>document.querySelectorAll('input[name=bg]').forEach(r => r.onchange = e => document.body.className = e.target.value);</script>
</body></html>"""
    out = Path(args.out) if args.out else ROOT / "reports" / f"concepts_{args.concept}.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page)
    print(f"{out.relative_to(ROOT)}: {sum(len(d) for d in groups.values())} call(s) in {len(groups)} look(s), {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
