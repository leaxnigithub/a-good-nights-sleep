shader_type spatial;
// Unshaded makes the glow ignore shadows. 
// blend_add makes it act like pure light added on top of the original enemy model!
render_mode unshaded, blend_add, cull_disabled;

// --- TWEAKABLE SETTINGS ---
// This is the exact parameter your Player script tweens to fade it out!
uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.1, 1.0); 

uniform float vibration_speed = 30.0; // How fast they jitter
uniform float vibration_strength = 0.015; // How far the mesh stretches

uniform float flicker_speed = 25.0; // How fast the electric light pulses
uniform float rim_power = 2.0; // Higher numbers push the glow closer to the edges

void vertex() {
	// --- VIBRATION MATH ---
	// We use the TIME variable and standard sin/cos waves to distort the mesh
	// Adding the VERTEX positions ensures different parts of the body vibrate in different directions
	float noise_x = sin(TIME * vibration_speed + VERTEX.y * 15.0);
	float noise_y = cos(TIME * vibration_speed * 1.3 + VERTEX.x * 15.0);
	float noise_z = sin(TIME * vibration_speed * 0.8 + VERTEX.z * 15.0);
	
	// Apply the chaotic vibration to the actual physical mesh
	vec3 jitter = vec3(noise_x, noise_y, noise_z) * vibration_strength;
	
	// We fade out the physical vibration using the alpha channel, 
	// so as the visual glow fades out, the vibrating smoothly stops too!
	VERTEX += NORMAL * jitter * glow_color.a;
}

void fragment() {
	// --- RIM LIGHT (AURA) MATH ---
	// Dot product calculates where the mesh surface faces away from the camera lens
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// Pow tightens that math so it only hugs the sharpest edges of the model
	float rim_intensity = pow(rim, rim_power);
	
	// --- FLICKER MATH ---
	// A basic sine wave to make the light pulse, remapped to stay between 0.4 and 1.0 
	// (so it never completely turns off between pulses)
	float flicker = (sin(TIME * flicker_speed) + 1.0) * 0.5;
	flicker = mix(0.4, 1.0, flicker);
	
	// --- FINAL OUTPUT ---
	// Multiply the color to make it look extra bright and blown-out
	ALBEDO = glow_color.rgb * 1.5; 
	
	// The final transparency is a mix of the rim light, the flicker, and the master alpha channel!
	ALPHA = glow_color.a * rim_intensity * flicker;
}