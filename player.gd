extends CharacterBody3D

@onready var body = $CollisionShape3D
@onready var notifier = $interacter/notifier
@onready var interact = $Camera3D/interact
@onready var cursor = $cursor

# --- Audio Node References ---
@onready var footsteps = $Footsteps
@onready var jump_grunt = $jumpgrunt  
@onready var jump_woosh = $jumpwoosh  
var mouse_sens: float = 0.002

const SPEED = 5.0
const JUMP_VELOCITY = 3.2

# --- Head Bobbing Settings ---
@onready var camera = $Camera3D
@onready var default_cam_height: float = camera.position.y

var bob_time: float = 0.0
var current_bob_intensity: float = 0.0

const IDLE_BOB_SPEED: float = 2.0
const IDLE_BOB_AMOUNT: float = 0.015
const WALK_BOB_SPEED: float = 12.0
const WALK_BOB_AMOUNT: float = 0.06

# --- Echolocation Ability Settings ---
@export var max_echo_distance: float = 30.0
@export var echo_speed: float = 15.0       
@export var echo_cooldown: float = 3.0

var is_echoing: bool = false
var current_echo_radius: float = 0.0
var cooldown_timer: float = 0.0
var pulse_sphere: MeshInstance3D

# Preload your outline materials
var enemy_mat = preload("res://enemy_outline_mat.tres")

# Track objects highlighted during the current active pulse
var highlighted_objects: Array = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
		
	if Input.is_key_pressed(KEY_E) and cooldown_timer <= 0 and not is_echoing:
		start_echolocation_pulse()

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
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
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
			current_bob_intensity = lerp(current_bob_intensity, WALK_BOB_AMOUNT, delta * 5.0)
			camera.position.y = default_cam_height + sin(bob_time) * current_bob_intensity
		else:
			bob_time += delta * IDLE_BOB_SPEED
			current_bob_intensity = lerp(current_bob_intensity, IDLE_BOB_AMOUNT, delta * 5.0)
			camera.position.y = default_cam_height + sin(bob_time) * current_bob_intensity
	else:
		camera.position.y = lerp(camera.position.y, default_cam_height, delta * 10.0)


# =================================================================
#               ECHOLOCATION PULSE CORE SYSTEM
# =================================================================

func start_echolocation_pulse() -> void:
	is_echoing = true
	current_echo_radius = 0.0
	highlighted_objects.clear()
	cooldown_timer = echo_cooldown
	print("Echolocation ping sent!")
	
	# Create the visual traveling wave sphere
	pulse_sphere = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	pulse_sphere.mesh = sphere_mesh
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.15) # Soft translucent white aura
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	pulse_sphere.material_override = mat
	get_tree().root.add_child(pulse_sphere)
	pulse_sphere.global_position = global_position


func _process_echo_pulse(delta: float) -> void:
	current_echo_radius += echo_speed * delta
	
	# Scale the visual sphere outward to match the logic radius
	if is_instance_valid(pulse_sphere):
		pulse_sphere.scale = Vector3(current_echo_radius, current_echo_radius, current_echo_radius)
		
		# Fade the sphere's opacity as it stretches further away
		var sphere_mat = pulse_sphere.material_override as StandardMaterial3D
		if sphere_mat:
			var alpha = remap(current_echo_radius, 0.0, max_echo_distance, 0.15, 0.0)
			sphere_mat.albedo_color.a = clamp(alpha, 0.0, 0.15)
	
	if current_echo_radius >= max_echo_distance:
		is_echoing = false
		if is_instance_valid(pulse_sphere):
			pulse_sphere.queue_free()
		return

	# Gather all nodes assigned to the "enemy" group
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy is MeshInstance3D and not enemy in highlighted_objects:
			_check_and_highlight_enemy(enemy)
		else:
			var mesh_node = enemy.get_node_or_null("MeshInstance3D") as MeshInstance3D
			if mesh_node and not mesh_node in highlighted_objects:
				_check_and_highlight_enemy(mesh_node)


func _check_and_highlight_enemy(mesh_node: MeshInstance3D) -> void:
	var distance = global_position.distance_to(mesh_node.global_position)
	
	# Check if the expanding radius ring is currently washing over the mesh
	if distance <= current_echo_radius and distance >= (current_echo_radius - 3.0):
		if enemy_mat:
			highlighted_objects.append(mesh_node)
			mesh_node.material_override = enemy_mat
			
			# Clean tween callback method binding to prevent syntax errors
			var tween = create_tween()
			tween.tween_interval(1.5)
			tween.tween_callback(_clear_enemy_highlight.bind(mesh_node))


func _clear_enemy_highlight(mesh_node: MeshInstance3D) -> void:
	if is_instance_valid(mesh_node):
		mesh_node.material_override = null
