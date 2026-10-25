extends Node

const FARM_PATH := "res://scn/Maps/farm.tscn"
const DAT_SCENE := preload("res://scn/Farms/DatTrongCay.tscn")

var tiles = {}   # Vector2 -> node DatTrongCay
var tile_size := 16
var farm_parent: Node = null
var active := false   # true khi đang ở map farm


func _ready():
	if TimeManager:
		TimeManager.day_changed.connect(on_new_day)


# qua ngày: hỏi server, server tính cây lớn rồi trả farm mới về
func on_new_day(_day, _season, _year):
	if active:
		Server.api("sync")


func save_farm():
	pass   # server giữ farm, client không lưu nữa


func clear_tiles():
	tiles.clear()
	active = false


func load_farm(data: Dictionary, parent: Node):
	clear_tiles()
	farm_parent = parent
	active = true
	sync_farm(data)


# so khớp các ô đang có với dữ liệu server: thêm / cập nhật / xoá
func sync_farm(data: Dictionary):

	if not active or farm_parent == null or not is_instance_valid(farm_parent):
		return

	var want := {}
	for d in data.get("tiles", []):
		want[snap(Vector2(float(d.x), float(d.y)))] = d

	for pos in tiles.keys():
		if not want.has(pos):
			var old = tiles[pos]
			tiles.erase(pos)
			if is_instance_valid(old):
				old.queue_free()

	for pos in want:
		var t = tiles.get(pos, null)
		if t == null or not is_instance_valid(t):
			t = DAT_SCENE.instantiate()
			t.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # thêm dòng này
			farm_parent.add_child(t)
			t.global_position = pos + Vector2(8, 8)
			tiles[pos] = t          # <-- thêm dòng này
		t.apply_data(want[pos])

	for pos in tiles:
		tiles[pos].update_visual()


func add_tile(pos: Vector2, tile):
	pos = snap(pos)
	tiles[pos] = tile
	update_neighbors(pos)


func remove_tile(pos: Vector2):
	pos = snap(pos)
	tiles.erase(pos)
	update_neighbors(pos)


func get_tile(pos: Vector2):
	var key = snap(pos)
	var t = tiles.get(key, null)
	if t != null and not is_instance_valid(t):
		tiles.erase(key)
		return null
	return t


func snap(pos: Vector2):
	return Vector2(
		floor(pos.x / tile_size) * tile_size,
		floor(pos.y / tile_size) * tile_size
	)


# autotile: cập nhật ô xung quanh và chính nó
func update_neighbors(pos: Vector2):

	var dirs = [
		Vector2(0, -tile_size), Vector2(0, tile_size),
		Vector2(-tile_size, 0), Vector2(tile_size, 0), Vector2.ZERO
	]

	for d in dirs:
		var t = get_tile(pos + d)
		if t != null and t.has_method("update_visual"):
			t.update_visual()
