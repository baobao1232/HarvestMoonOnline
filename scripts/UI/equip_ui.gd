extends Control
# UI mặc trang bị. Mở bằng:
#   UIManager.open(preload("res://scn/UI/EquipUI.tscn"), null, "equip")
#
# Điều khiển (giống inventory): D-pad di chuyển, A (interact) chọn, X (interactx) quay lại.
# Muốn gắn background tự vẽ: kéo ảnh vào Panel/BG -> Texture (BGFallback tự ẩn).

const COLUMNS := 2

const SLOT_DEFS := [
	{"key": "helmet",    "slot": ItemData.EquipSlot.HELMET,    "name": "Mũ"},
	{"key": "armor",     "slot": ItemData.EquipSlot.ARMOR,     "name": "Áo giáp"},
	{"key": "weapon",    "slot": ItemData.EquipSlot.WEAPON,    "name": "Vũ khí"},
	{"key": "accessory", "slot": ItemData.EquipSlot.ACCESSORY, "name": "Phụ kiện"},
]

const FIRST_DELAY := 0.25
const REPEAT_DELAY := 0.1

@onready var bg: TextureRect = $Panel/BG
@onready var fallback: Panel = $Panel/BGFallback
@onready var cursor: Panel = $Panel/Cursor
@onready var list_box: VBoxContainer = $Panel/PickList/Items
@onready var info: Label = $Panel/Info
@onready var slot_nodes := [
	$Panel/Slots/Helmet,
	$Panel/Slots/Armor,
	$Panel/Slots/Weapon,
	$Panel/Slots/Accessory,
]

var mode := "slots"      # slots | pick
var slot_i := 0
var pick_i := 0
var candidates: Array = []   # [null (tháo), ItemData, ...]

var ready_for_input := false
var _prev_dir := Vector2.ZERO
var _hold := 0.0


func _ready():
	fallback.visible = bg.texture == null

	for i in slot_nodes.size():
		slot_nodes[i].get_node("Name").text = SLOT_DEFS[i].name

	_refresh_slots()
	_update_cursor()
	_show_slot_info()

	# chờ vài frame để cú bấm A mở UI không bị tính là bấm chọn
	await get_tree().process_frame
	await get_tree().process_frame
	ready_for_input = true


# ===============================
# LOOP
# ===============================
func _process(delta):

	if not ready_for_input:
		return
	if UIManager.input_mode != "equip" or DialogManager.is_showing:
		return

	_handle_dpad(delta)

	if Input.is_action_just_pressed("interact"):
		_confirm()
	elif Input.is_action_just_pressed("interactx"):
		_back()


func _handle_dpad(delta):

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


func _move(dir: Vector2):

	if mode == "slots":
		var col := slot_i % COLUMNS
		var row := slot_i / COLUMNS

		if dir.x > 0: col += 1
		elif dir.x < 0: col -= 1
		elif dir.y > 0: row += 1
		elif dir.y < 0: row -= 1

		if col < 0 or col >= COLUMNS or row < 0:
			return

		var n := row * COLUMNS + col
		if n >= slot_nodes.size():
			return

		slot_i = n
		_update_cursor()
		_show_slot_info()

	else:
		if dir.y > 0: pick_i += 1
		elif dir.y < 0: pick_i -= 1
		else: return

		pick_i = clampi(pick_i, 0, candidates.size() - 1)
		_refresh_rows()


# ===============================
# SLOTS
# ===============================
func _refresh_slots():

	for i in slot_nodes.size():
		var icon: TextureRect = slot_nodes[i].get_node("Icon")
		var it := EquipData.get_item(SLOT_DEFS[i].key)
		icon.texture = it.icon if it != null else null
		icon.visible = it != null


func _update_cursor():
	var n: Control = slot_nodes[slot_i]
	cursor.size = n.size + Vector2(8, 8)
	cursor.global_position = n.global_position - Vector2(4, 4)


func _show_slot_info():

	var def = SLOT_DEFS[slot_i]
	var it := EquipData.get_item(def.key)

	var t: String = "%s: " % def.name
	t += it.name if it != null else "(trống)"
	t += "\nTổng ATK %d  |  DEF %d" % [EquipData.total_atk(), EquipData.total_def()]
	info.text = t


# ===============================
# PICK
# ===============================
func _open_pick():

	var def = SLOT_DEFS[slot_i]

	candidates = [null]   # null = tháo
	var seen := {}

	for s in InventoryManager.slots:
		if s == null:
			continue
		var it: ItemData = s["item"]
		if it == null or not it.is_equipment():
			continue
		if it.equip_slot != def.slot or seen.has(it.id):
			continue
		seen[it.id] = true
		candidates.append(it)

	if candidates.size() == 1 and EquipData.get_item(def.key) == null:
		info.text = "Không có trang bị phù hợp cho ô %s" % def.name
		return

	# đặt con trỏ ngay món đang mặc
	pick_i = 0
	var cur: String = EquipData.get_id(def.key)
	for i in range(1, candidates.size()):
		if candidates[i].id == cur:
			pick_i = i

	mode = "pick"
	_refresh_rows()


func _refresh_rows():

	for c in list_box.get_children():
		c.queue_free()

	var def = SLOT_DEFS[slot_i]
	var cur: String = EquipData.get_id(def.key)

	for i in candidates.size():
		var it = candidates[i]
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 22)

		var txt: String = "— Tháo —" if it == null else it.name
		if it != null and it.id == cur:
			txt += "  (đang mặc)"

		l.text = ("▶ " if i == pick_i else "    ") + txt
		if i == pick_i:
			l.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		list_box.add_child(l)

	var sel = candidates[pick_i]
	if sel == null:
		info.text = "Tháo trang bị khỏi ô %s" % def.name
	else:
		info.text = "%s\n%s\nATK +%d  DEF +%d" % [sel.name, sel.description, sel.atk, sel.def]


func _clear_rows():
	for c in list_box.get_children():
		c.queue_free()


# ===============================
# ACTIONS
# ===============================
func _confirm():

	if mode == "slots":
		_open_pick()
		return

	var def = SLOT_DEFS[slot_i]
	var sel = candidates[pick_i]

	_equip(def.key, "" if sel == null else sel.id)

	mode = "slots"
	_clear_rows()
	_refresh_slots()
	_show_slot_info()


# Chỗ duy nhất đổi trang bị. Sau này muốn server quyết định thì thay bằng
# Server.api("equip", {...}, callback) ở đây.
func _equip(key: String, item_id: String):

	EquipData.set_item(key, item_id)
	Server._save_remote(true)

	# hook để vẽ layer lên nhân vật (move.gd tự thêm hàm này khi làm layer)
	var p = SceneManager.player
	if p != null and is_instance_valid(p) and p.has_method("apply_equipment"):
		p.apply_equipment()


func _back():

	if mode == "pick":
		mode = "slots"
		_clear_rows()
		_show_slot_info()
		return

	UIManager.close()
