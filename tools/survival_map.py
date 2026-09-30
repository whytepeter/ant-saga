#!/usr/bin/env python3
"""Draws docs/narrative/survival-map.html: the survival plan (docs/SURVIVAL.md) on the garden as it
is today (world/lawn/layout.json), each place marked built, part-built or still to build, act by act.

The plan is data (docs/narrative/survival-map.json): update a status there when something gets built,
then run this. It borrows the story map's drawing (tools/narrative_map.py).
Run:  python3 tools/survival_map.py
"""
import json
import sys
from html import escape
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import narrative_map as nm  # noqa: E402

ROOT = nm.ROOT
PLAN = ROOT / "docs/narrative/survival-map.json"
OUT = ROOT / "docs/narrative/survival-map.html"
MARK = {"built": "✓", "part": "½", "todo": "+"}
WORD = {"built": "in the game", "part": "part-built", "todo": "to build"}

EXTRA_CSS = """
.spin circle { cursor:help; stroke-width:2 }
.spin.built text { fill:#fff } .spin.part circle { fill-opacity:.45 } .spin.part text { fill:var(--ink) }
.spin.todo circle { fill:var(--panel) !important; stroke-dasharray:3 2 } .spin text { font-size:10px; font-weight:700 }
svg.zoom .spin text { font-size:9px }
.region.built { stroke-dasharray:none; stroke-width:1.6 } .grounds-built { fill:var(--grounds); fill-opacity:.8 }
.ww { fill:none; stroke:#1f7f8f; stroke-width:3; stroke-opacity:.55; stroke-linecap:round }
.wwc { fill:#1f7f8f; fill-opacity:.35 }
.todo-line { stroke-dasharray:6 5 !important }
.status { margin-top:22px } .status h3 { font-size:15px; margin:18px 0 6px; display:flex; align-items:center; gap:8px }
.status ul { list-style:none; padding:0; margin:0 } .status li { padding:5px 0; border-top:1px solid var(--line); display:grid; grid-template-columns:92px 1fr; gap:10px }
.tag { font-size:12px; font-weight:600; white-space:nowrap } .tag.built { color:#2f8a4a } .tag.part { color:#b5651d } .tag.todo { color:var(--muted) }
.status b { font-weight:600 } .note { color:var(--muted) }
.missions { display:grid; grid-template-columns:repeat(auto-fill, minmax(220px, 1fr)); gap:10px; margin-top:8px }
.mission { background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:10px 12px }
.mission h4 { margin:0 0 6px; font-size:14px } .mission ol { margin:0; padding-left:18px; color:var(--muted) }
aside ol { margin:6px 0 0; padding-left:18px } aside ol li { margin:4px 0 }
"""


def spin(x, z, colour, status, tip):
    px, py = nm.P(x, z)
    return (f'<g class="spin {status}"><title>{escape(tip)}</title>'
            f'<circle cx="{px:.1f}" cy="{py:.1f}" r="8" style="fill:{colour};stroke:{colour}"/>'
            f'<text x="{px:.1f}" y="{py + 3.5:.1f}" text-anchor="middle"'
            + (f' style="fill:{colour}"' if status == "todo" else "") + f'>{MARK[status]}</text></g>')


def build(d, plan, title, zoom=False):
    layers = plan["layers"]
    colours = {l["key"]: l["colour"] for l in layers}
    groups = {"base": nm.base_layer(d, set())}
    for l in layers:
        groups[l["key"]] = []
    base = groups["base"]
    # the tree grounds as built (the story map only had them as a plan)
    tg = d.get("tree_grounds", {})
    if tg.get("bounds"):
        x0, z0, x1, z1 = tg["bounds"]
        base.insert(0, nm.rect([x0, z0, x1, z1], "grounds-built"))
        for a in tg.get("areas", []):
            cx, cz = a["center"]
            base.append(nm.ellipse(cx, cz, a["radii"][0], a["radii"][1], "area"))
        for pd in tg.get("puddles", []):
            base.append(nm.circle(pd["pos"][0], pd["pos"][1], pd["radius"], "pond"))
    # the Wormways, from the layout (built)
    ww = d.get("wormways", {})
    g = groups.get("rain", [])
    for t in ww.get("tunnels", []):
        if t.get("points"):
            g.append(nm.line([(q[0], q[2]) for q in t["points"]], "ww"))
    for c in ww.get("chambers", []):
        at = c.get("center") or c.get("pos")
        r = c.get("radii") or [c.get("radius", 10)] * 3
        if at:
            g.append(nm.ellipse(at[0], at[2], r[0], r[2] if len(r) > 2 else r[0], "wwc"))

    for r in plan.get("regions", []):
        g = groups[r["layer"]]
        c = colours[r["layer"]]
        cls = "region " + r.get("status", "todo")
        tip = f"<title>{escape(r['name'] + ' (' + WORD[r.get('status', 'todo')] + '): ' + r.get('note', ''))}</title>"
        if "circle" in r:
            x, z, rad = r["circle"]
            g.append(f"<g>{tip}" + nm.circle(x, z, rad, cls, style=f"stroke:{c}") + "</g>")
            g.append(nm.label(x, z - rad - 6, r["name"], "plbl", fill=c))
        elif "rect" in r:
            g.append(f"<g>{tip}" + nm.rect(r["rect"], cls, f"stroke:{c}") + "</g>")
            g.append(nm.label(r["rect"][0] + 4, r["rect"][1] + 12, r["name"], "plbl", anchor="start", fill=c))
    for rt in plan.get("routes", []):
        g = groups[rt["layer"]]
        style = rt.get("style", "route")
        todo = " todo-line" if rt.get("status") == "todo" else ""
        colour = f"stroke:{colours[rt['layer']]}" if style == "route" else ""
        g.append(nm.line(rt["points"], style + todo, colour))
        if rt.get("name"):
            mid = rt["points"][len(rt["points"]) // 2]
            cls = f"{style}-lbl" if style != "route" else "plbl"
            g.append(nm.label(mid[0], mid[1], rt["name"], cls, dy=-8, fill=colours[rt["layer"]] if style == "route" else None))
    for p in plan.get("pins", []):
        g = groups[p["layer"]]
        c = colours[p["layer"]]
        x, z = p["at"]
        st = p.get("status", "todo")
        g.append(spin(x, z, c, st, f"{p['name']} ({WORD[st]}): {p.get('note', '')}"))
        g.append(nm.label(x, z, p["name"], "plbl", dy=19, fill=c))

    order = ["base"] + [l["key"] for l in layers]
    svg = [f'<svg viewBox="0 0 {nm.W:.0f} {nm.H:.0f}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{escape(title)}"'
           + (' class="zoom"' if zoom else "") + ">"]
    for k in order:
        svg.append(f'<g class="layer-{k}">' + "".join(groups[k]) + "</g>")
    cx, cy = nm.W - 40, 40
    svg.append(f'<g class="compass"><circle cx="{cx}" cy="{cy}" r="22"/><text x="{cx}" y="{cy - 6}" text-anchor="middle">N</text>'
               f'<path d="M{cx} {cy - 18} L{cx - 5} {cy - 2} L{cx + 5} {cy - 2} Z"/></g>')
    bar = 100 * nm.S
    svg.append(f'<g class="scale"><line x1="20" y1="{nm.H - 20}" x2="{20 + bar}" y2="{nm.H - 20}"/>'
               f'<text x="{20 + bar / 2}" y="{nm.H - 26}" text-anchor="middle">100 m in game (28 cm real)</text></g></svg>')
    return "".join(svg)


def status_list(plan):
    out = ['<section class="status"><h2 class="zh">Place by place</h2>']
    rank = {"built": 0, "part": 1, "todo": 2}
    for l in plan["layers"]:
        items = [p for p in plan.get("pins", []) + plan.get("regions", []) if p["layer"] == l["key"]]
        if not items:
            continue
        items.sort(key=lambda p: rank[p.get("status", "todo")])
        out.append(f'<h3><span class="key" style="background:{l["colour"]}"></span>{escape(l["name"])}</h3><ul>')
        for p in items:
            st = p.get("status", "todo")
            out.append(f'<li><span class="tag {st}">{MARK[st]} {WORD[st]}</span>'
                       f'<span><b>{escape(p["name"][0].upper() + p["name"][1:])}</b> <span class="note">{escape(p.get("note", ""))}</span></span></li>')
        out.append("</ul>")
    tm = plan.get("tree_missions", [])
    if tm:
        head = escape(plan.get("tree_missions_title", "Proposed: the apple tree's missions"))
        out.append(f'<h3><span class="key" style="background:#2f8a4a"></span>{head}</h3>'
                   '<p class="note" style="margin:0">Shown under the compass like the Wormways\' (world/missions.gd), one step at a time.</p>'
                   '<div class="missions">')
        for m in tm:
            steps = "".join(f"<li>{escape(s)}</li>" for s in m["steps"])
            out.append(f'<div class="mission"><h4>{escape(m["title"])}</h4><ol>{steps}</ol></div>')
        out.append("</div>")
    out.append("</section>")
    return "".join(out)


def main():
    d = json.loads(nm.LAYOUT.read_text())
    plan = json.loads(PLAN.read_text())
    nm.set_window(plan["window"], plan["scale"])
    whole = build(d, plan, "The whole garden")
    zooms = []
    for z in plan.get("zooms", []):
        nm.set_window(z["window"], z["scale"])
        zooms.append(f'<h2 class="zh">{escape(z["title"])}</h2><div class="map">{build(d, plan, z["title"], zoom=True)}</div>')
    toggles = "".join(f'<label><input type="checkbox" data-layer="{l["key"]}" checked> '
                      f'<span class="key" style="background:{l["colour"]}"></span>{escape(l["name"])}</label>'
                      for l in plan["layers"])
    nxt = "".join(f"<li>{escape(n)}</li>" for n in plan.get("next", []))
    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Survival Garden Map</title><style>{nm.CSS}{EXTRA_CSS}</style></head><body><main>
<h1>{escape(plan["title"])}</h1>
<p class="sub">{escape(plan["sub"])}</p>
<div class="wrap">
<div><div class="map">{whole}</div>{"".join(zooms)}</div>
<aside>
<h2>Layers</h2>{toggles}
<h2 style="margin-top:14px">Pins</h2>
<div><b>✓</b> in the game &nbsp; <b>½</b> part-built &nbsp; <b>+</b> to build</div>
<h2 style="margin-top:14px">What's next (recommended)</h2><ol>{nxt}</ol>
</aside></div>
{status_list(plan)}
</main>
<script>
document.querySelectorAll('input[data-layer]').forEach(function (box) {{
  box.addEventListener('change', function () {{
    document.querySelectorAll('.layer-' + box.dataset.layer).forEach(function (g) {{
      g.style.display = box.checked ? '' : 'none';
    }});
  }});
}});
</script>
</body></html>
"""
    OUT.write_text(html)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
