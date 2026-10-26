@tool
extends EditorPlugin

var insp

func _enter_tree():
	insp = preload("res://addons/grip_editor/grip_inspector.gd").new()
	add_inspector_plugin(insp)

func _exit_tree():
	remove_inspector_plugin(insp)
