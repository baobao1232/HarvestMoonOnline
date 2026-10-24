class_name PlayerData

const MAX_SLOT := 20
const HOTBAR_SIZE := 8   # 🔥 thêm

# ===== identity =====
var id : int = 0
var name : String = ""

# ===== position =====
var map : String = ""
var spawn : String = ""
var pos : Vector2 = Vector2.ZERO

# ===== economy =====
var gold : int = 0

# ===== stamina =====
var energy : int = 100
var max_energy : int = 100

# ===== level system =====
var level : int = 1
var exp : int = 0
var exp_max : int = 100

# ===== data =====
var inventory : Array = []
var farm : Dictionary = {}
var quests : Dictionary = {}

# 🔥 HOTBAR
var hotbar : Array = []
var is_newbie := true;

# ================================
# INIT
# ================================
func _init():

	inventory.resize(MAX_SLOT)

	# 🔥 INIT HOTBAR
	hotbar.resize(HOTBAR_SIZE)

	for i in range(HOTBAR_SIZE):
		hotbar[i] = null


# ================================
# SAVE
# ================================
func to_dict():

	var inv_save := []

	for slot in inventory:

		if slot == null:
			inv_save.append(null)
			continue

		var item = slot.get("item", null)

		# 🔥 FIX: nếu item là string → convert lại
		if typeof(item) == TYPE_STRING:
			item = ItemDb.items.get(item, null)

		if item == null:
			Dbg.p("❌ SAVE FAIL SLOT:", slot)
			inv_save.append(null)
			continue

		inv_save.append({
			"id": item.id,
			"amount": slot.get("amount", 1)
		})


	var hotbar_save := []

	for slot in hotbar:

		if slot == null:
			hotbar_save.append(null)
			continue

		var item = slot.get("item", null)

		if typeof(item) == TYPE_STRING:
			item = ItemDb.items.get(item, null)

		if item == null:
			hotbar_save.append(null)
			continue

		hotbar_save.append({
			"id": item.id,
			"amount": slot.get("amount", 1)
		})


	return {
		"id": id,
		"name": name,
		"map": map,
		"spawn": spawn,
		"pos_x": pos.x,
		"pos_y": pos.y,
		"gold": gold,
		"energy": energy,
		"is_newbie": is_newbie,
		"max_energy": max_energy,
		"level": level,
		"exp": exp,
		"exp_max": exp_max,
		"inventory": inv_save,
		"hotbar": hotbar_save,
		"farm": farm,
		"quests": quests
	}
# LOAD
# ================================
func from_dict(data: Dictionary):

	# ===== BASIC =====
	id = data.get("id", 0)
	name = data.get("name", "")

	map = data.get("map", "")
	spawn = data.get("spawn", "")

	pos = Vector2(
		data.get("pos_x", 0),
		data.get("pos_y", 0)
	)

	gold = data.get("gold", 0)

	energy = data.get("energy", 100)
	max_energy = data.get("max_energy", 100)

	level = data.get("level", 1)
	exp = data.get("exp", 0)
	exp_max = data.get("exp_max", 100)
	is_newbie = data.get("is_newbie", true)


	# =====================================
	# 🔥 INVENTORY (FIX FULL)
	# =====================================
	var inv = data.get("inventory", [])
	inventory = []

	if inv is Array:

		for slot in inv:

			if slot == null:
				inventory.append(null)
				continue

			# ===== CASE 1: đúng format save {id, amount}
			if slot is Dictionary and slot.has("id"):

				var item_id = slot["id"]
				var item = ItemDb.items.get(item_id, null)

				if item == null:
					Dbg.p("❌ LOAD FAIL (ID):", item_id)
					inventory.append(null)
					continue

				inventory.append({
					"item": item,
					"amount": slot.get("amount", 1)
				})
				continue


			# ===== CASE 2: data cũ bị string resource
			if slot is Dictionary and slot.has("item"):

				var raw = slot["item"]

				var item = null

				# 🔥 nếu là string → convert
				if typeof(raw) == TYPE_STRING:
					item = ItemDb.items.get(raw, null)

				# 🔥 nếu là object → dùng luôn
				elif raw != null:
					item = raw

				if item == null:
					Dbg.p("❌ LOAD FAIL (ITEM):", raw)
					inventory.append(null)
					continue

				inventory.append({
					"item": item,
					"amount": slot.get("amount", 1)
				})
				continue


			# ===== CASE 3: data rác
			Dbg.p("⚠ INVALID SLOT:", slot)
			inventory.append(null)

	else:
		inventory = []

	# ===== FIX SIZE =====
	if inventory.size() < MAX_SLOT:
		inventory.resize(MAX_SLOT)
	elif inventory.size() > MAX_SLOT:
		inventory = inventory.slice(0, MAX_SLOT)


	# =====================================
	# 🔥 HOTBAR (FIX FULL)
	# =====================================
	var hb = data.get("hotbar", [])
	hotbar = []

	if hb is Array:

		for slot in hb:

			if slot == null:
				hotbar.append(null)
				continue

			if slot is Dictionary and slot.has("id"):

				var item = ItemDb.items.get(slot["id"], null)

				if item == null:
					Dbg.p("❌ HOTBAR FAIL:", slot["id"])
					hotbar.append(null)
					continue

				hotbar.append({
					"item": item,
					"amount": slot.get("amount", 1)
				})
			else:
				hotbar.append(null)

	else:
		hotbar = []

	# ===== FIX SIZE HOTBAR =====
	if hotbar.size() < HOTBAR_SIZE:
		hotbar.resize(HOTBAR_SIZE)
	elif hotbar.size() > HOTBAR_SIZE:
		hotbar = hotbar.slice(0, HOTBAR_SIZE)


	# =====================================
	# DATA KHÁC
	# =====================================
	farm = data.get("farm", {})
	quests = data.get("quests", {})


	Dbg.p("✔ LOAD DONE | INV:", inventory)
	Dbg.p("✔ LOAD DONE | HOTBAR:", hotbar)
