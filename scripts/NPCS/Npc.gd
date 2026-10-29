extends CharacterBody2D
# Npc.gd - node NPC trong map. Mọi dữ liệu (lịch, thoại, quà...) lấy từ NPCData.
# NpcManager spawn node này rồi gọi apply_entry() mỗi khi lịch đổi.
# Scene cần: AnimatedSprite2D (down/left/right/up, idle_*, tuỳ chọn sit_*),
# Label tên "Name" (tuỳ chọn). Đặt npc_id = tên file, ví dụ "Karen".

const ARRIVE_DIST := 3.0
const STUCK_TIME := 1.5

@export var npc_id : String
@export var speed := 40.0       # bị ghi đè bằng movement.speed trong JSON

var data : NPCData = null
var entry := {}                 # mốc lịch đang áp dụng
var state := "idle"             # idle / sit / walk / inside_open
var target_pos := Vector2.ZERO
var moving := false
var last_dir := "down"
var in_dialog := false

var _stuck := 0.0
var breath_mat : ShaderMaterial

@onready var sprite = $AnimatedSprite2D
@onready var name_label = get_node_or_null("Name")


func _ready():

	data = NpcManager.get_data(npc_id)

	if data != null:
		speed = data.speed
		if name_label:
			name_label.text = data.npc_name

	setup_breathing()
	play_idle()


# ===============================
# BREATHING
# ===============================
func setup_breathing():
	breath_mat = ShaderMaterial.new()
	breath_mat.shader = load("res://shader/breathing.gdshader")
	sprite.material = breath_mat


func set_breathing(active: bool):
	if breath_mat == null:
		return
	breath_mat.set_shader_parameter("intensity", 0.015 if active else 0.0)


# ===============================
# NHẬN LỊCH TỪ NpcManager
# ===============================
func apply_entry(new_entry: Dictionary, snap := false):

	entry = new_entry
	state = str(entry.get("state", "idle"))
	target_pos = NpcManager.resolve_pos(npc_id, entry)

	if snap:
		global_position = target_pos
		_arrive()
	else:
		moving = global_position.distance_to(target_pos) > ARRIVE_DIST
		_stuck = 0.0


func _arrive():
	moving = false
	velocity = Vector2.ZERO
	_stuck = 0.0


# ===============================
# MOVEMENT
# ===============================
func _physics_process(delta):

	# đang nói chuyện -> đứng yên
	if in_dialog:
		if DialogManager.is_showing:
			velocity = Vector2.ZERO
			set_breathing(false)
			play_idle()
			return
		in_dialog = false

	if not moving:
		set_breathing(true)
		play_idle()
		return

	var to_target := target_pos - global_position

	if to_target.length() <= ARRIVE_DIST:
		_arrive()
		return

	velocity = to_target.normalized() * speed
	set_breathing(false)
	update_animation(to_target)
	move_and_slide()
	global_position = NpcManager.clamp_to_map(global_position, 8.0)

	# kẹt tường quá lâu -> dịch thẳng tới đích
	if get_real_velocity().length() < speed * 0.2:
		_stuck += delta
		if _stuck >= STUCK_TIME:
			global_position = target_pos
			_arrive()
	else:
		_stuck = 0.0


# ===============================
# ANIMATION
# ===============================
func update_animation(dir: Vector2):

	if abs(dir.x) > abs(dir.y):
		last_dir = "right" if dir.x > 0 else "left"
	else:
		last_dir = "down" if dir.y > 0 else "up"

	if sprite.animation != last_dir:
		sprite.play(last_dir)


func play_idle():

	var anim := "idle_" + last_dir

	# state "sit": có anim sit_<hướng> thì ngồi, không thì idle
	if state == "sit" and sprite.sprite_frames.has_animation("sit_" + last_dir):
		anim = "sit_" + last_dir

	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func face_player():

	var player = SceneManager.player
	if player == null:
		return

	var dir = player.global_position - global_position

	if abs(dir.x) > abs(dir.y):
		last_dir = "right" if dir.x > 0 else "left"
	else:
		last_dir = "down" if dir.y > 0 else "up"

	play_idle()


# ===============================
# INTERACT (player bấm A)
# ===============================
func interact():

	if data == null:
		return

	face_player()

	var ctx := NpcManager.make_context()

	# 1) heart event đang chờ
	var ev := data.find_ready_event(ctx)

	if not ev.is_empty():
		_show(ev.get("lines", []), true)
		data.register_talk(ctx)
		NpcManager.start_event(npc_id, ev)
		return

	# 2) thoại thường (intro / birthday / heart / mưa / nơi chốn / tối / mùa / normal)
	var lines := data.pick_dialog(ctx, entry)
	data.register_talk(ctx)
	_show(lines)


func _show(lines: Array, with_speaker := false):

	var d := data.to_dialog(lines, with_speaker)

	if d.texts.is_empty():
		return

	in_dialog = true
	DialogManager.show(d.texts, d.portraits)


# ===============================
# TẶNG QUÀ
# gọi từ nơi xử lý item: npc.give_gift(item.id)
# ===============================
func give_gift(item_id: String) -> bool:

	if data == null:
		return false

	face_player()

	var r := data.give_gift(item_id, NpcManager.make_context())
	_show(r.lines)

	return r.ok
