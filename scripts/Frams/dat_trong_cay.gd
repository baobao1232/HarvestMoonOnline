extends Node2D

@onready var dat = $StaticBody2D/Dat
@onready var dat_da_tuoi = $StaticBody2D/Dat_DaTuoi
@onready var hat_giong = $StaticBody2D/HatGiong
@onready var grow_label = $StaticBody2D/GrowLabel

# ===============================
# STATE
# ===============================
var is_tilled := false
var is_watered := false
var has_seed := false

# ===============================
# CROP DATA
# ===============================
var crop_data = null
var growth_stage := 0
var current_day := 0

# ===============================
# PLAYER CHECK (LABEL)
# ===============================
var player = null
@export var show_distance := 32.0


# ===============================
func _ready():
	update_visual()


# ===============================
# 🔥 ONLY HANDLE LABEL HERE
# ===============================
func _process(delta):

	if player == null:
		player = get_tree().get_first_node_in_group("local_player")

	if player == null:
		return

	var tile_size = 16

	var player_tile = Vector2(
		floor((player.global_position.x - 8) / tile_size) * tile_size,
		floor((player.global_position.y - 8) / tile_size) * tile_size
	)

	var my_tile = get_grid_pos()

	# 🔥 DEBUG ĐẶT NGAY ĐÂY
	#Dbg.p("PLAYER:", player_tile)
	#Dbg.p("TILE:", my_tile)

	if player_tile == my_tile:
		update_grow_label()
	else:
		grow_label.visible = false

# ===============================
# 🪓 ACTION
# ===============================
func till():

	if is_tilled:
		return

	is_tilled = true

	# 🔥 ADD vào FarmManager
	FarmManager.add_tile(get_grid_pos(), self)

	FarmManager.update_neighbors(get_grid_pos())

	Dbg.p("🪓 Đã cuốc")

	update_visual()
	FarmManager.save_farm()
	
func water():
	if not is_tilled:
		return
	
	if is_watered:
		return
	
	is_watered = true
	Dbg.p("💧 Đã tưới")
	update_visual()
	FarmManager.save_farm()


func plant_seed(item):

	if not is_tilled:
		return

	if has_seed:
		return

	if item.crop_textures.size() == 0:
		Dbg.p("❌ Seed không có data")
		return

	has_seed = true
	crop_data = item

	growth_stage = 0
	current_day = 0

	Dbg.p("🌱 Plant seed → stage 0")

	update_visual()
	FarmManager.save_farm()


# ===============================
# 🌿 GROW (CALL BY GAME DAY)
# ===============================
func grow():

	if not has_seed or crop_data == null:
		return

	if crop_data.need_water and not is_watered:
		Dbg.p("❌ Thiếu nước")
		return

	current_day += 1

	var max_stage = crop_data.crop_textures.size() - 1

	if growth_stage >= max_stage:
		return

	if growth_stage < crop_data.grow_days.size():
		if current_day >= crop_data.grow_days[growth_stage]:

			current_day = 0
			growth_stage += 1

			Dbg.p("🌿 Stage:", growth_stage)

	update_visual()

	# reset nước mỗi ngày
	is_watered = false

# ===============================
# 🌾 HARVEST
# ===============================
func can_harvest() -> bool:

	if not has_seed or crop_data == null:
		return false

	return growth_stage >= crop_data.crop_textures.size() - 1


func harvest() -> bool:

	if not can_harvest():
		return false

	var item : ItemData = crop_data.harvest_item

	if item == null:
		return false

	# túi đầy thì không thu (tránh mất đồ)
	if not InventoryManager.can_add_item(item, 1):
		Dbg.p("Túi đầy")
		return false

	InventoryManager.add_item(item, 1)

	if crop_data.regrow:
		# cây ra quả nhiều lần: lùi về giai đoạn trước cuối
		growth_stage = max(crop_data.crop_textures.size() - 2, 0)
		current_day = 0
	else:
		has_seed = false
		crop_data = null
		growth_stage = 0
		current_day = 0

	grow_label.visible = false
	update_visual()

	FarmManager.save_farm()

	return true

# ===============================
# 🎨 VISUAL
# ===============================
func update_visual():

	dat.visible = false
	dat_da_tuoi.visible = false
	hat_giong.visible = false

	if not is_tilled:
		return

	# ===== ĐẤT =====
	var mask = get_neighbor_mask()

	dat.visible = true

	if dat is AnimatedSprite2D:
		dat.frame = mask

	# ===== NƯỚC =====
	if is_watered:
		dat_da_tuoi.visible = true

	# ===== CÂY =====
	if has_seed and crop_data != null:

		if crop_data.crop_textures.size() == 0:
			return

		hat_giong.visible = true

		var stage = clamp(growth_stage, 0, crop_data.crop_textures.size() - 1)

		if hat_giong is Sprite2D:
			hat_giong.texture = crop_data.crop_textures[stage]


# ===============================
# 🧾 LABEL (GAME DAY)
# ===============================
func update_grow_label():

	if not has_seed or crop_data == null:
		grow_label.visible = false
		return

	var max_stage = crop_data.crop_textures.size() - 1

	# ===== TÊN CÂY =====
	var crop_name = crop_data.name if "name" in crop_data else "Crop"

	# ===== READY =====
	if growth_stage >= max_stage:
		grow_label.text = crop_name + "\nReady"
		grow_label.visible = true
		return

	# ===== CHECK DATA =====
	if growth_stage >= crop_data.grow_days.size():
		grow_label.visible = false
		return

	var need_days = crop_data.grow_days[growth_stage]
	var days_left = need_days - current_day
	days_left = max(days_left, 0)

	# ===== HIỂN THỊ 2 DÒNG =====
	grow_label.text = crop_name + "\n" + str(days_left) + "d"

	grow_label.visible = true
# ===============================
# 🔗 AUTO TILE
# ===============================
func get_neighbor_mask():

	var pos = get_grid_pos()
	var tile_size = 16

	var mask = 0

	if FarmManager.get_tile(pos + Vector2(0, -tile_size)):
		mask |= 1

	if FarmManager.get_tile(pos + Vector2(tile_size, 0)):
		mask |= 2

	if FarmManager.get_tile(pos + Vector2(0, tile_size)):
		mask |= 4

	if FarmManager.get_tile(pos + Vector2(-tile_size, 0)):
		mask |= 8

	return mask


# ===============================
# 📦 GRID
# ===============================
func get_grid_pos():

	var tile_size = 16

	# 🔥 FIX OFFSET
	return Vector2(
		floor((global_position.x - 8) / tile_size) * tile_size,
		floor((global_position.y - 8) / tile_size) * tile_size
	)

func to_data() -> Dictionary:

	var p = get_grid_pos()

	return {
		"x": p.x,
		"y": p.y,
		"watered": is_watered,
		"seed": crop_data.id if crop_data != null else "",
		"stage": growth_stage,
		"day": current_day
	}


func apply_data(d: Dictionary):

	is_tilled = true
	is_watered = d.get("watered", false)

	var sid = d.get("seed", "")
	if sid != "":
		var it = ItemDb.items.get(sid, null)
		if it != null:
			has_seed = true
			crop_data = it
			growth_stage = int(d.get("stage", 0))
			current_day = int(d.get("day", 0))

	FarmManager.add_tile(get_grid_pos(), self)
	update_visual()
