extends Control

# Replace this path with the actual path to your dark world scene file!
const MAIN_GAME_SCENE = "res://test_world" 

func _on_start_button_pressed() -> void:
	# This loads your actual game world when "Start Game" is clicked
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)

func _on_quit_button_pressed() -> void:
	# This closes the game when "Quit" is clicked
	get_tree().quit()
