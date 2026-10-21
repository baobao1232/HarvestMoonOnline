extends Node2D

@onready var anim = $AnimatedSprite2D


func _ready():
	anim.play("idle")


func show_icon():
	visible = true
	anim.play("idle")


func hide_icon():
	visible = false
	anim.stop()
