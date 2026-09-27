#!/usr/bin/env python3
"""Generate garden models with the Meshy API from assets/garden/manifest.json.

    python3 tools/meshy_assets.py plan            # what would be made and what it costs (spends nothing)
    python3 tools/meshy_assets.py make --pilot    # generate the pilot set (spends credits)
    python3 tools/meshy_assets.py make daisy twig # generate named assets (spends credits)
    python3 tools/meshy_assets.py make --group creatures
    python3 tools/meshy_assets.py status          # credit balance and each asset's state
    python3 tools/meshy_assets.py concept --group world   # Nano Banana pictures only, to review
    python3 tools/meshy_assets.py concept --redo sweetcorn # a new picture (after editing the prompt)

An asset with "image" (a reference picture's path) is made by image-to-3D instead.

An asset with "via": "nano" goes picture first: Google's Nano Banana (Meshy's
text-to-image, manifest "image_model") draws it from the prompt and the house
style, the picture is saved as assets/garden/<id>/<id>_concept.png to check
against the design, and `make` turns that picture into a textured model
(image-to-3D). `make` draws the picture first if there isn't one; `concept`
only draws, so pictures can be looked at before paying for the 3D. With
"references" (1-5 picture paths), Nano Banana draws from them instead
(image-to-image), to keep a new model true to an existing one.

Each asset is a text-to-3D preview (shape, 20 credits) then a refine with PBR
textures (10 credits); the GLB lands in assets/garden/<id>/<id>.glb. Task ids
are saved in assets/garden/state.json, so a rerun resumes instead of paying
again. The key is read from .env (MESHY_API_KEY) and never printed.
"""

import base64
import json
import sys
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "assets" / "garden"
MANIFEST = DIR / "manifest.json"
STATE = DIR / "state.json"
API = "https://api.meshy.ai/openapi"
PREVIEW_COST, REFINE_COST = 20, 10
CONCEPT_COST = {"nano-banana": 3, "nano-banana-2": 6, "nano-banana-pro": 9}
IMAGE_TO_3D_COST = 40  # 30 base, plus PBR maps (Meshy doesn't itemise them)
_lock = threading.Lock()


def key():
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("MESHY_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("MESHY_API_KEY missing from .env")


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {key()}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def load_state():
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save_state(state):
    with _lock:
        STATE.write_text(json.dumps(state, indent=2) + "\n")


def wait(task_id, label, endpoint="/v2/text-to-3d"):
    last = -1
    while True:
        t = call("GET", f"{endpoint}/{task_id}")
        if t["status"] == "SUCCEEDED":
            return t
        if t["status"] in ("FAILED", "CANCELED"):
            raise RuntimeError(f"{label}: {t['status']} {t.get('task_error')}")
        if t.get("progress", 0) // 25 != last:
            last = t.get("progress", 0) // 25
            print(f"  {label}: {t['status'].lower()} {t.get('progress', 0)}%", flush=True)
        time.sleep(8)


def data_uri(path):
    mime = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()


def concept_one(asset, manifest, state, redo=False):
    """Nano Banana draws the asset; the picture is saved for review."""
    aid = asset["id"]
    s = state.setdefault(aid, {})
    png = DIR / aid / f"{aid}_concept.png"
    if redo:
        s.pop("concept", None)
        png.unlink(missing_ok=True)
    endpoint = "/v1/image-to-image" if asset.get("references") else "/v1/text-to-image"
    if "concept" not in s:
        view = asset.get("view", "The whole object in view, a three-quarter view from slightly above, plain white background, soft even light.")
        prompt = f"{asset['prompt']} {asset.get('style', manifest['style'])} {view}"
        body = {"ai_model": manifest.get("image_model", "nano-banana"), "prompt": prompt[:2000], "aspect_ratio": "1:1"}
        if asset.get("references"):
            body["reference_image_urls"] = [data_uri(ROOT / r) for r in asset["references"]]
        s["concept"] = call("POST", endpoint, body)["result"]
        save_state(state)
    task = wait(s["concept"], f"{aid} picture", endpoint)
    if not png.exists():
        png.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(task["image_urls"][0], png)
    return f"{aid}: {png.relative_to(ROOT)}"


def make_one(asset, manifest, state):
    aid = asset["id"]
    s = state.setdefault(aid, {})
    out = DIR / aid / f"{aid}.glb"
    if out.exists():
        return f"{aid}: already downloaded"
    if asset.get("via") == "nano":
        concept_one(asset, manifest, state)
        if "image" not in s:
            s["image"] = call("POST", "/v1/image-to-3d", {
                "input_task_id": s["concept"], "ai_model": manifest.get("ai_model", "latest"), "enable_pbr": True,
                "should_remesh": True, "should_texture": True, "topology": "triangle",
                "target_polycount": asset["polycount"]})["result"]
            save_state(state)
        task = wait(s["image"], f"{aid} picture to 3D", "/v1/image-to-3d")
        out.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(task["model_urls"]["glb"], out)
        s["done"] = True
        s["credits"] = task.get("consumed_credits")
        save_state(state)
        return f"{aid}: {out.relative_to(ROOT)} ({out.stat().st_size / 1e6:.1f} MB, {task.get('consumed_credits')} credits)"
    if asset.get("image"):
        # image-to-3D from a reference picture (path relative to the repo): one
        # task gives the shape and PBR textures together
        ref = ROOT / asset["image"]
        mime = "image/png" if ref.suffix.lower() == ".png" else "image/jpeg"
        uri = f"data:{mime};base64," + base64.b64encode(ref.read_bytes()).decode()
        if "image" not in s:
            s["image"] = call("POST", "/v1/image-to-3d", {
                "image_url": uri, "ai_model": manifest.get("ai_model", "latest"), "enable_pbr": True,
                "should_remesh": True, "should_texture": True, "topology": "triangle",
                "target_polycount": asset["polycount"]})["result"]
            save_state(state)
        task = wait(s["image"], f"{aid} image to 3D", "/v1/image-to-3d")
        out.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(task["model_urls"]["glb"], out)
        s["done"] = True
        save_state(state)
        return f"{aid}: {out.relative_to(ROOT)} ({out.stat().st_size / 1e6:.1f} MB)"
    if "preview" not in s:
        s["preview"] = call("POST", "/v2/text-to-3d", {
            "mode": "preview", "prompt": f"{asset['prompt']} {asset.get('style', manifest['style'])}"[:800],
            "ai_model": manifest.get("ai_model", "latest"), "topology": "triangle",
            "target_polycount": asset["polycount"], "should_remesh": True})["result"]
        save_state(state)
    wait(s["preview"], f"{aid} shape")
    if "refine" not in s:
        s["refine"] = call("POST", "/v2/text-to-3d", {
            "mode": "refine", "preview_task_id": s["preview"], "enable_pbr": True,
            "texture_prompt": f"{asset['prompt']} {asset.get('texture_style', 'Hand-painted stylized game textures, vivid natural colours.')}"[:800]})["result"]
        save_state(state)
    task = wait(s["refine"], f"{aid} textures")
    out.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(task["model_urls"]["glb"], out)
    s["done"] = True
    save_state(state)
    return f"{aid}: {out.relative_to(ROOT)} ({out.stat().st_size / 1e6:.1f} MB)"


def main():
    manifest = json.loads(MANIFEST.read_text())
    cmd = sys.argv[1] if len(sys.argv) > 1 else "plan"
    args = sys.argv[2:]
    group = args[args.index("--group") + 1] if "--group" in args else None
    chosen = [a for a in manifest["assets"] if ("--pilot" in args and a.get("pilot")) or a["id"] in args
              or (group is not None and a.get("group") == group)] if args else manifest["assets"]
    state = load_state()
    if cmd == "plan":
        todo = [a for a in chosen if not (DIR / a["id"] / f"{a['id']}.glb").exists()]
        picture = CONCEPT_COST.get(manifest.get("image_model", "nano-banana"), 9)

        def price(a):
            st = state.get(a["id"], {})
            if a.get("via") == "nano":
                return (0 if "concept" in st else picture) + (0 if "image" in st else IMAGE_TO_3D_COST)
            return (0 if "preview" in st else PREVIEW_COST) + (0 if "refine" in st else REFINE_COST)
        cost = sum(price(a) for a in todo)
        print(f"{len(todo)} to make: {', '.join(a['id'] for a in todo)}")
        print(f"cost ≈ {cost} credits · balance {call('GET', '/v1/balance')['balance']}")
    elif cmd == "status":
        print(f"balance {call('GET', '/v1/balance')['balance']}")
        for a in manifest["assets"]:
            s = state.get(a["id"], {})
            print(f"  {a['id']:16} {'done' if s.get('done') else 'refine' if 'refine' in s else 'preview' if 'preview' in s else '-'}")
    elif cmd == "concept":
        redo = "--redo" in args
        with ThreadPoolExecutor(max_workers=5) as pool:
            for line in pool.map(lambda a: _safe(concept_one, a, manifest, state, redo), chosen):
                print(line, flush=True)
        print(f"balance now {call('GET', '/v1/balance')['balance']}")
    elif cmd == "make":
        with ThreadPoolExecutor(max_workers=5) as pool:
            for line in pool.map(lambda a: _safe(make_one, a, manifest, state), chosen):
                print(line, flush=True)
        print(f"balance now {call('GET', '/v1/balance')['balance']}")
    else:
        sys.exit(__doc__)


def _safe(fn, asset, manifest, state, *more):
    try:
        return fn(asset, manifest, state, *more)
    except Exception as e:  # keep the other assets going
        return f"{asset['id']}: FAILED {e}"


if __name__ == "__main__":
    main()
