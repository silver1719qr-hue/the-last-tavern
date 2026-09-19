extends SceneTree

const ROAD_SCENE := "res://assets/world/bratislava_castle_road.glb"
const ROAD_REPORT := "res://assets/world/bratislava_castle_road_validation.json"
const ROAD_PATH := "res://assets/world/bratislava_castle_road_path.json"


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var packed := load(ROAD_SCENE) as PackedScene
	if packed == null:
		_fail("Blender road GLB could not be loaded")
		return
	var road_root := packed.instantiate() as Node3D
	root.add_child(road_root)
	var road_mesh := road_root.find_child("Bratislava_Castle_Road", true, false) as MeshInstance3D
	if road_mesh == null or road_mesh.mesh == null:
		_fail("Bratislava_Castle_Road mesh is missing from Blender GLB")
		return
	var bounds := road_mesh.global_transform * road_mesh.get_aabb()
	if bounds.size.x < 550.0 or bounds.size.z < 850.0 or bounds.size.y < 80.0:
		_fail("Road GLB bounds show a flattened or incorrectly oriented mesh: " + str(bounds))
		return
	if bounds.position.x < 2050.0 or bounds.end.x > 2900.0 or bounds.position.z < 4500.0 or bounds.end.z > 5550.0:
		_fail("Road GLB is not in the expected Bratislava world coordinates: " + str(bounds))
		return
	if road_mesh.mesh.get_surface_count() != 2:
		_fail("Road GLB must contain road and shoulder material surfaces")
		return
	var vertex_count := 0
	for surface_index in road_mesh.mesh.get_surface_count():
		var arrays := road_mesh.mesh.surface_get_arrays(surface_index)
		vertex_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if vertex_count < 5000:
		_fail("Road mesh is unexpectedly sparse")
		return

	var report = JSON.parse_string(FileAccess.get_file_as_string(ROAD_REPORT))
	if not report is Dictionary or report.get("status", "") != "ROAD_VALIDATION_OK":
		_fail("Blender road validation report is missing or invalid")
		return
	if float(report.get("sample_spacing_m", 999.0)) > 5.0:
		_fail("Blender road validation spacing exceeds 5 metres")
		return
	if int(report.get("self_intersection_count", 1)) != 0:
		_fail("Blender road centerline self-intersects")
		return
	if float(report.get("min_top_above_terrain_m", -1.0)) < 0.1:
		_fail("Blender road penetrates the terrain")
		return
	if float(report.get("max_support_clearance_error_m", 1.0)) > 0.001:
		_fail("Blender road clearance validation failed")
		return
	if float(report.get("max_vertical_step_m", 99.0)) > 1.0:
		_fail("Blender road contains an anomalous vertical jump")
		return
	if float(report.get("max_grade_percent", 99.0)) > 40.0:
		_fail("Blender road grade exceeds the accepted castle-hill limit")
		return

	var path_data = JSON.parse_string(FileAccess.get_file_as_string(ROAD_PATH))
	if not path_data is Dictionary or (path_data.get("points", []) as Array).size() != int(report.get("sample_count", 0)):
		_fail("Godot navigation path does not match the Blender validation samples")
		return
	print(
		"BLENDER_ROAD_VALIDATION_OK samples=", report["sample_count"],
		" spacing=", report["sample_spacing_m"],
		" width=", report["road_width_m"],
		" max_step=", snappedf(float(report["max_vertical_step_m"]), 0.001),
		" max_grade=", snappedf(float(report["max_grade_percent"]), 0.1),
		" intersections=0 vertices=", vertex_count,
		" bounds=", bounds
	)
	road_root.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("BLENDER_ROAD_VALIDATION_FAILED: ", message)
	quit(1)
