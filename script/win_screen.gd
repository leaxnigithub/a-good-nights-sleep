extends Control

@onready var win_layer: CanvasLayer = $win_layer
# Link up the new audio node
@onready var win_sound: AudioStreamPlayer2D = $WinSound

func _ready() -> void:
	# Hide the win menu when the game first boots up
	win_layer.hide()

func player_won() -> void:
	# 1. Play the victory audio track immediately!
	if win_sound:
		win_sound.play()
		
	# Freeze physics/movements and display the victory overlay
	get_tree().paused = true
	win_layer.show()
	
	# Release the mouse so they can click your menu buttons
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_play_again_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://titlescreen.tscn")
