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

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: Server.api("give", {"item": "binhtuoi_normal", "amount": 1})
			KEY_F2: Server.api("give", {"item": "liem_normal", "amount": 1})
			KEY_F3: Server.api("give", {"item": "cucai_s", "amount": 10})
