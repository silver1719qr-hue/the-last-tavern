extends Node3D

const TerrainSurface = preload("res://scripts/terrain_surface.gd")
const SHIP_SCENE: PackedScene = preload("res://assets/kenney/pirate/ship-pirate-large.glb")
const WALL_SCENE: PackedScene = preload("res://assets/kenney/pirate/castle-wall.glb")
const TOWER_SCENE: PackedScene = preload("res://assets/kenney/pirate/tower-watch.glb")
const CANNON_SCENE: PackedScene = preload("res://assets/kenney/pirate/cannon.glb")

const WATER_Y := 39.5
const SHIP_SCALE := 4.2
const SHIP_SPEED := 62.0

var route_curve: Curve3D
var ships: Array[Dictionary] = []
var batteries: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var sampler


static func route_points() -> Array[Vector3]:
	# A broad downstream Danube route: Devín confluence -> Karlova Ves bend ->
	# Bratislava riverfront. It stays on the imported OSM water corridor.
	return [
		Vector3(-6810.0, WATER_Y, 1030.0),
		Vector3(-6460.0, WATER_Y, 1420.0),
		Vector3(-5960.0, WATER_Y, 1770.0),
		Vector3(-5350.0, WATER_Y, 2140.0),
		Vector3(-4680.0, WATER_Y, 2630.0),
		Vector3(-3920.0, WATER_Y, 3260.0),
		Vector3(-3050.0, WATER_Y, 3920.0),
		Vector3(-2140.0, WATER_Y, 4490.0),
		Vector3(-1160.0, WATER_Y, 4960.0),
		Vector3(-120.0, WATER_Y, 5280.0),
		Vector3(820.0, WATER_Y, 5370.0),
		Vector3(1540.0, WATER_Y, 5290.0),
		Vector3(2050.0, WATER_Y, 5150.0),
		Vector3(2225.0, WATER_Y, 5060.0)
	]


static func build_route(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Devin_To_Bratislava_River_Route"
	parent.add_child(root)
	var path := Path3D.new()
	path.name = "InvaderShipPath3D"
	path.curve = Curve3D.new()
	path.curve.bake_interval = 12.0
	for point in route_points():
		path.curve.add_point(point)
	root.add_child(path)
	root.set_meta("source", "Danube river siege route")
	root.set_meta("route_length", path.curve.get_baked_length())
	return root


func setup(terrain_root: Node3D) -> void:
	sampler = TerrainSurface.new(terrain_root)
	var route_root := build_route(self)
	route_curve = (route_root.get_node("InvaderShipPath3D") as Path3D).curve
	_build_fortified_embankment()
	_spawn_initial_fleet()


func _process(delta: float) -> void:
	if route_curve == null:
		return
	_update_ships(delta)
	_update_batteries(delta)
	_update_projectiles(delta)


func _spawn_initial_fleet() -> void:
	var length := route_curve.get_baked_length()
	var progresses := [0.0, length * 0.38, length * 0.61, length * 0.76, length * 0.86, length * 0.93]
	for i in range(progresses.size()):
		_spawn_ship(float(progresses[i]), i)


func _spawn_ship(progress: float, index: int) -> void:
	var ship := SHIP_SCENE.instantiate() as Node3D
	ship.name = "InvaderShip_%02d" % (index + 1)
	ship.scale = Vector3.ONE * SHIP_SCALE
	add_child(ship)
	ships.append({
		"root": ship,
		"progress": progress,
		"speed": SHIP_SPEED * (0.92 + float(index % 3) * 0.05),
		"hp": 100.0
	})
	_place_ship(ships[-1])


func _place_ship(ship_data: Dictionary) -> void:
	var ship := ship_data["root"] as Node3D
	var progress := float(ship_data["progress"])
	var length := route_curve.get_baked_length()
	var p := route_curve.sample_baked(clampf(progress, 0.0, length), true)
	var ahead := route_curve.sample_baked(clampf(progress + 18.0, 0.0, length), true)
	ship.global_position = p
	if p.distance_to(ahead) > 0.1:
		ship.look_at(ahead, Vector3.UP)


func _update_ships(delta: float) -> void:
	var length := route_curve.get_baked_length()
	for i in range(ships.size() - 1, -1, -1):
		var ship_data: Dictionary = ships[i]
		var ship := ship_data["root"] as Node3D
		if not is_instance_valid(ship):
			ships.remove_at(i)
			continue
		ship_data["progress"] = float(ship_data["progress"]) + float(ship_data["speed"]) * delta
		if float(ship_data["progress"]) >= length:
			ship_data["progress"] = 0.0
			ship_data["hp"] = 100.0
		ships[i] = ship_data
		_place_ship(ship_data)


func _build_fortified_embankment() -> void:
	var wall_points: Array[Vector2] = [
		Vector2(380.0, 5015.0), Vector2(720.0, 5000.0),
		Vector2(1060.0, 4980.0), Vector2(1400.0, 4955.0),
		Vector2(1730.0, 4925.0), Vector2(2050.0, 4895.0)
	]
	for segment_index in range(wall_points.size() - 1):
		var a := wall_points[segment_index]
		var b := wall_points[segment_index + 1]
		var length := a.distance_to(b)
		var pieces := maxi(1, ceili(length / 34.0))
		for j in range(pieces):
			var p := a.lerp(b, (float(j) + 0.5) / float(pieces))
			var next := a.lerp(b, minf((float(j) + 1.5) / float(pieces), 1.0))
			var wall := WALL_SCENE.instantiate() as Node3D
			wall.name = "RiverWall_%02d_%02d" % [segment_index, j]
			wall.scale = Vector3(4.6, 4.6, 4.6)
			add_child(wall)
			wall.global_position = Vector3(p.x, sampler.height_world_at(p.x, p.y) + 4.5, p.y)
			wall.rotation.y = -atan2(next.y - p.y, next.x - p.x)

	var defense_points: Array[Vector2] = [
		Vector2(480.0, 4985.0), Vector2(850.0, 4965.0),
		Vector2(1220.0, 4940.0), Vector2(1580.0, 4910.0),
		Vector2(1930.0, 4875.0), Vector2(2160.0, 4840.0)
	]
	for i in range(defense_points.size()):
		var p := defense_points[i]
		var ground: float = float(sampler.height_world_at(p.x, p.y))
		var tower := TOWER_SCENE.instantiate() as Node3D
		tower.name = "DanubeWatchtower_%02d" % (i + 1)
		tower.scale = Vector3.ONE * 6.0
		add_child(tower)
		tower.global_position = Vector3(p.x, ground + 6.0, p.y)

		var cannon := CANNON_SCENE.instantiate() as Node3D
		cannon.name = "RiverCannon_%02d" % (i + 1)
		cannon.scale = Vector3.ONE * 4.0
		add_child(cannon)
		cannon.global_position = Vector3(p.x, ground + 4.4, p.y + 18.0)
		cannon.rotation.y = PI
		batteries.append({"root": cannon, "cooldown": 0.35 + float(i) * 0.23, "index": i})


func _update_batteries(delta: float) -> void:
	for i in range(batteries.size()):
		var battery: Dictionary = batteries[i]
		battery["cooldown"] = float(battery["cooldown"]) - delta
		if float(battery["cooldown"]) <= 0.0:
			var cannon := battery["root"] as Node3D
			var target := _nearest_ship(cannon.global_position, 980.0)
			if target != null:
				_fire(cannon, target)
				battery["cooldown"] = 2.8 + float(int(battery["index"]) % 3) * 0.45
			else:
				battery["cooldown"] = 0.5
		batteries[i] = battery


func _nearest_ship(origin: Vector3, max_distance: float) -> Node3D:
	var result: Node3D = null
	var best := max_distance
	for ship_data in ships:
		var ship := ship_data["root"] as Node3D
		if is_instance_valid(ship):
			var distance := origin.distance_to(ship.global_position)
			if distance < best:
				best = distance
				result = ship
	return result


func _fire(cannon: Node3D, target: Node3D) -> void:
	var ball := MeshInstance3D.new()
	ball.name = "Cannonball"
	var sphere := SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 2.4
	ball.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#2a2521")
	material.metallic = 0.65
	material.roughness = 0.5
	ball.material_override = material
	add_child(ball)
	ball.global_position = cannon.global_position + Vector3(0.0, 6.5, 8.0)
	projectiles.append({
		"root": ball,
		"start": ball.global_position,
		"target": target,
		"time": 0.0,
		"duration": maxf(0.45, ball.global_position.distance_to(target.global_position) / 420.0)
	})


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var ball := shot["root"] as Node3D
		var target := shot["target"] as Node3D
		if not is_instance_valid(ball) or not is_instance_valid(target):
			if is_instance_valid(ball):
				ball.queue_free()
			projectiles.remove_at(i)
			continue
		shot["time"] = float(shot["time"]) + delta
		var t := clampf(float(shot["time"]) / float(shot["duration"]), 0.0, 1.0)
		var destination := target.global_position + Vector3(0.0, 8.0, 0.0)
		var start: Vector3 = shot["start"]
		var position := start.lerp(destination, t)
		position.y += sin(t * PI) * 70.0
		ball.global_position = position
		projectiles[i] = shot
		if t >= 1.0:
			ball.queue_free()
			projectiles.remove_at(i)
