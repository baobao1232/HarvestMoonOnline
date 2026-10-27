@tool
extends EditorScript

const ITEM_FOLDER := "res://scripts/Items"
const OUT_PATH := "D:/Xamp/htdocs/hvm/api/items.json"

# thứ tự khớp enum trong ItemData.gd
const TYPES := ["consumable", "equipment", "material", "quest", "tool", "seed"]
# export_items.gd
const TOOLS := ["none", "hoe", "axe", "pickaxe", "watering_can", "sickle", "hammer"]
const TYPE_TOOL := 4
const TYPE_SEED := 5
const TAG_FOOD := 0

var items := {}
var crops := {}


func _run():
	items.clear()
	crops.clear()
	_scan(ITEM_FOLDER)

	var f = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Không ghi được: " + OUT_PATH)
		return

	f.store_string(JSON.stringify({"items": items, "crops": crops}, "\t"))
	f.close()
	print("EXPORT OK: %d items, %d crops -> %s" % [items.size(), crops.size(), OUT_PATH])


func _scan(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Không mở được folder: " + path)
		return

	for sub in dir.get_directories():
		_scan(path + "/" + sub)

	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue

		var full = path + "/" + file
		var res = load(full)

		if res == null or not ("id" in res):
			print("BỎ QUA (không phải ItemData): ", full)
			continue

		if res.id == "":
			push_warning("Item không có id: " + full)
			continue

		if items.has(res.id):
			push_error("TRÙNG id '%s': %s" % [res.id, full])
			continue

		print("  + ", res.id, "  (", full, ")")
		_add(res)


func _add(it):
	var t: int = int(it.type)
	var entry := {"max": int(it.max_stack), "price": int(it.price)}
	
	if t == TYPE_TOOL:
		entry["type"] = "tool"
		entry["tool"] = TOOLS[int(it.tool_type)]
	elif t == TYPE_SEED:
		entry["type"] = "seed"
	elif t == 0 and (TAG_FOOD in it.tags):
		entry["type"] = "food"
	else:
		entry["type"] = TYPES[t]

	items[it.id] = entry

	if t == TYPE_SEED and it.grow_days.size() > 0 and it.crop_textures.size() > 0 and it.harvest_item != null:
		var days := []
		for d in it.grow_days:
			days.append(int(d))

		crops[it.id] = {
			"grow": days,
			"stages": it.crop_textures.size(),
			"need_water": bool(it.need_water),
			"harvest": it.harvest_item.id,
			"regrow": bool(it.regrow)
		}
