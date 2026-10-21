extends "res://scripts/MapBase.gd"

func _ready():
	super()
	print("Thorrn loaded")


func _on_to_farm_body_entered(body: Node2D) -> void:
	pass


func _process(delta):

	var player = SceneManager.player
	var table = ysort.get_node_or_null("Table")
