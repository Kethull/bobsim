shader_type canvas_item;

uniform float intensity : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    COLOR = vec4(0.2, 0.8, 1.0, intensity);
}