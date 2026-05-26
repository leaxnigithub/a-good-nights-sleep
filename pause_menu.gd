extends Control

@onready var pause_layer: CanvasLayer = $pause_layer
@onready var pause_main: PanelContainer = $pause_layer/pause_main
@onready var options_menu: PanelContainer = $pause_layer/options_menu

func _ready() -> void:
	# Keep the UI hidden on game boot
	pause_layer.hide()

func _input(event: InputEvent) -> void:
	# Intercepts the Escape key globally
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	get_tree().paused = true
	pause_layer.show()
	pause_main.show()
	options_menu.hide()
	# Free the mouse cursor so you can hover and select menu options
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume_game() -> void:
	get_tree().paused = false
	pause_layer.hide()
	
	# 1. Force the UI system to release keyboard/mouse focus from the last clicked button
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus:
		current_focus.release_focus()
		
	# 2. Capture the mouse back into the viewport center
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- BUTTON SIGNALS ---

func _on_resume_pressed() -> void:
	resume_game()

func _on_options_pressed() -> void:
	pause_main.hide()
	options_menu.show()

func _on_back_pressed() -> void:
	options_menu.hide()
	pause_main.show()

func _on_quit_pressed() -> void:
	get_tree().paused = false # Unpause state safety line
	get_tree().change_scene_to_file("res://titlescreen.tscn")

# --- SETTINGS CONTROLS ---

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
