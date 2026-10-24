extends CanvasLayer

@onready var btn_inv = $RightMenu/BtnSystem

var inventory_ref = null
var selecting_hotbar := false
var hotbar_index := 0

var hold_time := 0.0
var move_delay := 0.15
var using_hotbar := false
var move_timer := 0.0
var temp_cursor = null

@onready var hotbar_slots = [
	$BoxHotbar/HotbarSlot,
	$BoxHotbar/HotbarSlot2,
	$BoxHotbar/HotbarSlot3,
	$BoxHotbar/HotbarSlot4,
	$BoxHotbar/HotbarSlot5,
	$BoxHotbar/HotbarSlot6,
	$BoxHotbar/HotbarSlot7,
	$BoxHotbar/HotbarSlot8
]

@onready var hotbar_cursor = $Cursor
@onready var name_label = get_node_or_null("NameLabel")
@onready var pos_label = get_node_or_null("PosLabel")


# ===============================
# READY (FINAL FIX)
# ===============================
func _ready():

	await get_tree().process_frame

	if UIManager:
		UIManager.hud = self
		Dbg.p("🔥 HUD REGISTER:", self)

	layer = 1

	$RightMenu.mouse_filter = Control.MOUSE_FILTER_PASS
	$BoxHotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_inv.mouse_filter = Control.MOUSE_FILTER_STOP

	# ===============================
	# FIX CURSOR GỐC
	# ===============================
	if hotbar_cursor.get_parent() != self:
		hotbar_cursor.get_parent().remove_child(hotbar_cursor)
		add_child(hotbar_cursor)

	hotbar_cursor.top_level = true
	hotbar_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_cursor.z_index = 999

	load_hotbar_ui()

	hotbar_cursor.visible = true
	update_hotbar_cursor()

	# 🔥 FIX SIGNAL DUPLICATE
	if not btn_inv.pressed.is_connected(_on_btn_system_pressed):
		btn_inv.pressed.connect(_on_btn_system_pressed)

	Dbg.p("✅ HUD READY:", self)


# ===============================
# PROCESS
# ===============================
func _process(delta):

	# ===============================
	# LOCK CURSOR
	# ===============================
	if selecting_hotbar:
		hotbar_cursor.visible = false

	# CLEAN TEMP CURSOR
	if not selecting_hotbar and temp_cursor != null:
		_clear_temp_cursor()

	# BLOCK DIALOG
	if DialogManager.is_showing:
		return

	# BLOCK INPUT MODE
	if UIManager.input_mode != "player" \
	and UIManager.input_mode != "hotbar_move" \
	and UIManager.input_mode != "hotbar":
		return

	# ===============================
	# GET DPAD
	# ===============================
	var dpad = get_tree().get_first_node_in_group("dpad")

	# ===============================
	# TAP A → USE ITEM
	# ===============================
	if Input.is_action_just_pressed("hotbar_select"):

		# ❌ đang move hoặc select thì bỏ
		if not using_hotbar and not selecting_hotbar:
			Dbg.p("🟡 USE ITEM")
			_use_current_item()

	# ===============================
	# HOLD A (HOTBAR SELECT)
	# ===============================
	if not selecting_hotbar:

		var is_holding := Input.is_action_pressed("hotbar_select")

		if is_holding:

			hold_time += delta

			if hold_time > 0.15 and not using_hotbar:

				Dbg.p("🔥 ENTER HOTBAR MOVE")

				using_hotbar = true
				UIManager.input_mode = "hotbar_move"
				move_timer = 0

				# 🔥 STOP MOVEMENT NGAY
				if dpad:
					dpad.direction = Vector2.ZERO

				# 🔥 FORCE PLAYER IDLE
				var player = get_tree().get_first_node_in_group("local_player")
				if player:
					if player.has_method("update_animation"):
						player.update_animation(Vector2.ZERO)

					if player.has_node("AnimatedSprite2D"):
						var anim = player.get_node("AnimatedSprite2D")
						if anim:
							var dir = player.last_dir if "last_dir" in player else "down"
							anim.play("idle_" + dir)

		else:

			if using_hotbar:
				Dbg.p("🔚 EXIT HOTBAR MOVE")

				using_hotbar = false
				UIManager.input_mode = "player"

				if dpad:
					dpad.direction = Vector2.ZERO

			hold_time = 0
			move_timer = 0

	# ===============================
	# MOVE HOTBAR
	# ===============================
	if dpad and (UIManager.input_mode == "hotbar_move" or selecting_hotbar):

		var dir: Vector2 = dpad.direction

		if dir == Vector2.ZERO:
			move_timer = 0
		else:
			move_timer -= delta

			if move_timer <= 0:

				if dir.x > 0:
					hotbar_index += 1
				elif dir.x < 0:
					hotbar_index -= 1

				hotbar_index = wrapi(hotbar_index, 0, hotbar_slots.size())
				Dbg.p("🎯 SWITCH SLOT:", hotbar_index)

				if selecting_hotbar:
					update_temp_cursor()
				else:
					update_hotbar_cursor()
					_update_player_item(true)

				move_timer = move_delay

	# ===============================
	# SELECT MODE
	# ===============================
	if selecting_hotbar:

		if Input.is_action_just_pressed("interact"):
			confirm_hotbar_assign()
			return

		if Input.is_action_just_pressed("interactx"):

			selecting_hotbar = false
			UIManager.input_mode = "inventory"

			if inventory_ref:
				inventory_ref.visible = true
				inventory_ref.return_from_hotbar(false)

			_clear_temp_cursor()

			hotbar_cursor.visible = true
			update_hotbar_cursor()

			return

		return

# ===============================
# ENTER HOTBAR MODE
# ===============================
func enter_hotbar_select(inv):

	Dbg.p("🟢 ENTER HOTBAR SELECT")

	inventory_ref = inv
	selecting_hotbar = true

	using_hotbar = false
	hold_time = 0
	move_timer = 0

	UIManager.input_mode = "hotbar"

	if inventory_ref:
		inventory_ref.visible = false

	_clear_temp_cursor()

	hotbar_cursor.visible = false

	# 🔥 CREATE TEMP CURSOR
	temp_cursor = hotbar_cursor.duplicate()
	temp_cursor.name = "TempCursor"

	add_child(temp_cursor)

	temp_cursor.top_level = true
	temp_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	temp_cursor.visible = true
	temp_cursor.z_index = 1000

	temp_cursor.scale = Vector2.ONE
	temp_cursor.size = hotbar_cursor.size

	update_temp_cursor()


# ===============================
# CONFIRM
# ===============================
func confirm_hotbar_assign():

	if inventory_ref == null:
		return

	var index = inventory_ref.last_slot_index
	var data = inventory_ref.get_slot(index)

	if data == null:
		return

	var new_item = data["item"]
	var new_amount = data["amount"]

	var slot = hotbar_slots[hotbar_index]

	# ===============================
	# 🔥 LẤY ITEM CŨ TRONG HOTBAR
	# ===============================
	var old_item = null
	var old_amount = 0

	if slot.has_method("get_item"):
		old_item = slot.get_item()

	if slot.has_method("get_amount"):
		old_amount = slot.get_amount()

	# ===============================
	# 🔥 TRẢ ITEM CŨ VỀ INVENTORY
	# ===============================
	if old_item != null:

		var success = InventoryManager.add_item(old_item, old_amount)

		if not success:
			Dbg.p("❌ Inventory full → không swap")
			return

	# ===============================
	# 🔥 GÁN ITEM MỚI
	# ===============================
	slot.set_item(new_item, new_amount)

	# ===============================
	# 🔥 XOÁ SLOT INVENTORY CŨ
	# ===============================
	InventoryManager.slots[index] = null

	if inventory_ref.has_method("refresh"):
		inventory_ref.refresh()

	# ===============================
	# 🔥 SAVE
	# ===============================
	if Server.has_method("request_save_hotbar"):
		Server.request_save_hotbar(hotbar_index, new_item, new_amount)

	Dbg.p("🔥 SWAP:", new_item.name, "<->", old_item if old_item else "empty")

	# ===============================
	# 🔥 EXIT
	# ===============================
	selecting_hotbar = false
	UIManager.input_mode = "inventory"

	inventory_ref.visible = true
	inventory_ref.return_from_hotbar(true)

	_clear_temp_cursor()

	hotbar_cursor.visible = true
	update_hotbar_cursor()
# ===============================
# TEMP CURSOR
# ===============================
func update_temp_cursor():

	if temp_cursor == null:
		return

	var slot = hotbar_slots[hotbar_index]

	var slot_center = slot.global_position + slot.size / 2
	var cursor_half = temp_cursor.size / 2

	temp_cursor.global_position = slot_center - cursor_half + Vector2(0, 2)


func _clear_temp_cursor():

	if temp_cursor != null and is_instance_valid(temp_cursor):
		temp_cursor.queue_free()

	temp_cursor = null

	# 🔥 HARD CLEAN clone rác
	for c in get_children():
		if c != hotbar_cursor and c.name == "TempCursor":
			c.queue_free()


# ===============================
# CURSOR
# ===============================
func update_hotbar_cursor():

	var slot = hotbar_slots[hotbar_index]

	var slot_center = slot.global_position + slot.size / 2
	var cursor_half = hotbar_cursor.size / 2

	hotbar_cursor.global_position = slot_center - cursor_half + Vector2(0, 2)


# ===============================
# PLAYER ITEM
# ===============================
func _update_player_item(play_anim := false):

	var slot = hotbar_slots[hotbar_index]

	if not slot.has_method("get_item"):
		return

	var item = slot.get_item()

	# 🔥 LẤY PLAYER CHUẨN
	var player = get_tree().get_first_node_in_group("local_player")

	if player == null:
		Dbg.p("❌ NO LOCAL PLAYER")
		return

	# 🔥 UPDATE VISUAL
	if player.has_method("show_hotbar_item"):
		player.show_hotbar_item(item)

	# 🔥 PLAY ANIM
	if play_anim and player.has_method("play_show_item_anim"):
		Dbg.p("🔥 PLAY SHOW ITEM")
		player.play_show_item_anim()
# ===============================
# LOAD HOTBAR
# ===============================
func load_hotbar_ui():

	if SaveManager.player == null:
		return

	var data = SaveManager.player.hotbar

	for i in range(hotbar_slots.size()):

		var slot = hotbar_slots[i]

		if slot.get_item() != null:
			continue

		if i >= data.size():
			continue

		var slot_data = data[i]
		if slot_data == null:
			continue

		var item = slot_data.get("item", null)
		var amount = slot_data.get("amount", 1)

		if item == null:
			continue

		slot.set_item(item, amount)


# ===============================
# BUTTON
# ===============================
func _on_btn_system_pressed():

	Dbg.p("🔥 BTN SYSTEM CLICKED")

	if DialogManager.is_showing:
		DialogManager.force_close()

	if UIManager.current_ui != null and is_instance_valid(UIManager.current_ui):
		UIManager.close()

	var scene = preload("res://scn/UI/MenuSystem.tscn")
	UIManager.open(scene, self, "menu")

func _use_current_item():

	var slot = hotbar_slots[hotbar_index]

	if not slot.has_method("get_item"):
		return

	var item = slot.get_item()

	if item == null:
		Dbg.p("❌ NO ITEM TO USE")
		return

	var player = get_tree().get_first_node_in_group("local_player")

	if player == null:
		Dbg.p("❌ NO LOCAL PLAYER")
		return
	
	if player.has_method("get_interact_target") and player.get_interact_target() != null:
		return
		
	# 🔥 FIX: gọi manager thay vì player
	ItemUseManager.use_item(player, item, slot)

	Dbg.p("🔥 USED ITEM:", item.name)
