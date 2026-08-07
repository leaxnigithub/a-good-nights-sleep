extends CharacterBody3D

# --- Shaders ---
const STUN_OUTLINE = preload("res://shaders/stun_wave_mat.tres") # Make sure this matches your file name!

# --- Status Effect Tracking ---
var speed_multiplier: float = 1.0

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var face_light: SpotLight3D = $FaceLight
# --- Reference to the eye raycast ---
@onready var los_ray: RayCast3D = $RayCast3D

# Audio node connections
@onready var spotted_sound: AudioStreamPlayer3D = $SpottedSound
@onready var kill_sound: AudioStreamPlayer3D = $KillSound

@export var player: Node3D 

# --- Speed Settings Per State ---
const WANDER_SPEED: float = 1.5
const CHASE_SPEED: float = 4.0

# --- Smooth Movement & Rotation Settings ---
@export var acceleration: float = 3.0  
@export var turn_speed: float = 10.0   

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
@export var chase_delay_duration: float = 1.2 
var chase_delay_timer: float = 0.0
var is_chase_starting: bool = false
# --- Tracks if the player is currently sitting inside our physical detection triggers ---
var player_in_range: bool = false

@export var wander_radius: float = 10.0
@export var de_aggro_duration: float = 3.0 

func _ready() -> void:
	if not player:
		player = get_node_or_null("../player")

	# --- Re-enabled proximity area tracking connections ---
	var proximity_area = $proximityarea
	if proximity_area:
		proximity_area.body_entered.connect(_on_proximityarea_body_entered)
		proximity_area.body_exited.connect(_on_proximityarea_body_exited)
	else:
		push_error("Enemy Error: Missing 'proximityarea' child node!")
	
	var kill_zone = $killzone
	if kill_zone:
		kill_zone.body_entered.connect(_on_killzone_body_entered)
	else:
		push_error("Enemy Error: Missing 'killzone' child node!")
	
	if not face_light:
		push_warning("Enemy Warning: Missing 'FaceLight' child node! Visual light transitions will not occur.")
	else:
		face_light.light_color = Color("#ffdf6d")
	
	# Verify raycast is configured
	if not los_ray:
		push_error("Enemy Error: Please add a RayCast3D child named 'RayCast3D' to your enemy node!")
	
	_set_new_random_wander_target()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# --- Continuous Line of Sight scanning logic ---
	_check_line_of_sight_logic()

	match current_state:
		State.WANDERING:
			_process_wandering_state(delta)
		State.CHASING:
			_process_chasing_state(delta)
		State.DE_AGGRO:
			_process_de_aggro_state(delta)

	# --- FIXED: Backup safety check to kill player if they are overlapping the killzone ---
	var kill_zone = $killzone
	if kill_zone and kill_zone.has_overlapping_bodies():
		for body in kill_zone.get_overlapping_bodies():
			if body.is_in_group("player"):
				_on_killzone_body_entered(body)

	move_and_slide()


# --- LINE OF SIGHT METHOD ---
func _check_line_of_sight_logic() -> void:
	if not player or not los_ray:
		return

	if player_in_range:
		var target_world_position = player.global_position + Vector3(0, 1.5, 0)
		los_ray.target_position = los_ray.to_local(target_world_position)
		los_ray.force_raycast_update()
		
		if los_ray.is_colliding():
			var collider = los_ray.get_collider()
			
			if collider.is_in_group("enemy") or collider == self:
				return 
				
			if collider == player:
				if current_state != State.CHASING:
					print("Player visual path confirmed clear! Initiating aggro.")
					_trigger_chase_state()
			else:
				var distance_to_player = global_position.distance_to(player.global_position)
				if current_state == State.CHASING and distance_to_player > 1.5:
					print("Player broke visual tracking line via geometry wall! Going to alert state.")
					_trigger_de_aggro_state()


# --- HELPER FUNCTIONS FOR CLEAN SEAMLESS TRANSITIONS ---
func _trigger_chase_state() -> void:
	if current_state != State.CHASING:
		is_chase_starting = true
		chase_delay_timer = chase_delay_duration
		
		if spotted_sound:
			spotted_sound.play()
		if face_light:
			face_light.light_color = Color.RED
			
	current_state = State.CHASING


func _trigger_de_aggro_state() -> void:
	is_chase_starting = false 
	current_state = State.DE_AGGRO
	de_aggro_timer = de_aggro_duration
	
	if face_light:
		face_light.light_color = Color.DARK_ORANGE
	if player:
		nav.set_target_position(player.global_position)


# --- STATE PROCESSING MANAGEMENT ---
func _process_wandering_state(delta: float) -> void:
	if is_waiting:
		wait_timer -= delta
		rotate_y(sin(Time.get_ticks_msec() * 0.002) * 0.01)
		
		if wait_timer <= 0:
			is_waiting = false
			_set_new_random_wander_target()
		
		_move_towards_nav_target(WANDER_SPEED)
		return 

	wander_timer -= delta
	
	if nav.is_navigation_finished() or wander_timer <= 0:
		if randf() < 0.6: 
			is_waiting = true
			wait_timer = randf_range(1.5, 3.5) 
		else:
			_set_new_random_wander_target()
		
	_move_towards_nav_target(WANDER_SPEED)


func _process_chasing_state(delta: float) -> void:
	is_waiting = false 
	
	if not player:
		return

	nav.set_target_position(player.global_position)

	if is_chase_starting:
		chase_delay_timer -= delta
		
		var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_to(target_pos) > 0.1:
			var target_basis = transform.looking_at(target_pos, Vector3.UP).basis
			transform.basis = transform.basis.slerp(target_basis, turn_speed * delta)
		
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)
		
		if chase_delay_timer <= 0:
			is_chase_starting = false
		return

	_move_towards_nav_target(CHASE_SPEED)


func _process_de_aggro_state(delta: float) -> void:
	de_aggro_timer -= delta
	
	if nav.is_navigation_finished() or de_aggro_timer <= 0:
		current_state = State.WANDERING
		is_waiting = true
		wait_timer = randf_range(2.0, 4.0) 
		
		if face_light:
			face_light.light_color = Color("#ffdf6d")
	else:
		_move_towards_nav_target(WANDER_SPEED)


# --- PHYSICAL NAVIGATION MOTOR ---
func _move_towards_nav_target(speed: float) -> void:
	var delta = get_physics_process_delta_time()

	if nav.is_navigation_finished() or is_waiting:
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)
		return
		
	var next_location = nav.get_next_path_position()
	var target_pos = Vector3(next_location.x, global_position.y, next_location.z)
	
	if global_position.distance_to(target_pos) > 0.1:
		var target_basis = transform.looking_at(target_pos, Vector3.UP).basis
		transform.basis = transform.basis.slerp(target_basis, turn_speed * delta)
	
	var target_velocity = (next_location - global_position).normalized() * (speed * speed_multiplier)
	
	velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)


func _set_new_random_wander_target() -> void:
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(4, wander_radius)
	var target_vector = global_position + Vector3(random_dir.x, 0, random_dir.y)
	
	nav.set_target_position(target_vector)
	wander_timer = randf_range(6.0, 12.0) 


# --- PHYSICAL BODY HITBOX DETECTORS ---
func _on_proximityarea_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true 


func _on_proximityarea_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false 
		if current_state == State.CHASING:
			_trigger_de_aggro_state()


func _on_killzone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if kill_sound:
			kill_sound.play()
			
		var death_screen = get_node_or_null("/root/TestWorld/DeathScreen")
		if death_screen:
			death_screen.player_died()
		else:
			get_tree().reload_current_scene()
			
# --- STATUS EFFECTS (FIXED VISUALS) ---
func apply_echo_slow(duration: float) -> void:
	if speed_multiplier < 1.0:
		return 
		
	print("Enemy deafened by mega pulse! Slowing down...")
	speed_multiplier = 0.4 
	
	var original_energy = 0.0
	var original_color = Color("#ffdf6d")
	
	if face_light:
		original_energy = face_light.light_energy
		original_color = face_light.light_color 
		face_light.light_energy = original_energy * 0.2
		face_light.light_color = Color.RED 
		
	await get_tree().create_timer(duration).timeout
	
	speed_multiplier = 1.0
	
	if face_light:
		face_light.light_energy = original_energy
		face_light.light_color = original_color
