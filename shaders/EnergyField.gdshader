shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.2, 0.8, 0.2, 0.7);
uniform float intensity : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform float pulse_speed : hint_range(0.1, 5.0, 0.1) = 1.0;
uniform float noise_scale : hint_range(1.0, 50.0, 1.0) = 10.0;
uniform float noise_influence : hint_range(0.0, 1.0, 0.01) = 0.3;

// Simple pseudo-random noise function
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float simple_noise(vec2 uv_scale) {
    vec2 i = floor(uv_scale);
    vec2 f = fract(uv_scale);

    // Smooth interpolation (hermite interpolation)
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = rand(i + vec2(0.0,0.0));
    float b = rand(i + vec2(1.0,0.0));
    float c = rand(i + vec2(0.0,1.0));
    float d = rand(i + vec2(1.0,1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
    // Pulsing effect
    float pulse = (sin(TIME * pulse_speed) + 1.0) / 2.0; // Ranges from 0.0 to 1.0
    pulse = 0.5 + pulse * 0.5; // Make pulse range from 0.5 to 1.0 so it's always somewhat visible

    // Noise effect
    vec2 noise_uv = UV * noise_scale + vec2(TIME * 0.1, TIME * 0.05); // Slowly scrolling noise
    float noise_val = simple_noise(noise_uv);

    // Combine pulse and noise for alpha
    float base_alpha = field_color.a * intensity * pulse;
    float noisy_alpha = mix(base_alpha, base_alpha * noise_val, noise_influence);
    
    // Get texture color if available
    vec4 tex_color = texture(TEXTURE, UV);

    // If texture is present, modulate its alpha. Otherwise, use field_color.rgb.
    if (TEXTURE_PIXEL_SIZE.x > 0.0 || TEXTURE_PIXEL_SIZE.y > 0.0) { // Check if a texture is actually bound
        COLOR = vec4(tex_color.rgb, tex_color.a * noisy_alpha);
    } else {
        COLOR = vec4(field_color.rgb, noisy_alpha);
    }
}