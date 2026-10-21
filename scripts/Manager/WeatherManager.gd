extends Node

signal weather_changed(weather)

const WEATHER_TYPES = [
	"SUNNY",
	"RAIN",
	"SNOW"
]

var current_weather := "SUNNY"


func _ready():
	TimeManager.day_changed.connect(on_new_day)


func on_new_day(day, season, year):

	generate_weather(season)

	emit_signal("weather_changed", current_weather)

	print("Weather today:", current_weather)



func generate_weather(season):

	var roll = randi() % 100

	# WINTER có snow
	if season == 3:

		if roll < 60:
			current_weather = "SNOW"
		else:
			current_weather = "SUNNY"

		return

	# mùa khác

	if roll < 70:
		current_weather = "SUNNY"
	elif roll < 90:
		current_weather = "RAIN"
	else:
		current_weather = "SUNNY"



func is_raining():

	return current_weather == "RAIN"


func is_snowing():

	return current_weather == "SNOW"


func is_sunny():

	return current_weather == "SUNNY"
