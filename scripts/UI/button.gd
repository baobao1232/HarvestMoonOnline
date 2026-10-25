extends Control

@onready var btn_a: TextureButton = $BtnA
@onready var btn_x: TextureButton = $BtnX

# ===== TEXTURE =====
var a_tex_normal
var a_tex_pressed

var x_tex_normal
var x_tex_pressed

# ===== A HOLD =====
var a_hold_time := 0.0
var a_hold_threshold := 0.18
var a_holding := false
var a_pressed := false
var a_touch_id := -1

# ===== X =====
var x_touch_id := -1


func _ready():

	# ===== LƯU TEXTURE =====
	a_tex_normal = btn_a.texture_normal
	a_tex_pressed = btn_a.texture_pressed

	x_tex_normal = btn_x.texture_normal
	x_tex_pressed = btn_x.texture_pressed

	# ===== KHÔNG BLOCK INPUT =====
	for btn in [btn_a, btn_x]:
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.focus_mode = Control.FOCUS_NONE

	set_process_input(true)

	Dbg.p("BUTTON READY (MULTI TOUCH + VISUAL)")


# ===============================
# MULTI TOUCH INPUT
# ===============================
func _input(event):
	if UIManager.input_mode == "chat":
		_cancel_all()
		return
		
	# ===== TOUCH DOWN =====
	if event is InputEventScreenTouch and event.pressed:

		if btn_a.get_global_rect().has_point(event.position):

			a_touch_id = event.index
			_on_a_down()

			# 🔥 EFFECT PRESS
			btn_a.texture_normal = a_tex_pressed
			return


		if btn_x.get_global_rect().has_point(event.position):

			x_touch_id = event.index
			_on_x_down()

			# 🔥 EFFECT PRESS
			btn_x.texture_normal = x_tex_pressed
			return


	# ===== TOUCH UP =====
	if event is InputEventScreenTouch and not event.pressed:

		if event.index == a_touch_id:

			a_touch_id = -1
			_on_a_up()

			# 🔥 RESET TEXTURE
			btn_a.texture_normal = a_tex_normal
			return


		if event.index == x_touch_id:

			x_touch_id = -1
			_on_x_up()

			# 🔥 RESET TEXTURE
			btn_x.texture_normal = x_tex_normal
			return


# ===============================
# BTN A
# ===============================
func _on_a_down():

	if a_pressed:
		return

	a_pressed = true
	a_hold_time = 0
	a_holding = true

	Input.action_press("hotbar_select")

	Dbg.p("A DOWN")


func _on_a_up():

	if not a_pressed:
		return

	a_pressed = false

	Input.action_release("hotbar_select")

	if a_hold_time < a_hold_threshold:

		Dbg.p("A TAP → USE")

		Input.action_press("interact")
		Input.action_release("interact")

		Input.action_press("hotbar_use")
		Input.action_release("hotbar_use")

	else:
		Dbg.p("A HOLD END")

		# 🔥🔥🔥 FIX Ở ĐÂY
		var player = get_tree().get_first_node_in_group("local_player")
		if player and player.has_method("cancel_show_item"):
			player.cancel_show_item()

	a_holding = false

# ===============================
# BTN X
# ===============================
func _on_x_down():

	Dbg.p("X DOWN")

	Input.action_press("interactx")
	Input.action_press("hotbar_cancel")


func _on_x_up():

	Input.action_release("interactx")
	Input.action_release("hotbar_cancel")


# ===============================
# HOLD TIMER
# ===============================
func _process(delta):

	if a_holding:
		a_hold_time += delta

func _cancel_all():

	if a_touch_id != -1 or a_pressed:
		a_touch_id = -1
		a_pressed = false
		a_holding = false
		a_hold_time = 0.0
		Input.action_release("hotbar_select")
		btn_a.texture_normal = a_tex_normal

	if x_touch_id != -1:
		x_touch_id = -1
		Input.action_release("interactx")
		Input.action_release("hotbar_cancel")
		btn_x.texture_normal = x_tex_normal
