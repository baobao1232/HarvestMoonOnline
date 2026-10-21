extends Node
# Net.gd  (AUTOLOAD - đặt TRÊN Client trong danh sách autoload)
#
# Chạy server:  godot --headless -- --server
# Client: gọi Net.join(ip, ten_nhan_vat) sau khi login

signal remote_joined(id, data)          # data: name, map, pos, has_pos, anim
signal remote_state(id, pos, anim)
signal remote_map(id, map)
signal remote_left(id)
signal server_lost

const PORT := 7777
const MAX_CLIENTS := 32

var server_ip := "127.0.0.1"   # đổi thành IP VPS khi deploy
var is_server := false
var online := false            # client: đã kết nối xong tới server

var players := {}              # CHỈ server dùng: peer_id -> {name,map,pos,has_pos,anim}

var my_name := ""
var my_map := ""


func _ready():
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--server" in args:
		start_server()


# ===============================
# SERVER
# ===============================
func start_server():
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("NET: không mở được port %d (err %d)" % [PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	print("🖥️ SERVER LISTENING ON UDP ", PORT)


func _on_peer_disconnected(id: int):
	if not is_server:
		return
	if players.has(id):
		print("🚪 PEER LEFT:", id, players[id].name)
		players.erase(id)
		cl_left.rpc(id)


# ===============================
# CLIENT
# ===============================
func join(ip: String = "", pname: String = ""):
	if is_server or online:
		return
	if ip != "":
		server_ip = ip
	my_name = pname

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(server_ip, PORT)
	if err != OK:
		push_error("NET: create_client lỗi %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("🌐 CONNECTING TO ", server_ip, ":", PORT)


func _on_connected():
	online = true
	print("✅ CONNECTED, id =", multiplayer.get_unique_id())
	srv_register.rpc_id(1, my_name, my_map)


func _on_connect_failed():
	print("❌ NET: kết nối thất bại")
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	print("❌ NET: mất kết nối server")
	online = false
	multiplayer.multiplayer_peer = null
	server_lost.emit()


# ---- API cho game gọi ----
func send_state(pos: Vector2, anim: String):
	if online:
		srv_state.rpc_id(1, pos, anim)


func send_map(map: String):
	my_map = map
	if online:
		srv_map.rpc_id(1, map)


# ===============================
# RPC: CLIENT -> SERVER
# ===============================
@rpc("any_peer", "call_remote", "reliable")
func srv_register(pname: String, map: String):
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()

	# gửi danh sách người đang online cho người mới
	for pid in players:
		cl_joined.rpc_id(id, pid, players[pid])

	players[id] = {
		"name": pname.substr(0, 24),
		"map": map,
		"pos": Vector2.ZERO,
		"has_pos": false,
		"anim": "idle_down"
	}

	# báo người mới cho những người cũ
	for pid in players:
		if pid != id:
			cl_joined.rpc_id(pid, id, players[id])

	print("👤 REGISTER:", id, pname, "| online:", players.size())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_state(pos: Vector2, anim: String):
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return

	var p = players[id]
	p.pos = pos
	p.anim = anim
	p.has_pos = true

	for pid in players:
		if pid != id:
			cl_state.rpc_id(pid, id, pos, anim)


@rpc("any_peer", "call_remote", "reliable")
func srv_map(map: String):
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return

	players[id].map = map
	players[id].has_pos = false   # chờ state mới ở map mới

	for pid in players:
		if pid != id:
			cl_map.rpc_id(pid, id, map)


# ===============================
# RPC: SERVER -> CLIENT
# ===============================
@rpc("authority", "call_remote", "reliable")
func cl_joined(id: int, data: Dictionary):
	remote_joined.emit(id, data)


@rpc("authority", "call_remote", "unreliable_ordered")
func cl_state(id: int, pos: Vector2, anim: String):
	remote_state.emit(id, pos, anim)


@rpc("authority", "call_remote", "reliable")
func cl_map(id: int, map: String):
	remote_map.emit(id, map)


@rpc("authority", "call_remote", "reliable")
func cl_left(id: int):
	remote_left.emit(id)
