extends Control

@onready var username_input = $Username
@onready var password_input = $Password
@onready var status_label = $Status

# ===============================
# GLOBAL STATE
# ===============================
var current_ui = null
var input_mode := "player"
var hud = null
# =========================
# READY
# =========================
func _ready():
	if not Server.login_result.is_connected(_on_login_result):
		Server.login_result.connect(_on_login_result)
	if not Server.register_result.is_connected(_on_register_result):
		Server.register_result.connect(_on_register_result)

	password_input.secret = true

	if UIManager:
		UIManager.remove_game_ui()


# =========================
# BUTTONS
# =========================
func _on_login_pressed():

	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if username == "" or password == "":
		_set_status("Missing input")
		return

	Server.request_login(username, password)


func _on_register_pressed():

	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	Dbg.p("U=[", username, "] P=[", password, "]")   # debug, xong thì xoá

	if username == "" or password == "":
		_set_status("Missing input")
		return

	_set_status("Đang đăng ký...")
	Server.request_register(username, password)


func _on_register_result(success, msg):
	_set_status(msg)

# =========================
# SERVER RESPONSE
# =========================
func _on_login_result(success, msg, player_data):

	_set_status(msg)

	if not success:
		return

	Dbg.p("✅ LOGIN OK")

	var username = username_input.text.strip_edges()

	# =========================
	# SAVE USER
	# =========================
	SaveManager.current_user = username

	# =========================
	# 🔥 ƯU TIÊN SERVER (FIX CHÍNH)
	# =========================
	SaveManager.player = player_data

	# =========================
	# CLIENT SYNC
	# =========================
	Client.set_player_data(SaveManager.player)

	# =========================
	# SERVER SYNC
	# =========================
	Server.player_data = SaveManager.player

	# =========================
	# UI GAME
	# =========================
	SceneManager.set_player_data(SaveManager.player)
	UIManager.setup_game_ui()

	# =========================
	# MAP LOAD (ĐÚNG)
	# =========================
	var map_path = SaveManager.player.map

	if map_path == "" or map_path == null:
		map_path = "res://scn/Maps/farm.tscn"

	Dbg.p("📍 LOAD MAP:", map_path)
	Dbg.p("📍 LOAD POS:", SaveManager.player.pos)
	if not TimeManager.synced:
		_set_status("Đang đồng bộ thời gian...")
		await TimeManager.time_synced
		
	Net.join(Net.server_ip, SaveManager.player.name)
	Server.request_change_map(map_path, "")

	queue_free()

# =========================
# UI HELPER
# =========================
func _set_status(text):

	if status_label:
		status_label.text = text
	else:
		Dbg.p(text)
		
	
