extends CharacterBody3D

@onready var body = $CollisionShape3D
@onready var notifier = $interacter/notifier
@onready var interact = $Camera3D/interact
@onready var cursor = $cursor
@export var mouse_sens = 0.002

# --- Audio Node References ---
@onready var footsteps = $Footsteps

const SPEED = 5.0
const JUMP_VELOCITY = 3.2

# --- Head Bobbing Settings ---
@onready var camera = $Camera3D
@onready var default_cam_height: float = camera.position.y

var bob_time: float = 0.0
var current_bob_intensity: float = 0.0

# Subtle breathing settings for when standing still
const IDLE_BOB_SPEED: float = 4.0
const IDLE_BOB_AMOUNT: float = 0.03

# Step cadence settings for when walking/running
const WALK_BOB_SPEED: float = 15.0
const WALK_BOB_AMOUNT: float = 0.08

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
	# 1. If the game engine is paused, stop camera look calculations completely
	if get_tree().paused:
		return
		
	# 2. Only rotate the camera if the mouse mode is actively locked/captured
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		camera.rotate_x(-event.relative.y * mouse_sens)
		camera.rotation.x = clamp(camera.rotation.x, -1.2, 1.2)

func _physics_process(delta: float) -> void:
	# 3. Freeze character physics when the game is paused
	if get_tree().paused:
		return

	check_ray_hit()
	
	# Add the gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Get movement vector
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	move_and_slide()

	# Audio Logic: Play sound if moving on the floor, kill it if still or mid-air
	if direction != Vector3.ZERO and is_on_floor():
		if not footsteps.playing:
			footsteps.play()
	else:
		footsteps.stop()

	# Dynamic, seamless head bobbing calculations
	_handle_head_bob(delta, direction)

func _handle_head_bob(delta: float, direction: Vector3) -> void:
	if is_on_floor():
		if direction != Vector3.ZERO:
			# Moving: Progress the time wave at walking speed
			bob_time += delta * WALK_BOB_SPEED
			# Smoothly slide the intensity up to the walking amount
			current_bob_intensity = lerp(current_bob_intensity, WALK_BOB_AMOUNT, delta * 5.0)
			
			var bob_offset = sin(bob_time) * current_bob_intensity
			camera.position.y = default_cam_height + bob_offset
		else:
			# Stationary: Progress the time wave at idle speed
			bob_time += delta * IDLE_BOB_SPEED
			# Smoothly slide the intensity down to the idle breathing amount
			current_bob_intensity = lerp(current_bob_intensity, IDLE_BOB_AMOUNT, delta * 5.0)
			
			var bob_offset = sin(bob_time) * current_bob_intensity
			camera.position.y = default_cam_height + bob_offset
	else:
		# Mid-air safety line: smoothly reset camera and intensity to default baseline
		current_bob_intensity = lerp(current_bob_intensity, 0.0, delta * 10.0)
		camera.position.y = lerp(camera.position.y, default_cam_height, delta * 10.0)
