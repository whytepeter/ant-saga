extends SceneTree
## Gives Amodu fingers. Meshy's auto-rig stops at the wrist (no finger bones),
## so his modelled fingers can't close and his hands stay flat. This finds the
## four fingers and the thumb in each hand's mesh, adds two bones to each
## (proximal and distal, children of the hand) and shares the hand's skin
## weights out along them. The skeleton's existing bones are untouched, so every
## animation clip still fits (a Blender round trip would re-orient the bones).
##
##   Godot --headless --path . -s tools/add_finger_bones.gd [-- --dir=res://assets/characters/amodu2/]
##
## Writes into the character folder:
##   hands_mesh.res   the body mesh with the new weights (skin indices 24+)
##   hands_skin.res   the skin with the finger binds appended, bound by name
##   hands.json       the finger bones: name, parent, rest (relative to parent)
## Player adds the bones and swaps the mesh and skin at load (player.gd
## _add_fingers); FingerCurl bends them.
##
## Each finger bone's rest has +Y along the finger and +X as the knuckle's
## hinge, so curling is a rotation about +X (positive closes toward the palm).

const HANDS := {"Right": "RightHand", "Left": "LeftHand"}
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
## Height up the hand (bone units) to start looking for separate fingers.
const SCAN_FROM := 6.0
## Where along a finger its distal bone starts (0 knuckle, 1 tip).
const SPLIT := 0.52

var dir := "res://assets/characters/amodu2/"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
	_run.call_deferred()


func _run() -> void:
	var model := (load(dir + "rigged.glb") as PackedScene).instantiate()
	root.add_child(model)
	var mi := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := mi.skin.duplicate() as Skin
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var per := bones.size() / verts.size()
	var new_bones: Array[Dictionary] = []
	# extra influences per vertex: v -> {bind: weight}; the hand's weight is moved onto them
	var moved := {}

	for side: String in HANDS:
		var hand_name: String = HANDS[side]
		var hand := -1
		for b in skin.get_bind_count():
			if String(skin.get_bind_name(b)) == hand_name:
				hand = b
		var bind := skin.get_bind_pose(hand)
		var local := {}  # vertex -> position in the hand bone's rest frame
		var hand_w := {}
		for v in verts.size():
			var w := 0.0
			for k in per:
				if bones[v * per + k] == hand:
					w += weights[v * per + k]
			if w > 0.001:
				local[v] = bind * verts[v]
				hand_w[v] = w
		var frame := _palm_frame(local)  # [normal, spread]
		var n: Vector3 = frame[0]
		var spread: Vector3 = frame[1]
		var adj := _adjacency(local, idx)
		var found := _find_digits(local, adj, spread)
		var digits: Array = found["fingers"]
		digits.append(found["thumb"])
		print("%s hand: %d vertices, knuckles at y %.1f, digits %s" % [side, local.size(), found["knuckle"],
			str(digits.map(func(d: Dictionary) -> int: return (d["members"] as Dictionary).size()))])

		for i in digits.size():
			var d: Dictionary = digits[i]
			var digit_name: String = FINGERS[i] if i < FINGERS.size() else "Thumb"
			var base: Vector3 = d["base"]
			var tip: Vector3 = d["tip"]
			var axis := (tip - base).normalized()
			var hinge := axis.cross(n).normalized()
			var rest_basis := Basis(hinge, axis, hinge.cross(axis).normalized())
			var mid := base.lerp(tip, SPLIT)
			var prox := Transform3D(rest_basis, base)
			var dist := Transform3D(rest_basis, mid)
			var prox_name := "%s%s1" % [side, digit_name]
			var dist_name := "%s%s2" % [side, digit_name]
			new_bones.append({"name": prox_name, "parent": hand_name, "rest": _xf_list(prox)})
			new_bones.append({"name": dist_name, "parent": prox_name, "rest": _xf_list(prox.affine_inverse() * dist)})
			var prox_bind := skin.get_bind_count()
			skin.add_named_bind(prox_name, prox.affine_inverse() * bind)
			var dist_bind := skin.get_bind_count()
			skin.add_named_bind(dist_name, dist.affine_inverse() * bind)
			d["binds"] = [prox_bind, dist_bind]
			d["axis"] = axis

		# each vertex goes to one digit: the thumb's own piece, else the finger
		# whose axis it is nearest (two fingers can be joined in the mesh, so a
		# split by piece alone can cut through one). Along that digit: none of
		# the hand's weight behind the knuckle, all of it past it, the tip half
		# to the distal bone; then both are smoothed over the mesh so the
		# creases at the joints are soft.
		var owner := {}  # vertex -> digit index
		var share := {}  # vertex -> how much goes to the digit (0..1)
		var distal := {}  # vertex -> how much of that goes to the distal bone
		var thumb_i := digits.size() - 1
		for v: int in local:
			var p: Vector3 = local[v]
			var best := -1
			var best_d := INF
			if (digits[thumb_i]["members"] as Dictionary).has(v):
				best = thumb_i
			else:
				for i in digits.size():
					var d: Dictionary = digits[i]
					var base: Vector3 = d["base"]
					var length := base.distance_to(d["tip"])
					var t := clampf((p - base).dot(d["axis"]) / length, -0.4, 1.0)
					var dist := (p - base - (d["axis"] as Vector3) * (t * length)).length()
					if i == thumb_i and dist > float(d["radius"]) * 1.8:
						continue  # the thumb only reaches past its own piece near its root
					if dist < best_d:
						best_d = dist
						best = i
			if best < 0:
				continue
			var dg: Dictionary = digits[best]
			var root: Vector3 = dg["base"]
			var t := (p - root).dot(dg["axis"]) / root.distance_to(dg["tip"])
			owner[v] = best
			share[v] = smoothstep(-0.3, 0.1, t)
			distal[v] = smoothstep(SPLIT - 0.15, SPLIT + 0.12, t)
		# smooth per position, not per vertex: the copies of a vertex along a
		# texture seam must keep identical weights or the skin cracks open
		var rep := {}  # vertex -> the first vertex at its position
		var first := {}
		for v: int in owner:
			var p: Vector3 = local[v]
			var key := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
			if not first.has(key):
				first[key] = v
			rep[v] = first[key]
		var near := {}  # representative -> neighbouring representatives on the same digit
		for v: int in owner:
			var r: int = rep[v]
			if not near.has(r):
				near[r] = {}
			for u: int in adj[v]:
				if rep.has(u) and owner[u] == owner[v] and rep[u] != r:
					(near[r] as Dictionary)[rep[u]] = true
		for it in 4:
			var next_share := {}
			var next_distal := {}
			for r: int in near:
				var s_sum := float(share[r])
				var d_sum := float(distal[r])
				for u: int in near[r]:
					s_sum += float(share[u])
					d_sum += float(distal[u])
				var count := 1 + (near[r] as Dictionary).size()
				next_share[r] = s_sum / count
				next_distal[r] = d_sum / count
			for r: int in next_share:
				share[r] = next_share[r]
				distal[r] = next_distal[r]
		for v: int in owner:
			share[v] = share[rep[v]]
			distal[v] = distal[rep[v]]
		for v: int in owner:
			var take: float = float(hand_w[v]) * float(share[v])
			if take <= 0.001:
				continue
			var binds: Array = digits[owner[v]]["binds"]
			moved[v] = {"hand": hand, "take": take, "add": {
				int(binds[0]): take * (1.0 - float(distal[v])), int(binds[1]): take * float(distal[v])}}

	# write the weights back: take from the hand, add the digits, keep the top four
	var out_bones := PackedInt32Array(bones)
	var out_weights := PackedFloat32Array(weights)
	for v: int in moved:
		var entry: Dictionary = moved[v]
		var infl := {}
		for k in per:
			var b := bones[v * per + k]
			if weights[v * per + k] > 0.0:
				infl[b] = float(infl.get(b, 0.0)) + weights[v * per + k]
		infl[entry["hand"]] = maxf(float(infl.get(entry["hand"], 0.0)) - float(entry["take"]), 0.0)
		for b: int in entry["add"]:
			infl[b] = float(infl.get(b, 0.0)) + float(entry["add"][b])
		var ranked := infl.keys()
		ranked.sort_custom(func(a: int, b: int) -> bool: return float(infl[a]) > float(infl[b]))
		var total := 0.0
		for k in mini(per, ranked.size()):
			total += float(infl[ranked[k]])
		for k in per:
			if k < ranked.size() and total > 0.0:
				out_bones[v * per + k] = int(ranked[k])
				out_weights[v * per + k] = float(infl[ranked[k]]) / total
			else:
				out_bones[v * per + k] = 0
				out_weights[v * per + k] = 0.0
	arr[Mesh.ARRAY_BONES] = out_bones
	arr[Mesh.ARRAY_WEIGHTS] = out_weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mi.mesh.surface_get_material(0))
	print("reweighted %d vertices, %d finger bones" % [moved.size(), new_bones.size()])
	var ok := ResourceSaver.save(mesh, dir + "hands_mesh.res", ResourceSaver.FLAG_COMPRESS) == OK \
		and ResourceSaver.save(skin, dir + "hands_skin.res") == OK
	var f := FileAccess.open(dir + "hands.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"note": "Finger bones added by tools/add_finger_bones.gd", "bones": new_bones}, "\t"))
	print("saved hands_mesh.res, hands_skin.res, hands.json: %s" % ("OK" if ok else "FAILED"))
	quit()


## The palm's normal (its thinnest direction) and the across-the-knuckles
## direction, from the hand's vertices (bone +Y runs up the hand).
func _palm_frame(local: Dictionary) -> Array:
	var c := Vector3.ZERO
	for v: int in local:
		c += local[v]
	c /= local.size()
	var cov := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for v: int in local:
		var d: Vector3 = (local[v] as Vector3) - c
		cov[0] += d * d.x
		cov[1] += d * d.y
		cov[2] += d * d.z
	var m := Basis(cov[0], cov[1], cov[2])
	# the thinnest direction: power iteration on the inverse
	var inv := m.inverse()
	var n := Vector3(1.0, 0.3, 0.7).normalized()
	for i in 60:
		n = (inv * n).normalized()
	var spread := Vector3.UP.cross(n).normalized()
	n = spread.cross(Vector3.UP).normalized()
	return [n, spread]


## Neighbours within the hand, with vertices at the same spot (UV seams) merged.
func _adjacency(local: Dictionary, idx: PackedInt32Array) -> Dictionary:
	var first := {}
	var canon := {}
	for v: int in local:
		var p: Vector3 = local[v]
		var key := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
		if not first.has(key):
			first[key] = v
		canon[v] = first[key]
	var adj := {}
	for v: int in local:
		adj[v] = []
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := idx[t + e]
			var b := idx[t + (e + 1) % 3]
			if local.has(a) and local.has(b):
				(adj[a] as Array).append(b)
				(adj[b] as Array).append(a)
	# seam twins are neighbours too
	var twins := {}
	for v: int in canon:
		var c: int = canon[v]
		if not twins.has(c):
			twins[c] = []
		(twins[c] as Array).append(v)
	for c: int in twins:
		var group: Array = twins[c]
		for a: int in group:
			for b: int in group:
				if a != b:
					(adj[a] as Array).append(b)
	return adj


## The pieces of the hand above height y (each separate piece has its members).
func _pieces(local: Dictionary, adj: Dictionary, y: float) -> Array:
	var seen := {}
	var out := []
	for v: int in local:
		if seen.has(v) or (local[v] as Vector3).y < y:
			continue
		var members := {}
		var stack := [v]
		seen[v] = true
		while not stack.is_empty():
			var c: int = stack.pop_back()
			members[c] = true
			for d: int in adj[c]:
				if not seen.has(d) and (local[d] as Vector3).y >= y:
					seen[d] = true
					stack.append(d)
		out.append(members)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.size() > b.size())
	return out


## The four fingers (index first, toward the thumb) and the thumb: members,
## base (the knuckle, centred in the finger), tip and radius.
func _find_digits(local: Dictionary, adj: Dictionary, spread: Vector3) -> Dictionary:
	# the thumb breaks away from the palm lower down than the fingers do
	var thumb := {}
	var y := SCAN_FROM
	while y < 12.0 and thumb.is_empty():
		var pieces := _pieces(local, adj, y)
		if pieces.size() >= 2 and (pieces[1] as Dictionary).size() >= 20:
			thumb = pieces[1]
			for extra in range(2, pieces.size()):  # the nail can be a piece of its own
				if (pieces[extra] as Dictionary).size() >= 10 and _near(local, pieces[extra], thumb, 2.0):
					thumb.merge(pieces[extra])
		y += 0.5
	# the knuckles: the lowest height where the rest splits into long pieces
	var knuckle := 9.0
	var finger_pts: Array[int] = []
	for step in 20:
		var h := 8.0 + step * 0.4
		var long := 0
		for piece: Dictionary in _pieces(local, adj, h):
			if piece.size() >= 20 and not _overlaps(piece, thumb) and _extent(local, piece) > 3.0:
				long += 1
		if long >= 3:
			knuckle = h
			break
	for v: int in local:
		if (local[v] as Vector3).y >= knuckle and not thumb.has(v):
			finger_pts.append(v)
	# split the fingers across the knuckles into four (k-means on the spread coordinate)
	var s_lo := INF
	var s_hi := -INF
	for v in finger_pts:
		var s := (local[v] as Vector3).dot(spread)
		s_lo = minf(s_lo, s)
		s_hi = maxf(s_hi, s)
	var centres: Array[float] = []
	for k in 4:
		centres.append(lerpf(s_lo, s_hi, (k + 0.5) / 4.0))
	var groups: Array = []
	for it in 30:
		groups = [{}, {}, {}, {}]
		var sums := [0.0, 0.0, 0.0, 0.0]
		for v in finger_pts:
			var s := (local[v] as Vector3).dot(spread)
			var best := 0
			for k in 4:
				if absf(s - centres[k]) < absf(s - centres[best]):
					best = k
			(groups[best] as Dictionary)[v] = true
			sums[best] += s
		for k in 4:
			if (groups[k] as Dictionary).size() > 0:
				centres[k] = float(sums[k]) / (groups[k] as Dictionary).size()
	# index finger first: the one nearest the thumb
	var thumb_s := 0.0
	for v: int in thumb:
		thumb_s += (local[v] as Vector3).dot(spread)
	thumb_s /= maxf(thumb.size(), 1.0)
	var order := [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return absf(centres[a] - thumb_s) < absf(centres[b] - thumb_s))
	var fingers: Array = []
	for k: int in order:
		fingers.append(_digit(local, groups[k], knuckle))
	return {"fingers": fingers, "thumb": _digit(local, thumb, INF), "knuckle": knuckle}


## Base, tip and radius of one digit from its vertices.
func _digit(local: Dictionary, members: Dictionary, knuckle: float) -> Dictionary:
	var pts: Array[Vector3] = []
	for v: int in members:
		pts.append(local[v])
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	var count := pts.size()
	var base := Vector3.ZERO
	var tip := Vector3.ZERO
	var nb := maxi(count / 6, 1)
	for i in nb:
		base += pts[i]
		tip += pts[count - 1 - i]
	base /= nb
	tip /= nb
	if knuckle != INF:
		base.y = knuckle - 0.6  # the joint sits a little below where the fingers part
	var axis := (tip - base).normalized()
	var r := 0.0
	for p in pts:
		r += (p - base - axis * (p - base).dot(axis)).length()
	return {"members": members, "base": base, "tip": tip, "radius": r / count}


func _near(local: Dictionary, a: Dictionary, b: Dictionary, dist: float) -> bool:
	var ca := Vector3.ZERO
	for v: int in a:
		ca += local[v]
	ca /= a.size()
	for v: int in b:
		if (local[v] as Vector3).distance_to(ca) < dist * 2.0:
			return true
	return false


func _overlaps(a: Dictionary, b: Dictionary) -> bool:
	for v: int in a:
		if b.has(v):
			return true
	return false


func _extent(local: Dictionary, piece: Dictionary) -> float:
	var lo := INF
	var hi := -INF
	for v: int in piece:
		lo = minf(lo, (local[v] as Vector3).y)
		hi = maxf(hi, (local[v] as Vector3).y)
	return hi - lo


func _xf_list(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
