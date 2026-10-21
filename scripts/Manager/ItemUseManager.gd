extends Node
class_name ItemUseManager

# ===============================
# MAIN USE
# ===============================
static func use_item(player, item, slot = null):

	print("================================")
	print("SLOT:", slot)

	if item == null:
		print("❌ No item")
		return

	print("PLAYER USE:", item.name)
	print("IS TOOL:", item.is_tool())
	print("TOOL TYPE:", item.tool_type)
	print("EXPECTED HOE:", ItemData.ToolType.HOE)

	# ===============================
	# 🪓 TOOL
	# ===============================
	if item.is_tool():

		print("🔧 ENTER TOOL LOGIC")

		# 🔥 FIX: KHÔNG DÙNG MATCH
		if item.tool_type == ItemData.ToolType.HOE:

			print("🪓 HOE DETECTED")

			if player.dat_scene == null:
				print("❌ dat_scene NULL")
				return

			var pos = get_front_position(player)
			print("📍 FRONT POS:", pos)

			if not can_farm_at(player, pos):
				print("❌ Không phải đất trồng")
				return
			else:
				print("✅ Có thể trồng")

			if has_dat_at(player, pos):
				print("⚠ Đã có đất rồi")
				return
			else:
				print("✅ Chưa có đất")

			print("🚀 SPAWN DAT")
			spawn_dat(player)
			return


		elif item.tool_type == ItemData.ToolType.WATERING_CAN:
			print("💧 WATER CAN")
			use_water(player)
			return


		elif item.tool_type == ItemData.ToolType.SICKLE:
			print("🌿 SICKLE")
			use_sickle(player)
			return


		else:
			print("❌ UNKNOWN TOOL TYPE:", item.tool_type)
			return


	# ===============================
	# 🌱 SEED / 🍖 FOOD
	# ===============================
	if item.is_seed() or item.is_food():

		print("🍽 / 🌱 USE:", item.name)

		var used := false

		if item.is_seed():

			print("🌱 TRY PLANT")

			var planted = plant_seed_around(player, item)
			print("🌱 planted:", planted)

			if planted > 0:
				used = true
				player.play_raihat_anim()
			else:
				print("❌ Không trồng được")

		if item.is_food():
			print("🍖 Ăn đồ")
			used = true

		if used and slot != null:

			print("👉 TRỪ ITEM | BEFORE:", slot.amount)

			if slot.amount <= 0:
				print("❌ Hết item")
				return

			slot.amount -= 1

			if slot.amount <= 0:
				slot.set_item(null, 0)
			else:
				slot._update_amount()

			print("👉 AFTER:", slot.amount)

		return

	print("❌ ITEM KHÔNG DÙNG ĐƯỢC")
	print("================================")
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
# SPAWN DAT
# ===============================
static func spawn_dat(player):

	var pos = get_front_position(player)

	var dat = player.dat_scene.instantiate()
	dat.global_position = pos + Vector2(8, 8)

	player.get_parent().add_child(dat)

	if dat.has_method("till"):
		dat.till()

	print("====== SPAWN DEBUG ======")
	print("PLAYER:", player.global_position)
	print("FRONT:", pos)
	print("FINAL:", dat.global_position)
	print("=========================")


# ===============================
# WATER
# ===============================
static func use_water(player):

	if not player.ray.is_colliding():
		return

	var obj = player.ray.get_collider()

	if obj.has_method("water"):
		obj.water()
	elif obj.get_parent() and obj.get_parent().has_method("water"):
		obj.get_parent().water()

	print("💧 Tưới")


# ===============================
# SICKLE
# ===============================
static func use_sickle(player):

	if not player.ray.is_colliding():
		return

	var obj = player.ray.get_collider()

	if obj.has_method("harvest"):
		obj.harvest()
		return

	if obj.get_parent() and obj.get_parent().has_method("harvest"):
		obj.get_parent().harvest()
		return

	print("❌ Không có gì để cắt")


# ===============================
# FARM CHECK
# ===============================
static func can_farm_at(player, pos):

	var space = player.get_world_2d().direct_space_state

	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space.intersect_point(query)

	for r in result:
		var collider = r.collider

		if collider == null:
			continue

		if collider.name == "BaiDat":
			return true

		if collider.get_parent() and collider.get_parent().name == "BaiDat":
			return true

	return false


# ===============================
# CHECK DAT
# ===============================
static func has_dat_at(player, pos):

	for child in player.get_parent().get_children():

		if child.scene_file_path == player.dat_scene.resource_path:
			if child.global_position.distance_to(pos + Vector2(8, 8)) < 1:
				return true

	return false


# ===============================
# PLANT AROUND
# ===============================
static func plant_seed_around(player, item):

	var tile_size = 16

	var base = Vector2(
		floor(player.global_position.x / tile_size) * tile_size,
		floor(player.global_position.y / tile_size) * tile_size
	)

	var offsets = [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1,  0), Vector2(0,  0), Vector2(1,  0),
		Vector2(-1,  1), Vector2(0,  1), Vector2(1,  1)
	]

	var planted := 0

	for o in offsets:

		var pos = base + o * tile_size

		if not has_dat_at(player, pos):
			continue

		var dat = get_dat_at(player, pos)
		if dat == null:
			continue

		if dat.has_seed:
			continue

		if dat.has_method("plant_seed"):
			dat.plant_seed(item)
			print("🌱 TRỒNG:", pos)
			planted += 1

	print("🌱 TOTAL:", planted)
	return planted


# ===============================
# GET DAT
# ===============================
static func get_dat_at(player, pos):

	for child in player.get_parent().get_children():

		if child.scene_file_path == player.dat_scene.resource_path:
			if child.global_position.distance_to(pos + Vector2(8, 8)) < 1:
				return child

	return null
