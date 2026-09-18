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
	var slots := route.find_children("TowerSlot_*", "Marker3D", true, false)
	if path == null:
		_fail("Continuous Path3D is missing")
		return
	if path.curve.point_count < 100:
		_fail("Route sampling is too sparse")
		return
	if not bool(route.get_meta("single_road_mesh", false)):
		_fail("Road is not marked as one continuous mesh")
		return
	if int(route.get_meta("road_mesh_count", 0)) != 1:
		_fail("Expected exactly one generated road mesh")
		return
	if float(route.get_meta("max_sample_gap", 999.0)) > 8.0:
		_fail("A gap exists in the route samples")
		return
	if slots.size() != 10:
		_fail("Expected exactly 10 tower slots")
		return
	if route.has_node("SouthBankApproach") or route.has_node("CastleHillRoad"):
		_fail("Old split-road nodes still exist")
		return
	print("SIEGE_ROUTE_VALIDATION_OK samples=", path.curve.point_count, " length=", snappedf(path.curve.get_baked_length(), 0.1), " max_gap=", snappedf(float(route.get_meta("max_sample_gap")), 0.01), " slots=", slots.size())
	scene.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("SIEGE_ROUTE_VALIDATION_FAILED: ", message)
	quit(1)
