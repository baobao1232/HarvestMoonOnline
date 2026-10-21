extends Node
#Client.gd
var player = null
var player_data : PlayerData = null

var other_players = {}

# =========================
# READY
# =========================
func _ready():

	Server.player_joined.connect(_on_player_joined)
	Server.player_moved.connect(_on_player_moved)
	Server.player_left.connect(_on_player_left)

	Server.map_changed.connect(_on_map_changed)
	Server.drop_spawned.connect(_on_drop_spawned)


# =========================
# SET DATA
# =========================
func set_player_data(data):

	player_data = data


# =========================
# PLAYER JOIN
# =========================
func _on_player_joined(id, data):

	if id == SaveManager.current_user:
		return

	# ❗ tránh spawn trùng
	if other_players.has(id):
		return

	var p = preload("res://scn/Player/Player.tscn").instantiate()
	get_tree().current_scene.add_child(p)

	p.global_position = data.pos

	other_players[id] = p

	print("👤 JOIN:", id)


# =========================
# PLAYER MOVE
# =========================
func _on_player_moved(id, pos):

	if id == SaveManager.current_user:
		return

	if not other_players.has(id):
		return

	var p = other_players[id]

	if not is_instance_valid(p):
		other_players.erase(id)
		return

	p.global_position = pos


# =========================
# PLAYER LEAVE
# =========================
func _on_player_left(id):

	if not other_players.has(id):
		return

	var p = other_players[id]

	if is_instance_valid(p):
		p.queue_free()

	other_players.erase(id)

	print("❌ PLAYER LEFT:", id)

# =========================
# MAP
# =========================
func _on_map_changed(path, spawn):

	change_map_local(path, spawn)


func change_map_local(path, spawn):

	print("🔥 CHANGE MAP CALLED FROM:", get_stack())

	var tree = get_tree()
	var root = tree.root

	var old_map = tree.current_scene
	var new_map = load(path).instantiate()

	root.add_child(new_map)
	tree.current_scene = new_map

	await tree.process_frame

	# ===============================
	# 🔥 PLAYER
	# ===============================
	if player == null or not is_instance_valid(player):
		player = preload("res://scn/Player/Player.tscn").instantiate()

	player.dat_scene = preload("res://scn/Farms/DatTrongCay.tscn")

	# attach player vào map
	var ysort = new_map.find_child("YSort", true, false)

	if player.get_parent():
		player.get_parent().remove_child(player)

	if ysort:
		ysort.add_child(player)
	else:
		new_map.add_child(player)

	print("✅ PLAYER ATTACHED:", player.get_path())

	# ===============================
	# 🔥 OTHER PLAYERS
	# ===============================
	for id in other_players.keys():

		var p = other_players[id]

		if not is_instance_valid(p):
			continue

		if p.get_parent():
			p.get_parent().remove_child(p)

		if ysort:
			ysort.add_child(p)
		else:
			new_map.add_child(p)

	# ===============================
	# 🔥 SPAWN / LOAD SAVE
	# ===============================
	var spawn_node = null

	# portal spawn
	if spawn != "":
		spawn_node = new_map.find_child(spawn, true, false)

	# fallback Spawn
	if spawn_node == null:
		spawn_node = new_map.find_child("Spawn", true, false)

	print("🧪 SPAWN PARAM:", spawn)
	print("🧪 FOUND SPAWN:", spawn_node)

	# ===============================
	# 🌱 NEWBIE PLAYER
	# ===============================
	if player_data != null and player_data.is_newbie:

		if spawn_node:
			player.global_position = spawn_node.global_position
			print("🌱 NEWBIE SPAWN:", spawn_node.name)
			player_data.is_newbie = false;
			SaveManager.save(player_data)
		else:
			player.global_position = Vector2.ZERO
			print("❌ NO SPAWN NODE")

		player_data.is_newbie = false

	# ===============================
	# 🚪 PORTAL TELEPORT
	# ===============================
	elif spawn != "" and spawn_node != null:

		player.global_position = spawn_node.global_position
		print("🚪 PORTAL SPAWN:", spawn_node.name)

	# ===============================
	# 📍 LOAD SAVE POSITION
	# ===============================
	elif player_data != null:

		player.global_position = player_data.pos
		print("📍 LOAD SAVED POS:", player_data.pos)

	# ===============================
	# ❌ FALLBACK
	# ===============================
	else:

		player.global_position = Vector2.ZERO
		print("❌ FALLBACK ZERO")

	# ===============================
	# 🔥 CAMERA
	# ===============================
	if player.has_method("snap_camera"):
		player.snap_camera()

	# ===============================
	# 🔥 REMOVE OLD MAP
	# ===============================
	if old_map and is_instance_valid(old_map):
		old_map.queue_free()
		
func _on_drop_spawned(data):

	print("📦 CLIENT RECEIVED DROP:", data)

	_spawn_drop_local(data.item, data.amount, data.pos)

func _spawn_drop_local(item: ItemData, amount: int, pos: Vector2):

	if item == null or amount <= 0:
		return

	if player == null:
		print("❌ NO PLAYER")
		return

	var scene = preload("res://scn/Items/DroppedItem.tscn")
	var drop = scene.instantiate()

	var map = player.get_parent()   # 🔥 CHUẨN
	map.add_child(drop)

	drop.global_position = pos
	drop.setup(item, amount)

	print("✅ DROP CREATED:", item.name)
