extends Node3D

@onready var terrain_root: Node3D = $BratislavaRealTerrain
@onready var camera: Camera3D = $Camera3D

var move_speed: float = 80.0
var fast_multiplier: float = 4.0
var mouse_sensitivity: float = 0.003

func _ready() -> void:
	# Hide helper/collision objects from the imported GLB.
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

	# Start with a wide overview of the real Bratislava terrain.
	camera.position = Vector3(0.0, 150.0, 280.0)
	camera.look_at(Vector3(0.0, 8.0, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction -= camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		direction -= Vector3.UP

	if direction.length_squared() > 0.0:
		var speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= fast_multiplier
		camera.global_position += direction.normalized() * speed * delta
