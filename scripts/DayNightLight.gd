extends StaticBody2D

@onready var ban_ngay = $BanNgay
@onready var ban_dem = $BanDem
@onready var light = $Light   # hoặc PointLight2D nếu mày đặt tên vậy

func _ready():
	TimeManager.time_changed.connect(_on_time_changed)
	update_day_night(TimeManager.hour)


func _on_time_changed(hour, minute):
	update_day_night(hour)


func update_day_night(hour):

	var is_night = hour >= 18 or hour < 6

	if is_night:
		# 🌙 BAN ĐÊM
		if ban_ngay:
			ban_ngay.visible = false

		if ban_dem:
			ban_dem.visible = true

		if light:
			light.enabled = true   # 🔥 nhớ: light dùng enabled

	else:
		# ☀ BAN NGÀY
		if ban_ngay:
			ban_ngay.visible = true

		if ban_dem:
			ban_dem.visible = false

		if light:
			light.enabled = false
