#!/usr/bin/env python3
"""A review page of a concept's generated effects (PixelLab /vfx) for the user to pick from.

    tools/art/vfx_review.py vfx_jeanne [--out reports/vfx_vfx_jeanne.html] [--inline]

One card per call (art/raw/<concept>/<id>/): the GIF at its true pixel size on a checker, the
canvas, frame count, fps, loop, the parts the artist built it from, the generations charged and
the link to edit it for free on PixelLab's website. Cards are grouped by effect: the id without its
variant suffix (_pro_a, _pro_b, _lite, _pro). The page links the GIFs under art/raw/, so open it
with the repository served at its root (`python3 -m http.server`); with --inline the GIFs are embedded
and the file stands alone. Nothing is judged here.
"""

import argparse
import base64
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art" / "raw"
SUFFIX = re.compile(r"_(pro_[a-z]|lite|pro)$")

STYLE = """
body { margin: 0; padding: 24px; background: #2a242c; color: #ebe1cd; font: 15px/1.4 system-ui, sans-serif; }
h1 { font-size: 22px; margin: 0 0 4px; }
h2 { font-size: 18px; margin: 32px 0 8px; border-bottom: 1px solid #4a424c; padding-bottom: 4px; }
.cards { display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start; }
.card { background: #352e38; border-radius: 8px; padding: 12px; max-width: 560px; }
.card img { display: block; image-rendering: pixelated; max-width: 536px; height: auto;
  background: repeating-conic-gradient(#4e4652 0% 25%, #3e3741 0% 50%) 0 0 / 16px 16px; }
.card.dark img { background: #111; }
.meta { font-size: 13px; color: #c9bfae; margin-top: 8px; }
.meta b { color: #ebe1cd; }
a { color: #f0c674; }
.controls { margin: 8px 0 16px; font-size: 13px; }
"""


def effect_of(call_id: str) -> str:
    return SUFFIX.sub("", call_id)


def card(call_dir: Path, concept: str, inline: bool = False) -> str:
    response = json.loads((call_dir / "response.json").read_text())
    jobs = response.get("jobs") or []
    result = next(((j.get("last_response") or {}) for j in jobs if (j.get("last_response") or {}).get("files")), {})
    request = json.loads((call_dir / "request.json").read_text())["body"]
    gif = next((n for n in result.get("files", {}) if n.endswith(".gif")), None)
    if not gif:
        return f'<div class="card"><b>{html.escape(call_dir.name)}</b><div class="meta">no result</div></div>'
    rel = f"../art/raw/{concept}/{call_dir.name}/{gif}"
    src = "data:image/gif;base64," + base64.b64encode((call_dir / gif).read_bytes()).decode() if inline else rel
    canvas = result.get("canvas") or {}
    usage = (result.get("billing_usage") or {}).get("generations")
    parts = ", ".join(result.get("parts") or [])
    message = html.escape(result.get("message") or "")
    return f"""<div class="card">
  <b>{html.escape(call_dir.name)}</b> <span class="meta">({html.escape(request.get("artist", "?"))})</span>
  <img src="{html.escape(src)}" alt="{html.escape(call_dir.name)}">
  <div class="meta">{canvas.get("w")}×{canvas.get("h")}, {result.get("frames")} frames at {result.get("fps")} fps,
    {"loops" if result.get("loop") else "plays once"} · parts: {html.escape(parts)} · <b>{usage}</b> generations
    · <a href="{html.escape(result.get("edit_url", "#"))}" target="_blank">edit on PixelLab</a>
    · <code>{html.escape(str(call_dir.relative_to(ROOT)))}</code></div>
  <div class="meta"><i>{message}</i></div>
</div>"""


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("concept")
    parser.add_argument("--out")
    parser.add_argument("--inline", action="store_true", help="embed the GIFs so the file stands alone")
    args = parser.parse_args(argv)
    concept_dir = RAW / args.concept
    if not concept_dir.is_dir():
        print(f"no outputs under {concept_dir.relative_to(ROOT)}", file=sys.stderr)
        return 1
    groups: dict[str, list[Path]] = {}
    for call_dir in sorted(p for p in concept_dir.iterdir() if (p / "response.json").exists()):
        groups.setdefault(effect_of(call_dir.name), []).append(call_dir)
    sections = []
    for effect, dirs in groups.items():
        cards = "\n".join(card(d, args.concept, args.inline) for d in dirs)
        sections.append(f"<h2>{html.escape(effect)}</h2>\n<div class=\"cards\">\n{cards}\n</div>")
    page = f"""<!doctype html><html><head><meta charset="utf-8"><title>{html.escape(args.concept)} effects</title>
<style>{STYLE}</style></head><body>
<h1>{html.escape(args.concept)}: the generated effects</h1>
<div class="controls"><label><input type="checkbox" id="dark"> dark background (the stage at night)</label>
 · GIFs at their true pixel size; every one is proposed, the person picks.</div>
{chr(10).join(sections)}
<script>document.getElementById('dark').onchange = e => document.querySelectorAll('.card').forEach(c => c.classList.toggle('dark', e.target.checked));</script>
</body></html>"""
    out = Path(args.out) if args.out else ROOT / "reports" / f"vfx_{args.concept}.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page)
    print(f"{out.relative_to(ROOT)}: {sum(len(d) for d in groups.values())} effect(s) in {len(groups)} group(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
