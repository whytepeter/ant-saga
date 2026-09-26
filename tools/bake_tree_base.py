"""Bake the apple tree's base (world/lawn/layout.json "tree_base") into
assets/world/tree_base.glb with Blender:

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/bake_tree_base.py

A solid (the soil bank the roots heave up around the trunk, joined with the
lower trunk) has the caves cut out of it with an exact boolean: tunnels (round
tubes along a path or up a helix) and chambers (ellipsoids with flat floors).
Noise roughens the walls. Vertex colours tell the game's shader
(world/shaders/tree_base.gdshader) what each part is:
    r = bark, g = cave wall, b = how much open sky it sees (0 deep inside)
Coordinates: layout/Godot [x, y, z] with y up -> Blender (x, -z, y).
"""
import json
import math
import os
import time

import bmesh
import bpy
from mathutils import Vector, noise

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "world", "tree_base.glb")

layout = json.load(open(os.path.join(ROOT, "world", "lawn", "layout.json")))
TB = layout["tree_base"]
TRUNK = TB["trunk"]
BANK = TB["bank"]
CX, CZ = TRUNK["center"]


def bl(p):
    """Godot [x, y, z] -> Blender vector."""
    return Vector((p[0], -p[2], p[1]))


def gd(v):
    """Blender vector -> Godot (x, y, z)."""
    return (v.x, v.z, -v.y)


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def trunk_r(y):
    """Matches the builder's tapered trunk cylinder, which starts at y = -5."""
    return TRUNK["radius"] - (TRUNK["radius"] - TRUNK["top_radius"]) * (y + 5.0) / TRUNK["height"]


def bank_h(x, z):
    r = math.hypot(x - CX, z - CZ)
    h = BANK["peak"] * smoothstep(BANK["outer"], BANK["inner"], r)
    floor = BANK["outside_floor"] if x < BANK["outside_x"] else BANK["inside_floor"]
    return max(h, floor)


# ── cave paths ────────────────────────────────────────────────────────────────

def catmull(points, spacing=1.2):
    """Dense points along a Catmull-Rom curve through `points` (Godot coords)."""
    pts = [Vector(p) for p in points]
    if len(pts) < 2:
        return pts
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        n = max(2, int((p2 - p1).length / spacing))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tunnel_points(t):
    if "helix" in t:
        h = t["helix"]
        steps = int(h["turns"] * 60)
        pts = []
        for k in range(steps + 1):
            f = k / steps
            a = math.radians(h["start_angle_deg"] + 360.0 * h["turns"] * f)
            pts.append(Vector((h["center"][0] + h["radius"] * math.cos(a), h["from_y"] + (h["to_y"] - h["from_y"]) * f,
                               h["center"][1] + h["radius"] * math.sin(a))))
        return pts
    return catmull(t["points"])


TUNNELS = [(tunnel_points(t), t["radius"]) for t in TB["tunnels"]]
CHAMBERS = TB["chambers"]
OPENINGS = [Vector(p) for p in TB["openings"]]


def cave_distance(p):
    """Signed-ish distance (Godot coords) from p to the nearest cave wall (< 0 inside)."""
    best = 1e9
    for pts, radius in TUNNELS:
        for i in range(0, len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-6)))
            best = min(best, (a + ab * t - p).length - radius)
    for c in CHAMBERS:
        rel = Vector(((p[0] - c["center"][0]) / c["radii"][0], (p[1] - c["center"][1]) / c["radii"][1],
                      (p[2] - c["center"][2]) / c["radii"][2]))
        best = min(best, (rel.length - 1.0) * min(c["radii"]))
    return best


# ── meshes ────────────────────────────────────────────────────────────────────

def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def bank_solid():
    x0, z0, x1, z1 = BANK["region"]
    step, bottom = 2.5, -16.0
    nx, nz = int((x1 - x0) / step) + 1, int((z1 - z0) / step) + 1
    bm = bmesh.new()
    top = [[bm.verts.new(bl((x0 + i * step, bank_h(x0 + i * step, z0 + j * step), z0 + j * step))) for j in range(nz)] for i in range(nx)]
    bot = [[bm.verts.new(bl((x0 + i * step, bottom, z0 + j * step))) for j in range(nz)] for i in range(nx)]
    for i in range(nx - 1):
        for j in range(nz - 1):
            bm.faces.new((top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]))
            bm.faces.new((bot[i][j], bot[i + 1][j], bot[i + 1][j + 1], bot[i][j + 1]))
    for i in range(nx - 1):
        bm.faces.new((top[i][0], top[i + 1][0], bot[i + 1][0], bot[i][0]))
        bm.faces.new((top[i][nz - 1], bot[i][nz - 1], bot[i + 1][nz - 1], top[i + 1][nz - 1]))
    for j in range(nz - 1):
        bm.faces.new((top[0][j], bot[0][j], bot[0][j + 1], top[0][j + 1]))
        bm.faces.new((top[nx - 1][j], top[nx - 1][j + 1], bot[nx - 1][j + 1], bot[nx - 1][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object("bank", bm)


def trunk_solid():
    y0, y1 = TRUNK["baked_from"], TRUNK["baked_to"]
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=96, radius1=trunk_r(y0), radius2=trunk_r(y1), depth=y1 - y0)
    bmesh.ops.translate(bm, verts=bm.verts, vec=bl((CX, (y0 + y1) / 2.0, CZ)))
    # a few horizontal rings so the boolean and the noise have vertices to work with
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 1.0], cuts=30)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    return new_object("trunk", bm)


def tube(pts, radius, name):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_mode = "ROUND"
    curve.bevel_depth = radius
    curve.bevel_resolution = 5
    curve.use_fill_caps = True
    curve.twist_mode = "Z_UP"
    spline = curve.splines.new("POLY")
    spline.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        v = bl(p)
        spline.points[i].co = (v.x, v.y, v.z, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return obj


def chamber(c):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1.0)
    rx, ry, rz = c["radii"]
    bmesh.ops.scale(bm, vec=Vector((rx, rz, ry)), verts=bm.verts)
    center = bl(c["center"])
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    # flat floor: cut the bottom off and close it
    floor_z = c["floor"]
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector((0, 0, floor_z)),
                                 plane_no=Vector((0, 0, 1)), clear_inner=True)
    edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.holes_fill(bm, edges=edges)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(c["id"], bm)


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


# ── bake ──────────────────────────────────────────────────────────────────────

def main():
    started = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    solid = join([bank_solid(), trunk_solid()], "tree_base")

    parts = []
    for t in TB["tunnels"]:
        obj = tube(tunnel_points(t), t["radius"], t["id"])
        select_only(obj)
        bpy.ops.object.convert(target="MESH")
        parts.append(obj)
    for c in CHAMBERS:
        parts.append(chamber(c))
    caves = join(parts, "caves")
    # merge the overlapping tubes and chambers into one clean volume
    select_only(caves)
    remesh = caves.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.55
    remesh.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier="remesh")
    print("caves: %d faces (%.0f s)" % (len(caves.data.polygons), time.time() - started))

    select_only(solid)
    boolean = solid.modifiers.new("carve", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.use_self = True
    boolean.object = caves
    bpy.ops.object.modifier_apply(modifier="carve")
    bpy.data.objects.remove(caves)
    print("carved: %d faces (%.0f s)" % (len(solid.data.polygons), time.time() - started))

    bm = bmesh.new()
    bm.from_mesh(solid.data)
    # nothing is ever seen from below the ground
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < -15.0], context="FACES")
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    colors = bm.verts.layers.float_color.new("Col")
    for v in bm.verts:
        p = Vector(gd(v.co))
        cave = 1.0 - smoothstep(0.4, 2.5, cave_distance(p))
        r = math.hypot(p.x - CX, p.z - CZ)
        bark = smoothstep(trunk_r(p.y) - 4.0, trunk_r(p.y) - 0.5, r) * smoothstep(bank_h(p.x, p.z) + 0.5, bank_h(p.x, p.z) + 3.0, p.y)
        bark *= 1.0 - cave
        depth = min((p - o).length for o in OPENINGS)
        sky = 1.0 - cave * (1.0 - max(0.04, min(1.0, 1.0 - depth / 30.0)))
        # rough the soil and cave walls, barely the bark
        amp = 0.9 - 0.7 * bark
        n = noise.noise(Vector((p.x, p.y, p.z)) * 0.11) + 0.5 * noise.noise(Vector((p.x, p.y, p.z)) * 0.31)
        if abs(p.y) < 60.0 and p.y > -14.0:
            v.co += v.normal * n * amp
        v[colors] = (bark, cave, sky, 1.0)
    bm.to_mesh(solid.data)
    bm.free()
    solid.data.color_attributes.active_color = solid.data.color_attributes["Col"]
    for poly in solid.data.polygons:
        poly.use_smooth = True
    print("final: %d faces, %d verts (%.0f s)" % (len(solid.data.polygons), len(solid.data.vertices), time.time() - started))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    select_only(solid)
    kwargs = dict(filepath=OUT, use_selection=True, export_format="GLB", export_yup=True, export_apply=True,
                  export_normals=True, export_materials="NONE", export_texcoords=False)
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs, export_colors=True)
    print("saved %s (%.0f s)" % (OUT, time.time() - started))


main()
