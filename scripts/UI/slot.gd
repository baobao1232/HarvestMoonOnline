extends Control

@onready var icon = $Icon
@onready var amount_bg = $AmountBG
@onready var amount_label = $AmountBG/AmountLabel

var item = null
var amount = 0


func set_item(item_data, amt):

	item = item_data
	amount = int(amt)


	# ===== KHÔNG CÓ ITEM =====
	if item == null:
		icon.texture = null
		icon.hide()

		amount_bg.hide()   # 🔥 phải ẩn cả BG
		amount_label.text = ""

		return


	# ===== HIỂN THỊ ICON =====
	icon.texture = item.icon
	icon.show()


	# ===== HIỂN THỊ STACK =====
	if item.max_stack > 1 and amount > 1:
		amount_label.text = str(amount)
		amount_bg.show()   # 🔥 show cả BG + label
	else:
		amount_label.text = ""
		amount_bg.hide()
