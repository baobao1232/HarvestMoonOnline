extends Node
# NpcManager (autoload)
#
# - Giữ NPCData của từng NPC (đọc từ JSON, cache lại).
# - Mỗi phút game / khi đổi thời tiết: hỏi lịch -> spawn, đổi mục tiêu hoặc despawn.
# - Map nào cũng chỉ cần gọi 1 lần trong _ready():
#       NpcManager.spawn_npcs(name, ysort)
#   (tốt nhất để trong MapBase.gd, rồi xoá dòng gọi ở forest.gd)

signal event_started(npc_id, event)   # UI chọn lựa chọn kết nối vào đây
signal data_ready                     # đã tải xong dữ liệu mọi NPC

# JSON nằm ở  htdocs/hvm/<DATA_DIR>/<id viết thường>.json
const DATA_DIR := "npc-data"

const NPC_IDS := ["Karen", "Ann", "Jeff"]

const SCENE_PATH := "res://scn/NPC/%s.tscn"
const DATA_PATH := "res://scripts/NPCS/%s/%s.gd"
const LOCAL_JSON_PATH := "res://scripts/NPCS/%s/%s.json"

# TimeManager.total_days = 0 là thứ mấy? 0 = Chủ nhật. Lệch thì chỉnh số này.
const WEEKDAY_OFFSET := 0

# map dự phòng khi map trong lịch không tồn tại
const FALLBACK_MAP := "Forest"

const LEG_MIN := 30.0          # phút game để đi qua 1 map
const MAX_WALK_SPEED := 140.0

# map nào nối với map nào (tên viết thường, bỏ "_Int")
const ADJ := {
	"town1": ["town2", "town3", "forest", "farm", "thoren"],
	"town2": ["town1", "town3", "supermarket"],
	"town3": ["town1", "town2", "beach"],
	"forest": ["town1", "farm", "motherhill", "thomoc"],
	"farm": ["town1", "forest"],
	"beach": ["town3"],
	"motherhill": ["forest"],
	"supermarket": ["town2"],
	"thoren": ["town1"],
	"thomoc": ["forest"],
}

var _datas := {}      # id -> NPCData
var _nodes := {}      # id -> node Npc đang có trong map hiện tại
var _keys := {}       # id -> key mốc lịch đã áp dụng

var _map_name := ""
var _parent: Node = null

var _loaded := false
var _pending := 0

var _map_exists_cache := {}
var _warned := {}     # chỉ log cảnh báo map lỗi 1 lần / NPC / map


func _ready():
	await get_tree().process_frame
	TimeManager.time_changed.connect(_on_time_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	load_all()


# ===============================
# DATA
# ===============================
func get_data(id: String) -> NPCData:
	return _datas.get(id)


# URL: cùng host với API  ->  http://.../hvm/npc-data/ann.json
func _data_url(id: String) -> String:
	var base: String = Server.API_URL.rsplit("/", true, 1)[0]
	return "%s/%s/%s.json" % [base, DATA_DIR, id.to_lower()]


# tải lại toàn bộ dữ liệu NPC (gọi lại sau khi sửa JSON trên server cũng được)
func load_all():

	_loaded = false
	_pending = NPC_IDS.size()

	if _pending == 0:
		_loaded = true
		data_ready.emit()
		return

	for id in NPC_IDS:
		_fetch(id)


func _fetch(id: String):

	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)

	req.request_completed.connect(func(result, code, _headers, body):
		req.queue_free()

		var ok := false

		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if typeof(json) == TYPE_DICTIONARY:
				ok = _make_data(id, json)

		if not ok:
			Dbg.p("NPC data: tải server lỗi, dùng bản dự phòng:", id)
			_load_local(id)

		_one_done()
	)

	if req.request(_data_url(id)) != OK:
		req.queue_free()
		_load_local(id)
		_one_done()


func _one_done():

	_pending -= 1

	if _pending <= 0 and not _loaded:
		_loaded = true
		Dbg.p("NPC data loaded:", _datas.keys())
		data_ready.emit()


# tạo NPCData: dùng <Id>.gd nếu có và nó extends NPCData, không thì NPCData thường
func _new_data(id: String) -> NPCData:

	var path := DATA_PATH % [id, id]

	if ResourceLoader.exists(path):
		var inst = load(path).new()
		if inst is NPCData:
			return inst
		push_warning("NpcManager: %s không extends NPCData -> bỏ qua, dùng NPCData thường" % path)

	return NPCData.new()


func _make_data(id: String, json: Dictionary) -> bool:

	var d := _new_data(id)

	if not d.load_dict(json):
		push_error("NpcManager: JSON của %s không hợp lệ" % id)
		return false

	_datas[id] = d
	return true


func _load_local(id: String):

	var d := _new_data(id)
	var path := LOCAL_JSON_PATH % [id, id]

	if FileAccess.file_exists(path) and d.load_json(path):
		_datas[id] = d
	else:
		push_warning("NpcManager: không có dữ liệu cho " + id)


func get_npc_node(id: String):
	var n = _nodes.get(id)
	return n if is_instance_valid(n) else null


# ===============================
# CONTEXT (thời gian / thời tiết / map)
# ===============================
func make_context() -> Dictionary:

	return {
		"hour": TimeManager.hour,
		"minute": TimeManager.minute,
		"day": TimeManager.day,
		"season": TimeManager.season,
		"season_name": TimeManager.SEASONS[TimeManager.season],
		"year": TimeManager.year,
		"total_days": TimeManager.total_days,
		"weekday": (TimeManager.total_days + WEEKDAY_OFFSET) % 7,
		"weather": WeatherManager.current_weather.to_lower(),
		"festival": false,    # chưa có hệ thống lễ hội
		"map": _map_name
	}


# ===============================
# MAP CHECK + FALLBACK
# ===============================

# map có scene thật không? ("Forest" -> scn/Maps/forest.tscn, "MotherHill" -> MotherHill.tscn)
func map_exists(map_name: String) -> bool:

	if map_name == "":
		return false

	if _map_exists_cache.has(map_name):
		return _map_exists_cache[map_name]

	var found := false

	for dir in ["res://scn/Maps/", "res://scn/House/Interior/"]:
		for n in [map_name, map_name.to_lower()]:
			if ResourceLoader.exists("%s%s.tscn" % [dir, n]):
				found = true

	_map_exists_cache[map_name] = found
	return found


# map không tồn tại -> đổi entry sang Forest.
# Vị trí: ưu tiên Marker2D "<Id>_fallback" trong forest, không có thì dùng pos trong JSON.
func fix_entry(id: String, entry: Dictionary) -> Dictionary:

	if entry.is_empty():
		return entry

	var m := str(entry.get("map", ""))

	if map_exists(m):
		return entry

	var e := entry.duplicate(true)
	e["map"] = FALLBACK_MAP
	e["spot"] = "fallback"
	e["state"] = "idle"
	e.erase("pos")           # toạ độ của map cũ không dùng được ở Forest
	
	var wk := "%s|%s" % [id, m]
	if not _warned.has(wk):
		_warned[wk] = true
		Dbg.p("NPC %s: map '%s' không tồn tại -> spawn ở %s" % [id, m, FALLBACK_MAP])

	return e


# ===============================
# SPAWN (gọi từ map._ready)
# ===============================
func spawn_npcs(current_map: String, parent: Node):

	_map_name = current_map
	_parent = parent
	_nodes.clear()    # node của map cũ đã bị free theo map
	_keys.clear()

	# dữ liệu đang tải từ server -> đợi xong mới spawn
	if not _loaded:
		await data_ready
		if not is_instance_valid(parent) or _parent != parent:
			return    # trong lúc đợi đã đổi map

	Dbg.p("=== NPC SPAWN | map:", current_map, "| hour:", TimeManager.hour)

	for id in NPC_IDS:
		refresh(id)


# vị trí đích: ưu tiên Marker2D tên "<Id>_<spot>" trong map (vd Karen_counter),
# không có thì lấy pos trong JSON
func resolve_pos(id: String, entry: Dictionary) -> Vector2:

	if entry.has("_target"):
		var t: Dictionary = entry["_target"]
		return Vector2(float(t.x), float(t.y))

	var spot := str(entry.get("spot", ""))

	if _parent != null and is_instance_valid(_parent):
		var root := _parent.get_parent()

		# marker riêng: Karen_<spot>, Jeff_counter...
		var marker = root.find_child("%s_%s" % [id, spot], true, false)
		if marker is Node2D:
			return clamp_to_map(marker.global_position)

		# spot dự phòng -> điểm spawn có sẵn của map hiện tại
		if spot == "fallback":
			for n in ["SpawnNhaThoMoc", "SpawnFarm", "SpawnTown1"]:
				var sp = root.find_child(n, true, false)
				if sp is Node2D:
					return clamp_to_map(sp.global_position)

		# pos trong JSON chỉ dùng khi nằm TRONG map hiện tại
	if entry.has("pos"):
		var p: Dictionary = entry["pos"]
		var v := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		var r := map_rect()
		if r.size == Vector2.ZERO or r.grow(-16).has_point(v):
			return v

	# không có marker/pos hợp lệ -> dùng marker bất kỳ trong YSort (điểm spawn, đi lại được)
	if _parent != null and is_instance_valid(_parent):
		for c in _parent.get_children():
			if c is Marker2D:
				return c.global_position

	var rc := map_rect()
	return rc.get_center() if rc.size != Vector2.ZERO else Vector2.ZERO

# "ThoMoc_Int" / "ThoMocInt" -> "thomoc", "Town1" -> "town1"
func norm(n: String) -> String:
	var s := n.to_lower().replace("_", "")
	if s.length() > 5 and s.ends_with("int"):
		s = s.substr(0, s.length() - 3)
	return s


# đường đi ngắn nhất giữa 2 map (BFS). Không có trong ADJ -> đi thẳng [from, to]
func find_path(from_map: String, to_map: String) -> Array:

	var a := norm(from_map)
	var b := norm(to_map)

	if a == b:
		return [a]

	if not ADJ.has(a) or not ADJ.has(b):
		return [a, b]

	var prev := {a: ""}
	var queue := [a]

	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == b:
			break
		for nx in ADJ[cur]:
			if not prev.has(nx):
				prev[nx] = cur
				queue.append(nx)

	if not prev.has(b):
		return [a, b]

	var path := []
	var c: String = b
	while c != "":
		path.push_front(c)
		c = prev[c]

	return path


# vị trí cửa dẫn sang map `other` trong map hiện tại
func door_pos(other: String) -> Vector2:

	if _parent == null or not is_instance_valid(_parent):
		return Vector2.ZERO

	var root := _parent.get_parent()

	for a in root.find_children("*", "Area2D", true, false):

		var tm = a.get("target_map")
		if tm == null or str(tm) == "":
			continue

		if norm(str(tm).get_file().get_basename()) != other:
			continue

		var shape = a.get_node_or_null("CollisionShape2D")
		var p: Vector2 = shape.global_position if shape is Node2D else a.global_position
		return clamp_to_map(p)

	var r := map_rect()
	return r.get_center() if r.size != Vector2.ZERO else Vector2.ZERO


# NPC đang ở đâu / đang làm gì NGAY BÂY GIỜ trong map hiện tại?
# trả {} = không có mặt ở map này. Có thì: entry, key, (start, speed nếu đang đi qua map)
func make_plan(id: String, data: NPCData, ctx: Dictionary) -> Dictionary:

	var raw: Dictionary = data.get_current_entry(ctx)
	if raw.is_empty():
		return {}

	var entry := fix_entry(id, raw)
	var cur_map := norm(_map_name)

	# mốc liền trước (mốc cuối hôm trước nếu đây là mốc đầu ngày)
	var list := data.get_entries(ctx)
	var prev_raw := raw
	var rk := data.entry_key(raw)
	for i in list.size():
		if data.entry_key(list[i]) == rk:
			prev_raw = list[(i - 1 + list.size()) % list.size()]
			break

	var prev := fix_entry(id, prev_raw)
	var locked := str(entry.get("state", "idle")) == "inside_locked"

	var from_map := norm(str(prev.get("map", "")))
	var to_map := norm(str(entry.get("map", "")))

	# ===== CÙNG MAP: đứng/đi như cũ =====
	if from_map == to_map:
		if to_map != cur_map or locked:
			return {}
		return {"entry": entry, "key": data.entry_key(entry)}

	# ===== KHÁC MAP: đi bộ qua từng map =====
	var path := find_path(from_map, to_map)

	var dt := float(int(ctx.hour) * 60 + int(ctx.minute)) - float(NPCData._mins(entry))
	if dt < 0.0:
		dt += 1440.0

	var k := mini(int(dt / LEG_MIN), path.size() - 1)

	if path[k] != cur_map:
		return {}      # NPC đang ở map khác trên đường đi

	var last := (k == path.size() - 1)

	if last and locked:
		return {}      # đã tới nơi và vào nhà

	var in_leg := dt - k * LEG_MIN
	var frac := clampf(in_leg / LEG_MIN, 0.0, 1.0)

	var start: Vector2 = resolve_pos(id, prev) if k == 0 else door_pos(path[k - 1])
	var target: Vector2 = resolve_pos(id, entry) if last else door_pos(path[k + 1])
	var here_pos := start.lerp(target, frac)

	var e := entry.duplicate(true)
	e["_target"] = {"x": target.x, "y": target.y}
	if not last:
		e["state"] = "walk"

	var remain_real := (LEG_MIN - in_leg) * TimeManager.real_seconds_per_game_minute
	var spd := MAX_WALK_SPEED
	if remain_real > 0.5:
		spd = clampf(here_pos.distance_to(target) / remain_real, data.speed, MAX_WALK_SPEED)

	return {
		"entry": e,
		"key": "%s_k%d" % [data.entry_key(entry), k],
		"start": here_pos,
		"speed": spd
	}
	
# ===============================
# REFRESH 1 NPC
# ===============================
func refresh(id: String):

	if _parent == null or not is_instance_valid(_parent):
		return

	var data := get_data(id)
	if data == null:
		return

	var plan := make_plan(id, data, make_context())

	if plan.is_empty():
		_despawn(id)
		return

	var node = _nodes.get(id)
	if node != null and not is_instance_valid(node):
		_nodes.erase(id)
		node = null

	var key: String = plan.key

	if node != null and _keys.get(id, "") == key:
		return    # mốc không đổi

	_keys[id] = key

	var entry: Dictionary = plan.entry
	Dbg.p("NPC %s -> %s / %s | %s" % [id, entry.get("map", ""), entry.get("spot", ""), entry.get("state", "")])

	if node == null:
		node = _spawn(id)
		if node == null:
			return
		if plan.has("start"):
			node.global_position = plan.start      # xuất hiện ở đúng điểm đã đi được
			node.apply_entry(entry, false)         # rồi đi tiếp
		else:
			node.apply_entry(entry, true)
	else:
		node.apply_entry(entry, false)

	node.speed = float(plan.get("speed", data.speed))

func _spawn(id: String):

	var path := SCENE_PATH % id

	# không có scene riêng -> mượn scene của NPC khác đang có
	if not ResourceLoader.exists(path):
		path = ""
		for other in NPC_IDS:
			var p := SCENE_PATH % other
			if ResourceLoader.exists(p):
				path = p
				break

		if path == "":
			push_warning("NpcManager: không có scene NPC nào trong res://scn/NPC/")
			return null

	var node = load(path).instantiate()

	if not (node is CharacterBody2D) or not ("npc_id" in node) or not node.has_method("apply_entry"):
		push_error("NpcManager: %s sai script (cần Npc.gd)" % path)
		node.queue_free()
		return null

	node.npc_id = id
	_parent.add_child(node)
	_nodes[id] = node

	Dbg.p("SPAWN NPC:", id)
	return node

func _despawn(id: String):

	var node = _nodes.get(id)

	if node != null and is_instance_valid(node):
		node.queue_free()
		Dbg.p("DESPAWN NPC:", id)

	_nodes.erase(id)
	_keys.erase(id)


# ===============================
# SIGNAL
# ===============================
func _on_time_changed(_hour, _minute):
	for id in NPC_IDS:
		refresh(id)


func _on_weather_changed(_weather):
	for id in NPC_IDS:
		refresh(id)


# ===============================
# EVENT
# ===============================
# Npc gọi khi bắt đầu 1 heart event. Có UI lựa chọn thì connect event_started,
# UI chọn xong gọi data.complete_event(event_id, choice_idx).
# Chưa có UI thì tự chọn lựa chọn đầu tiên (chỉ cộng tình bạn).
func start_event(id: String, ev: Dictionary):

	if not event_started.get_connections().is_empty():
		event_started.emit(id, ev)
		return

	var data := get_data(id)
	if data:
		Dbg.p("EVENT (auto choice 0):", ev.get("id", ""))
		data.complete_event(str(ev.get("id", "")), 0)


# ===============================
# DEBUG: NPC đang ở đâu?
# dùng: NpcManager.where("Karen")  hoặc lệnh chat /npc [tên]
# ===============================
func where(id: String) -> String:

	var data := get_data(id)
	if data == null:
		return "%s: không có dữ liệu" % id

	var ctx := make_context()
	var e := fix_entry(id, data.get_current_entry(ctx))

	if e.is_empty():
		return "%s: không có lịch hôm nay" % id

	var now := int(ctx.hour) * 60 + int(ctx.minute)
	var st := str(e.get("state", "idle"))
	var pos := resolve_pos(id, e)
	var node = get_npc_node(id)

	# trạng thái thực tế
	var status := ""
	if node != null:
		status = "ĐANG CÓ trong map này tại (%d, %d)" % [node.global_position.x, node.global_position.y]
	elif str(e.get("map", "")) != _map_name:
		status = "ở map khác (bạn đang ở %s)" % _map_name
	elif st == "inside_locked":
		status = "ẩn trong nhà (inside_locked)"
	else:
		status = "chưa spawn (thiếu scene hoặc map chưa gọi spawn_npcs?)"

	# mốc kế tiếp
	var next_txt := "hết lịch hôm nay"
	for x in data.get_entries(ctx):
		if NPCData._mins(x) > now:
			next_txt = "%02d:%02d -> %s / %s" % [int(x.hour), int(x.get("minute", 0)),
				str(x.map), str(x.get("spot", ""))]
			break

	return "%s | %02d:%02d | %s\nmốc: %s / %s (%s) -> đích (%d, %d)\n%s\ntiếp theo: %s" % [
		id, ctx.hour, ctx.minute, ctx.weather,
		str(e.get("map", "")), str(e.get("spot", "")), st, pos.x, pos.y,
		status, next_txt
	]
# khung của map hiện tại (theo sprite "Map"), Rect2() rỗng nếu không tìm thấy
func map_rect() -> Rect2:

	if _parent == null or not is_instance_valid(_parent):
		return Rect2()

	var root := _parent.get_parent()
	var m = root.get_node_or_null("Map")

	if not (m is Sprite2D) or m.texture == null:
		return Rect2()

	var size: Vector2 = m.texture.get_size() * m.scale
	var origin: Vector2 = m.global_position

	if m.centered:
		origin -= size * 0.5

	return Rect2(origin, size)


# ép điểm nằm trong map (chừa lề để NPC không dính mép)
func clamp_to_map(p: Vector2, margin := 16.0) -> Vector2:

	var r := map_rect()
	if r.size == Vector2.ZERO:
		return p

	return Vector2(
		clampf(p.x, r.position.x + margin, r.end.x - margin),
		clampf(p.y, r.position.y + margin, r.end.y - margin)
	)
