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

# ----- giữ lại để scene cũ không mất giá trị -----
@export var length_max : float = 0.0
@export var length_min : float = 0.0
@export var foot_offset : float = 0.0

# ----- hình dạng bóng -----
@export var flatten : float = 0.35
@export var min_flatten : float = 0.15
@export var skew_max : float = 1.5
@export var skew_min : float = 0.4
@export var alpha_low : float = 0.25
@export var alpha_high : float = 0.45
const LAMP_GROUP := "street_lamp"
@export var lamp_alpha : float = 0.5
@export var lamp_flatten : float = 0.3
@export var lamp_skew_max : float = 1.5
@export var lamp_skew_div : float = 24.0   # nhỏ hơn = bóng ngả dài hơn
var target
var trunk
var foot


func _ready():
	target = get_node_or_null(target_path)
	trunk = get_node_or_null(trunk_path)
	foot = get_node_or_null(foot_path)

	# auto tìm sprite nếu target sai
	if target and not (target is Sprite2D or target is AnimatedSprite2D):
		var found = target.find_child("*", true, false)
		if found is Sprite2D or found is AnimatedSprite2D:
			target = found

	modulate = Color(0, 0, 0, 0.4)
	z_index = -1
	centered = true

func _process(_delta):

	if ShadowManager.indoor:
		visible = false
		return

	if target == null or not is_instance_valid(target):
		return

	var dir: Vector2 = ShadowManager.sun_dir
	var h: float = clampf(float(ShadowManager.sun_height), 0.0, 1.0)

	# ===== TEXTURE =====
	if target is AnimatedSprite2D:
		if target.sprite_frames == null:
			return
		var tex = target.sprite_frames.get_frame_texture(target.animation, target.frame)
		if tex == null:
			return
		texture = tex
		flip_h = target.flip_h
	elif target is Sprite2D:
		if target.texture == null:
			return
		texture = target.texture
		flip_h = target.flip_h
	else:
		return

	offset = Vector2(0, -texture.get_height() * 0.5)

	var base: Vector2 = get_base_position()
	var w: float = get_width_scale()

		# ===== TỐI / CHẠNG VẠNG: bóng từ đèn đường =====
	if h < 0.15:
		var lamp := _find_lamp(base)
		if lamp.is_empty():
			visible = false
			return

		var off: Vector2 = base - lamp.pos
		var dist: float = off.length()
		var dir_l: Vector2 = off / dist if dist > 0.01 else Vector2(0, 1)

		# độ dài bóng: xa đèn thì dài hơn, gần chân đèn thì ngắn
		var len_k: float = clampf(dist / lamp_skew_div, 0.15, lamp_skew_max)

		# cột Y: đỉnh sprite (local y = -1 đơn vị chiều cao) đổ về hướng dir_l
		# dấu "-" vì local y của đỉnh là âm
		var y_axis: Vector2 = -dir_l * len_k

		global_transform = Transform2D(
			Vector2(w, 0.0),
			y_axis,
			base
		)
		modulate.a = lamp_alpha * lamp.k * lamp.k
		visible = true
		return

	# ===== BAN NGÀY: bóng mặt trời (như cũ) =====
	var push: float = lerpf(length_max, length_min, h)
	var origin: Vector2 = base + dir * push
	origin.y += foot_offset

	var sx2: float = dir.x * lerpf(skew_max, skew_min, h)
	var sy: float = lerpf(min_flatten, flatten, absf(dir.y)) * lerpf(1.0, 0.6, h)

	global_transform = Transform2D(
		Vector2(w, 0.0),
		Vector2(-sx2, -sy),
		origin
	)

	modulate.a = lerpf(alpha_low, alpha_high, h)
	visible = true

# ===============================
# BASE POSITION
# ===============================
func get_base_position() -> Vector2:

	match shadow_type:

		ShadowType.PLAYER:
			if foot:
				return foot.global_position
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
# BỀ NGANG
# ===============================
func get_width_scale() -> float:

	match shadow_type:
		ShadowType.PLAYER:
			return 0.85
		ShadowType.TREE:
			return 1.0
		ShadowType.BUILDING:
			return 1.2

	return 1.0
# đèn sáng gần nhất có phủ tới điểm p (k: 0..1, càng gần càng lớn)
func _find_lamp(p: Vector2) -> Dictionary:
	var best := {}
	var best_k := 0.0
	for l in get_tree().get_nodes_in_group(LAMP_GROUP):
		if not l.has_method("get_light_info"):
			continue
		var info: Dictionary = l.get_light_info()
		if info.is_empty():
			continue
		var k: float = 1.0 - p.distance_to(info.pos) / info.radius
		if k > best_k:
			best_k = k
			best = info
			best["k"] = k
	return best
