shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.3, 0.5, 1.0, 0.7);
uniform float glow_size : hint_range(0.0, 0.5, 0.01) = 0.1; // Relative to the sprite size
uniform float falloff : hint_range(0.1, 5.0, 0.1) = 1.5; // Controls how quickly the glow fades

void fragment() {
    vec2 centered_uv = UV - vec2(0.5); // Center UV coordinates
    float dist_from_center = length(centered_uv); // Distance from the center (0.0 to ~0.707)

    // The 'planet' is assumed to be a circle filling most of the UV space.
    // Let's define the planet's radius as slightly less than 0.5 (e.g., 0.45)
    // to allow the glow to be visible around it.
    float planet_radius = 0.5 - glow_size; // Radius of the planet itself

    // Calculate glow intensity based on distance from the planet's edge
    // The glow starts from planet_radius and extends outwards up to planet_radius + glow_size
    float glow_intensity = smoothstep(planet_radius + glow_size, planet_radius, dist_from_center);
    
    // Apply falloff to the glow
    glow_intensity = pow(glow_intensity, falloff);

    // Get the original texture color
    vec4 tex_color = texture(TEXTURE, UV);

    // Blend the glow with the texture color.
    // If the texture has alpha, we want the glow to be behind it.
    // If the texture is opaque, the glow will mostly be around the edges.
    // For a simple ColorRect, tex_color.a will be 1.0, and tex_color.rgb will be the rect's color.
    
    // Final color is the glow color, with its alpha determined by glow_intensity,
    // then composited over the original texture color.
    // This makes the glow appear "around" or "behind" the existing sprite content.
    vec3 final_rgb = mix(tex_color.rgb, glow_color.rgb, glow_intensity * glow_color.a);
    float final_alpha = tex_color.a + (1.0 - tex_color.a) * glow_intensity * glow_color.a;
    
    // A simpler approach if you want the glow to just add to whatever is there:
    // COLOR = tex_color + vec4(glow_color.rgb * glow_intensity, glow_intensity * glow_color.a);

    // If the original texture has transparency, we want the glow to show through.
    // The glow should be strongest where the original texture is transparent but within the glow radius.
    float combined_alpha = tex_color.a + glow_intensity * glow_color.a * (1.0 - tex_color.a);

    COLOR = vec4(mix(tex_color.rgb, glow_color.rgb, glow_intensity * glow_color.a * (1.0 - tex_color.a) / combined_alpha), combined_alpha);
    // If original pixel is opaque, glow is not added to RGB, only alpha might change if glow extends beyond.
    // If original pixel is transparent, glow color is fully visible.
    if (tex_color.a > 0.01) { // If original pixel is mostly opaque
        // Soften the edge of the sprite itself slightly into the glow
        float edge_softness = smoothstep(planet_radius, planet_radius - 0.02, dist_from_center);
        COLOR = mix(vec4(glow_color.rgb, glow_color.a * glow_intensity), tex_color, edge_softness);
        COLOR.a = tex_color.a + glow_intensity * glow_color.a * (1.0 - tex_color.a);
    } else { // Original pixel is transparent, just show glow
        COLOR = vec4(glow_color.rgb, glow_intensity * glow_color.a);
    }

    // Ensure the planet itself (if drawn by this shader on a ColorRect) is solid
    if (dist_from_center < planet_radius) {
         // If no texture, draw a solid planet color, otherwise use texture
        if (length(TEXTURE_PIXEL_SIZE) == 0.0) { // No texture bound
             COLOR = vec4(0.2,0.2,0.2,1.0); // Default planet color if no texture
        } else {
            COLOR = tex_color; // Use the texture for the planet body
        }
    }


}