shader_type canvas_item;
render_mode blend_add;

uniform vec2 light_pos = vec2(0.5, 0.5);
uniform float radius = 0.5;
uniform float softness = 1.5;
uniform vec4 light_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float intensity = 1.2;
uniform vec3 compensate = vec3(1.0);   // bù màu CanvasModulate

void fragment() {
	float d = distance(UV, light_pos);
	float l = 1.0 - smoothstep(0.0, radius, d);
	l = pow(l, softness);
	COLOR = vec4(light_color.rgb * l * intensity * compensate, 1.0);
}