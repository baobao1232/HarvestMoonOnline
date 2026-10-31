class_name MapBase
extends Node2D

const SHADOW_SCRIPT := preload("res://scripts/ShadowCaster.gd")   # <-- THÊM

@export var is_indoor := false
@export var allow_npcs := false   # indoor nhưng vẫn có NPC (Supermarket...)

var _lamps: Array = []

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

	_setup_indoor_lighting()

	_attach_player()
	_apply_daynight()
	_setup_camera()
	_spawn_npcs()


# ===============================
# NPC (map nào cũng tự spawn, trừ map trong nhà)
# ===============================
func _spawn_npcs():
	if (is_indoor and not allow_npcs) or ysort == null:
		return
	NpcManager.spawn_npcs(name, ysort)

# ===============================
# PLAYER ATTACH (SAFE)
# ===============================
func _attach_player():

	var player = get_tree().get_first_node_in_group("local_player")

	if player == null or not is_instance_valid(player):
		Dbg.p("❌ NO LOCAL PLAYER (ATTACH)")
		return

	if player.get_parent() != ysort:
		if player.get_parent():
			player.get_parent().remove_child(player)

		ysort.add_child(player)


# ===============================
# CAMERA
# ===============================
func _setup_camera():

	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		Dbg.p("❌ NO LOCAL PLAYER (CAMERA)")
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

	if player == null:
		Dbg.p("❌ NO LOCAL PLAYER (SAVE)")
		return

	if SaveManager.player == null:
		return

	save_delay -= delta

	if save_delay > 0:
		return

	var current_pos = player.global_position.round()

	if current_pos == last_saved_pos:
		return

	last_saved_pos = current_pos
	save_delay = 1.0

	Dbg.p("💾 SAVE POS:", current_pos)

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


# ===============================
# INDOOR: đèn treo trên đầu + bóng ngay dưới chân
# ===============================
func _setup_indoor_lighting():

	# map ngoài trời cũng đi qua đây nên cờ luôn được reset đúng
	ShadowManager.indoor = is_indoor

	if not is_indoor:
		return

	var lamps := find_children("*", "PointLight2D", true, false)
	if lamps.is_empty():
		lamps.append(_make_lamp())

	for l in lamps:
		l.shadow_enabled = false

	_lamps = lamps
	TimeManager.time_changed.connect(_on_indoor_time)
	_on_indoor_time(TimeManager.hour, TimeManager.minute)

	_add_prop_shadows()

func _make_lamp() -> PointLight2D:

	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0, 0, 0, 1)])

	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var l := PointLight2D.new()
	l.name = "Lamp"
	l.texture = tex
	l.texture_scale = 3.0
	l.energy = 0.1
	l.color = Color(1.0, 0.93, 0.8)
	l.shadow_enabled = false

	var center := Vector2.ZERO
	if map != null and map.texture != null:
		center = map.position + (Vector2.ZERO if map.centered else map.texture.get_size() * 0.5)
	l.position = center

	add_child(l)
	return l


# gắn bóng cho mọi Sprite2D trong YSort (trừ tường z>=10, node có script, group "no_shadow")
func _add_prop_shadows():

	if ysort == null:
		return

	for s in ysort.find_children("*", "Sprite2D", true, false):

		if s.get_script() != null:
			continue
		if s.texture == null or s.z_index >= 10 or s.is_in_group("no_shadow"):
			continue
		if s.get_parent().get_node_or_null("AutoShadow_" + str(s.name)) != null:
			continue

		var sh := Sprite2D.new()
		sh.name = "AutoShadow_" + str(s.name)
		sh.set_script(SHADOW_SCRIPT)
		sh.set("shadow_type", 3)                          # PROP
		sh.set("target_path", NodePath("../" + str(s.name)))
		s.get_parent().add_child(sh)
func _on_indoor_time(hour, _minute):
	# khớp với day_night.gd: 17h bật đèn dần, 22h tắt
	var on: bool = hour >= 17 and hour < 22
	for l in _lamps:
		if is_instance_valid(l):
			l.enabled = on
