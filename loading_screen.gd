extends Control

@onready var progress_bar = $ColorRect/VBoxContainer/TextureProgressBar
@onready var radar_icon = $ColorRect/VBoxContainer/RadarIcon

var is_switching: bool = false

func _ready() -> void:
	# 1. FADE IN ANIMATION
	# Start completely transparent (alpha = 0)
	modulate = Color(1.0, 1.0, 1.0, 0.0) 
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	
	# 2. START LOADING
	if Global.target_scene_path != "":
		ResourceLoader.load_threaded_request(Global.target_scene_path)
	else:
		print("Error: No target scene was set in the Global script!")

func _process(delta: float) -> void:
	# 3. SPINNING RADAR ANIMATION
	if radar_icon:
		# Multiply by delta to ensure it spins at the exact same speed on all computers
		radar_icon.rotation += 3.0 * delta 
		
	if Global.target_scene_path == "" or is_switching:
		return
		
	var progress = []
	var load_status = ResourceLoader.load_threaded_get_status(Global.target_scene_path, progress)
	
	match load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0
			
		ResourceLoader.THREAD_LOAD_LOADED:
			# Stop the loading checks and trigger the outro animation!
			is_switching = true
			progress_bar.value = 100.0
			_transition_to_scene()
			
		ResourceLoader.THREAD_LOAD_FAILED:
			print("Error: Could not load the scene. Check your file path!")
			set_process(false)

func _transition_to_scene() -> void:
	# 1. Force the loading screen to draw on top of everything (including the player's UI)
	z_index = 100
	
	# 2. Grab the finished scene and spawn it in
	var next_scene_resource = ResourceLoader.load_threaded_get(Global.target_scene_path)
	var new_scene = next_scene_resource.instantiate()
	
	# 3. Add the new scene to the game secretly behind this loading screen
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene # Tell the game this is the new main level
	
	# 4. Fade OUT the loading screen to reveal the dungeon underneath!
	var tween = create_tween()
	# Fades out over 1.0 seconds (adjust this number to make it faster or slower)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	
	# 5. Wait for the fade to completely finish
	await tween.finished 
	
	# 6. Delete the loading screen now that we are done with it
	queue_free()
