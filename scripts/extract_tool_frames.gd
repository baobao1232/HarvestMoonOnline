@tool
extends EditorScript

const SHEET := "res://Assest/Character/use_tool_marker.png"   # bản sheet CÒN chấm xanh
const CELL := 32
const OUT := "res://scripts/Players/tool_frames.json"
const ROW_DIR := ["up", "down", "left", "right"]

func _is_green(c: Color) -> bool:
	return c.a > 0.5 and c.g > 0.6 and c.g > c.r + 0.15 and c.g > c.b + 0.15

func _run():
	var img: Image = load(SHEET).get_image()
	var data := {}

	for row in img.get_height() / CELL:
		for col in img.get_width() / CELL:
			var pts: Array[Vector2] = []
			for y in CELL:
				for x in CELL:
					if _is_green(img.get_pixel(col * CELL + x, row * CELL + y)):
						pts.append(Vector2(x, y))
			if pts.is_empty():
				continue

			var a := pts[0]
			var b := pts[0]
			var best := 0.0
			for p in pts:
				for q in pts:
					var d := p.distance_squared_to(q)
					if d > best:
						best = d; a = p; b = q

			var centre := Vector2(CELL / 2.0, CELL / 2.0)
			if a.distance_to(centre) > b.distance_to(centre):
				var t := a; a = b; b = t

			data["use_%s_%d" % [ROW_DIR[row], col]] = {
				"x": a.x, "y": a.y,
				"rot": rad_to_deg((b - a).angle())
			}

	var f = FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("OK: %d frames -> %s" % [data.size(), OUT])
