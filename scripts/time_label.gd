extends Label

func _ready():
	update_time()

	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)


func _on_time_changed(hour, minute):
	update_time()


func _on_day_changed(day, season, year):
	update_time()


func update_time():
	text = TimeManager.get_time_string() + "\n" + TimeManager.get_date_string()
	
