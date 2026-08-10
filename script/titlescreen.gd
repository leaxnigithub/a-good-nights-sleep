extends Control

const MAIN_GAME_SCENE = "res://scenes/test_world.tscn" 

func _on_start_pressed() -> void:
	# 1. Write the destination to the Global script
	Global.target_scene_path = MAIN_GAME_SCENE
	
	# 2. Send the player to the loading screen!
	# (Make sure this path perfectly matches where you saved your loading screen scene)
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
