extends Node

signal weather_changed(weather)

var current_weather := "SUNNY"


func _ready():
	TimeManager.time_synced.connect(_refresh)
	TimeManager.day_changed.connect(func(_d, _s, _y): _refresh())
	_refresh()


func _refresh():

	var w := weather_for_day(TimeManager.total_days)

	if w == current_weather:
		return

	current_weather = w
	weather_changed.emit(w)
	Dbg.p("Weather today:", w)


# Cùng day_index → luôn ra cùng kết quả (mọi client giống nhau)
func weather_for_day(day_index: int) -> String:

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hvm_weather_%d" % day_index)

	var roll := rng.randi() % 100
	var s := (day_index / TimeManager.DAYS_PER_SEASON) % 4

	match s:
		0: # xuân
			return "RAIN" if roll < 30 else "SUNNY"
		1: # hè
			return "RAIN" if roll < 20 else "SUNNY"
		2: # thu
			return "RAIN" if roll < 25 else "SUNNY"
		_: # đông
			return "SNOW" if roll < 40 else "SUNNY"


# xem trước ngày mai (dùng cho dự báo thời tiết sau này)
func forecast_tomorrow() -> String:
	return weather_for_day(TimeManager.total_days + 1)


func is_raining():
	return current_weather == "RAIN"

func is_snowing():
	return current_weather == "SNOW"

func is_sunny():
	return current_weather == "SUNNY"
