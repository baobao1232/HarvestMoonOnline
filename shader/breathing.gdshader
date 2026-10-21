shader_type canvas_item;

uniform float intensity = 1.5;
uniform float speed = 2.0;

void vertex() {
	float t = TIME * speed;

	float mask = 1.0 - UV.y;
	mask = smoothstep(0.3, 1.0, mask);

	float offset = sin(t) * intensity * mask;

	VERTEX.y -= offset;
}