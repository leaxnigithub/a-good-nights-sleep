extends Node3D

const MAIN_GAME_SCENE = "res://scenes/test_world.tscn" 

func _on_start_pressed() -> void:
	# 1. Write the destination to the Global script
	Global.target_scene_path = MAIN_GAME_SCENE
	
	# 2. Send the player to the loading screen!
	# (Make sure this path perfectly matches where you saved your loading screen scene)
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()

@onready var camera = $Camera3D
@onready var default_cam_height: float = camera.position.y # Store where the camera starts

var bob_time: float = 0.0
@export var bob_speed: float = 1.5   # How fast it bobs up and down
@export var bob_amount: float = 0.2  # How far up and down it travels

func _ready() -> void:
	# Make sure the mouse is visible for the UI buttons
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if not camera:
		return
		
	# 1. Advance the timer
	bob_time += delta * bob_speed
	
	# 2. Apply the up-and-down sine wave to the camera's Y position
	camera.position.y = default_cam_height + (sin(bob_time) * bob_amount)
