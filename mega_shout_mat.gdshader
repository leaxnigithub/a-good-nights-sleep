shader_type spatial;
// Unshaded makes it glow in the dark, cull_disabled lets you see the inside of the sphere
render_mode unshaded, cull_disabled, blend_add;

// This creates a slot in the Inspector to drop your image!
uniform sampler2D shout_texture : source_color, filter_nearest;
uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Defaults to Red

void fragment() {
	// Read the pixels of your image based on the sphere's UV mapping
	vec4 tex_color = texture(shout_texture, UV);
	
	// Multiply the texture by our red glow color
	ALBEDO = tex_color.rgb * glow_color.rgb;
	
	// Use the texture's transparency so the black parts are invisible
	ALPHA = tex_color.a * glow_color.a;
}