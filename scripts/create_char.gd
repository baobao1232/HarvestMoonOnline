extends Control

@onready var name_input = $name


# ===============================
# READY
# ===============================
func _ready():

	if name_input:
		name_input.grab_focus()
	else:
		push_error("Name input not found")


# ===============================
# CREATE BUTTON
# ===============================
func _on_create_pressed():

	Dbg.p("CLICKED")

	if name_input == null:
		push_error("name_input NULL")
		return

	var raw_name = name_input.text
	Dbg.p("RAW:", "[" + raw_name + "]")

	var player = PlayerData.new()

	player.name = raw_name.strip_edges()

	Dbg.p("FINAL NAME:", player.name)

	# ===== VALIDATE =====
	if player.name == "":
		Dbg.p("Name is empty")
		return

	if player.name.length() < 3:
		Dbg.p("Name too short")
		return

	# ===== SET PLAYER =====
	InventoryManager.set_player(player)

	# ===== STARTER ITEM =====
	var item = ItemDb.items.get("khoailang")
	if item:
		InventoryManager.add_item(item, 10)

	# ===== SAVE =====
	Server._save_remote(true)

	Dbg.p("Created player:", player.name)

	# ===== RESET INPUT =====
	name_input.text = ""
	name_input.grab_focus()

	# ===== QUAY VỀ MENU / VÀO GAME =====
	get_tree().change_scene_to_file("res://scn/Maps/farm.tscn")
