extends Node
class_name ItemUseManager


# ===============================
# MAIN USE
# (tham số thứ 3 giữ lại cho hud.gd gọi, không dùng nữa)
# ===============================
static func use_item(player, item, _slot = null):

	Dbg.p("USE_ITEM | item:", item.id if item != null else "null",
		"| is_tool:", item.is_tool() if item != null else false,
		"| tool_type:", item.tool_type if item != null else -1)

	if player == null or item == null:
		return

	# ===== TOOL =====
	if item.is_tool():

		var pos = get_front_position(player)
		var t: int = int(item.tool_type)

		if t == ItemData.ToolType.HOE:
			var ok = can_farm_at(player, pos)
			var existed = FarmManager.get_tile(pos)
			Dbg.p("HOE | pos:", pos, "| can_farm:", ok, "| đã có đất:", existed != null)
			if not ok or existed != null:
				return
			Server.api("till", {"x": pos.x, "y": pos.y})

		elif t == ItemData.ToolType.WATERING_CAN:
			if FarmManager.get_tile(pos) == null:
				return
			Server.api("water", {"x": pos.x, "y": pos.y})

		elif t == ItemData.ToolType.SICKLE:
			if FarmManager.get_tile(pos) == null:
				return
			Server.api("harvest", {"x": pos.x, "y": pos.y})

		return

	# ===== SEED =====
	if item.is_seed():

		var targets = plant_targets(player)
		if targets.is_empty():
			return

		Server.api("plant", {"seed": item.id, "tiles": targets}, func(r):
			if r.get("ok", false) and is_instance_valid(player):
				player.play_raihat_anim()
		)
		return

	# ===== FOOD =====
	if item.is_food():
		Server.api("eat", {"item": item.id})


# ===============================
# FRONT POSITION
# ===============================
static func get_front_position(player):

	var tile_size = 16
	var foot = player.ray.global_position

	var base = Vector2(
		floor(foot.x / tile_size) * tile_size,
		floor(foot.y / tile_size) * tile_size
	)

	var dir = Vector2.ZERO

	match player.last_dir:
		"up": dir = Vector2(0, -1)
		"down": dir = Vector2(0, 1)
		"left": dir = Vector2(-1, 0)
		"right": dir = Vector2(1, 0)

	return base + dir * tile_size


# ===============================
# PLANT TARGETS: ô đất 3x3 quanh player chưa có cây
# (server kiểm tra lại, và trừ 1 hạt mỗi ô)
# ===============================
static func plant_targets(player) -> Array:

	var tile_size = 16
	var base = Vector2(
		floor(player.global_position.x / tile_size) * tile_size,
		floor(player.global_position.y / tile_size) * tile_size
	)

	var list := []

	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			var pos = base + Vector2(ox, oy) * tile_size
			var dat = FarmManager.get_tile(pos)
			if dat != null and not dat.has_seed:
				list.append({"x": pos.x, "y": pos.y})

	return list


# ===============================
# FARM CHECK (chặn sớm, server vẫn kiểm tra lại)
# ===============================
static func can_farm_at(player, pos):

	# chỉ cuốc được ở map farm
	var scene = player.get_tree().current_scene
	if scene == null or scene.scene_file_path != "res://scn/Maps/farm.tscn":
		return false

	# vùng BaiDat: x 269 → 964, y 171 → 580
	var area := Rect2(269, 171, 695, 409)
	return area.has_point(pos + Vector2(8, 8))
