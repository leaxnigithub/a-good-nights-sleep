extends Button

# The scale size when hovered (1.1 means 110% size)
@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
# The default normal size (1.0 means 100% size)
@export var normal_scale: Vector2 = Vector2(1.0, 1.0)
# How fast the animation transitions (in seconds)
@export var duration: float = 0.15

# --- NEW: Reference to your audio player node ---
# Assumes 'buttonclick' is a child of this button. Change path if it's somewhere else!
@onready var hover_sound: AudioStreamPlayer2D = $"../../buttonclick"

var tween: Tween

func _ready() -> void:
	# Automatically calculate the center pivot point
	pivot_offset = size / 2.0
	
	# Connect the mouse hover signals automatically
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Safety check: Recalculate pivot if the button changes size dynamically
	item_rect_changed.connect(func(): pivot_offset = size / 2.0)


func _on_mouse_entered() -> void:
	# --- NEW: Play the hover sound effect ---
	if hover_sound:
		hover_sound.play()

	if tween:
		tween.kill()
	
	# Create a smooth transition to the larger size
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", hover_scale, duration)


func _on_mouse_exited() -> void:
	if tween:
		tween.kill()
		
	# Create a smooth transition back to normal size
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", normal_scale, duration)
