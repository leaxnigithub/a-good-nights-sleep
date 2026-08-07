shader_type spatial;
// cull_disabled forces Godot to draw the inside of the sphere!
render_mode unshaded, blend_add, cull_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 wave_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_thickness = 0.15; 

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	// Calculates the distance between the expanding sphere and your walls
	float diff = linear_depth + VERTEX.z; 
	
	// Draws a crisp line ONLY where they are intersecting
	float line = 1.0 - smoothstep(0.0, line_thickness, diff);
	
	ALBEDO = wave_color.rgb;
	ALPHA = line * wave_color.a;
}