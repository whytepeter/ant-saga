#!/usr/bin/env python3
"""Build a rigged, animated character with the Meshy API from
assets/characters/<name>/manifest.json.

    python3 tools/meshy_character.py plan amodu     # stages left and their cost (spends nothing)
    python3 tools/meshy_character.py model amodu    # textured model in A-pose (30 credits)
    python3 tools/meshy_character.py rig amodu      # auto-rig (5) + all library actions (3 each)
                                                    # + custom text-to-motion clips (13 each)
    python3 tools/meshy_character.py status amodu

Downloads land in assets/characters/<name>/: model.glb, rigged.glb, and one
anim_<batch>.glb per group of up to 10 library actions (each clip named by
Meshy) plus motion_<name>.glb per custom clip. Every task id is saved in
state.json, so a rerun resumes instead of paying twice. The API key comes from
.env (MESHY_API_KEY) and is never printed.
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
API = "https://api.meshy.ai/openapi"
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
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


class Char:
    def __init__(self, name):
        self.dir = ROOT / "assets" / "characters" / name
        self.manifest = json.loads((self.dir / "manifest.json").read_text())
        self.state_path = self.dir / "state.json"
        self.state = json.loads(self.state_path.read_text()) if self.state_path.exists() else {}

    def save(self):
        with _lock:
            self.state_path.write_text(json.dumps(self.state, indent=2) + "\n")

    def task(self, key, create):
        """Runs `create` once and remembers the task id under `key`."""
        if key not in self.state:
            self.state[key] = create()
            self.save()
        return self.state[key]


def wait(path, label):
    last = -1
    while True:
        t = call("GET", path)
        if t["status"] == "SUCCEEDED":
            return t
        if t["status"] in ("FAILED", "CANCELED", "EXPIRED"):
            raise RuntimeError(f"{label}: {t['status']} {t.get('task_error')}")
        p = int(t.get("progress", 0))
        if p // 25 != last:
            last = p // 25
            print(f"  {label}: {t['status'].lower()} {p}%", flush=True)
        time.sleep(8)


def fetch(url, dest):
    if dest.exists():  # a rerun only fetches what's missing
        return
    req = urllib.request.Request(url, headers={"User-Agent": "ant-game/1.0"})
    with urllib.request.urlopen(req, timeout=300) as r, open(dest, "wb") as f:
        f.write(r.read())
    print(f"  saved {dest.relative_to(ROOT)} ({dest.stat().st_size / 1e6:.1f} MB)", flush=True)


def glb_urls(obj):
    """Every .glb URL anywhere in a task's JSON, with its key path."""
    out = []
    def walk(o, path):
        if isinstance(o, dict):
            for k, v in o.items():
                walk(v, f"{path}.{k}" if path else k)
        elif isinstance(o, list):
            for i, v in enumerate(o):
                walk(v, f"{path}[{i}]")
        elif isinstance(o, str) and ".glb" in o.split("?")[0]:
            out.append((path, o))
    walk(obj, "")
    return out


def stage_model(c):
    m = c.manifest
    ref = c.dir / m["reference_image"] if m.get("reference_image") else None
    if ref is not None and ref.exists():
        # image-to-3D from the design reference: one task, shape and PBR textures
        mime = "image/png" if ref.suffix.lower() == ".png" else "image/jpeg"
        uri = f"data:{mime};base64," + base64.b64encode(ref.read_bytes()).decode()
        rid = c.task("refine", lambda: call("POST", "/v1/image-to-3d", {
            "image_url": uri, "ai_model": "latest", "pose_mode": "a-pose", "enable_pbr": True,
            "should_remesh": True, "topology": "triangle", "target_polycount": m.get("polycount", 30000),
            "texture_prompt": m.get("texture_prompt", "")[:800]})["result"])
        t = wait(f"/v1/image-to-3d/{rid}", "image to 3D")
        fetch(t["model_urls"]["glb"], c.dir / "model.glb")
        return
    pid = c.task("preview", lambda: call("POST", "/v2/text-to-3d", {
        "mode": "preview", "prompt": m["prompt"][:800], "ai_model": "latest", "pose_mode": "a-pose",
        "topology": "triangle", "target_polycount": m.get("polycount", 30000), "should_remesh": True})["result"])
    wait(f"/v2/text-to-3d/{pid}", "shape")
    rid = c.task("refine", lambda: call("POST", "/v2/text-to-3d", {
        "mode": "refine", "preview_task_id": pid, "enable_pbr": True,
        "texture_prompt": m.get("texture_prompt", "")[:800]})["result"])
    t = wait(f"/v2/text-to-3d/{rid}", "textures")
    fetch(t["model_urls"]["glb"], c.dir / "model.glb")


def action_batches(m):
    """[(state key / file stem, [(name, action id), ...])], up to 10 per batch."""
    batches = []
    for key, prefix in (("actions", "anim_"), ("more_actions", "anim_more_")):
        items = list(m.get(key, {}).items())
        for i in range(0, len(items), 10):
            batches.append((f"{prefix}{i // 10}", items[i:i + 10]))
    return batches


def stage_rig(c):
    m = c.manifest
    rid = c.state["refine"]
    rig = c.task("rig", lambda: call("POST", "/v1/rigging", {
        "input_task_id": rid, "height_meters": m.get("height_meters", 1.7)})["result"])
    t = wait(f"/v1/rigging/{rig}", "rig")
    c.state["rig_result"] = t.get("result", {})
    c.save()
    for path, url in glb_urls(t.get("result", {})):
        name = "rigged.glb" if "rig" in path.lower() or "character" in path.lower() else f"rig_{path.split('.')[-1]}.glb"
        fetch(url, c.dir / name)

    # "actions" were fetched in batches of 10 keyed by position, so actions added
    # later go in "more_actions" (their own batches, anim_more_<i>.glb) rather
    # than shifting the old batches and being skipped as already done
    batches = action_batches(m)
    motions = list(m.get("motions", {}).items())

    def do_batch(i):
        name, batch = batches[i]
        ids = [a for _, a in batch]
        tid = c.task(name, lambda: call("POST", "/v1/animations", {"rig_task_id": rig, "action_ids": ids})["result"])
        t = wait(f"/v1/animations/{tid}", f"animations {name}")
        fetch(t["result"]["animation_glb_url"], c.dir / f"{name}.glb")
        return f"{name}: {', '.join(n for n, _ in batch)}"

    def do_motion(item):
        name, spec = item
        mid = c.task(f"motion_{name}", lambda: call("POST", "/v1/text-to-motion", {
            "prompt": spec["prompt"][:400], "duration": spec["duration"], "mode": "prime"})["result"])
        wait(f"/v1/text-to-motion/{mid}", f"motion {name}")
        tid = c.task(f"motion_anim_{name}", lambda: call("POST", "/v1/animations", {"rig_task_id": rig, "motion_task_id": mid})["result"])
        t = wait(f"/v1/animations/{tid}", f"apply {name}")
        fetch(t["result"]["animation_glb_url"], c.dir / f"motion_{name}.glb")
        return f"motion {name}"

    jobs = [(do_batch, i) for i in range(len(batches))] + [(do_motion, mo) for mo in motions]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for line in pool.map(lambda j: _safe(j[0], j[1]), jobs):
            print(line, flush=True)


def _safe(fn, arg):
    try:
        return fn(arg)
    except Exception as e:
        return f"FAILED {arg if isinstance(arg, int) else arg[0]}: {e}"


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, c = sys.argv[1], Char(sys.argv[2])
    n_actions = len(c.manifest["actions"]) + len(c.manifest.get("more_actions", {}))
    n_motions = len(c.manifest.get("motions", {}))
    if cmd == "plan":
        made = sum(1 for k in c.manifest.get("motions", {}) if f"motion_{k}" in c.state)
        new_actions = sum(len(batch) for name, batch in action_batches(c.manifest) if name not in c.state)
        cost = (0 if "refine" in c.state else 30) + (0 if "rig" in c.state else 5) + 3 * new_actions \
            + 13 * (n_motions - made) + 3 * (n_motions - sum(1 for k in c.manifest.get("motions", {}) if f"motion_anim_{k}" in c.state))
        print(f"model 30 · rig 5 · {n_actions} actions × 3 · {n_motions} motions × 13  → about {cost} credits left to spend")
        print(f"balance {call('GET', '/v1/balance')['balance']}")
    elif cmd == "model":
        stage_model(c)
        print(f"balance now {call('GET', '/v1/balance')['balance']}")
    elif cmd == "rig":
        stage_rig(c)
        print(f"balance now {call('GET', '/v1/balance')['balance']}")
    elif cmd == "status":
        print(json.dumps({k: v for k, v in c.state.items() if k != "rig_result"}, indent=2))
        print(f"balance {call('GET', '/v1/balance')['balance']}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
