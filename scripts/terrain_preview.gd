extends Node3D

@onready var terrain_root: Node3D = $BratislavaRealTerrain
@onready var camera: Camera3D = $Camera3D

var focus := Vector3(0.0, 7.0, 0.0)
var distance: float = 300.0
var yaw: float = deg_to_rad(-22.0)
var pitch: float = deg_to_rad(-52.0)
var pan_speed: float = 90.0
var rotate_speed: float = 0.004
var zoom_step: float = 0.88
var dragging := false

var terrain_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var castle_mat: StandardMaterial3D
var marker_mat: StandardMaterial3D

func _ready() -> void:
	terrain_mat = _unlit(Color("#4f7f35"))
	water_mat = _unlit(Color("#1769aa"))
	castle_mat = _unlit(Color("#c8a766"))
	marker_mat = _unlit(Color("#ff7a18"))

	# Remove/disable EVERYTHING imported that can affect the view except mesh geometry.
	for n in terrain_root.find_children("*", "", true, false):
		if n is Light3D:
			n.queue_free()
		elif n is Camera3D:
			n.current = false

	var stats := {"mesh": 0, "hidden": 0, "terrain": 0, "water": 0, "castle": 0, "other": 0}
	_force_materials_recursive(terrain_root, "", stats)

	_setup_environment()
	_setup_overlay(stats)
	_update_camera()

func _unlit(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return m

func _force_materials_recursive(node: Node, inherited_name: String, stats: Dictionary) -> void:
	var path_name := (inherited_name + "/" + str(node.name)).to_lower()

	if node is MeshInstance3D:
		stats["mesh"] += 1
		if "terrain-col" in path_name or "collision" in path_name:
			node.visible = false
			stats["hidden"] += 1
		elif "danube" in path_name or "morava" in path_name or "water" in path_name:
			node.visible = true
			node.material_override = water_mat
			stats["water"] += 1
		elif "castle" in path_name or "devin" in path_name:
			node.visible = true
			node.material_override = castle_mat
			stats["castle"] += 1
		elif "terrain" in path_name:
			node.visible = true
			node.material_override = terrain_mat
			stats["terrain"] += 1
		else:
			# Hide helper spheres/markers so they cannot cover the map.
			if "kamzik" in path_name or "centre" in path_name or "lowland" in path_name or "confluence" in path_name:
				node.visible = false
				stats["hidden"] += 1
			else:
				node.visible = true
				node.material_override = marker_mat
				stats["other"] += 1

	for child in node.get_children():
		_force_materials_recursive(child, path_name, stats)

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#91a7bb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	$WorldEnvironment.environment = env

func _setup_overlay(stats: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.06, 0.08, 0.92)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(790, 145)
	layer.add_child(panel)

	var label := Label.new()
	label.position = Vector2(26, 24)
	label.text = "TERRAIN DEBUG BUILD 5 — REAL GLB ONLY\nGREEN = terrain | BLUE = Danube/Morava | TAN = castle placeholders\nMeshes: %d  terrain:%d  water:%d  castle:%d  hidden:%d\nWheel zoom | Right-drag rotate | WASD pan | T top | R oblique" % [
		stats["mesh"], stats["terrain"], stats["water"], stats["castle"], stats["hidden"]
	]
	label.add_theme_font_size_override("font_size", 18)
	layer.add_child(label)

func _update_camera() -> void:
	var cp := cos(pitch)
	var offset := Vector3(
		sin(yaw) * cp,
		-sin(pitch),
		cos(yaw) * cp
	) * distance
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = maxf(40.0, distance * zoom_step)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(800.0, distance / zoom_step)
			_update_camera()

	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * rotate_speed
		pitch -= event.relative.y * rotate_speed
		pitch = clampf(pitch, deg_to_rad(-88.0), deg_to_rad(-15.0))
		_update_camera()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			yaw = 0.0
			pitch = deg_to_rad(-88.0)
			distance = 320.0
			focus = Vector3.ZERO
			_update_camera()
		elif event.keycode == KEY_R:
			yaw = deg_to_rad(-22.0)
			pitch = deg_to_rad(-52.0)
			distance = 300.0
			focus = Vector3(0.0, 7.0, 0.0)
			_update_camera()

func _process(delta: float) -> void:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move := Vector3.ZERO

	if Input.is_key_pressed(KEY_W): move += forward
	if Input.is_key_pressed(KEY_S): move -= forward
	if Input.is_key_pressed(KEY_A): move -= right
	if Input.is_key_pressed(KEY_D): move += right

	if move.length_squared() > 0.0:
		focus += move.normalized() * pan_speed * maxf(distance / 300.0, 0.25) * delta
		_update_camera()
