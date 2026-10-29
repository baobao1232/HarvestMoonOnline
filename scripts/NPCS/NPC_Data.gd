extends Resource
class_name NPCData
# =====================================================================
# Đọc 1 file <Tên>.json và trả lời các câu hỏi:
#   - Bây giờ NPC đang ở đâu, làm gì?        -> get_current_entry(ctx)
#   - Nói câu gì?                             -> pick_dialog(ctx, entry)
#   - Tặng quà thì phản ứng ra sao?           -> give_gift(item_id, ctx)
#   - Có heart event nào đang chờ không?      -> find_ready_event(ctx)
#
# ctx (do NpcManager.make_context() tạo) gồm:
#   hour, minute, day, season, season_name, year, total_days,
#   weekday (0 = Chủ nhật), weather ("sunny"/"rain"/"snow"), festival, map
#
# Tình bạn / đã gặp / event đã xem được lưu trong
#   SceneManager.player_data.quests["npc"][<id>]
# nên server đang lưu "quests" thì tự được lưu theo (không cần sửa PHP).
# =====================================================================

const SEASONS := ["SPRING", "SUMMER", "AUTUMN", "WINTER"]
const DEFAULT_PRIORITY := ["festival", "snow", "rain", "sunny"]
const GIFT_ORDER := ["special_loved", "loved", "liked", "disliked", "hated"]

const POINTS_PER_HEART := 50
const MAX_HEARTS := 10

# điểm tình bạn tối thiểu cho từng màu heart (nếu event không ghi required_points)
const HEART_EVENT_POINTS := {
	"black": 1, "purple": 100, "blue": 200,
	"yellow": 300, "green": 400, "orange": 450
}

var json_path := ""

# thang tình bạn riêng cho từng NPC (JSON: "friendship": {...}), mặc định theo const
var points_per_heart := POINTS_PER_HEART
var event_points := HEART_EVENT_POINTS

# ===== dữ liệu từ JSON =====
var id := ""
var npc_name := ""
var profile := {}
var speed := 40.0
var default_map := ""
var portrait_paths := {}
var schedule_rules := {}
var schedule := {}
var overrides := []
var dialog_rules := {}
var dialog := {}
var gifts := {}
var heart_events := []
var other_events := []     # chưa xử lý, giữ lại để mở rộng
var rival_events := []     # chưa xử lý, giữ lại để mở rộng
var interaction := {}

var _portraits := {}
var _fallback := {}        # dùng khi chưa có player_data


# ===============================
# LOAD
# ===============================
func load_json(path: String) -> bool:

	json_path = path

	if not FileAccess.file_exists(path):
		push_error("NPCData: không thấy file " + path)
		return false

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("NPCData: JSON lỗi " + path)
		return false

	return load_dict(parsed)


# đường dẫn bản JSON đóng gói sẵn trong game (dự phòng khi không tải được từ server)
func local_path() -> String:
	return get_script().resource_path.get_basename() + ".json"


# nhận dict đã parse (từ server hoặc từ file)
func load_dict(parsed: Dictionary) -> bool:

	id = str(parsed.get("id", ""))
	npc_name = str(parsed.get("name", id))
	profile = parsed.get("profile", {})

	var mv: Dictionary = parsed.get("movement", {})
	speed = float(mv.get("speed", 40))
	default_map = str(mv.get("default_map", ""))

	portrait_paths = parsed.get("portraits", {})
	schedule_rules = parsed.get("schedule_rules", {})
	schedule = parsed.get("schedule", {})
	overrides = parsed.get("schedule_overrides", [])
	dialog_rules = parsed.get("dialog_rules", {})
	dialog = parsed.get("dialog", {})
	gifts = parsed.get("gifts", {})
	heart_events = parsed.get("heart_events", [])
	other_events = parsed.get("other_events", [])
	rival_events = parsed.get("rival_events", [])
	interaction = parsed.get("interaction", {})

	var fr: Dictionary = parsed.get("friendship", {})
	points_per_heart = int(fr.get("points_per_heart", POINTS_PER_HEART))
	if fr.has("event_points"):
		event_points = fr["event_points"]

	return id != ""


# ===============================
# HELPER THỜI GIAN
# ===============================
static func _mins(e: Dictionary) -> int:
	return int(e.get("hour", 0)) * 60 + int(e.get("minute", 0))


static func _hhmm(s: String) -> int:
	var p := s.split(":")
	return int(p[0]) * 60 + (int(p[1]) if p.size() > 1 else 0)


static func _has_num(arr, n: int) -> bool:
	if not (arr is Array):
		return false
	for x in arr:
		if int(x) == n:
			return true
	return false


# ===============================
# SCHEDULE
# ===============================

# chọn bộ lịch theo schedule_rules.priority (festival > snow > rain > sunny)
func resolve_schedule_key(ctx: Dictionary) -> String:

	var priority: Array = schedule_rules.get("priority", DEFAULT_PRIORITY)

	for key in priority:

		var ok := false

		match str(key):
			"festival": ok = bool(ctx.get("festival", false))
			_: ok = (ctx.weather == str(key))

		var list = schedule.get(key, [])

		if ok and list is Array and not list.is_empty():
			return str(key)

	return str(schedule_rules.get("fallback", "sunny"))


# ghi đè khoảng thời gian của `extra` lên lịch gốc `base`
func _merge(base: Array, extra: Array) -> Array:

	if extra.is_empty():
		return base

	var lo := 99999
	var hi := -1

	for e in extra:
		lo = mini(lo, _mins(e))
		hi = maxi(hi, _mins(e))

	var out := []

	for e in base:
		var m := _mins(e)
		if m < lo or m > hi:
			out.append(e)

	out.append_array(extra)
	return out


func _override_ok(ov: Dictionary, ctx: Dictionary) -> bool:

	if ov.has("weekday") and int(ov["weekday"]) != int(ctx.weekday):
		return false

	if ov.has("weather") and not (ctx.weather in ov["weather"]):
		return false

	return true


# toàn bộ lịch của hôm nay (đã gộp override, đã sắp theo giờ)
func get_entries(ctx: Dictionary) -> Array:

	var key := resolve_schedule_key(ctx)
	var list: Array = (schedule.get(key, []) as Array).duplicate()

	for ov in overrides:
		if _override_ok(ov, ctx):
			list = _merge(list, ov.get("entries", []))

	list.sort_custom(func(a, b): return _mins(a) < _mins(b))

	return list


# mốc lịch đang có hiệu lực ở thời điểm hiện tại
func get_current_entry(ctx: Dictionary) -> Dictionary:

	var list := get_entries(ctx)

	if list.is_empty():
		return {}

	var now := int(ctx.hour) * 60 + int(ctx.minute)

	# trước mốc đầu tiên trong ngày -> vẫn là mốc cuối của hôm trước
	var cur: Dictionary = list[list.size() - 1]

	for e in list:
		if _mins(e) <= now:
			cur = e
		else:
			break

	return cur


func entry_key(e: Dictionary) -> String:
	return "%s_%d_%d_%s_%s" % [id, int(e.get("hour", 0)), int(e.get("minute", 0)),
		str(e.get("map", "")), str(e.get("spot", ""))]


# ===============================
# STATE (lưu trong player_data.quests)
# ===============================
func state() -> Dictionary:

	var all: Dictionary = _fallback
	var pd = SceneManager.player_data

	if pd != null:
		if not pd.quests.has("npc"):
			pd.quests["npc"] = {}
		all = pd.quests["npc"]

	if not all.has(id):
		all[id] = {
			"points": 0, "met": false,
			"talk_day": -1, "gift_day": -1, "gift_count": 0,
			"events": []
		}

	return all[id]


func _save():
	if Server.player_data != null:
		Server._save_remote()


func get_points() -> int:
	return int(state().get("points", 0))


func get_hearts() -> int:
	return mini(floori(float(get_points()) / points_per_heart), MAX_HEARTS)


func add_points(n: int):
	var st := state()
	st["points"] = clampi(get_points() + n, 0, MAX_HEARTS * points_per_heart)


func is_birthday(ctx: Dictionary) -> bool:
	var b: Dictionary = profile.get("birthday", {})
	return str(b.get("season", "")) == str(ctx.season_name) \
		and int(b.get("day", 0)) == int(ctx.day)


# ===============================
# PORTRAIT
# ===============================
func get_portrait(face: String) -> Texture2D:

	if face == "" or not portrait_paths.has(face):
		return null

	if not _portraits.has(face):
		var p: String = portrait_paths[face]
		_portraits[face] = load(p) if ResourceLoader.exists(p) else null

	return _portraits[face]


# ===============================
# DIALOG
# ===============================
func _lines(key) -> Array:
	var v = dialog.get(key)
	return v if v is Array else []


func _place_lines(ctx: Dictionary, entry: Dictionary) -> Array:

	var places = dialog.get("place", {})
	var spot := str(entry.get("spot", ""))

	# spot "counter" -> "shop_counter", map "Beach" -> "beach"
	for k in [spot, "shop_" + spot, str(ctx.map).to_lower()]:
		var v = places.get(k)
		if v is Array and not v.is_empty():
			return v

	return []


func _random_normal() -> Array:

	var keys: Array = interaction.get("talk_cooldown_lines", ["normal"])
	var avail := keys.filter(func(k): return not _lines(k).is_empty())

	if avail.is_empty():
		return []

	return _lines(avail.pick_random())


func _dialog_step(step: String, ctx: Dictionary, entry: Dictionary, talked_today: bool) -> Array:

	match step:

		"birthday":
			if not talked_today and is_birthday(ctx):
				return _lines("birthday")

		"heart_level":
			if not talked_today:
				var hearts := get_hearts()
				for lv in dialog_rules.get("heart_levels", []):
					if hearts >= int(lv):
						var l := _lines("heart%d" % int(lv))
						if not l.is_empty():
							return l

		"rain":    # cả mưa lẫn tuyết
			if ctx.weather == "rain":
				return _lines("rain")
			if ctx.weather == "snow":
				var s := _lines("snow")
				return s if not s.is_empty() else _lines("rain")

		"place":
			return _place_lines(ctx, entry)

		"evening":
			if int(ctx.hour) >= 18:
				return _lines("evening")

		"season":
			return _lines(str(ctx.season_name).to_lower())

		"normal":
			return _random_normal()

	return []


# chọn lời thoại theo dialog_rules.order
func pick_dialog(ctx: Dictionary, entry: Dictionary) -> Array:

	var st := state()

	# lần đầu gặp
	if not bool(st.get("met", false)):
		var intro := _lines(dialog_rules.get("first_meet", "intro"))
		if not intro.is_empty():
			return intro

	# birthday + heart chỉ nói ở lần nói chuyện ĐẦU TIÊN trong ngày
	var talked_today := int(st.get("talk_day", -1)) == int(ctx.total_days)

	for step in dialog_rules.get("order", ["normal"]):
		var lines := _dialog_step(str(step), ctx, entry, talked_today)
		if not lines.is_empty():
			return lines

	return _random_normal()


# gọi sau mỗi lần nói chuyện: đánh dấu đã gặp + cộng điểm lần đầu trong ngày
func register_talk(ctx: Dictionary):

	var st := state()
	st["met"] = true

	if int(st.get("talk_day", -1)) != int(ctx.total_days):
		st["talk_day"] = int(ctx.total_days)
		add_points(int(interaction.get("talk_gain", {}).get("first_time_per_day", 0)))

	_save()


# [{text, face, speaker?}] -> {texts, portraits} cho DialogManager.show()
func to_dialog(lines: Array, with_speaker := false) -> Dictionary:

	var texts := []
	var faces := []

	for l in lines:

		if not (l is Dictionary) or not l.has("text"):
			continue

		var t := str(l["text"])
		var sp := str(l.get("speaker", ""))

		if with_speaker and sp != "" and sp != "Narration":
			t = sp + ": " + t

		texts.append(t)

		# lời của người khác (Jeff, Sasha...) thì không dùng ảnh của NPC này
		if sp == "" or sp == npc_name:
			faces.append(get_portrait(str(l.get("face", ""))))
		else:
			faces.append(null)

	return {"texts": texts, "portraits": faces}


# ===============================
# GIFT
# ===============================
func gift_tier(item_id: String) -> String:

	var lists: Dictionary = gifts.get("lists", {})

	for t in GIFT_ORDER:
		if item_id in lists.get(t, []):
			return t

	return "neutral"


# trả về {ok, tier, points, lines}
func give_gift(item_id: String, ctx: Dictionary) -> Dictionary:

	var st := state()
	var reactions: Dictionary = gifts.get("reactions", {})
	var limit := int(gifts.get("limits", {}).get("per_day", 1))
	var today := int(ctx.total_days)

	if int(st.get("gift_day", -1)) == today and int(st.get("gift_count", 0)) >= limit:
		return {"ok": false, "tier": "already_gifted", "points": 0,
			"lines": reactions.get("already_gifted", [])}

	var tier := gift_tier(item_id)
	var table: Dictionary = gifts.get("points", {})
	var pts := int(table.get(tier, 0))

	if pts > 0 and is_birthday(ctx):
		pts *= int(table.get("birthday_multiplier", 1))

	if int(st.get("gift_day", -1)) != today:
		st["gift_day"] = today
		st["gift_count"] = 0

	st["gift_count"] = int(st["gift_count"]) + 1
	st["met"] = true
	add_points(pts)
	_save()

	return {"ok": true, "tier": tier, "points": pts,
		"lines": reactions.get(tier, [])}


# ===============================
# HEART EVENT
# ===============================
func has_seen(event_id: String) -> bool:
	return event_id in state().get("events", [])


func _event_ready(ev: Dictionary, ctx: Dictionary) -> bool:

	# event chưa có lời thoại thì bỏ qua (tránh trigger rồi không hiện gì)
	var ev_lines = ev.get("lines", [])
	if not (ev_lines is Array) or ev_lines.is_empty():
		return false

	if has_seen(str(ev.get("id", ""))):
		return false

	if str(ev.get("map", "")) != str(ctx.map):
		return false

	if ev.has("weekdays") and not _has_num(ev["weekdays"], int(ctx.weekday)):
		return false

	if ev.has("time"):
		var now := int(ctx.hour) * 60 + int(ctx.minute)
		if now < _hhmm(str(ev["time"]["from"])) or now > _hhmm(str(ev["time"]["to"])):
			return false

	var w = ev.get("weather", "any")
	if w is Array and not (ctx.weather in w):
		return false

	var need := int(ev.get("required_points",
		event_points.get(str(ev.get("heart", "")), 0)))
	if get_points() < need:
		return false

	for r in ev.get("requires", []):
		var req := str(r)
		if req.begins_with("event:"):
			if not has_seen(req.substr(6)):
				return false
		elif req == "inventory_free_slot":
			if InventoryManager.is_full():
				return false

	return true


func find_ready_event(ctx: Dictionary) -> Dictionary:

	if not bool(state().get("met", false)):
		return {}

	for ev in heart_events:
		if _event_ready(ev, ctx):
			return ev

	return {}


# áp dụng lựa chọn: cộng/trừ tình bạn, đánh dấu đã xem.
# trả về choice để nơi gọi tự xử lý reward / energy / teleport.
func complete_event(event_id: String, choice_idx := 0) -> Dictionary:

	var st := state()

	if not (event_id in st["events"]):
		st["events"].append(event_id)

	var choice := {}

	for ev in heart_events:
		if str(ev.get("id", "")) == event_id:
			var choices: Array = ev.get("choices", [])
			if choice_idx >= 0 and choice_idx < choices.size():
				choice = choices[choice_idx]
			break

	var eff: Dictionary = choice.get("effect", {})
	add_points(int(eff.get("friendship", eff.get("affection", 0))))
	_save()

	return choice
