extends Control

const MAIN_GAME_SCENE = "res://test_world.tscn" 

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
