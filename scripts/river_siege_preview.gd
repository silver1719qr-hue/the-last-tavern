extends RefCounted

const ASSET_ROOT := "res://assets/kenney/pirate/"
const SHIP_PATH := ASSET_ROOT + "ship-pirate-large.glb"
const CANNON_PATH := ASSET_ROOT + "cannon.glb"
const WALL_PATH := ASSET_ROOT + "castle-wall.glb"
const TOWER_PATH := ASSET_ROOT + "tower-watch.glb"

const WATER_Y := 43.0
const SHIP_SCALE := 4.8
const DEFENSE_SCALE := 5.0

static var river_points := PackedVector3Array([
	Vector3(-6550.0, WATER_Y, 1150.0),
	Vector3(-5350.0, WATER_Y, 2050.0),
	Vector3(-3650.0, WATER_Y, 3300.0),
	Vector3(-1700.0, WATER_Y, 4450.0),
	Vector3(250.0, WATER_Y, 5150.0),
	Vector3(1700.0, WATER_Y, 5270.0),
	Vector3(2700.0, WATER_Y, 5350.0)
])

static func build(parent: Node3D, terrain_root: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "RiverSiegePrototype"
	parent.add_child(root)

	_add_route_markers(root)
	_add_ship_wave(root)
	_add_city_embankment(root)
	_add_petrzalka_defense(root)
	_add_dock(root)
	return root

static func _add_ship_wave(root: Node3D) -> void:
	var placements := [
		{"segment": 0, "t": 0.35, "scale": 1.00},
		{"segment": 1, "t": 0.45, "scale": 0.88},
		{"segment": 2, "t": 0.62, "scale": 0.96},
		{"segment": 3, "t": 0.52, "scale": 0.82},
		{"segment": 4, "t": 0.58, "scale": 0.92},
	]
	for i in placements.size():
		var p: Dictionary = placements[i]
		var a := river_points[int(p["segment"])]
		var b := river_points[int(p["segment"]) + 1]
		var pos := a.lerp(b, float(p["t"]))
		var direction := (b - a).normalized()
		var ship := _instantiate_or_fallback(SHIP_PATH, _make_fallback_ship())
		ship.name = "InvaderShip_%02d" % (i + 1)
		root.add_child(ship)
		ship.global_position = pos
		ship.scale = Vector3.ONE * SHIP_SCALE * float(p["scale"])
		ship.rotation.y = atan2(direction.x, direction.z)

static func _add_city_embankment(root: Node3D) -> void:
	var start := Vector3(900.0, 47.0, 5050.0)
	var end := Vector3(3200.0, 47.0, 5480.0)
	var segments := 12
	for i in range(segments):
		var t := (float(i) + 0.5) / float(segments)
		var pos := start.lerp(end, t)
		var direction := (end - start).normalized()
		var wall := _instantiate_or_fallback(WALL_PATH, _make_fallback_wall())
		wall.name = "StoneQuay_%02d" % (i + 1)
		root.add_child(wall)
		wall.global_position = pos
		wall.scale = Vector3.ONE * DEFENSE_SCALE
		wall.rotation.y = atan2(direction.x, direction.z)

	for t in [0.08, 0.30, 0.52, 0.74, 0.94]:
		var pos := start.lerp(end, float(t))
		var tower := _instantiate_or_fallback(TOWER_PATH, _make_fallback_tower())
		tower.name = "CityRiverTower"
		root.add_child(tower)
		tower.global_position = pos + Vector3(0.0, 5.0, -38.0)
		tower.scale = Vector3.ONE * DEFENSE_SCALE

	for t in [0.16, 0.40, 0.64, 0.86]:
		var pos := start.lerp(end, float(t))
		var cannon := _instantiate_or_fallback(CANNON_PATH, _make_fallback_cannon())
		cannon.name = "RiverCannon"
		root.add_child(cannon)
		cannon.global_position = pos + Vector3(0.0, 10.0, -18.0)
		cannon.scale = Vector3.ONE * 5.5
		cannon.rotation.y = deg_to_rad(165.0)

static func _add_petrzalka_defense(root: Node3D) -> void:
	var points := [
		Vector3(1150.0, 48.0, 5750.0),
		Vector3(1600.0, 48.0, 5900.0),
		Vector3(2050.0, 48.0, 5980.0),
		Vector3(2500.0, 48.0, 6030.0),
		Vector3(2950.0, 48.0, 6050.0),
	]
	for i in points.size():
		var post := _make_wooden_fire_post()
		post.name = "PetrzalkaFirePost_%02d" % (i + 1)
		root.add_child(post)
		post.global_position = points[i]

static func _add_dock(root: Node3D) -> void:
	var dock := Node3D.new()
	dock.name = "BratislavaLandingDock"
	root.add_child(dock)
	dock.global_position = Vector3(2740.0, 46.0, 5420.0)

	var wood := _material(Color("#6c4328"), 0.95)
	for i in range(7):
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(10.0, 1.3, 42.0)
		mesh.material = wood
		plank.mesh = mesh
		plank.position = Vector3(float(i) * 10.5 - 31.5, 0.0, 0.0)
		dock.add_child(plank)

	var label := Label3D.new()
	label.text = "LANDING / ENEMY DISEMBARK"
	label.position = Vector3(0.0, 18.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.font_size = 12
	label.outline_size = 4
	label.modulate = Color("#ffd39b")
	label.outline_modulate = Color("#28130a")
	dock.add_child(label)

static func _add_route_markers(root: Node3D) -> void:
	for i in range(river_points.size() - 1):
		var a := river_points[i]
		var b := river_points[i + 1]
		var steps := 7
		for s in range(steps):
			var marker := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 3.0
			sphere.height = 6.0
			sphere.material = _material(Color(0.9, 0.2, 0.12, 0.42), 0.8, true)
			marker.mesh = sphere
			marker.global_position = a.lerp(b, float(s) / float(steps))
			root.add_child(marker)

static func _instantiate_or_fallback(path: String, fallback: Node3D) -> Node3D:
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			fallback.queue_free()
			return packed.instantiate() as Node3D
	return fallback

static func _make_fallback_ship() -> Node3D:
	var root := Node3D.new()
	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(6.0, 2.0, 17.0)
	hull_mesh.material = _material(Color("#4b2517"), 0.88)
	hull.mesh = hull_mesh
	hull.position.y = 1.0
	root.add_child(hull)

	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.18
	mast_mesh.bottom_radius = 0.22
	mast_mesh.height = 10.0
	mast_mesh.material = _material(Color("#3d2417"), 0.9)
	mast.mesh = mast_mesh
	mast.position = Vector3(0.0, 6.0, 0.0)
	root.add_child(mast)

	var sail := MeshInstance3D.new()
	var sail_mesh := QuadMesh.new()
	sail_mesh.size = Vector2(7.0, 6.0)
	sail_mesh.material = _material(Color("#c9b08a"), 0.85)
	sail.mesh = sail_mesh
	sail.position = Vector3(0.0, 7.0, 0.2)
	sail.rotation_degrees.y = 90.0
	root.add_child(sail)
	return root

static func _make_fallback_wall() -> Node3D:
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(7.0, 5.0, 2.0)
	mesh.material = _material(Color("#78736a"), 0.96)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 2.5
	root.add_child(mesh_instance)
	return root

static func _make_fallback_tower() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.8
	mesh.bottom_radius = 3.2
	mesh.height = 8.0
	mesh.radial_segments = 10
	mesh.material = _material(Color("#777168"), 0.96)
	body.mesh = mesh
	body.position.y = 4.0
	root.add_child(body)
	return root

static func _make_fallback_cannon() -> Node3D:
	var root := Node3D.new()
	var barrel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.52
	mesh.height = 4.5
	mesh.radial_segments = 12
	mesh.material = _material(Color("#25272b"), 0.55, false, 0.45)
	barrel.mesh = mesh
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 1.4, 0.0)
	root.add_child(barrel)
	return root

static func _make_wooden_fire_post() -> Node3D:
	var root := Node3D.new()
	var wood := _material(Color("#5c351e"), 0.95)
	for x in [-3.5, 3.5]:
		for z in [-3.5, 3.5]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.7, 8.0, 0.7)
			leg_mesh.material = wood
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 4.0, z)
			root.add_child(leg)

	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(9.0, 0.8, 9.0)
	deck_mesh.material = wood
	deck.mesh = deck_mesh
	deck.position.y = 8.0
	root.add_child(deck)

	var brazier := MeshInstance3D.new()
	var brazier_mesh := CylinderMesh.new()
	brazier_mesh.top_radius = 1.4
	brazier_mesh.bottom_radius = 1.0
	brazier_mesh.height = 1.0
	brazier_mesh.radial_segments = 8
	brazier_mesh.material = _material(Color("#2c2c2b"), 0.7, false, 0.25)
	brazier.mesh = brazier_mesh
	brazier.position = Vector3(0.0, 9.0, 0.0)
	root.add_child(brazier)

	var flame := OmniLight3D.new()
	flame.light_color = Color("#ff7b2f")
	flame.light_energy = 3.0
	flame.omni_range = 24.0
	flame.position = Vector3(0.0, 10.0, 0.0)
	root.add_child(flame)
	return root

static func _material(color: Color, roughness: float, transparent: bool = false, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
