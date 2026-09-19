extends RefCounted

# Automatic terrain-aware siege road.
# The road is generated at runtime from the real Bratislava terrain:
# bridge-side start -> terrain-following switchbacks -> castle gate.

const TerrainSurface = preload("res://scripts/terrain_surface.gd")

const START_XZ := Vector2(2262.0, 5480.0)
const GOAL_XZ := Vector2(2440.0, 4720.0)

const ROAD_WIDTH := 12.0
const ROAD_OFFSET := 0.45
const SAMPLE_SPACING := 4.0
const MAX_TARGET_GRADE := 0.07
const SWITCHBACK_COUNT := 6
const MIN_LATERAL_SWING := 90.0
const MAX_LATERAL_SWING := 260.0


static func build(parent: Node3D, terrain_root: Node3D, create_visuals: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Bratislava_Auto_Terrain_Road"
	parent.add_child(root)
	root.top_level = true
	root.global_transform = Transform3D.IDENTITY

	var sampler := TerrainSurface.new(terrain_root)
	var path_points := _generate_route(sampler)

	var path := Path3D.new()
	path.name = "EnemyPath3D"
	path.curve = Curve3D.new()
	path.curve.bake_interval = SAMPLE_SPACING
	for point in path_points:
		path.curve.add_point(point)
	root.add_child(path)

	if create_visuals:
		var road_mesh := MeshInstance3D.new()
		road_mesh.name = "Medieval_Cobblestone_Road"
		road_mesh.mesh = _build_road_mesh(path_points, sampler)
		road_mesh.material_override = _road_material()
		road_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(road_mesh)

	var spawn := Marker3D.new()
	spawn.name = "EnemySpawn_BridgeSide"
	spawn.position = path_points[0]
	root.add_child(spawn)

	var goal := Marker3D.new()
	goal.name = "EnemyGoal_BratislavaCastleMainGate"
	goal.position = path_points[-1]
	root.add_child(goal)

	root.set_meta("source", "automatic terrain-aware route generator")
	root.set_meta("road_sample_count", path_points.size())
	root.set_meta("road_length", path.curve.get_baked_length())
	root.set_meta("road_width_m", ROAD_WIDTH)
	root.set_meta("target_max_grade", MAX_TARGET_GRADE)
	root.set_meta("switchbacks", SWITCHBACK_COUNT)
	return root


static func _generate_route(sampler) -> Array[Vector3]:
	var start := sampler.point_world_at(START_XZ.x, START_XZ.y, ROAD_OFFSET)
	var goal := sampler.point_world_at(GOAL_XZ.x, GOAL_XZ.y, ROAD_OFFSET)

	var start_2d := Vector2(start.x, start.z)
	var goal_2d := Vector2(goal.x, goal.z)
	var delta := goal_2d - start_2d
	var direct_length := maxf(delta.length(), 1.0)
	var forward := delta.normalized()
	var lateral := Vector2(-forward.y, forward.x)

	# Length needed to keep the average climb comfortable.
	var rise := absf(goal.y - start.y)
	var target_length := maxf(direct_length, rise / MAX_TARGET_GRADE)
	var forward_step := direct_length / float(SWITCHBACK_COUNT)
	var target_segment := target_length / float(SWITCHBACK_COUNT)
	var lateral_swing := MIN_LATERAL_SWING
	if target_segment > forward_step:
		lateral_swing = 0.5 * sqrt(maxf(target_segment * target_segment - forward_step * forward_step, 0.0))
	lateral_swing = clampf(lateral_swing, MIN_LATERAL_SWING, MAX_LATERAL_SWING)

	var anchors: Array[Vector2] = []
	anchors.append(start_2d)
	for i in range(1, SWITCHBACK_COUNT):
		var t := float(i) / float(SWITCHBACK_COUNT)
		var taper := sin(PI * t)
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := start_2d.lerp(goal_2d, t) + lateral * lateral_swing * taper * side
		anchors.append(p)
	anchors.append(goal_2d)

	# Chaikin smoothing turns the zig-zag into broad cart-friendly bends.
	var smooth := anchors
	for _pass in range(3):
		var next: Array[Vector2] = []
		next.append(smooth[0])
		for i in range(smooth.size() - 1):
			var a := smooth[i]
			var b := smooth[i + 1]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		next.append(smooth[-1])
		smooth = next

	var points: Array[Vector3] = []
	for i in range(smooth.size() - 1):
		var a := smooth[i]
		var b := smooth[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(1, ceili(length / SAMPLE_SPACING))
		for s in range(steps):
			var t := float(s) / float(steps)
			var p := a.lerp(b, t)
			points.append(sampler.point_world_at(p.x, p.y, ROAD_OFFSET))
	points.append(goal)
	return _dedupe(points)


static func _dedupe(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in points:
		if result.is_empty() or result[-1].distance_to(point) > 0.25:
			result.append(point)
	return result


static func _build_road_mesh(points: Array[Vector3], sampler) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half_width := ROAD_WIDTH * 0.5
	var distance_along := 0.0

	for i in range(points.size()):
		var prev := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, points.size() - 1)]
		var tangent := Vector2(next.x - prev.x, next.z - prev.z).normalized()
		if tangent.length_squared() < 0.001:
			tangent = Vector2(0.0, -1.0)
		var right := Vector2(-tangent.y, tangent.x)

		if i > 0:
			distance_along += points[i - 1].distance_to(points[i])

		var left_xz := Vector2(points[i].x, points[i].z) - right * half_width
		var right_xz := Vector2(points[i].x, points[i].z) + right * half_width
		var left := sampler.point_world_at(left_xz.x, left_xz.y, ROAD_OFFSET)
		var right_point := sampler.point_world_at(right_xz.x, right_xz.y, ROAD_OFFSET)

		vertices.append(left)
		vertices.append(right_point)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, distance_along / 5.0))
		uvs.append(Vector2(1.0, distance_along / 5.0))

	for i in range(points.size() - 1):
		var base := i * 2
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _road_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#716b5d")
	material.roughness = 0.96
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
