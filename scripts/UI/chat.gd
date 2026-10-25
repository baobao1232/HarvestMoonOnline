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
			if Server.is_admin:
				_sys("/give <item_id> [số lượng]  - nhận vật phẩm")
				_sys("/items  - xem danh sách item_id")
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
