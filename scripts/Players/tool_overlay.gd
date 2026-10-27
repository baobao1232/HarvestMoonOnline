extends Sprite2D

const FRAMES_JSON := "res://scripts/Players/tool_frames.json"
static var frames_data := {}

# ===== CHẾ ĐỘ CŨ (tool không có tool_frames) =====
const DOWN_ANGLES := [-100.0, -80.0, 60.0]
const UP_DOWN_SCREEN_SCALE := Vector2(0.6, 1.0)
const TOOL_LENGTH_SCALE := 1.5

# Hướng up, FRAME CUỐI: ghi đè vị trí tay cầm (pixel trong khung 32x32) + góc.
# y nhỏ hơn = tool cao hơn, rot -90 = đầu tool chỉ thẳng lên.
const UP_LAST_HAND := Vector2(16, 10)
const UP_LAST_ROT := -90.0

# Đẩy tool ra xa người chơi theo frame (pixel). Key = "use_<hướng>_<frame>".
# Số dương = ra xa hơn theo hướng đang quay mặt.
const FRAME_PUSH := {
	"use_down_3": 0.0,
	"use_up_3": 0.0,
	"use_left_3": 0.0,
	"use_right_3": 0.0,
}

var grip := Vector2.ZERO
var base_angle := -45.0

# ===== CHẾ ĐỘ MỚI =====
var tool_frames: SpriteFrames = null

@onready var anim: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")


func _ready():
	if frames_data.is_empty() and FileAccess.file_exists(FRAMES_JSON):
		frames_data = JSON.parse_string(FileAccess.get_file_as_string(FRAMES_JSON))
	texture_filter = TEXTURE_FILTER_NEAREST
	visible = false
	anim.frame_changed.connect(_update)
	anim.animation_changed.connect(_update)


func set_tool(item) -> void:
	if item == null:
		texture = null
		tool_frames = null
	else:
		texture = item.icon
		grip = item.grip
		base_angle = item.icon_angle
		tool_frames = item.tool_frames
	_update()


func _update():
	var an := String(anim.animation)

	if not an.begins_with("use_"):
		visible = false
		return

	if tool_frames != null:
		_update_synced(an)
	else:
		_update_legacy(an)


# ===============================
# HELPER
# ===============================

# "use_hoe_down" -> "down" | "use_down" -> "down"
func _dir_of(an: String) -> String:
	return an.rsplit("_", true, 1)[1]


# frame hiện tại có phải frame cuối của anim không
func _is_last_frame() -> bool:
	return anim.frame >= anim.sprite_frames.get_frame_count(anim.animation) - 1


# offset đẩy tool ra phía trước người chơi theo hướng + frame
func _push_offset(an: String) -> Vector2:
	var dir := _dir_of(an)
	var key := "use_%s_%d" % [dir, anim.frame]
	var d: float = FRAME_PUSH.get(key, 0.0)
	if d == 0.0:
		return Vector2.ZERO

	match dir:
		"up": return Vector2(0, -d)
		"down": return Vector2(0, d)
		"left": return Vector2(-d, 0)
		"right": return Vector2(d, 0)
	return Vector2.ZERO


# ===============================
# MỚI: bám đúng frame của player
# ===============================
func _update_synced(an: String):

	# tool có animation trùng tên với người thì dùng,
	# không có thì dự phòng về use_<hướng>
	var dir := _dir_of(an)
	var tan := an
	if not tool_frames.has_animation(tan):
		tan = "use_" + dir

	if not tool_frames.has_animation(tan) \
	or anim.frame >= tool_frames.get_frame_count(tan):
		visible = false
		return

	# dùng cùng khung 32x32 với player → đặt trùng sprite player là khớp
	centered = true
	offset = anim.offset
	flip_h = anim.flip_h
	flip_v = false
	scale = Vector2.ONE
	rotation = 0.0
	position = anim.position + _push_offset(an)

	texture = tool_frames.get_frame_texture(tan, anim.frame)

	# up: tool nằm sau player, riêng frame cuối ra phía trước
	show_behind_parent = (dir == "up" and not _is_last_frame())
	visible = true


# ===============================
# CŨ: tool chỉ có icon, tự xoay theo marker
# ===============================
func _update_legacy(an: String):

	var dir := _dir_of(an)
	var key := "use_%s_%d" % [dir, anim.frame]

	if texture == null or not frames_data.has(key):
		visible = false
		return

	centered = false
	flip_v = false

	var f = frames_data[key]
	var w := float(texture.get_width())
	var g := grip + Vector2(0.5, 0.5)

	var flip := (dir == "right")
	flip_h = flip
	offset = Vector2(-(w - g.x) if flip else -g.x, -g.y)

	var icon_ang := (180.0 - base_angle) if flip else base_angle

	# góc + vị trí tay cầm: mặc định lấy từ JSON, down/up-frame-cuối thì ghi đè
	var target: float = f.rot
	var hand := Vector2(f.x, f.y)
	var up_last := (dir == "up" and _is_last_frame())

	if dir == "down":
		target = DOWN_ANGLES[mini(anim.frame, DOWN_ANGLES.size() - 1)]
	elif up_last:
		target = UP_LAST_ROT
		hand = UP_LAST_HAND

	var rot := deg_to_rad(target - icon_ang)
	var pos := anim.position + hand - Vector2(16, 16) + _push_offset(an)

	# kéo dài dọc theo cán (tay cầm đứng yên)
	var ia := deg_to_rad(icon_ang)
	var stretch := Transform2D(ia, Vector2.ZERO) \
		* Transform2D(Vector2(TOOL_LENGTH_SCALE, 0.0), Vector2(0.0, 1.0), Vector2.ZERO) \
		* Transform2D(-ia, Vector2.ZERO)

	var t := Transform2D(rot, Vector2.ZERO) * stretch

	# up/down: ép ngang theo trục màn hình
	if dir == "up" or dir == "down":
		var squash := Transform2D(
			Vector2(UP_DOWN_SCREEN_SCALE.x, 0.0),
			Vector2(0.0, UP_DOWN_SCREEN_SCALE.y),
			Vector2.ZERO
		)
		t = squash * t

	t.origin = pos
	transform = t

	# up: tool nằm sau player, riêng frame cuối ra phía trước để không bị thân che
	show_behind_parent = (dir == "up" and not up_last)
	visible = true
