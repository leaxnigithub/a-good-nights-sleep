extends CharacterBody3D

# --- UI References ---
var is_on_cooldown: bool = false 
@onready var blood_meter = $PlayerUI/BloodMeter
@onready var cooldown_meter = $PlayerUI/CooldownMeter
var cooldown_base_pos: Vector2 = Vector2.ZERO 

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

# --- Blood (Health + Stamina) Stats ---
var max_blood: float = 100.0
var current_blood: float = 100.0
var blood_regen_rate: float = 5.0 

var normal_pulse_cost: float = 25.0
var mega_pulse_cost: float = 55.0

# --- Audio Node References ---
@onready var footsteps = $Footsteps
@onready var jump_grunt = $jumpgrunt  
@onready var jump_woosh = $jumpwoosh  
@onready var echoping: AudioStreamPlayer3D = $echoping

var mouse_sens: float = 0.002

const SPEED = 5.0
const JUMP_VELOCITY = 3.2
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

var cooldown_timer: float = 0.0
var is_echoing: bool = false
var current_echo_radius: float = 0.0
var pulse_sphere: MeshInstance3D

# Preload your outline materials
var enemy_mat = preload("res://shaders/enemy_outline_mat.tres")
var wave_mat = preload("res://shaders/radar_wave_mat.tres") 
var mega_shout_mat = preload("res://shaders/mega_shout_mat.tres")
var vial_mat = preload("res://shaders/vial_outline_mat.tres") 

var highlighted_objects: Array = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if blood_meter:
		blood_meter.max_value = max_blood
		blood_meter.value = current_blood
		
	if cooldown_meter:
		cooldown_meter.max_value = echo_cooldown
		cooldown_meter.value = echo_cooldown
		cooldown_base_pos = cooldown_meter.position # <--- ADD THIS

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

# --- Blood Meter Update (Passive Healing Removed) ---
	if blood_meter:
		blood_meter.value = current_blood


# --- Cooldown Timer & UI Update ---
	if cooldown_timer > 0:
		cooldown_timer -= delta
		if cooldown_meter:
			var step_amount = 1.0 
			cooldown_meter.value = snapped(echo_cooldown - cooldown_timer, step_amount)
	else:
		if cooldown_meter:
			cooldown_meter.value = echo_cooldown 
			
		# Trigger the pop effect right when the timer finishes
		if is_on_cooldown:
			_play_recharge_effect()
			is_on_cooldown = false # Reset it so it only plays once

	# --- HOLD-TO-CHARGE LOGIC ---
	if Input.is_key_pressed(KEY_E) and not is_echoing and cooldown_timer <= 0 and current_blood > normal_pulse_cost:
		is_charging = true
		charge_timer += delta
		
		if charge_timer >= 3.0:
			if current_blood > mega_pulse_cost:
				_trigger_pulse(true) 
			else:
				_trigger_pulse(false)
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
	if is_on_floor():
		if direction != Vector3.ZERO:
			bob_time += delta * WALK_BOB_SPEED
			current_bob_intensity = lerp(current_bob_intensity, WALK_BOB_AMOUNT, delta * 8.0)
		else:
			bob_time += delta * IDLE_BOB_SPEED
			current_bob_intensity = lerp(current_bob_intensity, IDLE_BOB_AMOUNT, delta * 8.0)
	else:
		current_bob_intensity = lerp(current_bob_intensity, 0.0, delta * 10.0)

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
	# Start the 10-second cooldown timer
	cooldown_timer = echo_cooldown
	is_on_cooldown = true 
	
	# Empty the visual bar instantly
	if cooldown_meter:
		cooldown_meter.value = 0.0 

	# Sacrifice blood
	if is_mega_pulse:
		current_blood -= mega_pulse_cost
	else:
		current_blood -= normal_pulse_cost
		
	is_echoing = true
	current_echo_radius = 0.0
	highlighted_objects.clear()
	
	# PLAY UI EFFECTS HERE
	_play_use_effect()        # Shakes the blood meter
	_play_cooldown_effect()   # Flashes and shudders the cooldown meter
	
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
				
	# --- HIGHLIGHT BLOOD VIALS ---
	var vials = get_tree().get_nodes_in_group("blood_vial")
	for vial in vials:
		var dist = global_position.distance_to(vial.global_position)
		if dist <= current_echo_radius and dist >= (current_echo_radius - 3.0):
			
			# Find the mesh inside the vial scene
			var vial_mesh = vial.get_node_or_null("MeshInstance3D")
			if vial_mesh and not vial_mesh in highlighted_objects:
				_highlight_pickup(vial_mesh)

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
			
func _highlight_pickup(mesh_node: MeshInstance3D) -> void:
	highlighted_objects.append(mesh_node)
	
	if vial_mat:
		var unique_mat = vial_mat.duplicate() as ShaderMaterial
		mesh_node.material_overlay = unique_mat
		
		var tween = create_tween()
		tween.tween_interval(3.0) # Vials stay lit for 3 seconds
		tween.tween_property(unique_mat, "shader_parameter/glow_color:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_clear_enemy_highlight.bind(mesh_node)) # Reusing the clear function since it does the exact same thing

func _clear_enemy_highlight(mesh_node: MeshInstance3D) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.material_overlay = null


# =================================================================
#                 DAMAGE & HEALTH SYSTEM
# =================================================================
func take_damage(amount: float) -> void:
	current_blood -= amount
	
	if blood_meter:
		blood_meter.value = current_blood
	
	_play_use_effect()
		
	if current_blood <= 0:
		die()

func die() -> void:
	print("Player bled out!")
	
func add_blood(amount: float) -> void:
	current_blood += amount
	
	# Prevent the blood from going over the maximum limit
	if current_blood > max_blood:
		current_blood = max_blood
		
	if blood_meter:
		blood_meter.value = current_blood
		
	# Optional: You can create a new UI effect here for healing, 
	# or just reuse the recharge effect to show a positive flash!
	_play_recharge_effect()


# =================================================================
#                 UI ANIMATIONS
# =================================================================
func _play_use_effect() -> void:
	if not blood_meter:
		return
		
	blood_meter.pivot_offset = blood_meter.size / 2.0 
	var original_pos = blood_meter.position 
	var tween = create_tween()
	var shake_power = 7.0
	
	tween.tween_property(blood_meter, "scale", Vector2(0.8, 0.8), 0.05)
	tween.parallel().tween_property(blood_meter, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.05)
	
	tween.parallel().tween_property(blood_meter, "position", original_pos + Vector2(-shake_power, shake_power), 0.02)
	tween.tween_property(blood_meter, "position", original_pos + Vector2(shake_power, -shake_power), 0.02)
	tween.tween_property(blood_meter, "position", original_pos + Vector2(-shake_power / 2.0, 0), 0.02)
	
	tween.tween_property(blood_meter, "position", original_pos, 0.05)
	tween.parallel().tween_property(blood_meter, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(blood_meter, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

func _play_cooldown_effect() -> void:
	if not cooldown_meter:
		return
		
	cooldown_meter.pivot_offset = cooldown_meter.size / 2.0 
	var original_pos = cooldown_meter.position 
	var tween = create_tween()
	var shake_power = 8.0 
	
	# Flash bright white and scale up slightly
	tween.tween_property(cooldown_meter, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.1)
	tween.parallel().tween_property(cooldown_meter, "scale", Vector2(1.1, 1.1), 0.1)
	
	# Shudder violently side-to-side
	tween.tween_property(cooldown_meter, "position", original_pos + Vector2(shake_power, 0), 0.03)
	tween.tween_property(cooldown_meter, "position", original_pos + Vector2(-shake_power, 0), 0.03)
	tween.tween_property(cooldown_meter, "position", original_pos + Vector2(shake_power / 2.0, 0), 0.03)
	tween.tween_property(cooldown_meter, "position", original_pos + Vector2(-shake_power / 2.0, 0), 0.03)
	
	# Smoothly return to normal
	tween.tween_property(cooldown_meter, "position", original_pos, 0.05)
	tween.parallel().tween_property(cooldown_meter, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	tween.parallel().tween_property(cooldown_meter, "scale", Vector2(1.0, 1.0), 0.2)
	
func _play_recharge_effect() -> void:
	if not cooldown_meter:
		return
		
	cooldown_meter.pivot_offset = cooldown_meter.size / 2.0 
	var tween = create_tween()
	
	# Pop out and flash bright (adjust the Color values to change the flash color)
	tween.tween_property(cooldown_meter, "scale", Vector2(1.2, 1.2), 0.1)
	tween.parallel().tween_property(cooldown_meter, "modulate", Color(1.5, 2.5, 1.5, 1.0), 0.1) 
	
	# Bounce back to normal size and color
	tween.tween_property(cooldown_meter, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cooldown_meter, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
