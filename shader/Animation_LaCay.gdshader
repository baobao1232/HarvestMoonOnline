shader_type canvas_item;

uniform float strength = 0.03;
uniform float speed = 2.0;

void vertex() {

	float t = TIME * speed;
	float wave = sin(t + VERTEX.y * 0.05);

	VERTEX.x += wave * strength * VERTEX.y;
}