extends Node2D

var item : ItemData
var amount : int = 1

var can_pick := false
var player = null
var is_picking := false

@onready var sprite = $Sprite2D


func setup(new_item, new_amount):
	item = new_item
	amount = new_amount

	if item.icon:
		sprite.texture = item.icon


func _process(delta):

	# 🔥 CHỈ CHẶN KHI CÓ UI
	if UIManager.current_ui != null:
		return

	if is_picking:
		return

	if can_pick and Input.is_action_just_pressed("interact"):

		if player == null or not is_instance_valid(player):
			return

		if InventoryManager.add_item(item, amount):

			var target_pos = player.global_position
			start_pick_animation(target_pos)
# ===============================
# PICK ANIMATION
# ===============================
func start_pick_animation(target_pos: Vector2):
	print("MODE:", UIManager.input_mode)

	if is_picking:
		return

	is_picking = true

	$Area2D.monitoring = false

	var tween = create_tween()

	# ===== nhảy nhẹ lên
	var jump_pos = global_position + Vector2(0, -8)

	tween.tween_property(
		self,
		"global_position",
		jump_pos,
		0.08
	)

	# ===== bay vào target (KHÔNG dùng player nữa)
	tween.tween_property(
		self,
		"global_position",
		target_pos,
		0.18
	)

	# ===== scale nhỏ
	tween.parallel().tween_property(
		self,
		"scale",
		Vector2(0.2, 0.2),
		0.25
	)

	# ===== fade
	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		0.25
	)

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
