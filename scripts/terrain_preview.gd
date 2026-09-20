extends Node3D

const CastleModels = preload("res://scripts/castle_models.gd")
const TerrainSurface = preload("res://scripts/terrain_surface.gd")
const SiegeRoute = preload("res://scripts/siege_route.gd")
const TacticalGameplay = preload("res://scripts/tactical_gameplay.gd")\nconst RiverSiegePreview = preload("res://scripts/river_siege_preview.gd")

@onready var terrain_root: Node3D = $BratislavaRealTerrain
@onready var camera: Camera3D = $Camera3D

const VERTICAL_REVIEW_SCALE := 1.6

var focus := Vector3(0.0, 260.0, 900.0)
var distance: float = 23200.0
var yaw: float = deg_to_rad(-24.0)
var pitch: float = deg_to_rad(-43.0)
var pan_speed: float = 4200.0
var rotate_speed: float = 0.004
var zoom_step: float = 0.88
var dragging := false

var terrain_mat: ShaderMaterial
var water_mat: StandardMaterial3D


func _ready() -> void:
	terrain_root.scale = Vector3(1.0, VERTICAL_REVIEW_SCALE, 1.0)
	if DisplayServer.get_name() == "headless":
		# CI validates the imported resources with dedicated scripts. Avoid asking
		# Godot's dummy renderer to prepare visible GLB meshes without GPU storage.
		terrain_root.visible = false
		return
	terrain_mat = _make_terrain_material()
	water_mat = _lit_material(Color("#176f9e"), 0.24, 0.05)

	# Imported Blender review lights/cameras must not affect this Godot review scene.
	for node in terrain_root.find_children("*", "", true, false):
		if node is Light3D:
			node.visible = false
		elif node is Camera3D:
			node.current = false

	var stats := {"mesh": 0, "hidden": 0, "terrain": 0, "water": 0, "castle": 0, "road": 0, "river": 0}
	_prepare_meshes(terrain_root, stats)

	# Review scene: real terrain/water, landmark castles, historical bridge and
	# one automatically generated terrain-aware medieval road.
	var surface_sampler := TerrainSurface.new(terrain_root)

	var bratislava_castle := CastleModels.build_bratislava(self)
	bratislava_castle.global_position.y = surface_sampler.height_world_at(2260.8, 4704.0) + 0.6

	var devin_castle := CastleModels.build_devin(self)
	devin_castle.global_position.y = surface_sampler.height_world_at(-6722.0, 1321.0) + 0.6

	CastleModels.build_historical_bridges(self)

	var route_root := SiegeRoute.build(self, terrain_root, false)
	var tactical := TacticalGameplay.new()
	tactical.name = "TacticalGameplay"
	add_child(tactical)
	tactical.setup(terrain_root, route_root, camera)

	stats["castle"] = 2
	stats["road"] = 1

	_setup_environment()
	_setup_landmark_labels()
	_setup_overlay(stats)
	set_river_siege_view()


func _make_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying float elevation_m;
varying vec3 local_normal;

void vertex() {
	elevation_m = VERTEX.y;
	local_normal = NORMAL;
}

void fragment() {
	float h = clamp(elevation_m / 600.0, 0.0, 1.0);
	float slope = 1.0 - clamp(abs(normalize(local_normal).y), 0.0, 1.0);
	vec3 lowland = vec3(0.28, 0.48, 0.15);
	vec3 forest = vec3(0.055, 0.24, 0.085);
	vec3 highland = vec3(0.17, 0.31, 0.12);
	vec3 rock = vec3(0.37, 0.34, 0.29);
	vec3 color = mix(lowland, forest, smoothstep(0.17, 0.42, h));
	color = mix(color, highland, smoothstep(0.55, 0.78, h));
	color = mix(color, rock, smoothstep(0.28, 0.72, slope));
	ALBEDO = color;
	ROUGHNESS = 0.94;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _lit_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _prepare_meshes(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		var own_name := str(node.name).to_lower()
		stats["mesh"] += 1
		if "terrain-col" in own_name or "collision" in own_name:
			node.visible = false
			stats["hidden"] += 1
		elif "danube" in own_name or "morava" in own_name or "water" in own_name:
			node.visible = true
			node.material_override = water_mat
			stats["water"] += 1
		elif "castle" in own_name or "devin" in own_name:
			# Retain the imported OSM blocks as placement data, but replace their
			# appearance with the game-ready landmark models.
			node.visible = false
			stats["hidden"] += 1
		elif own_name == "terrain":
			node.visible = true
			node.material_override = terrain_mat
			stats["terrain"] += 1
		else:
			# Hide the orange diagnostic spheres from the source GLB.
			node.visible = false
			stats["hidden"] += 1

	for child in node.get_children():
		_prepare_meshes(child, stats)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9bb8cf")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9d9df")
	env.ambient_light_energy = 0.48
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	$WorldEnvironment.environment = env


func _setup_landmark_labels() -> void:
	_add_label("• Devín Castle", Vector3(-6722.0, 180.0, 1321.0))
	_add_label("• Morava → Danube", Vector3(-6930.0, 120.0, 930.0))
	_add_label("• Bratislava Castle", Vector3(2260.0, 240.0, 4700.0))
	_add_label("• Staré Mesto", Vector3(3180.0, 120.0, 4480.0))
	_add_label("• Petržalka", Vector3(2600.0, 92.0, 8100.0))
	_add_label("• Kamzík", Vector3(1830.0, 735.0, 250.0))
	_add_label("• Little Carpathians", Vector3(2300.0, 600.0, -3600.0))
	_add_label("• Danube", Vector3(-700.0, 105.0, 5900.0))


func _add_label(text_value: String, world_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = world_position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.font_size = 11
	label.outline_size = 2
	label.modulate = Color(1.0, 0.96, 0.78, 0.9)
	label.outline_modulate = Color(0.02, 0.025, 0.03, 0.82)
	label.no_depth_test = false
	add_child(label)


func _setup_overlay(stats: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(430, 0)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "BRATISLAVA — REAL DEM / OSM TERRAIN"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	var status := Label.new()
	status.text = "TACTICAL DEFENSE TEST — NO VISIBLE ROAD\nEnemies use a hidden bridge-to-castle route\n19.3 × 18.9 km | relief ×%.1f | real DEM/OSM\nTerrain: %d | water: %d | castles: %d | road: %d" % [
		VERTICAL_REVIEW_SCALE, stats["terrain"], stats["water"], stats["castle"], stats["road"]
	]
	status.add_theme_font_size_override("font_size", 11)
	box.add_child(status)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var oblique_button := Button.new()
	oblique_button.text = "OBLIQUE VIEW (R)"
	oblique_button.pressed.connect(set_oblique_view)
	buttons.add_child(oblique_button)
	var top_button := Button.new()
	top_button.text = "TOP VIEW (T)"
	top_button.pressed.connect(set_top_view)
	buttons.add_child(top_button)

	var help := Label.new()
	help.text = "Mouse/WASD • 1 Castle • 2 Devín • 3 Danube • 4 Morava • 5 river siege • T top • R region"
	help.add_theme_font_size_override("font_size", 11)
	box.add_child(help)


func set_oblique_view() -> void:
	focus = Vector3(0.0, 260.0, 900.0)
	distance = 23200.0
	yaw = deg_to_rad(-24.0)
	pitch = deg_to_rad(-43.0)
	_update_camera()


func set_top_view() -> void:
	focus = Vector3(0.0, 120.0, 200.0)
	distance = 22500.0
	yaw = 0.0
	pitch = deg_to_rad(-89.0)
	_update_camera()


func set_river_siege_view() -> void:
	# Focus on the Bratislava river-defense sector: ships, stone quay,
	# Petržalka fire posts and the enemy landing dock.
	focus = Vector3(1700.0, 70.0, 5520.0)
	distance = 2450.0
	yaw = deg_to_rad(-34.0)
	pitch = deg_to_rad(-39.0)
	_update_camera()


func set_road_review_view() -> void:
	# Kept for development reference; the new gameplay direction is river-first.
	focus = Vector3(2480.0, 145.0, 5020.0)
	distance = 1750.0
	yaw = deg_to_rad(-2.0)
	pitch = deg_to_rad(-80.0)
	_update_camera()


func set_anchor_review_view() -> void:
	focus = Vector3(2260.0, 142.0, 4700.0)
	distance = 720.0
	yaw = deg_to_rad(-16.0)
	pitch = deg_to_rad(-68.0)
	_update_camera()


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
			distance = maxf(260.0, distance * zoom_step)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(50000.0, distance / zoom_step)
			_update_camera()

	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * rotate_speed
		pitch -= event.relative.y * rotate_speed
		pitch = clampf(pitch, deg_to_rad(-88.5), deg_to_rad(-10.0))
		_update_camera()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			set_top_view()
		elif event.keycode == KEY_R:
			set_oblique_view()
		elif event.keycode == KEY_1:
			focus = Vector3(2260.0, 205.0, 4700.0)
			distance = 520.0
			yaw = deg_to_rad(-32.0)
			pitch = deg_to_rad(-28.0)
			_update_camera()
		elif event.keycode == KEY_2:
			focus = Vector3(-6722.0, 155.0, 1321.0)
			distance = 760.0
			yaw = deg_to_rad(-42.0)
			pitch = deg_to_rad(-31.0)
			_update_camera()
		elif event.keycode == KEY_3:
			focus = Vector3(2262.0, 42.0, 5173.0)
			distance = 720.0
			yaw = deg_to_rad(-38.0)
			pitch = deg_to_rad(-30.0)
			_update_camera()
		elif event.keycode == KEY_4:
			focus = Vector3(-6914.0, 47.0, 700.0)
			distance = 440.0
			yaw = deg_to_rad(-48.0)
			pitch = deg_to_rad(-27.0)
			_update_camera()
		elif event.keycode == KEY_5:
			set_road_review_view()


func _process(delta: float) -> void:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move += forward
	if Input.is_key_pressed(KEY_S): move -= forward
	if Input.is_key_pressed(KEY_A): move -= right
	if Input.is_key_pressed(KEY_D): move += right
	if move.length_squared() > 0.0:
		focus += move.normalized() * pan_speed * maxf(distance / 23200.0, 0.12) * delta
		_update_camera()
