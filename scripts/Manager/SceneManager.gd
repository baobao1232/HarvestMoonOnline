extends Node
#SceneManager

# ===== CLIENT STATE =====
var player = null
var player_data : PlayerData = null

# ===== MULTIPLAYER =====
var other_players := {}   # id -> node

# ===== MAP =====
var teleport_lock : bool = false


# ===============================
# READY
# ===============================
func _ready():

	await get_tree().process_frame

	var dialog = load("res://scn/UI/DialogUI.tscn").instantiate()
	get_tree().root.add_child.call_deferred(dialog)

	# ===== SERVER SIGNAL =====
	if not Server.player_left.is_connected(_on_player_left):
		Server.player_left.connect(_on_player_left)


# ===============================
# CLIENT → SERVER API
# ===============================
func request_change_map(path: String, spawn: String):

	if player_data == null:
		push_error("❌ CLIENT: player_data NULL")
		return

	Server.request_change_map(path, spawn)

func _on_player_left(id):

	if not other_players.has(id):
		return

	other_players[id].queue_free()
	other_players.erase(id)

	print("❌ PLAYER LEFT:", id)


# ===============================
# SET PLAYER DATA
# ===============================
func set_player_data(data: PlayerData):

	if data == null:
		push_error("❌ player_data NULL")
		return

	player_data = data
	InventoryManager.set_player(player_data)

	print("📦 PLAYER DATA SET:", player_data.name)


# ===============================
# UI
# ===============================
func setup_global_ui():

	var root = get_tree().root

	if root.get_node_or_null("Hud") == null:
		var hud = preload("res://scn/UI/Hud.tscn").instantiate()
		hud.name = "Hud"
		root.call_deferred("add_child", hud)

	if root.get_node_or_null("DayNight") == null:
		var dn = preload("res://scn/UI/DayNight.tscn").instantiate()
		dn.name = "DayNight"
		root.call_deferred("add_child", dn)
