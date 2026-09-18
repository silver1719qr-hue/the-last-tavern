extends RefCounted

const TerrainSurface = preload("res://scripts/terrain_surface.gd")

const WALL_HEIGHT := 11.0
const WALL_THICKNESS := 5.0
const GATE_CENTER := Vector2(2260.0, 4762.0)
const GATE_HALF_WIDTH := 18.0


static func build(parent: Node3D, terrain_root: Node3D) -> Node3D:
	var sampler := TerrainSurface.new(terrain_root)
	var root := Node3D.new()
	root.name = "Bratislava_Castle_Fortifications"
	parent.add_child(root)
	root.top_level = true
	root.global_transform = Transform3D.IDENTITY

	var stone := _material(Color("#8e8778"))
	var dark := _material(Color("#4b4035"))
	var roof := _material(Color("#7d3128"))

	# Terrain-following enclosure around the castle. The south side intentionally
	# leaves a centred opening toward the Danube/bridge.
	var loop: Array[Vector2] = [
		# West / north / east perimeter around the castle hill.
		Vector2(2160.0, 4760.0),
		Vector2(2140.0, 4700.0),
		Vector2(2165.0, 4630.0),
		Vector2(2260.0, 4585.0),
		Vector2(2355.0, 4630.0),
		Vector2(2380.0, 4700.0),
		Vector2(2360.0, 4760.0)
	]
	var gate_left := Vector2(GATE_CENTER.x - GATE_HALF_WIDTH, GATE_CENTER.y)
	var gate_right := Vector2(GATE_CENTER.x + GATE_HALF_WIDTH, GATE_CENTER.y)

	# Left half of river-facing wall -> west/north/east perimeter.
	_add_wall_path(root, [gate_left, loop[0], loop[1], loop[2], loop[3], loop[4], loop[5], loop[6], gate_right], sampler, stone)

	# Main gate faces the river and aligns with the final road center.
	_add_gatehouse(root, sampler, stone, dark, roof)
	return root


static func _add_wall_path(parent: Node3D, points: Array[Vector2], sampler: TerrainSurface, material: Material) -> void:
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var pieces := maxi(1, ceili(length / 18.0))
		for j in range(pieces):
			var t0 := float(j) / float(pieces)
			var t1 := float(j + 1) / float(pieces)
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, t1)
			_add_wall_segment(parent, p0, p1, sampler, material)


static func _add_wall_segment(parent: Node3D, a_xz: Vector2, b_xz: Vector2, sampler: TerrainSurface, material: Material) -> void:
	var a := sampler.point_world_at(a_xz.x, a_xz.y, 0.15)
	var b := sampler.point_world_at(b_xz.x, b_xz.y, 0.15)
	var horizontal := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if horizontal.length() < 0.1:
		return
	var side := Vector3(-horizontal.z, 0.0, horizontal.x).normalized() * WALL_THICKNESS * 0.5
	var a0 := a - side
	var a1 := a + side
	var b0 := b - side
	var b1 := b + side
	var up := Vector3.UP * WALL_HEIGHT

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	_quad(st, a0, a1, b1, b0)
	_quad(st, a0 + up, b0 + up, b1 + up, a1 + up)
	_quad(st, a0, a0 + up, a1 + up, a1)
	_quad(st, b0, b1, b1 + up, b0 + up)
	_quad(st, a0, b0, b0 + up, a0 + up)
	_quad(st, a1, a1 + up, b1 + up, b1)
	st.generate_normals()

	var mesh := MeshInstance3D.new()
	mesh.name = "WallSegment"
	mesh.mesh = st.commit()
	parent.add_child(mesh)


static func _add_gatehouse(parent: Node3D, sampler: TerrainSurface, stone: Material, dark: Material, roof: Material) -> void:
	var ground_y := sampler.height_world_at(GATE_CENTER.x, GATE_CENTER.y)
	var gate_width := GATE_HALF_WIDTH * 2.0
	var tower_offset := GATE_HALF_WIDTH + 7.0

	var gate_sides: Array[float] = [-1.0, 1.0]
	for side_sign: float in gate_sides:
		var x: float = GATE_CENTER.x + tower_offset * side_sign
		var y: float = sampler.height_world_at(x, GATE_CENTER.y)
		_add_cylinder(parent, Vector3(x, y + 8.0, GATE_CENTER.y), 7.0, 16.0, stone)
		_add_cone(parent, Vector3(x, y + 19.0, GATE_CENTER.y), 8.5, 7.0, roof)

	# Dark opening and stone lintel, centred exactly on the road.
	_add_box(parent, Vector3(GATE_CENTER.x, ground_y + 5.0, GATE_CENTER.y), Vector3(gate_width, 10.0, 4.5), dark)
	_add_box(parent, Vector3(GATE_CENTER.x, ground_y + 12.0, GATE_CENTER.y), Vector3(gate_width + 6.0, 4.0, 6.0), stone)

	var label := Label3D.new()
	label.text = "MAIN GATE"
	label.position = Vector3(GATE_CENTER.x, ground_y + 19.0, GATE_CENTER.y)
	label.fixed_size = true
	label.font_size = 10
	label.outline_size = 3
	label.modulate = Color("#ffd88a")
	label.no_depth_test = true
	parent.add_child(label)


static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.position = pos
	parent.add_child(instance)


static func _add_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.05
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)


static func _add_cone(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
