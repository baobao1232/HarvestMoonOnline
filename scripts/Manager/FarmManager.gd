extends Node

# ===============================
# DATA
# ===============================
var tiles = {}  # Dictionary: Vector2 -> tile
var tile_size := 16   # 🔥 dùng 16


# ===============================
# INIT
# ===============================
func _ready():

	if TimeManager:
		TimeManager.day_changed.connect(on_new_day)


# ===============================
# ADD TILE
# ===============================
func add_tile(pos: Vector2, tile):

	pos = snap(pos)

	tiles[pos] = tile

	update_neighbors(pos)


# ===============================
# REMOVE TILE (optional)
# ===============================
func remove_tile(pos: Vector2):

	pos = snap(pos)

	if tiles.has(pos):
		tiles.erase(pos)

	update_neighbors(pos)


# ===============================
# GET TILE
# ===============================
func get_tile(pos: Vector2):

	pos = snap(pos)

	return tiles.get(pos, null)


# ===============================
# SNAP GRID (🔥 QUAN TRỌNG)
# ===============================
func snap(pos: Vector2):

	return Vector2(
		floor(pos.x / tile_size) * tile_size,
		floor(pos.y / tile_size) * tile_size
	)


# ===============================
# 🔗 UPDATE NEIGHBOR (AUTO TILE)
# ===============================
func update_neighbors(pos: Vector2):

	var dirs = [
		Vector2(0, -tile_size),
		Vector2(0, tile_size),
		Vector2(-tile_size, 0),
		Vector2(tile_size, 0)
	]

	# update xung quanh
	for d in dirs:
		var t = get_tile(pos + d)
		if t != null and t.has_method("update_visual"):
			t.update_visual()

	# update chính nó
	var center = get_tile(pos)
	if center != null and center.has_method("update_visual"):
		center.update_visual()


# ===============================
# 🌿 GROW ALL (CALL MỖI NGÀY)
# ===============================
func on_new_day(day, season, year):

	Dbg.p("🌅 NEW DAY:", day)

	for pos in tiles:
		var tile = tiles[pos]

		if tile != null and tile.has_method("grow"):
			tile.grow()
	save_farm()

var active := false   # true khi đang ở map farm (tránh ghi đè dữ liệu bằng danh sách rỗng)

const FARM_MAP := "res://scn/Maps/farm.tscn"
const DAT_SCENE := preload("res://scn/Farms/DatTrongCay.tscn")


func clear_tiles():
	tiles.clear()
	active = false


func serialize() -> Dictionary:

	var list := []

	for pos in tiles:
		var t = tiles[pos]
		if t != null and is_instance_valid(t):
			list.append(t.to_data())

	return {"tiles": list, "day": TimeManager.total_days}


# gọi mỗi khi cuốc / tưới / trồng / thu hoạch
func save_farm():

	if not active:
		return
	if Server.player_data == null:
		return

	Server.player_data.farm = serialize()
	Server._save_remote()   # đã có throttle 5 giây


func load_farm(data: Dictionary, parent: Node):

	clear_tiles()
	active = true

	var list = data.get("tiles", [])
	var passed := clampi(TimeManager.total_days - int(data.get("day", TimeManager.total_days)), 0, 200)

	for d in list:
		var dat = DAT_SCENE.instantiate()
		parent.add_child(dat)
		dat.global_position = Vector2(float(d.x), float(d.y)) + Vector2(8, 8)
		dat.apply_data(d)

	# cho cây lớn bù những ngày offline (cây cần nước mà không được tưới thì không lớn)
	for i in passed:
		for pos in tiles:
			tiles[pos].grow()

	for pos in tiles:
		tiles[pos].update_visual()
