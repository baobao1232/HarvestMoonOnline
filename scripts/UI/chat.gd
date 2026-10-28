extends CanvasLayer
# Chat + command. Scene: res://scn/UI/Chat.tscn
# - Mặc định ẩn. Enter (hoặc nút Chat) để mở. Kéo thanh trên cùng để di chuyển.
# - Gõ xong, không chat tiếp sau hide_delay giây thì tự ẩn.

@export var max_lines := 50
@export var hide_delay := 30.0          # giây không hoạt động → ẩn khung
@export var fade_time := 1.0            # mờ dần trong giây cuối
@export var show_toggle_button := false # nút "Chat" (bật lên nếu chơi điện thoại không có phím Enter)

@onready var window: PanelContainer = %Window
@onready var drag_bar: Label = %DragBar
@onready var log_box: RichTextLabel = %Log
@onready var input_row: HBoxContainer = %InputRow
@onready var input: LineEdit = %Input
@onready var send_btn: Button = %SendBtn
@onready var toggle_btn: Button = %ToggleBtn

var lines: Array = []
var hide_timer := 0.0
var unread := 0

var dragging := false
var drag_offset := Vector2.ZERO

# map -> đường dẫn + danh sách marker spawn (phần tử đầu = mặc định)
const TP_MAPS := {
	"farm":       {"path": "res://scn/Maps/farm.tscn",       "spawns": ["Spawn", "SpawnTown1", "SpawnFarm1"]},
	"town1":      {"path": "res://scn/Maps/town1.tscn",      "spawns": ["SpawnFarm", "SpawnTown2", "SpawnTown3", "SpawnForest", "SpawnThoRenToTown1"]},
	"town2":      {"path": "res://scn/Maps/town2.tscn",      "spawns": ["SpawnTown1", "SpawnTown3"]},
	"town3":      {"path": "res://scn/Maps/town3.tscn",      "spawns": ["SpawnTown1", "SpawnTown2", "SpawnBeach"]},
	"forest":     {"path": "res://scn/Maps/forest.tscn",     "spawns": ["SpawnFarm", "SpawnTown1", "SpawnForest1", "SpawnForest2", "SpawnNhaThoMoc"]},
	"beach":      {"path": "res://scn/Maps/beach.tscn",      "spawns": ["SpawnTown3"]},
	"motherhill": {"path": "res://scn/Maps/MotherHill.tscn", "spawns": ["SpawnForest1", "SpawnForest2"]},
	"thomoc":     {"path": "res://scn/House/Interior/ThoMoc_Int.tscn", "spawns": ["SpawnForest"]},
	"thoren":     {"path": "res://scn/House/Interior/Thoren_Int.tscn", "spawns": ["NhaThoRen"]},
}
const STUCK_COOLDOWN := 30.0

var _last_stuck := -1000.0

func _ready():
	toggle_btn.visible = show_toggle_button
	window.visible = false

	toggle_btn.pressed.connect(_toggle)
	send_btn.pressed.connect(func(): _on_submit(input.text))
	input.text_submitted.connect(_on_submit)
	drag_bar.gui_input.connect(_on_drag_input)
	Net.remote_chat.connect(_on_chat)

	_sys("Gõ /help để xem danh sách lệnh")
	unread = 0
	_update_toggle_text()


# ===============================
# SHOW / HIDE
# ===============================
func _process(delta):

	if not window.visible:
		return

	# đang gõ hoặc đang kéo → không đếm giờ ẩn
	if input_row.visible or dragging:
		hide_timer = hide_delay
		window.modulate.a = 1.0
		return

	hide_timer -= delta

	if hide_timer <= 0.0:
		_hide_window()
		return

	window.modulate.a = clamp(hide_timer / fade_time, 0.0, 1.0)


func _show_window():
	window.visible = true
	window.modulate.a = 1.0
	hide_timer = hide_delay
	unread = 0
	_update_toggle_text()
	_clamp_window()


func _hide_window():
	dragging = false
	input.release_focus()
	input_row.visible = false
	window.visible = false
	if UIManager.input_mode == "chat":
		UIManager.input_mode = "player"


func _update_toggle_text():
	toggle_btn.text = "Chat" if unread <= 0 else "Chat (%d)" % unread


# ===============================
# OPEN / CLOSE INPUT
# ===============================
func _toggle():
	if input_row.visible:
		_close_input()
	else:
		_open_input()


func _open_input():
	if input_row.visible:
		return
	if UIManager.input_mode != "player" or DialogManager.is_showing:
		return
	_show_window()
	input_row.visible = true
	input.grab_focus()
	UIManager.input_mode = "chat"


# đóng ô gõ nhưng khung vẫn còn → tự ẩn sau hide_delay
func _close_input():
	input.release_focus()
	input_row.visible = false
	input.clear()
	hide_timer = hide_delay
	if UIManager.input_mode == "chat":
		UIManager.input_mode = "player"


func _input(event):
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var is_enter: bool = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER

	if event.keycode == KEY_ESCAPE:
		if input_row.visible:
			_close_input()
			get_viewport().set_input_as_handled()
		elif window.visible:
			_hide_window()
			get_viewport().set_input_as_handled()

	elif is_enter and not input_row.visible:
		if UIManager.input_mode == "player" and not DialogManager.is_showing:
			_open_input()
			get_viewport().set_input_as_handled()


# ===============================
# DRAG
# ===============================
func _on_drag_input(event):

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset = window.position - get_viewport().get_mouse_position()

	elif event is InputEventMouseMotion and dragging:
		window.position = get_viewport().get_mouse_position() + drag_offset
		_clamp_window()


func _clamp_window():
	var vs := get_viewport().get_visible_rect().size
	var max_pos := (vs - window.size).max(Vector2.ZERO)
	window.position = window.position.clamp(Vector2.ZERO, max_pos)


# ===============================
# SEND / RECEIVE
# ===============================
func _on_submit(t: String):
	t = t.strip_edges()
	_close_input()

	if t == "":
		return

	if t.begins_with("/"):
		_command(t)
	else:
		Net.send_chat(t)


# bong bóng trên đầu player do Client.gd xử lý
func _on_chat(_sender_id: int, pname: String, text: String):
	_add("[color=#8fd3ff][b]%s[/b][/color]: %s" % [_esc(pname), _esc(text)])


func _sys(text: String, color := "#ffd966"):
	_add("[color=%s]%s[/color]" % [color, _esc(text)])


func _err(text: String):
	_sys(text, "#ff7a7a")


func _add(bb: String):
	lines.append(bb)
	if lines.size() > max_lines:
		lines.pop_front()
	log_box.text = "\n".join(lines)

	if window.visible:
		if not input_row.visible:
			hide_timer = hide_delay      # có tin mới → gia hạn
	else:
		unread += 1                      # đang ẩn → chỉ báo số tin chưa đọc
		_update_toggle_text()


# chặn người chơi chèn BBCode vào chat
func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


# ===============================
# COMMANDS
# ===============================
func _command(line: String):

	var parts := line.substr(1).split(" ", false)
	if parts.is_empty():
		return

	var cmd := parts[0].to_lower()

	match cmd:
		"help":
			_sys("/clear  - xoá khung chat")
			_sys("/stuck  - thoát khi bị kẹt")
			if Server.is_admin:
				_sys("/give <item_id> [số lượng]  - nhận vật phẩm")
				_sys("/items  - xem danh sách item_id")
				_sys("/tp  - xem danh sách map / spawn")
				_sys("/tp <map> [spawn]  - sang map khác")
				_sys("/tp <spawn>  - tới marker trong map hiện tại")
		"stuck":
			_cmd_stuck()
		"tp":
			_cmd_tp(parts)
		"items":
			if not Server.is_admin:
				_err("Bạn không có quyền dùng lệnh này")
				return
			_sys("Items: " + ", ".join(ItemDb.items.keys()))
		"clear":
			lines.clear()
			log_box.text = ""
		"give":
			_cmd_give(parts)
		_:
			_err("Lệnh không tồn tại: /" + cmd + "  (gõ /help)")


func _cmd_give(parts: PackedStringArray):
	
	if not Server.is_admin:
		_err("Bạn không có quyền dùng lệnh này")
		return
		
	if parts.size() < 2:
		_err("Dùng: /give <item_id> [số lượng]")
		return

	var item_id := parts[1]
	var amount := 1
	if parts.size() >= 3:
		amount = int(parts[2])

	if amount <= 0:
		_err("Số lượng phải > 0")
		return

	if not ItemDb.items.has(item_id):
		_err("Không có item: " + item_id + "  (gõ /items)")
		return

	var item: ItemData = ItemDb.items[item_id]

	Server.api("give", {"item": item_id, "amount": amount}, func(r):
		if r.get("ok", false):
			_sys("Đã nhận %d x %s" % [amount, item.name], "#9dff9d")
		else:
			_err(str(r.get("msg", "Không give được")))
	)
# ===============================
# TELEPORT
# ===============================
func _current_markers() -> Array:
	var scene := get_tree().current_scene
	var list: Array = []
	if scene == null:
		return list
	var ysort := scene.get_node_or_null("YSort")
	if ysort == null:
		return list
	for c in ysort.get_children():
		if c is Marker2D:
			list.append(c)
	return list


func _find_marker(spawn: String) -> Marker2D:
	for m in _current_markers():
		if String(m.name).to_lower() == spawn.to_lower():
			return m
	return null


func _place_player(m: Marker2D):
	var p = SceneManager.player
	if p == null or not is_instance_valid(p):
		_err("Chưa có nhân vật")
		return
	p.global_position = m.global_position
	p.velocity = Vector2.ZERO
	if p.has_method("snap_camera"):
		p.snap_camera()


func _cmd_stuck():
	var now := Time.get_ticks_msec() / 1000.0
	if not Server.is_admin and now - _last_stuck < STUCK_COOLDOWN:
		_err("Đợi %d giây nữa mới dùng lại được" % int(STUCK_COOLDOWN - (now - _last_stuck)))
		return

	var p = SceneManager.player
	if p == null or not is_instance_valid(p):
		_err("Chưa có nhân vật")
		return

	var best: Marker2D = null
	var best_d := INF
	for m in _current_markers():
		var d: float = m.global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = m

	if best == null:
		_err("Map này không có điểm spawn")
		return

	_last_stuck = now
	_place_player(best)
	_sys("Đã đưa bạn về " + String(best.name), "#9dff9d")


func _cmd_tp(parts: PackedStringArray):

	if not Server.is_admin:
		_err("Bạn không có quyền dùng lệnh này")
		return

	# /tp  → liệt kê
	if parts.size() < 2:
		_sys("Map: " + ", ".join(TP_MAPS.keys()))
		var names: Array = []
		for m in _current_markers():
			names.append(String(m.name))
		_sys("Spawn map hiện tại: " + ", ".join(names))
		return

	var arg := parts[1]
	var key := arg.to_lower()

	# /tp <map> [spawn]
	if TP_MAPS.has(key):
		var info: Dictionary = TP_MAPS[key]
		var spawns: Array = info["spawns"]
		var spawn: String = spawns[0]

		if parts.size() >= 3:
			var found := ""
			for s in spawns:
				if String(s).to_lower() == parts[2].to_lower():
					found = s
			if found == "":
				_err("Map %s có spawn: %s" % [key, ", ".join(spawns)])
				return
			spawn = found

		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == info["path"]:
			var m := _find_marker(spawn)
			if m: _place_player(m)
		else:
			SceneManager.request_change_map(info["path"], spawn)
		_sys("Tele tới %s / %s" % [key, spawn], "#9dff9d")
		return

	# /tp <spawn> trong map hiện tại
	var marker := _find_marker(arg)
	if marker == null:
		_err("Không có map hay spawn: " + arg + "  (gõ /tp)")
		return

	_place_player(marker)
	_sys("Tele tới " + String(marker.name), "#9dff9d")
