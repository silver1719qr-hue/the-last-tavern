extends Node3D

@onready var terrain_root: Node3D = $BratislavaRealTerrain
@onready var camera: Camera3D = $Camera3D

var focus := Vector3(0.0, 5.0, 0.0)
var distance: float = 285.0
var yaw: float = deg_to_rad(-18.0)
var pitch: float = deg_to_rad(-55.0)
var pan_speed: float = 95.0
var rotate_speed: float = 0.004
var zoom_step: float = 0.88
var dragging: bool = false
var relief_mode := 3

func _ready() -> void:
	# The GLB contains its own Blender Sun exported with extreme intensity (~1570).
	# Disable imported lights/cameras so they cannot blow out the terrain preview.
	for child in terrain_root.find_children("*", "Light3D", true, false):
		if child is Light3D:
			child.visible = false
	var imported_camera := terrain_root.find_child("Overview_Camera", true, false)
	if imported_camera is Camera3D:
		imported_camera.current = false

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

	_apply_review_materials()
	_setup_environment()
	_setup_overlay()
	_update_camera()

func make_material(color: Color, roughness: float = 0.95, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _set_material(node_name: String, material: StandardMaterial3D) -> void:
	var node := terrain_root.find_child(node_name, true, false)
	if node is MeshInstance3D:
		node.material_override = material

func _apply_review_materials() -> void:
	# Temporary diagnostic colors so the actual geometry, rivers and landmarks are readable.
	_set_material("Terrain", make_material(Color(0.24, 0.42, 0.20)))
	_set_material("Danube_OSM", make_material(Color(0.10, 0.36, 0.62), 0.28, 0.05))
	_set_material("Morava_OSM", make_material(Color(0.14, 0.46, 0.68), 0.28, 0.05))
	_set_material("Bratislava_Castle_OSM_Placeholder", make_material(Color(0.78, 0.70, 0.52)))
	_set_material("Devin_Castle_OSM_Placeholder", make_material(Color(0.64, 0.57, 0.45)))

func _setup_environment() -> void:
	var env_node := $WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.68, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.84)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env

func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.56)
	panel.position = Vector2(14, 14)
	panel.size = Vector2(690, 132)
	layer.add_child(panel)

	var label := Label.new()
	label.name = "ReviewHelp"
	label.position = Vector2(28, 24)
	label.text = "BRATISLAVA REAL TERRAIN REVIEW\nWheel — zoom | Right drag — rotate | WASD — pan | T — top | R — oblique\n1 — true elevation scale | 2 — relief x3 (current, easier to inspect)"
	label.add_theme_font_size_override("font_size", 18)
	layer.add_child(label)

func _set_relief(multiplier: int) -> void:
	relief_mode = multiplier
	terrain_root.scale = Vector3(0.02, 0.02 * float(multiplier), 0.02)
	var label := get_node_or_null("ReviewHelp")
	if label == null:
		label = find_child("ReviewHelp", true, false)
	if label is Label:
		var mode_text := "true elevation scale" if multiplier == 1 else "relief x3 for inspection"
		label.text = "BRATISLAVA REAL TERRAIN REVIEW\nWheel — zoom | Right drag — rotate | WASD — pan | T — top | R — oblique\n1 — true elevation scale | 2 — relief x3 | CURRENT: " + mode_text

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
			distance = maxf(45.0, distance * zoom_step)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(750.0, distance / zoom_step)
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
			distance = 320.0
			focus = Vector3(0.0, 0.0, 0.0)
			_update_camera()
		elif event.keycode == KEY_R:
			yaw = deg_to_rad(-18.0)
			pitch = deg_to_rad(-55.0)
			distance = 285.0
			focus = Vector3(0.0, 5.0, 0.0)
			_update_camera()
		elif event.keycode == KEY_1:
			_set_relief(1)
		elif event.keycode == KEY_2:
			_set_relief(3)

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
