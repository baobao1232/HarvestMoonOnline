extends CharacterBody2D

@export var walk_speed := 20
@export var run_speed := 90
@export var icon_scene: PackedScene = preload("res://scn/Icons/ChamThan.tscn")
@export var icon_time := 3.0

# 🔥 DEV MODE
@export var dev_mode := false   # bật = đứng yên test sort

var direction := Vector2.ZERO
var change_time := 0.0

var player: Node2D = null
var running := false
var icon = null

@onready var anim = $AnimatedSprite2D
@onready var icon_anchor = $IconAnchor


func _ready():
	randomize()

	if not dev_mode:
		change_direction()
	else:
		velocity = Vector2.ZERO   # 🔥 đứng im luôn


func _physics_process(delta):

	# 🔥 DEV MODE → KHÓA HOÀN TOÀN
	if dev_mode:
		velocity = Vector2.ZERO
		update_anim_idle()
		return


	# ===== RUN AWAY =====
	if running and player != null:

		run_away(player)

		if is_on_wall():
			change_direction()

		move_and_slide()
		update_anim()
		return


	# ===== RANDOM WALK =====
	change_time -= delta

	if change_time <= 0:
		change_direction()

	if is_on_wall():
		change_direction()

	move_and_slide()
	update_anim()


# ===== RANDOM WALK =====

func change_direction():

	change_time = randf_range(1.5, 3.5)

	direction = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized()

	velocity = direction * walk_speed


# ===== RUN AWAY =====

func run_away(player):

	var dir = (global_position - player.global_position).normalized()
	velocity = dir * run_speed


# ===== DETECT PLAYER =====

func _on_detect_body_entered(body):

	if dev_mode:
		return   # 🔥 dev thì không trigger

	if body == SceneManager.player:
		player = body
		running = true
		show_icon()


func _on_detect_body_exited(body):

	if dev_mode:
		return

	if body == SceneManager.player:
		running = false
		player = null


# ===== ICON =====

func show_icon():

	if icon != null:
		return

	icon = icon_scene.instantiate()
	icon_anchor.add_child(icon)

	hide_icon_later()


func hide_icon():

	if icon != null:
		icon.queue_free()
		icon = null


func hide_icon_later():

	await get_tree().create_timer(icon_time).timeout
	hide_icon()


# ===== ANIMATION =====

func update_anim():

	if abs(velocity.x) > abs(velocity.y):

		if velocity.x > 0:
			anim.play("right")
		else:
			anim.play("left")

	else:

		if velocity.y > 0:
			anim.play("down")
		else:
			anim.play("up")


# 🔥 DEV IDLE
func update_anim_idle():
	# giữ animation đứng yên (chọn tùy mày)
	anim.play("down")
