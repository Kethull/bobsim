shader_type canvas_item;

uniform vec3 atmosphere_color : source_color = vec3(0.4, 0.7, 1.0);

void fragment() {
    COLOR = vec4(atmosphere_color, 0.5);
}