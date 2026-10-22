extends Area2D

@export var target_map: String
@export var target_spawn: String

var triggered := false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	print("[TELEPORT] Body entered: ", body.name)

	if not body.is_in_group("player"):
		print("[TELEPORT] BLOCK: Not player group")
		return

	if triggered:
		return

	if SceneManager.player_data == null:
		print("[TELEPORT] BLOCK: player_data NULL")
		return

	if SceneManager.teleport_lock:
		print("[TELEPORT] BLOCK: teleport_lock = true")
		return

	triggered = true
	call_deferred("_teleport")


func _teleport() -> void:
	var player = SceneManager.player

	if player == null:
		print("[TELEPORT] ERROR: SceneManager.player NULL")
		triggered = false
		return

	if target_map.is_empty() or target_spawn.is_empty():
		print("[TELEPORT] ERROR: target_map hoặc target_spawn chưa được thiết lập")
		triggered = false
		return

	print("[TELEPORT] REQUEST → SERVER")
	print("MAP: ", target_map)
	print("SPAWN: ", target_spawn)

	SceneManager.request_change_map(target_map, target_spawn)
