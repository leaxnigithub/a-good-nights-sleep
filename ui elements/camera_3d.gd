extends Camera3D

var time_passed: float = 0.0

func _process(delta: float) -> void:
	time_passed += delta
	# Create a very slow, subtle handheld camera breathing effect
	transform.origin.x += sin(time_passed * 0.5) * 0.001
	transform.origin.y += cos(time_passed * 0.4) * 0.001
