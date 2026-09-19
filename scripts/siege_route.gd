extends RefCounted

# Hidden gameplay route only. No visual road is generated.
# Enemies start south of the Danube, cross the existing wooden bridge, then
# continue over the real terrain to Bratislava Castle.

const TerrainSurface = preload("res://scripts/terrain_surface.gd")

const ROAD_OFFSET := 1.15
const SAMPLE_SPACING := 4.0
const BRIDGE_X := 2262.0
const BRIDGE_SOUTH_Z := 5480.0
const BRIDGE_NORTH_Z := 5004.0
const BRIDGE_DECK_Y := 43.0
const GOAL_XZ := Vector2(2304.5, 4710.0)


static func build(parent: Node3D, terrain_root: Node3D, _create_visuals: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Bratislava_Hidden_Enemy_Route"
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

	var spawn := Marker3D.new()
	spawn.name = "EnemySpawn_SouthBank"
	spawn.position = path_points[0]
	root.add_child(spawn)

	var goal := Marker3D.new()
	goal.name = "EnemyGoal_BratislavaCastleMainGate"
	goal.position = path_points[-1]
	root.add_child(goal)

	root.set_meta("source", "hidden gameplay route")
	root.set_meta("road_sample_count", path_points.size())
	root.set_meta("road_length", path.curve.get_baked_length())
	root.set_meta("visual_mesh_generated", false)
	return root


static func _generate_route(sampler) -> Array[Vector3]:
	var points: Array[Vector3] = []

	# Approach + full bridge crossing. Keep enemies at a fixed bridge-deck height
	# so they cannot sink into the river or terrain while crossing.
	var bridge_steps := maxi(2, ceili(absf(BRIDGE_SOUTH_Z - BRIDGE_NORTH_Z) / SAMPLE_SPACING))
	for i in range(bridge_steps + 1):
		var t := float(i) / float(bridge_steps)
		var z := lerpf(BRIDGE_SOUTH_Z, BRIDGE_NORTH_Z, t)
		points.append(Vector3(BRIDGE_X, BRIDGE_DECK_Y, z))

	# Short, broad approach from the bridge to the east-side castle gate.
	# It is invisible; these anchors are for movement only, not for drawing a road.
	var anchors := [
		Vector2(BRIDGE_X, BRIDGE_NORTH_Z),
		Vector2(2268.0, 4935.0),
		Vector2(2288.0, 4865.0),
		Vector2(2318.0, 4800.0),
		GOAL_XZ
	]
	for a in range(anchors.size() - 1):
		var from: Vector2 = anchors[a]
		var to: Vector2 = anchors[a + 1]
		var segment_len := from.distance_to(to)
		var steps := maxi(1, ceili(segment_len / SAMPLE_SPACING))
		for i in range(1, steps + 1):
			var t := float(i) / float(steps)
			var p := from.lerp(to, t)
			points.append(sampler.point_world_at(p.x, p.y, ROAD_OFFSET))

	return _dedupe(points)


static func _dedupe(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in points:
		if result.is_empty() or result[-1].distance_to(point) > 0.25:
			result.append(point)
	return result
