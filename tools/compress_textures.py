#!/usr/bin/env python3
"""Switch every texture under assets/ to VRAM compression (fast loading, low
memory) and flag normal maps, then Godot reimports them on the next --import.

    python3 tools/compress_textures.py
    Godot --headless --path . --import

Textures Godot extracted from a GLB are matched to their glTF roles (colour,
metal/roughness, normal); Poly Haven sets use their _nor suffix. Small props
(manifest "size" under 15 m) are capped at 1K.
"""

import glob
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def set_params(imp, params):
    s = imp.read_text()
    for k, v in params.items():
        s, n = re.subn(rf"^{re.escape(k)}=.*$", f"{k}={v}", s, flags=re.M)
        if n == 0:
            s = s.rstrip("\n") + f"\n{k}={v}\n"
    imp.write_text(s)


def gltf_roles(glb):
    b = glb.read_bytes()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    roles = {}
    for m in j.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        for key, role in (("baseColorTexture", "color"), ("metallicRoughnessTexture", "orm")):
            if key in pbr:
                roles[j["textures"][pbr[key]["index"]]["source"]] = role
        if "normalTexture" in m:
            roles[j["textures"][m["normalTexture"]["index"]]["source"]] = "normal"
    return roles


def main():
    sizes = {}
    man = ROOT / "assets/garden/manifest.json"
    if man.exists():
        sizes = {a["id"]: a.get("size", 99) for a in json.loads(man.read_text())["assets"]}
    done = 0
    for glb in map(Path, glob.glob(str(ROOT / "assets/**/*.glb"), recursive=True)):
        roles = gltf_roles(glb)
        small = sizes.get(glb.stem, 99) < 15
        for imp in glob.glob(str(glb.parent / f"{glb.stem}_*.*.import")):
            imp = Path(imp)
            idx = imp.name[len(glb.stem) + 1:].split(".")[0]
            if not idx.isdigit():
                continue
            role = roles.get(int(idx), "color")
            set_params(imp, {"compress/mode": 2, "compress/normal_map": 1 if role == "normal" else 2,
                             "process/size_limit": 1024 if small else 0})
            done += 1
    for imp in map(Path, glob.glob(str(ROOT / "assets/textures/*/*.jpg.import"))):
        set_params(imp, {"compress/mode": 2, "compress/normal_map": 1 if imp.name.endswith("_nor.jpg.import") else 2})
        done += 1
    print(f"{done} textures set to VRAM compression")


if __name__ == "__main__":
    main()
