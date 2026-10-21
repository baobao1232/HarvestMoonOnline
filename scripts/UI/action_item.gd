extends Control

@onready var bg = $BG
@onready var label = $Label

func set_text(t):
	label.text = t

func set_selected(v):
	bg.visible = v
