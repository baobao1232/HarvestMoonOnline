extends Sprite2D

const FRAMES_JSON := "res://scripts/Players/tool_frames.json"
static var frames_data := {}

# Hướng xuống: bỏ góc trong JSON, ép góc cho từng frame.
# Góc = hướng từ tay cầm ra đầu tool (-90 = thẳng lên, 90 = thẳng xuống, 0 = sang phải).
const DOWN_ANGLES := [-100.0, -80.0, 60.0]

var grip := Vector2.ZERO
var base_angle := -45.0

@onready var anim: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")


func _ready():
	if frames_data.is_empty() and FileAccess.file_exists(FRAMES_JSON):
		frames_data = JSON.parse_string(FileAccess.get_file_as_string(FRAMES_JSON))
	centered = false
	texture_filter = TEXTURE_FILTER_NEAREST
	visible = false
	anim.frame_changed.connect(_update)
	anim.animation_changed.connect(_update)


func set_tool(item) -> void:
	if item == null:
		texture = null
	else:
		texture = item.icon
		grip = item.grip
		base_angle = item.icon_angle   # icon vẽ quay sang trái
	_update()


func _update():
	var an := String(anim.animation)
	var key := "%s_%d" % [an, anim.frame]

	if not an.begins_with("use_") or texture == null or not frames_data.has(key):
		visible = false
		return

	var dir := an.trim_prefix("use_")
	var f = frames_data[key]
	var w := float(texture.get_width())
	var g := grip + Vector2(0.5, 0.5)    # tâm pixel tay cầm

	# hướng phải: lật icon
	var flip := (dir == "right")
	flip_h = flip
	offset = Vector2(-(w - g.x) if flip else -g.x, -g.y)

	# lật thì hướng icon đổi từ a thành 180 - a
	var icon_ang := (180.0 - base_angle) if flip else base_angle

	# góc đích: down thì ép, còn lại lấy từ marker
	var target: float = f.rot
	if dir == "down":
		target = DOWN_ANGLES[mini(anim.frame, DOWN_ANGLES.size() - 1)]

	position = anim.position + Vector2(f.x - 16, f.y - 16)
	rotation_degrees = target - icon_ang
	show_behind_parent = (dir == "up")
	visible = true
