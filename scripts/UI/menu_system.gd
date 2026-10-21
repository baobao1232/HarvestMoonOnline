extends Control

@onready var grid = $BG/GridContainer
@onready var cursor = $BG/cursor

var items := []
var index := 0
var columns := 3

# ===== HOLD INPUT =====
var first_delay := 0.25
var repeat_delay := 0.08
var hold_time := 0.0
var is_holding := false

# ===== VISUAL =====
var last_item = null
var lift := 6
var origin_pos := Vector2.ZERO

# ===============================
# READY
# ===============================
func _ready():
	call_deferred("setup_menu")

func setup_menu():
	items = grid.get_children()
	reset_cursor()

# ===============================
# RESET CURSOR
# ===============================
func reset_cursor():
	index = 0
	update_cursor()

# ===============================
# UPDATE CURSOR + HIGHLIGHT
# ===============================
func update_cursor():
	if items.is_empty():
		return

	var target = items[index]
	var rect = target.get_global_rect()

	# ===== CURSOR =====
	var x = rect.position.x - cursor.size.x - 4
	var y = rect.position.y + rect.size.y / 2 - cursor.size.y / 2
	cursor.global_position = Vector2(floor(x), floor(y))

	# ===== RESET ITEM CŨ =====
	if last_item != null:
		last_item.scale = Vector2.ONE
		last_item.modulate = Color(1,1,1)
		if last_item.has_node("Icon"):
			var last_icon = last_item.get_node("Icon")
			last_icon.position = Vector2.ZERO
			last_icon.scale = Vector2.ONE

	# ===== HIGHLIGHT =====
	target.scale = Vector2(1.1, 1.1)
	target.modulate = Color(1.15, 1.15, 1.15)
	if target.has_node("Icon"):
		var icon = target.get_node("Icon")
		icon.position = Vector2(0, -lift)
		icon.scale = Vector2(1.1, 1.1)

	last_item = target

# ===============================
# MOVE
# ===============================
func move(dir: Vector2):
	var row = int(index / columns)
	var col = int(index % columns)

	if dir.x > 0:
		col += 1
	elif dir.x < 0:
		col -= 1
	elif dir.y > 0:
		row += 1
	elif dir.y < 0:
		row -= 1

	if col < 0 or col >= columns:
		return

	var new_index = row * columns + col
	if new_index < 0 or new_index >= items.size():
		return

	index = new_index
	update_cursor()

# ===============================
# CONFIRM
# ===============================
func confirm():
	match index:
		0:
			var scene = preload("res://scn/UI/InventoryUI.tscn")

			if SaveManager.player:
				InventoryManager.set_player(SaveManager.player)

			# 🔥 ĐÓNG MENU TRƯỚC
			UIManager.close()

			# 🔥 MỞ INVENTORY
			UIManager.open(scene, null, "inventory")

		1:
			print("QUEST")

		2:
			print("CROPS")

		3:
			print("HOME")

		4:
			print("SHOP")

		5:
			logout()
# ===============================
# LOGOUT FUNCTION
# ===============================
# ===============================
# LOGOUT - XÓA SẠCH + CHUYỂN LOGIN
# ===============================
func logout():
	print("=== LOGOUT START ===")

	if is_instance_valid(SaveManager) and is_instance_valid(SaveManager.player):
		SaveManager.save(SaveManager.player)

	SaveManager.player = null
	SaveManager.current_user = ""

	InventoryManager.current_player = null
	InventoryManager.slots = []

	if is_instance_valid(SceneManager):
		SceneManager.player = null
		SceneManager.next_spawn = ""

	UIManager.reset_all()

	var root = get_tree().root

	var hud = root.get_node_or_null("Hud")
	if hud:
		hud.queue_free()

	var daynight = root.get_node_or_null("DayNight")
	if daynight:
		daynight.queue_free()

	# 🔥 KHÔNG await nữa
	get_tree().change_scene_to_file("res://scn/Login.tscn")

	print("✅ LOGOUT DONE")
	
# ===== HELPER: TÌM FILE LOGIN =====
func find_login_scene(dir: DirAccess, path: String):
	for file in dir.get_files():
		if file == "Login.tscn" or file == "login.tscn":
			print("🔍 Found login scene at: res://" + path + file)
	for folder in dir.get_directories():
		var sub_dir = DirAccess.open("res://" + path + folder + "/")
		if sub_dir:
			find_login_scene(sub_dir, path + folder + "/")

# ===============================
# INPUT
# ===============================
func _process(delta):
	if not is_instance_valid(UIManager):
		return

	if UIManager.input_mode != "menu":
		return

	var dpad = get_tree().get_first_node_in_group("dpad")
	if dpad == null:
		return

	var dir = dpad.direction

	if dir == Vector2.ZERO:
		hold_time = 0
		is_holding = false
	else:
		hold_time -= delta
		if not is_holding:
			move(dir)
			hold_time = first_delay
			is_holding = true
		elif hold_time <= 0:
			move(dir)
			hold_time = repeat_delay

	if Input.is_action_just_pressed("interact"):
		confirm()

	if Input.is_action_just_pressed("interactx"):
		if is_instance_valid(UIManager):
			UIManager.close()
