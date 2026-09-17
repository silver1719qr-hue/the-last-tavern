extends Node3D

var player: CharacterBody3D
var base_hp: int = 300
var gold: int = 220
var wave: int = 0
var enemies_left: int = 0
var wave_active: bool = false
var next_wave_scheduled: bool = false

var hud_label: Label
var prompt_label: Label
var wave_banner: Label
var enemy_root: Node3D
var tower_root: Node3D
var spawn_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var command_ladder_pos := Vector3(6.4, 1.0, 7.0)
var command_top_pos := Vector3(0.0, 11.6, 3.0)

func _ready() -> void:
	setup_input_actions()
	rng.randomize()
	build_world()
	build_hud()
	spawn_player()
	call_deferred("schedule_first_wave")

func setup_input_actions() -> void:
	bind_key("move_forward", KEY_W)
	bind_key("move_back", KEY_S)
	bind_key("move_left", KEY_A)
	bind_key("move_right", KEY_D)
	bind_key("sprint", KEY_SHIFT)
	bind_key("interact", KEY_E)
	bind_key("toggle_camera", KEY_V)
	bind_key("overview", KEY_C)
	bind_key("ui_cancel", KEY_ESCAPE)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	if InputMap.action_get_events("attack").is_empty():
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mouse_event)

func bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action, key_event)

func mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func box_obj(name: String, pos: Vector3, size: Vector3, color: Color, parent: Node = self, collision: bool = true) -> Node3D:
	var body: Node3D
	if collision:
		body = StaticBody3D.new()
	else:
		body = Node3D.new()
	body.name = name
	parent.add_child(body)
	body.position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat(color)
	body.add_child(mesh)

	if collision:
		var collision_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision_shape.shape = shape
		body.add_child(collision_shape)
	return body

func cyl_obj(name: String, pos: Vector3, radius: float, height: float, color: Color, parent: Node = self, collision: bool = true) -> Node3D:
	var body: Node3D
	if collision:
		body = StaticBody3D.new()
	else:
		body = Node3D.new()
	body.name = name
	parent.add_child(body)
	body.position = pos

	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh.mesh = cylinder
	mesh.material_override = mat(color)
	body.add_child(mesh)

	if collision:
		var collision_shape := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision_shape.shape = shape
		body.add_child(collision_shape)
	return body

func build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("92b6c7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfd7c6")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	box_obj("Ground", Vector3(0, -0.5, 0), Vector3(140, 1, 140), Color("4e6b3a"), self, true)
	box_obj("RoadN", Vector3(0, 0.02, -42), Vector3(9, 0.08, 52), Color("765b3c"), self, false)
	box_obj("RoadE", Vector3(42, 0.02, 0), Vector3(52, 0.08, 9), Color("765b3c"), self, false)
	box_obj("RoadW", Vector3(-42, 0.02, 0), Vector3(52, 0.08, 9), Color("765b3c"), self, false)
	spawn_points = [Vector3(0, 1, -67), Vector3(67, 1, 0), Vector3(-67, 1, 0)]

	build_tavern_and_command_deck()
	build_palisade()

	tower_root = Node3D.new()
	tower_root.name = "TowerSites"
	add_child(tower_root)
	for pos in [Vector3(-16, 0, -14), Vector3(16, 0, -14), Vector3(-16, 0, 14), Vector3(16, 0, 14)]:
		build_tower_site(pos)

	for i in range(95):
		var angle := rng.randf_range(0, TAU)
		var radius := rng.randf_range(28, 66)
		var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if abs(pos.x) < 8 or abs(pos.z) < 8:
			continue
		build_tree(pos, rng.randf_range(0.8, 1.35))

	for i in range(28):
		var angle := rng.randf_range(0, TAU)
		var radius := rng.randf_range(35, 64)
		var pos := Vector3(cos(angle) * radius, 0.4, sin(angle) * radius)
		build_rock(pos, rng.randf_range(0.9, 2.1))

	for pos in [Vector3(-55, 8, -55), Vector3(55, 10, -56), Vector3(-58, 9, 55), Vector3(59, 12, 51)]:
		var mountain := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 12
		sphere.height = 28
		mountain.mesh = sphere
		mountain.scale = Vector3(1.8, 1.0, 1.3)
		mountain.position = pos
		mountain.material_override = mat(Color("59635d"))
		add_child(mountain)

	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)

func build_tavern_and_command_deck() -> void:
	box_obj("Tavern", Vector3(0, 2.5, 3), Vector3(14, 5, 10), Color("7b4a2d"))
	box_obj("TavernUpper", Vector3(0, 6, 3), Vector3(11, 2.2, 8), Color("d0ad75"))

	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(16, 5, 12)
	roof.mesh = prism
	roof.material_override = mat(Color("4a2b22"))
	roof.position = Vector3(0, 8, 3)
	roof.rotation_degrees = Vector3(0, 0, 90)
	add_child(roof)
	box_obj("Door", Vector3(0, 1.6, -2.03), Vector3(2.2, 3.2, 0.25), Color("38241d"), self, false)

	box_obj("CommandDeck", Vector3(0, 10.6, 3), Vector3(12.5, 0.55, 8.5), Color("765031"), self, true)
	for x in [-5.7, 5.7]:
		box_obj("CommandRail", Vector3(x, 11.55, 3), Vector3(0.25, 1.7, 8.0), Color("51341f"), self, false)
	for z in [-0.6, 6.6]:
		box_obj("CommandRail", Vector3(0, 11.55, z), Vector3(11.5, 1.7, 0.25), Color("51341f"), self, false)

	box_obj("LadderLeft", Vector3(6.55, 4.8, 7.0), Vector3(0.18, 8.0, 0.18), Color("8a6339"), self, false)
	box_obj("LadderRight", Vector3(7.25, 4.8, 7.0), Vector3(0.18, 8.0, 0.18), Color("8a6339"), self, false)
	for y in range(1, 9):
		box_obj("LadderStep", Vector3(6.9, float(y), 7.0), Vector3(0.9, 0.12, 0.18), Color("9b7144"), self, false)

	box_obj("CommandTable", Vector3(0, 11.35, 3.0), Vector3(3.0, 0.25, 1.5), Color("4f3524"), self, false)
	box_obj("CommandSeat", Vector3(0, 11.25, 5.1), Vector3(1.2, 0.7, 1.2), Color("3f2b20"), self, false)

	var beacon := OmniLight3D.new()
	beacon.light_color = Color("ffd58a")
	beacon.light_energy = 2.2
	beacon.omni_range = 12.0
	beacon.position = Vector3(0, 12.5, 3)
	add_child(beacon)

func build_palisade() -> void:
	for x in range(-20, 21, 2):
		if abs(x) > 4:
			cyl_obj("Stake", Vector3(x, 2.2, -18), 0.45, 4.4, Color("6b452b"))
		cyl_obj("Stake", Vector3(x, 2.2, 18), 0.45, 4.4, Color("6b452b"))
	for z in range(-16, 17, 2):
		cyl_obj("Stake", Vector3(-20, 2.2, z), 0.45, 4.4, Color("6b452b"))
		cyl_obj("Stake", Vector3(20, 2.2, z), 0.45, 4.4, Color("6b452b"))
	box_obj("GateL", Vector3(-4, 3, -18), Vector3(1.4, 6, 1.4), Color("51341f"))
	box_obj("GateR", Vector3(4, 3, -18), Vector3(1.4, 6, 1.4), Color("51341f"))

func build_tree(pos: Vector3, scale_factor: float) -> void:
	cyl_obj("TreeTrunk", pos + Vector3(0, 2 * scale_factor, 0), 0.45 * scale_factor, 4 * scale_factor, Color("5a3c24"), self, true)
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.3 * scale_factor
	sphere.height = 4.6 * scale_factor
	crown.mesh = sphere
	crown.position = pos + Vector3(0, 5 * scale_factor, 0)
	crown.material_override = mat(Color("315f38"))
	add_child(crown)

func build_rock(pos: Vector3, scale_factor: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5 * scale_factor
	sphere.height = 2.0 * scale_factor
	mesh.mesh = sphere
	mesh.scale = Vector3(1.4, 0.8, 1.0)
	mesh.material_override = mat(Color("6d706b"))
	body.add_child(mesh)
	var collision_shape := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.4 * scale_factor
	collision_shape.shape = shape
	body.add_child(collision_shape)

func build_tower_site(pos: Vector3) -> void:
	var tower := Node3D.new()
	tower.name = "WatchtowerSite"
	tower.set_script(load("res://scripts/tower.gd"))
	tower.position = pos
	tower_root.add_child(tower)

func spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0, 1, 11)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.8
	collision.shape = shape
	player.add_child(collision)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.55
	capsule.height = 1.8
	body.mesh = capsule
	body.material_override = mat(Color("b7bec7"), 0.45, 0.1)
	player.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.42
	head_mesh.height = 0.84
	head.mesh = head_mesh
	head.position = Vector3(0, 1.25, 0)
	head.material_override = mat(Color("d6b08b"))
	player.add_child(head)

	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.5, 0)
	player.add_child(camera_pivot)

	var spring_arm := SpringArm3D.new()
	spring_arm.name = "SpringArm"
	spring_arm.spring_length = 5.2
	spring_arm.collision_mask = 1
	camera_pivot.add_child(spring_arm)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	spring_arm.add_child(camera)

	player.set("main_ref", self)
	add_child(player)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.48)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(420, 96)
	layer.add_child(panel)

	hud_label = Label.new()
	hud_label.position = Vector2(34, 30)
	hud_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud_label)

	wave_banner = Label.new()
	wave_banner.position = Vector2(300, 120)
	wave_banner.size = Vector2(680, 110)
	wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_banner.add_theme_font_size_override("font_size", 38)
	wave_banner.add_theme_color_override("font_color", Color("fff1c1"))
	wave_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	wave_banner.add_theme_constant_override("shadow_offset_x", 3)
	wave_banner.add_theme_constant_override("shadow_offset_y", 3)
	layer.add_child(wave_banner)

	prompt_label = Label.new()
	prompt_label.position = Vector2(330, 620)
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.size = Vector2(620, 42)
	layer.add_child(prompt_label)

	var help := Label.new()
	help.text = "WASD move  |  Shift sprint  |  Mouse look  |  LMB attack  |  E interact/build  |  V camera  |  C overview on command deck  |  Esc cursor"
	help.position = Vector2(20, 690)
	help.add_theme_font_size_override("font_size", 15)
	layer.add_child(help)

	update_hud()

func update_hud() -> void:
	if hud_label != null:
		hud_label.text = "THE LAST TAVERN\nBase %d HP    Gold %d    Wave %d    Enemies %d" % [base_hp, gold, wave, enemies_left]

func schedule_first_wave() -> void:
	wave_banner.text = "Prepare the defenses"
	await get_tree().create_timer(4.0).timeout
	start_wave()

func start_wave() -> void:
	if wave_active or next_wave_scheduled or base_hp <= 0:
		return
	wave_active = true
	wave += 1
	update_hud()

	var is_boss_wave := wave % 5 == 0
	for countdown in [3, 2, 1]:
		if is_boss_wave:
			wave_banner.text = "BOSS WAVE %d\nBegins in %d" % [wave, countdown]
		else:
			wave_banner.text = "WAVE %d\nBegins in %d" % [wave, countdown]
		await get_tree().create_timer(1.0).timeout

	wave_banner.text = "BOSS WAVE %d" % wave if is_boss_wave else "WAVE %d" % wave
	await get_tree().create_timer(1.2).timeout
	wave_banner.text = ""

	var count := 5 + wave * 2
	for i in range(count):
		spawn_enemy(spawn_points[i % spawn_points.size()], false)
		await get_tree().create_timer(max(0.28, 0.62 - float(wave) * 0.012)).timeout

	if is_boss_wave:
		spawn_enemy(spawn_points[wave % spawn_points.size()], true)
		wave_banner.text = "BOSS HAS ENTERED THE BATTLE"
		await get_tree().create_timer(2.2).timeout
		wave_banner.text = ""

	wave_active = false
	if enemies_left == 0:
		schedule_next_wave()

func spawn_enemy(pos: Vector3, boss: bool = false) -> void:
	var enemy := CharacterBody3D.new()
	enemy.name = "Boss" if boss else "Raider"
	enemy.set_script(load("res://scripts/enemy.gd"))
	enemy.position = pos

	var collision_shape := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.0 if boss else 0.55
	shape.height = 3.2 if boss else 1.8
	collision_shape.shape = shape
	enemy.add_child(collision_shape)

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = shape.radius
	capsule.height = shape.height
	mesh.mesh = capsule
	mesh.material_override = mat(Color("3a171b") if boss else Color("7d3540"), 0.7, 0.05)
	enemy.add_child(mesh)

	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.42 if not boss else 0.75
	marker_mesh.height = marker_mesh.radius * 2.0
	marker.mesh = marker_mesh
	marker.position = Vector3(0, 1.65 if not boss else 2.8, 0)
	marker.material_override = mat(Color("ffcf67") if boss else Color("d6d6d6"), 0.55, 0.1)
	enemy.add_child(marker)

	enemy.set("main_ref", self)
	enemy.set("target_pos", Vector3(0, 0, -14))
	enemy.set("hp", 280 + wave * 25 if boss else 35 + wave * 9)
	enemy.set("speed", 2.0 if boss else 3.2)
	enemy.set("damage", 35 if boss else 8 + wave)
	enemy.set("reward", 70 if boss else 12)
	enemy_root.add_child(enemy)
	enemies_left += 1
	update_hud()

func enemy_died(reward: int) -> void:
	enemies_left = max(0, enemies_left - 1)
	gold += reward
	update_hud()
	if enemies_left == 0 and not wave_active:
		schedule_next_wave()

func schedule_next_wave() -> void:
	if next_wave_scheduled or base_hp <= 0:
		return
	next_wave_scheduled = true
	wave_banner.text = "WAVE CLEARED\nNext assault in 6 seconds"
	await get_tree().create_timer(6.0).timeout
	wave_banner.text = ""
	next_wave_scheduled = false
	start_wave()

func damage_base(amount: int) -> void:
	base_hp = max(0, base_hp - amount)
	update_hud()
	if base_hp <= 0:
		wave_banner.text = "THE TAVERN HAS FALLEN"
		prompt_label.text = "Press Esc to release the cursor."

func get_command_interaction(player_pos: Vector3) -> Dictionary:
	if player_pos.distance_to(command_ladder_pos) < 3.0:
		return {
			"kind": "climb",
			"text": "E — climb to the command deck"
		}
	if is_player_on_command_deck(player_pos) and player_pos.distance_to(command_top_pos) < 7.0:
		return {
			"kind": "descend",
			"text": "E — descend from command deck   |   C — tactical overview"
		}
	return {}

func use_command_interaction(player_node: CharacterBody3D, info: Dictionary) -> void:
	var kind: String = info.get("kind", "")
	if kind == "climb":
		player_node.global_position = command_top_pos
		player_node.velocity = Vector3.ZERO
		prompt_label.text = "Command deck: press C for tactical overview."
	elif kind == "descend":
		player_node.global_position = command_ladder_pos + Vector3(-1.0, 0.2, 0.0)
		player_node.velocity = Vector3.ZERO
		if bool(player_node.get("overview_mode")) and player_node.has_method("toggle_overview"):
			player_node.toggle_overview()

func is_player_on_command_deck(player_pos: Vector3) -> bool:
	return player_pos.y > 9.5 and abs(player_pos.x) < 7.5 and player_pos.z > -2.0 and player_pos.z < 8.5