extends Node

var current_user := ""
var player : PlayerData


func get_save_path():

	if current_user == "":
		push_error("SaveManager: current_user not set")
		return ""

	return "user://accounts/%s/player.save" % current_user


# ===============================
# SAVE
# ===============================
func save(data:PlayerData):

	if current_user == "":
		print("Save failed: no user logged in")
		return

	player = data

	var path = get_save_path()

	DirAccess.make_dir_recursive_absolute("user://accounts/%s" % current_user)

	var file = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("❌ Save failed: cannot open file " + path)
		return

	var json = JSON.stringify(data.to_dict())

	file.store_string(json)
	file.flush() # 🔥 BẮT BUỘC
	file.close()

	print("GAME SAVED:", path)


# ===============================
# LOAD
# ===============================
func load() -> PlayerData:

	if current_user == "":
		print("Load failed: no user logged in")
		return null

	var path = get_save_path()

	if !FileAccess.file_exists(path):
		print("No save file:", path)
		return null

	var file = FileAccess.open(path, FileAccess.READ)

	if file == null:
		print("Load failed: cannot open file")
		return null

	var text = file.get_as_text()
	file.close()

	# 🔥 FIX QUAN TRỌNG
	var json = JSON.parse_string(text)

	if typeof(json) != TYPE_DICTIONARY:
		print("❌ Save corrupted:", path)
		return null

	var data = PlayerData.new()
	data.from_dict(json)

	player = data

	print("GAME LOADED:", path)

	return data
