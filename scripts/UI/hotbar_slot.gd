extends Control

var item = null
var amount := 0

@onready var icon: TextureRect = $Icon
@onready var bg: TextureRect = $BG
@onready var amount_bg = $BG/Amount_BG
@onready var amount_label: Label = $BG/Amount_BG/Amount


func _ready():

	# SET Z_INDEX
	bg.z_index = 0
	icon.z_index = 10
	amount_bg.z_index = 20
	amount_label.z_index = 30

	# TẮT RELATIVE
	bg.z_as_relative = false
	icon.z_as_relative = false

	# ĐẢM BẢO ICON KHÔNG BỊ CHE
	icon.show_behind_parent = false

	_ensure_child_order()
	_clear()
# ===============================

# ===============================
# ĐẢM BẢO THỨ TỰ CON
# ===============================
func _ensure_child_order():

	if not bg or not icon:
		return

	# chỉ move node cùng cấp
	if bg.get_parent() == self:
		move_child(bg, 0)

	if icon.get_parent() == self:
		move_child(icon, -1)

# ===============================
# SET ITEM
# ===============================
func set_item(new_item, new_amount := 1):

	if new_item == null:
		_clear()
		return
	
	var final_amount = int(max(new_amount, 1))
	
	item = new_item
	amount = final_amount
	
	if icon and item.icon:
		icon.texture = item.icon
		icon.visible = true
	
	_update_amount()
	_ensure_child_order()

# ===============================
# CLEAR SLOT
# ===============================
func _clear():
	
	item = null
	amount = 0
	
	if icon:
		icon.texture = null
		icon.visible = false
	
	if amount_bg:
		amount_bg.visible = false
	
	if amount_label:
		amount_label.text = ""


# ===============================
# UPDATE UI
# ===============================
func _update_amount():
	if item == null:
		if amount_bg:
			amount_bg.visible = false
		return
	
	if amount <= 1:
		if amount_bg:
			amount_bg.visible = false
	else:
		if amount_bg:
			amount_bg.visible = true
		if amount_label:
			amount_label.text = str(amount)


# ===============================
# GETTERS
# ===============================
func get_item():
	return item

func get_amount():
	return amount


# ===============================
# RESET
# ===============================
func reset_slot():
	_clear()
