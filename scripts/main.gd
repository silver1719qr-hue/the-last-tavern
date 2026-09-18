extends Node3D

var player: CharacterBody3D
var base_hp: int = 500
var base_max_hp: int = 500
var castle_level: int = 1
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

var command_ladder_pos := Vector3(-15.0, 4.0, 8.0)
var command_top_pos := Vector3(0.0, 10.8, 3.0)

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

func box_obj(name: String, pos: Vector3, size: Vector3, color: Color, parent: Node = self, collision: bool = true, rotation_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var body: Node3D
	if collision:
		body = StaticBody3D.new()
	else:
		body = Node3D.new()
	body.name = name
	parent.add_child(body)
	body.position = pos
	body.rotation_degrees = rotation_deg

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


func terrain_height(x: float, z: float) -> float:
	# Broad natural relief. The play area is only a small part of this landscape.
	var base: float = 0.35
	base += sin(x * 0.028) * 1.15
	base += cos(z * 0.021) * 0.85
	base += sin((x + z) * 0.017) * 0.75
	base += cos((x - z) * 0.013) * 0.55

	# Bratislava-inspired castle hill: a broad shoulder, not a box.
	var castle_dist: float = sqrt(pow(x / 58.0, 2.0) + pow((z + 7.0) / 48.0, 2.0))
	var castle_hill: float = 8.0 * exp(-castle_dist * castle_dist * 2.25)
	base += castle_hill

	# Carve the Danube floodplain and channel around z=61.
	var river_dist: float = abs(z - 61.0)
	var valley: float = 6.2 * exp(-pow(river_dist / 29.0, 2.0))
	base -= valley
	if river_dist < 20.5:
		base = minf(base, -1.0 - 0.25 * cos((river_dist / 20.5) * PI))

	# Lower, flatter far bank where the attacking army assembles.
	if z > 87.0:
		base = lerpf(base, 0.25 + sin(x * 0.025) * 0.5, clampf((z - 87.0) / 34.0, 0.0, 1.0))

	# Plateau around the castle so walls sit naturally on the hilltop.
	var plateau_x: float = abs(x)
	var plateau_z: float = abs(z + 2.0)
	if plateau_x < 33.0 and plateau_z < 27.0:
		var edge: float = maxf(plateau_x / 33.0, plateau_z / 27.0)
		var blend: float = 1.0 - smoothstep(0.72, 1.0, edge)
		base = lerpf(base, 3.25, blend)

	# Side ridges frame the panorama.
	var left_ridge: float = 9.0 * exp(-pow((x + 105.0) / 38.0, 2.0) - pow((z + 25.0) / 80.0, 2.0))
	var right_ridge: float = 8.0 * exp(-pow((x - 110.0) / 42.0, 2.0) - pow((z + 35.0) / 85.0, 2.0))
	base += left_ridge + right_ridge
	return base

func build_terrain() -> void:
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "NaturalTerrain"
	add_child(terrain_body)

	var size_x: int = 280
	var size_z: int = 250
	var step: float = 4.0
	var cols: int = int(float(size_x) / step) + 1
	var rows: int = int(float(size_z) / step) + 1
	var start_x: float = -float(size_x) * 0.5
	var start_z: float = -88.0

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for rz in range(rows):
		var z: float = start_z + float(rz) * step
		for cx in range(cols):
			var x: float = start_x + float(cx) * step
			var y: float = terrain_height(x, z)
			vertices.append(Vector3(x, y, z))

			var dx: float = terrain_height(x + 1.0, z) - terrain_height(x - 1.0, z)
			var dz: float = terrain_height(x, z + 1.0) - terrain_height(x, z - 1.0)
			normals.append(Vector3(-dx * 0.5, 1.0, -dz * 0.5).normalized())

			var slope: float = clampf(1.0 - normals[normals.size() - 1].y, 0.0, 1.0)
			var c: Color
			if y < -0.35:
				c = Color("52614a")
			elif slope > 0.20:
				c = Color("6f705f")
			elif y > 5.0:
				c = Color("627548")
			else:
				c = Color("657a4c")
			var variation: float = 0.92 + 0.08 * sin(x * 0.09 + z * 0.06)
			colors.append(Color(c.r * variation, c.g * variation, c.b * variation, 1.0))

	for rz in range(rows - 1):
		for cx in range(cols - 1):
			var a: int = rz * cols + cx
			var b: int = a + 1
			var cidx: int = a + cols
			var d: int = cidx + 1
			indices.append_array(PackedInt32Array([a, cidx, b, b, cidx, d]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = terrain_mesh
	var terrain_material := StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
	mesh_instance.material_override = terrain_material
	terrain_body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(collision)

func build_river() -> void:
	var river := MeshInstance3D.new()
	river.name = "Danube"
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(276, 0.18, 41)
	river.mesh = water_mesh
	river.position = Vector3(0, -0.35, 61)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color("3c718c")
	water_material.roughness = 0.18
	water_material.metallic = 0.16
	water_material.emission_enabled = true
	water_material.emission = Color("173d52")
	water_material.emission_energy_multiplier = 0.18
	river.material_override = water_material
	add_child(river)

func build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b8c5cc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ead9bd")
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("b8c5c8")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0065
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color("ffd2a0")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)

	# One continuous height-field landscape: hills, river valley and castle plateau.
	build_terrain()
	build_river()

	# Main stone bridge: the primary invasion route.
	box_obj("DanubeBridge", Vector3(0, 1.0, 61), Vector3(11, 1, 66), Color("8d8170"), self, true)
	for z in range(34, 92, 8):
		box_obj("BridgePier", Vector3(0, 0.0, float(z)), Vector3(3.8, 3.0, 2.0), Color("70665b"), self, true)
	for side in [-5.0, 5.0]:
		box_obj("BridgeRail", Vector3(side, 2.0, 61), Vector3(0.35, 1.5, 66), Color("756b5f"), self, false)

	# Gentle stone causeway up to the city gate.
	box_obj("CastleCauseway", Vector3(0, 1.8, 27), Vector3(12, 1.1, 30), Color("837560"), self, true, Vector3(-5.5, 0, 0))

	# Historic bridge gate towers.
	for x in [-7.5, 7.5]:
		cyl_obj("BridgeGateTower", Vector3(x, 4.0, 30.5), 3.1, 8.0, Color("918b7f"), self, true)

	# Far-bank invasion camp.
	for p in [Vector3(-18,1.4,99), Vector3(-9,1.4,104), Vector3(10,1.4,101), Vector3(20,1.4,106)]:
		var tent := MeshInstance3D.new()
		var tent_mesh := PrismMesh.new()
		tent_mesh.size = Vector3(7,4,6)
		tent.mesh = tent_mesh
		tent.position = p
		tent.rotation_degrees = Vector3(0,0,90)
		tent.material_override = mat(Color("5e332b"))
		add_child(tent)

	spawn_points = [
		Vector3(-3, terrain_height(-3, 94) + 1.0, 94),
		Vector3(0, terrain_height(0, 98) + 1.0, 98),
		Vector3(3, terrain_height(3, 94) + 1.0, 94)
	]

	build_tavern_and_command_deck()
	build_palisade()

	tower_root = Node3D.new()
	tower_root.name = "CastleTowers"
	add_child(tower_root)
	for pos in [Vector3(-25, 10.0, -20), Vector3(25, 10.0, -20), Vector3(-25, 10.0, 16), Vector3(25, 10.0, 16)]:
		build_tower_site(pos)

	# Old-town houses around the fortress.
	var houses = [Vector3(-43,3,-5),Vector3(-39,3,8),Vector3(-45,3,16),Vector3(41,3,-7),Vector3(45,3,6),Vector3(39,3,15),Vector3(-34,3,-28),Vector3(35,3,-28)]
	for i in range(houses.size()):
		var hp: Vector3 = houses[i]
		var hh: float = 4.5 + float(i % 3)
		box_obj("HistoricHouse", hp + Vector3(0,hh*0.5,0), Vector3(7,hh,6.5), Color("cfba91"), self, true)

	# Church / old-town landmark.
	box_obj("ChurchTower", Vector3(-36,9,-12), Vector3(5,15,5), Color("d9d2c2"), self, true)
	cyl_obj("ChurchSpire", Vector3(-36,19,-12), 0.55, 8.0, Color("405f58"), self, false)

	# Forested hills around the city.
	for i in range(75):
		var angle := rng.randf_range(0, TAU)
		var radius := rng.randf_range(48, 92)
		var tree_x: float = cos(angle) * radius
		var tree_z: float = -8.0 + sin(angle) * radius * 0.65
		var tree_pos := Vector3(tree_x, terrain_height(tree_x, tree_z), tree_z)
		if abs(tree_pos.x) < 34 and tree_pos.z > -38 and tree_pos.z < 28:
			continue
		if tree_pos.z > 34 and abs(tree_pos.x) < 13:
			continue
		build_tree(tree_pos, rng.randf_range(0.75,1.25))

	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)

func build_tavern_and_command_deck() -> void:
	# Bratislava-inspired white castle in the centre of the fortified hill.
	box_obj("CastleMain", Vector3(0,6,-4), Vector3(24,6,18), Color("ded8ca"))
	box_obj("CastleUpper", Vector3(0,9,-4), Vector3(19,2,13), Color("eee9dd"))

	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(21,4,15)
	roof.mesh = prism
	roof.material_override = mat(Color("873a30"))
	roof.position = Vector3(0,11.2,-4)
	roof.rotation_degrees = Vector3(0,0,90)
	add_child(roof)

	for offset in [Vector3(-11.5,0,-8.5),Vector3(11.5,0,-8.5),Vector3(-11.5,0,8.5),Vector3(11.5,0,8.5)]:
		cyl_obj("CastleTurret", Vector3(offset.x,9,-4+offset.z), 2.2, 10, Color("e7e0d2"), self, true)

	# Command terrace: hero starts here and gets the tactical overview.
	box_obj("CommandDeck", Vector3(0,9.55,3), Vector3(13,0.9,10), Color("b0a89a"), self, true)
	box_obj("CommandTable", Vector3(0,10.35,3), Vector3(3.2,0.25,1.6), Color("55402e"), self, false)

	var beacon := OmniLight3D.new()
	beacon.light_color = Color("ffd08a")
	beacon.light_energy = 2.2
	beacon.omni_range = 15
	beacon.position = Vector3(0,12.5,3)
	add_child(beacon)

	# Central banner / upgrade point.
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.12
	pole_mesh.height = 6.5
	pole.mesh = pole_mesh
	pole.position = Vector3(0,13.0,3)
	pole.material_override = mat(Color("363434"),0.6,0.2)
	add_child(pole)
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(3.6,2.0,0.12)
	flag.mesh = flag_mesh
	flag.position = Vector3(1.8,15.0,3)
	flag.material_override = mat(Color("244b78"))
	add_child(flag)

func build_palisade() -> void:
	# Stone walls and continuous walkable parapets.
	box_obj("NorthWall", Vector3(0,6.3,-20), Vector3(50,7,3), Color("89857a"))
	box_obj("SouthWallL", Vector3(-14.5,6.3,16), Vector3(21,7,3), Color("89857a"))
	box_obj("SouthWallR", Vector3(14.5,6.3,16), Vector3(21,7,3), Color("89857a"))
	box_obj("WestWall", Vector3(-25,6.3,-2), Vector3(3,7,36), Color("89857a"))
	box_obj("EastWall", Vector3(25,6.3,-2), Vector3(3,7,36), Color("89857a"))

	box_obj("NorthWalk", Vector3(0,9.55,-20), Vector3(52,0.9,5.2), Color("a09889"))
	box_obj("SouthWalkL", Vector3(-14,9.55,16), Vector3(22,0.9,5.2), Color("a09889"))
	box_obj("SouthWalkR", Vector3(14,9.55,16), Vector3(22,0.9,5.2), Color("a09889"))
	box_obj("WestWalk", Vector3(-25,9.55,-2), Vector3(5.2,0.9,38), Color("a09889"))
	box_obj("EastWalk", Vector3(25,9.55,-2), Vector3(5.2,0.9,38), Color("a09889"))

	# Four round bastions. Their tops line up exactly with the wall walks.
	for p in [Vector3(-25,8,-20),Vector3(25,8,-20),Vector3(-25,8,16),Vector3(25,8,16)]:
		cyl_obj("CornerBastion", p, 5.2, 16, Color("817d73"), self, true)
		cyl_obj("BastionTop", Vector3(p.x,9.55,p.z), 5.5, 0.9, Color("a49c8c"), self, true)

	# Elevated links from the command terrace to every side.
	box_obj("LinkNorth", Vector3(0,9.55,-14), Vector3(5,0.9,12), Color("a09889"))
	box_obj("LinkSouth", Vector3(0,9.55,10), Vector3(5,0.9,12), Color("a09889"))
	box_obj("LinkWest", Vector3(-18,9.55,3), Vector3(16,0.9,5), Color("a09889"))
	box_obj("LinkEast", Vector3(18,9.55,3), Vector3(16,0.9,5), Color("a09889"))

	# South gate facing the Danube bridge.
	box_obj("GateLeft", Vector3(-6.5,6,16), Vector3(5,6,4), Color("77736b"))
	box_obj("GateRight", Vector3(6.5,6,16), Vector3(5,6,4), Color("77736b"))
	box_obj("GateTop", Vector3(0,10.8,16), Vector3(8,2,4), Color("77736b"))

	# Inner access ramp so the hero can leave the walls later.
	box_obj("InnerRamp", Vector3(-15,6.5,8), Vector3(5,1,17), Color("8f8778"), self, true, Vector3(-22,0,0))

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
	player.position = Vector3(0, 11.2, 3)
	player.add_to_group("player")

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
	spring_arm.spring_length = 6.4
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
		hud_label.text = "DEFENCE OF THE DANUBE\nCastle Lv.%d   HP %d/%d   Gold %d   Wave %d   Enemies %d" % [castle_level, base_hp, base_max_hp, gold, wave, enemies_left]

func schedule_first_wave() -> void:
	wave_banner.text = "THE DANUBE BRIDGE IS QUIET\nPrepare the city defenses"
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
			wave_banner.text = "BOSS WAVE %d\nCrossing the Danube in %d" % [wave, countdown]
		else:
			wave_banner.text = "WAVE %d\nEnemy columns approaching the bridge — %d" % [wave, countdown]
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
		wave_banner.text = "WARLORD ON THE BRIDGE!"
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
	enemy.set("target_pos", Vector3(0, 3.4, 11))
	enemy.set("hp", 280 + wave * 25 if boss else 35 + wave * 9)
	enemy.set("speed", 2.0 if boss else 3.2)
	enemy.set("damage", 35 if boss else 8 + wave)
	enemy.set("reward", 70 if boss else 12)
	enemy_root.add_child(enemy)
	enemies_left += 1
	update_hud()

func enemy_died(reward: int) -> void:
	enemies_left = maxi(0, enemies_left - 1)
	gold += reward
	update_hud()
	if enemies_left == 0 and not wave_active:
		schedule_next_wave()

func schedule_next_wave() -> void:
	if next_wave_scheduled or base_hp <= 0:
		return
	next_wave_scheduled = true
	wave_banner.text = "BRIDGE SECURED\nNext assault in 7 seconds"
	await get_tree().create_timer(7.0).timeout
	wave_banner.text = ""
	next_wave_scheduled = false
	start_wave()

func damage_base(amount: int) -> void:
	base_hp = maxi(0, base_hp - amount)
	update_hud()
	if base_hp <= 0:
		wave_banner.text = "BRATISLAVA HAS FALLEN"
		prompt_label.text = "Press Esc to release the cursor."

func get_castle_upgrade_cost() -> int:
	return 180 + castle_level * 120

func get_castle_tower_multiplier() -> float:
	return 1.0 + float(castle_level - 1) * 0.12

func get_command_interaction(player_pos: Vector3) -> Dictionary:
	if player_pos.distance_to(command_top_pos) < 4.5:
		if castle_level >= 6:
			return {
				"kind": "castle_max",
				"text": "Castle level 6 — maximum   |   C — tactical overview"
			}
		var cost: int = get_castle_upgrade_cost()
		return {
			"kind": "castle_upgrade",
			"text": "E — reinforce castle to level %d (%d gold)   |   C — tactical overview" % [castle_level + 1, cost]
		}
	return {}

func use_command_interaction(_player_node: CharacterBody3D, info: Dictionary) -> void:
	var kind: String = str(info.get("kind", ""))
	if kind == "castle_upgrade":
		var cost: int = get_castle_upgrade_cost()
		if gold < cost:
			prompt_label.text = "Need %d gold to reinforce the castle." % cost
			return
		gold -= cost
		castle_level += 1
		base_max_hp += 140
		base_hp = mini(base_max_hp, base_hp + 180)
		update_hud()
		prompt_label.text = "Castle reinforced to level %d. All towers gain strength." % castle_level
	elif kind == "castle_max":
		prompt_label.text = "The castle is already at maximum reinforcement."

func is_player_on_command_deck(player_pos: Vector3) -> bool:
	return player_pos.y > 9.0 and player_pos.distance_to(command_top_pos) < 8.0
