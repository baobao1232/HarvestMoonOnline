shader_type canvas_item;
render_mode blend_add;

uniform vec2 light_pos = vec2(0.5, 0.5);
uniform float radius = 0.5;
uniform float softness = 0.5;
uniform vec4 light_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float intensity = 0.8; // 🔥 giảm mạnh

void fragment() {
    float dist = distance(UV, light_pos);

    // falloff mềm hơn (KHÔNG bị gắt)
    float light = smoothstep(radius, 0.0, dist);

    // làm dịu vùng trung tâm (tránh cháy trắng)
    light = pow(light, 1.5);

    vec3 col = light_color.rgb * light * intensity;

    COLOR = vec4(col, light * 0.8);
}