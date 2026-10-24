class_name Dbg

const ENABLED := true


static func p(a = "", b = "", c = "", d = "", e = "", f = "") -> void:
	if not ENABLED:
		return

	var parts := []
	for x in [a, b, c, d, e, f]:
		if str(x) != "":
			parts.append(str(x))

	print(" ".join(parts))
