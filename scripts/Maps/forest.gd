extends "res://scripts/MapBase.gd"

func _ready():
	super()

	print("Forest loaded")
	print("Map name:", name)

	NpcManager.spawn_npcs(name, $YSort)


func _process(delta):

	var player = SceneManager.player
	if player == null:
		return

	var tree = $YSort.get_node_or_null("Tree06")

	if tree == null:
		return

	#print("-----")
	#print("Player pos:", player.position.y)
	#print("Player global:", player.global_position.y)
	#print("Player z:", player.z_index)

	#print("Tree pos:", tree.position.y)
	#print("Tree global:", tree.global_position.y)
	#print("Tree z:", tree.z_index)

func _on_to_farm_body_entered(body: Node2D) -> void:
	pass


func _on_to_tho_moc_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
