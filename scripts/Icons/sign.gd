extends Area2D

@export var dialog_lines : Array[String]
@export var portrait : Texture2D


func interact():

	if dialog_lines.is_empty():
		return

	DialogManager.show(dialog_lines, portrait)
