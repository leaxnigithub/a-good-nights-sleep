extends Control

@onready var death_layer: CanvasLayer = $death_layer

func _ready() -> void:
	# Hide it when the game starts
	death_layer.hide()

func player_died() -> void:
	get_tree().paused = true
	death_layer.show()
	# Free the mouse cursor so they can click the retry buttons
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://titlescreen.tscn")
