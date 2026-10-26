@tool
extends Resource
class_name ItemData

# ===============================
# BASIC
# ===============================
@export var id : String = ""
@export var name : String = ""
@export var icon : Texture2D
@export var description : String = ""

@export var max_stack : int = 99
@export var price : int = 0


# ===============================
# TYPE
# ===============================
enum ItemType {
	CONSUMABLE,
	EQUIPMENT,
	MATERIAL,
	QUEST,
	TOOL,
	SEED   # 🔥 thêm seed type
}
@export var type : ItemType = ItemType.CONSUMABLE


# ===============================
# TOOL TYPE
# ===============================
enum ToolType {
	NONE,
	HOE,
	AXE,
	PICKAXE,
	WATERING_CAN,
	SICKLE
}
@export var tool_type : ToolType = ToolType.NONE
@export_group("Tool Display")
@export var tool_frames : SpriteFrames           # anim riêng của tool: use_up/use_down/use_left/use_right
@export var grip := Vector2(2, 14)
@export var icon_angle := -45.0
@export_group("")

# ===============================
# 🌱 CROP DATA (GỘP LUÔN Ở ĐÂY)
# ===============================
@export var crop_textures : Array[Texture2D] = []   # từng stage
@export var grow_days : Array[int] = []             # [2,4,7]
@export var need_water : bool = true
@export var harvest_item : ItemData                 # item thu hoạch
@export var regrow : bool = false
@export var regrow_days : int = 0


# ===============================
# RARITY
# ===============================
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}
@export var rarity : Rarity = Rarity.COMMON


# ===============================
# TAG
# ===============================
enum ItemTag {
	FOOD,
	SELLABLE,
	QUEST_ITEM,
	SEED
}
@export var tags : Array[ItemTag] = []


# ===============================
# EQUIP
# ===============================
enum EquipSlot {
	NONE,
	WEAPON,
	ARMOR,
	HELMET,
	ACCESSORY
}
@export var equip_slot : EquipSlot = EquipSlot.NONE


# ===============================
# STATS
# ===============================
@export var atk : int = 0
@export var def : int = 0
@export var max_hp : int = 0
@export var max_mp : int = 0


# ===============================
# EFFECTS
# ===============================
@export var effects : Array[Dictionary] = []


# ===============================
# HELPER
# ===============================

func is_stackable() -> bool:
	return max_stack > 1


func is_consumable() -> bool:
	return type == ItemType.CONSUMABLE


func is_equipment() -> bool:
	return type == ItemType.EQUIPMENT


func is_tool() -> bool:
	return type == ItemType.TOOL


# 🔥 FIX SEED LOGIC CHUẨN
func is_seed() -> bool:
	return type == ItemType.SEED and crop_textures.size() > 0


func can_grow() -> bool:
	return grow_days.size() > 0 and crop_textures.size() > 0


func is_food() -> bool:
	return is_consumable() and ItemTag.FOOD in tags


func is_material() -> bool:
	return type == ItemType.MATERIAL


func is_quest() -> bool:
	return ItemTag.QUEST_ITEM in tags


func is_tool_type(t: ToolType) -> bool:
	return is_tool() and tool_type == t


func has_effects() -> bool:
	return effects.size() > 0
