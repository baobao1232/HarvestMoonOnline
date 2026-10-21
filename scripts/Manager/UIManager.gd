extends Node

var current_ui = null
var input_mode := "player"

var hud = null

# ===============================
# OPEN UI
# ===============================
func open(scene: PackedScene, parent = null, mode := "menu"):

	if scene == null:
		return

	# clear UI cũ
	if current_ui != null and is_instance_valid(current_ui):
		current_ui.queue_free()
		current_ui = null

	var ui = scene.instantiate()
	if ui == null:
		return

	var root = get_tree().root

	# đảm bảo có UI layer
	var ui_root = root.get_node_or_null("UIRoot")
	if ui_root == null:
		ui_root = CanvasLayer.new()
		ui_root.name = "UIRoot"
		root.add_child(ui_root)

	# luôn add vào UI layer (tránh camera / world scale)
	ui_root.add_child(ui)

	# chống scale rác
	if ui is Control:
		ui.scale = Vector2.ONE
		ui.rotation = 0

	current_ui = ui
	input_mode = mode
# CLOSE UI
# ===============================
func close():

	if current_ui != null and is_instance_valid(current_ui):
		current_ui.queue_free()

	current_ui = null
	input_mode = "player"

	print("🔴 CLOSE UI")


# ===============================
# SETUP GAME UI (LOGIN → GAME)
# ===============================
func setup_game_ui():

	print("🔥 setup_game_ui CALLED FROM:", get_stack())

	close()

	_ensure_hud()
	_ensure_dpad()
	_ensure_daynight()

	input_mode = "player"

	print("🎮 GAME UI READY")

func _ensure_dpad():

	var root = get_tree().root

	var exist = root.get_node_or_null("Dpad")
	if exist != null:
		print("✔ DPAD EXISTS")
		return

	var scene = load("res://scn/Dpad.tscn")

	if scene == null:
		print("❌ LOAD DPAD FAIL")
		return

	var dpad = scene.instantiate()

	if dpad == null:
		print("❌ INSTANTIATE DPAD FAIL")
		return

	dpad.name = "Dpad"

	# ❌ XOÁ 2 DÒNG NÀY
	# dpad.top_level = true
	# dpad.z_index = 9999

	root.call_deferred("add_child", dpad)

	print("🎮 DPAD READY:", dpad)
	
# ===============================
# ENSURE HUD (FIX NULL CRASH)
# ===============================
func _ensure_hud():

	var root = get_tree().root

	# đã có rồi thì thôi
	var exist = root.get_node_or_null("Hud")
	if exist != null:
		hud = exist
		print("✔ HUD EXISTS")
		return

	var scene = load("res://scn/UI/Hud.tscn")

	if scene == null:
		print("❌ LOAD HUD FAIL")
		return

	var inst = scene.instantiate()

	if inst == null:
		print("❌ INSTANTIATE HUD FAIL")
		return

	inst.name = "Hud"

	root.call_deferred("add_child", inst)

	hud = inst

	print("✅ HUD CREATED")


# ===============================
# ENSURE DAY NIGHT
# ===============================
func _ensure_daynight():

	var root = get_tree().root

	if root.get_node_or_null("DayNight") != null:
		return

	var scene = load("res://scn/UI/DayNight.tscn")

	if scene == null:
		print("❌ LOAD DAYNIGHT FAIL")
		return

	var dn = scene.instantiate()

	if dn == null:
		print("❌ INSTANTIATE DAYNIGHT FAIL")
		return

	dn.name = "DayNight"

	root.call_deferred("add_child", dn)

	print("🌙 DayNight READY:", dn)


# ===============================
# UPDATE PLAYER NAME (SAFE)
# ===============================
func update_player_name(name):

	if hud == null or not is_instance_valid(hud):
		return

	if hud.has_node("NameLabel"):
		hud.get_node("NameLabel").text = name

# ===============================
# REMOVE GAME UI (LOGIN CLEAN)
# ===============================
func remove_game_ui():

	print("🧹 REMOVE GAME UI")

	# xoá UI đang mở
	close()

	# xoá HUD
	var root = get_tree().root

	var hud = root.get_node_or_null("Hud")
	if hud and is_instance_valid(hud):
		hud.queue_free()

	# xoá DayNight
	var dn = root.get_node_or_null("DayNight")
	if dn and is_instance_valid(dn):
		dn.queue_free()
