extends Control

@onready var items = $Vbox.get_children()
@onready var cursor = $Cursor

var texts = ["Use", "Drop", "Hotbar"]

var index := 0
var item = null
var slot = null

var move_delay := 0.15
var move_timer := 0.0


# ===============================
# SETUP (FIX LỖI CHÍNH)
# ===============================
func setup(i, s):

	item = i
	slot = s

	Dbg.p("📦 ACTION MENU OPEN:", item)

	# reset index
	index = 0

	update_text()
	update_selection()
	update_cursor()


# ===============================
# READY
# ===============================
func _ready():

	update_text()
	update_selection()
	update_cursor()

	# 🔥 đảm bảo nằm trên cùng
	top_level = true


# ===============================
# SET TEXT
# ===============================
func update_text():

	for i in range(items.size()):
		if i < texts.size():
			items[i].set_text(texts[i])


# ===============================
# SET INDEX
# ===============================
func set_index(i):

	index = clamp(i, 0, items.size() - 1)

	update_selection()
	update_cursor()


# ===============================
# UPDATE BG
# ===============================
func update_selection():

	for i in range(items.size()):

		var item_ui = items[i]
		var selected = (i == index)

		item_ui.set_selected(selected)

		# kill tween cũ
		if item_ui.has_meta("tween"):
			item_ui.get_meta("tween").kill()

		var tween = create_tween()
		item_ui.set_meta("tween", tween)

		if selected:
			item_ui.modulate.a = 0.0
			tween.tween_property(item_ui, "modulate:a", 1.0, 0.15)
		else:
			tween.tween_property(item_ui, "modulate:a", 0.5, 0.1)


# ===============================
# UPDATE CURSOR
# ===============================
func update_cursor():

	var target = items[index]
	var rect = target.get_rect()

	var y = target.position.y + rect.size.y / 2 - cursor.size.y / 2
	y += 20  # chỉnh offset nếu cần

	var x = target.position.x + rect.size.x + 4

	cursor.position = Vector2(x, y)


# ===============================
# CONFIRM ACTION
# ===============================
func confirm():

	match index:

		0: # USE
			Dbg.p("👉 USE ITEM")

			if SceneManager.player and SceneManager.player.has_method("use_item"):
				SceneManager.player.use_item(item, slot)

		1: # DROP
			Dbg.p("👉 DROP ITEM")

			if slot and slot.has_method("remove_amount"):
				slot.remove_amount(1)

		2: # HOTBAR
			Dbg.p("👉 HOTBAR ASSIGN")

			var hud = UIManager.get_hud()

			if hud and hud.has_method("enter_hotbar_select"):
				hud.enter_hotbar_select_from_item(item, slot)
			else:
				Dbg.p("❌ Hud NULL (không tìm thấy)")
	queue_free()
