extends Control

var has_char := false
var player_data : PlayerData


func _ready():
	check_character()

func check_character():

	var data = SaveManager.load()

	if data == null:

		has_char = false
		$Char1.text = "+"

	else:

		has_char = true

		player_data = data   # ✅ FIX

		$Char1.text = player_data.name

func _on_char1_pressed():

	if has_char:
		print("Selected:", player_data.name)
	else:
		get_node("/root/Main").open_create_char()


func _on_create_pressed():

	if has_char:
		print("Character already exists")
		return

	get_node("/root/Main").open_create_char()

func _on_enter_pressed():

	if !has_char:
		print("No character")
		return
		
	print(player_data)
	print(player_data.map)

	SaveManager.player = player_data

	print("ENTER GAME:", player_data.name)

	var map_path = player_data.map

	# 🔥 FIX: check path tồn tại
	if map_path == "" or map_path == null or !ResourceLoader.exists(map_path):

		print("❌ MAP INVALID → RESET TO FARM")

		map_path = "res://scn/Maps/farm.tscn"

		SaveManager.player.map = map_path
		SaveManager.player.pos = Vector2.ZERO

		SceneManager.next_spawn = "Spawn"

		SaveManager.save(SaveManager.player) # 🔥 lưu lại fix luôn

	# 👉 vào game
	get_tree().change_scene_to_file(map_path)
