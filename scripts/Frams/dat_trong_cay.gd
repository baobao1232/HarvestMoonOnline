extends Node2D

@onready var dat = $StaticBody2D/Dat
@onready var dat_da_tuoi = $StaticBody2D/Dat_DaTuoi
@onready var hat_giong = $StaticBody2D/HatGiong
@onready var grow_label = $StaticBody2D/GrowLabel

# ===============================
# STATE (chỉ để hiển thị, server quyết định)
# ===============================
var is_tilled := false
var is_watered := false
var has_seed := false

var crop_data = null
var growth_stage := 0
var current_day := 0

var player = null


func _ready():
	update_visual()


# ===============================
# LABEL: hiện khi người chơi đứng trên ô này
# ===============================
func _process(_delta):

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("local_player")

	if player == null:
		return

	var tile_size = 16

	var player_tile = Vector2(
		floor((player.global_position.x - 8) / tile_size) * tile_size,
		floor((player.global_position.y - 8) / tile_size) * tile_size
	)

	if player_tile == get_grid_pos():
		update_grow_label()
	else:
		grow_label.visible = false


# ===============================
# NHẬN DỮ LIỆU TỪ SERVER
# ===============================
func apply_data(d: Dictionary):

	is_tilled = true
	is_watered = bool(d.get("watered", false))

	var seed_id: String = str(d.get("seed", ""))
	has_seed = seed_id != ""
	crop_data = ItemDb.items.get(seed_id, null) if has_seed else null

	if crop_data == null:
		has_seed = false

	growth_stage = int(d.get("stage", 0))
	current_day = int(d.get("day", 0))

	update_visual()

# ===============================
# VISUAL
# ===============================
func update_visual():

	dat.visible = false
	dat_da_tuoi.visible = false
	hat_giong.visible = false

	if not is_tilled:
		return

	# ===== ĐẤT (autotile) =====
	dat.visible = true

	if dat is AnimatedSprite2D:
		dat.frame = get_neighbor_mask()

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
# LABEL
# ===============================
func update_grow_label():

	if not has_seed or crop_data == null:
		grow_label.visible = false
		return

	var last_stage = crop_data.crop_textures.size() - 1   # stage cuối = hư
	var mature_stage = last_stage - 1                     # stage kế cuối = thu hoạch được
	var crop_name = crop_data.name if "name" in crop_data else "Crop"

	# 💀 HƯ
	if growth_stage >= last_stage:
		grow_label.text = crop_name + "\nĐã hư"
		grow_label.visible = true
		return

	# ✅ TRƯỞNG THÀNH → không đếm ngày nữa
	if growth_stage >= mature_stage:
		grow_label.text = crop_name + "\nCó thể thu hoạch"
		grow_label.visible = true
		return

	# 🌱 ĐANG LỚN → đếm ngày còn lại
	if growth_stage >= crop_data.grow_days.size():
		grow_label.visible = false
		return

	var days_left = max(crop_data.grow_days[growth_stage] - current_day, 0)

	grow_label.text = crop_name + "\n" + str(days_left) + "d"
	grow_label.visible = true

# ===============================
# AUTO TILE
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
# GRID
# ===============================
func get_grid_pos():

	var tile_size = 16

	return Vector2(
		floor((global_position.x - 8) / tile_size) * tile_size,
		floor((global_position.y - 8) / tile_size) * tile_size
	)
