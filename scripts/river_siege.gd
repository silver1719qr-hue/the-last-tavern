extends Node3D

const TerrainSurface = preload("res://scripts/terrain_surface.gd")
const SHIP_SCENE: PackedScene = preload("res://assets/kenney/pirate/ship-pirate-large.glb")
const WALL_SCENE: PackedScene = preload("res://assets/kenney/pirate/castle-wall.glb")
const TOWER_SCENE: PackedScene = preload("res://assets/kenney/pirate/tower-watch.glb")
const CANNON_SCENE: PackedScene = preload("res://assets/kenney/pirate/cannon.glb")

const SHIP_SCALE := 4.2
const SHIP_SPEED := 46.0
const MAX_SHIPS := 7

var route_curve: Curve3D
var ships: Array[Dictionary] = []
var batteries: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var sampler
var camera: Camera3D

var gold := 360
var destroyed := 0
var reached_city := 0
var next_ship_id := 1
var respawn_timer := 0.0
var hud: Label
var message: Label


static func route_points() -> Array[Vector3]:
	# Extracted from the centre of the Danube_OSM mesh in the terrain GLB.
	# Y follows the real sloping water surface after the 1.6 scene scale.
	return [
		Vector3(-6800.0, 48.1, 1563.3), Vector3(-6600.0, 40.8, 1714.6),
		Vector3(-6400.0, 38.0, 1859.9), Vector3(-6200.0, 39.1, 2010.5),
		Vector3(-6000.0, 40.0, 2173.6), Vector3(-5800.0, 39.6, 2345.4),
		Vector3(-5600.0, 39.3, 2517.2), Vector3(-5400.0, 39.0, 2689.0),
		Vector3(-5200.0, 38.0, 2860.8), Vector3(-5000.0, 37.9, 3019.4),
		Vector3(-4800.0, 37.8, 3169.4), Vector3(-4600.0, 37.8, 3323.0),
		Vector3(-4400.0, 37.5, 3490.8), Vector3(-4200.0, 37.1, 3671.2),
		Vector3(-4000.0, 37.4, 3909.6), Vector3(-3800.0, 38.1, 4178.7),
		Vector3(-3600.0, 38.5, 4429.9), Vector3(-3400.0, 39.9, 4659.8),
		Vector3(-3200.0, 40.3, 4818.5), Vector3(-3000.0, 39.9, 4893.5),
		Vector3(-2800.0, 39.5, 4968.5), Vector3(-2600.0, 39.2, 4979.3),
		Vector3(-2400.0, 38.8, 4978.7), Vector3(-2200.0, 38.2, 4966.6),
		Vector3(-2000.0, 37.8, 4919.7), Vector3(-1800.0, 37.6, 4872.6),
		Vector3(-1600.0, 37.5, 4825.5), Vector3(-1400.0, 37.4, 4778.4),
		Vector3(-1200.0, 37.4, 4730.0), Vector3(-1000.0, 40.4, 4668.6),
		Vector3(-800.0, 41.5, 4611.7), Vector3(-600.0, 40.9, 4608.4),
		Vector3(-400.0, 40.4, 4606.3), Vector3(-200.0, 39.5, 4615.7),
		Vector3(0.0, 37.7, 4655.9), Vector3(200.0, 36.0, 4696.1),
		Vector3(400.0, 35.3, 4740.5), Vector3(600.0, 36.3, 4792.7),
		Vector3(800.0, 37.3, 4844.8), Vector3(1000.0, 38.2, 4897.8),
		Vector3(1200.0, 38.5, 4956.8), Vector3(1400.0, 38.9, 5016.0),
		Vector3(1600.0, 38.7, 5073.4), Vector3(1800.0, 38.4, 5118.9),
		Vector3(2000.0, 37.9, 5148.5), Vector3(2200.0, 37.4, 5178.2)
	]


static func defense_bank_points() -> Array[Vector2]:
	# Northern shoreline of the same Danube_OSM mesh, offset onto dry land.
	return [
		Vector2(200.0, 4576.0), Vector2(400.0, 4618.9),
		Vector2(600.0, 4671.0), Vector2(800.0, 4723.2),
		Vector2(1000.0, 4775.3), Vector2(1200.0, 4834.1),
		Vector2(1400.0, 4893.3), Vector2(1600.0, 4951.3),
		Vector2(1800.0, 4999.8), Vector2(2000.0, 5029.5),
		Vector2(2200.0, 5059.3)
	]


static func build_route(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Danube_OSM_Exact_Ship_Route"
	parent.add_child(root)
	var path := Path3D.new()
	path.name = "InvaderShipPath3D"
	path.curve = Curve3D.new()
	path.curve.bake_interval = 8.0
	for point in route_points():
		path.curve.add_point(point)
	root.add_child(path)
	root.set_meta("source", "Danube_OSM mesh centreline")
	root.set_meta("route_length", path.curve.get_baked_length())
	return root


func setup(terrain_root: Node3D, active_camera: Camera3D) -> void:
	sampler = TerrainSurface.new(terrain_root)
	camera = active_camera
	var route_root := build_route(self)
	route_curve = (route_root.get_node("InvaderShipPath3D") as Path3D).curve
	_build_fortified_embankment()
	_build_hud()
	_spawn_initial_fleet()
	_update_hud()


func _process(delta: float) -> void:
	if route_curve == null:
		return
	_update_ships(delta)
	_update_batteries(delta)
	_update_projectiles(delta)
	respawn_timer -= delta
	if ships.size() < MAX_SHIPS and respawn_timer <= 0.0:
		_spawn_ship(0.0)
		respawn_timer = 3.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_upgrade_click(event.position)


func _spawn_initial_fleet() -> void:
	var length := route_curve.get_baked_length()
	var progresses := [0.0, length * 0.44, length * 0.66, length * 0.78, length * 0.86, length * 0.92, length * 0.96]
	for progress in progresses:
		_spawn_ship(float(progress))


func _spawn_ship(progress: float) -> void:
	var ship := SHIP_SCENE.instantiate() as Node3D
	ship.name = "InvaderShip_%02d" % next_ship_id
	ship.scale = Vector3.ONE * SHIP_SCALE
	add_child(ship)

	var bar := Label3D.new()
	bar.name = "ShipHealth_%02d" % next_ship_id
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.fixed_size = true
	bar.font_size = 18
	bar.outline_size = 5
	bar.no_depth_test = true
	add_child(bar)

	var max_hp := 140.0 + float((next_ship_id - 1) % 4) * 25.0
	ships.append({
		"root": ship, "bar": bar, "progress": progress,
		"speed": SHIP_SPEED * (0.94 + float(next_ship_id % 3) * 0.04),
		"hp": max_hp, "max_hp": max_hp, "id": next_ship_id
	})
	next_ship_id += 1
	_place_ship(ships[-1])
	_update_health_bar(ships[-1])


func _place_ship(ship_data: Dictionary) -> void:
	var ship := ship_data["root"] as Node3D
	var bar := ship_data["bar"] as Label3D
	var progress := float(ship_data["progress"])
	var length := route_curve.get_baked_length()
	var p := route_curve.sample_baked(clampf(progress, 0.0, length), true)
	var ahead := route_curve.sample_baked(clampf(progress + 20.0, 0.0, length), true)
	ship.global_position = p
	if p.distance_to(ahead) > 0.1:
		ship.look_at(ahead, Vector3.UP)
		ship.rotate_y(PI)
	bar.global_position = p + Vector3(0.0, 55.0, 0.0)


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
			reached_city += 1
			_remove_ship(i, false)
			_update_hud()
			continue
		ships[i] = ship_data
		_place_ship(ship_data)


func _build_fortified_embankment() -> void:
	var bank := defense_bank_points()
	for segment_index in range(bank.size() - 1):
		var a := bank[segment_index]
		var b := bank[segment_index + 1]
		var length := a.distance_to(b)
		var pieces := maxi(1, ceili(length / 24.0))
		var piece_length := length / float(pieces)
		for j in range(pieces):
			var p := a.lerp(b, (float(j) + 0.5) / float(pieces))
			var wall := WALL_SCENE.instantiate() as Node3D
			wall.name = "ContinuousRiverWall_%02d_%02d" % [segment_index, j]
			wall.scale = Vector3(piece_length / 2.0, 4.6, 4.6)
			add_child(wall)
			wall.global_position = Vector3(p.x, float(sampler.height_world_at(p.x, p.y)) + 4.5, p.y)
			wall.rotation.y = -atan2(b.y - a.y, b.x - a.x)

	var tower_indices := [1, 3, 5, 7, 9, 10]
	for i in range(tower_indices.size()):
		var bank_index: int = tower_indices[i]
		var shore := bank[bank_index]
		var previous := bank[maxi(0, bank_index - 1)]
		var next := bank[mini(bank.size() - 1, bank_index + 1)]
		var tangent := (next - previous).normalized()
		var land_normal := Vector2(tangent.y, -tangent.x)
		if land_normal.y > 0.0:
			land_normal = -land_normal
		var p := shore + land_normal * 24.0
		_build_battery(i, p)


func _build_battery(index: int, p: Vector2) -> void:
	var ground: float = float(sampler.height_world_at(p.x, p.y))
	var root := Node3D.new()
	root.name = "UpgradeableRiverBattery_%02d" % (index + 1)
	add_child(root)
	root.global_position = Vector3(p.x, ground, p.y)

	var tower := TOWER_SCENE.instantiate() as Node3D
	tower.name = "Watchtower"
	tower.scale = Vector3.ONE * 6.0
	tower.position.y = 6.0
	root.add_child(tower)

	var cannon_root := Node3D.new()
	cannon_root.name = "Cannons"
	root.add_child(cannon_root)
	_add_cannon(cannon_root, Vector3(0.0, 4.4, 18.0))

	var level_label := Label3D.new()
	level_label.name = "UpgradeLabel"
	level_label.text = "BATTERY LV 1\nCLICK TO UPGRADE"
	level_label.position = Vector3(0.0, 30.0, 0.0)
	level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_label.fixed_size = true
	level_label.font_size = 14
	level_label.outline_size = 4
	level_label.no_depth_test = true
	level_label.modulate = Color("#ffe091")
	root.add_child(level_label)

	batteries.append({
		"root": root, "tower": tower, "cannon_root": cannon_root,
		"label": level_label, "level": 1,
		"cooldown": 0.4 + float(index) * 0.18
	})


func _add_cannon(parent: Node3D, local_position: Vector3) -> Node3D:
	var cannon := CANNON_SCENE.instantiate() as Node3D
	cannon.scale = Vector3.ONE * 4.0
	cannon.position = local_position
	cannon.rotation.y = PI
	parent.add_child(cannon)
	return cannon


func _handle_upgrade_click(mouse_pos: Vector2) -> void:
	if camera == null:
		return
	var selected := -1
	var best_distance := 54.0
	for i in range(batteries.size()):
		var battery: Dictionary = batteries[i]
		var root := battery["root"] as Node3D
		if camera.is_position_behind(root.global_position):
			continue
		var screen := camera.unproject_position(root.global_position + Vector3(0.0, 22.0, 0.0))
		var distance := screen.distance_to(mouse_pos)
		if distance < best_distance:
			best_distance = distance
			selected = i
	if selected >= 0:
		_upgrade_battery(selected)


func _upgrade_battery(index: int) -> void:
	var battery: Dictionary = batteries[index]
	var level := int(battery["level"])
	if level >= 5:
		_show_message("Battery is already level 5")
		return
	var cost := 80 + level * 70
	if gold < cost:
		_show_message("Need %d gold for level %d" % [cost, level + 1])
		return
	gold -= cost
	level += 1
	battery["level"] = level
	var tower := battery["tower"] as Node3D
	tower.scale = Vector3.ONE * (6.0 + float(level - 1) * 0.55)
	var cannon_root := battery["cannon_root"] as Node3D
	var offsets := [-9.0, 9.0, -18.0, 18.0]
	_add_cannon(cannon_root, Vector3(offsets[level - 2], 4.4, 18.0))
	var label := battery["label"] as Label3D
	label.text = "BATTERY LV %d\nDAMAGE %d" % [level, 28 + level * 18]
	label.modulate = Color("#9dff9d")
	batteries[index] = battery
	_show_message("Battery upgraded to level %d" % level)
	_update_hud()


func _update_batteries(delta: float) -> void:
	for i in range(batteries.size()):
		var battery: Dictionary = batteries[i]
		battery["cooldown"] = float(battery["cooldown"]) - delta
		if float(battery["cooldown"]) <= 0.0:
			var root := battery["root"] as Node3D
			var target := _nearest_ship(root.global_position, 950.0)
			if target != null:
				var cannon_root := battery["cannon_root"] as Node3D
				cannon_root.look_at(target.global_position, Vector3.UP)
				cannon_root.rotate_y(PI)
				_fire(root, target, int(battery["level"]))
				battery["cooldown"] = maxf(0.75, 2.7 - float(battery["level"]) * 0.32)
			else:
				battery["cooldown"] = 0.35
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


func _fire(battery_root: Node3D, target: Node3D, level: int) -> void:
	var ball := MeshInstance3D.new()
	ball.name = "Cannonball"
	var sphere := SphereMesh.new()
	sphere.radius = 1.25
	sphere.height = 2.5
	ball.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#201c19")
	material.metallic = 0.7
	material.roughness = 0.45
	ball.material_override = material
	add_child(ball)
	ball.global_position = battery_root.global_position + Vector3(0.0, 11.0, 12.0)
	projectiles.append({
		"root": ball, "start": ball.global_position, "target": target,
		"damage": 28.0 + float(level) * 18.0, "time": 0.0,
		"duration": maxf(0.35, ball.global_position.distance_to(target.global_position) / 470.0)
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
		position.y += sin(t * PI) * 65.0
		ball.global_position = position
		projectiles[i] = shot
		if t >= 1.0:
			_damage_ship(target, float(shot["damage"]))
			ball.queue_free()
			projectiles.remove_at(i)


func _damage_ship(target: Node3D, damage: float) -> void:
	for i in range(ships.size()):
		var ship_data: Dictionary = ships[i]
		if ship_data["root"] != target:
			continue
		ship_data["hp"] = maxf(0.0, float(ship_data["hp"]) - damage)
		ships[i] = ship_data
		_update_health_bar(ship_data)
		if float(ship_data["hp"]) <= 0.0:
			_destroy_ship(i)
		return


func _update_health_bar(ship_data: Dictionary) -> void:
	var bar := ship_data["bar"] as Label3D
	if not is_instance_valid(bar):
		return
	var ratio := clampf(float(ship_data["hp"]) / float(ship_data["max_hp"]), 0.0, 1.0)
	var filled := int(round(ratio * 10.0))
	bar.text = "SHIP %d  %d%%\n%s%s" % [
		int(ship_data["id"]), int(round(ratio * 100.0)),
		"█".repeat(filled), "░".repeat(10 - filled)
	]
	if ratio > 0.6:
		bar.modulate = Color("#74ff72")
	elif ratio > 0.3:
		bar.modulate = Color("#ffd25f")
	else:
		bar.modulate = Color("#ff665e")


func _destroy_ship(index: int) -> void:
	var ship_data: Dictionary = ships[index]
	var ship := ship_data["root"] as Node3D
	_create_explosion(ship.global_position + Vector3(0.0, 10.0, 0.0))
	destroyed += 1
	gold += 75
	_remove_ship(index, true)
	_show_message("Ship destroyed — +75 gold")
	_update_hud()


func _remove_ship(index: int, was_destroyed: bool) -> void:
	var ship_data: Dictionary = ships[index]
	var ship := ship_data["root"] as Node3D
	var bar := ship_data["bar"] as Label3D
	if is_instance_valid(ship):
		ship.queue_free()
	if is_instance_valid(bar):
		bar.queue_free()
	ships.remove_at(index)
	respawn_timer = 2.6 if was_destroyed else 1.2


func _create_explosion(position: Vector3) -> void:
	var blast := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 5.0
	sphere.height = 10.0
	blast.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ff7a28")
	material.emission_enabled = true
	material.emission = Color("#ff3b12")
	material.emission_energy_multiplier = 5.0
	blast.material_override = material
	add_child(blast)
	blast.global_position = position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(blast, "scale", Vector3.ONE * 7.0, 0.55)
	tween.tween_property(blast, "transparency", 1.0, 0.55)
	tween.chain().tween_callback(blast.queue_free)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RiverSiegeHUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(930.0, 18.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 16)
	box.add_child(hud)
	message = Label.new()
	message.text = "Click a riverside battery to upgrade it"
	message.add_theme_font_size_override("font_size", 13)
	message.modulate = Color("#ffe091")
	box.add_child(message)


func _update_hud() -> void:
	if hud != null:
		hud.text = "RIVER DEFENSE\nGold: %d\nShips destroyed: %d\nReached Bratislava: %d" % [gold, destroyed, reached_city]


func _show_message(text_value: String) -> void:
	if message == null:
		return
	message.text = text_value
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_callback(func(): message.text = "Click a riverside battery to upgrade it")
