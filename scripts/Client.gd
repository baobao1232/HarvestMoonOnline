extends Node
#Client.gd  (thay toàn bộ file cũ)

const PLAYER_SCENE = preload("res://scn/Player/Player.tscn")
const REMOTE_SCRIPT = preload("res://scripts/Players/remote_player.gd")

var player = null
var player_data : PlayerData = null

var other_players = {}   # peer_id -> node (chỉ những người cùng map)
var remote_data = {}     # peer_id -> {name,map,pos,has_pos,anim}  (tất cả người online)


# =========================
# READY
# =========================
func _ready():

	Net.remote_joined.connect(_on_remote_joined)
	Net.remote_state.connect(_on_remote_state)
	Net.remote_map.connect(_on_remote_map)
	Net.remote_left.connect(_on_remote_left)
	Net.server_lost.connect(_on_server_lost)

	Server.map_changed.connect(_on_map_changed)
	Server.drop_spawned.connect(_on_drop_spawned)


func set_player_data(data):
	player_data = data


# =========================
# REMOTE PLAYERS
# =========================
func _current_map_path() -> String:
	var s = get_tree().current_scene
	return s.scene_file_path if s else ""


func _on_remote_joined(id, data):
	remote_data[id] = data
	_sync_remote(id)


func _on_remote_state(id, pos, anim, ts, item):
	if not remote_data.has(id):
		return

	var d = remote_data[id]
	d.pos = pos
	d.anim = anim

	var p = other_players.get(id)

	if p != null and is_instance_valid(p):
		p.push_state(pos, anim, ts, item)
	else:
		d.has_pos = true
		_sync_remote(id)

func _on_remote_map(id, map):
	if not remote_data.has(id):
		return
	remote_data[id].map = map
	remote_data[id].has_pos = false
	_sync_remote(id)


func _on_remote_left(id):
	remote_data.erase(id)
	_despawn_remote(id)
	Dbg.p("❌ PLAYER LEFT:", id)


func _on_server_lost():
	for id in other_players.keys():
		_despawn_remote(id)
	remote_data.clear()


# spawn / despawn tuỳ theo có cùng map với mình hay không
func _sync_remote(id):

	if not remote_data.has(id):
		return

	var d = remote_data[id]
	var same_map = (d.map == _current_map_path())

	var p = other_players.get(id)
	if p != null and not is_instance_valid(p):
		other_players.erase(id)
		p = null

	if same_map and d.get("has_pos", false) and p == null:
		_spawn_remote(id, d)
	elif not same_map and p != null:
		_despawn_remote(id)


func _spawn_remote(id, d):

	if player == null or not is_instance_valid(player):
		return
	if player.get_parent() == null:
		return

	var p = PLAYER_SCENE.instantiate()
	p.set_script(REMOTE_SCRIPT)          # thay move.gd bằng remote_player.gd

	player.get_parent().add_child(p)     # cùng YSort với player local
	p.setup(d.name, d.pos, d.anim)

	other_players[id] = p
	Dbg.p("👤 SPAWN REMOTE:", id, d.name)


func _despawn_remote(id):
	if other_players.has(id):
		var p = other_players[id]
		if is_instance_valid(p):
			p.queue_free()
		other_players.erase(id)


# =========================
# MAP
# =========================
func _on_map_changed(path, spawn):
	change_map_local(path, spawn)


func change_map_local(path, spawn):

	var tree = get_tree()
	var root = tree.root

	var old_map = tree.current_scene
	var new_map = load(path).instantiate()

	# remote players của map cũ sẽ được spawn lại ở map mới
	for id in other_players.keys():
		_despawn_remote(id)

	root.add_child(new_map)
	tree.current_scene = new_map

	await tree.process_frame

	# ===== PLAYER =====
	if player == null or not is_instance_valid(player):
		player = PLAYER_SCENE.instantiate()

	SceneManager.player = player   # <-- THÊM DÒNG NÀY

	player.dat_scene = preload("res://scn/Farms/DatTrongCay.tscn")

	var ysort = new_map.find_child("YSort", true, false)

	if player.get_parent():
		player.get_parent().remove_child(player)

	if ysort:
		ysort.add_child(player)
	else:
		new_map.add_child(player)

	# ===== SPAWN / LOAD SAVE =====
	var spawn_node = null

	if spawn != "":
		spawn_node = new_map.find_child(spawn, true, false)

	if spawn_node == null:
		spawn_node = new_map.find_child("Spawn", true, false)

	if player_data != null and player_data.is_newbie:
		# 🎁 đồ khởi đầu (chỉ 1 lần)
		InventoryManager.set_player(player_data)
		for id in {"khoailang": 10, "cuoc_normal": 1, "cucai_s": 1}:
			var it = ItemDb.items.get(id)
			if it:
				InventoryManager.add_item(it, {"khoailang": 10, "cuoc_normal": 1, "cucai_s": 1}[id])

		if spawn_node:
			player.global_position = spawn_node.global_position
			Server._save_remote(true)
		else:
			player.global_position = Vector2.ZERO

		player_data.is_newbie = false

	elif spawn != "" and spawn_node != null:
		player.global_position = spawn_node.global_position

	elif player_data != null:
		player.global_position = player_data.pos

	else:
		player.global_position = Vector2.ZERO

	if player.has_method("snap_camera"):
		player.snap_camera()

	# ===== SPAWN LẠI NGƯỜI CHƠI KHÁC Ở MAP MỚI =====
	for id in remote_data.keys():
		_sync_remote(id)

	if old_map and is_instance_valid(old_map):
		old_map.queue_free()


# =========================
# DROP
# =========================
func _on_drop_spawned(data):
	_spawn_drop_local(data.item, data.amount, data.pos)


func _spawn_drop_local(item: ItemData, amount: int, pos: Vector2):

	if item == null or amount <= 0:
		return

	if player == null:
		return

	var scene = preload("res://scn/Items/DroppedItem.tscn")
	var drop = scene.instantiate()

	var map = player.get_parent()
	map.add_child(drop)

	drop.global_position = pos
	drop.setup(item, amount)
