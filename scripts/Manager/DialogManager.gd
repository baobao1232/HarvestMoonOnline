extends Node

var dialog = null

var lines : Array = []
var portraits : Array = []

var index := 0
var page_size := 3

var typing := false
var full_text := ""
var char_index := 0
var speed := 0.02
var is_showing := false


func show(new_lines, new_portraits = []):

	is_showing = true   # 👈 thêm

	lines = new_lines

	if new_portraits is Array:
		portraits = new_portraits
	else:
		portraits = [new_portraits]

	index = 0

	show_page()


func show_page():

	var text := ""

	for i in range(page_size):

		var line_index = index + i

		if line_index >= lines.size():
			break

		text += lines[line_index] + "\n"

	type_text(text)



func type_text(t):

	full_text = t
	char_index = 0

	var portrait = null

	# lấy portrait đúng theo dòng dialog
	if portraits.size() > index:
		portrait = portraits[index]

	dialog.show_dialog("", portrait)

	typing = true



func next():

	if typing:
		dialog.text.text = full_text
		typing = false
		return

	index += page_size

	if index >= lines.size():
		dialog.hide_dialog()
		is_showing = false   # 👈 thêm
	else:
		show_page()


func _process(delta):

	if typing:

		char_index += 1

		dialog.text.text = full_text.substr(0, char_index)

		if char_index >= full_text.length():
			typing = false
