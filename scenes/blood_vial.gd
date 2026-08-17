extends Area3D

@export var heal_amount: float = 35.0

# --- Animation Settings ---
@export var rotation_speed: float = 2.0
@export var bob_speed: float = 3.0
@export var bob_height: float = 0.2

var start_y: float = 0.0
var time_passed: float = 0.0

@onready var mesh = $MeshInstance3D 

func _ready() -> void:
	# Save the starting height so it bobs based on where you placed it in the level
	start_y = global_position.y
	
	# Give the mesh a cool tilted angle at the start
	if mesh:
		mesh.rotation.z = deg_to_rad(15.0) 
		mesh.rotation.x = deg_to_rad(10.0)

func _process(delta: float) -> void:
	time_passed += delta
	
	# 1. Smoothly rotate the tilted mesh
	if mesh:
		mesh.rotate_y(rotation_speed * delta)
		
	# 2. Make the whole vial bob up and down using a sine wave
	global_position.y = start_y + (sin(time_passed * bob_speed) * bob_height)

func _on_body_entered(body: Node3D) -> void:
	# When a body touches the vial, check if it's the player (does it have the add_blood function?)
	if body.has_method("add_blood"):
		body.add_blood(heal_amount) # This calls the function you already made in Player.gd!
		queue_free() # Deletes the vial from the world
