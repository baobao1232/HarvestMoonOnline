extends "res://scripts/MapBase.gd"


func _ready():
	super()
	Dbg.p("Farm loaded")

	var pd = Server.player_data
	if pd != null:
		Dbg.p("FARM LOAD:", pd.farm)
		FarmManager.load_farm.call_deferred(pd.farm, ysort)


func _exit_tree():
	FarmManager.clear_tiles()
	FarmManager.farm_parent = null
