extends CharacterBody3D

@export var speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var gravity_force: float = 18.0
@export var mouse_sens: float = 0.0025

var main_ref: Node = null
var pivot: Node3D = null
var spring: SpringArm3D = null
var first_person: bool = false
var overview_mode: bool = false
var attack_cd: float = 0.0

func _ready() -> void:
	pivot = get_node_or_null("CameraPivot") as Node3D
	spring = get_node_or_null("CameraPivot/SpringArm") as SpringArm3D
	if pivot == null:
		push_error("Player: CameraPivot is missing")
	if spring == null:
		push_error("Player: CameraPivot/SpringArm is missing")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		if pivot != null:
			pivot.rotation.x = clampf(
				pivot.rotation.x - event.relative.y * mouse_sens,
				deg_to_rad(-70.0),
				deg_to_rad(55.0)
			)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_camera") and spring != null:
		overview_mode = false
		first_person = not first_person
		spring.spring_length = 0.2 if first_person else 6.4

	if event.is_action_pressed("overview"):
		toggle_overview()

func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	if not is_on_floor():
		velocity.y -= gravity_force * delta
	else:
		velocity.y = 0.0

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else speed
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	move_and_slide()

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("attack"):
		attack()
	check_interactions()

func attack() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = 0.55
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		if global_position.distance_to(enemy.global_position) < 2.8 and enemy.has_method("take_damage"):
			enemy.take_damage(35)

func check_interactions() -> void:
	if main_ref == null or not is_instance_valid(main_ref):
		return
	var prompt = main_ref.get("prompt_label")
	if prompt == null:
		return
	if main_ref.has_method("get_command_interaction"):
		var command_info: Dictionary = main_ref.get_command_interaction(global_position)
		if not command_info.is_empty():
			prompt.text = command_info.get("text", "")
			if Input.is_action_just_pressed("interact"):
				main_ref.use_command_interaction(self, command_info)
			return

	var nearest: Node3D = null
	var nearest_distance: float = INF
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not (tower is Node3D):
			continue
		var distance := global_position.distance_to(tower.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = tower

	if nearest != null and nearest_distance < 4.6:
		if nearest.has_method("get_interaction_text"):
			main_ref.prompt_label.text = nearest.get_interaction_text(main_ref)
		else:
			main_ref.prompt_label.text = "E — use tower"
		if Input.is_action_just_pressed("interact") and nearest.has_method("interact"):
			nearest.interact(self)
	else:
		prompt.text = ""

func toggle_overview() -> void:
	if spring == null or pivot == null or main_ref == null:
		return
	if not main_ref.has_method("is_player_on_command_deck"):
		return
	if not main_ref.is_player_on_command_deck(global_position):
		var prompt = main_ref.get("prompt_label")
		if prompt != null:
			prompt.text = "Return to the central command terrace to use tactical overview."
		return

	overview_mode = not overview_mode
	first_person = false
	if overview_mode:
		spring.spring_length = 34.0
		pivot.rotation.x = deg_to_rad(-47.0)
	else:
		spring.spring_length = 5.2
		pivot.rotation.x = deg_to_rad(-12.0)