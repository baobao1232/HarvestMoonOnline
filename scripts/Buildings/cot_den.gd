extends StaticBody2D

@onready var ban_ngay = $BanNgay
@onready var ban_dem = $BanDem
@onready var light: PointLight2D = $PointLight2D
@onready var glow = $ColorRect

static var _tex: GradientTexture2D


static func _soft_tex() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 1),
			Color(0.35, 0.35, 0.35, 1),
			Color(0, 0, 0, 1)
		])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex = t
	return _tex


func _ready():
	add_to_group("street_lamp")
	if glow:
		glow.visible = false          # tắt hẳn ColorRect, đã có đèn thật

	light.texture = _soft_tex()
	light.texture_scale = 1.0
	light.color = Color(1.0, 0.82, 0.5)
	light.energy = 2.5
	light.shadow_enabled = false
	light.blend_mode = Light2D.BLEND_MODE_ADD

	TimeManager.time_changed.connect(_on_time_changed)
	update_lamp(TimeManager.hour)


func _on_time_changed(hour, _minute):
	update_lamp(hour)


func update_lamp(hour):
	var is_night = hour >= 19 or hour < 5
	ban_ngay.visible = not is_night
	ban_dem.visible = is_night
	light.visible = is_night
	light.enabled = is_night
# ShadowCaster hỏi: đèn này đang sáng ở đâu, bán kính bao nhiêu
func get_light_info() -> Dictionary:
	if not light.visible or not light.enabled:
		return {}
	var r := 64.0 * light.texture_scale * absf(light.global_scale.x)   # texture 128px → bán kính 64
	return {"pos": light.global_position, "radius": r}
