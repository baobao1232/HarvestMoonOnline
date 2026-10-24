extends CanvasModulate

var target_color : Color = Color(1,1,1)
var is_indoor := false


func _ready():
	Dbg.p("🌙 DayNight READY:", self)

	TimeManager.time_changed.connect(update_target)
	update_target(TimeManager.hour, TimeManager.minute)


func _process(delta):

	# 🔥 INDOOR → trắng NGAY, không lerp
	if is_indoor:
		if color != Color(1,1,1):
			Dbg.p("🏠 FORCE WHITE (INDOOR)")
		color = Color(1, 1, 1)
		return

	# 🌳 OUTDOOR → lerp bình thường
	color = color.lerp(target_color, delta * 0.5)


# =========================================
# 🌙 SET INDOOR
# =========================================
func set_indoor(value: bool):
	is_indoor = value

	Dbg.p("🌙 set_indoor:", value)

	if is_indoor:
		color = Color(1,1,1) # reset ngay


# =========================================
# 🌅 TIME UPDATE
# =========================================
func update_target(hour, minute):

	var t = hour + minute / 60.0
	var season = TimeManager.season

	var dawn : Color
	var morning : Color
	var day : Color
	var sunset : Color
	var night : Color


	match season:

		0:
			dawn = Color(0.75, 0.85, 0.7)
			morning = Color(0.95, 1.0, 0.9)
			day = Color(1, 1, 1)
			sunset = Color(1, 0.6, 0.4)
			night = Color(0.22, 0.26, 0.38)

		1:
			dawn = Color(0.85, 0.9, 0.7)
			morning = Color(1.0, 0.95, 0.8)
			day = Color(1, 1, 1)
			sunset = Color(1, 0.55, 0.35)
			night = Color(0.20, 0.24, 0.36)

		2:
			dawn = Color(0.9, 0.8, 0.6)
			morning = Color(1.0, 0.9, 0.75)
			day = Color(1.0, 0.95, 0.9)
			sunset = Color(1, 0.5, 0.3)
			night = Color(0.24, 0.24, 0.35)

		3:
			dawn = Color(0.75, 0.85, 1)
			morning = Color(0.9, 0.95, 1)
			day = Color(0.95, 0.98, 1)
			sunset = Color(0.9, 0.65, 0.5)
			night = Color(0.26, 0.3, 0.42)


	if t >= 5 and t < 6:
		target_color = night.lerp(dawn, (t - 5))

	elif t >= 6 and t < 10:
		target_color = dawn.lerp(morning, (t - 6) / 4.0)

	elif t >= 10 and t < 16:
		target_color = morning.lerp(day, (t - 10) / 6.0)

	elif t >= 16 and t < 18:
		target_color = day.lerp(sunset, (t - 16) / 2.0)

	elif t >= 18 and t < 20:
		target_color = sunset.lerp(night, (t - 18) / 2.0)

	else:
		target_color = night

	#Dbg.p("🌙 TARGET:", target_color)
