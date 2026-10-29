extends "res://scripts/MapBase.gd"

func _ready():
	super()    # MapBase lo attach player, camera, day/night và spawn NPC
	Dbg.p("Forest loaded")


func _on_to_farm_body_entered(body: Node2D) -> void:
	pass


func _on_to_tho_moc_body_entered(body: Node2D) -> void:
	pass
