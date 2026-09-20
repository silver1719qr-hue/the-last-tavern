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
	if path.curve.point_count < 12:
		_fail("Danube route has too few control points")
		return
	var length := path.curve.get_baked_length()
	if length < 8500.0:
		_fail("Devín-to-Bratislava river route is unexpectedly short")
		return
	if route_root.get_meta("source", "") != "Danube river siege route":
		_fail("River route metadata is incorrect")
		return
	for point in path.curve.get_baked_points():
		if absf(point.y - RiverSiege.WATER_Y) > 0.1:
			_fail("A ship route point is outside the water plane")
			return
	print("RIVER_SIEGE_VALIDATION_OK points=", path.curve.point_count, " length=", snappedf(length, 0.1))
	scene.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("RIVER_SIEGE_VALIDATION_FAILED: ", message)
	quit(1)

