extends CharacterBody3D

@onready var cooldown_bar = $CooldownBar 
@onready var screech_sound = $ScreechSound
@onready var body = $CollisionShape3D
@onready var notifier = $interacter/notifier
@onready var interact = $Camera3D/interact
@onready var cursor = $cursor

# --- Charge-Up Variables ---
var is_charging: bool = false
var charge_timer: float = 0.0
var is_mega_pulse: bool = false
var slowed_enemies: Array = []

# --- Audio Node References ---
@onready var footsteps = $Footsteps
@onready var jump_grunt = $jumpgrunt  
@onready var jump_woosh = $jumpwoosh  
@onready var echoping: AudioStreamPlayer3D = $echoping

var mouse_sens: float = 0.002
var is_ability_ready: bool = true

const SPEED = 5.0
const JUMP_VELOCITY = 3.2

# --- NEW: We track the current speed globally so we can smoothly transition it! ---
var current_speed: float = SPEED

# --- Head Bobbing Settings ---
@onready var camera = $Camera3D
@onready var default_cam_height: float = camera.position.y

var bob_time: float = 0.0
var current_bob_intensity: float = 0.0

const IDLE_BOB_SPEED: float = 2.0
const IDLE_BOB_AMOUNT: float = 0.04
const WALK_BOB_SPEED: float = 12.0
const WALK_BOB_AMOUNT: float = 0.08

# --- Echolocation Ability Settings ---
@export var max_echo_distance: float = 20.0
@export var echo_speed: float = 10.0       
@export var echo_cooldown: float = 10.0

var is_echoing: bool = false
var current_echo_radius: float = 0.0
var cooldown_timer: float = 0.0
var pulse_sphere: MeshInstance3D

# Preload your outline materials
var enemy_mat = preload("res://enemy_outline_mat.tres")
var wave_mat = preload("res://radar_wave_mat.tres") 
var mega_shout_mat = preload("res://mega_shout_mat.tres")

# Track objects highlighted during the current active pulse
var highlighted_objects: Array = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if cooldown_bar:
		cooldown_bar.max_value = echo_cooldown
		cooldown_bar.step = 0.15 
		cooldown_bar.value = 0.0

func check_ray_hit() -> void:
	if interact.is_colliding():
		if interact.get_collider().is_in_group("exit"):
			notifier.visible = true
			cursor.visible = false
			if Input.is_action_just_pressed("interact"):
				var win_screen = get_node_or_null("/root/TestWorld/WinScreen")
				if win_screen:
					win_screen.player_won()
				else:
					get_tree().reload_current_scene()
	else:
		notifier.visible = false
		cursor.visible = true


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		camera.rotate_x(-event.relative.y * mouse_sens)
		camera.rotation.x = clamp(camera.rotation.x, -1.2, 1.2)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	# --- Echolocation Ability Management ---
	if cooldown_timer > 0:
		cooldown_timer -= delta
		is_ability_ready = false 
		
		if cooldown_bar:
			cooldown_bar.value = echo_cooldown - cooldown_timer
	else:
		if cooldown_bar:
			cooldown_bar.value = echo_cooldown
			
		if not is_ability_ready:
			_play_recharge_effect()
			is_ability_ready = true 

	# --- HOLD-TO-CHARGE LOGIC ---
	if Input.is_key_pressed(KEY_E) and cooldown_timer <= 0 and not is_echoing:
		is_charging = true
		charge_timer += delta
		
		if charge_timer >= 3.0:
			_trigger_pulse(true) 
	else:
		if is_charging:
			_trigger_pulse(false)

	if is_echoing:
		_process_echo_pulse(delta)

	# --- Handle Jump ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if jump_grunt:
			jump_grunt.play(0.35) 
		if jump_woosh:
			jump_woosh.play()

	check_ray_hit()
	
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# --- PLAYER SLOWDOWN PENALTY ---
	var target_speed = SPEED
	
	if is_charging and charge_timer > 0.2:
		target_speed = SPEED * 0.3
		
	current_speed = lerp(current_speed, target_speed, delta * 8.0)
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	move_and_slide()

	if direction != Vector3.ZERO and is_on_floor():
		if not footsteps.playing:
			footsteps.play()
	else:
		footsteps.stop()

	_handle_head_bob(delta, direction)


func _handle_head_bob(delta: float, direction: Vector3) -> void:
	# --- THE FIX: Continuous bobbing math ---
	if is_on_floor():
		if direction != Vector3.ZERO:
			bob_time += delta * WALK_BOB_SPEED
			# Lerp the intensity up to walking amount
			current_bob_intensity = lerp(current_bob_intensity, WALK_BOB_AMOUNT, delta * 8.0)
		else:
			bob_time += delta * IDLE_BOB_SPEED
			# Lerp the intensity down to idle amount
			current_bob_intensity = lerp(current_bob_intensity, IDLE_BOB_AMOUNT, delta * 8.0)
	else:
		# Mid-air: Smoothly fade the intensity to zero
		current_bob_intensity = lerp(current_bob_intensity, 0.0, delta * 10.0)

	# Apply the position constantly. Because the intensity drops to 0 in the air, 
	# it naturally settles at the default height without ever snapping!
	camera.position.y = default_cam_height + sin(bob_time) * current_bob_intensity


# =================================================================
#                 ECHOLOCATION PULSE CORE SYSTEM
# =================================================================
func _trigger_pulse(mega: bool) -> void:
	is_charging = false
	charge_timer = 0.0
	is_mega_pulse = mega
	slowed_enemies.clear() 
	start_echolocation_pulse()
	
func start_echolocation_pulse() -> void:
	is_echoing = true
	current_echo_radius = 0.0
	highlighted_objects.clear()
	cooldown_timer = echo_cooldown
	
	_play_use_effect()
	
	if screech_sound:
		if is_mega_pulse:
			screech_sound.pitch_scale = 0.55 
			screech_sound.volume_db = 19.68  
		else:
			screech_sound.pitch_scale = 0.74  
			screech_sound.volume_db = 16.68
		screech_sound.play()
		
	pulse_sphere = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	pulse_sphere.mesh = sphere_mesh
	
	var active_wave_mat = wave_mat.duplicate() as ShaderMaterial
	
	if active_wave_mat:
		if is_mega_pulse:
			active_wave_mat.set_shader_parameter("wave_color", Color(1.0, 0.0, 0.0, 1.0)) 
		else:
			active_wave_mat.set_shader_parameter("wave_color", Color(1.0, 1.0, 1.0, 1.0))
		
	pulse_sphere.material_override = active_wave_mat
	
	get_tree().root.add_child(pulse_sphere)
	pulse_sphere.global_position = global_position + Vector3(0, 1.0, 0)

func _process_echo_pulse(delta: float) -> void:
	current_echo_radius += echo_speed * delta
	
	if is_instance_valid(pulse_sphere):
		pulse_sphere.scale = Vector3(current_echo_radius, current_echo_radius, current_echo_radius)
		
		var sphere_mat = pulse_sphere.material_override as ShaderMaterial
		if sphere_mat:
			var alpha: float = 0.0
			var peak_distance: float = 8.0 
			var max_brightness: float = 0.3 
			
			if current_echo_radius < peak_distance:
				alpha = remap(current_echo_radius, 0.0, peak_distance, 0.0, max_brightness)
			else:
				alpha = remap(current_echo_radius, peak_distance, max_echo_distance, max_brightness, 0.0)
				
			var current_color = sphere_mat.get_shader_parameter("wave_color")
			if current_color != null:
				current_color.a = clamp(alpha, 0.0, max_brightness)
				sphere_mat.set_shader_parameter("wave_color", current_color)
	
	if current_echo_radius >= max_echo_distance:
		is_echoing = false
		if is_instance_valid(pulse_sphere):
			pulse_sphere.queue_free()
		return

	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_mega_pulse and not enemy in slowed_enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= current_echo_radius and dist >= (current_echo_radius - 3.0):
				slowed_enemies.append(enemy)
				if enemy.has_method("apply_echo_slow"):
					enemy.apply_echo_slow(4.0) 
	
		var meshes = enemy.find_children("*", "MeshInstance3D", true, false)
		if enemy is MeshInstance3D:
			meshes.append(enemy)
			
		for mesh_node in meshes:
			if "StunClone" in mesh_node.name:
				continue 
				
			if not mesh_node in highlighted_objects:
				_check_and_highlight_enemy(mesh_node, is_mega_pulse)

func _check_and_highlight_enemy(mesh_node: MeshInstance3D, is_mega: bool = false) -> void:
	var distance = global_position.distance_to(mesh_node.global_position)
	
	if distance <= current_echo_radius and distance >= (current_echo_radius - 3.0):
		highlighted_objects.append(mesh_node)
		
		var unique_mat: ShaderMaterial
		
		if is_mega:
			if mega_shout_mat:
				unique_mat = mega_shout_mat.duplicate() as ShaderMaterial
		else:
			if enemy_mat:
				unique_mat = enemy_mat.duplicate() as ShaderMaterial
		
		if unique_mat:
			mesh_node.material_overlay = unique_mat
			
			var tween = create_tween()
			tween.tween_interval(4.0) 
			tween.tween_property(unique_mat, "shader_parameter/glow_color:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_callback(_clear_enemy_highlight.bind(mesh_node))


func _clear_enemy_highlight(mesh_node: MeshInstance3D) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.material_overlay = null
		
func _play_recharge_effect() -> void:
	if not cooldown_bar:
		return
		
	cooldown_bar.pivot_offset = cooldown_bar.size / 2.0 
	var original_pos = cooldown_bar.position 
	var tween = create_tween()
	var shake_power = 8.0 
	
	tween.tween_property(cooldown_bar, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.parallel().tween_property(cooldown_bar, "scale", Vector2(1.2, 1.2), 0.1)
	
	tween.tween_property(cooldown_bar, "position", original_pos + Vector2(shake_power, 0), 0.03)
	tween.tween_property(cooldown_bar, "position", original_pos + Vector2(-shake_power, 0), 0.03)
	tween.tween_property(cooldown_bar, "position", original_pos + Vector2(shake_power / 2.0, 0), 0.03)
	tween.tween_property(cooldown_bar, "position", original_pos + Vector2(-shake_power / 2.0, 0), 0.03)
	
	tween.tween_property(cooldown_bar, "position", original_pos, 0.05)
	tween.parallel().tween_property(cooldown_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	tween.parallel().tween_property(cooldown_bar, "scale", Vector2(1.0, 1.0), 0.2)
	
func _play_use_effect() -> void:
	if not cooldown_bar:
		return
		
	cooldown_bar.pivot_offset = cooldown_bar.size / 2.0 
	var original_pos = cooldown_bar.position 
	var tween = create_tween()
	var shake_power = 7.0
	
	tween.tween_property(cooldown_bar, "scale", Vector2(0.8, 0.8), 0.05)
	tween.parallel().tween_property(cooldown_bar, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.05)
	
	tween.parallel().tween_property(cooldown_bar, "position", original_pos + Vector2(-shake_power, shake_power), 0.02)
	tween.tween_property(cooldown_bar, "position", original_pos + Vector2(shake_power, -shake_power), 0.02)
	tween.tween_property(cooldown_bar, "position", original_pos + Vector2(-shake_power / 2.0, 0), 0.02)
	
	tween.tween_property(cooldown_bar, "position", original_pos, 0.05)
	tween.parallel().tween_property(cooldown_bar, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(cooldown_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
