#!/usr/bin/env python3
"""Draws docs/narrative/map-proposal.html: the garden as it is today (world/lawn/layout.json)
with the narrative map plan (docs/narrative/map-plan.json) drawn over it, level by level.

The plan is data: the narrative designer edits map-plan.json, then runs this.
Nothing here changes the game until the plan is applied to world/lawn/layout.json.
Run:  python3 tools/narrative_map.py
"""
import json
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "world/lawn/layout.json"
PLAN = ROOT / "docs/narrative/map-plan.json"
OUT = ROOT / "docs/narrative/map-proposal.html"

LEVEL_COLOURS = {1: "#1b6fd1", 2: "#2f8a4a", 3: "#1f7f8f", 4: "#b5651d", 5: "#9a3fb0", 6: "#c0392b"}
LEVEL_NAMES = {1: "Level 1: the backyard", 2: "Level 2: the apple tree", 3: "Level 3: the kingdom and the pond"}
X0 = X1 = Z0 = Z1 = S = W = H = 0.0


def set_window(win, s):
    global X0, X1, Z0, Z1, S, W, H
    X0, X1, Z0, Z1 = (float(v) for v in win)
    S = float(s)
    W, H = (X1 - X0) * S, (Z1 - Z0) * S


def P(x, z):
    return (x - X0) * S, (z - Z0) * S


def pts(points):
    return " ".join("%.1f,%.1f" % P(p[0], p[1]) for p in points)


def colour(level):
    return LEVEL_COLOURS.get(int(level), LEVEL_COLOURS[4]) if level else "#555"


def level_name(lv):
    return LEVEL_NAMES.get(lv, f"Level {lv}+ (later)")


def label(x, z, text, cls="lbl", dx=0, dy=0, anchor="middle", fill=None):
    px, py = P(x, z)
    f = f' style="fill:{fill}"' if fill else ""
    return f'<text class="{cls}" x="{px + dx:.1f}" y="{py + dy:.1f}" text-anchor="{anchor}"{f}>{escape(str(text))}</text>'


def circle(x, z, r_m, cls, r_px=None, style=""):
    px, py = P(x, z)
    r = r_px if r_px is not None else r_m * S
    st = f' style="{style}"' if style else ""
    return f'<circle class="{cls}" cx="{px:.1f}" cy="{py:.1f}" r="{r:.1f}"{st}/>'


def ellipse(x, z, rx, rz, cls):
    px, py = P(x, z)
    return f'<ellipse class="{cls}" cx="{px:.1f}" cy="{py:.1f}" rx="{rx * S:.1f}" ry="{rz * S:.1f}"/>'


def rect(r, cls, style=""):
    a, b = P(r[0], r[1])
    c, d = P(r[2], r[3])
    st = f' style="{style}"' if style else ""
    return f'<rect class="{cls}" x="{min(a, c):.1f}" y="{min(b, d):.1f}" width="{abs(c - a):.1f}" height="{abs(d - b):.1f}"{st}/>'


def line(points, cls, style=""):
    st = f' style="{style}"' if style else ""
    return f'<polyline class="{cls}" points="{pts(points)}"{st}/>'


def pin(x, z, text, fill, tip=""):
    px, py = P(x, z)
    t = f"<title>{escape(tip)}</title>" if tip else ""
    return (f'<g class="pin">{t}<circle cx="{px:.1f}" cy="{py:.1f}" r="8" style="fill:{fill}"/>'
            f'<text x="{px:.1f}" y="{py + 3.5:.1f}" text-anchor="middle">{escape(str(text))}</text></g>')


def centre(poly):
    xs = [q[0] for q in poly]
    zs = [q[1] for q in poly]
    return (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2


def base_layer(d, removed):
    b = []
    tb = d["tree_base"]
    patio = d.get("patio", {})
    edge_z, wall_z = patio.get("edge_z", 345), patio.get("wall_z", 640)
    b.append(rect([-1500, edge_z, 1500, wall_z], "patio"))
    b.append(rect([-1500, wall_z, 1500, wall_z + 400], "house"))
    b.append(label(0, wall_z + 30, "THE HOUSE (south)", "big"))
    b.append(label(0, (edge_z + wall_z) / 2, "the patio (its edge is an 18 m cliff)", "small"))
    veg = d.get("veg_bed", {}).get("box")
    if veg:
        b.append(rect([veg[0], veg[1], veg[2], veg[3]], "veg"))
        b.append(label(0, veg[3] - 20, "vegetable beds (north)", "small"))
    b.append(rect([345, -360, 1500, edge_z], "drive"))
    b.append(label(395, -10, "driveway", "small"))
    b.append(rect([-360, -360, 360, edge_z], "lawn"))
    for a in d["areas"]:
        if a["id"] in removed or (a["id"] == "lolly_bridge" and "lolly_stick" in removed):
            continue
        cx, cz = a["center"]
        b.append(ellipse(cx, cz, a["radii"][0], a["radii"][1], "area"))
        b.append(label(cx, cz - a["radii"][1] + 10, a["name"], "area-lbl"))
    for bar in d.get("barriers", []):
        b.append(f'<polygon class="tussock" points="{pts(bar.get("points") or bar.get("polygon"))}"/>')
    for p in d["paths"]:
        cls = {"root": "root", "hose": "hose", "ant_road": "antroad", "log": "log", "stream": "stream"}.get(p.get("kind"))
        if cls:
            b.append(line(p["points"], cls))
    b.append(label(-200, 140, "the Great Root", "small"))
    tx, tz = tb["trunk"]["center"]
    b.append(circle(tx, tz, tb["bank"]["outer"], "bank"))
    b.append(circle(tx, tz, tb["trunk"]["radius"], "trunk"))
    b.append(label(tx, tz + 4, "APPLE TREE", "big"))
    for t in tb["tunnels"]:
        if "points" in t:
            b.append(line([(q[0], q[2]) for q in t["points"]], "tunnel"))
    for c in tb["chambers"]:
        b.append(ellipse(c["center"][0], c["center"][2], c["radii"][0], c["radii"][2], "chamber"))
    for l in d["landmarks"]:
        pos = l.get("pos")
        if l["id"] in removed or not pos:
            continue
        b.append(circle(pos[0], pos[1], 0, "dot", r_px=2.5))
        b.append(label(pos[0], pos[1], l.get("name", l["id"]), "tiny", dy=-5))
    return b


def build(d, plan, title, zoom=False):
    removed = {r["id"] for r in plan.get("remove", [])}
    groups = {"base": base_layer(d, removed), "today": [], "playable": [], "hidden": []}
    levels = sorted({int(x.get("level", 4)) for k in ("water", "regions", "features", "routes", "missions")
                     for x in plan.get(k, [])} | {1, 2, 3})
    for lv in levels:
        groups[f"l{lv}"] = []

    def grp(item):
        return groups[f"l{int(item.get('level', 4))}"]

    # today's water, and whatever the plan removes, for comparison
    t = groups["today"]
    for w in d.get("water", []):
        t.append(f'<polygon class="pond-now" points="{pts(w["polygon"])}"/>')
    lm = {l["id"]: l for l in d["landmarks"]}
    for r in plan.get("remove", []):
        l = lm.get(r["id"])
        if l and l.get("pos"):
            x, z = l["pos"]
            size = l.get("size", [4, 1, 4])
            half = max(size[0], size[2]) / 2
            seg = [(x, z - half), (x, z + half)] if size[2] >= size[0] else [(x - half, z), (x + half, z)]
            t.append(line(seg, "removed"))
            t.append(label(x + 6, z - half - 4, f"{l.get('name', r['id'])}: removed", "small warn", anchor="start"))

    for pa in plan.get("playable", []):
        if pa.get("today"):
            groups["playable"].append(rect(pa["rect"], "bounds"))
            groups["playable"].append(label(pa["rect"][0] + 4, pa["rect"][1] + 10, pa["name"], "small", anchor="start"))
        else:
            c = colour(pa.get("level"))
            groups["base"].insert(0, rect(pa["rect"], "grounds"))
            groups["playable"].append(rect(pa["rect"], "extend", f"stroke:{c}"))
            groups["playable"].append(label(pa["rect"][0] + 4, pa["rect"][1] + 12, pa["name"], "plbl", anchor="start", fill=c))

    for w in plan.get("water", []):
        g = grp(w)
        g.append(f'<polygon class="pond" points="{pts(w["polygon"])}"/>')
        cx, cz = centre(w["polygon"])
        g.append(label(cx, cz, w["name"], "water-lbl"))
        if w.get("sub"):
            g.append(label(cx, cz + 14, w["sub"], "water-sub"))
    for r in plan.get("regions", []):
        g = grp(r)
        c = colour(r.get("level"))
        tip = f"<title>{escape(r['name'] + ': ' + r.get('note', ''))}</title>"
        if "circle" in r:
            x, z, rad = r["circle"]
            g.append(f'<g>{tip}' + circle(x, z, rad, "region", style=f"stroke:{c}") + "</g>")
            g.append(label(x, z - rad - 6, r["name"], "plbl", fill=c))
        elif "rect" in r:
            g.append(f'<g>{tip}' + rect(r["rect"], "region", f"stroke:{c}") + "</g>")
            g.append(label(r["rect"][0] + 4, r["rect"][1] + 12, r["name"], "plbl", anchor="start", fill=c))
        elif "polygon" in r:
            g.append(f'<g>{tip}<polygon class="region" style="stroke:{c}" points="{pts(r["polygon"])}"/></g>')
            cx, cz = centre(r["polygon"])
            g.append(label(cx, cz, r["name"], "plbl", fill=c))
    for rt in plan.get("routes", []):
        g = grp(rt)
        style = rt.get("style", "route")
        g.append(line(rt["points"], style, f"stroke:{colour(rt.get('level'))}" if style == "route" else ""))
        if style != "route":
            mid = rt["points"][len(rt["points"]) // 2]
            g.append(label(mid[0], mid[1], rt["name"], f"{style}-lbl", dy=-8))
    for f in plan.get("features", []):
        g = grp(f)
        c = colour(f.get("level"))
        x, z = f["at"]
        if f.get("kind") == "citadel":
            g.append(f'<g><title>{escape(f["name"] + ": " + f.get("note", ""))}</title>'
                     + rect([x - 55, z - 36, x + 55, z + 36], "woodpile") + "</g>")
            g.append(label(x, z + 4, f["name"], "big"))
        else:
            g.append(pin(x, z, "★", c, f"{f['name']}: {f.get('note', '')}"))
            g.append(label(x, z, f["name"], "plbl", dy=18, fill=c))
    for m in plan.get("missions", []):
        x, z = m["at"]
        grp(m).append(pin(x, z, m["label"], "#c23b22" if m.get("boss") else colour(m.get("level")), m.get("note", "")))
    for h in plan.get("hidden", []):
        x, z = h["at"]
        groups["hidden"].append(pin(x, z, "?", "#7a5cc4", h.get("note", "")))
    for o in plan.get("offmap", []):
        groups["playable"].append(label(o["at"][0], o["at"][1], o["text"], "far", anchor=o.get("anchor", "middle")))

    order = ["base", "today"] + [f"l{lv}" for lv in levels] + ["hidden", "playable"]
    names = {"base": "The garden today", "today": "Today's pond, and what the plan removes",
             "hidden": "Hidden missions", "playable": "Playable area: today and planned"}
    for lv in levels:
        names[f"l{lv}"] = level_name(lv)

    svg = [f'<svg viewBox="0 0 {W:.0f} {H:.0f}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{escape(title)}"'
           + (' class="zoom"' if zoom else "") + ">"]
    for k in order:
        hidden = ' style="display:none"' if k == "today" else ""
        svg.append(f'<g class="layer-{k}"{hidden}>' + "".join(groups[k]) + "</g>")
    cx, cy = W - 40, 40
    svg.append(f'<g class="compass"><circle cx="{cx}" cy="{cy}" r="22"/><text x="{cx}" y="{cy - 6}" text-anchor="middle">N</text>'
               f'<path d="M{cx} {cy - 18} L{cx - 5} {cy - 2} L{cx + 5} {cy - 2} Z"/></g>')
    bar = 100 * S
    svg.append(f'<g class="scale"><line x1="20" y1="{H - 20}" x2="{20 + bar}" y2="{H - 20}"/>'
               f'<text x="{20 + bar / 2}" y="{H - 26}" text-anchor="middle">100 m in game (28 cm real)</text></g></svg>')
    return "".join(svg), [(k, names[k], k != "today") for k in order], levels


CSS = """
:root { --bg:#f6f4ee; --ink:#1f2a1c; --muted:#5b6457; --lawn:#cfe0b4; --patio:#d9d3c7; --house:#b9aea0; --veg:#d6d9b0;
  --water:#8fc3e6; --water-ink:#15405e; --panel:#fffdf8; --line:#e2ddd2; --grounds:#d9cfa6; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#15171a; --ink:#e8e6df; --muted:#a3a79b; --lawn:#2c3a22;
  --patio:#3a3833; --house:#4a4540; --veg:#343a26; --water:#2f5f86; --water-ink:#cfe7fb; --panel:#1d2024; --line:#30343a; --grounds:#3d3727; } }
:root[data-theme="dark"] { --bg:#15171a; --ink:#e8e6df; --muted:#a3a79b; --lawn:#2c3a22; --patio:#3a3833; --house:#4a4540; --veg:#343a26;
  --water:#2f5f86; --water-ink:#cfe7fb; --panel:#1d2024; --line:#30343a; --grounds:#3d3727; }
* { box-sizing:border-box }
body { margin:0; background:var(--bg); color:var(--ink); font:15px/1.45 -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; }
main { max-width:1200px; margin:0 auto; padding:20px 16px 40px; }
h1 { font-size:22px; margin:0 0 4px } p.sub { margin:0 0 14px; color:var(--muted) }
h2.zh { font-size:16px; margin:18px 0 8px }
.wrap { display:grid; grid-template-columns:1fr 300px; gap:16px; align-items:start }
@media (max-width:880px) { .wrap { grid-template-columns:1fr } }
.map { background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:8px; overflow:auto }
svg { width:100%; height:auto; display:block }
aside { background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:14px }
aside h2 { font-size:13px; margin:0 0 8px; text-transform:uppercase; letter-spacing:.04em; color:var(--muted) }
aside label { display:block; margin:4px 0; cursor:pointer }
aside ul { margin:6px 0 0; padding-left:18px } aside li { margin:3px 0 }
.key { display:inline-block; width:14px; height:10px; border-radius:2px; vertical-align:middle; margin-right:6px }
.lawn { fill:var(--lawn) } .patio { fill:var(--patio) } .house { fill:var(--house) } .veg { fill:var(--veg) } .drive { fill:var(--patio) }
.grounds { fill:var(--grounds) }
.bounds { fill:none; stroke:var(--ink); stroke-opacity:.35; stroke-dasharray:6 5 }
.extend { fill:none; stroke-width:1.5; stroke-dasharray:10 6 }
.region { fill:none; stroke-width:1.2; stroke-dasharray:8 6; stroke-opacity:.8 }
.area { fill:#fff; fill-opacity:.12; stroke:var(--ink); stroke-opacity:.18 }
.tussock { fill:#6f8f3a; fill-opacity:.45 }
.root { fill:none; stroke:#7a5a3a; stroke-width:7; stroke-linecap:round; stroke-opacity:.7 }
.hose { fill:none; stroke:#3f8f4a; stroke-width:6; stroke-linecap:round }
.stream { fill:none; stroke:var(--water); stroke-width:3 }
.antroad { fill:none; stroke:#8a6d3b; stroke-width:1.5; stroke-dasharray:2 4 }
.log { stroke:#e1b62f; stroke-width:5; stroke-linecap:round }
.bank { fill:#9c8a6a; fill-opacity:.35 } .trunk { fill:#6b4b2f }
.tunnel { fill:none; stroke:#2b1d10; stroke-width:4; stroke-opacity:.6 } .chamber { fill:#2b1d10; fill-opacity:.45 }
.dot { fill:var(--ink) }
.pond-now { fill:none; stroke:var(--water-ink); stroke-width:1.5; stroke-dasharray:4 3 }
.removed { stroke:#c23b22; stroke-width:4 }
.pond { fill:var(--water); stroke:var(--water-ink); stroke-opacity:.5 }
.woodpile { fill:#8b5a2b; stroke:#5a3a1a }
.route { fill:none; stroke-width:2.5; stroke-opacity:.6 }
.raid { fill:none; stroke:#c23b22; stroke-width:2.5; stroke-dasharray:8 5 }
.underground { fill:none; stroke:#7b3fa0; stroke-width:3; stroke-dasharray:1 6; stroke-linecap:round }
.causeway { fill:none; stroke:#8b5a2b; stroke-width:5; stroke-dasharray:6 3 }
.climb { fill:none; stroke:#b5651d; stroke-width:2; stroke-dasharray:2 3 }
text { fill:var(--ink) } .lbl { font-size:11px } .small { font-size:10px; fill:var(--muted) } .tiny { font-size:8.5px; fill:var(--muted) }
.big { font-size:12px; font-weight:700; letter-spacing:.05em } .area-lbl { font-size:10px; font-weight:600; fill:var(--muted) }
.water-lbl { font-size:12px; font-weight:700; fill:var(--water-ink) } .water-sub { font-size:10px; fill:var(--water-ink) }
.plbl { font-size:10px; font-weight:600 } .far { font-size:11px; font-weight:600; fill:#b5651d } .warn { fill:#c23b22 }
.raid-lbl { font-size:10px; font-weight:600; fill:#c23b22 } .underground-lbl { font-size:10px; font-style:italic; fill:#7b3fa0 }
.causeway-lbl { font-size:10px; font-weight:600; fill:#8b5a2b } .climb-lbl { font-size:10px; fill:#b5651d }
.pin text { fill:#fff; font-size:10px; font-weight:700 } .pin circle { cursor:help }
svg.zoom text { font-size:8px } svg.zoom .big { font-size:10px } svg.zoom .pin text { font-size:9px }
.compass circle { fill:var(--panel); stroke:var(--ink); stroke-opacity:.4 } .compass text { font-size:10px; font-weight:700 } .compass path { fill:#c23b22 }
.scale line { stroke:var(--ink); stroke-width:2 } .scale text { font-size:10px; fill:var(--muted) }
"""


def main():
    d = json.loads(LAYOUT.read_text())
    plan = json.loads(PLAN.read_text())
    set_window(plan.get("window", [-700, 440, -400, 690]), plan.get("scale", 0.8))
    whole, layers, levels = build(d, plan, "The whole garden")
    zooms = []
    for z in plan.get("zooms", []):
        set_window(z["window"], z.get("scale", 1.6))
        svg, _, _ = build(d, plan, z["title"], zoom=True)
        zooms.append(f'<h2 class="zh">{escape(z["title"])}</h2><div class="map">{svg}</div>')
    toggles = "".join(f'<label><input type="checkbox" data-layer="{k}"{" checked" if on else ""}> {escape(t)}</label>'
                      for k, t, on in layers)
    keys = "".join(f'<div><span class="key" style="background:{colour(lv)}"></span>{escape(level_name(lv))}</div>' for lv in levels)
    notes = "".join(f"<li>{escape(n)}</li>" for n in plan.get("summary", []))
    plan_box = f'<h2 style="margin-top:14px">The plan</h2><ul>{notes}</ul>' if notes else ""
    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Garden Map Plan</title><style>{CSS}</style></head>
<body><main>
<h1>Garden map: the plan</h1>
<p class="sub">Today's garden from <code>world/lawn/layout.json</code>, with the map plan (<code>docs/narrative/map-plan.json</code>) drawn over it. Nothing here changes the game yet. Hover a marker for what happens there.</p>
<div class="wrap">
<div><div class="map">{whole}</div>{"".join(zooms)}</div>
<aside>
<h2>Layers</h2>{toggles}
{plan_box}
<h2 style="margin-top:14px">Key</h2>{keys}
<div><span class="key" style="background:#c23b22"></span>Termites, bosses</div>
<div><span class="key" style="background:#7a5cc4"></span>Hidden missions</div>
<div><span class="key" style="background:#7b3fa0"></span>Underground</div>
</aside></div>
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
