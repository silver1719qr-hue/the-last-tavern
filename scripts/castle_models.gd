extends RefCounted

# Game-ready landmark blockouts. Anchors and extents follow the real OSM
# castle footprints already embedded in the Bratislava terrain GLB.


static func build_bratislava(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Bratislava_Castle_Game_Landmark"
	root.position = Vector3(2260.8, 184.0, 4704.0)
	root.rotation.y = deg_to_rad(-8.0)
	parent.add_child(root)

	var plaster := _material(Color("#eee8dc"), 0.88)
	var trim := _material(Color("#d5c9b5"), 0.92)
	var roof := _material(Color("#8f3025"), 0.82)
	var dark := _material(Color("#263139"), 0.48)
	var courtyard := _material(Color("#b8aa91"), 1.0)

	# Four wings around the real castle's square courtyard.
	_add_box(root, "NorthWing", Vector3(0, 11, -35), Vector3(86, 22, 18), plaster)
	_add_box(root, "SouthWing", Vector3(0, 11, 35), Vector3(86, 22, 18), plaster)
	_add_box(root, "WestWing", Vector3(-35, 11, 0), Vector3(18, 22, 52), plaster)
	_add_box(root, "EastWing", Vector3(35, 11, 0), Vector3(18, 22, 52), plaster)
	_add_box(root, "Courtyard", Vector3(0, 0.35, 0), Vector3(51, 0.7, 51), courtyard)

	_add_box(root, "NorthRoof", Vector3(0, 23, -35), Vector3(89, 3.2, 21), roof)
	_add_box(root, "SouthRoof", Vector3(0, 23, 35), Vector3(89, 3.2, 21), roof)
	_add_box(root, "WestRoof", Vector3(-35, 23, 0), Vector3(21, 3.2, 55), roof)
	_add_box(root, "EastRoof", Vector3(35, 23, 0), Vector3(21, 3.2, 55), roof)

	var corners := [
		Vector3(-42, 0, -42), Vector3(42, 0, -42),
		Vector3(-42, 0, 42), Vector3(42, 0, 42)
	]
	for i in corners.size():
		var tower_height := 34.0 if i == 2 else 29.0
		_add_box(root, "CornerTower%d" % i, corners[i] + Vector3(0, tower_height * 0.5, 0), Vector3(18, tower_height, 18), plaster)
		_add_pyramid(root, "TowerRoof%d" % i, corners[i] + Vector3(0, tower_height + 5, 0), 14.5, 10.0, roof)

	# East portal and pale stone framing.
	_add_box(root, "EastPortal", Vector3(44.15, 7.0, 0), Vector3(1.0, 12.0, 8.0), dark)
	_add_box(root, "PortalTop", Vector3(44.75, 14.0, 0), Vector3(1.2, 2.0, 11.0), trim)

	# Restrained window rhythm on all four exterior facades.
	for x in [-28.0, -14.0, 0.0, 14.0, 28.0]:
		for y in [8.0, 16.0]:
			_add_box(root, "WindowN", Vector3(x, y, -44.15), Vector3(3.4, 4.4, 0.45), dark)
			_add_box(root, "WindowS", Vector3(x, y, 44.15), Vector3(3.4, 4.4, 0.45), dark)
	for z in [-26.0, -13.0, 13.0, 26.0]:
		for y in [8.0, 16.0]:
			_add_box(root, "WindowW", Vector3(-44.15, y, z), Vector3(0.45, 4.4, 3.4), dark)
			_add_box(root, "WindowE", Vector3(44.15, y, z), Vector3(0.45, 4.4, 3.4), dark)

	return root


static func build_devin(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Devin_Castle_Restored_Game_Landmark"
	root.position = Vector3(-6722.0, 114.0, 1321.0)
	root.rotation.y = deg_to_rad(-4.0)
	parent.add_child(root)

	var stone := _material(Color("#9a8d77"), 0.98)
	var light_stone := _material(Color("#b2a58d"), 0.96)
	var roof := _material(Color("#665044"), 0.9)
	var timber := _material(Color("#49382b"), 0.92)
	var gate_dark := _material(Color("#221f1c"), 1.0)

	# Irregular outer enceinte follows the real long OSM footprint on the cliff.
	var wall_points := [
		Vector3(-178, 0, -60), Vector3(-126, 0, -132),
		Vector3(-12, 0, -157), Vector3(116, 0, -105),
		Vector3(172, 0, -18), Vector3(139, 0, 105),
		Vector3(38, 0, 151), Vector3(-76, 0, 126),
		Vector3(-164, 0, 48)
	]
	for i in wall_points.size():
		_add_wall(root, "OuterWall%d" % i, wall_points[i], wall_points[(i + 1) % wall_points.size()], 11.0, 5.5, stone)

	# Gatehouse and flanking towers on the landward approach.
	_add_box(root, "Gatehouse", Vector3(151, 11, 10), Vector3(24, 22, 31), light_stone, deg_to_rad(-9.0))
	_add_box(root, "MainGate", Vector3(163.0, 6.0, 10), Vector3(1.0, 11, 8), gate_dark, deg_to_rad(-9.0))
	_add_round_tower(root, "GateTowerNorth", Vector3(142, 12, -18), 10, 24, stone)
	_add_round_tower(root, "GateTowerSouth", Vector3(146, 12, 38), 10, 24, stone)

	# Middle castle: service hall, chapel and defended courtyard.
	_add_box(root, "GreatHall", Vector3(43, 10, 48), Vector3(55, 20, 25), light_stone, deg_to_rad(-13.0))
	_add_box(root, "GreatHallRoof", Vector3(43, 21.5, 48), Vector3(59, 3, 29), roof, deg_to_rad(-13.0))
	_add_box(root, "Chapel", Vector3(70, 8.5, -44), Vector3(25, 17, 16), light_stone, deg_to_rad(18.0))
	_add_box(root, "ChapelRoof", Vector3(70, 18.2, -44), Vector3(28, 2.5, 19), roof, deg_to_rad(18.0))

	# Restored upper castle: compact keep above the river cliff.
	_add_wall(root, "UpperWallWest", Vector3(-104, 8, -52), Vector3(-92, 8, 38), 19, 6.5, light_stone)
	_add_wall(root, "UpperWallNorth", Vector3(-104, 8, -52), Vector3(-35, 8, -78), 19, 6.5, light_stone)
	_add_wall(root, "UpperWallEast", Vector3(-35, 8, -78), Vector3(-18, 8, 28), 19, 6.5, light_stone)
	_add_wall(root, "UpperWallSouth", Vector3(-18, 8, 28), Vector3(-92, 8, 38), 19, 6.5, light_stone)
	_add_box(root, "UpperKeep", Vector3(-65, 24, -20), Vector3(31, 32, 27), stone, deg_to_rad(-7.0))
	_add_pyramid(root, "UpperKeepRoof", Vector3(-65, 44, -20), 24, 12, roof)
	_add_round_tower(root, "DanubeWatchTower", Vector3(-153, 16, -77), 9, 32, stone)
	_add_pyramid(root, "WatchTowerRoof", Vector3(-153, 36.5, -77), 12, 9, roof)

	# Battlements make the restored silhouette readable when zoomed in.
	for x in range(-92, -29, 12):
		_add_box(root, "UpperMerlon", Vector3(float(x), 28.5, -68), Vector3(5, 5, 5), stone)
	for z in range(-118, 91, 24):
		_add_box(root, "WestMerlon", Vector3(-174, 8.5, float(z)), Vector3(5, 5, 6), stone)

	_add_box(root, "KeepDoor", Vector3(-65, 12.5, -6.2), Vector3(7, 12, 0.8), timber, deg_to_rad(-7.0))
	for y in [22.0, 31.0]:
		for x in [-73.0, -57.0]:
			_add_box(root, "KeepWindow", Vector3(x, y, -5.9), Vector3(4, 5, 0.7), gate_dark, deg_to_rad(-7.0))

	return root


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _add_box(parent: Node3D, object_name: String, position: Vector3, size: Vector3, material: Material, rotation_y: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation.y = rotation_y
	parent.add_child(instance)
	return instance


static func _add_pyramid(parent: Node3D, object_name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 4
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation.y = deg_to_rad(45.0)
	parent.add_child(instance)
	return instance


static func _add_round_tower(parent: Node3D, object_name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	return instance


static func _add_wall(parent: Node3D, object_name: String, from: Vector3, to: Vector3, height: float, thickness: float, material: Material) -> MeshInstance3D:
	var delta := to - from
	var midpoint := (from + to) * 0.5
	midpoint.y += height * 0.5
	return _add_box(parent, object_name, midpoint, Vector3(Vector2(delta.x, delta.z).length(), height, thickness), material, -atan2(delta.z, delta.x))
