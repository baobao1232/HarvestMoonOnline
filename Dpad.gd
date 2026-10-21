extends Control

var direction: Vector2 = Vector2.ZERO

@onready var up: TextureButton = $BtnUp
@onready var down: TextureButton = $BtnDown
@onready var left: TextureButton = $BtnLeft
@onready var right: TextureButton = $BtnRight

# ===== MULTI TOUCH =====
var touch_map := {}   # index -> direction

# ===== TEXTURE =====
var tex_normal := {}
var tex_pressed := {}

# ===== SCALE =====
var base_scale := {}
var last_direction := Vector2.ZERO
func _ready():

	add_to_group("dpad")

	for btn in [up, down, left, right]:

		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.focus_mode = Control.FOCUS_NONE

		# 👉 lưu texture
		tex_normal[btn] = btn.texture_normal
		tex_pressed[btn] = btn.texture_pressed

		# 👉 lưu scale gốc
		base_scale[btn] = btn.scale

	set_process_input(true)

	print("DPAD READY (MULTI TOUCH + VISUAL FIX)")


# ===============================
# MULTI TOUCH INPUT
# ===============================
func _input(event):

	# ===== TOUCH DOWN =====
	if event is InputEventScreenTouch and event.pressed:

		var pos = event.position

		if up.get_global_rect().has_point(pos):
			touch_map[event.index] = Vector2(0, -1)
			_press_btn(up)
			print("UP PRESS")

		elif down.get_global_rect().has_point(pos):
			touch_map[event.index] = Vector2(0, 1)
			_press_btn(down)
			print("DOWN PRESS")

		elif left.get_global_rect().has_point(pos):
			touch_map[event.index] = Vector2(-1, 0)
			_press_btn(left)
			print("LEFT PRESS")

		elif right.get_global_rect().has_point(pos):
			touch_map[event.index] = Vector2(1, 0)
			_press_btn(right)
			print("RIGHT PRESS")

		_update_direction()
		return


	# ===== TOUCH UP =====
	if event is InputEventScreenTouch and not event.pressed:

		if touch_map.has(event.index):

			var dir = touch_map[event.index]

			if dir == Vector2(0, -1):
				_release_btn(up)
			elif dir == Vector2(0, 1):
				_release_btn(down)
			elif dir == Vector2(-1, 0):
				_release_btn(left)
			elif dir == Vector2(1, 0):
				_release_btn(right)

			touch_map.erase(event.index)
			print("RELEASE")

		_update_direction()
		return


# ===============================
# VISUAL
# ===============================
func _press_btn(btn):

	btn.texture_normal = tex_pressed[btn]

	# 👉 scale dựa trên scale gốc (KHÔNG bị reset)
	btn.scale = base_scale[btn] * 0.9


func _release_btn(btn):

	btn.texture_normal = tex_normal[btn]

	# 👉 trả về scale ban đầu
	btn.scale = base_scale[btn]


# ===============================
# UPDATE DIRECTION
# ===============================


func _update_direction():

	var dir := Vector2.ZERO

	for d in touch_map.values():
		dir += d

	dir.x = clamp(dir.x, -1, 1)
	dir.y = clamp(dir.y, -1, 1)

	# ===============================
	# 🔥 KHÔNG ĐỔI → KHÔNG LÀM GÌ
	# ===============================
	if dir == last_direction:
		return

	last_direction = dir
	direction = dir

	# ===============================
	# RESET INPUT
	# ===============================
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("ui_left")
	Input.action_release("ui_right")

	# ===============================
	# APPLY INPUT MỚI
	# ===============================
	if dir.y < 0:
		Input.action_press("ui_up")
	if dir.y > 0:
		Input.action_press("ui_down")
	if dir.x < 0:
		Input.action_press("ui_left")
	if dir.x > 0:
		Input.action_press("ui_right")

	if dir != Vector2.ZERO:
		print("DIR:", dir)
