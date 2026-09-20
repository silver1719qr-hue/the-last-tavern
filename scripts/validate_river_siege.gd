extends SceneTree

const RiverSiege = preload("res://scripts/river_siege.gd")


func _initialize() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var route_root := RiverSiege.build_route(scene)
	var path := route_root.get_node_or_null("InvaderShipPath3D") as Path3D
	if path == null:
		_fail("Invader ship Path3D is missing")
		return
	if path.curve.point_count < 40:
		_fail("Danube route is not sampled closely enough")
		return
	var length := path.curve.get_baked_length()
	if length < 10000.0:
		_fail("Devín-to-Bratislava river route is unexpectedly short")
		return
	if route_root.get_meta("source", "") != "Danube_OSM mesh centreline":
		_fail("River route is not derived from the Danube OSM mesh")
		return

	var min_y := INF
	var max_y := -INF
	for point in path.curve.get_baked_points():
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	if max_y - min_y < 8.0:
		_fail("Ship route is flat instead of following the river surface")
		return

	var bank := RiverSiege.defense_bank_points()
	if bank.size() < 10:
		_fail("Fortified embankment has too few shoreline anchors")
		return
	var route := RiverSiege.route_points()
	for bank_point in bank:
		var nearest_gap := INF
		for route_point in route:
			if absf(route_point.x - bank_point.x) < 1.0:
				nearest_gap = route_point.z - bank_point.y
		if nearest_gap < 95.0 or nearest_gap > 155.0:
			_fail("A fortification anchor is not on the northern Danube shoreline")
			return

	print(
		"RIVER_SIEGE_VALIDATION_OK source=Danube_OSM points=", path.curve.point_count,
		" length=", snappedf(length, 0.1), " height_span=", snappedf(max_y - min_y, 0.1),
		" bank_anchors=", bank.size()
	)
	scene.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("RIVER_SIEGE_VALIDATION_FAILED: ", message)
	quit(1)
