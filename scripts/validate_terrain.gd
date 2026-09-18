extends SceneTree

const GLB_PATH := "res://Bratislava_Real_Terrain_Godot4.glb"


func _initialize() -> void:
	var packed := load(GLB_PATH) as PackedScene
	if packed == null:
		_fail("GLB could not be loaded as PackedScene")
		return

	var imported_root := packed.instantiate()
	var found := {}
	for child in imported_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		found[str(mesh_instance.name)] = mesh_instance

	var required := ["Terrain", "Terrain-col", "Danube_OSM", "Morava_OSM", "Bratislava_Castle_OSM_Placeholder", "Devin_Castle_OSM_Placeholder"]
	for node_name in required:
		if not found.has(node_name):
			imported_root.free()
			_fail("Missing required GLB mesh: " + node_name)
			return

	var terrain := found["Terrain"] as MeshInstance3D
	var bounds := terrain.get_aabb()
	print("TERRAIN_BOUNDS position=", bounds.position, " size=", bounds.size)
	print("TERRAIN_MESH_COUNT=", found.size())
	if bounds.size.x < 18000.0 or bounds.size.z < 18000.0:
		imported_root.free()
		_fail("Terrain horizontal bounds are unexpectedly small")
		return
	if bounds.size.y < 500.0:
		imported_root.free()
		_fail("Terrain vertical relief is unexpectedly flat")
		return

	print("TERRAIN_VALIDATION_OK real GLB geometry present; Danube and Morava present")
	imported_root.free()
	quit(0)


func _fail(message: String) -> void:
	printerr("TERRAIN_VALIDATION_FAILED: ", message)
	quit(1)
