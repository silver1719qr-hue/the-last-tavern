extends RefCounted

# First siege route: Petrzalka -> Danube bridge -> Castle Hill switchbacks ->
# Bratislava Castle. Heights are sampled from the real DEM at every control
# point; the bridge span itself uses the existing wooden pontoon deck.


static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Bratislava_First_Siege_Route"
	parent.add_child(root)

	var road_material := _material(Color("#8a6844"), 1.0)
	var edge_material := _material(Color("#4e493e"), 1.0)
	var pad_stone := _material(Color("#9a8d77"), 1.0)
	var pad_center := _material(Color("#594b37"), 1.0)
	var route_points: Array[Vector3] = [
		Vector3(2262.0, 30.6, 5480.0),
		Vector3(2262.0, 31.7, 5350.0),
		Vector3(2262.0, 45.3, 5005.0),
		Vector3(2480.0, 35.3, 5000.0),
		Vector3(2480.0, 41.9, 4940.0),
		Vector3(2280.0, 57.5, 4960.0),
		Vector3(2450.0, 61.0, 4900.0),
		Vector3(2350.0, 84.4, 4900.0),
		Vector3(2250.0, 99.7, 4900.0),
		Vector3(2150.0, 101.7, 4900.0),
		Vector3(2020.0, 119.0, 4850.0),
		Vector3(2100.0, 139.4, 4840.0),
		Vector3(2200.0, 151.4, 4830.0),
		Vector3(2300.0, 150.4, 4820.0),
		Vector3(2384.0, 138.9, 4806.0),
		Vector3(2410.0, 137.3, 4765.0),
		Vector3(2350.0, 153.2, 4765.0),
		Vector3(2250.0, 182.6, 4765.0),
		Vector3(2150.0, 162.1, 4765.0),
		Vector3(2050.0, 160.9, 4765.0),
		Vector3(2020.0, 169.6, 4710.0),
		Vector3(2100.0, 157.2, 4710.0),
		Vector3(2200.0, 177.0, 4725.0),
		Vector3(2255.0, 183.5, 4750.0)
	]
	var north_road := _chaikin(route_points.slice(2), 2)
	var navigation_points: Array[Vector3] = [route_points[0], route_points[1]]
	for point in north_road:
		navigation_points.append(point)

	# This curve is the future navigation source for monster movement.
	var path := Path3D.new()
	path.name = "EnemyPath3D"
	path.curve = Curve3D.new()
	path.curve.bake_interval = 4.0
	for point in navigation_points:
		path.curve.add_point(point)
	root.add_child(path)

	# The bridge already provides its own wooden surface, so the road is split
	# into a south-bank approach and a north-bank castle climb.
	_add_road_section(root, "SouthBankApproach", route_points.slice(0, 1), 18.0, road_material, edge_material)
	_add_road_section(root, "CastleHillRoad", north_road, 18.0, road_material, edge_material)

	var spawn := Marker3D.new()
	spawn.name = "EnemySpawn_SouthBank"
	spawn.position = route_points[0]
	root.add_child(spawn)

	var goal := Marker3D.new()
	goal.name = "EnemyGoal_BratislavaCastleGate"
	goal.position = route_points[-1]
	root.add_child(goal)

	var tower_points: Array[Vector3] = [
		Vector3(2225.0, 28.3, 5450.0),
		Vector3(2240.0, 69.8, 4940.0),
		Vector3(2475.0, 69.1, 4865.0),
		Vector3(2100.0, 128.2, 4864.0),
		Vector3(2435.0, 117.9, 4810.0),
		Vector3(2025.0, 154.5, 4800.0),
		Vector3(2000.0, 171.8, 4680.0),
		Vector3(2320.0, 161.7, 4715.0)
	]
	for i in tower_points.size():
		_add_tower_pad(root, i + 1, tower_points[i], pad_stone, pad_center)

	return root


static func _chaikin(points: Array[Vector3], passes: int) -> Array[Vector3]:
	var result := points.duplicate()
	for _pass in passes:
		if result.size() < 3:
			break
		var rounded: Array[Vector3] = [result[0]]
		for i in result.size() - 1:
			rounded.append(result[i].lerp(result[i + 1], 0.25))
			rounded.append(result[i].lerp(result[i + 1], 0.75))
		rounded.append(result[-1])
		result = rounded
	return result


static func _add_road_section(parent: Node3D, object_name: String, points: Array[Vector3], width: float, road_material: Material, edge_material: Material) -> void:
	if points.size() < 2:
		return
	_add_ribbon(parent, object_name, points, width, road_material)
	var left_edge := _offset_points(points, width * 0.5 - 0.8, 0.16)
	var right_edge := _offset_points(points, -width * 0.5 + 0.8, 0.16)
	_add_ribbon(parent, object_name + "_LeftEdge", left_edge, 1.5, edge_material)
	_add_ribbon(parent, object_name + "_RightEdge", right_edge, 1.5, edge_material)


static func _add_ribbon(parent: Node3D, object_name: String, points: Array[Vector3], width: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in points.size():
		var tangent: Vector3
		if i == 0:
			tangent = points[1] - points[0]
		elif i == points.size() - 1:
			tangent = points[i] - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent.y = 0.0
		tangent = tangent.normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x) * width * 0.5
		left.append(points[i] + side)
		right.append(points[i] - side)
	for i in points.size() - 1:
		_add_triangle(surface, left[i], right[i], right[i + 1])
		_add_triangle(surface, left[i], right[i + 1], left[i + 1])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = surface.commit()
	parent.add_child(instance)
	return instance


static func _offset_points(points: Array[Vector3], offset: float, lift: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in points.size():
		var tangent: Vector3
		if i == 0:
			tangent = points[1] - points[0]
		elif i == points.size() - 1:
			tangent = points[i] - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent.y = 0.0
		tangent = tangent.normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x) * offset
		result.append(points[i] + side + Vector3.UP * lift)
	return result


static func _add_tower_pad(parent: Node3D, number: int, position: Vector3, stone: Material, center_material: Material) -> void:
	var root := Node3D.new()
	root.name = "TowerBuildPoint_%02d" % number
	root.position = position
	parent.add_child(root)
	var marker := Marker3D.new()
	marker.name = "TowerAnchor"
	root.add_child(marker)

	var outer_mesh := CylinderMesh.new()
	outer_mesh.top_radius = 18.0
	outer_mesh.bottom_radius = 18.8
	outer_mesh.height = 1.5
	outer_mesh.radial_segments = 24
	outer_mesh.material = stone
	var outer := MeshInstance3D.new()
	outer.name = "StoneFoundation"
	outer.mesh = outer_mesh
	root.add_child(outer)

	var center_mesh := CylinderMesh.new()
	center_mesh.top_radius = 13.5
	center_mesh.bottom_radius = 13.5
	center_mesh.height = 1.65
	center_mesh.radial_segments = 24
	center_mesh.material = center_material
	var center := MeshInstance3D.new()
	center.name = "BuildSurface"
	center.mesh = center_mesh
	center.position.y = 0.15
	root.add_child(center)


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
