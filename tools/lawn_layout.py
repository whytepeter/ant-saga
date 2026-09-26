#!/usr/bin/env python3
"""Validate and render the Lawn layout (world/lawn/layout.json).

    python3 tools/lawn_layout.py check    # connectivity + sanity checks, exit 1 on failure
    python3 tools/lawn_layout.py render   # writes docs/lawn_map.svg
    python3 tools/lawn_layout.py bake     # writes the height / surface / grass-density grids
    python3 tools/lawn_layout.py fmt      # rewrites layout.json in the compact house style

layout.json is the single source of truth for Level 1 coordinates; the graybox
builder reads the same file, so this check guards the level before it exists.
"""

import json
import math
import random
import struct
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
    trunk = by_id(layout["skyline"], "apple_tree")
    g.block_circle(trunk["pos"][0], trunk["pos"][1], trunk["size"][0] / 2, "apple_tree")
    for b in layout["barriers"]:
        g.block_polygon(b["polygon"], b["id"])
    for w in layout["water"]:
        g.block_polygon(w["polygon"], w["id"])
    for p in layout["paths"]:
        if p["kind"] == "root":
            g.block_polyline(p["points"], p["width"] / 2, p["id"])
    if bridge:
        stick = by_id(layout["landmarks"], "lolly_stick")
        (cx, cz), (sw, _, sl) = stick["pos"], stick["size"]
        g.block_polygon([[cx - sw / 2, cz - sl / 2], [cx + sw / 2, cz - sl / 2],
                         [cx + sw / 2, cz + sl / 2], [cx - sw / 2, cz + sl / 2]], None, value=False)
    if tunnel:
        g.block_polyline(by_id(layout["paths"], "root_tunnel")["points"], 2.0, None, value=False)
    return g


# ── check ─────────────────────────────────────────────────────────────────────

# Landmarks you can walk over, through or under (or that the builder keeps a lane through).
WALKABLE = {"pot_ring", "trip_lines", "orb_web", "colony_gate", "lolly_stick", "spider_burrow",
            "coin_plaza", "termite_camp", "abandoned_post", "pencil_log", "root_hall", "crisp_packet"}
STANDIN_RADIUS = {"ant": 1.4, "pill_bug": 2.8, "wolf_spider": 5.5}  # spider: solid body only, the legs are visual


def solid_obstacles(layout, margin=0.6):
    """(name, test(x, z)) pairs for footprints a walking player collides with."""
    obs = []
    for lm in layout["landmarks"]:
        if lm["id"] in WALKABLE or lm["id"].startswith("fallen_leaf"):
            continue
        (cx, cz), (w, _, d) = lm["pos"], lm["size"]
        hw, hd = w / 2 + margin, d / 2 + margin
        centers = [lm["pos"]] + lm.get("also", [])
        obs.append((lm["id"], lambda x, z, cs=centers, hw=hw, hd=hd: any(abs(x - c[0]) < hw and abs(z - c[1]) < hd for c in cs)))
    for sd in layout.get("standins", []):
        r = STANDIN_RADIUS.get(sd["kind"], 1.5) + margin
        (cx, cz) = sd["pos"]
        obs.append((sd["name"], lambda x, z, cx=cx, cz=cz, r=r: math.hypot(x - cx, z - cz) < r))
    for fl in layout.get("flowers", []):
        (cx, cz), r = fl["pos"], 2.0 + margin  # the stem and its leaves; the head is overhead
        obs.append((f'{fl["kind"]} stem', lambda x, z, cx=cx, cz=cz, r=r: math.hypot(x - cx, z - cz) < r))
    return obs


def check(layout):
    failures = []
    ok = lambda msg: print(f"  ok    {msg}")

    def fail(msg):
        failures.append(msg)
        print(f"  FAIL  {msg}")

    spawn = layout["spawn"]["pos"]
    south_areas = {"windfall_roots", "spiders_edge"}

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
        elif a["id"] not in south_areas and not reach and a["id"] != "lolly_bridge":
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

    print("Routes keep clear of solid props")
    before = len(failures)
    obstacles = solid_obstacles(layout)
    for p in layout["paths"]:
        if p["kind"] not in ("main_route", "shortcut"):
            continue
        pts = p["points"]
        hit = None
        for k in range(len(pts) - 1):
            (ax, az), (bx, bz) = pts[k], pts[k + 1]
            steps = max(1, int(math.hypot(bx - ax, bz - az)))
            for s in range(steps + 1):
                x, z = ax + (bx - ax) * s / steps, az + (bz - az) * s / steps
                for name, test in obstacles:
                    if test(x, z):
                        hit = (k, x, z, name)
                        break
                if hit:
                    break
            if hit:
                break
        if hit:
            fail(f"{p['id']} segment {hit[0]} runs into '{hit[3]}' at ({hit[1]:.0f}, {hit[2]:.0f})")
    if len(failures) == before:
        ok("no route passes through a landmark or creature stand-in")

    print("Patio and the way home")
    before = len(failures)
    patio = layout.get("patio")
    if patio:
        full = build_grid(layout)
        seen_full = full.flood(spawn)
        foot = patio["trowel"]["from"]
        i, j = full.to_cell(*foot)
        if full.is_blocked(*foot) or not seen_full[j][i]:
            fail(f"trowel foot {foot} can't be reached from the spawn")
        if not (patio["trowel"]["to"][1] >= patio["edge_z"] and foot[1] < patio["edge_z"]):
            fail("the trowel must run from the lawn up onto the patio")
        sx0, sz0, sx1, sz1 = patio["step"]["rect"]
        bx, bz = patio["brush"]["to"]
        if not (sx0 <= bx <= sx1 and sz0 <= bz <= sz1):
            fail("the brush must lean on the back step")
        dx0, dx1 = patio["door"]["x"]
        hx, hz = patio["home"]
        if not (dx0 <= hx <= dx1 and hz > patio["wall_z"]):
            fail("home must be just inside the back door")
    fl_bad = [f for f in layout.get("flowers", []) if not layout["areas"] or
              not any(math.hypot((f["pos"][0] - a["center"][0]) / a["radii"][0], (f["pos"][1] - a["center"][1]) / a["radii"][1]) < 1.0
                      for a in layout["areas"] if a["id"] == "flower_bed")]
    if fl_bad:
        fail(f"{len(fl_bad)} flower(s) outside the Flower Bed")
    if len(failures) == before:
        ok("trowel reachable, brush on the step, home inside the door, flowers in their bed")

    print("Expedition (Phase 3c)")
    before = len(failures)
    exp = layout.get("expedition", {})
    solid = [(n, t) for n, t in obstacles if n not in ("Pill bug", "Young pill bug")]  # live creatures on a run
    for job in exp.get("jobs", []):
        pts = job["haul_path"]
        if pts[0] != job["prize"]["pos"]:
            fail(f"{job['id']}: haul_path must start at the prize")
        gate = next(lm for lm in layout["landmarks"] if lm["id"] == "colony_gate")["pos"]
        if math.hypot(pts[-1][0] - gate[0], pts[-1][1] - gate[1]) > 2:
            fail(f"{job['id']}: haul_path must end at the Colony Gate")
        hit = None
        for k in range(len(pts) - 1):
            (ax, az), (bx, bz) = pts[k], pts[k + 1]
            steps = max(1, int(math.hypot(bx - ax, bz - az)))
            for st in range(steps + 1):
                x, z = ax + (bx - ax) * st / steps, az + (bz - az) * st / steps
                if g.is_blocked(x, z):
                    hit = (k, x, z, "a wall")
                for name, test in solid:
                    if test(x, z):
                        hit = (k, x, z, name)
                if hit:
                    break
            if hit:
                break
        if hit:
            fail(f"{job['id']}: haul_path segment {hit[0]} runs into {hit[3]} at ({hit[1]:.0f}, {hit[2]:.0f})")
        spots = [("worker", w) for w in job["workers"] + job.get("storage_workers", [])]
        spots += [(pr["name"], pr["pos"]) for pr in job.get("props", []) + job.get("pill_bugs", [])]
        for name, (x, z) in spots:
            if not (x0 <= x <= x1 and z0 <= z <= z1) or g.is_blocked(x, z) or any(t(x, z) for _, t in solid):
                fail(f"{job['id']}: {name} at ({x}, {z}) is inside something or out of bounds")
        L = sum(math.hypot(pts[k + 1][0] - pts[k][0], pts[k + 1][1] - pts[k][1]) for k in range(len(pts) - 1))
        print(f"  info  {job['id']}: haul {L:.0f} m, {L / 1.6 / 60:.1f} min at the 1.6 m/s base carry speed")
    if len(failures) == before:
        ok("haul paths clear, job spots free")

    print("Route length")
    speed = 4.5  # m/s, Amodu jog (player.gd jog_speed)
    for p in layout["paths"]:
        if p["kind"] == "main_route":
            L = sum(math.hypot(p["points"][k + 1][0] - p["points"][k][0], p["points"][k + 1][1] - p["points"][k][1])
                    for k in range(len(p["points"]) - 1))
            print(f"  info  {p['id']}: {L:.0f} m, {L / speed / 60:.1f} min at a {speed} m/s jog")

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
    "backpack_hollow": "#f3e7b0", "blade_forest": "#6f9d52", "flower_bed": "#bfe3ea",
    "capstone_shelter": "#f0d6a8", "bare_patch": "#c9ad83", "hose_run": "#cfe8f3",
    "lolly_bridge": "#e9d9b4", "windfall_roots": "#b89a74", "spiders_edge": "#8c7a86",
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
    "dandelion": (9, 4, "start"), "dandelion_clock": (-9, 4, "end"),
    "crisp_packet": (0, -26, "middle"), "marble": (-8, 4, "end"), "orb_web": (10, 4, "start"),
    "root_hall": (12, -8, "start"), "lookout_blade": (8, -6, "start"),
    "colony_gate": (10, 14, "start"), "patrol_gate": (10, 4, "start"),
    "hose_coupling": (12, -6, "start"), "lolly_stick": (8, -22, "start"),
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
    a(text(M, 44, "Level 1 — The Compound Grass", 26, 700, halo=False))
    a(text(M, 68, "Top-down layout · 720 m × 720 m in game (2 m × 2 m of real ground, scale ×360) · 07:30, rainy-season morning",
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
    trunk = by_id(layout["skyline"], "apple_tree")
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

    # Flower Bed climb: daisy and buttercup heads
    for fl in layout.get("flowers", []):
        col = "#fbf6e6" if fl["kind"] == "daisy" else "#f3c623"
        a(f'<circle cx="{px(fl["pos"][0])}" cy="{pz(fl["pos"][1])}" r="{fl["head"] * S:.1f}" fill="{col}" stroke="#c9a13b" stroke-width="1"/>')

    # The patio beyond the south edge, and the trowel ramp up onto it
    patio = layout.get("patio")
    if patio:
        a(f'<rect x="{px(-360)}" y="{pz(patio["edge_z"])}" width="{720 * S}" height="{(M - 20)}" fill="#cfc8bc" stroke="#8f877a" stroke-width="1"/>')
        for k in range(-360, 361, int(patio["slab"])):
            a(f'<line x1="{px(k)}" y1="{pz(patio["edge_z"])}" x2="{px(k)}" y2="{pz(patio["edge_z"]) + M - 20}" stroke="#9e968a" stroke-width="1"/>')
        t = patio["trowel"]
        a(f'<line x1="{px(t["from"][0])}" y1="{pz(t["from"][1])}" x2="{px(t["to"][0])}" y2="{pz(t["to"][1])}" stroke="#7d8a92" stroke-width="{t["width"] * S:.1f}" stroke-linecap="round"/>')

    # Expedition haul paths and prizes (Phase 3c)
    for job in layout.get("expedition", {}).get("jobs", []):
        a(f'<polyline points="{pts_attr(job["haul_path"])}" fill="none" stroke="#f2c14e" stroke-width="2.4" '
          f'stroke-dasharray="4 3" stroke-linecap="round" opacity="0.95"/>')
        pz_, pr_ = job["prize"]["pos"], job["prize"]["size"] / 2
        a(f'<circle cx="{px(pz_[0])}" cy="{pz(pz_[1])}" r="{max(pr_ * S, 4):.1f}" fill="#c9782a" stroke="#fff" stroke-width="1.5"/>')

    # Main routes and shortcut
    for p in layout["paths"]:
        if p["kind"] == "main_route":
            a(f'<polyline points="{pts_attr(p["points"])}" fill="none" stroke="{COL["route"]}" stroke-width="3.2" '
              f'stroke-linejoin="round" stroke-linecap="round" marker-end="url(#arrow)" marker-mid="url(#arrow)"/>')
        elif p["kind"] == "shortcut":
            a(f'<polyline points="{pts_attr(p["points"])}" fill="none" stroke="{COL["route"]}" stroke-width="2.4" '
              f'stroke-dasharray="2 5" stroke-linecap="round"/>')

    # Popsicle stick
    st = by_id(layout["landmarks"], "lolly_stick")
    (sx, sz), (sw, _, sl) = st["pos"], st["size"]
    a(f'<rect x="{px(sx - sw / 2):.1f}" y="{pz(sz - sl / 2):.1f}" width="{max(sw * S, 4):.1f}" height="{sl * S:.1f}" '
      f'rx="2" fill="{COL["stick"]}" stroke="#9c7b43"/>')

    # Landmarks (footprint to scale, minimum marker size)
    skip_shape = {"lolly_stick", "hose_coupling", "pencil_log", "pot_ring", "trip_lines", "termite_camp"}
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
        fill = {"backpack": "#3d5a80", "marble": "#9ad0e6", "crown_cap": "#d64541", "colony_gate": "#2b2a26",
                "coin_plaza": "#c9a13b", "crisp_packet": "#cfe6f2", "spider_burrow": "#1d1b1f",
                "abandoned_post": "#c7a36a", "termite_tower": "#9b6a43", "root_hall": "#3a2716", "bead_shrine": "#d8432c"}.get(lm["id"], "#5d4a36")
        if lm["id"] in ("fallen_apple", "windfall_apple"):
            fill = "#e0a526"
        if lm["id"] == "apple_core":
            fill = "#c9b07a"
        if lm["id"].startswith("fallen_leaf"):
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
    name_off = {"hose_run": (38, 60), "lolly_bridge": (0, -46), "bare_patch": (0, -40), "capstone_shelter": (0, 44),
                "spiders_edge": (26, -40), "windfall_roots": (40, 8), "flower_bed": (50, -30),
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
        if sk["id"] == "apple_tree":  # drawn on the map itself; label it beside the trunk
            a(text(M - 118, pz(-128), "Mango tree (trunk)", 11, 700, "start", halo=False))
            a(text(M - 118, pz(-128) + 13, f"{dist:.0f} m · {sk['size'][0]:.0f} m wide", 10, 400, "start", fill=COL["muted"], halo=False))
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
    a(text(sbx, sby + 42, "Amodu = 1.8 m · jog 4.5 m/s, sprint 6 m/s · crossing the box ≈ 2.7 min jogging", 10.5, 400, "start", fill=COL["muted"], halo=False))

    # Legend
    ly = pz(360) + 118
    items = [
        ("line", COL["route"], "Main route", "3.2", None), ("line", COL["route"], "Shortcut (root tunnel)", "2.4", "2 5"),
        ("line", COL["antroad"], "Ant road", "2", "1 5"), ("line", COL["termite"], "Termite trail", "2.2", "6 4"),
        ("line", COL["root"], "Oak roots (walls)", "8", None), ("line", COL["hose"], "Garden hose", "7", None),
        ("box", COL["water"], "The Rut (tyre rut, water = defeat)", None, None), ("box", "url(#tuss)", "Tussock (impassable)", None, None),
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



# ── bake ──────────────────────────────────────────────────────────────────────
#
# Grids sampled at every vertex of a 2 m lattice over the playable box
# (361 x 361). The Godot builder (world/lawn/lawn_builder.gd) reads them to make
# the terrain, its collision, and to plant grass; LawnLayout.gd mirrors the
# surface codes below.

SURFACE = {"lawn": 0, "bare_soil": 1, "mud": 2, "leaf_litter": 3, "water": 4,
           "flattened": 5, "tussock": 6, "clover": 7, "ant_road": 8}

FILL = 10.0  # standing blades per 100 m² in ordinary lawn (one per 10 m²)


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def base_relief(x, z):
    """Gentle lawn undulation, about ±1.1 m (±3 mm real)."""
    return (0.55 * math.sin(x / 47.0 + 1.3) * math.cos(z / 61.0 - 0.4)
            + 0.35 * math.sin((x + z) / 29.0 + 0.7)
            + 0.2 * math.sin(x / 13.7) * math.sin(z / 17.1 + 2.0))


# ── the floor's own relief ────────────────────────────────────────────────────
# At 5 mm a lawn's floor is anything but flat: crumbs of earth heaped into
# mounds, worm-cast humps, dips where rain pooled. Soft rolling ground plus
# scattered mounds (1–4.6 m high, 18–68 m across), smooth enough to walk over
# (slopes under ~30°) and real terrain, so they collide. Kept off the props, the
# hollow Amodu wakes in, the Bare Patch dish, the runoff, the Rut's banks and the
# tree's bank (relief_mask); routes keep their lumps but no mounds.

RELIEF_PAD = 8.0
MOUNDS = 90
_PERM = list(range(256))
random.Random(360).shuffle(_PERM)
_PERM += _PERM
_GRAD = [(math.cos(k * math.pi / 4), math.sin(k * math.pi / 4)) for k in range(8)]


def noise2(x, z):
    """2D gradient noise, roughly -1..1."""
    xi, zi = math.floor(x), math.floor(z)
    xf, zf = x - xi, z - zi
    xi &= 255
    zi &= 255
    u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    v = zf * zf * zf * (zf * (zf * 6 - 15) + 10)

    def g(ix, iz, dx, dz):
        gx, gz = _GRAD[_PERM[_PERM[ix] + iz] & 7]
        return gx * dx + gz * dz

    n00 = g(xi, zi, xf, zf)
    n10 = g(xi + 1, zi, xf - 1, zf)
    n01 = g(xi, zi + 1, xf, zf - 1)
    n11 = g(xi + 1, zi + 1, xf - 1, zf - 1)
    return 1.4 * (n00 + u * (n10 - n00) + v * (n01 - n00) + u * v * (n00 - n10 - n01 + n11))


def rolling(x, z):
    """Soft rolls (±1 m) and lumps underfoot (±0.3 m)."""
    return (0.7 * noise2(x / 38.0, z / 38.0) + 0.35 * noise2(x / 17.0 + 5.3, z / 17.0 + 9.1)
            + 0.3 * noise2(x / 7.5 + 13.7, z / 7.5 + 2.9))


class ReliefContext:
    def __init__(self, layout, feats):
        self.feats = feats
        self.areas = {a["id"]: a for a in layout["areas"]}
        ring = by_id(layout["landmarks"], "pot_ring")
        self.ring_c, self.ring_r = ring["pos"], ring["size"][0] / 2
        self.runoff = by_id(layout["paths"], "runoff")["points"]
        self.rut = layout["water"][0]["polygon"]
        self.patio_z = layout["patio"]["edge_z"] if "patio" in layout else 1e9
        self.rut_box = (min(p[0] for p in self.rut) - 40, min(p[1] for p in self.rut) - 40,
                        max(p[0] for p in self.rut) + 40, max(p[1] for p in self.rut) + 40)
        tb = layout.get("tree_base")
        self.tree = (tb["trunk"]["center"], tb["bank"]["outer"]) if tb else None


def relief_mask(ctx, x, z):
    """1 where the ground may heave freely, 0 where it must stay as laid out."""
    edge = min(x + 360, 360 - x, z + 360, 360 - z)
    m = smoothstep(0, 25, edge) * smoothstep(ctx.patio_z, ctx.patio_z - 30, z)
    if m <= 0.0:
        return 0.0
    for f in ctx.feats:
        if f.near(x, z):
            d = f.distance(x, z)
            if f.soft:
                m *= 0.45 + 0.55 * smoothstep(f.clear, f.clear + f.ramp + 4, d)
            else:
                m *= smoothstep(f.clear, f.clear + f.ramp + RELIEF_PAD, d)
    m *= smoothstep(1.0, 1.5, ellipse_q(x, z, ctx.areas["backpack_hollow"]))
    m *= smoothstep(1.0, 1.4, ellipse_q(x, z, ctx.areas["lolly_bridge"]))
    m *= smoothstep(ctx.ring_r + 15, ctx.ring_r + 40, math.hypot(x - ctx.ring_c[0], z - ctx.ring_c[1]))
    if -30 < x < 270 and -80 < z < 190:
        m *= smoothstep(4, 14, dist_to_polyline(x, z, ctx.runoff))
    if ctx.tree:
        c, outer = ctx.tree
        m *= smoothstep(outer + 5, outer + 35, math.hypot(x - c[0], z - c[1]))
    rb = ctx.rut_box
    if m > 0.0 and rb[0] <= x <= rb[2] and rb[1] <= z <= rb[3]:
        m *= smoothstep(8, 40, signed_poly_distance(x, z, ctx.rut))
    return m


def place_mounds(ctx):
    """[(cx, cz, a, b, angle, height)], each clear of everything relief_mask protects."""
    rnd = random.Random(2026)
    mounds = []
    for _ in range(6000):
        if len(mounds) >= MOUNDS:
            break
        cx, cz = rnd.uniform(-335, 335), rnd.uniform(-335, 315)
        h = 1.0 + 3.6 * rnd.random() ** 1.8
        b = max(rnd.uniform(9.0, 20.0), 3.0 * h)  # never steeper than ~27°
        a = b * rnd.uniform(1.0, 1.7)
        th = rnd.uniform(0, math.pi)
        if any(math.hypot(cx - m[0], cz - m[1]) < 0.7 * (a + m[2]) + 10 for m in mounds):
            continue
        if relief_mask(ctx, cx, cz) < 0.99:
            continue
        if any(relief_mask(ctx, cx + dx, cz + dz) < 0.7 for dx, dz in ((a, 0), (-a, 0), (0, a), (0, -a))):
            continue
        mounds.append((cx, cz, a, b, th, h))
    return mounds


def mound_height(mounds, x, z):
    h = 0.0
    for cx, cz, a, b, th, height in mounds:
        dx, dz = x - cx, z - cz
        if abs(dx) > a or abs(dz) > a:
            continue
        u = dx * math.cos(th) + dz * math.sin(th)
        v = -dx * math.sin(th) + dz * math.cos(th)
        q = math.hypot(u / a, v / b)
        if q < 1.0:
            h += height * (1.0 - smoothstep(0.0, 1.0, q))
    return h


def signed_poly_distance(x, z, poly):
    """Negative inside the polygon, positive outside."""
    d = min(dist_to_segment(x, z, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))
    return -d if point_in_polygon(x, z, poly) else d


def ellipse_q(x, z, area):
    (cx, cz), (rx, rz) = area["center"], area["radii"]
    return math.hypot((x - cx) / rx, (z - cz) / rz)


class Feature:
    """A polyline or circle that carves grass (and optionally paints a surface)."""

    def __init__(self, pts, clear, ramp, surface=None, surface_width=0.0, soft=False):
        self.pts, self.clear, self.ramp = pts, clear, ramp
        self.surface, self.surface_width = surface, surface_width
        self.soft = soft  # a route: the ground's lumps carry on over it (see relief_mask)
        pad = clear + ramp + RELIEF_PAD
        xs = [p[0] for p in pts]
        zs = [p[1] for p in pts]
        self.bbox = (min(xs) - pad, min(zs) - pad, max(xs) + pad, max(zs) + pad)

    def near(self, x, z):
        b = self.bbox
        return b[0] <= x <= b[2] and b[1] <= z <= b[3]

    def distance(self, x, z):
        if len(self.pts) == 1:
            return math.hypot(x - self.pts[0][0], z - self.pts[0][1])
        return dist_to_polyline(x, z, self.pts)


def bake_features(layout):
    feats = []
    for p in layout["paths"]:
        k = p["kind"]
        if k == "main_route":
            feats.append(Feature(p["points"], 3.5, 4.0, soft=True))
        elif k == "shortcut":
            feats.append(Feature(p["points"], 2.5, 3.0, soft=True))
        elif k == "ant_road":
            feats.append(Feature(p["points"], 2.0, 3.0, "ant_road", 2.0, soft=True))
        elif k == "termite_trail":
            feats.append(Feature(p["points"], 1.5, 2.0, soft=True))
        elif k == "hose":
            feats.append(Feature(p["points"], p["diameter"] / 2 + 1.5, 3.0))
        elif k == "root":
            feats.append(Feature(p["points"], p["width"] / 2 + 1.5, 2.0))
        elif k == "log":
            feats.append(Feature(p["points"], p["width"] / 2 + 2.0, 2.0))
    flat = {"pot_ring", "trip_lines", "orb_web"}
    for lm in layout["landmarks"]:
        if lm["id"] in flat:
            continue
        w, _, d = lm["size"]
        feats.append(Feature([lm["pos"]], max(w, d) / 2 + 3.0, 3.0))
    for sd in layout.get("standins", []):
        feats.append(Feature([sd["pos"]], 4.0, 2.0))
    for hv in layout.get("heavables", []):
        feats.append(Feature([hv["pos"]], hv["size"] / 2 + 2.5, 2.0))
    for fl in layout.get("flowers", []):
        feats.append(Feature([fl["pos"]], fl["head"] + 2.0, 2.0))
    if "patio" in layout:
        t = layout["patio"]["trowel"]
        feats.append(Feature([t["from"], t["to"]], t["width"] / 2 + 4.0, 3.0))
    for job in layout.get("expedition", {}).get("jobs", []):
        # the carrying trail: wide enough for the load and the ants under its rim
        feats.append(Feature(job["haul_path"], job["prize"]["size"] / 2 + 1.5, 3.0))
        for pr in job.get("props", []):
            feats.append(Feature([pr["pos"]], pr["size"] / 2 + 2.5, 2.0))
        for pb in job.get("pill_bugs", []):
            feats.append(Feature([pb["pos"]], 4.0, 2.0))
    return feats


def bake(layout):
    meta = layout["meta"]
    bk = meta["bake"]
    n, cell, org = bk["size"], bk["cell"], bk["origin"]
    areas = {a["id"]: a for a in layout["areas"]}
    rut = layout["water"][0]["polygon"]
    rut_box = (min(p[0] for p in rut) - 32, min(p[1] for p in rut) - 32,
               max(p[0] for p in rut) + 32, max(p[1] for p in rut) + 32)
    runoff = by_id(layout["paths"], "runoff")["points"]
    ring = by_id(layout["landmarks"], "pot_ring")
    ring_c, ring_r = ring["pos"], ring["size"][0] / 2
    barriers = [b["polygon"] for b in layout["barriers"]]
    feats = bake_features(layout)
    relief = ReliefContext(layout, feats)
    mounds = place_mounds(relief)

    heights, surface, density = [], [], []
    for j in range(n):
        z = org + j * cell
        for i in range(n):
            x = org + i * cell
            edge = min(x + 360, 360 - x, z + 360, 360 - z)
            h = base_relief(x, z) * smoothstep(0, 20, edge)
            rm = relief_mask(relief, x, z)
            mh = 0.0
            if rm > 0.0:
                mh = mound_height(mounds, x, z) * rm
                h += rolling(x, z) * rm + mh
            surf = "lawn"
            dens = FILL

            # Areas: clearings, the flattened hollow, touch-me-not, shade under the mango
            q = {k: ellipse_q(x, z, a) for k, a in areas.items()}
            for k, qv in q.items():
                if qv < 1.0 and k not in ("blade_forest", "backpack_hollow", "bare_patch", "lolly_bridge"):
                    dens = min(dens, FILL * (0.15 + 0.85 * smoothstep(0.55, 1.0, qv)))
            if q["blade_forest"] < 1.0:
                dens = FILL * (1.0 + 0.6 * (1 - smoothstep(0.6, 1.0, q["blade_forest"])))
            if q["flower_bed"] < 1.0:
                surf = "clover"
                dens = min(dens, 5.0)
            if q["windfall_roots"] < 1.0 or q["spiders_edge"] < 1.0 or x < -330:
                surf = "leaf_litter"
                dens = min(dens, 3.0)
            if q["backpack_hollow"] < 1.0:
                h -= 0.6 * (1 - smoothstep(0.6, 1.0, q["backpack_hollow"]))
                surf = "flattened"
                dens = 0.0

            # Bare Patch: a dish where the pot stood, with the rim's groove
            r = math.hypot(x - ring_c[0], z - ring_c[1])
            if r < ring_r + 25:
                h -= 1.0 * (1 - smoothstep(15, ring_r + 10, r)) + 0.45 * math.exp(-((r - ring_r) / 2.2) ** 2)
                if r < ring_r + 15:
                    surf = "bare_soil"
                    dens = min(dens, FILL * smoothstep(ring_r + 8, ring_r + 20, r))

            # Runoff channel from the coupling down to the Rut
            if -10 < x < 250 and -60 < z < 170:
                dr = dist_to_polyline(x, z, runoff)
                if dr < 5:
                    h -= 0.7 * (1 - dr / 5)
                    dens = min(dens, FILL * smoothstep(3, 6, dr))
                    if dr < 3:
                        surf = "mud"

            # The Rut: a flooded mower-wheel rut; calm ground and mud banks around it
            if rut_box[0] <= x <= rut_box[2] and rut_box[1] <= z <= rut_box[3]:
                sd = signed_poly_distance(x, z, rut)
                if sd < 0:
                    h = -0.8 - 3.2 * smoothstep(0, 18, -sd)
                    surf, dens = "water", 0.0
                elif sd < 30:
                    h *= smoothstep(6, 30, sd)
                    if sd < 5:
                        h = -0.8 + (h + 0.8) * smoothstep(0, 5, sd)
                    if sd < 6:
                        surf = "mud"
                        dens = min(dens, FILL * smoothstep(3, 8, sd))

            # Carved lanes and clearings around props
            for f in feats:
                if f.near(x, z):
                    d = f.distance(x, z)
                    if d < f.clear + f.ramp:
                        dens = min(dens, FILL * smoothstep(f.clear, f.clear + f.ramp, d))
                    if f.surface and d < f.surface_width and surf in ("lawn", "clover", "leaf_litter"):
                        surf = f.surface

            # Mounds are bare heaps of dry earth, the grass only round their foot
            if mh > 0.4:
                dens = min(dens, FILL * (1 - smoothstep(0.4, 1.4, mh)))
                if mh > 0.9 and surf == "lawn":
                    surf = "bare_soil"

            # Tussock walls last: they override everything
            for poly in barriers:
                if point_in_polygon(x, z, poly):
                    surf, dens = "tussock", 45.0

            heights.append(h)
            surface.append(SURFACE[surf])
            density.append(int(round(max(0.0, min(255.0, dens)))))

    out = ROOT / bk["dir"]
    out.mkdir(parents=True, exist_ok=True)
    (out / "height.f32").write_bytes(struct.pack(f"<{len(heights)}f", *heights))
    (out / "surface.u8").write_bytes(bytes(surface))
    (out / "density.u8").write_bytes(bytes(density))

    blades = sum(d / 100.0 * cell * cell for d in density)
    counts = {name: surface.count(code) for name, code in SURFACE.items()}
    stats = {"size": n, "cell": cell, "origin": org, "height_min": round(min(heights), 2),
             "height_max": round(max(heights), 2), "estimated_blades": int(blades),
             "surface_cells": counts}
    (out / "bake.json").write_text(json.dumps(stats, indent=2) + "\n")
    _write_preview(out / "preview.png", n, heights, surface, density)
    print(f"baked {n}x{n} grid to {out.relative_to(ROOT)}: heights {stats['height_min']}..{stats['height_max']} m, "
          f"~{int(blades)} standing blades")
    print("  surface cells: " + ", ".join(f"{k} {v}" for k, v in counts.items() if v))


def _write_preview(path, n, heights, surface, density):
    """Top-down PNG of the bake: grass density as green, surfaces tinted, hillshade from relief."""
    import zlib
    tint = {0: (110, 66, 42), 1: (176, 92, 52), 2: (80, 44, 30), 3: (140, 100, 55), 4: (60, 130, 190),
            5: (190, 175, 110), 6: (30, 70, 25), 7: (90, 110, 60), 8: (120, 90, 60)}
    rows = []
    for j in range(n):
        row = bytearray([0])
        for i in range(n):
            k = j * n + i
            r, g, b = tint[surface[k]]
            shade = 1.0 + 0.25 * (heights[k] - heights[k - 1 if i else k])
            g2 = min(255, g + density[k] * 5)
            px = [int(max(0, min(255, c * shade))) for c in (r * (1 - density[k] / 60), g2, b)]
            row += bytes(px)
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 2, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")
    path.write_bytes(png)


# ── formatting ────────────────────────────────────────────────────────────────

def _compact(value, indent=0):
    """JSON with objects expanded but numeric lists (and lists of them) on one line."""
    pad = "  " * indent
    if isinstance(value, dict):
        if not value:
            return "{}"
        items = [f'{pad}  {json.dumps(k)}: {_compact(v, indent + 1)}' for k, v in value.items()]
        return "{\n" + ",\n".join(items) + f"\n{pad}}}"
    if isinstance(value, list):
        flat = json.dumps(value, separators=(", ", ": "))
        if all(not isinstance(v, dict) for v in value) and len(flat) <= 160:
            return flat
        if all(isinstance(v, list) for v in value):
            rows = [json.dumps(v, separators=(", ", ": ")) for v in value]
            lines, line = [], ""
            for r in rows:
                if line and len(line) + len(r) + 2 > 140:
                    lines.append(line)
                    line = ""
                line = f"{line}, {r}" if line else r
            lines.append(line)
            return "[" + (",\n" + pad + " ").join(lines) + "]"
        items = [f"{pad}  {_compact(v, indent + 1)}" for v in value]
        return "[\n" + ",\n".join(items) + f"\n{pad}]"
    return json.dumps(value)


def fmt(layout):
    LAYOUT.write_text(_compact(layout) + "\n")
    print(f"formatted {LAYOUT.relative_to(ROOT)}")


if __name__ == "__main__":
    layout = json.loads(LAYOUT.read_text())
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        sys.exit(0 if check(layout) else 1)
    elif cmd == "render":
        render(layout)
    elif cmd == "fmt":
        fmt(layout)
    elif cmd == "bake":
        bake(layout)
    else:
        sys.exit(__doc__)
