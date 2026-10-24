extends "res://scripts/MapBase.gd"


func _ready():
	super()
	Dbg.p("Farm loaded")

	var pd = Server.player_data
	if pd != null:
		# deferred để chắc chắn YSort/scene đã sẵn sàng
		FarmManager.load_farm.call_deferred(pd.farm, ysort)


func _exit_tree():
	# rời map farm → tắt save (tránh ghi đè bằng danh sách rỗng/node đã free)
	FarmManager.clear_tiles()
