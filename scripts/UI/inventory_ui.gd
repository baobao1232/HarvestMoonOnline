extends Control

@onready var grid = $SlotsGrid
@onready var selector = $TextureRect/Selector
@onready var name_label = $ItemNameLabel
@onready var info_panel = $TextureRect/Information
@onready var info_name = $TextureRect/Information/ItemNameLabel
@onready var info_desc = $TextureRect/Information/ItemDesLabel
@onready var info_stack = $TextureRect/Information/ItemStackBG/ItemStack

# ===== STATE =====
var mode := "select"
var selected_index := 0
var last_slot_index := 0

# ===== ACTION MENU =====
var action_index := 0
var columns := 7

# ===== DPad hold =====
var first_delay := 0.25
var repeat_delay := 0.08
var hold_time := 0.0
var is_holding := false

var slots := []
var slot_base_pos := {}
var last_slot = null
var ignore_input := false
var action_menu = null
var action_move_delay := 0.18
var action_move_timer := 0.0

# ===============================
# SAFE GET SLOT
# ===============================
func get_slot(index):

	if index < 0 or index >= InventoryManager.slots.size():
		return null

	var data = InventoryManager.slots[index]

	if data == null:
		return null

	# 🔥 FIX: loại bỏ slot rác
	if data["amount"] <= 0:
		InventoryManager.slots[index] = null
		return null

	return data
# ===============================
# READY
# ===============================
func _ready():

	scale = Vector2.ONE
	Dbg.p("INVENTORY SCALE:", scale)
	Dbg.p("PARENT:", get_parent())
	await get_tree().process_frame
	await get_tree().process_frame

	mode = "select"
	action_index = 0
	ignore_input = false

	# 🔥 KHÔNG dùng menu cũ nữa
	action_menu = null

	setup_slots()
	refresh()
# ===============================
# SETUP
# ===============================
func setup_slots():

	slots = grid.get_children()
	slot_base_pos.clear()

	for s in slots:
		slot_base_pos[s] = s.position

	last_slot = null
	selected_index = 0

	update_selector()

	if InventoryManager.slots.size() > 0:
		show_info(get_slot(selected_index))

	refresh()


# ===============================
# REFRESH UI
# ===============================
func refresh():

	for i in range(slots.size()):

		var ui_slot = slots[i]
		var data = get_slot(i)

		if ui_slot.has_method("set_item"):
			if data != null:
				ui_slot.set_item(data["item"], data["amount"])
			else:
				ui_slot.set_item(null, 0)
		if mode == "action" and get_slot(last_slot_index) == null:
			mode = "select"
			hide_action_menu() 
			#menu tự đống khi ô hết đồ


# ===============================
# UPDATE SELECTOR
# ===============================
func update_selector():

	if slots.is_empty():
		return

	selected_index = clamp(selected_index, 0, slots.size() - 1)

	var slot = slots[selected_index]

	if last_slot != null:
		last_slot.position = slot_base_pos[last_slot]

	slot.position = slot_base_pos[slot] - Vector2(0, 6)
	last_slot = slot

	var padding := 2
	selector.size = slot.size + Vector2(padding * 2, padding * 2)
	selector.global_position = slot.global_position - Vector2(padding, padding)

	show_info(get_slot(selected_index))


# ===============================
# ACTION MENU
# ===============================
func show_action_menu():

	UIManager.input_mode = "inventory_action"

	# ===============================
	# CREATE
	# ===============================
	if action_menu == null or not is_instance_valid(action_menu):

		var scene = preload("res://scn/UI/ActionMenu.tscn")
		action_menu = scene.instantiate()
		add_child(action_menu)

		await get_tree().process_frame

	# ===============================
	# 🔥 LẤY SLOT (KHÔNG DÙNG SELECTOR NỮA)
	# ===============================
	var slot = slots[last_slot_index]
	var slot_rect = slot.get_global_rect()

	var start_pos = slot_rect.position

	var menu_size = action_menu.size
	var screen_size = get_viewport_rect().size

	var pos_x = slot_rect.position.x + slot_rect.size.x + 8

	if pos_x + menu_size.x > screen_size.x:
		pos_x = slot_rect.position.x - menu_size.x - 8

	var pos_y = slot_rect.position.y + slot_rect.size.y / 2 - menu_size.y / 2

	var final_pos = Vector2(pos_x, pos_y)

	# ===============================
	# START STATE (KHÔNG CHỚP GÓC)
	# ===============================
	action_menu.global_position = start_pos
	action_menu.scale = Vector2(0.6, 0.6)
	action_menu.modulate.a = 0.0

	action_menu.show()

	await get_tree().process_frame

	if not is_instance_valid(action_menu):
		action_menu = null
		return

	# ===============================
	# ANIMATION
	# ===============================
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(action_menu, "global_position", final_pos, 0.18)
	tween.parallel().tween_property(action_menu, "scale", Vector2(1, 1), 0.18)
	tween.parallel().tween_property(action_menu, "modulate:a", 1.0, 0.15)

	# ===============================
	# RESET INDEX
	# ===============================
	action_index = 0

	if action_menu.has_method("set_index"):
		action_menu.set_index(action_index)
func hide_action_menu():

	# ===============================
	# 🔥 CHECK CHẾT / NULL
	# ===============================
	if action_menu == null:
		return

	if not is_instance_valid(action_menu):
		Dbg.p("💀 action_menu đã bị free → reset")
		action_menu = null
		return

	# ===============================
	# ANIM
	# ===============================
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)

	tween.parallel().tween_property(action_menu, "scale", Vector2(0.7, 0.7), 0.12)
	tween.parallel().tween_property(action_menu, "modulate:a", 0.0, 0.1)

	await tween.finished

	# ===============================
	# 🔥 CHECK LẠI SAU AWAIT
	# ===============================
	if not is_instance_valid(action_menu):
		Dbg.p("💀 action_menu chết sau tween")
		action_menu = null
		return

	action_menu.hide()

	UIManager.input_mode = "inventory"
# ===============================
# INPUT
# ===============================
func handle_action():

	if ignore_input:
		return

	# chỉ chạy trong inventory
	if UIManager.input_mode != "inventory" \
	and UIManager.input_mode != "inventory_action":
		return

	# ===============================
	# BTN A
	# ===============================
	if Input.is_action_just_pressed("interact"):

		Dbg.p("A TAP → INVENTORY | mode:", mode)

		# ===== SELECT → MỞ MENU =====
		if mode == "select":

			var data = get_slot(selected_index)
			if data == null:
				return

			mode = "action"
			last_slot_index = selected_index

			await show_action_menu()
			return


		# ===== ACTION → EXECUTE =====
		elif mode == "action":

			var data = get_slot(last_slot_index)
			if data == null:
				return

			match action_index:

				0:
					Dbg.p("👉 USE ITEM")
					ItemUseManager.use_item(SceneManager.player, data["item"])

				1:
					Dbg.p("👉 DROP ITEM")
					Server.request_drop_item(last_slot_index, 1)

				# ===============================
				# HOTBAR
				# ===============================
				2:
					Dbg.p("👉 HOTBAR MODE")
					enter_hotbar_mode()
					return


			# ===============================
			# REFRESH
			# ===============================
			refresh()

			var new_data = get_slot(last_slot_index)
			show_info(new_data)

			# hết item → đóng menu
			if new_data == null:
				await hide_action_menu()
				mode = "select"

			return


	# ===============================
	# BTN B
	# ===============================
	if Input.is_action_just_pressed("interactx"):

		if mode == "action":

			mode = "select"
			await hide_action_menu()
			return

		elif mode == "select":

			await close_inventory()
			return
# ===============================
# DPAD
# ===============================
func handle_dpad(delta):

	var dpad = get_tree().get_first_node_in_group("dpad")
	if dpad == null:
		return

	var dir = dpad.direction

	if dir == Vector2.ZERO:
		hold_time = 0
		is_holding = false
		return

	hold_time -= delta

	if not is_holding:
		move_input(dir)
		hold_time = first_delay
		is_holding = true
		return

	if hold_time <= 0:
		move_input(dir)
		hold_time = repeat_delay


# ===============================
# MOVE
# ===============================
func move_input(dir: Vector2):

	if mode == "select":
		move_grid(dir)
	else:
		move_action(dir)


func move_grid(dir: Vector2):

	@warning_ignore("shadowed_global_identifier")
	var max = slots.size()

	@warning_ignore("integer_division")
	var row = int(selected_index / columns)
	var col = int(selected_index % columns)

	if dir.x > 0:
		col += 1
	elif dir.x < 0:
		col -= 1
	elif dir.y > 0:
		row += 1
	elif dir.y < 0:
		row -= 1

	if col < 0:
		col = columns - 1
		row -= 1
	elif col >= columns:
		col = 0
		row += 1

	if row < 0:
		return

	var new_index = row * columns + col
	if new_index >= max:
		return

	selected_index = new_index
	update_selector()

var last_action_dir := 0
var action_input_locked := false

var action_pressed := false

func move_action(dir: Vector2):

	if action_menu == null or not is_instance_valid(action_menu):
		return

	# ===== DEBUG =====
	if Input.is_action_just_pressed("ui_down"):
		Dbg.p("JUST DOWN FRAME")
	if Input.is_action_just_pressed("ui_up"):
		Dbg.p("JUST UP FRAME")

	# ===============================
	var is_press := false
	var move_dir := 0

	if Input.is_action_just_pressed("ui_down"):
		is_press = true
		move_dir = 1

	elif Input.is_action_just_pressed("ui_up"):
		is_press = true
		move_dir = -1

	if not is_press:
		return

	Dbg.p("MOVE TRIGGER:", move_dir, " | BEFORE:", action_index)

	action_index += move_dir
	action_index = clamp(action_index, 0, 2)

	Dbg.p("AFTER:", action_index)

	if action_menu.has_method("set_index"):
		action_menu.set_index(action_index)
# ===============================
# INFO PANEL
# ===============================
func show_info(data):

	info_panel.show()

	if data == null:
		info_name.text = ""
		info_desc.text = ""
		info_stack.get_parent().hide()
		return

	var item : ItemData = data["item"]
	var amount : int = int(data["amount"])  # 🔥 FIX

	info_name.text = item.name
	info_desc.text = item.description

	if item.max_stack > 1:
		info_stack.text = str(amount)
		info_stack.get_parent().show()
	else:
		info_stack.get_parent().hide()

func close_inventory():

	if action_menu != null and is_instance_valid(action_menu):
		action_menu.queue_free()

	action_menu = null

	UIManager.close()

	await get_tree().process_frame
	
func enter_hotbar_mode():

	mode = "hotbar"
	ignore_input = true

	await hide_action_menu()
	await get_tree().process_frame

	# 🔥 FIX CHUẨN: tìm toàn bộ tree
	var hud = get_tree().root.find_child("Hud", true, false)

	if hud and is_instance_valid(hud):
		hud.enter_hotbar_select(self)
	else:
		Dbg.p("❌ Hud NULL (không tìm thấy)")
		mode = "select"

	ignore_input = false

func return_from_hotbar(success: bool):

	ignore_input = true

	# 🔥 QUAY VỀ INVENTORY
	UIManager.input_mode = "inventory"

	if success:
		# 👉 chỉ quay về select mode (KHÔNG đóng)
		mode = "select"

	else:
		# 👉 quay lại action menu
		mode = "action"

		await get_tree().process_frame
		show_action_menu()

	# 🔥 chống input dính
	await get_tree().process_frame
	ignore_input = false
	
# ===============================
# LOOP
# ===============================

func _process(delta):

	if DialogManager.is_showing:
		return

	if UIManager.input_mode != "inventory" \
	and UIManager.input_mode != "inventory_action":
		return

	handle_action()

	# 🔥 TÁCH RIÊNG
	if mode == "action":
		var dpad = get_tree().get_first_node_in_group("dpad")
		if dpad:
			move_action(dpad.direction)
	else:
		handle_dpad(delta)
