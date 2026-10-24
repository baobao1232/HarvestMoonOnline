extends Node
class_name ItemDatabase

@export var item_folder := "res://scripts/Items"

var items : Dictionary = {}


func _ready():
	load_items()


func load_items():
	items.clear()
	_scan_folder(item_folder)
	Dbg.p("Total items loaded:", items.size())


# ===== RECURSIVE SCAN =====
func _scan_folder(path: String):

	var dir = DirAccess.open(path)

	if dir == null:
		push_error("ItemDatabase: Cannot open folder " + path)
		return

	dir.list_dir_begin()

	var file = dir.get_next()

	while file != "":

		var full_path = path + "/" + file

		# ===== nếu là folder → gọi lại chính nó =====
		if dir.current_is_dir():
			if file != "." and file != "..":
				_scan_folder(full_path)

		# ===== nếu là file item =====
		elif file.ends_with(".tres") and not file.ends_with(".import"):

			var res = load(full_path)

			if res == null:
				push_error("Failed to load: " + full_path)
				file = dir.get_next()
				continue

			if res is not ItemData:
				push_warning("Not ItemData: " + full_path)
				file = dir.get_next()
				continue

			var item : ItemData = res

			if item.id == "":
				push_warning("Item has no ID: " + full_path)
				file = dir.get_next()
				continue

			if items.has(item.id):
				push_error("Duplicate item id: " + item.id + " at " + full_path)
				file = dir.get_next()
				continue

			items[item.id] = item
			Dbg.p("Loaded item:", item.id)

		file = dir.get_next()

	dir.list_dir_end()
