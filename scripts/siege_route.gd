extends RefCounted

# Automatic terrain-aware siege road.
# The road is generated at runtime from the real Bratislava terrain:
# bridge-side start -> terrain-following switchbacks -> castle gate.

const TerrainSurface = preload("res://scripts/terrain_surface.gd")

const START_XZ := Vector2(2262.0, 5004.0)
const GOAL_XZ := Vector2(2304.5, 4710.0)

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
	var start: Vector3 = sampler.point_world_at(START_XZ.x, START_XZ.y, ROAD_OFFSET)
	var goal: Vector3 = sampler.point_world_at(GOAL_XZ.x, GOAL_XZ.y, ROAD_OFFSET)

	var start_2d := Vector2(start.x, start.z)
	var goal_2d := Vector2(goal.x, goal.z)
	var delta := goal_2d - start_2d
	var direct_length := maxf(delta.length(), 1.0)
	var forward := delta.normalized()
	var lateral := Vector2(-forward.y, forward.x)

	# Build a true bridge-to-gate serpentine. The endpoints are exact; only the
	# middle of the road swings sideways. This prevents the old "hook" that
	# stopped beside the castle and failed to meet the bridge.
	var rise := absf(goal.y - start.y)
	var turns := clampi(roundi(rise / 28.0), 3, 5)
	var amplitude := clampf(rise * 1.35, 85.0, 170.0)
	var estimated_length := direct_length + float(turns) * amplitude * 3.5
	var samples := maxi(180, ceili(estimated_length / SAMPLE_SPACING))

	var points: Array[Vector3] = []
	for i in range(samples + 1):
		var t := float(i) / float(samples)
		var base := start_2d.lerp(goal_2d, t)
		var envelope := sin(PI * t)
		var phase := TAU * float(turns) * t
		var swing := sin(phase) * amplitude * envelope
		var p := base + lateral * swing
		points.append(sampler.point_world_at(p.x, p.y, ROAD_OFFSET))

	# Force exact contact with the wooden bridge and the castle east portal.
	points[0] = start
	points[-1] = goal
	return _dedupe(points)

