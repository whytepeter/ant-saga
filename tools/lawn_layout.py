#!/usr/bin/env python3
"""Validate and render the Lawn layout (world/lawn/layout.json).

    python3 tools/lawn_layout.py check    # connectivity + sanity checks, exit 1 on failure
    python3 tools/lawn_layout.py render   # writes docs/lawn_map.svg

layout.json is the single source of truth for Level 1 coordinates; the graybox
builder reads the same file, so this check guards the level before it exists.
"""

import json
import math
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "world" / "lawn" / "layout.json"
MAP_OUT = ROOT / "docs" / "lawn_map.svg"

CELL = 2.0  # meters per grid cell for the walkability raster


# ── geometry ──────────────────────────────────────────────────────────────────

def point_in_polygon(x, z, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            inside = not inside
        j = i
    return inside


def dist_to_segment(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    cx, cz = ax + t * dx, az + t * dz
    return math.hypot(px - cx, pz - cz)


def dist_to_polyline(px, pz, pts):
    return min(dist_to_segment(px, pz, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


# ── walkability grid ──────────────────────────────────────────────────────────

class Grid:
    def __init__(self, layout):
        x0, z0, x1, z1 = layout["meta"]["playable_bounds"]
        self.x0, self.z0 = x0, z0
        self.w = int((x1 - x0) / CELL)
        self.h = int((z1 - z0) / CELL)
        self.blocked = [[False] * self.w for _ in range(self.h)]
        self.reason = [[None] * self.w for _ in range(self.h)]

    def cell_center(self, i, j):
        return self.x0 + (i + 0.5) * CELL, self.z0 + (j + 0.5) * CELL

    def to_cell(self, x, z):
        return int((x - self.x0) / CELL), int((z - self.z0) / CELL)

    def cells_in_bbox(self, xa, za, xb, zb):
        ia, ja = self.to_cell(xa, za)
        ib, jb = self.to_cell(xb, zb)
        for j in range(max(0, ja), min(self.h, jb + 1)):
            for i in range(max(0, ia), min(self.w, ib + 1)):
                yield i, j

    def mark(self, i, j, value, reason):
        self.blocked[j][i] = value
        if value:
            self.reason[j][i] = reason

    def block_polygon(self, poly, reason, value=True):
        xs = [p[0] for p in poly]
        zs = [p[1] for p in poly]
        for i, j in self.cells_in_bbox(min(xs), min(zs), max(xs), max(zs)):
            if point_in_polygon(*self.cell_center(i, j), poly):
                self.mark(i, j, value, reason)

    def block_polyline(self, pts, half_width, reason, value=True):
        xs = [p[0] for p in pts]
        zs = [p[1] for p in pts]
        pad = half_width + CELL
        for i, j in self.cells_in_bbox(min(xs) - pad, min(zs) - pad, max(xs) + pad, max(zs) + pad):
            if dist_to_polyline(*self.cell_center(i, j), pts) <= half_width:
                self.mark(i, j, value, reason)

    def block_circle(self, cx, cz, r, reason):
        for i, j in self.cells_in_bbox(cx - r, cz - r, cx + r, cz + r):
            x, z = self.cell_center(i, j)
            if math.hypot(x - cx, z - cz) <= r:
                self.mark(i, j, True, reason)

    def is_blocked(self, x, z):
        i, j = self.to_cell(x, z)
        if not (0 <= i < self.w and 0 <= j < self.h):
            return True
        return self.blocked[j][i]

    def flood(self, start):
        si, sj = self.to_cell(*start)
        seen = [[False] * self.w for _ in range(self.h)]
        if self.blocked[sj][si]:
            return seen
        seen[sj][si] = True
        q = deque([(si, sj)])
        while q:
            i, j = q.popleft()
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ni, nj = i + di, j + dj
                if 0 <= ni < self.w and 0 <= nj < self.h and not seen[nj][ni] and not self.blocked[nj][ni]:
                    seen[nj][ni] = True
                    q.append((ni, nj))
        return seen


def by_id(items, id_):
    return next(it for it in items if it["id"] == id_)


def build_grid(layout, bridge=True, tunnel=True):
    g = Grid(layout)
    # World edges: the playable box is inset from the boundary props.
    edge = {"north": ("z", -345, -1), "south": ("z", 345, 1), "east": ("x", 345, 1), "west": ("x", -350, -1)}
    for j in range(g.h):
        for i in range(g.w):
            x, z = g.cell_center(i, j)
            for side, (axis, v, sign) in edge.items():
                c = x if axis == "x" else z
                if (c - v) * sign >= 0:
                    g.mark(i, j, True, f"boundary:{side}")
    trunk = by_id(layout["skyline"], "oak_trunk")
    g.block_circle(trunk["pos"][0], trunk["pos"][1], trunk["size"][0] / 2, "oak_trunk")
    for b in layout["barriers"]:
        g.block_polygon(b["polygon"], b["id"])
    for w in layout["water"]:
        g.block_polygon(w["polygon"], w["id"])
    for p in layout["paths"]:
        if p["kind"] == "root":
            g.block_polyline(p["points"], p["width"] / 2, p["id"])
    if bridge:
        stick = by_id(layout["landmarks"], "popsicle_stick")
        (cx, cz), (sw, _, sl) = stick["pos"], stick["size"]
        g.block_polygon([[cx - sw / 2, cz - sl / 2], [cx + sw / 2, cz - sl / 2],
                         [cx + sw / 2, cz + sl / 2], [cx - sw / 2, cz + sl / 2]], None, value=False)
    if tunnel:
        g.block_polyline(by_id(layout["paths"], "root_tunnel")["points"], 2.0, None, value=False)
    return g


# ── check ─────────────────────────────────────────────────────────────────────

def check(layout):
    failures = []
    ok = lambda msg: print(f"  ok    {msg}")

    def fail(msg):
        failures.append(msg)
        print(f"  FAIL  {msg}")

    spawn = layout["spawn"]["pos"]
    south_areas = {"oak_rootlands", "spiders_edge"}

    print("Bounds")
    x0, z0, x1, z1 = layout["meta"]["playable_bounds"]
    for coll in ("areas", "landmarks"):
        for it in layout[coll]:
            x, z = it.get("center", it.get("pos"))
            if not (x0 <= x <= x1 and z0 <= z <= z1):
                fail(f"{coll}/{it['id']} at {x},{z} is outside the playable box")
    ok("all areas and landmarks inside the 720 m box") if not failures else None

    print("Gating (no bridge, no tunnel): the south must be sealed")
    g = build_grid(layout, bridge=False, tunnel=False)
    seen = g.flood(spawn)
    for a in layout["areas"]:
        i, j = g.to_cell(*a["center"])
        reach = seen[j][i]
        if a["id"] in south_areas and reach:
            fail(f"{a['id']} reachable without the bridge: the south is not sealed")
        elif a["id"] not in south_areas and not reach and a["id"] != "popsicle_bridge":
            fail(f"{a['id']} unreachable from spawn")
    if not any("sealed" in f or "unreachable" in f for f in failures):
        ok("south sealed; every northern area reachable from spawn")

    print("Full level (bridge + tunnel)")
    g = build_grid(layout)
    seen = g.flood(spawn)
    before = len(failures)
    for a in layout["areas"]:
        i, j = g.to_cell(*a["center"])
        if not seen[j][i]:
            fail(f"{a['id']} unreachable with the bridge")
    if len(failures) == before:
        ok("all 9 areas reachable")

    print("Routes never pass through walls")
    before = len(failures)
    for p in layout["paths"]:
        if p["kind"] not in ("main_route", "shortcut", "ant_road"):
            continue
        pts = p["points"]
        for k in range(len(pts) - 1):
            (ax, az), (bx, bz) = pts[k], pts[k + 1]
            steps = max(1, int(math.hypot(bx - ax, bz - az) / 1.0))
            for s in range(steps + 1):
                x, z = ax + (bx - ax) * s / steps, az + (bz - az) * s / steps
                if g.is_blocked(x, z):
                    i, j = g.to_cell(x, z)
                    why = g.reason[j][i] if 0 <= i < g.w and 0 <= j < g.h else "outside"
                    fail(f"{p['id']} segment {k} hits '{why}' at ({x:.0f}, {z:.0f})")
                    break
            else:
                continue
            break
    if len(failures) == before:
        ok("main routes, shortcut and ant roads are clear")

    print("Route length")
    speed = 6.0  # m/s, Amodu run
    for p in layout["paths"]:
        if p["kind"] == "main_route":
            L = sum(math.hypot(p["points"][k + 1][0] - p["points"][k][0], p["points"][k + 1][1] - p["points"][k][1])
                    for k in range(len(p["points"]) - 1))
            print(f"  info  {p['id']}: {L:.0f} m, {L / speed / 60:.1f} min at a {speed:.0f} m/s run")

    print()
    print("PASS" if not failures else f"{len(failures)} failure(s)")
    return not failures


# ── render ────────────────────────────────────────────────────────────────────

S = 1.2      # px per meter
M = 130      # margin px around the 720 m box
MAPPX = 720 * S
W = int(MAPPX + 2 * M)
LEGEND_H = 110
TOP = 36     # extra room under the title
H = W + LEGEND_H + TOP

COL = {
    "paper": "#efe9dc", "ink": "#2b2a26", "muted": "#6b675d",
    "lawn": "#9cc47a", "lawn_dark": "#6f9d52", "shade": "#5c7f48",
    "patio": "#c9c4ba", "stones": "#b9b2a4", "brick": "#b0674a", "litter": "#a4814f",
    "water": "#6fb3d9", "water_edge": "#3d86b3", "root": "#7a5634", "hose": "#2f6b4a",
    "brass": "#c9a13b", "stick": "#e2c58b", "route": "#e8641b", "antroad": "#5a3e22",
    "termite": "#c0392b", "tussock": "#476e37",
}

AREA_TINT = {
    "backpack_hollow": "#f3e7b0", "blade_forest": "#6f9d52", "dewdrop_garden": "#bfe3ea",
    "capstone_shelter": "#f0d6a8", "bare_patch": "#c9ad83", "hose_run": "#cfe8f3",
    "popsicle_bridge": "#e9d9b4", "oak_rootlands": "#b89a74", "spiders_edge": "#8c7a86",
}


def px(x):
    return M + (x + 360) * S


def pz(z):
    return M + (z + 360) * S


def pts_attr(pts):
    return " ".join(f"{px(x):.1f},{pz(z):.1f}" for x, z in pts)


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, s, size=11, weight=400, anchor="start", fill=None, halo=True, italic=False):
    fill = fill or COL["ink"]
    style = f'font-size:{size}px;font-weight:{weight};' + ("font-style:italic;" if italic else "")
    halo_attr = f' stroke="{COL["paper"]}" stroke-width="3" paint-order="stroke" stroke-linejoin="round"' if halo else ""
    return f'<text x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}" fill="{fill}" style="{style}"{halo_attr}>{esc(s)}</text>'


# Label placement for landmarks: (dx, dy, anchor) in px; omitted ids are drawn unlabeled.
LABELS = {
    "backpack": (0, -52, "middle"), "pencil_log": (10, 22, "start"),
    "dandelion_bloom": (9, 4, "start"), "dandelion_seed": (-9, 4, "end"),
    "lego_waystation": (9, 4, "start"), "marble": (-8, 4, "end"), "orb_web": (10, 4, "start"),
    "oak_root_hall": (12, -8, "start"), "lookout_blade": (8, -6, "start"),
    "colony_gate": (10, 14, "start"), "patrol_gate": (10, 4, "start"),
    "hose_coupling": (12, -6, "start"), "popsicle_stick": (8, -22, "start"),
    "abandoned_post": (-10, 4, "end"), "termite_camp": (0, 30, "middle"), "termite_tower": (8, -6, "start"),
    "spider_burrow": (0, 18, "middle"), "trip_lines": (40, -4, "start"),
}


def render(layout):
    out = []
    a = out.append
    a(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
      f'font-family="-apple-system, Helvetica, Arial, sans-serif">')
    a("""<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="#e8641b"/></marker>
  <marker id="sky" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto">
    <path d="M0,0 L10,5 L0,10 z" fill="#6b675d"/></marker>
  <pattern id="tuss" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(35)">
    <rect width="6" height="6" fill="#476e37"/><line x1="0" y1="0" x2="0" y2="6" stroke="#2f4d24" stroke-width="2.2"/></pattern>
  <pattern id="litter" width="8" height="8" patternUnits="userSpaceOnUse" patternTransform="rotate(-20)">
    <rect width="8" height="8" fill="#a4814f"/><circle cx="3" cy="3" r="1.6" fill="#8a6a3d"/></pattern>
  <radialGradient id="mist"><stop offset="0" stop-color="#ffffff" stop-opacity="0.75"/>
    <stop offset="1" stop-color="#cfe8f3" stop-opacity="0"/></radialGradient>
  <linearGradient id="canopy" x1="0" x2="1"><stop offset="0" stop-color="#1f3b1a" stop-opacity="0.28"/>
    <stop offset="1" stop-color="#1f3b1a" stop-opacity="0"/></linearGradient>
</defs>""")
    a(f'<rect width="{W}" height="{H}" fill="{COL["paper"]}"/>')

    # Title
    a(text(M, 44, "Level 1 — The Lawn", 26, 700, halo=False))
    a(text(M, 68, "Top-down layout · 720 m × 720 m in game (2 m × 2 m of real lawn, scale ×360) · 07:30, early summer",
           12.5, 400, fill=COL["muted"], halo=False))
    a(f'<g transform="translate(0,{TOP})">')

    # Lawn base and canopy shade (the Big Oak is west; shade deepens toward it)
    a(f'<rect x="{px(-360)}" y="{pz(-360)}" width="{MAPPX}" height="{MAPPX}" fill="{COL["lawn"]}"/>')
    a(f'<rect x="{px(-360)}" y="{pz(-360)}" width="{MAPPX * 0.55:.1f}" height="{MAPPX}" fill="url(#canopy)"/>')

    # Boundaries
    a(f'<rect x="{px(-360)}" y="{pz(-360)}" width="{MAPPX}" height="{15 * S}" fill="{COL["patio"]}"/>')
    a(f'<rect x="{px(345)}" y="{pz(-360)}" width="{15 * S}" height="{MAPPX}" fill="{COL["stones"]}"/>')
    for k in range(5):  # stepping-stone joints
        a(f'<line x1="{px(345)}" y1="{pz(-360 + 144 * k)}" x2="{px(360)}" y2="{pz(-360 + 144 * k)}" stroke="#8f887a" stroke-width="1.5"/>')
    a(f'<rect x="{px(-360)}" y="{pz(345)}" width="{MAPPX}" height="{15 * S}" fill="{COL["brick"]}"/>')
    a(f'<rect x="{px(-360)}" y="{pz(-360)}" width="{10 * S}" height="{MAPPX}" fill="url(#litter)"/>')

    # Big Oak trunk (mostly beyond the west edge)
    trunk = by_id(layout["skyline"], "oak_trunk")
    tx, tz = trunk["pos"]
    a(f'<circle cx="{px(tx)}" cy="{pz(tz)}" r="{trunk["size"][0] / 2 * S:.1f}" fill="#6b4a2b" stroke="#4a321c" stroke-width="2"/>')

    # Areas
    for ar in layout["areas"]:
        (cx, cz), (rx, rz) = ar["center"], ar["radii"]
        a(f'<ellipse cx="{px(cx):.1f}" cy="{pz(cz):.1f}" rx="{rx * S:.1f}" ry="{rz * S:.1f}" '
          f'fill="{AREA_TINT[ar["id"]]}" fill-opacity="0.55" stroke="{COL["ink"]}" stroke-opacity="0.35" stroke-dasharray="4 4"/>')

    # Barriers and water
    for b in layout["barriers"]:
        a(f'<polygon points="{pts_attr(b["polygon"])}" fill="url(#tuss)" stroke="#2f4d24" stroke-width="1"/>')
    for w in layout["water"]:
        a(f'<polygon points="{pts_attr(w["polygon"])}" fill="{COL["water"]}" stroke="{COL["water_edge"]}" stroke-width="1.5"/>')

    paths = {p["id"]: p for p in layout["paths"]}
    a(f'<polyline points="{pts_attr(paths["runoff"]["points"])}" fill="none" stroke="{COL["water"]}" stroke-width="3" stroke-linecap="round"/>')

    # Roots
    for p in layout["paths"]:
        if p["kind"] == "root":
            a(f'<polyline points="{pts_attr(p["points"])}" fill="none" stroke="{COL["root"]}" '
              f'stroke-width="{p["width"] * S:.1f}" stroke-linecap="round" stroke-linejoin="round"/>')

    # Hose, mist, coupling
    cpl = by_id(layout["landmarks"], "hose_coupling")
    a(f'<circle cx="{px(cpl["pos"][0] - 20)}" cy="{pz(cpl["pos"][1] - 10)}" r="{45 * S}" fill="url(#mist)"/>')
    a(f'<polyline points="{pts_attr(paths["hose"]["points"])}" fill="none" stroke="{COL["hose"]}" '
      f'stroke-width="{paths["hose"]["diameter"] * S:.1f}" stroke-linecap="butt" stroke-linejoin="round"/>')
    a(f'<rect x="{px(cpl["pos"][0]) - 8}" y="{pz(cpl["pos"][1]) - 6}" width="16" height="12" rx="3" fill="{COL["brass"]}" stroke="#8a6b1f"/>')

    # Pencil log
    a(f'<polyline points="{pts_attr(paths["pencil"]["points"])}" fill="none" stroke="#e4b73b" stroke-width="4" stroke-linecap="round"/>')

    # Ant roads, termite trail
    for p in layout["paths"]:
        if p["kind"] == "ant_road":
            a(f'<polyline points="{pts_attr(p["points"])}" fill="none" stroke="{COL["antroad"]}" stroke-width="2" '
              f'stroke-dasharray="1 5" stroke-linecap="round" opacity="0.9"/>')
    a(f'<polyline points="{pts_attr(paths["termite_trail"]["points"])}" fill="none" stroke="{COL["termite"]}" '
      f'stroke-width="2.2" stroke-dasharray="6 4"/>')

    # Main routes and shortcut
    for p in layout["paths"]:
        if p["kind"] == "main_route":
            a(f'<polyline points="{pts_attr(p["points"])}" fill="none" stroke="{COL["route"]}" stroke-width="3.2" '
              f'stroke-linejoin="round" stroke-linecap="round" marker-end="url(#arrow)" marker-mid="url(#arrow)"/>')
        elif p["kind"] == "shortcut":
            a(f'<polyline points="{pts_attr(p["points"])}" fill="none" stroke="{COL["route"]}" stroke-width="2.4" '
              f'stroke-dasharray="2 5" stroke-linecap="round"/>')

    # Popsicle stick
    st = by_id(layout["landmarks"], "popsicle_stick")
    (sx, sz), (sw, _, sl) = st["pos"], st["size"]
    a(f'<rect x="{px(sx - sw / 2):.1f}" y="{pz(sz - sl / 2):.1f}" width="{max(sw * S, 4):.1f}" height="{sl * S:.1f}" '
      f'rx="2" fill="{COL["stick"]}" stroke="#9c7b43"/>')

    # Landmarks (footprint to scale, minimum marker size)
    skip_shape = {"popsicle_stick", "hose_coupling", "pencil_log", "pot_ring", "trip_lines", "termite_camp"}
    pr = by_id(layout["landmarks"], "pot_ring")
    a(f'<circle cx="{px(pr["pos"][0])}" cy="{pz(pr["pos"][1])}" r="{pr["size"][0] / 2 * S}" fill="none" '
      f'stroke="#8a6d49" stroke-width="3" stroke-opacity="0.7"/>')
    tl = by_id(layout["landmarks"], "trip_lines")
    for k in range(4):
        a(f'<line x1="{px(-282)}" y1="{pz(235 + k * 6)}" x2="{px(-232)}" y2="{pz(228 + k * 8)}" stroke="#f4f1ea" stroke-width="1" opacity="0.9"/>')
    tc = by_id(layout["landmarks"], "termite_camp")
    for dx, dz, r in ((-18, -6, 5), (-4, 8, 6), (10, -4, 4.5), (22, 10, 5), (0, -14, 4)):
        a(f'<circle cx="{px(tc["pos"][0] + dx)}" cy="{pz(tc["pos"][1] + dz)}" r="{r * S}" fill="#9b6a43" stroke="{COL["termite"]}" stroke-width="1.2"/>')
    for lm in layout["landmarks"]:
        if lm["id"] in skip_shape:
            continue
        x, z = lm["pos"]
        w, _, d = lm["size"]
        rw, rd = max(w * S, 5), max(d * S, 5)
        fill = {"backpack": "#3d5a80", "marble": "#9ad0e6", "bottle_cap": "#d64541", "colony_gate": "#2b2a26",
                "coin_plaza": "#b8b8b8", "lego_waystation": "#e53935", "spider_burrow": "#1d1b1f",
                "abandoned_post": "#c7a36a", "termite_tower": "#9b6a43", "oak_root_hall": "#3a2716"}.get(lm["id"], "#5d4a36")
        if lm["id"].startswith("acorn"):
            fill = "#8b5a2b"
        if lm["id"].startswith("oak_leaf"):
            a(f'<ellipse cx="{px(x)}" cy="{pz(z)}" rx="{w * S / 2}" ry="{d * S / 2}" fill="#c08a3e" stroke="#7a5634" '
              f'transform="rotate(-25 {px(x)} {pz(z)})"/>')
            continue
        a(f'<rect x="{px(x) - rw / 2:.1f}" y="{pz(z) - rd / 2:.1f}" width="{rw:.1f}" height="{rd:.1f}" rx="{min(rw, rd) / 3:.1f}" '
          f'fill="{fill}" stroke="#1d1b1f" stroke-width="0.8"/>')

    for lm in layout["landmarks"]:
        if lm["id"] in LABELS:
            dx, dy, anc = LABELS[lm["id"]]
            name = lm["name"].split(" (")[0].split(" / ")[0]
            a(text(px(lm["pos"][0]) + dx, pz(lm["pos"][1]) + dy, name, 10.5, 500, anc))

    # Area numbers and names
    name_off = {"hose_run": (38, 60), "popsicle_bridge": (0, -46), "bare_patch": (0, -40), "capstone_shelter": (0, 44),
                "spiders_edge": (26, -40), "oak_rootlands": (40, 8), "dewdrop_garden": (50, -30),
                "backpack_hollow": (-120, 10), "blade_forest": (0, 12)}
    for ar in layout["areas"]:
        cx, cz = ar["center"]
        ox, oy = name_off.get(ar["id"], (0, 0))
        X, Y = px(cx) + ox, pz(cz) + oy
        a(f'<circle cx="{X - 0:.1f}" cy="{Y - 22:.1f}" r="11" fill="{COL["ink"]}"/>')
        a(text(X, Y - 18, str(ar["order"]), 12, 700, "middle", fill="#fff", halo=False))
        a(text(X, Y + 2, ar["name"], 14, 700, "middle"))

    # Viewpoints
    for vp in layout["viewpoints"]:
        (x, z), (lx, lz) = vp["pos"], vp["look_at"]
        ang = math.atan2(pz(lz) - pz(z), px(lx) - px(x))
        tip = (px(x) + 16 * math.cos(ang), pz(z) + 16 * math.sin(ang))
        l = (px(x) + 7 * math.cos(ang + 2.2), pz(z) + 7 * math.sin(ang + 2.2))
        r = (px(x) + 7 * math.cos(ang - 2.2), pz(z) + 7 * math.sin(ang - 2.2))
        a(f'<polygon points="{tip[0]:.1f},{tip[1]:.1f} {l[0]:.1f},{l[1]:.1f} {r[0]:.1f},{r[1]:.1f}" fill="#7b3fa0" stroke="#fff" stroke-width="1"/>')
        a(text(px(x) - 6, pz(z) - 7, vp["id"], 10, 700, "end", fill="#7b3fa0"))

    # Spawn
    sx0, sz0 = layout["spawn"]["pos"]
    a(f'<circle cx="{px(sx0)}" cy="{pz(sz0)}" r="6" fill="#fff" stroke="{COL["route"]}" stroke-width="3"/>')
    a(text(px(sx0) + 10, pz(sz0) + 16, "Start", 11, 700, fill=COL["route"]))

    # Skyline bearings around the frame
    cxp, czp = px(0), pz(0)
    half = MAPPX / 2
    ring = half + 28
    for sk in layout["skyline"]:
        if "pos" not in sk:
            continue
        x, z = sk["pos"]
        dist = math.hypot(x, z)
        if sk["id"] == "oak_trunk":  # drawn on the map itself; label it beside the trunk
            a(text(M - 118, pz(-128), "Big Oak (trunk)", 11, 700, "start", halo=False))
            a(text(M - 118, pz(-128) + 13, f"{dist:.0f} m · 216 m wide", 10, 400, "start", fill=COL["muted"], halo=False))
            continue
        ang = math.atan2(z, x)
        # project to a square ring just outside the map
        k = ring / max(abs(math.cos(ang)), abs(math.sin(ang)))
        ex, ey = cxp + k * math.cos(ang), czp + k * math.sin(ang)
        k2 = (half + 4) / max(abs(math.cos(ang)), abs(math.sin(ang)))
        bx_, by_ = cxp + k2 * math.cos(ang), czp + k2 * math.sin(ang)
        a(f'<line x1="{bx_:.1f}" y1="{by_:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="{COL["muted"]}" stroke-width="1.4" marker-end="url(#sky)"/>')
        dtxt = f"{dist / 1000:.1f} km" if dist >= 1000 else f"{dist:.0f} m"
        hgt = sk["size"][1]
        htxt = f"{hgt / 1000:.1f} km tall" if hgt >= 1000 else f"{hgt:.0f} m tall"
        cosA, sinA = math.cos(ang), math.sin(ang)
        anchor = "middle" if abs(cosA) < 0.45 else ("start" if cosA > 0 else "end")
        lx = ex + 6 * cosA
        ly = ey + (16 if sinA > 0.45 else (-24 if sinA < -0.45 else 4))
        a(text(lx, ly, sk["name"].replace(" (parked)", ""), 11, 700, anchor, halo=False))
        a(text(lx, ly + 13, f"{dtxt} · {htxt}", 10, 400, anchor, fill=COL["muted"], halo=False))

    # Frame, compass, scale bar
    a(f'<rect x="{px(-360)}" y="{pz(-360)}" width="{MAPPX}" height="{MAPPX}" fill="none" stroke="{COL["ink"]}" stroke-width="1.2"/>')
    nx, ny = px(360) - 30, 52
    a(f'<polygon points="{nx},{ny - 18} {nx - 8},{ny + 6} {nx},{ny} {nx + 8},{ny + 6}" fill="{COL["ink"]}"/>')
    a(text(nx, ny + 22, "N", 12, 700, "middle", halo=False))
    sbx, sby = px(-360), pz(360) + 34
    a(f'<rect x="{sbx}" y="{sby}" width="{100 * S}" height="6" fill="{COL["ink"]}"/>')
    a(f'<rect x="{sbx + 100 * S}" y="{sby}" width="{100 * S}" height="6" fill="none" stroke="{COL["ink"]}"/>')
    a(text(sbx, sby + 22, "0", 10, 400, "middle", halo=False))
    a(text(sbx + 100 * S, sby + 22, "100 m (28 cm real)", 10, 400, "middle", halo=False))
    a(text(sbx + 200 * S, sby + 22, "200 m", 10, 400, "middle", halo=False))
    a(text(sbx, sby + 42, "Amodu = 1.8 m · a run across the box ≈ 2 min", 10.5, 400, "start", fill=COL["muted"], halo=False))

    # Legend
    ly = pz(360) + 118
    items = [
        ("line", COL["route"], "Main route", "3.2", None), ("line", COL["route"], "Shortcut (root tunnel)", "2.4", "2 5"),
        ("line", COL["antroad"], "Ant road", "2", "1 5"), ("line", COL["termite"], "Termite trail", "2.2", "6 4"),
        ("line", COL["root"], "Oak roots (walls)", "8", None), ("line", COL["hose"], "Garden hose", "7", None),
        ("box", COL["water"], "The Rut (water = defeat)", None, None), ("box", "url(#tuss)", "Tussock (impassable)", None, None),
        ("tri", "#7b3fa0", "Viewpoint (sight-line check)", None, None),
    ]
    col_w = MAPPX / 3
    for n, (kind, color, label, sw, dash) in enumerate(items):
        cx0 = px(-360) + (n % 3) * col_w
        cy0 = ly + (n // 3) * 24
        if kind == "line":
            d = f' stroke-dasharray="{dash}"' if dash else ""
            a(f'<line x1="{cx0}" y1="{cy0}" x2="{cx0 + 30}" y2="{cy0}" stroke="{color}" stroke-width="{sw}" stroke-linecap="round"{d}/>')
        elif kind == "box":
            a(f'<rect x="{cx0}" y="{cy0 - 7}" width="30" height="14" fill="{color}" stroke="#2b2a26" stroke-width="0.6"/>')
        else:
            a(f'<polygon points="{cx0 + 22},{cy0} {cx0 + 8},{cy0 - 7} {cx0 + 8},{cy0 + 7}" fill="{color}"/>')
        a(text(cx0 + 40, cy0 + 4, label, 11.5, 400, halo=False))

    a("</g>")
    a("</svg>")
    MAP_OUT.write_text("\n".join(out))
    print(f"wrote {MAP_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    layout = json.loads(LAYOUT.read_text())
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        sys.exit(0 if check(layout) else 1)
    elif cmd == "render":
        render(layout)
    else:
        sys.exit(__doc__)
