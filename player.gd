extends CharacterBody3D

@onready var options = $options
@onready var body = $CollisionShape3D
@onready var notifier = $interacter/notifier
@onready var interact = $Camera3D/interact
@export var mouse_sens = 0.002

const SPEED = 5.0
const JUMP_VELOCITY = 3.2

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func check_ray_hit() -> void:
	if interact.is_colliding():
		if interact.get_collider().is_in_group("exit"):
			notifier.visible = true
		if Input.is_action_just_pressed("interact"):
			interact.get_collider().queue_free()
			get_tree().reload_current_scene()
	else:
		notifier.visible = false

func _input(event: InputEvent) -> void:
	# 1. If the game engine is paused, stop camera look calculations completely
	if get_tree().paused:
		return
		
	# 2. Only rotate the camera if the mouse mode is actively locked/captured
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		$Camera3D.rotate_x(-event.relative.y * mouse_sens)
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, -1.2, 1.2)

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
