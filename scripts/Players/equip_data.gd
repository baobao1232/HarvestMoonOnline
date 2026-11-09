class_name EquipData
# Trang bị đang mặc, lưu trong player_data.quests["equip"] = { "helmet": "item_id", ... }
# (quests đã được server lưu sẵn nên không phải sửa PHP / PlayerData)
#
# Chỗ khác muốn biết người chơi đang mặc gì (vẽ layer lên nhân vật...) thì gọi:
#   EquipData.get_item("helmet")  -> ItemData hoặc null
#   EquipData.get_all()           -> { "helmet": ItemData, ... } (chỉ slot đang có đồ)

const KEYS := ["helmet", "armor", "weapon", "accessory"]


static func _store() -> Dictionary:
	var pd = SceneManager.player_data
	if pd == null:
		return {}
	if typeof(pd.quests) != TYPE_DICTIONARY:
		pd.quests = {}
	if not pd.quests.has("equip") or typeof(pd.quests["equip"]) != TYPE_DICTIONARY:
		pd.quests["equip"] = {}
	return pd.quests["equip"]


static func get_id(key: String) -> String:
	return str(_store().get(key, ""))


static func get_item(key: String) -> ItemData:
	var id := get_id(key)
	if id == "":
		return null
	return ItemDb.items.get(id, null)


static func get_all() -> Dictionary:
	var out := {}
	for k in KEYS:
		var it := get_item(k)
		if it != null:
			out[k] = it
	return out


# item_id = "" -> tháo
static func set_item(key: String, item_id: String) -> void:
	var st := _store()
	if item_id == "":
		st.erase(key)
	else:
		st[key] = item_id


static func total_atk() -> int:
	var t := 0
	for it in get_all().values():
		t += it.atk
	return t


static func total_def() -> int:
	var t := 0
	for it in get_all().values():
		t += it.def
	return t
