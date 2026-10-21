extends Node

@onready var container = $SceneContainer


func _ready():
	open_login()


func change_scene(path):

	for c in container.get_children():
		c.queue_free()

	var scene = load(path).instantiate()
	container.add_child(scene)


func open_login():
	change_scene("res://scn/Login.tscn")


func open_register():
	change_scene("res://scn/Register.tscn")


func open_select_char():
	change_scene("res://scn/select_char.tscn")


func open_create_char():
	change_scene("res://scn/create_char.tscn")
