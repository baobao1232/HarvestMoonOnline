extends StaticBody2D

@onready var ban_ngay = $BanNgay
@onready var ban_dem = $BanDem
@onready var light = $PointLight2D
@onready var glow = $ColorRect   # 🔥 thêm cái này


func _ready():
	TimeManager.time_changed.connect(_on_time_changed)
	update_lamp(TimeManager.hour)


func _on_time_changed(hour, minute):
	update_lamp(hour)


func update_lamp(hour):

	var is_night = hour >= 18 or hour < 6

	if is_night:
		# 🌙 BAN ĐÊM
		ban_ngay.visible = false
		ban_dem.visible = true

		if light:
			light.enabled = true

		if glow:
			glow.visible = true   # bật glow

	else:
		# ☀ BAN NGÀY
		ban_ngay.visible = true
		ban_dem.visible = false

		if light:
			light.enabled = false

		if glow:
			glow.visible = false  # 🔥 tắt luôn
