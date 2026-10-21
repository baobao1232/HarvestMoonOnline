extends Node

# =========================
# SIGNAL
# =========================
signal login_result(success, msg, player_data)

signal player_joined(id, data)
signal player_moved(id, pos)
signal player_left(id)

signal map_changed(path, spawn)
signal drop_spawned(data)

# =========================
# DATA
# =========================
var accounts = {}
var players = {}
var player_data = null
var current_id = ""

const SAVE_PATH = "user://accounts.json"


# =========================
# READY
# =========================
func _ready():
	_load_accounts()


# =========================
# LOAD ACCOUNTS
# =========================
func _load_accounts():

	if not FileAccess.file_exists(SAVE_PATH):
		print("📂 No accounts file")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var json = JSON.parse_string(text)

	if typeof(json) != TYPE_DICTIONARY:
		print("❌ accounts.json corrupted")
		return

	for username in json.keys():

		var acc = json[username]

		var data = PlayerData.new()
		data.from_dict(acc["data"])

		accounts[username] = {
			"password": acc["password"],
			"data": data
		}

	print("📂 ACCOUNTS LOADED:", accounts.size())


# =========================
# SAVE ACCOUNTS
# =========================
func _save_accounts():
	print("save account")

	var data = {}

	for username in accounts.keys():

		data[username] = {
			"password": accounts[username].password,
			"data": accounts[username].data.to_dict()
		}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	print("💾 ACCOUNTS SAVED")


# =========================
# REGISTER
# =========================
func request_register(username, password):

	if accounts.has(username):
		emit_signal("login_result", false, "Username exists", null)
		return

	var data = PlayerData.new()
	data.name = username

	accounts[username] = {
		"password": password,
		"data": data
	}

	_save_accounts()

	print("✅ REGISTER:", username)


# =========================
# LOGIN
# =========================
func request_login(username, password):

	if not accounts.has(username):
		emit_signal("login_result", false, "User not found", null)
		return

	if accounts[username].password != password:
		emit_signal("login_result", false, "Wrong password", null)
		return

	current_id = username
	player_data = accounts[username].data

	players[current_id] = {
		"pos": player_data.pos,
		"map": player_data.map
	}

	emit_signal("login_result", true, "Login success", player_data)

	# ❌ XOÁ DÒNG NÀY
	# emit_signal("player_joined", current_id, players[current_id])

	print("✅ LOGIN:", username)


# =========================
# MOVE
# =========================
# =========================
# MOVE (REALTIME)
# =========================
func request_move(pos: Vector2):

	if current_id == "":
		return

	if not players.has(current_id):
		return

	players[current_id].pos = pos

	# 🔥 broadcast cho tất cả client
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
	else:
		final_spawn = ""

	player_data.map = path

	emit_signal("map_changed", path, final_spawn)


# =========================
# DROP
# =========================
func spawn_drop(item: ItemData, amount: int, pos: Vector2):

	if item == null or amount <= 0:
		return

	var drop_data = {
		"item": item,
		"amount": amount,
		"pos": pos
	}

	print("🔥 SERVER SPAWN DROP:", drop_data)

	# 👉 CHỈ EMIT SIGNAL
	emit_signal("drop_spawned", drop_data)
	
# =========================
# SAVE POSITION
# =========================
func request_save_position(pos: Vector2, map_path: String):
	print("request save pos")

	if player_data == null:
		return

	player_data.pos = pos
	player_data.map = map_path

	# 🔥 save player riêng
	if SaveManager:
		SaveManager.save(player_data)

	# 🔥 save accounts (QUAN TRỌNG)
	_save_accounts()

# =========================
# HOTBAR SAVE
# =========================
func request_save_hotbar(index: int, item, amount: int):

	if player_data == null:
		print("❌ HOTBAR SAVE FAIL: player_data null")
		return

	# đảm bảo size
	if player_data.hotbar.size() < 8:
		player_data.hotbar.resize(8)

	player_data.hotbar[index] = {
		"item": item,
		"amount": amount
	}

	print("💾 HOTBAR SAVE:", index, item, amount)

	# 🔥 lưu local (tạm thời)
	if SaveManager:
		SaveManager.save(player_data)

func _enter_tree():
	print("🚨 ENTER TREE:", get_path())

func _notification(what):

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_player_exit()

	if what == NOTIFICATION_PREDELETE:
		_on_player_exit()
		
func _on_player_exit():

	if current_id == "":
		return

	print("🚪 PLAYER EXIT:", current_id)

	# 🔥 SAVE
	if player_data:
		request_save_position(player_data.pos, player_data.map)

	emit_signal("player_left", current_id)

	if players.has(current_id):
		players.erase(current_id)

	current_id = ""
	player_data = null

func request_drop_item(item, amount):

	if current_id == "":
		return

	if not players.has(current_id):
		return

	var player = players[current_id]

	var pos = player.pos

	var data = {
		"item": item,
		"amount": amount,
		"pos": pos
	}

	print("🔥 SERVER DROP:", data)

	emit_signal("drop_spawned", data)
