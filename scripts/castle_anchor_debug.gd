extends RefCounted

const TerrainSurface = preload("res://scripts/terrain_surface.gd")

const MARKER_OFFSET := 0.18
const FUTURE_GATE_WIDTH := 18.0


static func build(parent: Node3D, terrain_root: Node3D, route_root: Node3D, create_visuals: bool = true) -> Node3D:
	var sampler := TerrainSurface.new(terrain_root)
	var path := route_root.get_node("EnemyPath3D") as Path3D
	assert(path != null and path.curve.point_count >= 2, "EnemyPath3D is required before placing castle anchors")

	var route_end := path.curve.get_point_position(path.curve.point_count - 1)
	var route_before_end := path.curve.get_point_position(path.curve.point_count - 2)
	var road_forward := Vector2(route_end.x - route_before_end.x, route_end.z - route_before_end.z).normalized()
	var gate_side := Vector2(-road_forward.y, road_forward.x)
	var gate_center_xz := Vector2(route_end.x, route_end.z)
	var gate_left_xz := gate_center_xz + gate_side * FUTURE_GATE_WIDTH * 0.5
	var gate_right_xz := gate_center_xz - gate_side * FUTURE_GATE_WIDTH * 0.5

	# Ordered clockwise in world X/Z. The first and last anchors are the future
	# gate edges; the gap between them is centred exactly on the road spline.
	var anchor_xz: Array[Vector2] = [
		gate_left_xz,
		Vector2(2130.0, 4810.0),
		Vector2(2115.0, 4700.0),
		Vector2(2140.0, 4570.0),
		Vector2(2250.0, 4540.0),
		Vector2(2380.0, 4570.0),
		Vector2(2400.0, 4680.0),
		Vector2(2370.0, 4810.0),
		Vector2(2260.0, 4850.0),
		gate_right_xz
	]

	var root := Node3D.new()
	root.name = "Bratislava_Castle_Anchor_Review"
	parent.add_child(root)
	root.top_level = true
	root.global_transform = Transform3D.IDENTITY

	var anchor_positions := PackedVector3Array()
	for i in anchor_xz.size():
		var world_position := sampler.point_world_at(anchor_xz[i].x, anchor_xz[i].y, MARKER_OFFSET)
		anchor_positions.append(world_position)
		var anchor := Marker3D.new()
		anchor.name = "CastleAnchor_%02d" % (i + 1)
		root.add_child(anchor)
		anchor.global_position = world_position
		anchor.set_meta("terrain_y", sampler.height_world_at(anchor_xz[i].x, anchor_xz[i].y))
		anchor.set_meta("surface_offset", MARKER_OFFSET)
		if create_visuals:
			_add_anchor_visual(anchor, i + 1, i == 0 or i == anchor_xz.size() - 1)

	var gate_position := sampler.point_world_at(gate_center_xz.x, gate_center_xz.y, MARKER_OFFSET)
	var gate := Marker3D.new()
	gate.name = "FutureGateCenter_OnRoad"
	root.add_child(gate)
	gate.global_position = gate_position
	gate.set_meta("terrain_y", sampler.height_world_at(gate_center_xz.x, gate_center_xz.y))
	gate.set_meta("road_center_distance", Vector2(gate.global_position.x, gate.global_position.z).distance_to(gate_center_xz))
	if create_visuals:
		_add_gate_visual(gate)

	root.set_meta("anchor_positions", anchor_positions)
	root.set_meta("anchor_count", anchor_positions.size())
	root.set_meta("gate_position", gate_position)
	root.set_meta("gate_left_position", anchor_positions[0])
	root.set_meta("gate_right_position", anchor_positions[-1])
	root.set_meta("road_gate_xz_error", Vector2(gate_position.x, gate_position.z).distance_to(gate_center_xz))
	root.set_meta("terrain_scale_y", terrain_root.global_transform.basis.y.length())
	return root


static func _add_anchor_visual(anchor: Marker3D, number: int, is_gate_edge: bool) -> void:
	var color := Color("#ff9c2a") if is_gate_edge else Color("#21d4fd")
	var material := _material(color, color.darkened(0.35))
	var marker := MeshInstance3D.new()
	marker.name = "AnchorPin"
	marker.mesh = _make_pin_mesh(material, 3.0, 5.5)
	anchor.add_child(marker)

	var label := Label3D.new()
	label.name = "AnchorNumber"
	label.text = str(number)
	label.position = Vector3(0.0, 7.0, 0.0)
	label.fixed_size = true
	label.font_size = 16
	label.outline_size = 5
	label.modulate = color
	label.outline_modulate = Color("#102027")
	label.no_depth_test = true
	anchor.add_child(label)


static func _add_gate_visual(gate: Marker3D) -> void:
	var color := Color("#ff2bb5")
	var material := _material(color, color.darkened(0.32))
	var marker := MeshInstance3D.new()
	marker.name = "GateCenterPin"
	marker.mesh = _make_pin_mesh(material, 4.2, 8.0)
	gate.add_child(marker)

	var label := Label3D.new()
	label.name = "GateLabel"
	label.text = "GATE"
	label.position = Vector3(0.0, 10.0, 0.0)
	label.fixed_size = true
	label.font_size = 15
	label.outline_size = 5
	label.modulate = color
	label.outline_modulate = Color("#2b0620")
	label.no_depth_test = true
	gate.add_child(label)


static func _make_pin_mesh(material: Material, radius: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var bottom := Vector3(0.0, 0.0, 0.0)
	var ring := [
		Vector3(radius, height * 0.55, 0.0),
		Vector3(0.0, height * 0.55, radius),
		Vector3(-radius, height * 0.55, 0.0),
		Vector3(0.0, height * 0.55, -radius)
	]
	var top := Vector3(0.0, height, 0.0)
	for i in ring.size():
		_add_triangle(surface, bottom, ring[(i + 1) % ring.size()], ring[i])
		_add_triangle(surface, top, ring[i], ring[(i + 1) % ring.size()])
	surface.generate_normals()
	return surface.commit()


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


static func _material(color: Color, emission: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 0.7
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
