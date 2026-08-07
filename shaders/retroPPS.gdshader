shader_type spatial;
// Unshaded ignores lights. Fog disabled stops the filter from vanishing in fog.
render_mode unshaded, fog_disabled; 

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// --- EXPORTED SETTINGS ---
uniform float pixel_size : hint_range(1.0, 20.0, 1.0) = 2.0;
uniform float levels : hint_range(1.0, 100.0, 1.0) = 16.0;
uniform vec2 gamma = vec2(0.8, 1.2); // X = boundary shift, Y = lightness tuning

void vertex() {
	// Forces the Quad to stretch perfectly over the screen no matter what
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// ==========================================
	// 1. PIXELATION
	// ==========================================
	
	// Find out the exact resolution of the screen
	vec2 text_size = vec2(textureSize(screen_texture, 0));
	
	// Calculate how many pixels we want. 
	// (Multiplied by 2.0 to prevent odd-number division causing weird rectangular lines!)
	vec2 pixel_count = text_size / (pixel_size * 2.0);
	
	// Crunch the smooth UVs into blocky grid steps
	vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count;
	vec4 color = texture(screen_texture, pixelated_uv);

	// ==========================================
	// 2. POSTERIZATION (Color Banding)
	// ==========================================
	
	// Gamma X: Applied BEFORE the crunch to shift where the color boundaries sit
	color.rgb = pow(color.rgb, vec3(gamma.x));
	
	// Find the grayscale value by grabbing the brightest color channel (R, G, or B)
	float grayscale = max(color.r, max(color.g, color.b));
	
	// Calculate the closest available color steps
	float lower = floor(grayscale * levels) / levels;
	float higher = ceil(grayscale * levels) / levels;
	
	// Measure if our original color is closer to the higher step or the lower step
	float lower_diff = abs(lower - grayscale);
	float higher_diff = abs(higher - grayscale);
	float level = lower_diff < higher_diff ? lower : higher;
	
	// Shift the actual image colors to snap to our chosen step
	float adjustment = level / grayscale;
	color.rgb *= adjustment;
	
	// Gamma Y: Applied AFTER to brighten or darken the final retro colors
	color.rgb = pow(color.rgb, vec3(gamma.y));
	
	ALBEDO = color.rgb;
}