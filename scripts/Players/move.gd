extends CharacterBody2D

signal use_finished(item)

@export var speed = 200

var dpad = null
var last_dir := "down"
var show_timer := 0.0
var is_showing_item := false
var block_anim_timer := 0.0
var current_item_id := ""

@onready var cam: Camera2D = $Camera2D
@onready var anim = $AnimatedSprite2D
@onready var ray = $RayCast2D
@onready var item_show = $ItemShow
@onready var tool_overlay = get_node_or_null("ToolOverlay")   # NEW

@export var dat_scene: PackedScene

# realtime sync
var sync_timer := 0.0
var prev_anim := ""

# ===============================
# READY
# ===============================
func _ready():

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	add_to_group("player")
	Dbg.p("ANIMS:", anim.sprite_frames.get_animation_names())

	add_to_group("local_player")

	if is_instance_valid(SaveManager) and is_instance_valid(SaveManager.player):
		UIManager.update_player_name(SaveManager.player.name)

	# CAMERA
	cam.make_current()
	cam.position = Vector2.ZERO
	cam.limit_enabled = true
	cam.position_smoothing_enabled = false

	_setup_camera_limit()

	# NEW: 1 handler duy nhất cho mọi anim không loop (raihat, use_*)
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)


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

	_sync_net(delta)

	var is_locked := DialogManager.is_showing

	if is_instance_valid(UIManager):
		is_locked = is_locked or UIManager.input_mode in [
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

	if block_anim_timer > 0:
		block_anim_timer -= delta

	# ===============================
	# SHOW ITEM / USE TOOL (PRIORITY CAO NHẤT)
	# ===============================
	if is_showing_item:

		show_timer -= delta

		if show_timer <= 0:
			_end_use()   # FIX: timer chốt an toàn cũng dọn tool overlay

		if is_showing_item:
			velocity = Vector2.ZERO   # FIX: không trượt tiếp
			move_and_slide()
			return

		if item_show:
			item_show.visible = false

	# ===============================
	# MOVE
	# ===============================
	if is_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		update_animation(Vector2.ZERO)
		return

	velocity = dir * speed

	move_and_slide()

	update_animation(dir)


# ===============================
# ANIMATION
# ===============================
func update_animation(dir: Vector2):

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
			ray.target_position = Vector2(0, 16)
		"up":
			ray.target_position = Vector2(0, -16)
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
		current_item_id = ""
		item_show.visible = false
		return

	current_item_id = item.id

	item_show.visible = true
	item_show.modulate.a = 1.0

	if item_show.has_method("set_item"):
		item_show.set_item(item)
	elif item_show is TextureRect:
		item_show.texture = item.icon


func get_shown_item_id() -> String:
	# NEW: đang vung tool thì vẫn báo item cho remote
	if String(anim.animation).begins_with("use_"):
		return current_item_id
	if item_show and item_show.visible:
		return current_item_id
	return ""


func _sync_net(delta):
	sync_timer -= delta
	if sync_timer <= 0:
		sync_timer = 0.05
		Net.send_state(global_position, anim.animation, get_shown_item_id())


# ===============================
# SHOW ITEM ANIM (VISUAL ONLY)
# ===============================
func play_show_item_anim():

	if not anim.sprite_frames or not anim.sprite_frames.has_animation("showitem"):
		Dbg.p("❌ NO SHOWITEM ANIM")
		return

	is_showing_item = true
	show_timer = 1.5
	block_anim_timer = 0.5

	anim.play("showitem")
	anim.frame = 0

	if item_show:
		item_show.visible = true

	Dbg.p("🎬 PLAY SHOWITEM FORCED")


func cancel_show_item():

	if not is_showing_item:
		return

	Dbg.p("🛑 CANCEL SHOW ITEM")

	_end_use()   # FIX: dùng chung hàm dọn

	if item_show:
		item_show.visible = false


func play_raihat_anim():

	if is_showing_item:
		return

	if not anim.sprite_frames or not anim.sprite_frames.has_animation("raihat"):
		Dbg.p("❌ Không có anim raihat")
		return

	is_showing_item = true
	show_timer = 5.0   # NEW: chốt an toàn, kết thúc thật ở animation_finished
	block_anim_timer = 0.4

	anim.play("raihat")
	anim.frame = 0


# ===============================
# NEW: USE TOOL
# ===============================
func play_use_anim(item):

	if is_showing_item or item == null:
		return

	var an: String
	if item.use_anim != "":
		an = "use_%s_%s" % [item.use_anim, last_dir]   # use_water_down
	else:
		an = "use_" + last_dir                          # use_down

	if not anim.sprite_frames.has_animation(an):
		Dbg.p("❌ NO ANIM:", an)
		return

	is_showing_item = true
	show_timer = 5.0
	block_anim_timer = 0.3
	current_item_id = item.id
	velocity = Vector2.ZERO

	if item_show:
		item_show.visible = false

	Dbg.p("▶ PLAY:", an)
	anim.play(an)
	anim.frame = 0

	if tool_overlay:
		tool_overlay.set_tool(item)
		
func _end_use():
	is_showing_item = false
	show_timer = 0
	if tool_overlay:
		tool_overlay.set_tool(null)

func _on_anim_finished():
	var an := String(anim.animation)

	if an == "raihat" or an.begins_with("use_"):
		var item_id := current_item_id
		_end_use()
		anim.play("idle_" + last_dir)
		use_finished.emit(item_id)

# ===============================
# INTERACT (nút A)
# ===============================
func _process(_delta):

	if not Input.is_action_just_pressed("interact"):
		return

	if UIManager.input_mode != "player":
		return

	if DialogManager.is_showing:
		DialogManager.next()
		return

	if is_showing_item:
		return

	var target = get_interact_target()
	if target != null:
		target.interact()


func get_interact_target():

	if ray == null:
		return null

	ray.force_raycast_update()

	if not ray.is_colliding():
		return null

	var node = ray.get_collider()

	for i in 2:
		if node == null:
			break
		if node.has_method("interact"):
			return node
		node = node.get_parent()

	return null
