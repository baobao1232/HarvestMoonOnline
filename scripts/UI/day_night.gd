extends CanvasModulate

var target_color : Color = Color(1,1,1)
var indoor_target : Color = Color(1,1,1)

# ===== MÀU TRONG NHÀ =====
const INDOOR_DAY   := Color(1.0, 1.0, 1.0, 1.0)               # ban ngày: sáng bình thường
const INDOOR_LAMP  := Color(1.0, 0.82, 0.55)       # đèn bóng vàng ấm (chỉnh ở đây)
const INDOOR_OFF   := Color(0.25, 0.27, 0.38)      # tắt đèn: tối xanh


func _ready():
	TimeManager.time_changed.connect(update_target)
	update_target(TimeManager.hour, TimeManager.minute)


func _process(delta):

	var scene = get_tree().current_scene
	var indoor = scene != null and scene.get("is_indoor") == true

	if indoor:
		# vào nhà thì đổi khá nhanh, nhưng vẫn mượt
		color = color.lerp(indoor_target, delta * 4.0)
	else:
		color = color.lerp(target_color, delta * 0.5)

# =========================================
# 🌙 SET INDOOR
# =========================================
func set_indoor(value: bool):
	Dbg.p("🌙 set_indoor:", value)

	# vào nhà thì nhảy thẳng sang màu indoor hiện tại, ra ngoài thì để _process lerp
	if value:
		color = indoor_target

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
	
		# ===== MÀU INDOOR THEO GIỜ =====
	if t >= 6 and t < 17:
		indoor_target = INDOOR_DAY                                  # ngày
	elif t >= 17 and t < 19:
		indoor_target = INDOOR_DAY.lerp(INDOOR_LAMP, (t - 17) / 2.0) # chiều → bật đèn dần
	elif t >= 19 and t < 22:
		indoor_target = INDOOR_LAMP                                 # tối: đèn vàng
	elif t >= 22 or t < 5:
		indoor_target = INDOOR_OFF                                 # khuya: tối
	else:
		indoor_target = INDOOR_OFF.lerp(INDOOR_DAY, (t - 5))        # 5h→6h: sáng dần
	#Dbg.p("🌙 TARGET:", target_color)
