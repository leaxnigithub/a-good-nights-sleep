shader_type spatial;
// Unshaded means lighting doesn't affect it. Depth_test_disabled puts it OVER everything.
render_mode unshaded, depth_test_disabled;

uniform sampler2D effect_texture : repeat_enable;
uniform vec4 effect_color : source_color = vec4(1.0);
uniform vec2 scroll_speed = vec2(0.0, 0.0);

// These control the "clear circle" in the middle of the screen
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_outer : hint_range(0.0, 2.0) = 0.8;

// We will change this from 0.0 to 1.0 in the Player script!
uniform float effect_intensity : hint_range(0.0, 1.0) = 0.0; 

void fragment() {
    // 1. Lock UVs to the screen so they don't stretch with camera FOV
    vec2 screen_coords = SCREEN_UV;
    
    // 2. Scroll the texture over time based on our speed
    vec2 moving_uv = screen_coords + (TIME * scroll_speed);
    
    // 3. Sample your asset (wind lines or blood veins)
    vec4 tex_color = texture(effect_texture, moving_uv);
    
    // 4. Create a circular mask in the center (Vignette)
    float dist = distance(screen_coords, vec2(0.5));
    float vignette = smoothstep(vignette_inner, vignette_outer, dist);
    
    // 5. Apply colors and combine. 
    // Intensity allows us to fade the whole thing in/out via script.
    ALBEDO = tex_color.rgb * effect_color.rgb;
    ALPHA = tex_color.a * vignette * effect_intensity * effect_color.a;
}