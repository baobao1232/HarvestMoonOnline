extends Control

const FIRST_DELAY := 0.25
const REPEAT_DELAY := 0.1

const SLOT_DEFS := [
	{"key": "helmet", "slot": ItemData.EquipSlot.HELMET, "name": "Mũ"},
	{"key": "armor", "slot": ItemData.EquipSlot.ARMOR, "name": "Áo"},
	{"key": "pants", "slot": ItemData.EquipSlot.PANTS, "name": "Quần"},
	{"key": "gloves", "slot": ItemData.EquipSlot.GLOVES, "name": "Găng tay"},
	{"key": "boots", "slot": ItemData.EquipSlot.BOOTS, "name": "Giày"},
]

@onready var bg: TextureRect = $Panel/BG
@onready var fallback: Panel = $Panel/BGFallback
@onready var cursor: Panel = $Panel/Cursor
@onready var slots_root: Control = $Panel/Slots
@onready var pick_bar: Panel = $Panel/PickBar
@onready var list_box: HBoxContainer = $Panel/PickBar/Scroll/Items
@onready var player_preview: TextureRect = $Panel/PlayerPreview
@onready var selected_icon: TextureRect = $Panel/SelectedIcon
@onready var selected_name: Label = $Panel/SelectedName
@onready var selected_desc: Label = $Panel/SelectedDesc
@onready var stats: Label = $Panel/Stats
@onready var info: Label = $Panel/Info

@onready var slot_nodes := [
	$Panel/Slots/Non,
	$Panel/Slots/Ao,
	$Panel/Slots/Quan,
	$Panel/Slots/GangTay,
	$Panel/Slots/Giay,
]

var mode := "slots" # slots | pick
var slot_i := 0
var pick_i := 0
var candidates: Array = []

var ready_for_input := false
var _prev_dir := Vector2.ZERO
var _hold := 0.0

func _ready() -> void:
	fallback.visible = bg.texture == null

	for i in slot_nodes.size():
		slot_nodes[i].get_node("Name").text = SLOT_DEFS[i].name

	_refresh_slots()
	_update_cursor()
	_show_slot_info()
	pick_bar.visible = false

	await get_tree().process_frame
	await get_tree().process_frame
	ready_for_input = true


func _process(delta: float) -> void:
	if not ready_for_input:
		return
	if UIManager.input_mode != "equip" or DialogManager.is_showing:
		return

	_handle_dpad(delta)

	if Input.is_action_just_pressed("interact"):
		_confirm()
	elif Input.is_action_just_pressed("interactx"):
		_back()


func _input(event: InputEvent) -> void:
	if not ready_for_input or UIManager.input_mode != "equip":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "slots":
			for i in slot_nodes.size():
				if slot_nodes[i].get_global_rect().has_point(event.position):
					slot_i = i
					_update_cursor()
					_show_slot_info()
					_open_pick()
					get_viewport().set_input_as_handled()
					return


func _handle_dpad(delta: float) -> void:
	var dpad = get_tree().get_first_node_in_group("dpad")
	if dpad == null:
		return

	var dir: Vector2 = dpad.direction
	if dir == Vector2.ZERO:
		_prev_dir = Vector2.ZERO
		_hold = 0.0
		return

	if dir != _prev_dir:
		_prev_dir = dir
		_hold = FIRST_DELAY
		_move(dir)
		return

	_hold -= delta
	if _hold <= 0.0:
		_hold = REPEAT_DELAY
		_move(dir)


func _move(dir: Vector2) -> void:
	if mode == "slots":
		var col := slot_i % 2
		var row := int(slot_i / 2)

		if dir.x > 0:
			col += 1
		elif dir.x < 0:
			col -= 1
		elif dir.y > 0:
			row += 1
		elif dir.y < 0:
			row -= 1

		if col < 0 or col >= 2 or row < 0:
			return

		var next_index := row * 2 + col
		if next_index >= slot_nodes.size():
			return

		slot_i = next_index
		_update_cursor()
		_show_slot_info()
	else:
		if dir.x > 0:
			pick_i += 1
		elif dir.x < 0:
			pick_i -= 1
		else:
			return

		pick_i = clampi(pick_i, 0, candidates.size() - 1)
		_refresh_rows()


func _refresh_slots() -> void:
	for i in slot_nodes.size():
		var icon: TextureRect = slot_nodes[i].get_node("Icon")
		var item: ItemData = EquipData.get_item(SLOT_DEFS[i].key)
		icon.texture = item.icon if item != null else null
		icon.visible = item != null


func _update_cursor() -> void:
	var node: Control = slot_nodes[slot_i]
	cursor.visible = true
	cursor.size = node.size + Vector2(8, 8)
	cursor.global_position = node.global_position - Vector2(4, 4)


func _show_slot_info() -> void:
	var def: Dictionary = SLOT_DEFS[slot_i]
	var item: ItemData = EquipData.get_item(def.key)

	if item == null:
		selected_icon.texture = null
		selected_name.text = def.name + " — (trống)"
		selected_desc.text = "Chọn ô này để xem các trang bị phù hợp trong túi đồ."
		stats.text = "ATK  +%d\nDEF  +%d" % [EquipData.total_atk(), EquipData.total_def()]
		info.text = "Chưa trang bị vật phẩm ở ô này."
	else:
		selected_icon.texture = item.icon
		selected_name.text = item.name
		selected_desc.text = item.description
		stats.text = "ATK  +%d\nDEF  +%d\nHP   +%d\nMP   +%d" % [item.atk, item.def, item.max_hp, item.max_mp]
		info.text = "Tổng nhân vật: ATK %d  |  DEF %d" % [EquipData.total_atk(), EquipData.total_def()]


func _open_pick() -> void:
	var def: Dictionary = SLOT_DEFS[slot_i]
	candidates = [null] # null = tháo
	var seen := {}

	for slot_data in InventoryManager.slots:
		if slot_data == null:
			continue
		var item: ItemData = slot_data.get("item") if slot_data is Dictionary else null
		if item == null or not item.is_equipment():
			continue
		if item.equip_slot != def.slot or seen.has(item.id):
			continue
		seen[item.id] = true
		candidates.append(item)

	if candidates.size() == 1 and EquipData.get_item(def.key) == null:
		pick_bar.visible = false
		info.text = "Không có trang bị phù hợp cho ô %s." % def.name
		return

	pick_i = 0
	var current_id: String = EquipData.get_id(def.key)
	for i in range(1, candidates.size()):
		if candidates[i].id == current_id:
			pick_i = i

	mode = "pick"
	pick_bar.visible = true
	_refresh_rows()


func _refresh_rows() -> void:
	for child in list_box.get_children():
		child.queue_free()

	var current_id: String = EquipData.get_id(SLOT_DEFS[slot_i].key)

	for i in candidates.size():
		var item = candidates[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 62)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_item_button_pressed.bind(i))

		if item == null:
			button.text = "Tháo"
		else:
			button.icon = item.icon
			button.expand_icon = true
			button.text = item.name
			button.tooltip_text = item.name + ("\nĐang mặc" if item.id == current_id else "")

		if i == pick_i:
			button.add_theme_stylebox_override("normal", _make_selected_style())
			button.add_theme_color_override("font_color", Color(0.25, 0.13, 0.05))
		list_box.add_child(button)

	var selected = candidates[pick_i]
	if selected == null:
		selected_icon.texture = null
		selected_name.text = "Tháo " + SLOT_DEFS[slot_i].name
		selected_desc.text = "Bỏ trang bị đang mặc ở ô này."
		stats.text = "Không cộng chỉ số"
	else:
		selected_icon.texture = selected.icon
		selected_name.text = selected.name
		selected_desc.text = selected.description
		stats.text = "ATK  +%d\nDEF  +%d\nHP   +%d\nMP   +%d" % [selected.atk, selected.def, selected.max_hp, selected.max_mp]

	info.text = "A: xác nhận    X: quay lại    ← →: chọn vật phẩm"


func _make_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.84, 0.48, 1)
	style.border_color = Color(1.0, 0.66, 0.12, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	return style


func _on_item_button_pressed(index: int) -> void:
	if mode != "pick":
		return
	pick_i = index
	_refresh_rows()


func _clear_rows() -> void:
	for child in list_box.get_children():
		child.queue_free()


func _confirm() -> void:
	if mode == "slots":
		_open_pick()
		return

	if candidates.is_empty():
		return

	var def: Dictionary = SLOT_DEFS[slot_i]
	var selected = candidates[pick_i]
	_equip(def.key, "" if selected == null else selected.id)

	mode = "slots"
	pick_bar.visible = false
	_clear_rows()
	_refresh_slots()
	_show_slot_info()
	_update_cursor()


func _equip(key: String, item_id: String) -> void:
	EquipData.set_item(key, item_id)
	Server._save_remote(true)

	var player = SceneManager.player
	if player != null and is_instance_valid(player) and player.has_method("apply_equipment"):
		player.apply_equipment()


func _back() -> void:
	if mode == "pick":
		mode = "slots"
		pick_bar.visible = false
		_clear_rows()
		_show_slot_info()
		return

	UIManager.close()
