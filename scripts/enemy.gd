extends CharacterBody3D

var main_ref: Node = null
var target_pos := Vector3.ZERO
var hp: int = 50
var speed: float = 3.0
var damage: int = 10
var reward: int = 12
var gravity_force: float = 18.0

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity_force * delta
	else:
		velocity.y = 0.0

	var to_target := target_pos - global_position
	to_target.y = 0
	if to_target.length() < 2.0:
		if main_ref != null:
			main_ref.damage_base(damage)
			main_ref.enemy_died(0)
		queue_free()
		return

	var direction := to_target.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	look_at(global_position + direction, Vector3.UP)
	move_and_slide()

func take_damage(value: int) -> void:
	hp -= value
	if hp <= 0:
		if main_ref != null:
			main_ref.enemy_died(reward)
		queue_free()