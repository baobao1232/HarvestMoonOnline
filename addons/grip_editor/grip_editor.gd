@tool
extends EditorProperty

const ZOOM := 12
var canvas := Control.new()
var dragging := false


func _init():
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
	canvas.custom_minimum_size = Vector2(16, 16) * ZOOM
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_on_input)
	add_child(canvas)
	set_bottom_editor(canvas)


func _update_property():
	var obj = get_edited_object()
	var tex: Texture2D = obj.icon
	canvas.custom_minimum_size = (tex.get_size() if tex else Vector2(16, 16)) * ZOOM
	canvas.queue_redraw()


func _draw_canvas():
	var obj = get_edited_object()
	var tex: Texture2D = obj.icon
	var sz: Vector2 = (tex.get_size() if tex else Vector2(16, 16)) * ZOOM

	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.25, 0.25, 0.25))
	if tex:
		canvas.draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false)

	# lưới pixel
	var cells := sz / ZOOM
	for x in range(1, int(cells.x)):
		canvas.draw_line(Vector2(x * ZOOM, 0), Vector2(x * ZOOM, sz.y), Color(1, 1, 1, 0.08))
	for y in range(1, int(cells.y)):
		canvas.draw_line(Vector2(0, y * ZOOM), Vector2(sz.x, y * ZOOM), Color(1, 1, 1, 0.08))

	# chấm xanh = grip
	var g: Vector2 = obj.grip
	var c := (g + Vector2(0.5, 0.5)) * ZOOM
	canvas.draw_circle(c, 6, Color.BLACK)
	canvas.draw_circle(c, 4, Color(0.2, 1.0, 0.3))

	# vạch đỏ = hướng icon_angle (từ grip đi ra)
	var dir := Vector2.from_angle(deg_to_rad(obj.icon_angle))
	canvas.draw_line(c, c + dir * 60, Color(1, 0.3, 0.3), 2)


func _on_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			_set_from(event.position)
	elif event is InputEventMouseMotion and dragging:
		_set_from(event.position)


func _set_from(pos: Vector2):
	var obj = get_edited_object()
	var tex: Texture2D = obj.icon
	var cells := tex.get_size() if tex else Vector2(16, 16)
	var p := (pos / ZOOM).floor().clamp(Vector2.ZERO, cells - Vector2.ONE)
	emit_changed(get_edited_property(), p)
