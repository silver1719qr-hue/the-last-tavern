extends SceneTree

const TerrainSurface = preload("res://scripts/terrain_surface.gd")
const SiegeRoute = preload("res://scripts/siege_route.gd")
const CastleAnchorDebug = preload("res://scripts/castle_anchor_debug.gd")


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
	var anchors_root := CastleAnchorDebug.build(scene, terrain_root, route, false)
	var sampler := TerrainSurface.new(terrain_root)
	var anchors := anchors_root.find_children("CastleAnchor_*", "Marker3D", true, false)
	if anchors.size() != 10:
		_fail("Expected exactly 10 ordered castle anchors")
		return

	var max_clearance_error := 0.0
	for anchor_node in anchors:
		var anchor := anchor_node as Marker3D
		var terrain_y := sampler.height_world_at(anchor.global_position.x, anchor.global_position.z)
		var clearance := anchor.global_position.y - terrain_y
		max_clearance_error = maxf(max_clearance_error, absf(clearance - CastleAnchorDebug.MARKER_OFFSET))
	if max_clearance_error > 0.002:
		_fail("At least one castle anchor is not fitted to the terrain surface")
		return

	var path := route.get_node("EnemyPath3D") as Path3D
	var road_end := path.curve.get_point_position(path.curve.point_count - 1)
	var gate := anchors_root.get_node("FutureGateCenter_OnRoad") as Marker3D
	var road_gate_error := Vector2(road_end.x, road_end.z).distance_to(Vector2(gate.global_position.x, gate.global_position.z))
	if road_gate_error > 0.002:
		_fail("Gate marker is not centred on the road spline")
		return
	var gate_clearance_error := absf(gate.global_position.y - sampler.height_world_at(gate.global_position.x, gate.global_position.z) - CastleAnchorDebug.MARKER_OFFSET)
	if gate_clearance_error > 0.002:
		_fail("Gate marker is not fitted to the terrain surface")
		return

	var left := anchors_root.get_meta("gate_left_position") as Vector3
	var right := anchors_root.get_meta("gate_right_position") as Vector3
	var gate_width := Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))
	var gate_midpoint := (Vector2(left.x, left.z) + Vector2(right.x, right.z)) * 0.5
	if absf(gate_width - CastleAnchorDebug.FUTURE_GATE_WIDTH) > 0.01 or gate_midpoint.distance_to(Vector2(gate.global_position.x, gate.global_position.z)) > 0.002:
		_fail("Gate edge anchors do not meet the road-centred gate opening")
		return

	var castle_source := FileAccess.get_file_as_string("res://scripts/castle_models.gd")
	for forbidden_name in ["CastleFortification", "SigismundGate", "ViennaGate", "LeopoldGate", "GardenRetaining", "GardenWall"]:
		if forbidden_name in castle_source:
			_fail("Old hardcoded fortification geometry still exists: " + forbidden_name)
			return

	print("CASTLE_ANCHOR_VALIDATION_OK anchors=", anchors.size(), " terrain_scale_y=", terrain_root.global_transform.basis.y.length(), " max_clearance_error=", snappedf(max_clearance_error, 0.0001), " gate_clearance_error=", snappedf(gate_clearance_error, 0.0001), " gate_road_error=", snappedf(road_gate_error, 0.0001), " gate_width=", snappedf(gate_width, 0.01))
	scene.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("CASTLE_ANCHOR_VALIDATION_FAILED: ", message)
	quit(1)
