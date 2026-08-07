shader_type spatial;
// Unshaded (glows in the dark), ignores walls (depth_test_disabled), and adds light (blend_add)
render_mode unshaded, depth_test_disabled, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Red by default
uniform float edge_power = 2.0; // Higher number = thinner edge outline

void fragment() {
	// Calculates the edges of the mesh based on the camera angle
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), edge_power);
	
	ALBEDO = glow_color.rgb;
	// The alpha is controlled by both the color's alpha slider and the edge detection
	ALPHA = glow_color.a * fresnel;
}