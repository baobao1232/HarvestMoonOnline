# ShadowManager.gd (autoload)
extends Node

var sun_dir := Vector2.RIGHT
var sun_height := 1.0

func _process(delta):
	var t = TimeManager.hour + TimeManager.minute / 60.0
	
	var k = clamp((t - 6.0) / 12.0, 0.0, 1.0)
	var angle = lerp(PI, 0.0, k)
	
	sun_dir = Vector2(cos(angle), sin(angle)).normalized()
	sun_height = sin(k * PI)
