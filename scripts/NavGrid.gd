class_name NavGrid
extends RefCounted
# Lưới đi lại tự dựng từ collision của map (chỉ tính StaticBody2D, layer 1).

const CELL := 8.0
const PROBE_SIZE := Vector2(12, 8)   # to hơn collider NPC (11x5) một chút để chừa lề
const ROWS_PER_FRAME := 6            # quét dần, không giật khi vào map
const LOOKAHEAD := 24                # làm mượt: nhìn trước tối đa bao nhiêu ô

var origin := Vector2.ZERO
var cols := 0
var rows := 0
var astar := AStarGrid2D.new()
var is_ready := false


# owner: node bất kỳ của map (dùng để lấy world + kiểm tra map còn sống)
func build(owner: Node2D, rect: Rect2) -> void:

	if rect.size == Vector2.ZERO:
		return

	var tree := owner.get_tree()
	var world: World2D = owner.get_world_2d()

	origin = rect.position
	cols = int(ceil(rect.size.x / CELL))
	rows = int(ceil(rect.size.y / CELL))

	astar.region = Rect2i(0, 0, cols, rows)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

	# đợi để body của map mới được đăng ký vào physics
	await tree.physics_frame
	await tree.physics_frame
	if not is_instance_valid(owner):
		return

	var probe := RectangleShape2D.new()
	probe.size = PROBE_SIZE

	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = probe
	q.collision_mask = 1               # layer 1 = tường/nhà/cây; đất trồng (layer 2) không chặn
	q.collide_with_bodies = true
	q.collide_with_areas = false

	var space := world.direct_space_state
	var solid_count := 0

	for y in rows:
		for x in cols:
			q.transform = Transform2D(0.0, cell_center(Vector2i(x, y)))
			for hit in space.intersect_shape(q, 8):
				# CharacterBody2D (player, NPC, thú) không tính là tường
				if hit.collider is StaticBody2D:
					astar.set_point_solid(Vector2i(x, y), true)
					solid_count += 1
					break

		if y % ROWS_PER_FRAME == ROWS_PER_FRAME - 1:
			await tree.physics_frame
			if not is_instance_valid(owner):
				return

	is_ready = true
	Dbg.p("NavGrid:", cols, "x", rows, "| tường:", solid_count)


# ===============================
# TOẠ ĐỘ
# ===============================
func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor((p.x - origin.x) / CELL)), 0, cols - 1),
		clampi(int(floor((p.y - origin.y) / CELL)), 0, rows - 1)
	)


func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


# ô trống gần nhất (tìm theo vòng tròn mở rộng dần)
func snap_cell(c: Vector2i, max_r := 40) -> Vector2i:

	if not astar.is_point_solid(c):
		return c

	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if not astar.is_in_boundsv(n) or astar.is_point_solid(n):
					continue
				var d := float(dx * dx + dy * dy)
				if d < best_d:
					best_d = d
					best = n
		if best.x >= 0:
			return best

	return c


# kéo điểm ra khỏi tường (điểm đã đi được thì giữ nguyên)
func snap(p: Vector2) -> Vector2:
	if not is_ready:
		return p
	var c := cell_of(p)
	if not astar.is_point_solid(c):
		return p
	return cell_center(snap_cell(c))


# ===============================
# ĐƯỜNG ĐI: [a, ...các điểm rẽ..., b]
# ===============================
func route(a: Vector2, b: Vector2) -> PackedVector2Array:

	var out := PackedVector2Array([a])

	if not is_ready:
		out.append(b)
		return out

	var ids := astar.get_id_path(snap_cell(cell_of(a)), snap_cell(cell_of(b)))

	if ids.is_empty():
		out.append(b)       # 2 vùng không nối nhau -> đi thẳng như cũ
		return out

	ids = _smooth(ids)

	for i in range(1, ids.size()):
		out.append(cell_center(ids[i]))

	out.append(b)
	return out


# bỏ bớt điểm thừa: nếu nhìn thẳng tới điểm xa hơn được thì đi thẳng
func _smooth(ids: Array[Vector2i]) -> Array[Vector2i]:

	if ids.size() <= 2:
		return ids

	var out: Array[Vector2i] = [ids[0]]
	var i := 0

	while i < ids.size() - 1:
		var j := mini(i + LOOKAHEAD, ids.size() - 1)
		while j > i + 1 and not _los(ids[i], ids[j]):
			j -= 1
		out.append(ids[j])
		i = j

	return out


# đường thẳng giữa 2 ô có bị tường chắn không (Bresenham, không cắt góc)
func _los(a: Vector2i, b: Vector2i) -> bool:

	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy

	for _i in dx - dy + 2:

		if astar.is_point_solid(Vector2i(x, y)):
			return false

		if x == b.x and y == b.y:
			return true

		var e2 := 2 * err
		var nx := x
		var ny := y

		if e2 >= dy:
			err += dy
			nx += sx
		if e2 <= dx:
			err += dx
			ny += sy

		# đi chéo thì 2 ô kề góc cũng phải trống
		if nx != x and ny != y:
			if astar.is_point_solid(Vector2i(nx, y)) or astar.is_point_solid(Vector2i(x, ny)):
				return false

		x = nx
		y = ny

	return false
