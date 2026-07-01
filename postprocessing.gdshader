shader_type canvas_item;

// Grabs the render of the entire game behind the UI
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Lower number = more retro/chunky colors. Higher number = smoother.
uniform float color_steps : hint_range(1.0, 32.0, 1.0) = 8.0;

void fragment() {
	vec4 raw_color = texture(screen_texture, SCREEN_UV);
	
	// Math to snap the smooth colors to harsh grid increments
	vec3 posterized = floor(raw_color.rgb * color_steps) / color_steps;
	
	COLOR = vec4(posterized, raw_color.a);
}