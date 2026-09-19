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
		_fail("Blender-authored navigation Path3D is missing")
		return
	if path.curve.point_count < 100:
		_fail("Route sampling is too sparse")
		return
	if bool(route.get_meta("visual_mesh_generated_by_gdscript", true)):
		_fail("GDScript must not generate the visual road mesh")
		return
	if not route.find_children("*", "MeshInstance3D", true, false).is_empty():
		_fail("Runtime route contains forbidden procedural MeshInstance3D nodes")
		return
	if float(route.get_meta("max_sample_gap", 999.0)) > 5.0:
		_fail("A gap exists in the route samples")
		return
	var source := FileAccess.get_file_as_string("res://scripts/siege_route.gd")
	for forbidden_text in ["SurfaceTool", "RoadSurface", "_build_terrain_ribbon"]:
		if forbidden_text in source:
			_fail("Procedural visual road code still exists: " + forbidden_text)
			return
	if not str(route.get_meta("source", "")).begins_with("Blender"):
		_fail("Runtime path is not identified as Blender source data")
		return
	print("SIEGE_ROUTE_VALIDATION_OK source=Blender samples=", path.curve.point_count, " length=", snappedf(path.curve.get_baked_length(), 0.1), " max_gap=", snappedf(float(route.get_meta("max_sample_gap")), 0.01), " procedural_meshes=0")
	scene.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("SIEGE_ROUTE_VALIDATION_FAILED: ", message)
	quit(1)
