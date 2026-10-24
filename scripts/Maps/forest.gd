extends "res://scripts/MapBase.gd"

func _ready():
	super()

	Dbg.p("Forest loaded")
	Dbg.p("Map name:", name)

	NpcManager.spawn_npcs(name, $YSort)


func _process(delta):

	var player = SceneManager.player
	if player == null:
		return

	var tree = $YSort.get_node_or_null("Tree06")

	if tree == null:
		return

	#Dbg.p("-----")
	#Dbg.p("Player pos:", player.position.y)
	#Dbg.p("Player global:", player.global_position.y)
	#Dbg.p("Player z:", player.z_index)

	#Dbg.p("Tree pos:", tree.position.y)
	#Dbg.p("Tree global:", tree.global_position.y)
	#Dbg.p("Tree z:", tree.z_index)

func _on_to_farm_body_entered(body: Node2D) -> void:
	pass


func _on_to_tho_moc_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
