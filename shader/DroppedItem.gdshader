shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float outline_size = 1.0;
uniform float glow_strength = 1.0;

uniform vec2 shadow_offset = vec2(0.0, 3.0);
uniform float shadow_alpha = 0.4;

void fragment() {

	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;

	vec2 size = TEXTURE_PIXEL_SIZE * outline_size;

	// ===== OUTLINE =====
	float outline = 0.0;
	outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	outline = step(0.01, outline);

	// ===== SHADOW SAMPLE =====
	vec2 shadow_uv = UV - shadow_offset * TEXTURE_PIXEL_SIZE;
	float shadow = texture(TEXTURE, shadow_uv).a;

	vec4 result = tex;

	// 👉 vẽ shadow phía sau (chỉ khi pixel hiện tại trong suốt)
	if (alpha < 0.1 && shadow > 0.1) {
		result = vec4(0.0, 0.0, 0.0, shadow_alpha);
	}

	// 👉 glow viền (ưu tiên hơn shadow)
	if (alpha < 0.1 && outline > 0.0) {
		result = vec4(glow_color.rgb * glow_strength, 1.0);
	}

	COLOR = result;
}