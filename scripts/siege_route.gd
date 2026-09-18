extends RefCounted

# One continuous tower-defense route over the existing Bratislava DEM.
# The road, debug centreline and EnemyPath3D all use the same dense sample set.

const ROAD_WIDTH := 10.0
const ROAD_OFFSET := 0.14
const SAMPLE_SPACING := 6.0
const GRID_SIZE := 129
const BRIDGE_X := 2262.0
const BRIDGE_NORTH_Z := 5005.0
const BRIDGE_SOUTH_Z := 5350.0
const BRIDGE_DECK_Y := 41.95


class TerrainHeightSampler:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var step_x := 1.0
	var step_z := 1.0
	var heights := PackedFloat32Array()


	func _init(terrain_mesh: MeshInstance3D, parent_space: Node3D) -> void:
		var relative_transform := parent_space.global_transform.affine_inverse() * terrain_mesh.global_transform
		var all_vertices: Array[PackedVector3Array] = []
		for surface_index in terrain_mesh.mesh.get_surface_count():
			var arrays := terrain_mesh.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			all_vertices.append(vertices)
			for vertex in vertices:
				var point := relative_transform * vertex
				min_x = minf(min_x, point.x)
				max_x = maxf(max_x, point.x)
				min_z = minf(min_z, point.z)
				max_z = maxf(max_z, point.z)

		step_x = (max_x - min_x) / float(GRID_SIZE - 1)
		step_z = (max_z - min_z) / float(GRID_SIZE - 1)
		heights.resize(GRID_SIZE * GRID_SIZE)
		heights.fill(-INF)
		for vertices in all_vertices:
			for vertex in vertices:
				var point := relative_transform * vertex
				var ix := clampi(roundi((point.x - min_x) / step_x), 0, GRID_SIZE - 1)
				var iz := clampi(roundi((point.z - min_z) / step_z), 0, GRID_SIZE - 1)
				var index := iz * GRID_SIZE + ix
				heights[index] = maxf(heights[index], point.y)


	func height_at(x: float, z: float) -> float:
		var fx := clampf((x - min_x) / step_x, 0.0, float(GRID_SIZE - 1))
		var fz := clampf((z - min_z) / step_z, 0.0, float(GRID_SIZE - 1))
		var x0 := clampi(floori(fx), 0, GRID_SIZE - 2)
		var z0 := clampi(floori(fz), 0, GRID_SIZE - 2)
		var tx := fx - float(x0)
		var tz := fz - float(z0)
		var h00 := heights[z0 * GRID_SIZE + x0]
		var h10 := heights[z0 * GRID_SIZE + x0 + 1]
		var h01 := heights[(z0 + 1) * GRID_SIZE + x0]
		var h11 := heights[(z0 + 1) * GRID_SIZE + x0 + 1]
		return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


static func build(parent: Node3D, terrain_root: Node3D, create_visuals: bool = true) -> Node3D:
	var terrain_collision := terrain_root.find_child("Terrain-col", true, false) as MeshInstance3D
	assert(terrain_collision != null, "Terrain-col is required for the siege route")
	var sampler := TerrainHeightSampler.new(terrain_collision, parent)

	var root := Node3D.new()
	root.name = "Bratislava_Continuous_Siege_Route"
	parent.add_child(root)

	# Bridge -> right turn -> lower Castle Hill -> rear side -> five broad
	# switchbacks -> defensive point beside Bratislava Castle.
	var controls: Array[Vector2] = [
		Vector2(2262.0, 5480.0),
		Vector2(2262.0, 5350.0),
		Vector2(2262.0, 5005.0),
		Vector2(2520.0, 4990.0),
		Vector2(2760.0, 4860.0),
		Vector2(2830.0, 4620.0),
		Vector2(2800.0, 4380.0),
		Vector2(2300.0, 4350.0),
		Vector2(2650.0, 4470.0),
		Vector2(2150.0, 4450.0),
		Vector2(2500.0, 4580.0),
		Vector2(2050.0, 4600.0),
		Vector2(2200.0, 4750.0)
	]
	var design_curve := _make_design_curve(controls, sampler)
	var road_points := _sample_on_surface(design_curve, sampler, SAMPLE_SPACING)
	var path := _make_navigation_path(road_points)
	root.add_child(path)

	var slot_material: Material = null
	if create_visuals:
		var road_material := _material(Color("#80613f"), 1.0)
		var debug_material := _material(Color("#e12626"), 0.72, Color("#7d0505"))
		var arrow_material := _material(Color("#ffcf3e"), 0.82, Color("#8a5a00"))
		slot_material = _material(Color("#4aa6c8"), 0.86, Color("#123d52"))
		var marker_material := _material(Color("#f1efe7"), 0.9, Color("#333333"))
		root.add_child(_build_terrain_ribbon("RoadSurface", road_points, ROAD_WIDTH, ROAD_OFFSET, sampler, road_material))
		var debug_points: Array[Vector3] = []
		for point in road_points:
			debug_points.append(point + Vector3.UP * 0.28)
		root.add_child(_build_terrain_ribbon("DebugCenterLine", debug_points, 0.75, ROAD_OFFSET + 0.28, sampler, debug_material))
		root.add_child(_build_direction_arrows(road_points, sampler, arrow_material))
		_add_endpoint_marker(root, "SpawnDebugMarker", road_points[0], "SPAWN", sampler, marker_material, Color("#ffb233"))
		_add_endpoint_marker(root, "GoalDebugMarker", road_points[-1], "CASTLE GOAL", sampler, marker_material, Color("#65e06c"))
		_add_key_labels(root, controls, road_points)

	var spawn := Marker3D.new()
	spawn.name = "EnemySpawn_SouthBank"
	spawn.position = road_points[0]
	root.add_child(spawn)
	var goal := Marker3D.new()
	goal.name = "EnemyGoal_BratislavaCastle"
	goal.position = road_points[-1]
	root.add_child(goal)

	_add_tower_slots(root, controls, road_points, sampler, slot_material, create_visuals)

	root.set_meta("road_sample_count", road_points.size())
	root.set_meta("road_length", path.curve.get_baked_length())
	root.set_meta("tower_slot_count", 10)
	root.set_meta("single_road_mesh", true)
	root.set_meta("road_mesh_count", 1)
	root.set_meta("road_vertex_count", (road_points.size() - 1) * 6)
	root.set_meta("max_sample_gap", _max_gap(road_points))
	return root


static func _make_design_curve(controls: Array[Vector2], sampler: TerrainHeightSampler) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 2.0
	for i in controls.size():
		var current := _surface_point(controls[i], sampler, ROAD_OFFSET)
		var previous := current if i == 0 else _surface_point(controls[i - 1], sampler, ROAD_OFFSET)
		var next := current if i == controls.size() - 1 else _surface_point(controls[i + 1], sampler, ROAD_OFFSET)
		var tangent := next - previous
		tangent.y = 0.0
		tangent = tangent.normalized()
		var incoming := 0.0 if i == 0 else minf(current.distance_to(previous) * 0.24, 78.0)
		var outgoing := 0.0 if i == controls.size() - 1 else minf(current.distance_to(next) * 0.24, 78.0)
		curve.add_point(current, -tangent * incoming, tangent * outgoing)
	return curve


static func _sample_on_surface(curve: Curve3D, sampler: TerrainHeightSampler, spacing: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var design_point := curve.sample_baked(distance, true)
		points.append(_surface_point(Vector2(design_point.x, design_point.z), sampler, ROAD_OFFSET))
		distance += spacing
	var end := curve.sample_baked(length, true)
	points.append(_surface_point(Vector2(end.x, end.z), sampler, ROAD_OFFSET))
	return points


static func _surface_point(xz: Vector2, sampler: TerrainHeightSampler, offset: float) -> Vector3:
	return Vector3(xz.x, _route_surface_height(xz.x, xz.y, sampler) + offset, xz.y)


static func _route_surface_height(x: float, z: float, sampler: TerrainHeightSampler) -> float:
	var terrain_y := sampler.height_at(x, z)
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


static func _build_terrain_ribbon(object_name: String, centers: Array[Vector3], width: float, offset: float, sampler: TerrainHeightSampler, material: Material) -> MeshInstance3D:
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


static func _build_direction_arrows(points: Array[Vector3], sampler: TerrainHeightSampler, material: Material) -> MeshInstance3D:
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


static func _add_tower_slots(parent: Node3D, controls: Array[Vector2], points: Array[Vector3], sampler: TerrainHeightSampler, material: Material, create_visuals: bool) -> void:
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


static func _build_square_slot(object_name: String, center: Vector2, sampler: TerrainHeightSampler, material: Material) -> MeshInstance3D:
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


static func _add_key_labels(parent: Node3D, controls: Array[Vector2], points: Array[Vector3]) -> void:
	var key_controls := [0, 1, 3, 6, 9, 12]
	for key_number in key_controls.size():
		var point_index := _nearest_point_index(points, controls[key_controls[key_number]])
		var label := Label3D.new()
		label.name = "RouteKey_%d" % (key_number + 1)
		label.text = str(key_number + 1)
		label.position = points[point_index] + Vector3.UP * 3.0
		label.fixed_size = true
		label.font_size = 14
		label.outline_size = 4
		label.modulate = Color.WHITE
		label.outline_modulate = Color("#7c1111")
		label.no_depth_test = true
		parent.add_child(label)


static func _add_endpoint_marker(parent: Node3D, object_name: String, point: Vector3, text: String, sampler: TerrainHeightSampler, material: Material, text_color: Color) -> void:
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
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.55
	return material
