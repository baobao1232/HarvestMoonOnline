extends "res://scripts/MapBase.gd"

var debug_timer := 0.0


func _ready():
	super()
	Dbg.p("Thorrn loaded")


func _on_to_farm_body_entered(body: Node2D) -> void:
	pass


func _process(delta):
	super(delta)   # giữ auto-save vị trí của MapBase

	var player = SceneManager.player
	var table = ysort.get_node_or_null("Table")

	if player == null:
		Dbg.p("DEBUG: player NULL")
		return

	if table == null:
		Dbg.p("DEBUG: không tìm thấy Table trong ", ysort.get_path())
		return

	var spr = table.get_node_or_null("Sprite2D")

	# ===== DEBUG (in mỗi 0.5s) =====
	debug_timer -= delta
	if debug_timer <= 0:
		debug_timer = 0.5
		Dbg.p("--------- DEBUG TABLE ---------")
		Dbg.p("player y=", player.global_position.y, " | z=", player.z_index)
		Dbg.p("player parent=", player.get_parent().get_path())
		Dbg.p("table  y=", table.global_position.y, " | z=", table.z_index)
		Dbg.p("table parent=", table.get_parent().get_path())
		if spr:
			Dbg.p("sprite z=", spr.z_index, " | sprite y_sort=", spr.y_sort_enabled)
			Dbg.p("YSort enabled=", ysort.y_sort_enabled)

	# ===== LOGIC TẠM: player ở sau bàn thì bàn che player =====
	if player.global_position.y < table.global_position.y:
		table.z_index = 2
	else:
		table.z_index = 0
