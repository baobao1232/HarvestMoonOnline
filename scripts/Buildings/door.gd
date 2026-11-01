extends StaticBody2D
class_name Door

@export var start_open := false

@export var sprite_closed: Sprite2D
@export var sprite_open: Sprite2D
@export var shape: CollisionShape2D
@export var click_area: Area2D

@export var interact_range := 40.0

var is_open := false
var door_id := ""
var map_path := ""
const NPC_CLOSE_DELAY := 1.5

var _npc_opened := false
var _close_timer := 0.0

func _enter_tree():
	add_to_group("door")


func _ready():
	click_area.input_pickable = true
	click_area.input_event.connect(_on_click_area_input)

	map_path = _find_map_path()
	door_id = "%s@%d,%d" % [name, int(global_position.x), int(global_position.y)]
	Dbg.p("DOOR READY:", door_id, "| map:", map_path)

	set_open(start_open)

	Net.door_changed.connect(_on_net_door)
	Net.query_door(map_path, door_id)   # hỏi server trạng thái hiện tại


func _exit_tree():
	if Net.door_changed.is_connected(_on_net_door):
		Net.door_changed.disconnect(_on_net_door)


# scene gốc của map chứa cửa (current_scene lúc này có thể còn là map cũ)
func _find_map_path() -> String:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n.scene_file_path


# chỉ đổi trạng thái tại máy mình, KHÔNG gửi mạng
func set_open(value: bool):
	is_open = value
	_npc_opened = false
	sprite_closed.visible = not value
	sprite_open.visible = value
	shape.set_deferred("disabled", value)

func can_interact(player) -> bool:
	var center: Vector2 = shape.global_position
	return player.global_position.distance_to(center) <= interact_range


# nút A: mở / đóng
func interact():
	toggle()


func toggle():
	# đang có người đứng trong khung cửa thì không đóng (tránh kẹt)
	if is_open and _someone_in_doorway():
		return
	set_open(not is_open)
	Net.send_door(map_path, door_id, is_open)   # báo server -> người khác


# nhận từ server: chỉ đổi, không gửi lại (tránh vòng lặp)
func _on_net_door(map: String, id: String, open: bool):
	if map == map_path and id == door_id:
		set_open(open)


# click chuột / chạm
func _on_click_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var p = SceneManager.player
		if p != null and is_instance_valid(p) and can_interact(p):
			toggle()


func _someone_in_doorway() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape.shape
	q.transform = shape.global_transform
	q.collision_mask = 1
	q.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
		if hit.collider is CharacterBody2D:
			return true
	return false

# điểm pos có nằm trong/sát khung cửa không
func is_near(pos: Vector2, margin := 12.0) -> bool:
	var c := shape.global_position
	if shape.shape is RectangleShape2D:
		var s: Vector2 = shape.shape.size * shape.global_scale.abs()
		return Rect2(c - s * 0.5, s).grow(margin).has_point(pos)
	return c.distance_to(pos) <= margin + 16.0


# NPC gọi mỗi frame khi đang đi qua cửa
func npc_open():
	_close_timer = NPC_CLOSE_DELAY
	if is_open:
		return
	set_open(true)
	_npc_opened = true     # đặt SAU set_open (set_open reset cờ này)
	# chỉ mở tại máy mình, không gửi mạng: mỗi client tự chạy NPC của nó


func _process(delta):
	if not _npc_opened:
		return
	_close_timer -= delta
	if _close_timer > 0.0:
		return
	if _someone_in_doorway():
		_close_timer = 0.5     # còn người đứng đó, thử lại
		return
	set_open(false)            # cửa do NPC mở thì NPC đi khỏi sẽ tự đóng
