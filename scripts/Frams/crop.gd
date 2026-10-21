extends Node2D

@onready var sprite = $Sprite2D

# ===== DATA =====
var crop : ItemData
var planted_day := 0
var growth_stage := 0


# ===============================
# SETUP
# ===============================
func setup(_crop: ItemData):

	# ❌ không phải seed → không trồng
	if _crop == null or not _crop.is_seed():
		return

	crop = _crop
	planted_day = TimeManager.day
	growth_stage = 0

	# ⚠️ chống crash
	if crop.crop_textures.is_empty():
		return

	sprite.hframes = crop.crop_textures.size()

	update_visual()


# ===============================
# GROW (CALL MỖI NGÀY)
# ===============================
func on_new_day():

	if crop == null:
		return

	# 🌧️ cần nước mà chưa tưới → không grow
	if crop.need_water:
		if not get_parent().has_method("is_watered") or not get_parent().is_watered:
			return

	var day_passed = TimeManager.day - planted_day

	# update stage
	for i in range(crop.grow_days.size()):
		if day_passed >= crop.grow_days[i]:
			growth_stage = i

	update_visual()


# ===============================
# HARVEST CHECK
# ===============================
func can_harvest() -> bool:
	if crop == null:
		return false

	return growth_stage >= crop.grow_days.size() - 1


# ===============================
# HARVEST
# ===============================
func harvest():

	if not can_harvest():
		return null

	var item = crop.harvest_item

	# 🌱 regrow
	if crop.regrow:
		planted_day = TimeManager.day
		growth_stage = crop.grow_days.size() - 2   # quay lại stage trước cuối
	else:
		queue_free() # xoá cây

	return item


# ===============================
# WITHER
# ===============================
func wither():
	growth_stage = -1
	update_visual()


# ===============================
# VISUAL
# ===============================
func update_visual():

	if crop == null:
		return

	if crop.crop_textures.is_empty():
		return

	sprite.hframes = crop.crop_textures.size()

	# 💀 chết
	if growth_stage == -1:
		sprite.frame = sprite.hframes - 1
		return

	sprite.frame = clamp(growth_stage, 0, sprite.hframes - 1)
