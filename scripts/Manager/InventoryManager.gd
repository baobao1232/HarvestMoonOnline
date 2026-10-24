extends Node

var current_player : PlayerData = null
var slots : Array = []

var max_slots := 20


# ===============================
# SET PLAYER
# ===============================
func set_player(player: PlayerData):

	current_player = player

	# ===== INIT INVENTORY =====
	if player.inventory == null:
		player.inventory = []

	if player.inventory.size() < max_slots:
		player.inventory.resize(max_slots)

	# ===== CONVERT SAVE → RUNTIME =====
	for i in range(player.inventory.size()):

		var slot = player.inventory[i]

		if slot == null:
			continue

		# 🔥 CASE 1: đã đúng format runtime
		if slot.has("item"):

			# ⚠️ nhưng item có thể bị null (bug sau load)
			if slot["item"] == null:
				player.inventory[i] = null
				continue

			# ⚠️ nếu item bị biến thành string (bug m đang gặp)
			if typeof(slot["item"]) == TYPE_STRING:

				var item = ItemDb.items.get(slot["item"], null)

				if item == null:
					Dbg.p("❌ ITEM NOT FOUND (STRING):", slot["item"])
					player.inventory[i] = null
					continue

				slot["item"] = item

			continue


		# 🔥 CASE 2: save dạng {id, amount}
		if slot.has("id"):

			var item_id = slot["id"]
			var item = ItemDb.items.get(item_id, null)

			if item == null:
				Dbg.p("❌ ITEM NOT FOUND:", item_id)
				player.inventory[i] = null
				continue

			player.inventory[i] = {
				"item": item,
				"amount": slot.get("amount", 1)
			}

		else:
			# 🔥 dữ liệu rác → xoá
			Dbg.p("⚠ INVALID SLOT:", slot)
			player.inventory[i] = null


	slots = player.inventory

	Dbg.p("✔ INVENTORY LOADED:", slots)

# ===============================
# ADD ITEM (STACK + SAFE)
# ===============================
func add_item(item: ItemData, amount := 1) -> bool:

	if current_player == null:
		push_error("No player set in InventoryManager")
		return false

	if item == null or amount <= 0:
		return false

	var remain := amount

	# ===== STACK FIRST =====
	for i in range(slots.size()):

		var slot = slots[i]

		if slot != null and slot["item"].id == item.id:

			var current = slot["amount"]
			var max_stack = item.max_stack

			var space = max_stack - current
			if space <= 0:
				continue

			var add = min(space, remain)

			slot["amount"] += add
			remain -= add

			if remain <= 0:
				return true


	# ===== NEW SLOT =====
	for i in range(slots.size()):

		if slots[i] == null:

			var add = min(item.max_stack, remain)

			slots[i] = {
				"item": item,
				"amount": add
			}

			remain -= add

			if remain <= 0:
				return true


	# ===== FAIL =====
	return false


# ===============================
# CAN ADD ITEM (CHUẨN STACK)
# ===============================
func can_add_item(item: ItemData, amount := 1) -> bool:

	if item == null:
		return false

	var space_total := 0

	for slot in slots:

		if slot == null:
			space_total += item.max_stack

		elif slot["item"].id == item.id:
			space_total += item.max_stack - slot["amount"]

	return space_total >= amount


# ===============================
# REMOVE ITEM (BY INDEX)
# ===============================
func remove_item(index: int, amount := 1):

	if index < 0 or index >= slots.size():
		return

	var data = slots[index]
	if data == null:
		return

	data["amount"] -= amount

	if data["amount"] <= 0:
		slots[index] = null


# ===============================
# REMOVE BY ITEM (STACK AWARE)
# ===============================
func remove_item_by_type(item: ItemData, amount := 1) -> bool:

	var remain := amount

	for i in range(slots.size()):

		var slot = slots[i]
		if slot == null:
			continue

		if slot["item"].id == item.id:

			var take = min(slot["amount"], remain)

			slot["amount"] -= take
			remain -= take

			if slot["amount"] <= 0:
				slots[i] = null

			if remain <= 0:
				return true

	return false


# ===============================
# DROP ITEM
# ===============================
func drop_item(index: int, amount := 1):

	if index < 0 or index >= slots.size():
		return null

	var data = slots[index]
	if data == null:
		return null

	var item = data["item"]
	var drop_amount = min(amount, data["amount"])

	remove_item(index, drop_amount)

	return {
		"item": item,
		"amount": drop_amount
	}


# ===============================
# CHECK FULL (REAL)
# ===============================
func is_full() -> bool:

	for slot in slots:

		if slot == null:
			return false

		# còn stack được → chưa full
		if slot["amount"] < slot["item"].max_stack:
			return false

	return true
