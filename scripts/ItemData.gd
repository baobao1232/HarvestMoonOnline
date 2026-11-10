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
# ItemData.gd
enum ToolType { NONE, HOE, AXE, PICKAXE, WATERING_CAN, SICKLE, HAMMER }
@export var tool_type : ToolType = ToolType.NONE
@export_group("Tool Display")
@export_group("Tool Display")
@export var use_anim := ""   # "hoe", "water", "sickle"; để trống = dùng use_<hướng> mặc định
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
# EQUIP LAYER (sheet vẽ lên nhân vật, cùng bố cục với sheet gốc của player)
# ===============================
@export_group("Equip Layer")
@export var layer_idle : Texture2D        # ↔ idle_animation.png
@export var layer_run : Texture2D         # ↔ Run_animation.png
@export var layer_raihat : Texture2D      # ↔ raihatgiong.png
@export var layer_showitem : Texture2D    # ↔ show_item.png
@export var layer_use_hoe : Texture2D     # ↔ use_tool_animation.png
@export var layer_use_sickle : Texture2D  # ↔ use_sickle_animation.png
@export var layer_use_swing : Texture2D   # ↔ use_swing_animation.png
@export var layer_use_water : Texture2D   # ↔ use_water_animation.png
@export_group("")

# tên property → tên file (không đuôi) của sheet gốc trên Player
const LAYER_BASE_NAMES := {
	"layer_idle": "idle_animation",
	"layer_run": "Run_animation",
	"layer_raihat": "raihatgiong",
	"layer_showitem": "show_item",
	"layer_use_hoe": "use_tool_animation",
	"layer_use_sickle": "use_sickle_animation",
	"layer_use_swing": "use_swing_animation",
	"layer_use_water": "use_water_animation",
}


# {tên sheet gốc: texture layer}, chỉ gồm những ô đã kéo ảnh vào
func get_layer_sheets() -> Dictionary:
	var out := {}
	for prop in LAYER_BASE_NAMES:
		var t = get(prop)
		if t != null:
			out[LAYER_BASE_NAMES[prop]] = t
	return out


func has_layer() -> bool:
	return not get_layer_sheets().is_empty()

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
	HELMET,
	ARMOR,
	PANTS,
	GLOVES,
	BOOTS,
	WEAPON,      # chưa có ô UI
	ACCESSORY,   # chưa có ô UI
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
