"""Bake the Wormways (world/lawn/layout.json "wormways") into
assets/world/wormways.glb with Blender:

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/bake_wormways.py

The burrows (round tubes along a path) and chambers (ellipsoids with flat
floors) are merged into one clean volume (voxel remesh), turned inside out (we
see them from within), roughened with noise, and cut open where they reach the
lawn. Vertex colours tell the game's shader (world/shaders/wormways.gdshader)
what each spot is:
    r = floor (wet, slimed where worms slide), g = clay seam, b = daylight
    reaching it from an opening (0 deep inside)
Coordinates: layout/Godot [x, y, z] with y up -> Blender (x, -z, y).
"""
import json
import math
import os
import struct
import time

import bmesh
import bpy
from mathutils import Vector, noise

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "world", "wormways.glb")
layout = json.load(open(os.path.join(ROOT, "world", "lawn", "layout.json")))
WW = layout["wormways"]
BAKE = layout["meta"]["bake"]
N = BAKE["size"]
CELL = BAKE["cell"]
ORIGIN = BAKE["origin"]
HEIGHTS = struct.unpack("<%df" % (N * N), open(os.path.join(ROOT, BAKE["dir"], "height.f32"), "rb").read())


def ground(x, z):
    gx = min(max((x - ORIGIN) / CELL, 0.0), N - 1.001)
    gz = min(max((z - ORIGIN) / CELL, 0.0), N - 1.001)
    i, j = int(gx), int(gz)
    fx, fz = gx - i, gz - j
    a, b = HEIGHTS[j * N + i], HEIGHTS[j * N + i + 1]
    c, d = HEIGHTS[(j + 1) * N + i], HEIGHTS[(j + 1) * N + i + 1]
    return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz


def bl(p):
    return Vector((p[0], -p[2], p[1]))


def gd(v):
    return Vector((v.x, v.z, -v.y))


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def catmull(points, spacing=1.0):
    pts = [Vector(p) for p in points]
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


OPENINGS = [Vector(e["pos"]) for e in WW["entrances"]] + [Vector(WW["shaft"]["pos"])]


def shaft_near(p):
    """1 in or right by a vertical entrance shaft (or the old shaft), 0 away from them."""
    best = 1e9
    for o in OPENINGS:
        best = min(best, math.hypot(p.x - o.x, p.z - o.z))
    return 1.0 - smoothstep(3.0, 7.0, best)


def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


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
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    rx, ry, rz = c["radii"]
    bmesh.ops.scale(bm, vec=Vector((rx, rz, ry)), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=bl(c["center"]))
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=Vector((0, 0, c["floor"])),
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


def main():
    started = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = []
    for t in WW["tunnels"]:
        obj = tube(catmull(t["points"]), t["radius"], t["id"])
        select_only(obj)
        bpy.ops.object.convert(target="MESH")
        parts.append(obj)
    for c in WW["chambers"]:
        parts.append(chamber(c))
    caves = join(parts, "wormways")
    select_only(caves)
    remesh = caves.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.5
    remesh.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier="remesh")
    print("merged: %d faces (%.0f s)" % (len(caves.data.polygons), time.time() - started))

    bm = bmesh.new()
    bm.from_mesh(caves.data)
    # seen from inside: turn every face round
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    # open at the lawn: nothing above the ground (the mouths)
    cut = [f for f in bm.faces if gd(f.calc_center_median()).y > ground(*[gd(f.calc_center_median()).x, gd(f.calc_center_median()).z]) - 0.15]
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    colors = bm.verts.layers.float_color.new("Col")
    for v in bm.verts:
        p = gd(v.co)
        n = gd(v.normal)
        # roughen the walls, but not in the entrance shafts (no ledges to hang
        # on: he drops straight down them) nor where they meet the lawn
        near_top = smoothstep(8.0, 1.0, ground(p.x, p.z) - p.y) * min(1.0, 2.0 * shaft_near(p))
        amp = 0.45 * (1.0 - near_top)
        q = Vector((p.x, p.y, p.z))
        wobble = noise.noise(q * 0.21) + 0.5 * noise.noise(q * 0.55) + 0.25 * noise.noise(q * 1.3)
        v.co += v.normal * wobble * amp
        floor = smoothstep(0.35, 0.85, n.y)
        clay = smoothstep(0.25, 0.6, noise.noise(q * 0.045 + Vector((3.1, 7.7, 1.3))))
        depth = min((p - o).length for o in OPENINGS)
        sky = max(0.0, 1.0 - depth / 22.0) ** 1.5
        v[colors] = (floor, clay, sky, 1.0)
    bm.to_mesh(caves.data)
    bm.free()
    caves.data.color_attributes.active_color = caves.data.color_attributes["Col"]
    for poly in caves.data.polygons:
        poly.use_smooth = True
    print("final: %d faces, %d verts (%.0f s)" % (len(caves.data.polygons), len(caves.data.vertices), time.time() - started))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    select_only(caves)
    kwargs = dict(filepath=OUT, use_selection=True, export_format="GLB", export_yup=True, export_apply=True,
                  export_normals=True, export_materials="NONE", export_texcoords=False)
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs, export_colors=True)
    print("saved %s (%.0f s)" % (OUT, time.time() - started))


main()
