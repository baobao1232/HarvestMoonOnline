extends Node2D

var item : ItemData
var amount : int = 1

var can_pick := false
var player = null
var is_picking := false

var drop_id := 0
var pending := false

@onready var sprite = $Sprite2D


func setup(new_item, new_amount, id := 0):
	item = new_item
	amount = new_amount
	drop_id = id

	if item.icon:
		sprite.texture = item.icon


func _process(_delta):

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
func start_pick_animation(target_pos: Vector2):

	if is_picking:
		return

	is_picking = true

	$Area2D.monitoring = false

	var tween = create_tween()

	# nhảy nhẹ lên
	tween.tween_property(self, "global_position", global_position + Vector2(0, -8), 0.08)

	# bay vào người chơi
	tween.tween_property(self, "global_position", target_pos, 0.18)

	# nhỏ dần + mờ dần
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)

	await tween.finished

	queue_free()


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
