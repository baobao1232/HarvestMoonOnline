extends CharacterBody2D
# res://scripts/Players/remote_player.gd
# Snapshot interpolation: hiển thị người khác chậm DELAY giây để luôn có 2 điểm nội suy.

const DELAY := 0.1            # tăng lên 0.15 nếu mạng ngoài internet hay rớt gói
const TELEPORT_DIST := 200.0
const MAX_EXTRAPOLATE := 0.08

var buf: Array = []           # mỗi phần tử: {t, pos, anim}   (t theo giờ của máy mình, giây)
var offset_ms := INF          # chênh lệch đồng hồ giữa người gửi và máy mình
var item_show: TextureRect
var shown_item := "@none"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel


func _ready():
	collision_layer = 0
	collision_mask = 0

	var shape = get_node_or_null("CollisionShape2D")
	if shape:
		shape.set_deferred("disabled", true)

	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.enabled = false
		cam.queue_free()

	var pos_label = get_node_or_null("PosLabel")
	if pos_label:
		pos_label.visible = false

	item_show = get_node_or_null("ItemShow")
	if item_show:
		item_show.visible = false


func setup(pname: String, pos: Vector2, anim_name: String):
	global_position = pos
	name_label.text = pname
	buf.clear()
	offset_ms = INF
	_play(anim_name)


func push_state(pos: Vector2, anim_name: String, ts: float, item: String = ""):
	var now_ms := float(Time.get_ticks_msec())

	# ước lượng chênh lệch đồng hồ: lấy giá trị nhỏ nhất (gói nhanh nhất = ít trễ nhất)
	var o := now_ms - ts
	if o < offset_ms:
		offset_ms = o
	else:
		offset_ms += 0.02     # nhích nhẹ để theo kịp lệch đồng hồ theo thời gian

	var t := (ts + offset_ms) / 1000.0

	# teleport / đổi map → bỏ buffer cũ
	if not buf.is_empty() and buf[-1].pos.distance_to(pos) > TELEPORT_DIST:
		buf.clear()
		global_position = pos

	# bỏ gói đến muộn/trùng thứ tự
	if not buf.is_empty() and t <= buf[-1].t:
		return

	buf.append({"t": t, "pos": pos, "anim": anim_name, "item": item})

	if buf.size() > 40:
		buf = buf.slice(buf.size() - 40)


func _play(anim_name: String):
	if anim_name == "" or not anim.sprite_frames.has_animation(anim_name):
		return
	if anim.animation != anim_name:
		anim.play(anim_name)


func _process(_delta):
	if Engine.get_frames_drawn() % 60 == 0:
		print("FPS=", Engine.get_frames_per_second(), " buf=", buf.size())
		
	if buf.is_empty():
		return
	
	var rt := Time.get_ticks_msec() / 1000.0 - DELAY   # thời điểm cần hiển thị

	# bỏ các điểm đã quá cũ (giữ lại 1 điểm trước rt)
	while buf.size() > 2 and buf[1].t <= rt:
		buf.pop_front()

	var a = buf[0]

	if buf.size() == 1 or rt <= a.t:
		global_position = a.pos
		_apply(a)
		return

	var b = buf[1]

	if rt < b.t:
		# bình thường: nội suy giữa a và b
		var k: float = (rt - a.t) / (b.t - a.t)
		global_position = a.pos.lerp(b.pos, k)
		_apply(a)
	else:
		# hết dữ liệu (rớt gói): ngoại suy nhẹ theo vận tốc cuối rồi đứng
		var dt: float = b.t - a.t
		var vel: Vector2 = (b.pos - a.pos) / dt if dt > 0.0001 else Vector2.ZERO
		var extra: float = min(rt - b.t, MAX_EXTRAPOLATE)
		global_position = b.pos + vel * extra
		_apply(b)

func _set_item(item_id: String):
	if item_show == null or item_id == shown_item:
		return
	shown_item = item_id

	if item_id == "":
		item_show.visible = false
		return

	var data = ItemDb.items.get(item_id, null)
	if data == null or data.icon == null:
		item_show.visible = false
		return

	item_show.texture = data.icon
	item_show.visible = true


func _apply(e):
	_play(e.anim)
	_set_item(e.item)
