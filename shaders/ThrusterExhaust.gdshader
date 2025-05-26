shader_type canvas_item;

uniform vec2 direction = vec2(0.0, -1.0); // Default direction upwards
uniform float power = 1.0; // Default power
uniform vec4 exhaust_color : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float spread = 0.5;
uniform float particle_size = 0.05;
uniform float lifetime = 1.0;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 p_uv = UV;
    p_uv -= vec2(0.5); // Center UV

    float final_alpha = 0.0;

    for (int i = 0; i < 5; i++) { // 5 particles
        float i_float = float(i);
        vec2 seed = vec2(i_float * 0.1, i_float * 0.23);
        
        float particle_time_offset = rand(seed) * lifetime;
        float current_particle_time = mod(TIME + particle_time_offset, lifetime);
        
        float progress = current_particle_time / lifetime; // 0 to 1

        // Particle movement
        vec2 particle_pos = direction * progress * power;
        
        // Add some spread
        float random_spread_x = (rand(seed + vec2(0.1, 0.0)) - 0.5) * 2.0 * spread * progress; // -spread to +spread
        float random_spread_y = (rand(seed + vec2(0.0, 0.1)) - 0.5) * 0.5 * spread * progress; // Less spread along direction
        
        vec2 perpendicular_dir = vec2(direction.y, -direction.x);
        particle_pos += perpendicular_dir * random_spread_x;
        particle_pos += direction * random_spread_y;

        float dist = distance(p_uv, particle_pos);
        
        float size_factor = mix(particle_size, particle_size * 0.5, progress); // Particle shrinks over time
        float alpha = smoothstep(size_factor, size_factor * 0.8, dist); // Soft particle edge
        alpha *= (1.0 - progress); // Fade out over lifetime

        final_alpha += alpha;
    }
    
    COLOR = vec4(exhaust_color.rgb, clamp(final_alpha, 0.0, 1.0) * exhaust_color.a);
}