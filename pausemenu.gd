extends Control

@onready var pause_layer: CanvasLayer = $pause_layer
@onready var pause_main: PanelContainer = $pause_layer/pause_main
@onready var options_menu: PanelContainer = $pause_layer/options_menu

func _ready() -> void:
	# Hide the entire layer when the game starts
	pause_layer.hide()
	options_menu.hide()

func _input(event: InputEvent) -> void:
	# Toggle pause when pressing the Escape key
	if event.is_action_pressed("ui_cancel"): # "ui_cancel" is mapped to ESC by default
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	get_tree().paused = true
	pause_layer.show()
	pause_main.show()
	options_menu.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Make mouse visible to click buttons

func resume_game() -> void:
	get_tree().paused = false
	pause_layer.hide()
	# If your 3D game locks the mouse to look around, turn it back on here:
	# Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- OPTION CONTROLS (Same as Title Screen) ---

func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus_index = AudioServer.get_bus_index("Master")
	if value == 0:
		AudioServer.set_bus_mute(master_bus_index, true)
	else:
		AudioServer.set_bus_mute(master_bus_index, false)
		AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value))
		
# --- BUTTON SIGNALS ---

func _on_resume_pressed() -> void:
	resume_game()


func _on_options_pressed() -> void:
	pause_main.hide()
	options_menu.show()


func _on_quit_pressed() -> void:
	get_tree().paused = false # Unpause before switching scenes!
	get_tree().change_scene_to_file("res://titlescreen.tscn") # Put your title screen path here
