extends Node

# =========================
# SIGNAL
# =========================
signal login_result(success, msg, player_data)
signal register_result(success, msg)

signal player_joined(id, data)
signal player_moved(id, pos)
signal player_left(id)

signal map_changed(path, spawn)
signal drop_spawned(data)
# =========================
# CONFIG
# =========================
# PC: 127.0.0.1 | Emulator: 10.0.2.2 | Điện thoại thật: IP LAN máy chạy XAMPP
const API_URL := "http://127.0.0.1/hvm/api"
const SAVE_INTERVAL := 5.0

# =========================
# DATA
# =========================
var players = {}
var player_data = null
var current_id = ""
var token := ""

var _last_save := 0.0
var _saving := false
var _dirty_again := false
var _timer_pending := false
var _api_queue: Array = []
var _api_busy := false

func _ready():
	if not Net.is_server:
		get_tree().auto_accept_quit = false
# =========================
# HTTP
# =========================
func _post(endpoint: String, body: Dictionary, cb: Callable):
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)

	req.request_completed.connect(func(result, code, headers, bytes):
		req.queue_free()
		var json = JSON.parse_string(bytes.get_string_from_utf8())
		if result != HTTPRequest.RESULT_SUCCESS or typeof(json) != TYPE_DICTIONARY:
			cb.call({"ok": false, "msg": "Không kết nối được server"})
			return
		cb.call(json)
	)

	var err = req.request(
		API_URL + "/" + endpoint,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if err != OK:
		req.queue_free()
		cb.call({"ok": false, "msg": "Request lỗi: %d" % err})


# =========================
# REGISTER / LOGIN
# =========================
func request_register(username, password):
	_post("register.php", {"username": username, "password": password}, func(r):
		register_result.emit(r.get("ok", false), r.get("msg", ""))
	)


func request_login(username, password):
	_post("login.php", {"username": username, "password": password}, func(r):
		if not r.get("ok", false):
			login_result.emit(false, r.get("msg", "Lỗi"), null)
			return

		var data = PlayerData.new()
		data.from_dict(r["data"])

		token = r.get("token", "")
		current_id = username
		player_data = data
		players[current_id] = {"pos": data.pos, "map": data.map}

		login_result.emit(true, "Login success", data)
	)


func logout():
	_save_remote(true)
	token = ""
	current_id = ""
	player_data = null
	players.clear()
	_api_queue.clear()
	
# =========================
# SAVE → DB
# =========================
func _save_remote(force := false):

	if player_data == null or token == "":
		return

	var now := Time.get_ticks_msec() / 1000.0

	if not force and now - _last_save < SAVE_INTERVAL:
		# không bỏ, hẹn lưu lại khi hết thời gian chờ
		if not _timer_pending:
			_timer_pending = true
			var wait := SAVE_INTERVAL - (now - _last_save) + 0.1
			get_tree().create_timer(wait).timeout.connect(func():
				_timer_pending = false
				_save_remote(true)
			)
		return

	# đang có request lưu chạy dở thì đánh dấu, lưu lại sau khi xong
	if _saving:
		_dirty_again = true
		return

	_last_save = now
	_saving = true

	_post("save.php", {
		"token": token,
		"data": player_data.to_dict()
	}, func(r):
		_saving = false
		if not r.get("ok", false):
			Dbg.p("❌ DB SAVE:", r.get("msg"))
		else:
			Dbg.p("💾 DB SAVED")

		if _dirty_again:
			_dirty_again = false
			_save_remote(true)
	)

func request_drop_item(slot: int, amount: int):

	api("drop", {"slot": slot, "amount": amount}, func(r):
		if not r.get("ok", false):
			return

		var item = ItemDb.items.get(r.get("item", ""), null)
		if item == null:
			return

		emit_signal("drop_spawned", {
			"item": item,
			"amount": int(r["amount"]),
			"pos": Vector2(r["x"], r["y"]),
			"id": int(r["drop_id"])
		})
	)

func request_save_position(pos: Vector2, map_path: String, force := false):

	if player_data == null:
		return

	player_data.pos = pos
	player_data.map = map_path

	_save_remote(force)

# =========================
# MOVE
# =========================
func request_move(pos: Vector2):

	if current_id == "":
		return

	if not players.has(current_id):
		return

	players[current_id].pos = pos
	emit_signal("player_moved", current_id, pos)


# =========================
# MAP
# =========================
func request_change_map(path, spawn):

	if current_id == "":
		return

	if player_data == null:
		return

	var final_spawn := ""

	if spawn != "":
		final_spawn = spawn
	elif player_data.map == "":
		final_spawn = "spawn"

	player_data.map = path
	Net.send_map(path)
	emit_signal("map_changed", path, final_spawn)


# =========================
# EXIT
# =========================
var _quitting := false


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_player_exit()


func _on_player_exit():

	if _quitting:
		return
	_quitting = true

	if current_id == "" or player_data == null or token == "":
		get_tree().quit()
		return

	Dbg.p("🚪 PLAYER EXIT:", current_id)

	var p = SceneManager.player
	if p != null and is_instance_valid(p):
		player_data.pos = p.global_position.round()
		player_data.map = get_tree().current_scene.scene_file_path

	emit_signal("player_left", current_id)

	# lưu xong (hoặc quá 3 giây) mới thoát
	get_tree().create_timer(3.0).timeout.connect(func(): get_tree().quit())

	_post("save.php", {
		"token": token,
		"data": player_data.to_dict()
	}, func(r):
		Dbg.p("💾 EXIT SAVE:", r.get("ok", false))
		get_tree().quit()
	)

func api(action: String, params := {}, cb := Callable()):

	if token == "" or player_data == null:
		Dbg.p("⛔ API BỊ CHẶN:", action, "| token:", token != "", "| pd:", player_data != null)
		return

	var body := params.duplicate()
	body["token"] = token
	body["action"] = action

	var p = SceneManager.player
	if p != null and is_instance_valid(p):
		body["px"] = p.global_position.x
		body["py"] = p.global_position.y

	Dbg.p("📤 GỬI:", action, params)
	_api_queue.append({"body": body, "cb": cb, "action": action})
	_api_next()


func _api_next():

	if _api_busy or _api_queue.is_empty():
		return

	_api_busy = true
	var job = _api_queue.pop_front()

	_post("action.php", job.body, func(r):
		_api_busy = false

		if r.get("ok", false):
			Dbg.p("✅", job.action, "| tiles:", r.get("farm", {}).get("tiles", []).size())
			_apply_state(r)
		else:
			Dbg.p("❌", job.action, ":", r.get("msg", ""))

		if job.cb.is_valid():
			job.cb.call(r)

		_api_next()
	)

func _apply_state(r: Dictionary):

	if player_data == null:
		return

	player_data.apply_server_slots(r.get("inventory", []), r.get("hotbar", []))
	InventoryManager.slots = player_data.inventory

	if r.has("farm"):
		player_data.farm = r["farm"]
		FarmManager.sync_farm(r["farm"])

	var hud = UIManager.hud
	if hud != null and is_instance_valid(hud):
		hud.refresh_hotbar()

	var ui = UIManager.current_ui
	if ui != null and is_instance_valid(ui) and ui.has_method("refresh"):
		ui.refresh()
