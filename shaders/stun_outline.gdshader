shader_type spatial;
// cull_front ensures this outline only draws behind the actual mesh
render_mode cull_front, unshaded;

uniform vec3 outline_color : source_color = vec3(1.0, 1.0, 0.0); // Yellow
uniform float outline_width : hint_range(0.0, 0.2) = 0.04;

void vertex() {
	// Pushes the vertices outward along their normals to make it fatter
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
