extends RefCounted

# Shared world-space height sampler for every object placed on the Bratislava
# terrain. It reads the displayed Terrain-col mesh after the full GLB parent
# transform, including the 1.6 review Y scale.

const GRID_SIZE := 129

var min_x := INF
var max_x := -INF
var min_z := INF
var max_z := -INF
var step_x := 1.0
var step_z := 1.0
var heights := PackedFloat32Array()


func _init(terrain_root: Node3D) -> void:
	var terrain_mesh := terrain_root.find_child("Terrain-col", true, false) as MeshInstance3D
	assert(terrain_mesh != null, "Terrain-col is required for world-space height sampling")
	assert(terrain_mesh.is_inside_tree(), "Terrain must be inside the SceneTree before sampling")
	var world_transform := terrain_mesh.global_transform
	var all_vertices: Array[PackedVector3Array] = []
	for surface_index in terrain_mesh.mesh.get_surface_count():
		var arrays := terrain_mesh.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		all_vertices.append(vertices)
		for vertex in vertices:
			var point := world_transform * vertex
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
			var point := world_transform * vertex
			var ix := clampi(roundi((point.x - min_x) / step_x), 0, GRID_SIZE - 1)
			var iz := clampi(roundi((point.z - min_z) / step_z), 0, GRID_SIZE - 1)
			var index := iz * GRID_SIZE + ix
			heights[index] = maxf(heights[index], point.y)
	for height in heights:
		assert(is_finite(height), "Terrain-col height grid contains an unsampled cell")


func height_world_at(x: float, z: float) -> float:
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


func point_world_at(x: float, z: float, offset: float = 0.0) -> Vector3:
	return Vector3(x, height_world_at(x, z) + offset, z)
