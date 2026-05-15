extends Area3D

@onready var player = $"../../../enemy"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_shape_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		get_tree().reload_current_scene()
