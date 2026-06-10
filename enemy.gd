extends CharacterBody3D

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var face_light: SpotLight3D = $FaceLight

# Audio node connections
@onready var spotted_sound: AudioStreamPlayer3D = $SpottedSound
@onready var kill_sound: AudioStreamPlayer3D = $KillSound

@export var player: Node3D 

# --- Speed Settings Per State ---
const WANDER_SPEED: float = 1.5
const CHASE_SPEED: float = 4.0

# --- Smooth Movement & Rotation Settings ---
@export var acceleration: float = 3.0  # Lowered slightly to make the startup chase build-up feel heavier
@export var turn_speed: float = 10.0   # Higher values = faster/snappier turning

# --- State Machine Setup ---
enum State { WANDERING, CHASING, DE_AGGRO }
var current_state: State = State.WANDERING

# --- State Helper Variables ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var wander_timer: float = 0.0
var de_aggro_timer: float = 0.0

# --- Looking Around Mechanics ---
var is_waiting: bool = false
var wait_timer: float = 0.0

# --- Spotting / Reaction Mechanics ---
@export var chase_delay_duration: float = 1.2 # Time spent frozen staring at the player before accelerating
var chase_delay_timer: float = 0.0
var is_chase_starting: bool = false

@export var wander_radius: float = 10.0
@export var de_aggro_duration: float = 3.0 # Time spent searching last known position before giving up

func _ready() -> void:
	# Automatically find the player if not manually dragged into the Inspector slot
	if not player:
		player = get_node_or_null("../player")

	# Connect the proximityarea body signals (using your modified single-underscore names)
	var proximity_area = $proximityarea
	if proximity_area:
		proximity_area.body_entered.connect(_on_proximityarea_body_entered)
		proximity_area.body_exited.connect(_on_proximityarea_body_exited)
	else:
		push_error("Enemy Error: Missing 'proximityarea' child node!")
	
	# Connect the killzone body signal (using your modified single-underscore name)
	var kill_zone = $killzone
	if kill_zone:
		kill_zone.body_entered.connect(_on_killzone_body_entered)
	else:
		push_error("Enemy Error: Missing 'killzone' child node!")
	
	# Verify that the FaceLight exists to avoid null pointer crashes later
	if not face_light:
		push_warning("Enemy Warning: Missing 'FaceLight' child node! Visual light transitions will not occur.")
	else:
		# Set initial patrol light color (Sickly Yellow/Amber)
		face_light.light_color = Color("#ffdf6d")
	
	# Start the enemy off with a wander target
	_set_new_random_wander_target()


func _physics_process(delta: float) -> void:
	# Stop everything if the game engine is paused
	if get_tree().paused:
		return

	# Apply world gravity forces
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# Process behavior based on what the enemy is currently doing
	match current_state:
		State.WANDERING:
			_process_wandering_state(delta)
		State.CHASING:
			_process_chasing_state(delta)
		State.DE_AGGRO:
			_process_de_aggro_state(delta)

	# Execute final physical movement calculated in the states
	move_and_slide()


# --- STATE PROCESSING MANAGEMENT ---

func _process_wandering_state(delta: float) -> void:
	# If looking around, handle pause timers and subtle scanning rotation
	if is_waiting:
		wait_timer -= delta
		
		# Slowly drift rotation left and right back/forth while searching
		rotate_y(sin(Time.get_ticks_msec() * 0.002) * 0.01)
		
		if wait_timer <= 0:
			is_waiting = false
			_set_new_random_wander_target()
		
		_move_towards_nav_target(WANDER_SPEED)
		return 

	wander_timer -= delta
	
	# If enemy reaches the current point or takes too long, stop to scan or pick a new point
	if nav.is_navigation_finished() or wander_timer <= 0:
		if randf() < 0.6: # 60% chance to pause and look around naturally
			is_waiting = true
			wait_timer = randf_range(1.5, 3.5) 
			print("Enemy stopped to scan area...")
		else:
			_set_new_random_wander_target()
		
	_move_towards_nav_target(WANDER_SPEED)


func _process_chasing_state(delta: float) -> void:
	is_waiting = false # Break out of waiting states instantly if player spotted
	
	if not player:
		return

	# Continually update the pathing target to map directly to the player's vector coordinates
	nav.set_target_position(player.global_transform.origin)

	# Handle the dynamic "shocked pause" mechanic upon tracking target
	if is_chase_starting:
		chase_delay_timer -= delta
		
		# Turn directly on the spot to face the player while frozen
		var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_to(target_pos) > 0.1:
			var target_basis = transform.looking_at(target_pos, Vector3.UP).basis
			transform.basis = transform.basis.slerp(target_basis, turn_speed * delta)
		
		# Force full horizontal deceleration during the scare-frame window
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)
		
		if chase_delay_timer <= 0:
			is_chase_starting = false
			print("Stare delay complete. Initiating acceleration pursuit!")
		return

	_move_towards_nav_target(CHASE_SPEED)


func _process_de_aggro_state(delta: float) -> void:
	de_aggro_timer -= delta
	
	# If arrived at player's last known spot or timeout occurs, give up chase
	if nav.is_navigation_finished() or de_aggro_timer <= 0:
		print("Lost player track completely. Returning to patrol.")
		current_state = State.WANDERING
		is_waiting = true
		wait_timer = randf_range(2.0, 4.0) # Look around cautiously where they lost you
		
		# Reset light back to default safe color
		if face_light:
			face_light.light_color = Color("#ffdf6d")
	else:
		_move_towards_nav_target(WANDER_SPEED)


# --- PHYSICAL NAVIGATION MOTOR ---

func _move_towards_nav_target(speed: float) -> void:
	var delta = get_physics_process_delta_time()

	# Handle smooth deceleration to a full stop when idle or arrived
	if nav.is_navigation_finished() or is_waiting:
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)
		return
		
	var next_location = nav.get_next_path_position()
	var target_pos = Vector3(next_location.x, global_position.y, next_location.z)
	
	# Smoothly slerp character basis towards path targets
	if global_position.distance_to(target_pos) > 0.1:
		var target_basis = transform.looking_at(target_pos, Vector3.UP).basis
		transform.basis = transform.basis.slerp(target_basis, turn_speed * delta)
	
	# Extract vectors towards target and apply tracking speed
	var target_velocity = (next_location - global_transform.origin).normalized() * speed
	
	# Natural acceleration interpolations
	velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)


func _set_new_random_wander_target() -> void:
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(4, wander_radius)
	var target_vector = global_transform.origin + Vector3(random_dir.x, 0, random_dir.y)
	
	nav.set_target_position(target_vector)
	wander_timer = randf_range(6.0, 12.0) 


# --- PHYSICAL BODY HITBOX DETECTORS ---

func _on_proximityarea_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Trigger the dramatic reaction pause only if transition occurs outside an active chase
		if current_state != State.CHASING:
			print("Player spotted! Locking position to track target configuration...")
			is_chase_starting = true
			chase_delay_timer = chase_delay_duration
			
			# Trigger the spotted sound cue
			if spotted_sound:
				spotted_sound.play()
			
			# Flash light to blood red on detection
			if face_light:
				face_light.light_color = Color.RED
			
		current_state = State.CHASING


func _on_proximityarea_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and current_state == State.CHASING:
		print("Player broke line-of-sight! Investigating last known spot.")
		is_chase_starting = false # Drops tracking timers if player dips around corners during freeze
		current_state = State.DE_AGGRO
		de_aggro_timer = de_aggro_duration
		
		# Shift light to alert orange while searching your last known position
		if face_light:
			face_light.light_color = Color.DARK_ORANGE
		
		if player:
			nav.set_target_position(player.global_transform.origin)


func _on_killzone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("Player caught by enemy!")
		
		# Trigger the jumpscare/kill sound
		if kill_sound:
			kill_sound.play()
			
		var death_screen = get_node_or_null("/root/TestWorld/DeathScreen")
		if death_screen:
			death_screen.player_died()
		else:
			# If no death screen exists, reload scene (consider adding a short await if scene switches instantly)
			get_tree().reload_current_scene()
