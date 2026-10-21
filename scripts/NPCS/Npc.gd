extends CharacterBody2D

@export var npc_id : String
@export var speed := 40


# ===== schedule =====
var schedule : Array = []
var target_pos : Vector2
var target_map : String
var moving := false


# ===== dialog data =====
var dialog_data = {}
var portraits = {}


var last_dir := "down"

@onready var sprite = $AnimatedSprite2D

# ===== breathing =====
var breath_mat : ShaderMaterial



func _ready():

	print("NPC parent:", get_parent())

	load_npc_data()

	print("Current map:", get_tree().current_scene.name)

	check_schedule(TimeManager.hour, TimeManager.minute)

	TimeManager.time_changed.connect(check_schedule)

	setup_breathing()



# ===============================
# BREATHING SETUP
# ===============================

func setup_breathing():

	breath_mat = ShaderMaterial.new()
	breath_mat.shader = load("res://shader/breathing.gdshader")
	sprite.material = breath_mat


func set_breathing(active: bool):

	if breath_mat == null:
		return

	breath_mat.set_shader_parameter("intensity", 0.015 if active else 0.0)



# ===============================
# LOAD NPC DATA
# ===============================

func load_npc_data():

	var path = "res://scripts/NPCS/%s/%s.gd" % [npc_id, npc_id]

	if not ResourceLoader.exists(path):
		print("NPC data missing:", path)
		return

	var script = load(path)
	var data = script.new()

	if "schedule" in data:
		schedule = data.schedule

	if "dialog" in data:
		dialog_data = data.dialog

	if "portraits" in data:
		portraits = data.portraits

	print("Loaded schedule:", schedule)



# ===============================
# SCHEDULE CHECK
# ===============================

func check_schedule(hour, minute):

	if schedule.is_empty():
		return

	var game_minutes = hour * 60 + minute
	moving = false

	for s in schedule:

		var target_minutes = s.hour * 60

		if game_minutes >= target_minutes:

			target_map = s.map
			target_pos = s.pos
			moving = true



# ===============================
# MOVEMENT
# ===============================

func _physics_process(delta):

	# ===== dialog đang mở =====
	if DialogManager.dialog and DialogManager.dialog.visible:
		velocity = Vector2.ZERO
		set_breathing(false)
		play_idle()
		return


	# ===== không di chuyển =====
	if not moving:
		set_breathing(true)
		play_idle()
		return


	var dir = target_pos - global_position

	# ===== tới nơi =====
	if dir.length() < 5:
		moving = false
		velocity = Vector2.ZERO
		set_breathing(true)
		play_idle()
		return


	# ===== đang di chuyển =====
	velocity = dir.normalized() * speed

	set_breathing(false)
	update_animation(dir)

	move_and_slide()



# ===============================
# ANIMATION
# ===============================

func update_animation(dir: Vector2):

	if abs(dir.x) > abs(dir.y):

		if dir.x > 0:
			sprite.play("right")
			last_dir = "right"
		else:
			sprite.play("left")
			last_dir = "left"

	else:

		if dir.y > 0:
			sprite.play("down")
			last_dir = "down"
		else:
			sprite.play("up")
			last_dir = "up"



func play_idle():

	var anim = "idle_" + last_dir

	if sprite.animation != anim:
		sprite.play(anim)



# ===============================
# FACE PLAYER
# ===============================

func face_player():

	var player = SceneManager.player
	if player == null:
		return

	var dir = player.global_position - global_position

	if abs(dir.x) > abs(dir.y):

		if dir.x > 0:
			last_dir = "right"
		else:
			last_dir = "left"

	else:

		if dir.y > 0:
			last_dir = "down"
		else:
			last_dir = "up"

	play_idle()



# ===============================
# INTERACT
# ===============================

func interact():

	print("Talk to NPC:", npc_id)

	face_player()

	if dialog_data.is_empty():
		return

	var lines = choose_dialog()

	if lines.is_empty():
		return

	show_dialog_sequence(lines)



# ===============================
# CHOOSE DIALOG
# ===============================

func choose_dialog():

	var hour = TimeManager.hour
	var season_name = TimeManager.SEASONS[TimeManager.season].to_lower()

	# ===== weather =====
	if Engine.has_singleton("WeatherManager"):
		if WeatherManager.is_raining():
			if "rain" in dialog_data:
				return dialog_data["rain"]

	# ===== evening =====
	if hour >= 18 and "evening" in dialog_data:
		return dialog_data["evening"]

	# ===== season =====
	if season_name in dialog_data:
		return dialog_data[season_name]

	# ===== intro =====
	if hour < 10 and "intro" in dialog_data:
		return dialog_data["intro"]

	# ===== normal =====
	if "normal" in dialog_data:
		return dialog_data["normal"]

	return []



# ===============================
# SHOW DIALOG
# ===============================

func show_dialog_sequence(lines):

	var text_lines = []
	var portrait_lines = []

	for l in lines:

		if "text" in l:
			text_lines.append(l["text"])
		else:
			continue

		var face = ""

		if "face" in l:
			face = l["face"]

		if face in portraits:
			portrait_lines.append(portraits[face])
		else:
			portrait_lines.append(null)

	DialogManager.show(text_lines, portrait_lines)
