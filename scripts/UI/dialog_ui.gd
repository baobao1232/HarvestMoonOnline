extends CanvasLayer

@onready var text = $DialogBox/Text
@onready var avatar = $DialogBox/Avatar

var full_text := ""
var char_index := 0
var typing_speed := 0.02


func _ready():
	DialogManager.dialog = self
	visible = false


func show_dialog(t, portrait = null):

	visible = true

	if portrait:
		avatar.texture = portrait

	full_text = t
	char_index = 0
	text.text = ""

	type_text()

func type_text():

	DialogManager.typing = true

	while char_index < full_text.length():

		if not visible:   # 🔥 bị force_close giữa chừng
			return

		text.text += full_text[char_index]
		char_index += 1

		await get_tree().create_timer(typing_speed).timeout

	DialogManager.typing = false


func finish_text():

	text.text = full_text
	char_index = full_text.length()
	DialogManager.typing = false


func hide_dialog():
	visible = false
