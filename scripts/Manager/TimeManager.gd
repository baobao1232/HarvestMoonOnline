extends Node

var dev_mode := 1
# 0 = normal
# 1 = force 7h
# 2 = force 20h
signal time_changed(hour, minute)
signal day_changed(day, season, year)

const SEASONS = ["SPRING","SUMMER","AUTUMN","WINTER"]

# 5 phút real = 1 giờ game
const REAL_SECONDS_PER_GAME_HOUR := 300

# bắt đầu lúc 06:00
const START_HOUR := 6

var minute := 0
var hour := 6
var day := 1
var season := 0
var year := 1

var last_minute := -1
var server_start_time := 0
var last_day := -1

const SAVE_FILE := "user://time.save"


func _ready():
	load_time()


func _process(delta):

	# ===== DEV MODE =====
	if dev_mode != 0:
		if dev_mode == 1:
			hour = 7
		elif dev_mode == 2:
			hour = 20

		minute = 0
		emit_signal("time_changed", hour, minute)
		return

	# ===== NORMAL =====
	var now = Time.get_unix_time_from_system()
	var real_passed = now - server_start_time

	var total_game_minutes = int(real_passed / REAL_SECONDS_PER_GAME_HOUR * 60)

	update_time(total_game_minutes)


func update_time(total_minutes):

	minute = total_minutes % 60
	var total_hours = total_minutes / 60

	hour = (total_hours + START_HOUR) % 24

	var total_days = total_hours / 24

	day = (total_days % 30) + 1
	season = (total_days / 30) % 4
	year = (total_days / 120) + 1

	# ===============================
	# ⏰ TIME CHANGE (MỖI PHÚT)
	# ===============================
	if minute != last_minute:
		last_minute = minute
		emit_signal("time_changed", hour, minute)

	# ===============================
	# 🌙 DAY CHANGE (CHỈ 1 LẦN)
	# ===============================
	if day != last_day:
		last_day = day
		emit_signal("day_changed", day, season, year)

func save_time():
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_64(server_start_time)
	file.close()


func load_time():

	if FileAccess.file_exists(SAVE_FILE):

		var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
		server_start_time = file.get_64()
		file.close()

	else:

		server_start_time = Time.get_unix_time_from_system()
		save_time()


func get_time_string():
	return "%02d:%02d" % [hour, minute]


func get_date_string():
	return "Day %d - %s - Year %d" % [day, SEASONS[season], year]
