class_name ItemModels
extends RefCounted
## What an item looks like in the world (ItemPickup) and on its icon
## (tools/render_icons.gd): its own model (data/items.json "icon": a garden
## prop id, "nature:<id>" for a Poly Haven model, "weapon:<id>"), or for the
## things with no model of their own ("made:<shape>": fibre, twine, silk...) a
## small shape built here. Unit size: its longest side about 1, standing on
## the ground at its origin.


## A node showing item `id` (null if it has no picture).
static func make(id: StringName) -> Node3D:
	return model(String(Items.info(id).get("icon", "")))


static func model(icon: String) -> Node3D:
	if icon.begins_with("made:"):
		return made(icon.trim_prefix("made:"))
	if icon.begins_with("nature:"):
		var v := NatureModels.variant(icon.trim_prefix("nature:"))
		if v == null:
			return null
		var holder := Node3D.new()
		holder.add_child(NatureModels.instance(v, Transform3D.IDENTITY))
		return holder
	var prop_id := icon
	var turn := Basis.IDENTITY
	if icon.begins_with("weapon:"):
		prop_id = String(Weapons.info(StringName(icon.trim_prefix("weapon:"))).get("model", ""))
		turn = Basis(Vector3.BACK, deg_to_rad(-40.0))  # tools lie diagonally, head up
	var prop := GardenProps.get_prop(prop_id) if prop_id != "" else null
	if prop == null:
		return null
	var holder := Node3D.new()
	holder.add_child(GardenProps.instance(prop, Transform3D(turn, Vector3.ZERO)))
	return holder


static func _mat(col: Color, rough := 0.7, alpha := 1.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


static func _mesh(mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	return mi


## The items with no model of their own, built from simple shapes (about a
## unit across, sitting on y = 0).
static func made(shape: String) -> Node3D:
	var n := Node3D.new()
	var lift := Vector3.ZERO
	match shape:
		"fibre":
			# a loose bundle of long grass strips, tied in the middle
			var green := _mat(Color(0.55, 0.66, 0.3), 0.8)
			for i in 7:
				var strip := BoxMesh.new()
				strip.size = Vector3(0.05, 1.0, 0.012)
				var fan := Basis(Vector3.BACK, deg_to_rad(-40.0 + (i - 3) * 5.0)) * Basis(Vector3.UP, i * 0.4)
				n.add_child(_mesh(strip, green, Transform3D(fan, Vector3((i - 3) * 0.018, 0, (i % 2) * 0.02))))
			var band := TorusMesh.new()
			band.inner_radius = 0.06
			band.outer_radius = 0.085
			n.add_child(_mesh(band, _mat(Color(0.5, 0.36, 0.2)), Transform3D(Basis(Vector3.BACK, deg_to_rad(-40.0)), Vector3.ZERO)))
			lift = Vector3(0, 0.36, 0)
		"twine":
			var cord := _mat(Color(0.7, 0.58, 0.36), 0.85)
			for i in 4:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.26
				ring.outer_radius = 0.34
				n.add_child(_mesh(ring, cord, Transform3D(Basis(Vector3.RIGHT, 0.12 * i), Vector3(0, i * 0.075, 0))))
			lift = Vector3(0, 0.05, 0)
		"silk":
			# a wound ball of spider silk: a pearly core with strands wrapped
			# round it every which way, shaded so it reads as a ball, not a symbol
			var core := SphereMesh.new()
			core.radius = 0.3
			core.height = 0.6
			n.add_child(_mesh(core, _mat(Color(0.5, 0.54, 0.58), 0.4), Transform3D.IDENTITY))
			var strand := _mat(Color(0.8, 0.82, 0.8), 0.25)
			strand.rim_enabled = true
			strand.rim = 0.5
			for i in 9:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.3
				ring.outer_radius = 0.335
				var b := Basis(Vector3.UP, i * 0.71) * Basis(Vector3.RIGHT, 0.3 + i * 0.37)
				n.add_child(_mesh(ring, strand, Transform3D(b, Vector3.ZERO)))
			lift = Vector3(0, 0.34, 0)
		"rubber":
			var chunk := CapsuleMesh.new()
			chunk.radius = 0.22
			chunk.height = 0.8
			n.add_child(_mesh(chunk, _mat(Color(0.28, 0.13, 0.1), 0.45),
				Transform3D(Basis(Vector3.BACK, 1.2).scaled(Vector3(1.0, 1.0, 0.55)), Vector3.ZERO)))
			lift = Vector3(0, 0.15, 0)
		"slime":
			var blob := SphereMesh.new()
			blob.radius = 0.4
			blob.height = 0.5
			n.add_child(_mesh(blob, _mat(Color(0.55, 0.72, 0.35), 0.1, 0.85, 0.2), Transform3D.IDENTITY))
			lift = Vector3(0, 0.2, 0)
		"sap":
			# a glob of amber sap: a fat drop slumped on itself, a smaller
			# bead run off it, glossy and lit from inside
			var amber := _mat(Color(0.74, 0.3, 0.03), 0.06, 0.9, 0.3)
			amber.metallic_specular = 1.0
			amber.rim_enabled = true
			amber.rim = 0.4
			var glob := SphereMesh.new()
			glob.radius = 0.4
			glob.height = 0.8
			n.add_child(_mesh(glob, amber, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.62, 0.9)), Vector3.ZERO)))
			var top := SphereMesh.new()
			top.radius = 0.24
			top.height = 0.48
			n.add_child(_mesh(top, amber, Transform3D(Basis.IDENTITY, Vector3(-0.06, 0.2, 0.02))))
			var bead := SphereMesh.new()
			bead.radius = 0.13
			bead.height = 0.24
			n.add_child(_mesh(bead, amber, Transform3D(Basis.IDENTITY, Vector3(0.42, -0.1, 0.12))))
			lift = Vector3(0, 0.25, 0)
		"honeydew":
			var dew := SphereMesh.new()
			dew.radius = 0.36
			dew.height = 0.62
			n.add_child(_mesh(dew, _mat(Color(0.98, 0.84, 0.36), 0.05, 0.8, 0.3), Transform3D.IDENTITY))
			lift = Vector3(0, 0.26, 0)
		"shell":
			var plate := SphereMesh.new()
			plate.radius = 0.45
			plate.height = 0.45
			plate.is_hemisphere = true
			n.add_child(_mesh(plate, _mat(Color(0.12, 0.1, 0.13), 0.22),
				Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.45, 0.75)), Vector3.ZERO)))
		"bandage":
			var roll := CylinderMesh.new()
			roll.top_radius = 0.2
			roll.bottom_radius = 0.2
			roll.height = 0.55
			var lay := Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, 0.3)
			n.add_child(_mesh(roll, _mat(Color(0.4, 0.6, 0.3), 0.75), Transform3D(lay, Vector3.ZERO)))
			for x: float in [-0.12, 0.12]:
				var tie := TorusMesh.new()
				tie.inner_radius = 0.19
				tie.outer_radius = 0.235
				n.add_child(_mesh(tie, _mat(Color(0.72, 0.62, 0.4)), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0, 0))))
			lift = Vector3(0, 0.2, 0)
		"torch":
			var stick := CylinderMesh.new()
			stick.top_radius = 0.05
			stick.bottom_radius = 0.06
			stick.height = 1.0
			var tilt := Basis(Vector3.BACK, deg_to_rad(-35.0))
			n.add_child(_mesh(stick, _mat(Color(0.45, 0.3, 0.17), 0.85), Transform3D(tilt, Vector3.ZERO)))
			var lump := SphereMesh.new()
			lump.radius = 0.14
			lump.height = 0.3
			n.add_child(_mesh(lump, _mat(Color(1.0, 0.58, 0.2), 0.2, 1.0, 1.6), Transform3D(tilt, tilt * Vector3(0, 0.5, 0))))
			lift = Vector3(0, 0.45, 0)
		"flint":
			var stone := SphereMesh.new()
			stone.radius = 0.4
			stone.height = 0.6
			stone.radial_segments = 7
			stone.rings = 3
			n.add_child(_mesh(stone, _mat(Color(0.2, 0.2, 0.23), 0.18),
				Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), 0.7).scaled(Vector3(1.2, 0.8, 0.9)), Vector3.ZERO)))
			lift = Vector3(0, 0.22, 0)
		"sprig":
			# a thin green stalk with two leaves at the top (Grounded's sprig)
			var stalk := CylinderMesh.new()
			stalk.top_radius = 0.025
			stalk.bottom_radius = 0.035
			stalk.height = 1.0
			var green := _mat(Color(0.42, 0.62, 0.24), 0.7)
			var tilt := Basis(Vector3.BACK, deg_to_rad(-30.0))
			n.add_child(_mesh(stalk, green, Transform3D(tilt, Vector3.ZERO)))
			for side: float in [-1.0, 1.0]:
				var leaf := SphereMesh.new()
				leaf.radius = 0.16
				leaf.height = 0.06
				var at := tilt * Vector3(side * 0.12, 0.46, 0.0)
				n.add_child(_mesh(leaf, _mat(Color(0.48, 0.7, 0.28), 0.6),
					Transform3D(tilt * Basis(Vector3.BACK, side * 0.5).scaled(Vector3(1.0, 1.0, 0.55)), at)))
			lift = Vector3(0, 0.42, 0)
		"plank":
			# a slab of grass stalk: pale green, with its ribs
			var slab := BoxMesh.new()
			slab.size = Vector3(1.0, 0.12, 0.34)
			n.add_child(_mesh(slab, _mat(Color(0.6, 0.72, 0.34), 0.75), Transform3D(Basis(Vector3.UP, 0.4), Vector3.ZERO)))
			var rib := BoxMesh.new()
			rib.size = Vector3(1.0, 0.03, 0.03)
			for z: float in [-0.1, 0.0, 0.1]:
				n.add_child(_mesh(rib, _mat(Color(0.5, 0.62, 0.26), 0.8),
					Transform3D(Basis(Vector3.UP, 0.4), Basis(Vector3.UP, 0.4) * Vector3(0, 0.07, z))))
			lift = Vector3(0, 0.06, 0)
		"meat":
			# a raw, pinkish chunk of bug
			var chunk := SphereMesh.new()
			chunk.radius = 0.38
			chunk.height = 0.5
			chunk.radial_segments = 9
			chunk.rings = 5
			n.add_child(_mesh(chunk, _mat(Color(0.86, 0.5, 0.46), 0.35),
				Transform3D(Basis(Vector3.UP, 0.5).scaled(Vector3(1.25, 0.8, 0.9)), Vector3.ZERO)))
			lift = Vector3(0, 0.2, 0)
		"fuzz":
			# a ball of red mite fuzz: many small tufts
			var red := _mat(Color(0.82, 0.2, 0.16), 0.95)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 18:
				var tuft := SphereMesh.new()
				tuft.radius = rng.randf_range(0.1, 0.16)
				tuft.height = tuft.radius * 2.0
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
				n.add_child(_mesh(tuft, red, Transform3D(Basis.IDENTITY, dir * 0.24)))
			lift = Vector3(0, 0.3, 0)
		"saddle":
			# a leaf folded over into a pad, lashed with two twine straps
			var pad := SphereMesh.new()
			pad.radius = 0.5
			pad.height = 0.5
			pad.is_hemisphere = true
			n.add_child(_mesh(pad, _mat(Color(0.42, 0.58, 0.26), 0.8),
				Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.55, 0.72)), Vector3.ZERO)))
			var rib := CylinderMesh.new()
			rib.top_radius = 0.025
			rib.bottom_radius = 0.025
			rib.height = 1.0
			n.add_child(_mesh(rib, _mat(Color(0.62, 0.7, 0.36), 0.8),
				Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.27, 0))))
			for x: float in [-0.2, 0.2]:
				var strap := TorusMesh.new()
				strap.inner_radius = 0.34
				strap.outer_radius = 0.38
				n.add_child(_mesh(strap, _mat(Color(0.72, 0.62, 0.4)),
					Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(1.0, 0.7, 1.0)), Vector3(x, 0.02, 0))))
			lift = Vector3(0, 0.05, 0)
		"roast_meat":
			# a chunk of bug meat roasted brown, charred at the edges
			var chunk := SphereMesh.new()
			chunk.radius = 0.38
			chunk.height = 0.5
			chunk.radial_segments = 9
			chunk.rings = 5
			var roast := _mat(Color(0.55, 0.3, 0.14), 0.45)
			n.add_child(_mesh(chunk, roast, Transform3D(Basis(Vector3.UP, 0.5).scaled(Vector3(1.25, 0.8, 0.9)), Vector3.ZERO)))
			var char_mat := _mat(Color(0.16, 0.09, 0.05), 0.7)
			for k in 3:  # grill marks
				var mark := BoxMesh.new()
				mark.size = Vector3(0.06, 0.03, 0.62)
				n.add_child(_mesh(mark, char_mat, Transform3D(Basis(Vector3.UP, 0.5 + 0.9),
					Basis(Vector3.UP, 0.5) * Vector3(-0.2 + k * 0.2, 0.2, 0.0))))
			lift = Vector3(0, 0.2, 0)
		"skewer":
			# a sprig through three mushroom caps, browned
			var stick := CylinderMesh.new()
			stick.top_radius = 0.025
			stick.bottom_radius = 0.03
			stick.height = 1.1
			var tilt := Basis(Vector3.BACK, deg_to_rad(-40.0))
			n.add_child(_mesh(stick, _mat(Color(0.42, 0.55, 0.24), 0.7), Transform3D(tilt, Vector3.ZERO)))
			var cap_mat := _mat(Color(0.62, 0.42, 0.24), 0.5)
			for k in 3:
				var cap := SphereMesh.new()
				cap.radius = 0.15
				cap.height = 0.18
				cap.is_hemisphere = true
				n.add_child(_mesh(cap, cap_mat, Transform3D(tilt * Basis(Vector3.RIGHT, PI * 0.5), tilt * Vector3(0, -0.05 + k * 0.22, 0))))
			lift = Vector3(0, 0.45, 0)
		"bag":
			# a sack of woven fibre, drawn shut with twine
			var sack := SphereMesh.new()
			sack.radius = 0.4
			sack.height = 0.9
			var weave := _mat(Color(0.7, 0.66, 0.4), 0.9)
			n.add_child(_mesh(sack, weave, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.85, 0.8)), Vector3(0, 0.38, 0))))
			var cord := _mat(Color(0.5, 0.36, 0.2))
			var tie := TorusMesh.new()
			tie.inner_radius = 0.1
			tie.outer_radius = 0.15
			n.add_child(_mesh(tie, cord, Transform3D(Basis.IDENTITY, Vector3(0, 0.74, 0))))
			var neck := CylinderMesh.new()
			neck.top_radius = 0.16
			neck.bottom_radius = 0.1
			neck.height = 0.18
			n.add_child(_mesh(neck, weave, Transform3D(Basis.IDENTITY, Vector3(0, 0.84, 0))))
			for k in 4:  # the weave's bands
				var band := TorusMesh.new()
				band.inner_radius = 0.33 - absf(k - 1.5) * 0.05
				band.outer_radius = band.inner_radius + 0.03
				n.add_child(_mesh(band, _mat(Color(0.58, 0.54, 0.3), 0.9), Transform3D(Basis.IDENTITY, Vector3(0, 0.18 + k * 0.15, 0))))
		"flask", "flask_full":
			# a round clay flask with a neck and a stopper; full, the water shows
			var clay := _mat(Color(0.66, 0.38, 0.24), 0.8)
			var body := SphereMesh.new()
			body.radius = 0.36
			body.height = 0.66
			n.add_child(_mesh(body, clay, Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0))))
			var neck := CylinderMesh.new()
			neck.top_radius = 0.1
			neck.bottom_radius = 0.14
			neck.height = 0.26
			n.add_child(_mesh(neck, clay, Transform3D(Basis.IDENTITY, Vector3(0, 0.74, 0))))
			var cord := TorusMesh.new()
			cord.inner_radius = 0.12
			cord.outer_radius = 0.16
			n.add_child(_mesh(cord, _mat(Color(0.5, 0.36, 0.2)), Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 0))))
			if shape == "flask_full":
				var cork := CylinderMesh.new()
				cork.top_radius = 0.09
				cork.bottom_radius = 0.08
				cork.height = 0.14
				n.add_child(_mesh(cork, _mat(Color(0.45, 0.3, 0.16), 0.9), Transform3D(Basis.IDENTITY, Vector3(0, 0.92, 0))))
				var drop := SphereMesh.new()
				drop.radius = 0.08
				drop.height = 0.14
				n.add_child(_mesh(drop, _mat(Color(0.55, 0.78, 0.95), 0.05, 0.85, 0.3), Transform3D(Basis.IDENTITY, Vector3(0.2, 0.6, 0.24))))
		"golden_thread":
			# a skein of golden silk: loops wound round and round, glinting
			var gold := _mat(Color(0.95, 0.72, 0.22), 0.25, 1.0, 0.25)
			gold.metallic = 0.6
			gold.rim_enabled = true
			gold.rim = 0.6
			for i in 7:
				var loop := TorusMesh.new()
				loop.inner_radius = 0.3
				loop.outer_radius = 0.36
				var tilt := Basis(Vector3.UP, 0.45 * i) * Basis(Vector3.RIGHT, PI / 2.0 + 0.35 * sin(i * 1.7))
				n.add_child(_mesh(loop, gold, Transform3D(tilt, Vector3(0, 0.02 * i, 0))))
			var tail := CylinderMesh.new()
			tail.top_radius = 0.025
			tail.bottom_radius = 0.025
			tail.height = 0.5
			n.add_child(_mesh(tail, gold, Transform3D(Basis(Vector3.FORWARD, 1.2), Vector3(0.45, -0.2, 0.1))))
			lift = Vector3(0, 0.36, 0)
		"calcite":
			# chalky pearls
			var chalk := _mat(Color(0.93, 0.92, 0.86), 0.55)
			for p: Vector3 in [Vector3(0, 0, 0), Vector3(0.28, 0.02, 0.1), Vector3(-0.18, 0.0, 0.22), Vector3(0.05, 0.22, 0.08)]:
				var pearl := SphereMesh.new()
				pearl.radius = 0.17
				pearl.height = 0.34
				n.add_child(_mesh(pearl, chalk, Transform3D(Basis.IDENTITY, p)))
			lift = Vector3(0, 0.17, 0)
		_:
			return null
	for c: Node in n.get_children():
		(c as Node3D).position += lift
	return n
