shader_type canvas_item;

uniform vec2 shadow_offset = vec2(12.0, 6.0); // hướng bóng (phải + xuống)
uniform float shadow_strength = 0.6;
uniform float blur = 2.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Lấy alpha của sprite gốc
    float alpha = tex.a;

    // Sample vị trí lệch để tạo bóng
    vec2 offset_uv = UV - shadow_offset / TEXTURE_PIXEL_SIZE;

    float shadow = texture(TEXTURE, offset_uv).a;

    // blur nhẹ
    shadow += texture(TEXTURE, offset_uv + vec2(blur) * TEXTURE_PIXEL_SIZE).a;
    shadow += texture(TEXTURE, offset_uv - vec2(blur) * TEXTURE_PIXEL_SIZE).a;
    shadow /= 3.0;

    // màu bóng (đen + alpha)
    vec4 shadow_col = vec4(0.0, 0.0, 0.0, shadow * shadow_strength);

    // vẽ bóng phía sau
    COLOR = shadow_col * (1.0 - alpha) + tex;
}