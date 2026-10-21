extends Sprite2D

enum ShadowType {
	PLAYER,
	TREE,
	BUILDING
}

@export var shadow_type : ShadowType = ShadowType.PLAYER

@export var target_path : NodePath
@export var trunk_path : NodePath
@export var foot_path : NodePath

@export var flatten := 0.35
@export var length_max := 30.0
@export var length_min := 6.0
@export var foot_offset := 0.0

var target
var trunk
var foot


func _ready():
	target = get_node_or_null(target_path)
	trunk = get_node_or_null(trunk_path)
	foot = get_node_or_null(foot_path)

	print("TARGET:", target)
	print("TRUNK:", trunk)
	print("FOOT:", foot)
	# auto tìm sprite nếu target sai
	if target and not (target is Sprite2D or target is AnimatedSprite2D):
		var found = target.find_child("*", true, false)
		if found is Sprite2D or found is AnimatedSprite2D:
			target = found

	modulate = Color(0, 0, 0, 0.5)
	z_index = -1

	centered = true   # 🔥 giữ true


func _process(delta):
	if target == null:
		return

	var dir = ShadowManager.sun_dir
	var h = clamp(ShadowManager.sun_height, 0.0, 1.0)
	var len = lerp(length_max, length_min, h)

	# ===============================
	# 🎨 TEXTURE
	# ===============================
	if target is AnimatedSprite2D:
		var tex = target.sprite_frames.get_frame_texture(target.animation, target.frame)
		if tex == null:
			return
		texture = tex
		flip_h = target.flip_h

	elif target is Sprite2D:
		if target.texture == null:
			return
		texture = target.texture
	else:
		return

	# ===============================
	# 🔥 BASE (FOOT)
	# ===============================
	var base_pos = get_base_position()

	# ===============================
	# 🔥 OFFSET PIVOT CHUẨN
	# ===============================
	var tex_h = texture.get_height()
	offset = Vector2(0, -tex_h * 0.5)   # 🔥 CHỐT

	# ===============================
	# 📍 POSITION
	# ===============================
	var shadow_pos = base_pos + dir * len
	shadow_pos.y += foot_offset

	global_position = shadow_pos

	# ===============================
	# 📐 SHAPE
	# ===============================
	scale = get_shadow_scale()

	# ===============================
	# 🎭 FADE
	# ===============================
	modulate.a = lerp(0.6, 0.2, h)

	visible = h > 0.05


# ===============================
# 🎯 BASE POSITION
# ===============================
func get_base_position() -> Vector2:

	match shadow_type:

		ShadowType.PLAYER:
			if foot:
				return foot.global_position

			if target:
				var parent = target.get_parent()
				if parent:
					return parent.global_position

			return target.global_position

		ShadowType.TREE:
			if trunk:
				return trunk.global_position
			return target.global_position

		ShadowType.BUILDING:
			return target.global_position + Vector2(0, 10)

	return target.global_position


# ===============================
# 📐 SCALE
# ===============================
func get_shadow_scale() -> Vector2:

	match shadow_type:

		ShadowType.PLAYER:
			return Vector2(0.7, flatten)

		ShadowType.TREE:
			return Vector2(1.0, flatten + 0.15)

		ShadowType.BUILDING:
			return Vector2(1.3, flatten + 0.25)

	return Vector2(0.7, flatten)
