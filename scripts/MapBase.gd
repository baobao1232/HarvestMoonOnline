class_name MapBase
extends Node2D

@export var is_indoor := false

@onready var map: Sprite2D = $Map
@onready var ysort: Node2D = $YSort

var last_saved_pos := Vector2.ZERO
var save_delay := 0.0


# ===============================
# READY
# ===============================
func _ready():

	if ysort:
		ysort.y_sort_enabled = true

	_attach_player()

	_setup_ui()

	_apply_daynight()

	_setup_camera()


# ===============================
# PLAYER ATTACH (SAFE)
# ===============================
func _attach_player():

	var player = get_tree().get_first_node_in_group("local_player")

	if player == null or not is_instance_valid(player):
		print("❌ NO LOCAL PLAYER (ATTACH)")
		return

	if player.get_parent() != ysort:
		if player.get_parent():
			player.get_parent().remove_child(player)

		ysort.add_child(player)


# ===============================
# UI
# ===============================
func _setup_ui():

	var root = get_tree().root

	if root.get_node_or_null("DayNight") == null:
		var dn = preload("res://scn/UI/DayNight.tscn").instantiate()
		dn.name = "DayNight"
		root.call_deferred("add_child", dn)


# ===============================
# CAMERA
# ===============================
func _setup_camera():

	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		print("❌ NO LOCAL PLAYER (CAMERA)")
		return

	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return

	cam.make_current()

	if map == null or map.texture == null:
		return

	var size = map.texture.get_size() * map.scale

	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = size.x
	cam.limit_bottom = size.y

# ===============================
# AUTO SAVE (ANTI SPAM)
# ===============================
func _process(delta):

	var player = get_tree().get_first_node_in_group("local_player")
	#print("1")

	if player == null:
		print("❌ NO LOCAL PLAYER (SAVE)")
		return
	#print("2")

	if SaveManager.player == null:
		return
	#print("3")
	

	save_delay -= delta
	#print("DELAY:", save_delay)

	if save_delay > 0:
		return
	#print("4")
	#print("CUR:", player.global_position, "| LAST:", last_saved_pos)
	var current_pos = player.global_position.round()

	if current_pos == last_saved_pos:
		return
	#print("5")

	last_saved_pos = current_pos
	save_delay = 1.0

	print("💾 SAVE POS:", current_pos)

	Server.request_save_position(
		current_pos,
		get_tree().current_scene.scene_file_path
	)


# ===============================
# MOBILE SAVE
# ===============================
func _notification(what):

	if what == NOTIFICATION_APPLICATION_PAUSED \
	or what == NOTIFICATION_WM_GO_BACK_REQUEST:

		var player = SceneManager.player
		if player == null:
			return

		if SaveManager.player == null:
			return

		Server.request_save_position(
			player.global_position.round(),
			get_tree().current_scene.scene_file_path,
			true
		)


# ===============================
# DAY NIGHT (FIX ROOT)
# ===============================
func _apply_daynight():

	var root = get_tree().root
	var daynight = root.get_node_or_null("DayNight")

	if daynight == null:
		return

	if daynight.has_method("set_indoor"):
		daynight.set_indoor(is_indoor)
	else:
		daynight.visible = !is_indoor
