extends Node2D

var item : ItemData
var amount : int = 1

var can_pick := false
var player = null
var is_picking := false

var drop_id := 0
var pending := false

var flying := false
var fly_target = null
var fly_speed := 120.0
var fly_time := 0.0

@onready var sprite = $Sprite2D

func setup(new_item, new_amount, id := 0, auto := false):
	item = new_item
	amount = new_amount
	drop_id = id

	if item.icon:
		sprite.texture = item.icon

	if auto:
		_auto_pickup()

func _auto_pickup():

	# nảy lên rồi rơi xuống
	var start := global_position
	var tw = create_tween()
	tw.tween_property(self, "global_position", start + Vector2(0, -10), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", start, 0.15).set_ease(Tween.EASE_IN)
	await tw.finished

	if not is_instance_valid(self) or pending or is_picking:
		return

	var p = SceneManager.player
	if p == null or not is_instance_valid(p):
		return

	player = p
	pending = true

	Server.api("pickup", {"drop_id": drop_id}, func(r):
		pending = false
		if r.get("ok", false) and is_instance_valid(self):
			start_pick_animation(p.global_position)
	)
	
func _process(delta):

	# ===== ĐANG BAY VỀ PLAYER =====
	if flying:
		if fly_target == null or not is_instance_valid(fly_target):
			queue_free()
			return

		var dest = fly_target.global_position + Vector2(0, -8)   # thân người, không phải chân
		fly_time += delta
		fly_speed += 900.0 * delta                                # tăng tốc dần → luôn đuổi kịp

		var to_dest = dest - global_position
		var step = fly_speed * delta

		# nhỏ dần + mờ dần khi bay
		var k = clamp(fly_time / 0.35, 0.0, 1.0)
		scale = Vector2.ONE.lerp(Vector2(0.2, 0.2), k)
		modulate.a = 1.0 - k

		if to_dest.length() <= step or fly_time > 1.0:
			queue_free()
			return

		global_position += to_dest.normalized() * step
		return

	if UIManager.current_ui != null or DialogManager.is_showing:
		return

	if is_picking or pending:
		return

	if can_pick and Input.is_action_just_pressed("interact"):

		if player == null or not is_instance_valid(player):
			return

		pending = true
		var target_pos = player.global_position

		Server.api("pickup", {"drop_id": drop_id}, func(r):
			pending = false
			if r.get("ok", false) and is_instance_valid(self):
				start_pick_animation(target_pos)
		)

# ===============================
# PICK ANIMATION
# ===============================
func start_pick_animation(_target_pos: Vector2):

	if is_picking:
		return

	is_picking = true
	$Area2D.set_deferred("monitoring", false)

	fly_target = player if player != null else SceneManager.player
	fly_speed = 120.0
	fly_time = 0.0

	# nảy nhẹ lên rồi bắt đầu đuổi theo
	var tw = create_tween()
	tw.tween_property(self, "global_position", global_position + Vector2(0, -8), 0.08)
	await tw.finished

	flying = true
# ===============================
# AREA DETECT
# ===============================
func _on_area_2d_body_entered(body):

	if body.is_in_group("player"):
		can_pick = true
		player = body


func _on_area_2d_body_exited(body):

	if body == player:
		can_pick = false
		player = null
