extends Node

signal time_changed(hour, minute)
signal day_changed(day, season, year)
signal time_synced

const SEASONS = ["SPRING", "SUMMER", "AUTUMN", "WINTER"]

const DAYS_PER_SEASON := 28
const REAL_SECONDS_PER_GAME_MINUTE := 15.0   # 1 mùa = 28 ngày = đúng 7 ngày thực
const START_HOUR := 6
const RESYNC_INTERVAL := 600.0

# ===== DEV =====
var dev_mode := 0        # 0 = bình thường | 1 = ép 7h | 2 = ép 20h
var debug_speed := 1.0   # test: đặt 100 để thời gian chạy nhanh (chỉ local)

# ===== SYNC =====
var server_epoch := 0.0
var clock_offset := 0.0  # giờ server - giờ máy mình
var synced := false
var _syncing := false

# ===== TIME =====
var minute := 0
var hour := 6
var day := 1             # ngày trong mùa (1-28)
var season := 0
var year := 1
var total_days := 0      # tổng số ngày kể từ mốc (dùng cho thời tiết, lưu farm)

var last_minute := -1
var last_day := -1


func _ready():
	await get_tree().process_frame   # đợi các autoload khác (Server) sẵn sàng
	sync_from_server()


# ===============================
# SYNC VỚI SERVER
# ===============================
func server_now() -> float:
	return Time.get_unix_time_from_system() + clock_offset


func sync_from_server():

	if _syncing:
		return
	_syncing = true

	var t0 := Time.get_unix_time_from_system()

	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)

	req.request_completed.connect(func(result, _code, _headers, body):
		req.queue_free()
		_syncing = false

		var json = JSON.parse_string(body.get_string_from_utf8())

		if result != HTTPRequest.RESULT_SUCCESS \
		or typeof(json) != TYPE_DICTIONARY \
		or not json.get("ok", false):
			Dbg.p("⏰ Sync time lỗi, thử lại sau 5s")
			get_tree().create_timer(5.0).timeout.connect(sync_from_server)
			return

		# bù trễ mạng: giả sử gói đi và về mất thời gian bằng nhau
		var t1 := Time.get_unix_time_from_system()
		var rtt := t1 - t0

		server_epoch = float(json["epoch"])
		clock_offset = float(json["now"]) + rtt * 0.5 - t1

		var first := not synced
		synced = true

		Dbg.p("⏰ TIME SYNCED | offset:", clock_offset)

		if first:
			time_synced.emit()

		# đồng bộ lại định kỳ cho khỏi lệch đồng hồ
		get_tree().create_timer(RESYNC_INTERVAL).timeout.connect(sync_from_server)
	)

	if req.request(Server.API_URL + "/time.php") != OK:
		req.queue_free()
		_syncing = false
		get_tree().create_timer(5.0).timeout.connect(sync_from_server)


# ===============================
# LOOP
# ===============================
func _process(_delta):

	# ===== DEV MODE =====
	if dev_mode != 0:
		hour = 7 if dev_mode == 1 else 20
		minute = 0
		emit_signal("time_changed", hour, minute)
		return

	if not synced:
		return

	var elapsed := maxf(0.0, server_now() - server_epoch) * debug_speed
	update_time(int(elapsed / REAL_SECONDS_PER_GAME_MINUTE))


@warning_ignore("integer_division")
func update_time(total_minutes: int):

	minute = total_minutes % 60
	var total_hours := total_minutes / 60

	hour = (total_hours + START_HOUR) % 24

	total_days = total_hours / 24
	day = (total_days % DAYS_PER_SEASON) + 1
	season = (total_days / DAYS_PER_SEASON) % 4
	year = (total_days / (DAYS_PER_SEASON * 4)) + 1

	# ===== MỖI PHÚT GAME =====
	if minute != last_minute:
		last_minute = minute
		emit_signal("time_changed", hour, minute)

	# ===== QUA NGÀY (6:00 sáng) =====
	if day != last_day:
		var first_tick := (last_day == -1)
		last_day = day

		# lần đầu chỉ ghi nhớ ngày hiện tại, không tính là "qua ngày mới"
		if not first_tick:
			emit_signal("day_changed", day, season, year)


func get_time_string():
	return "%02d:%02d" % [hour, minute]


func get_date_string():
	return "Day %d - %s - Year %d" % [day, SEASONS[season], year]
