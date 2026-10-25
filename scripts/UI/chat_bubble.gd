extends Node2D
# Bong bóng chat trên đầu nhân vật. Add làm con của node player rồi gọi setup(text).

@export var max_width := 320.0          # px (chưa nhân scale của Panel)
@export var head_offset := 42.0         # cách gốc nhân vật bao nhiêu px (lên trên)
@export var lifetime_min := 4.0
@export var lifetime_per_char := 0.06
@export var lifetime_max := 10.0
@export var fade_time := 0.5

@onready var panel: PanelContainer = %Panel
@onready var label: Label = %Label

var life := 0.0
var shown := false


func _ready():
	add_to_group("chat_bubble")
	z_index = 50
	modulate.a = 0.0                    # ẩn tới khi tính xong kích thước


func setup(text: String):

	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")

	# luôn tắt autowrap của Label (hay tính sai chiều cao), tự ngắt dòng bằng tay
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2.ZERO
	label.text = _wrap(text, font, fs, max_width)

	life = clamp(lifetime_min + text.length() * lifetime_per_char, lifetime_min, lifetime_max)
	_fit.call_deferred()


# đợi 1 frame cho layout tính xong, rồi ép panel co đúng kích thước nội dung
func _fit():
	await get_tree().process_frame
	if not is_inside_tree():
		return
	label.reset_size()
	panel.reset_size()
	panel.size = panel.get_combined_minimum_size()
	_reposition()


func _text_w(s: String, font: Font, fs: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _wrap(text: String, font: Font, fs: int, max_w: float) -> String:

	var out: Array = []
	var cur := ""

	for word in text.split(" ", false):

		# từ quá dài → cắt theo ký tự
		while _text_w(word, font, fs) > max_w:
			var cut := 1
			while cut < word.length() and _text_w(word.substr(0, cut + 1), font, fs) <= max_w:
				cut += 1
			if cur != "":
				out.append(cur)
				cur = ""
			out.append(word.substr(0, cut))
			word = word.substr(cut)

		var test := word if cur == "" else cur + " " + word

		if cur == "" or _text_w(test, font, fs) <= max_w:
			cur = test
		else:
			out.append(cur)
			cur = word

	if cur != "":
		out.append(cur)

	return "\n".join(out)


# đáy bong bóng nằm trên đầu, căn giữa theo nhân vật
func _reposition():
	var s := panel.size * panel.scale
	panel.position = Vector2(-s.x * 0.5, -s.y - head_offset)
	if not shown:
		shown = true
		modulate.a = 1.0


func _process(delta):
	if not shown:
		return

	life -= delta

	if life <= 0.0:
		queue_free()
	elif life < fade_time:
		modulate.a = life / fade_time
