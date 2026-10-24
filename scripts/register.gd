extends Control

@onready var username_input = $name
@onready var password_input = $pass


# =========================
# READY
# =========================
func _ready():

	if not Server.register_result.is_connected(_on_register_result):
		Server.register_result.connect(_on_register_result)


# =========================
# BUTTON
# =========================
func _on_confirm_pressed():

	var user = username_input.text.strip_edges()
	var pwd = password_input.text.strip_edges()

	if user == "" or pwd == "":
		Dbg.p("❌ Empty username or password")
		return

	# 🔥 gọi server
	Server.request_register(user, pwd)


# =========================
# SERVER RESPONSE
# =========================
func _on_register_result(success, msg):

	Dbg.p(msg)

	if not success:
		return

	Dbg.p("✅ REGISTER OK")

	# =========================
	# 🔥 CLEAR INPUT
	# =========================
	username_input.text = ""
	password_input.text = ""

	# =========================
	# 🔥 RESET UI (QUAN TRỌNG)
	# =========================
	if UIManager:
		UIManager.close_all()

	# =========================
	# 🔥 LOAD LOGIN SCENE
	# =========================
	get_tree().change_scene_to_file("res://scn/Login.tscn")
