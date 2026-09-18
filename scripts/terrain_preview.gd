extends Node3D

@onready var terrain_root: Node3D = $BratislavaRealTerrain
@onready var camera: Camera3D = $Camera3D

var focus := Vector3(0.0, 4.0, 0.0)
var distance: float = 300.0
var yaw: float = 0.0
var pitch: float = deg_to_rad(-58.0)
var pan_speed: float = 95.0
var rotate_speed: float = 0.004
var zoom_step: float = 0.88
var dragging: bool = false

func _ready() -> void:
	for node_name in [
		"Terrain-col",
		"Kamzik_439m",
		"Old_Town_Centre",
		"Petrzalka_Lowland",
		"Morava_Danube_Confluence"
	]:
		var n := terrain_root.find_child(node_name, true, false)
		if n is VisualInstance3D:
			n.visible = false

	_setup_environment()
	_setup_overlay()
	_update_camera()

func _setup_environment() -> void:
	var env_node := $WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.80)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.95, 1.0)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env

func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.48)
	panel.position = Vector2(14, 14)
	panel.size = Vector2(500, 108)
	layer.add_child(panel)

	var label := Label.new()
	label.position = Vector2(28, 24)
	label.text = "BRATISLAVA TERRAIN REVIEW\nMouse wheel — zoom   |   Right drag — rotate\nWASD — pan   |   T — top view   |   R — oblique overview"
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
			distance = maxf(35.0, distance * zoom_step)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(700.0, distance / zoom_step)
			_update_camera()

	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * rotate_speed
		pitch -= event.relative.y * rotate_speed
		pitch = clampf(pitch, deg_to_rad(-88.0), deg_to_rad(-18.0))
		_update_camera()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			yaw = 0.0
			pitch = deg_to_rad(-88.0)
			distance = 310.0
			focus = Vector3(0.0, 0.0, 0.0)
			_update_camera()
		elif event.keycode == KEY_R:
			yaw = deg_to_rad(-18.0)
			pitch = deg_to_rad(-55.0)
			distance = 285.0
			focus = Vector3(0.0, 4.0, 0.0)
			_update_camera()

func _process(delta: float) -> void:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		move += forward
	if Input.is_key_pressed(KEY_S):
		move -= forward
	if Input.is_key_pressed(KEY_A):
		move -= right
	if Input.is_key_pressed(KEY_D):
		move += right

	if move.length_squared() > 0.0:
		var speed := pan_speed * maxf(distance / 300.0, 0.25)
		focus += move.normalized() * speed * delta
		_update_camera()
