extends SceneTree

const SiegeRoute = preload("res://scripts/siege_route.gd")


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var packed := load("res://Bratislava_Real_Terrain_Godot4.glb") as PackedScene
	if packed == null:
		_fail("Terrain GLB could not be loaded")
		return

	var scene := Node3D.new()
	root.add_child(scene)
	var terrain_root := packed.instantiate() as Node3D
	terrain_root.name = "BratislavaRealTerrain"
	terrain_root.scale = Vector3(1.0, 1.6, 1.0)
	scene.add_child(terrain_root)

	var route := SiegeRoute.build(scene, terrain_root, false)
	var path := route.get_node_or_null("EnemyPath3D") as Path3D
	if path == null:
		_fail("Hidden enemy Path3D is missing")
		return
	if path.curve.point_count < 100:
		_fail("Hidden route sampling is too sparse")
		return

	var points := path.curve.get_baked_points()
	if points.size() < 100:
		_fail("Baked hidden route is too sparse")
		return

	var max_gap := 0.0
	for i in range(points.size() - 1):
		max_gap = maxf(max_gap, points[i].distance_to(points[i + 1]))

	if max_gap > 8.0:
		_fail("A gap exists in the hidden route samples")
		return
	if path.curve.get_baked_length() < 650.0:
		_fail("Hidden bridge-to-castle route is unexpectedly short")
		return
	if route.get_meta("source", "") != "hidden gameplay route":
		_fail("Route source metadata is incorrect")
		return
	if not route.find_children("*", "MeshInstance3D", true, false).is_empty():
		_fail("Hidden gameplay route must not generate a visible road mesh")
		return

	print(
		"SIEGE_ROUTE_VALIDATION_OK source=hidden samples=",
		path.curve.point_count,
		" length=",
		snappedf(path.curve.get_baked_length(), 0.1),
		" max_gap=",
		snappedf(max_gap, 0.01),
		" visible_road_meshes=0"
	)
	scene.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("SIEGE_ROUTE_VALIDATION_FAILED: ", message)
	quit(1)
