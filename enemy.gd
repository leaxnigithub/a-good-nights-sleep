extends CharacterBody3D

@onready var nav = $NavigationAgent3D
@export var player: Node3D 

const SPEED = 3.0

# A boolean flag to track if the enemy is currently activated
var is_activated: bool = false

# Reference to the player node once they enter the area
var player_node: Node3D = null

# Get gravity from project settings
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	# Fallback to look for the player in the parent scene if not assigned in Inspector
	if not player:
		player = get_node_or_null("../player")

	# Connect the proximity area signals
	var proximity_area = $proximityarea
	proximity_area.body_entered.connect(_on_proximity_area_body_entered)
	proximity_area.body_exited.connect(_on_proximity_area_body_exited)
	
	# Connect the killzone area signal
	var kill_zone = $killzone
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)


func _physics_process(delta: float) -> void:
	# 1. ALWAYS APPLY GRAVITY
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# 2. HANDLE MOVEMENT & LOOK-AT IF ACTIVATED
	if is_activated and player:
		_perform_activated_behavior(delta)
	else:
		# Stop horizontal movement when idle, keep gravity falling force
		velocity.x = 0
		velocity.z = 0

	# 3. ALWAYS RUN PHYSICS
	move_and_slide()


# --- SIGNAL HANDLERS ---

func _on_proximity_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("Player entered enemy detection zone!")
		player_node = body
		is_activated = true


func _on_proximity_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("Player escaped enemy detection zone.")
		player_node = null
		is_activated = false


# This triggers the instant the player touches the enemy's killzone hitbox
func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("Player touched! Reloading scene...")
		get_tree().reload_current_scene()


# --- NAVIGATION BEHAVIOR CODE ---

func _perform_activated_behavior(delta: float) -> void:
	# Update navigation target path toward the player's current position
	nav.set_target_position(player.global_transform.origin)
	
	var next_location = nav.get_next_path_position()
	
	# Actively Look at the Next Path Location (Keeps enemy upright on Y axis)
	var target_pos = Vector3(next_location.x, global_position.y, next_location.z)
	if global_position.distance_to(target_pos) > 0.1:
		look_at(target_pos, Vector3.UP)
	
	# Calculate velocity vector directed toward the next navigation point
	var new_velocity = (next_location - global_transform.origin).normalized() * SPEED
	
	# Apply calculated horizontal velocities, preserving the vertical gravity
	velocity.x = new_velocity.x
	velocity.z = new_velocity.z
