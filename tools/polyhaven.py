#!/usr/bin/env python3
"""Download CC0 models and textures from Poly Haven (polyhaven.com).

    python3 tools/polyhaven.py tex brick_wall_001 white_stucco      # 2k maps
    python3 tools/polyhaven.py model dandelion_01 trowel_01         # 1k glTF
    python3 tools/polyhaven.py tex bark_brown_01 --res 4k

Textures land in assets/textures/<id>/<id>_{diff,nor,rough}.jpg (the names
lawn_builder.gd's TEXTURED sets use); models in assets/nature/<id>/ as glTF
with their textures beside them. Each download is credited in the folder's
CREDITS.md. Already-downloaded files are skipped. Afterwards run
`python3 tools/compress_textures.py` and `Godot --headless --path . --import`.
"""

import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
API = "https://api.polyhaven.com"
UA = {"User-Agent": "ant-game-asset-fetch"}
# Poly Haven map name -> our file suffix
TEX_MAPS = {"Diffuse": "diff", "nor_gl": "nor", "Rough": "rough"}


def get_json(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA)))


def fetch(url, dest):
    if dest.exists() and dest.stat().st_size > 0:
        return 0
    dest.parent.mkdir(parents=True, exist_ok=True)
    data = urllib.request.urlopen(urllib.request.Request(url, headers=UA)).read()
    dest.write_bytes(data)
    return len(data)


def credit(folder, asset_id):
    path = folder / "CREDITS.md"
    line = f"- `{asset_id}`: https://polyhaven.com/a/{asset_id}"
    text = path.read_text() if path.exists() else (
        "# Credits\n\nAll from [Poly Haven](https://polyhaven.com), CC0 (public domain):\n\n")
    if line not in text:
        path.write_text(text.rstrip("\n") + "\n" + line + "\n")


def texture(asset_id, res):
    files = get_json(f"{API}/files/{asset_id}")
    folder = ROOT / "assets" / "textures" / asset_id
    got = 0
    for ph_name, suffix in TEX_MAPS.items():
        entry = files.get(ph_name, {}).get(res, {}).get("jpg")
        if entry is None:
            print(f"  {asset_id}: no {ph_name} at {res}")
            continue
        got += fetch(entry["url"], folder / f"{asset_id}_{suffix}.jpg")
    credit(ROOT / "assets" / "textures", asset_id)
    print(f"tex   {asset_id:30s} {got / 1e6:5.1f} MB")


def model(asset_id, res):
    files = get_json(f"{API}/files/{asset_id}")
    entry = files["gltf"][res]["gltf"]
    folder = ROOT / "assets" / "nature" / asset_id
    got = fetch(entry["url"], folder / f"{asset_id}.gltf")
    for rel, inc in entry.get("include", {}).items():
        got += fetch(inc["url"], folder / rel)
    # foliage: the glTF's colour maps are JPEGs with no transparency; the
    # cut-out masks come separately ("Alpha", "leaves_alpha"). tools/merge_alpha.gd
    # folds them into <name>_diffa_<res>.png, which NatureModels uses.
    for key, maps in files.items():
        if key.lower().endswith("alpha") and isinstance(maps, dict) and res in maps:
            fmt = "png" if "png" in maps[res] else "jpg"
            part = key[:-len("alpha")].rstrip("_").lower()
            name = f"{asset_id}_{part + '_' if part else ''}alpha_{res}.{fmt}"
            got += fetch(maps[res][fmt]["url"], folder / "textures" / name)
    credit(ROOT / "assets" / "nature", asset_id)
    print(f"model {asset_id:30s} {got / 1e6:5.1f} MB")


def main():
    args = sys.argv[1:]
    if len(args) < 2 or args[0] not in ("tex", "model"):
        print(__doc__)
        sys.exit(1)
    res = "2k" if args[0] == "tex" else "1k"
    if "--res" in args:
        i = args.index("--res")
        res = args[i + 1]
        del args[i:i + 2]
    for asset_id in args[1:]:
        (texture if args[0] == "tex" else model)(asset_id, res)


if __name__ == "__main__":
    main()
