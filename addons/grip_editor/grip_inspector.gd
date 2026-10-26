@tool
extends EditorInspectorPlugin

const GripEditor = preload("res://addons/grip_editor/grip_editor.gd")

func _can_handle(object) -> bool:
	return object is ItemData

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide) -> bool:
	if name == "grip":
		add_property_editor(name, GripEditor.new(), false)
		return true      # thay editor mặc định
	return false
