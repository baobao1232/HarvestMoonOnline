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

	print("🌅 NEW DAY:", day)

	for pos in tiles:
		var tile = tiles[pos]

		if tile != null and tile.has_method("grow"):
			tile.grow()
