extends Node3D

var level: int = 0
var cooldown: float = 0.0
var built: bool = false
var visual_root: Node3D
var turret_head: Node3D
var pad_light: OmniLight3D

func _ready() -> void:
	add_to_group("towers")
	build_pad()

func _process(delta: float) -> void:
	if not built:
		return
	cooldown = max(0.0, cooldown - delta)
	if cooldown <= 0.0:
		auto_fire()

func get_interaction_text(main: Node) -> String:
	if not built:
		return "E — build watchtower (75 gold)"
	if level >= 5:
		return "Watchtower level 5 — maximum"
	return "E — upgrade watchtower to level %d (%d gold)" % [level + 1, upgrade_cost()]

func interact(player: Node) -> void:
	var main = player.main_ref
	if main == null:
		return
	if not built:
		if main.gold < 75:
			main.prompt_label.text = "Need 75 gold to build this watchtower."
			return
		main.gold -= 75
		built = true
		level = 1
		build_tower_visuals()
		main.update_hud()
		main.prompt_label.text = "Watchtower built — level 1."
		return
	if level >= 5:
		main.prompt_label.text = "This watchtower is already at maximum level."
		return
	var cost := upgrade_cost()
	if main.gold < cost:
		main.prompt_label.text = "Need %d gold for the upgrade." % cost
		return
	main.gold -= cost
	level += 1
	update_tower_visuals()
	main.update_hud()
	main.prompt_label.text = "Watchtower upgraded to level %d." % level

func upgrade_cost() -> int:
	return 45 + level * 25

func auto_fire() -> void:
	var target: Node3D = null
	var nearest_distance := 18.0 + float(level) * 2.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			target = enemy
	if target == null:
		return
	cooldown = max(0.28, 1.18 - float(level) * 0.14)
	if turret_head != null:
		var flat_target := target.global_position
		flat_target.y = turret_head.global_position.y
		turret_head.look_at(flat_target, Vector3.UP)
	fire_projectile(target)

func fire_projectile(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var shot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16 + float(level) * 0.015
	sphere.height = sphere.radius * 2.0
	shot.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffd36b")
	material.emission_enabled = true
	material.emission = Color("ff9f43")
	material.emission_energy_multiplier = 4.0
	shot.material_override = material
	get_tree().current_scene.add_child(shot)
	var muzzle := global_position + Vector3(0.0, 7.15, 0.0)
	if turret_head != null:
		muzzle = turret_head.global_position + (-turret_head.global_transform.basis.z * 1.4)
	shot.global_position = muzzle
	var destination := target.global_position + Vector3(0.0, 1.0, 0.0)
	var duration: float = maxf(0.12, shot.global_position.distance_to(destination) / 22.0)
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(shot, "global_position", destination, duration)
	await tween.finished
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(15 + level * 10)
	if is_instance_valid(shot):
		shot.queue_free()

func build_pad() -> void:
	var pad := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.4
	cylinder.bottom_radius = 2.7
	cylinder.height = 0.25
	pad.mesh = cylinder
	pad.position.y = 0.13
	pad.material_override = make_material(Color("6d665b"), 0.95)
	add_child(pad)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.65
	ring_mesh.outer_radius = 2.05
	ring.mesh = ring_mesh
	ring.position.y = 0.28
	ring.material_override = make_emissive_material(Color("e7b963"), 2.2)
	add_child(ring)
	pad_light = OmniLight3D.new()
	pad_light.light_color = Color("ffc76d")
	pad_light.light_energy = 1.3
	pad_light.omni_range = 7.0
	pad_light.position = Vector3(0, 1.1, 0)
	add_child(pad_light)

func build_tower_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "BuiltTower"
	add_child(visual_root)
	for x in [-1.75, 1.75]:
		for z in [-1.75, 1.75]:
			add_box(visual_root, Vector3(x, 3.0, z), Vector3(0.55, 6.0, 0.55), Color("5a3c24"))
	add_box(visual_root, Vector3(0, 6.0, 0), Vector3(5.4, 0.65, 5.4), Color("8b6138"))
	add_box(visual_root, Vector3(-2.35, 7.0, 0), Vector3(0.28, 1.65, 5.2), Color("64462c"))
	add_box(visual_root, Vector3(2.35, 7.0, 0), Vector3(0.28, 1.65, 5.2), Color("64462c"))
	add_box(visual_root, Vector3(0, 7.0, -2.35), Vector3(5.2, 1.65, 0.28), Color("64462c"))
	add_box(visual_root, Vector3(0, 7.0, 2.35), Vector3(5.2, 1.65, 0.28), Color("64462c"))
	turret_head = Node3D.new()
	turret_head.name = "TurretHead"
	turret_head.position = Vector3(0, 7.0, 0)
	visual_root.add_child(turret_head)
	add_box(turret_head, Vector3(0, 0, 0), Vector3(1.2, 0.65, 1.5), Color("4c3a2a"))
	add_box(turret_head, Vector3(0, 0.05, -1.35), Vector3(0.22, 0.22, 2.3), Color("2e2e31"), true)
	if pad_light != null:
		pad_light.light_color = Color("7fd28c")
		pad_light.light_energy = 2.1
	update_tower_visuals()

func update_tower_visuals() -> void:
	if visual_root == null:
		return
	visual_root.scale = Vector3.ONE * (1.0 + float(level - 1) * 0.035)
	if pad_light != null:
		pad_light.light_energy = 1.8 + float(level) * 0.45

func add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metallic: bool = false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.material_override = make_material(color, 0.75, 0.2 if metallic else 0.0)
	parent.add_child(mesh_instance)
	return mesh_instance

func make_material(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := make_material(color, 0.55)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material