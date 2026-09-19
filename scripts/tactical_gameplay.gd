extends Node3D

const TerrainSurface = preload("res://scripts/terrain_surface.gd")

var terrain_root: Node3D
var route_root: Node3D
var camera: Camera3D
var sampler

var tower_sites: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []

var gold := 320
var wave := 0
var base_hp := 20
var wave_active := false
var spawn_queue := 0
var spawn_timer := 0.0
var next_wave_timer := 2.0

var hud: Label
var message: Label
var wave_label: Label
var route_curve: Curve3D


func setup(p_terrain_root: Node3D, p_route_root: Node3D, p_camera: Camera3D) -> void:
	terrain_root = p_terrain_root
	route_root = p_route_root
	camera = p_camera
	sampler = TerrainSurface.new(terrain_root)
	var path := route_root.get_node("EnemyPath3D") as Path3D
	route_curve = path.curve
	_build_tower_sites()
	_build_ui()
	_update_ui()


func _process(delta: float) -> void:
	if route_curve == null:
		return
	_update_wave(delta)
	_update_enemies(delta)
	_update_towers(delta)
	_update_projectiles(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)


func _handle_click(mouse_pos: Vector2) -> void:
	if camera == null:
		return
	var best_index := -1
	var best_distance := 42.0
	for i in range(tower_sites.size()):
		var site: Dictionary = tower_sites[i]
		var root := site["root"] as Node3D
		if not camera.is_position_behind(root.global_position):
			var screen := camera.unproject_position(root.global_position + Vector3(0, 3.0, 0))
			var d := screen.distance_to(mouse_pos)
			if d < best_distance:
				best_distance = d
				best_index = i
	if best_index >= 0:
		_build_or_upgrade(best_index)


func _build_tower_sites() -> void:
	var positions := [
		Vector2(2208.0, 5000.0), Vector2(2328.0, 4992.0),
		Vector2(2212.0, 4924.0), Vector2(2360.0, 4908.0),
		Vector2(2220.0, 4845.0), Vector2(2390.0, 4828.0),
		Vector2(2240.0, 4768.0), Vector2(2370.0, 4748.0)
	]
	for i in range(positions.size()):
		var p: Vector2 = positions[i]
		var y: float = float(sampler.height_world_at(p.x, p.y)) + 0.65
		var root := Node3D.new()
		root.name = "TowerSite_%02d" % (i + 1)
		root.global_position = Vector3(p.x, y, p.y)
		add_child(root)
		_build_site_pad(root)
		tower_sites.append({
			"root": root,
			"built": false,
			"level": 0,
			"cooldown": 0.0,
			"visual": null,
			"range": 115.0
		})


func _build_site_pad(root: Node3D) -> void:
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 8.0
	mesh.bottom_radius = 8.8
	mesh.height = 0.7
	mesh.radial_segments = 24
	base.mesh = mesh
	base.position.y = 0.35
	base.material_override = _mat(Color("#6a665d"), 0.98)
	root.add_child(base)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 5.4
	ring_mesh.outer_radius = 6.2
	ring.mesh = ring_mesh
	ring.position.y = 0.78
	ring.material_override = _emissive(Color("#d7aa55"), 1.8)
	root.add_child(ring)

	var marker := Label3D.new()
	marker.text = "BUILD"
	marker.position = Vector3(0, 4.8, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.fixed_size = true
	marker.font_size = 18
	marker.outline_size = 4
	marker.modulate = Color("#ffe5a3")
	root.add_child(marker)
	root.set_meta("marker", marker)


func _build_or_upgrade(index: int) -> void:
	var site: Dictionary = tower_sites[index]
	if not bool(site["built"]):
		if gold < 80:
			_show_message("Not enough gold — tower costs 80")
			return
		gold -= 80
		site["built"] = true
		site["level"] = 1
		var root := site["root"] as Node3D
		var visual := _build_stone_tower(root)
		site["visual"] = visual
		var marker = root.get_meta("marker")
		if marker is Label3D:
			marker.text = "LV 1"
			marker.modulate = Color("#bfe8b0")
		tower_sites[index] = site
		_show_message("Tower built — click it again to upgrade")
	else:
		var level := int(site["level"])
		if level >= 5:
			_show_message("Tower is already level 5")
			return
		var cost := 55 + level * 35
		if gold < cost:
			_show_message("Need %d gold for upgrade" % cost)
			return
		gold -= cost
		level += 1
		site["level"] = level
		site["range"] = 115.0 + float(level - 1) * 12.0
		var visual := site["visual"] as Node3D
		if visual != null:
			visual.scale = Vector3.ONE * (1.0 + float(level - 1) * 0.055)
		var root := site["root"] as Node3D
		var marker = root.get_meta("marker")
		if marker is Label3D:
			marker.text = "LV %d" % level
		tower_sites[index] = site
		_show_message("Tower upgraded to level %d" % level)
	_update_ui()


func _build_stone_tower(root: Node3D) -> Node3D:
	var visual := Node3D.new()
	visual.name = "BuiltStoneTower"
	root.add_child(visual)

	var stone := _mat(Color("#8b877c"), 0.97)
	var dark_stone := _mat(Color("#615f59"), 1.0)
	var wood := _mat(Color("#4a3526"), 0.95)

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 4.4
	body_mesh.bottom_radius = 5.7
	body_mesh.height = 13.0
	body_mesh.radial_segments = 16
	body.mesh = body_mesh
	body.position.y = 7.0
	body.material_override = stone
	visual.add_child(body)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 6.3
	platform_mesh.bottom_radius = 6.3
	platform_mesh.height = 1.0
	platform_mesh.radial_segments = 16
	platform.mesh = platform_mesh
	platform.position.y = 13.7
	platform.material_override = dark_stone
	visual.add_child(platform)

	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var merlon := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.5, 2.3, 1.5)
		merlon.mesh = box
		merlon.position = Vector3(cos(angle) * 5.35, 15.2, sin(angle) * 5.35)
		merlon.material_override = stone
		visual.add_child(merlon)

	var roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 4.2
	roof_mesh.height = 4.2
	roof_mesh.radial_segments = 8
	roof.mesh = roof_mesh
	roof.position.y = 18.0
	roof.material_override = _mat(Color("#5b3028"), 0.9)
	visual.add_child(roof)

	var crossbow := Node3D.new()
	crossbow.name = "TurretHead"
	crossbow.position = Vector3(0, 15.8, 0)
	visual.add_child(crossbow)

	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.6, 0.6, 5.6)
	beam.mesh = beam_mesh
	beam.position = Vector3(0, 0, -2.2)
	beam.material_override = wood
	crossbow.add_child(beam)
	visual.set_meta("turret", crossbow)
	return visual


func _update_wave(delta: float) -> void:
	if base_hp <= 0:
		return
	if not wave_active:
		next_wave_timer -= delta
		if next_wave_timer <= 0.0:
			_start_wave()
		return

	if spawn_queue > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_enemy()
			spawn_queue -= 1
			spawn_timer = 0.85

	if spawn_queue == 0 and enemies.is_empty():
		wave_active = false
		next_wave_timer = 5.0
		gold += 35 + wave * 5
		_show_message("Wave %d cleared — bonus gold" % wave)
		_update_ui()


func _start_wave() -> void:
	wave += 1
	wave_active = true
	spawn_queue = 6 + wave * 2
	spawn_timer = 0.2
	wave_label.text = "WAVE %d" % wave
	wave_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_callback(func(): wave_label.visible = false)
	_update_ui()


func _spawn_enemy() -> void:
	var root := Node3D.new()
	root.name = "Enemy"
	add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.15
	capsule.height = 4.6
	mesh_instance.mesh = capsule
	mesh_instance.material_override = _mat(Color("#64342f"), 0.92)
	mesh_instance.position.y = 2.3
	root.add_child(mesh_instance)

	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 1.05
	helmet_mesh.height = 1.5
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0, 4.1, 0)
	helmet.material_override = _mat(Color("#383b3b"), 0.55, 0.45)
	root.add_child(helmet)

	var hp := 45 + wave * 14
	var speed := 21.0 + minf(float(wave) * 0.8, 8.0)
	var first := route_curve.sample_baked(0.0, true)
	root.global_position = first
	enemies.append({
		"root": root,
		"progress": 0.0,
		"speed": speed,
		"hp": hp,
		"max_hp": hp
	})


func _update_enemies(delta: float) -> void:
	var route_length := route_curve.get_baked_length()
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var root := enemy["root"] as Node3D
		if root == null or not is_instance_valid(root):
			enemies.remove_at(i)
			continue
		var progress := float(enemy["progress"]) + float(enemy["speed"]) * delta
		enemy["progress"] = progress
		if progress >= route_length:
			base_hp -= 1
			root.queue_free()
			enemies.remove_at(i)
			_update_ui()
			if base_hp <= 0:
				_show_message("CASTLE LOST — refresh to restart")
			continue
		var pos := route_curve.sample_baked(progress, true)
		var ahead := route_curve.sample_baked(minf(progress + 3.0, route_length), true)
		root.global_position = pos
		var direction := ahead - pos
		direction.y = 0.0
		if direction.length_squared() > 0.01:
			root.look_at(root.global_position + direction.normalized(), Vector3.UP)
		enemies[i] = enemy


func _update_towers(delta: float) -> void:
	for i in range(tower_sites.size()):
		var site: Dictionary = tower_sites[i]
		if not bool(site["built"]):
			continue
		var cooldown := maxf(0.0, float(site["cooldown"]) - delta)
		site["cooldown"] = cooldown
		if cooldown <= 0.0:
			var target_index := _find_target(site)
			if target_index >= 0:
				var level := int(site["level"])
				site["cooldown"] = maxf(0.28, 1.05 - float(level) * 0.12)
				_fire(site, target_index)
		tower_sites[i] = site


func _find_target(site: Dictionary) -> int:
	var root := site["root"] as Node3D
	var best := -1
	var best_progress := -1.0
	var range_value := float(site["range"])
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var enemy_root := enemy["root"] as Node3D
		if enemy_root == null:
			continue
		if root.global_position.distance_to(enemy_root.global_position) <= range_value:
			var p := float(enemy["progress"])
			if p > best_progress:
				best_progress = p
				best = i
	return best


func _fire(site: Dictionary, enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var tower_root := site["root"] as Node3D
	var visual := site["visual"] as Node3D
	var target: Dictionary = enemies[enemy_index]
	var enemy_root := target["root"] as Node3D
	if enemy_root == null:
		return

	if visual != null:
		var turret = visual.get_meta("turret")
		if turret is Node3D:
			var flat := enemy_root.global_position
			flat.y = turret.global_position.y
			turret.look_at(flat, Vector3.UP)

	var shot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	shot.mesh = sphere
	shot.material_override = _emissive(Color("#ffd16b"), 3.0)
	add_child(shot)
	shot.global_position = tower_root.global_position + Vector3(0, 16.0, 0)
	projectiles.append({
		"root": shot,
		"target": enemy_root,
		"enemy_index": enemy_index,
		"damage": 18 + int(site["level"]) * 11,
		"speed": 150.0
	})


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var root := shot["root"] as Node3D
		var target := shot["target"] as Node3D
		if root == null or target == null or not is_instance_valid(root) or not is_instance_valid(target):
			if root != null and is_instance_valid(root):
				root.queue_free()
			projectiles.remove_at(i)
			continue
		var dest := target.global_position + Vector3(0, 2.5, 0)
		var to_target := dest - root.global_position
		var step := float(shot["speed"]) * delta
		if to_target.length() <= step:
			_damage_target(target, int(shot["damage"]))
			root.queue_free()
			projectiles.remove_at(i)
		else:
			root.global_position += to_target.normalized() * step


func _damage_target(target_root: Node3D, damage: int) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if enemy["root"] == target_root:
			var hp := int(enemy["hp"]) - damage
			enemy["hp"] = hp
			if hp <= 0:
				gold += 14 + wave
				target_root.queue_free()
				enemies.remove_at(i)
				_update_ui()
			else:
				enemies[i] = enemy
			return


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(18, 570)
	panel.custom_minimum_size = Vector2(430, 120)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 18)
	box.add_child(hud)

	message = Label.new()
	message.text = "Click a gold BUILD point to construct a tower. Click the built tower again to upgrade it."
	message.add_theme_font_size_override("font_size", 14)
	box.add_child(message)

	wave_label = Label.new()
	wave_label.position = Vector2(535, 80)
	wave_label.add_theme_font_size_override("font_size", 42)
	wave_label.visible = false
	layer.add_child(wave_label)


func _update_ui() -> void:
	if hud == null:
		return
	hud.text = "Gold: %d    Castle: %d/20    Wave: %d    Enemies: %d" % [gold, base_hp, wave, enemies.size() + spawn_queue]


func _show_message(text_value: String) -> void:
	if message != null:
		message.text = text_value


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color, 0.55)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
