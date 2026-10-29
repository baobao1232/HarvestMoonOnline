extends CharacterBody2D
# Npc.gd - node NPC trong map. Mọi dữ liệu (lịch, thoại, quà...) lấy từ NPCData.
# NpcManager spawn node này rồi gọi apply_entry() mỗi khi lịch đổi.
# Scene cần: AnimatedSprite2D (down/left/right/up, idle_*, tuỳ chọn sit_*),
# CollisionShape2D, Label tên "Name" (tuỳ chọn). Đặt npc_id = tên file, ví dụ "Karen".

const ARRIVE_DIST := 3.0
const STUCK_TIME := 1.0
const WAYPOINT_DIST := 3.0

# ===== CHẾ ĐỘ "MA" (tạm đi xuyên người/NPC khi bị chặn) =====
const NORMAL_LAYER := 1
const NORMAL_MASK := 1
const GHOST_LAYER := 4          # layer 3
const GHOST_MASK := 1           # chỉ va tường (StaticBody2D ở layer 1)
const GHOST_MAX := 4.0          # tối đa bao lâu ở chế độ ma (giây)
const GHOST_MIN := 0.6          # tối thiểu trước khi cho phép trả lại

# ===== ĐI DẠO =====
const WANDER_SPEED_MULT := 0.5

@export var npc_id : String
@export var speed := 40.0       # bị ghi đè bằng movement.speed trong JSON

@export var wander_enabled := true
@export var wander_radius := 96.0
@export var wander_pause := Vector2(1.0, 3.0)

var path := PackedVector2Array()
var path_i := 0

var data : NPCData = null
var entry := {}                 # mốc lịch đang áp dụng
var state := "idle"             # idle / sit / walk / inside_open
var target_pos := Vector2.ZERO
var moving := false
var last_dir := "down"
var in_dialog := false

var anchor := Vector2.ZERO      # điểm đích gốc theo lịch
var _wandering := false
var _wander_timer := 0.0

var _stuck := 0.0
var _stuck_n := 0
var _best_d := INF
var _last_i := -1

var _ghost := false
var _ghost_t := 0.0

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
	anchor = target_pos
	_wandering = false
	_reset_wander_timer()
	_stuck = 0.0
	_stuck_n = 0

	if snap:
		place(target_pos)
		_arrive()
	else:
		moving = global_position.distance_to(target_pos) > ARRIVE_DIST
		if moving:
			_repath()


func _arrive():
	moving = false
	_wandering = false
	velocity = Vector2.ZERO
	_stuck = 0.0
	_stuck_n = 0
	_reset_wander_timer()


# ===============================
# MOVEMENT
# ===============================
func _physics_process(delta):

	# đang ở chế độ ma: trả va chạm khi đủ lâu và không ai đè lên
	# (đặt trước dialog để luôn được dọn)
	if _ghost:
		_ghost_t += delta
		if _ghost_t >= GHOST_MAX \
		or (_ghost_t >= GHOST_MIN and not _overlapped()):
			_set_ghost(false)

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
		_tick_wander(delta)
		return

	if global_position.distance_to(target_pos) <= ARRIVE_DIST:
		_arrive()
		return

	# bỏ các điểm rẽ đã đi qua
	while path_i < path.size() - 1 \
	and global_position.distance_to(path[path_i]) <= WAYPOINT_DIST:
		path_i += 1

	var goal := path[path_i] if path_i < path.size() else target_pos
	var to_goal := goal - global_position
	var spd := speed * (WANDER_SPEED_MULT if _wandering else 1.0)

	# đổi waypoint -> đo tiến độ lại từ đầu
	if path_i != _last_i:
		_last_i = path_i
		_best_d = INF
		_stuck = 0.0

	velocity = to_goal.normalized() * spd
	set_breathing(false)
	update_animation(to_goal)
	move_and_slide()
	global_position = NpcManager.clamp_to_map(global_position, 8.0)

	# kẹt = không tiến gần waypoint hơn (kể cả khi đang trượt dọc tường)
	var d := global_position.distance_to(goal)
	if d < _best_d - 0.5:
		_best_d = d
		_stuck = 0.0
		_stuck_n = 0
	else:
		_stuck += delta

	if _stuck >= STUCK_TIME:
		_stuck = 0.0
		_best_d = INF

		# đang đi dạo mà kẹt -> thôi, đứng yên tại chỗ
		if _wandering:
			target_pos = anchor
			_arrive()
			return

		# lần kẹt đầu: nhiều khả năng bị người/NPC chặn -> tạm đi xuyên
		if not _ghost and _stuck_n == 0:
			_set_ghost(true)
			_stuck_n = 1
			return

		_stuck_n += 1
		if _stuck_n >= 3:
			place(target_pos)
			_arrive()
		else:
			_repath()


# ===============================
# GHOST
# ===============================
func _set_ghost(on: bool):
	if on == _ghost:
		return
	_ghost = on
	_ghost_t = 0.0
	if on:
		collision_layer = GHOST_LAYER
		collision_mask = GHOST_MASK
	else:
		collision_layer = NORMAL_LAYER
		collision_mask = NORMAL_MASK


# có người/NPC nào đang đè lên NPC này không
func _overlapped() -> bool:

	var cs = get_node_or_null("CollisionShape2D")
	if cs == null or cs.shape == null:
		return false

	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.collision_mask = 1
	q.exclude = [get_rid()]
	q.collide_with_bodies = true
	q.collide_with_areas = false

	for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
		if hit.collider is CharacterBody2D:
			return true
	return false


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

	# 2) thoại thường
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
# ===============================
func give_gift(item_id: String) -> bool:

	if data == null:
		return false

	face_player()

	var r := data.give_gift(item_id, NpcManager.make_context())
	_show(r.lines)

	return r.ok


# ===============================
# TIỆN ÍCH
# ===============================
func place(p: Vector2):
	global_position = p
	reset_physics_interpolation()


func _repath():
	path = NpcManager.find_route(global_position, target_pos)
	path_i = 1 if path.size() > 1 else 0
	_last_i = -1


# ===============================
# ĐI DẠO
# ===============================
func _reset_wander_timer():
	_wander_timer = randf_range(wander_pause.x, wander_pause.y)


func _tick_wander(delta):

	if not wander_enabled or state != "idle":
		return

	_wander_timer -= delta
	if _wander_timer > 0.0:
		return

	_reset_wander_timer()
	_start_wander()


func _start_wander():

	for _i in 10:
		var dist := randf_range(wander_radius * 0.3, wander_radius)
		var off := Vector2.from_angle(randf() * TAU) * dist
		var p := NpcManager.clamp_to_map(anchor + off, 8.0)
		p = NpcManager.snap_nav(p)

		# điểm bị đẩy ra quá xa neo -> bỏ
		if p.distance_to(anchor) > wander_radius * 1.3:
			continue
		if p.distance_to(global_position) < 12.0:
			continue

		# bỏ điểm phải đi vòng quá xa (bị tường chắn)
		var route := NpcManager.find_route(global_position, p)
		var direct := global_position.distance_to(p)
		if NpcManager.path_length(route) > direct * 2.5 + 24.0:
			continue

		target_pos = p
		path = route
		path_i = 1 if path.size() > 1 else 0
		_last_i = -1
		_wandering = true
		moving = true
		_stuck = 0.0
		_stuck_n = 0
		return
