#!/usr/bin/env python3
"""Generate garden models with the Meshy API from assets/garden/manifest.json.

    python3 tools/meshy_assets.py plan            # what would be made and what it costs (spends nothing)
    python3 tools/meshy_assets.py make --pilot    # generate the pilot set (spends credits)
    python3 tools/meshy_assets.py make daisy twig # generate named assets (spends credits)
    python3 tools/meshy_assets.py make --group creatures
    python3 tools/meshy_assets.py status          # credit balance and each asset's state

Each asset is a text-to-3D preview (shape, 20 credits) then a refine with PBR
textures (10 credits); the GLB lands in assets/garden/<id>/<id>.glb. Task ids
are saved in assets/garden/state.json, so a rerun resumes instead of paying
again. The key is read from .env (MESHY_API_KEY) and never printed.
"""

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


def wait(task_id, label):
    last = -1
    while True:
        t = call("GET", f"/v2/text-to-3d/{task_id}")
        if t["status"] == "SUCCEEDED":
            return t
        if t["status"] in ("FAILED", "CANCELED"):
            raise RuntimeError(f"{label}: {t['status']} {t.get('task_error')}")
        if t.get("progress", 0) // 25 != last:
            last = t.get("progress", 0) // 25
            print(f"  {label}: {t['status'].lower()} {t.get('progress', 0)}%", flush=True)
        time.sleep(8)


def make_one(asset, manifest, state):
    aid = asset["id"]
    s = state.setdefault(aid, {})
    out = DIR / aid / f"{aid}.glb"
    if out.exists():
        return f"{aid}: already downloaded"
    if "preview" not in s:
        s["preview"] = call("POST", "/v2/text-to-3d", {
            "mode": "preview", "prompt": f"{asset['prompt']} {manifest['style']}"[:800],
            "ai_model": manifest.get("ai_model", "latest"), "topology": "triangle",
            "target_polycount": asset["polycount"], "should_remesh": True})["result"]
        save_state(state)
    wait(s["preview"], f"{aid} shape")
    if "refine" not in s:
        s["refine"] = call("POST", "/v2/text-to-3d", {
            "mode": "refine", "preview_task_id": s["preview"], "enable_pbr": True,
            "texture_prompt": f"{asset['prompt']} Hand-painted stylized game textures, vivid natural colours."[:800]})["result"]
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
        cost = sum((0 if "preview" in state.get(a["id"], {}) else PREVIEW_COST) +
                   (0 if "refine" in state.get(a["id"], {}) else REFINE_COST) for a in todo)
        print(f"{len(todo)} to make: {', '.join(a['id'] for a in todo)}")
        print(f"cost ≈ {cost} credits · balance {call('GET', '/v1/balance')['balance']}")
    elif cmd == "status":
        print(f"balance {call('GET', '/v1/balance')['balance']}")
        for a in manifest["assets"]:
            s = state.get(a["id"], {})
            print(f"  {a['id']:16} {'done' if s.get('done') else 'refine' if 'refine' in s else 'preview' if 'preview' in s else '-'}")
    elif cmd == "make":
        with ThreadPoolExecutor(max_workers=5) as pool:
            for line in pool.map(lambda a: _safe(make_one, a, manifest, state), chosen):
                print(line, flush=True)
        print(f"balance now {call('GET', '/v1/balance')['balance']}")
    else:
        sys.exit(__doc__)


def _safe(fn, asset, manifest, state):
    try:
        return fn(asset, manifest, state)
    except Exception as e:  # keep the other assets going
        return f"{asset['id']}: FAILED {e}"


if __name__ == "__main__":
    main()
