extends AnimatedSprite2D
class_name PlayerLayer

@onready var base: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")

func _ready():
	texture_filter = TEXTURE_FILTER_NEAREST
	centered = base.centered
	visible = false


func _process(_delta):
	# chưa gắn đồ hoặc layer không có anim này -> ẩn
	if sprite_frames == null or not sprite_frames.has_animation(base.animation):
		visible = false
		return

	visible = true
	if animation != base.animation:
		animation = base.animation
	frame = mini(base.frame, sprite_frames.get_frame_count(animation) - 1)
	frame_progress = base.frame_progress

	# bám đúng sprite gốc
	position = base.position
	offset = base.offset
	flip_h = base.flip_h
	flip_v = base.flip_v
	scale = base.scale
	modulate = base.modulate


# Tạo SpriteFrames từ sheet của layer: copy cấu trúc của sprite gốc,
# chỉ thay ảnh atlas (sheet layer phải cùng bố cục với sheet gốc)
func set_sheets(sheet_map: Dictionary) -> void:
	# sheet_map: {base_atlas_texture: layer_atlas_texture}
	if sheet_map.is_empty():
		sprite_frames = null
		return

	var src: SpriteFrames = base.sprite_frames
	var out := SpriteFrames.new()
	out.remove_animation("default")

	for an in src.get_animation_names():
		out.add_animation(an)
		out.set_animation_speed(an, src.get_animation_speed(an))
		out.set_animation_loop(an, src.get_animation_loop(an))

		for i in src.get_frame_count(an):
			var tex = src.get_frame_texture(an, i)
			var dur := src.get_frame_duration(an, i)

			if tex is AtlasTexture and sheet_map.has(tex.atlas):
				var at := AtlasTexture.new()
				at.atlas = sheet_map[tex.atlas]
				at.region = tex.region
				out.add_frame(an, at, dur)
			elif sheet_map.has(tex):          # anim dùng cả ảnh (showitem)
				out.add_frame(an, sheet_map[tex], dur)
			else:
				out.add_frame(an, null, dur)  # layer không phủ anim này -> trống

	sprite_frames = out
