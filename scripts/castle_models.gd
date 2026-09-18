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
	var fortification := _material(Color("#9f927d"), 0.98)
	var hedge := _material(Color("#244d25"), 1.0)
	var garden_path := _material(Color("#c8b896"), 1.0)

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

	# The castle is not an isolated palace: the real complex is enclosed by
	# massive walls and four admission gates. These terrain-following segments
	# stay inside the verified OSM site extent and descend with Castle Hill.
	var fortification_points := [
		Vector3(-135, -48.1, -125), Vector3(110, -76.3, -135),
		Vector3(140, -44.9, -70), Vector3(135, -97.2, 120),
		Vector3(80, -79.3, 150), Vector3(-115, -27.6, 145),
		Vector3(-145, -28.5, 70)
	]
	for i in fortification_points.size():
		_add_sloped_wall(root, "CastleFortification%d" % i, fortification_points[i], fortification_points[(i + 1) % fortification_points.size()], 12.0, 5.0, fortification)

	# Sigismund, Vienna and Leopold approaches, simplified at game scale.
	_add_box(root, "SigismundGate", Vector3(136, -83, 84), Vector3(18, 22, 27), fortification, deg_to_rad(3.0))
	_add_box(root, "SigismundOpening", Vector3(127.0, -87, 84), Vector3(1.0, 11, 7), dark, deg_to_rad(3.0))
	_add_box(root, "ViennaGate", Vector3(88, -62, -133), Vector3(26, 20, 15), fortification)
	_add_box(root, "LeopoldGate", Vector3(-132, -18, 78), Vector3(18, 20, 26), fortification, deg_to_rad(-8.0))

	# Baroque garden north of the palace: walled terrace, paths and clipped
	# boxwood pattern, based on the restored Maria Theresa-era garden.
	_add_box(root, "GardenTerrace", Vector3(0, -9.5, -93), Vector3(102, 2.0, 74), garden_path)
	_add_box(root, "GardenRetainingNorth", Vector3(0, -20, -131), Vector3(108, 24, 5), fortification)
	_add_box(root, "GardenWallWest", Vector3(-53, -3, -93), Vector3(5, 15, 78), fortification)
	_add_box(root, "GardenWallEast", Vector3(53, -3, -93), Vector3(5, 15, 78), fortification)
	for x in [-36.0, -18.0, 18.0, 36.0]:
		_add_box(root, "BaroqueHedgeLong", Vector3(x, -7.6, -93), Vector3(3.2, 3.8, 55), hedge)
	for z in [-113.0, -93.0, -73.0]:
		_add_box(root, "BaroqueHedgeCross", Vector3(0, -7.6, z), Vector3(78, 3.8, 3.2), hedge)

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
	var limestone := _material(Color("#777267"), 1.0)

	# The Upper Castle rises from the real Devín limestone crag. The broad east
	# side merges into the mainland; only the river-facing faces are exposed.
	_add_devin_cliff(root, limestone)

	# Irregular outer enceinte follows the real long OSM footprint on the cliff.
	var wall_points := [
		Vector3(-178, -0.4, -60), Vector3(-126, 0.2, -132),
		Vector3(-12, -49.0, -157), Vector3(116, -30.5, -105),
		Vector3(172, -35.8, -18), Vector3(139, -31.0, 105),
		Vector3(38, -58.7, 151), Vector3(-76, -65.9, 126),
		Vector3(-164, -42.5, 48)
	]
	for i in wall_points.size():
		_add_sloped_wall(root, "OuterWall%d" % i, wall_points[i], wall_points[(i + 1) % wall_points.size()], 11.0, 5.5, stone)

	# Gatehouse and flanking towers on the landward approach.
	_add_box(root, "Gatehouse", Vector3(151, -24.8, 10), Vector3(24, 22, 31), light_stone, deg_to_rad(-9.0))
	_add_box(root, "MainGate", Vector3(163.0, -29.8, 10), Vector3(1.0, 11, 8), gate_dark, deg_to_rad(-9.0))
	_add_round_tower(root, "GateTowerNorth", Vector3(142, -23.8, -18), 10, 24, stone)
	_add_round_tower(root, "GateTowerSouth", Vector3(146, -19.0, 38), 10, 24, stone)

	# Middle castle: service hall, chapel and defended courtyard.
	_add_box(root, "GreatHall", Vector3(43, -1.4, 48), Vector3(55, 20, 25), light_stone, deg_to_rad(-13.0))
	_add_box(root, "GreatHallRoof", Vector3(43, 10.1, 48), Vector3(59, 3, 29), roof, deg_to_rad(-13.0))
	_add_box(root, "Chapel", Vector3(70, -22.0, -44), Vector3(25, 17, 16), light_stone, deg_to_rad(18.0))
	_add_box(root, "ChapelRoof", Vector3(70, -12.3, -44), Vector3(28, 2.5, 19), roof, deg_to_rad(18.0))

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

	_add_box(root, "KeepDoor", Vector3(-65, 12.5, -6.2), Vector3(7, 12, 0.8), timber, deg_to_rad(-7.0))
	for y in [22.0, 31.0]:
		for x in [-73.0, -57.0]:
			_add_box(root, "KeepWindow", Vector3(x, y, -5.9), Vector3(4, 5, 0.7), gate_dark, deg_to_rad(-7.0))

	return root


static func build_historical_bridges(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Historical_Game_Bridges"
	parent.add_child(root)
	var wood := _material(Color("#65452c"), 0.95)
	var dark_wood := _material(Color("#3d2a1d"), 1.0)

	# Danube: a timber-deck pontoon bridge, the historically appropriate bridge
	# family used at Bratislava before permanent steel crossings.
	for i in range(46):
		var z := 5004.0 + float(i) * 7.5
		_add_box(root, "DanubeDeckPlank", Vector3(2262, 41.5, z), Vector3(12, 0.75, 7.1), wood)
		if i % 4 == 0:
			_add_box(root, "DanubePontoon", Vector3(2262, 37.2, z), Vector3(20, 3.0, 5.0), dark_wood)
	for z in range(5010, 5350, 18):
		_add_box(root, "DanubeRailPostL", Vector3(2256, 44, float(z)), Vector3(0.7, 5, 0.7), dark_wood)
		_add_box(root, "DanubeRailPostR", Vector3(2268, 44, float(z)), Vector3(0.7, 5, 0.7), dark_wood)
	_add_box(root, "DanubeRailL", Vector3(2256, 46, 5173), Vector3(0.7, 0.8, 342), dark_wood)
	_add_box(root, "DanubeRailR", Vector3(2268, 46, 5173), Vector3(0.7, 0.8, 342), dark_wood)

	# Devín: a narrower gameplay crossing over the real Morava channel. It is a
	# historically styled route, not claimed as a surviving exact bridge.
	_add_sloped_wall(root, "MoravaBridgeWestRamp", Vector3(-7060, 43, 700), Vector3(-7005, 47, 700), 0.8, 9.0, wood)
	_add_sloped_wall(root, "MoravaBridgeDeck", Vector3(-7005, 47, 700), Vector3(-6823, 47, 700), 0.8, 9.0, wood)
	_add_sloped_wall(root, "MoravaBridgeEastRamp", Vector3(-6823, 47, 700), Vector3(-6750, 66, 700), 0.8, 9.0, wood)
	for x in range(-6995, -6825, 20):
		_add_box(root, "MoravaTrestle", Vector3(float(x), 43.5, 700), Vector3(0.9, 7, 7), dark_wood)
		_add_box(root, "MoravaRailPostN", Vector3(float(x), 50, 695.5), Vector3(0.7, 5, 0.7), dark_wood)
		_add_box(root, "MoravaRailPostS", Vector3(float(x), 50, 704.5), Vector3(0.7, 5, 0.7), dark_wood)
	_add_box(root, "MoravaRailN", Vector3(-6914, 52, 695.5), Vector3(182, 0.8, 0.7), dark_wood)
	_add_box(root, "MoravaRailS", Vector3(-6914, 52, 704.5), Vector3(182, 0.8, 0.7), dark_wood)

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


static func _add_sloped_wall(parent: Node3D, object_name: String, from: Vector3, to: Vector3, height: float, thickness: float, material: Material) -> MeshInstance3D:
	var horizontal := Vector3(to.x - from.x, 0, to.z - from.z)
	var side := Vector3(-horizontal.z, 0, horizontal.x).normalized() * thickness * 0.5
	var a := from - side
	var b := from + side
	var c := to + side
	var d := to - side
	var up := Vector3.UP * height
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	_add_quad(surface, a, b, c, d)
	_add_quad(surface, a + up, d + up, c + up, b + up)
	_add_quad(surface, a, a + up, b + up, b)
	_add_quad(surface, d, c, c + up, d + up)
	_add_quad(surface, a, d, d + up, a + up)
	_add_quad(surface, b, b + up, c + up, c)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = surface.commit()
	parent.add_child(instance)
	return instance


static func _add_devin_cliff(parent: Node3D, material: Material) -> MeshInstance3D:
	# Hand-fitted to the DEM: high on the connected eastern side, dropping to
	# the Morava/Danube-facing foot. No random noise and no island geometry.
	var top := [
		Vector3(-171, 0, -102), Vector3(-108, 8, -112),
		Vector3(-38, 10, -78), Vector3(-12, 4, -18),
		Vector3(-34, -3, 39), Vector3(-102, -8, 52),
		Vector3(-161, -34, 16), Vector3(-184, -51, -52)
	]
	var bottom := [
		Vector3(-214, -67, -117), Vector3(-139, -62, -139),
		Vector3(-46, -48, -112), Vector3(-18, -37, -30),
		Vector3(-50, -55, 66), Vector3(-137, -67, 78),
		Vector3(-207, -75, 31), Vector3(-225, -75, -61)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for i in top.size():
		_add_quad(surface, top[i], top[(i + 1) % top.size()], bottom[(i + 1) % bottom.size()], bottom[i])
	var top_center := Vector3.ZERO
	for point in top:
		top_center += point
	top_center /= float(top.size())
	for i in top.size():
		surface.add_vertex(top_center)
		surface.add_vertex(top[i])
		surface.add_vertex(top[(i + 1) % top.size()])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "DevinLimestoneCrag"
	instance.mesh = surface.commit()
	parent.add_child(instance)
	return instance


static func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)
