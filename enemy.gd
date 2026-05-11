extends CharacterBody3D
@onready var nav = $NavigationAgent3D
@onready var player = $"../player"
const SPEED = 3.0

func update_location(target_location):
	nav.set_target_location(target_location)

func _physics_process(delta: float) -> void:
	nav.set_target_position(player.global_transform.origin)
	var next_location = nav.get_next_path_position()
	var new_velocity = (next_location-global_transform.origin).normalized() * SPEED
	
	velocity = new_velocity
	move_and_slide()
	
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_deferred("reload_current_scene")
