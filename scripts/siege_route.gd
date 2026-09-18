extends RefCounted

const TerrainSurface = preload("res://scripts/terrain_surface.gd")

# One continuous tower-defense route over the existing Bratislava DEM.
# The road, debug centreline and EnemyPath3D all use the same dense sample set.

const ROAD_WIDTH := 22.0
const ROAD_OFFSET := 0.14
const SAMPLE_SPACING := 5.0
const BRIDGE_X := 2262.0
const BRIDGE_NORTH_Z := 5005.0
const BRIDGE_SOUTH_Z := 5350.0
const BRIDGE_DECK_Y := 41.95


static func build(parent: Node3D, terrain_root: Node3D, create_visuals: bool = true) -> Node3D:
	var sampler := TerrainSurface.new(terrain_root)

	var root := Node3D.new()
	root.name = "Bratislava_Continuous_Siege_Route"
	parent.add_child(root)
	root.top_level = true
	root.global_transform = Transform3D.IDENTITY

	# Bridge -> right turn toward Staré Mesto -> lower Castle Hill ->
	# rear side -> broad readable switchbacks -> castle gate.
	#
	# IMPORTANT: these are explicit world-space waypoints. We intentionally do
	# NOT use Bézier auto-handles here because the previous curve overshot and
	# created loops / disconnected-looking road pieces.
	var controls: Array[Vector2] = [
		Vector2(2262.0, 5480.0),
		Vector2(2262.0, 5350.0),
		Vector2(2262.0, 5005.0),

		# Smooth right turn from the bridge toward the Old Town side.
		Vector2(2340.0, 4998.0),
		Vector2(2440.0, 4980.0),
		Vector2(2550.0, 4945.0),
		Vector2(2660.0, 4890.0),
		Vector2(2760.0, 4815.0),
		Vector2(2840.0, 4725.0),
		Vector2(2890.0, 4635.0),
		Vector2(2870.0, 4555.0),

		# First broad traverse behind / beside the castle.
		Vector2(2800.0, 4495.0),
		Vector2(2680.0, 4460.0),
		Vector2(2530.0, 4455.0),
		Vector2(2400.0, 4485.0),
		Vector2(2320.0, 4545.0),

		# Hairpin 1.
		Vector2(2300.0, 4605.0),
		Vector2(2350.0, 4655.0),
		Vector2(2470.0, 4680.0),
		Vector2(2600.0, 4670.0),
		Vector2(2710.0, 4635.0),

		# Hairpin 2.
		Vector2(2770.0, 4665.0),
		Vector2(2750.0, 4715.0),
		Vector2(2650.0, 4745.0),
		Vector2(2500.0, 4750.0),
		Vector2(2380.0, 4740.0),

		# Final approach to the future gate.
		Vector2(2310.0, 4760.0),
		Vector2(2260.0, 4790.0)
	]
	var road_points := _sample_polyline_on_surface(controls, sampler, SAMPLE_SPACING)
	var path := _make_navigation_path(road_points)
	root.add_child(path)

	if create_visuals:
		var road_material := _material(Color("#6a4728"), 1.0)
		var debug_material := _material(Color("#ff3b30"), 0.72, Color("#ff3b30"))
		var arrow_material := _material(Color("#ffcf3e"), 0.82, Color("#8a5a00"))
		var marker_material := _material(Color("#f1efe7"), 0.9, Color("#333333"))
		root.add_child(_build_terrain_ribbon("RoadSurface", road_points, ROAD_WIDTH, ROAD_OFFSET, sampler, road_material))
		var debug_points: Array[Vector3] = []
		for point in road_points:
			debug_points.append(point + Vector3.UP * 0.28)
		root.add_child(_build_terrain_ribbon("DebugCenterLine", debug_points, 2.4, ROAD_OFFSET + 0.32, sampler, debug_material))
		root.add_child(_build_direction_arrows(road_points, sampler, arrow_material))
		_add_endpoint_marker(root, "SpawnDebugMarker", road_points[0], "SPAWN", sampler, marker_material, Color("#ffb233"))

	var spawn := Marker3D.new()
	spawn.name = "EnemySpawn_SouthBank"
	spawn.position = road_points[0]
	root.add_child(spawn)
	var goal := Marker3D.new()
	goal.name = "EnemyGoal_BratislavaCastle"
	goal.position = road_points[-1]
	root.add_child(goal)

	_add_tower_slots(root, controls, road_points, sampler, null, false)

	root.set_meta("road_sample_count", road_points.size())
	root.set_meta("road_length", path.curve.get_baked_length())
	root.set_meta("tower_slot_count", 10)
	root.set_meta("single_road_mesh", true)
	root.set_meta("road_mesh_count", 1)
	root.set_meta("road_vertex_count", (road_points.size() - 1) * 6)
	root.set_meta("max_sample_gap", _max_gap(road_points))
	return root


static func _sample_polyline_on_surface(controls: Array[Vector2], sampler: TerrainSurface, spacing: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if controls.is_empty():
		return points

	points.append(_surface_point(controls[0], sampler, ROAD_OFFSET))
	for i in range(controls.size() - 1):
		var a := controls[i]
		var b := controls[i + 1]
		var segment_length := a.distance_to(b)
		var steps := maxi(1, ceili(segment_length / spacing))
		for step_index in range(1, steps + 1):
			var t := float(step_index) / float(steps)
			var xz := a.lerp(b, t)
			points.append(_surface_point(xz, sampler, ROAD_OFFSET))
	return points


static func _surface_point(xz: Vector2, sampler: TerrainSurface, offset: float) -> Vector3:
	return Vector3(xz.x, _route_surface_height(xz.x, xz.y, sampler) + offset, xz.y)


static func _route_surface_height(x: float, z: float, sampler: TerrainSurface) -> float:
	var terrain_y := sampler.height_world_at(x, z)
	if absf(x - BRIDGE_X) > 12.0:
		return terrain_y
	if z >= BRIDGE_NORTH_Z and z <= BRIDGE_SOUTH_Z:
		var north_blend := smoothstep(BRIDGE_NORTH_Z, BRIDGE_NORTH_Z + 28.0, z)
		var south_blend := 1.0 - smoothstep(BRIDGE_SOUTH_Z - 55.0, BRIDGE_SOUTH_Z, z)
		var deck_weight := minf(north_blend, south_blend)
		return lerpf(terrain_y, BRIDGE_DECK_Y, deck_weight)
	return terrain_y


static func _make_navigation_path(points: Array[Vector3]) -> Path3D:
	var path := Path3D.new()
	path.name = "EnemyPath3D"
	path.curve = Curve3D.new()
	path.curve.bake_interval = SAMPLE_SPACING
	for point in points:
		path.curve.add_point(point)
	return path


static func _build_terrain_ribbon(object_name: String, centers: Array[Vector3], width: float, offset: float, sampler: TerrainSurface, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in centers.size():
		var side := _side_at(centers, i) * width * 0.5
		var left_xz := Vector2(centers[i].x + side.x, centers[i].z + side.z)
		var right_xz := Vector2(centers[i].x - side.x, centers[i].z - side.z)
		left.append(_surface_point(left_xz, sampler, offset))
		right.append(_surface_point(right_xz, sampler, offset))
	for i in centers.size() - 1:
		_add_triangle(surface, left[i], right[i + 1], right[i])
		_add_triangle(surface, left[i], left[i + 1], right[i + 1])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = surface.commit()
	return instance


static func _build_direction_arrows(points: Array[Vector3], sampler: TerrainSurface, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for arrow_number in range(1, 12):
		var index := clampi(roundi(float(arrow_number) * float(points.size() - 1) / 12.0), 1, points.size() - 2)
		var forward := points[index + 1] - points[index - 1]
		forward.y = 0.0
		forward = forward.normalized()
		var side := Vector3(-forward.z, 0.0, forward.x)
		var center := points[index]
		var tip_xz := Vector2(center.x + forward.x * 7.0, center.z + forward.z * 7.0)
		var left_xz := Vector2(center.x - forward.x * 4.0 + side.x * 3.4, center.z - forward.z * 4.0 + side.z * 3.4)
		var right_xz := Vector2(center.x - forward.x * 4.0 - side.x * 3.4, center.z - forward.z * 4.0 - side.z * 3.4)
		_add_triangle(surface, _surface_point(tip_xz, sampler, ROAD_OFFSET + 0.38), _surface_point(right_xz, sampler, ROAD_OFFSET + 0.38), _surface_point(left_xz, sampler, ROAD_OFFSET + 0.38))
	surface.generate_normals()
	var arrows := MeshInstance3D.new()
	arrows.name = "DebugDirectionArrows"
	arrows.mesh = surface.commit()
	return arrows


static func _add_tower_slots(parent: Node3D, controls: Array[Vector2], points: Array[Vector3], sampler: TerrainSurface, material: Material, create_visuals: bool) -> void:
	var control_indices := [3, 4, 6, 7, 8, 9, 9, 10, 11, 11]
	var sides := [-1.0, 1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0]
	for slot_number in control_indices.size():
		var index := _nearest_point_index(points, controls[control_indices[slot_number]])
		if slot_number == 6 or slot_number == 9:
			index = clampi(index + 10, 1, points.size() - 2)
		var side: Vector3 = _side_at(points, index) * 23.0 * float(sides[slot_number])
		var xz := Vector2(points[index].x + side.x, points[index].z + side.z)
		var marker := Marker3D.new()
		marker.name = "TowerSlot_%02d" % (slot_number + 1)
		marker.position = _surface_point(xz, sampler, ROAD_OFFSET)
		parent.add_child(marker)
		if create_visuals:
			parent.add_child(_build_square_slot("TowerSlotSurface_%02d" % (slot_number + 1), xz, sampler, material))


static func _build_square_slot(object_name: String, center: Vector2, sampler: TerrainSurface, material: Material) -> MeshInstance3D:
	var half_size := 6.0
	var corners := [
		Vector2(center.x - half_size, center.y - half_size),
		Vector2(center.x + half_size, center.y - half_size),
		Vector2(center.x + half_size, center.y + half_size),
		Vector2(center.x - half_size, center.y + half_size)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var a := _surface_point(corners[0], sampler, ROAD_OFFSET + 0.08)
	var b := _surface_point(corners[1], sampler, ROAD_OFFSET + 0.08)
	var c := _surface_point(corners[2], sampler, ROAD_OFFSET + 0.08)
	var d := _surface_point(corners[3], sampler, ROAD_OFFSET + 0.08)
	_add_triangle(surface, a, c, b)
	_add_triangle(surface, a, d, c)
	surface.generate_normals()
	var slot := MeshInstance3D.new()
	slot.name = object_name
	slot.mesh = surface.commit()
	return slot


static func _add_endpoint_marker(parent: Node3D, object_name: String, point: Vector3, text: String, sampler: TerrainSurface, material: Material, text_color: Color) -> void:
	var xz := Vector2(point.x, point.z)
	var marker := _build_square_slot(object_name, xz, sampler, material)
	parent.add_child(marker)
	var label := Label3D.new()
	label.name = object_name + "Label"
	label.text = text
	label.position = point + Vector3.UP * 5.0
	label.fixed_size = true
	label.font_size = 13
	label.outline_size = 4
	label.modulate = text_color
	label.no_depth_test = true
	parent.add_child(label)


static func _nearest_point_index(points: Array[Vector3], target: Vector2) -> int:
	var best_index := 0
	var best_distance := INF
	for i in points.size():
		var distance := Vector2(points[i].x, points[i].z).distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


static func _side_at(points: Array[Vector3], index: int) -> Vector3:
	var previous := points[maxi(index - 1, 0)]
	var next := points[mini(index + 1, points.size() - 1)]
	var forward := next - previous
	forward.y = 0.0
	forward = forward.normalized()
	return Vector3(-forward.z, 0.0, forward.x)


static func _max_gap(points: Array[Vector3]) -> float:
	var result := 0.0
	for i in points.size() - 1:
		var current := Vector2(points[i].x, points[i].z)
		var next := Vector2(points[i + 1].x, points[i + 1].z)
		result = maxf(result, current.distance_to(next))
	return result


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


static func _material(color: Color, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.55
	return material
