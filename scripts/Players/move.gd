extends CharacterBody2D

@export var speed = 200

var dpad = null
var last_dir := "down"
var show_timer := 0.0
var is_showing_item := false
var block_anim_timer := 0.0

@onready var cam: Camera2D = $Camera2D
@onready var anim = $AnimatedSprite2D
@onready var ray = $RayCast2D
@onready var item_show = $ItemShow

@export var dat_scene: PackedScene

# realtime sync
var sync_timer := 0.0
var prev_anim := ""

# ===============================
# READY
# ===============================
func _ready():

	add_to_group("player")
	print("ANIMS:", anim.sprite_frames.get_animation_names())

	add_to_group("local_player")

	if is_instance_valid(SaveManager) and is_instance_valid(SaveManager.player):
		UIManager.update_player_name(SaveManager.player.name)

	# CAMERA
	cam.make_current()
	cam.position = Vector2.ZERO
	cam.limit_enabled = true
	cam.position_smoothing_enabled = false

	_setup_camera_limit()


# ===============================
# CAMERA LIMIT
# ===============================
func _setup_camera_limit():

	var map = get_tree().current_scene.get_node_or_null("Map")
	if map == null or map.texture == null:
		return

	var size = map.texture.get_size() * map.scale

	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = size.x
	cam.limit_bottom = size.y


# ===============================
# PHYSICS
# ===============================
func _physics_process(delta):

	if not is_inside_tree():
		return

	if not is_instance_valid(SaveManager) or not is_instance_valid(SaveManager.player):
		return

	var is_locked := false

	if is_instance_valid(UIManager):
		is_locked = UIManager.input_mode in [
			"menu",
			"inventory",
			"inventory_action",
			"hotbar",
			"hotbar_move"
		]

	# INPUT
	if dpad == null:
		dpad = get_tree().get_first_node_in_group("dpad")

	var dir: Vector2 = Vector2.ZERO

	if not is_locked and dpad:
		dir = dpad.direction

	# 🔥 giảm timer block animation
	if block_anim_timer > 0:
		block_anim_timer -= delta

	# ===============================
	# 🔥 SHOW ITEM (PRIORITY CAO NHẤT)
	# ===============================
	if is_showing_item:

		show_timer -= delta

		# ❗ nếu di chuyển → hủy ngay
		if show_timer <= 0:
			is_showing_item = false

		elif show_timer <= 0:
			is_showing_item = false

		# ❗ CHẶN TOÀN BỘ animation khác
		if is_showing_item:
			move_and_slide()
			return

		# vừa kết thúc
		if item_show:
			item_show.visible = false

	# ===============================
	# MOVE
	# ===============================
	if is_locked:
		velocity = Vector2.ZERO
		move_and_slide()   # 🔥 vẫn gọi để stop ngay
		return             # 🔥 CHẶN hết phía dưới (quan trọng)

	velocity = dir * speed

	move_and_slide()

	# ===============================
	# ANIMATION
	# ===============================
	if is_locked:
		update_animation(Vector2.ZERO)
	else:
		update_animation(dir)

	# ===============================
	# SYNC
	# ===============================
	sync_timer -= delta
	if sync_timer <= 0:
		sync_timer = 0.1
		Net.send_state(global_position, anim.animation)

# ===============================
# ANIMATION
# ===============================
func update_animation(dir: Vector2):

	# 🔥 CHẶN override khi đang show hoặc vừa show xong
	if is_showing_item or block_anim_timer > 0:
		return

	var target_anim := ""

	if dir == Vector2.ZERO:
		target_anim = "idle_" + last_dir
	else:
		if abs(dir.x) > abs(dir.y):
			last_dir = "right" if dir.x > 0 else "left"
		else:
			last_dir = "down" if dir.y > 0 else "up"

		target_anim = "run_" + last_dir

	if anim.animation != target_anim:
		anim.play(target_anim)

	update_raycast()

# ===============================
# RAYCAST
# ===============================
func update_raycast():

	match last_dir:
		"down":
			ray.target_position = Vector2(0, 32)
		"up":
			ray.target_position = Vector2(0, -32)
		"left":
			ray.target_position = Vector2(-32, 0)
		"right":
			ray.target_position = Vector2(32, 0)


# ===============================
# SNAP CAMERA
# ===============================
func snap_camera():

	if cam == null:
		return

	cam.position = Vector2.ZERO


# ===============================
# HOTBAR VISUAL ONLY (NO LOGIC)
# ===============================
func show_hotbar_item(item):

	if item_show == null:
		return

	if item == null:
		item_show.visible = false
		return

	# 🔥 LUÔN bật khi có item
	item_show.visible = true
	item_show.modulate.a = 1.0

	if item_show.has_method("set_item"):
		item_show.set_item(item)
	elif item_show is TextureRect:
		item_show.texture = item.icon

# ===============================
# SHOW ITEM ANIM (VISUAL ONLY)
# ===============================
func play_show_item_anim():

	if not anim.sprite_frames or not anim.sprite_frames.has_animation("showitem"):
		print("❌ NO SHOWITEM ANIM")
		return

	is_showing_item = true
	show_timer = 1.5
	block_anim_timer = 0.5   # 🔥 QUAN TRỌNG

	# 🔥 play chuẩn
	anim.play("showitem")
	anim.frame = 0

	if item_show:
		item_show.visible = true

	print("🎬 PLAY SHOWITEM FORCED")

func cancel_show_item():

	if not is_showing_item:
		return

	print("🛑 CANCEL SHOW ITEM")

	is_showing_item = false
	show_timer = 0

	if item_show:
		item_show.visible = false

func play_raihat_anim():

	if is_showing_item:
		return

	if not anim.sprite_frames or not anim.sprite_frames.has_animation("raihat"):
		print("❌ Không có anim raihat")
		return

	is_showing_item = true

	# 🔥 FIX CHÍNH
	block_anim_timer = 0.4   # 👉 giữ anim không bị override

	anim.play("raihat")
	anim.frame = 0	
	
func _on_raihat_finished():

	if anim.animation != "raihat":
		return

	is_showing_item = false

	# quay về idle
	anim.play("idle_" + last_dir)
