extends CharacterBody2D
# Lưu tại: res://scripts/Players/remote_player.gd
# Được gán vào bản instance của Player.tscn (thay cho move.gd) trong Client.gd
# -> không có input, không camera, không va chạm, KHÔNG nằm trong group "player"

var target_pos := Vector2.ZERO

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

	var item_show = get_node_or_null("ItemShow")
	if item_show:
		item_show.visible = false


func setup(pname: String, pos: Vector2, anim_name: String):
	global_position = pos
	target_pos = pos
	name_label.text = pname
	_play(anim_name)


func set_target(pos: Vector2, anim_name: String):
	target_pos = pos
	_play(anim_name)


func _play(anim_name: String):
	if anim_name == "" or not anim.sprite_frames.has_animation(anim_name):
		return
	if anim.animation != anim_name:
		anim.play(anim_name)


func _process(delta):
	# server gửi 10 lần/giây -> nội suy cho mượt
	if global_position.distance_to(target_pos) > 200.0:
		global_position = target_pos   # teleport / đổi map
	else:
		global_position = global_position.lerp(target_pos, clamp(delta * 12.0, 0.0, 1.0))
