extends Node

var sun_dir := Vector2.RIGHT
var sun_height := 1.0


func _process(_delta):
	var t: float = float(TimeManager.hour) + float(TimeManager.minute) / 60.0

	var k: float = clampf((t - 6.0) / 12.0, 0.0, 1.0)
	var angle: float = lerpf(PI, 0.0, k)

	sun_dir = Vector2(cos(angle), sin(angle)).normalized()
	sun_height = sin(k * PI)
