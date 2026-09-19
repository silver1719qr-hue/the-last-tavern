extends RefCounted

# Runtime navigation data for the Blender-authored road. This script creates no
# visual geometry: the visible road is assets/world/bratislava_castle_road.glb.

const PATH_DATA := "res://assets/world/bratislava_castle_road_path.json"


static func build(parent: Node3D, _terrain_root: Node3D, _create_visuals: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Bratislava_Blender_Road_Path"
	parent.add_child(root)
	root.top_level = true
	root.global_transform = Transform3D.IDENTITY

	var path_points := _load_blender_path()
	var path := Path3D.new()
	path.name = "EnemyPath3D"
	path.curve = Curve3D.new()
	path.curve.bake_interval = 2.5
	for point in path_points:
		path.curve.add_point(point)
	root.add_child(path)

	var spawn := Marker3D.new()
	spawn.name = "EnemySpawn_SouthBank"
	spawn.position = path_points[0]
	root.add_child(spawn)
	var goal := Marker3D.new()
	goal.name = "EnemyGoal_BratislavaCastleMainGate"
	goal.position = path_points[-1]
	root.add_child(goal)

	root.set_meta("source", "Blender 4.3 bpy / Terrain-col BVH")
	root.set_meta("path_data", PATH_DATA)
	root.set_meta("road_sample_count", path_points.size())
	root.set_meta("road_length", path.curve.get_baked_length())
	root.set_meta("max_sample_gap", _max_gap(path_points))
	root.set_meta("visual_mesh_generated_by_gdscript", false)
	return root


static func _load_blender_path() -> Array[Vector3]:
	var file := FileAccess.open(PATH_DATA, FileAccess.READ)
	assert(file != null, "Blender road path data is missing")
	var parsed = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary and parsed.has("points"), "Blender road path JSON is invalid")
	var points: Array[Vector3] = []
	for value in parsed["points"]:
		points.append(Vector3(float(value[0]), float(value[1]), float(value[2])))
	assert(points.size() >= 2, "Blender road path must contain at least two points")
	return points


static func _max_gap(points: Array[Vector3]) -> float:
	var result := 0.0
	for index in points.size() - 1:
		result = maxf(result, points[index].distance_to(points[index + 1]))
	return result
