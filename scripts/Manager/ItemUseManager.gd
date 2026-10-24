extends Node
class_name ItemUseManager


# ===============================
# MAIN USE
# ===============================
static func use_item(player, item, hotbar_index := -1):

	if item == null or hotbar_index < 0:
		return

	var p = player.global_position
	var base := {"slot": hotbar_index, "px": p.x, "py": p.y}

	# ===== TOOL =====
	if item.is_tool():
		var pos = get_front_position(player)
		var params = base.merged({"x": pos.x, "y": pos.y})

		match item.tool_type:
			ItemData.ToolType.HOE:
				if not can_farm_at(player, pos):
					return
				Server.request_action("till", params)
			ItemData.ToolType.WATERING_CAN:
				Server.request_action("water", params)
			ItemData.ToolType.SICKLE:
				Server.request_action("harvest", params)
		return

	# ===== SEED =====
	if item.is_seed():
		Server.request_action("plant", base, func(r):
			if r.get("ok", false) and is_instance_valid(player):
				player.play_raihat_anim()
		)
		return

	# ===== FOOD =====
	if item.is_food():
		Server.request_action("consume", {"src": "hotbar", "slot": hotbar_index})


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
# FARM CHECK (chặn sớm, server vẫn kiểm tra lại)
# ===============================
static func can_farm_at(player, pos):

	var space = player.get_world_2d().direct_space_state

	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos + Vector2(8, 8)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	for r in space.intersect_point(query):
		var c = r.collider
		if c == null:
			continue
		if c.name == "BaiDat" or (c.get_parent() and c.get_parent().name == "BaiDat"):
			return true

	return false
