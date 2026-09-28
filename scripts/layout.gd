extends RefCounted
## Room/corridor topology adapted from the original game's LevelGen.ts.
## Coordinates are one-metre tiles; visible geometry is supplied by Temple.
const DIRS = [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
const TARGET_MINUTES = [3,5,5,8,8]
# Hallway width and room size range, in tiles.
const CORRIDOR = 5
const ROOM_MIN = 8
const ROOM_MAX = 15
var cells: Dictionary = {}
var rooms: Array[Rect2i] = []
var links: Array[Vector2i] = []
var start = Vector2i.ZERO
var exit_cell = Vector2i.ZERO
# The ascent stair's footprint and climbing direction. It climbs into a solid
# wall, so its top step meets the top of that wall. Its cells are removed from
# `cells`; exit_cell is the floor tile at its foot.
var stairs = Rect2i()
var stairs_dir = Vector2i.UP
const STAIR_WIDTH = 2
const STAIR_DEPTH = 4
var size = 50
var court = Rect2i()
var court_obstacle = Rect2i()
var terrace: Array[Rect2i] = []
var terrace_doors: Array[Rect2i] = []
var rng_state = 0

static func floor_seed(run_seed: int, floor_number: int) -> int:
	var h = ((run_seed*0x27d4eb2d) ^ (floor_number*0x165667b1)) & 0xffffffff
	h = ((h ^ (h >> 15))*0x85ebca6b) & 0xffffffff
	h = ((h ^ (h >> 13))*0xc2b2ae35) & 0xffffffff
	return (h ^ (h >> 16)) & 0xffffffff

func random() -> float:
	rng_state = (rng_state+0x6d2b79f5) & 0xffffffff
	var t = ((rng_state ^ (rng_state >> 15))*(1 | rng_state)) & 0xffffffff
	t = ((t+(((t ^ (t >> 7))*(61 | t)) & 0xffffffff)) ^ t) & 0xffffffff
	return float((t ^ (t >> 14)) & 0xffffffff)/4294967296.0

func integer(low: int, high: int) -> int:
	return low+floori(random()*(high-low+1))

func center(room: Rect2i) -> Vector2i:
	return room.position+Vector2i(room.size.x/2,room.size.y/2)

func carve(rect: Rect2i) -> void:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x): cells[Vector2i(x,y)] = true

func horizontal(a: Vector2i, b: Vector2i) -> void:
	carve(Rect2i(mini(a.x,b.x),a.y,absi(a.x-b.x)+1,CORRIDOR))

func vertical(a: Vector2i, b: Vector2i) -> void:
	carve(Rect2i(a.x,mini(a.y,b.y),CORRIDOR,absi(a.y-b.y)+1))

func connect_rooms(a: Vector2i, b: Vector2i) -> void:
	if court.has_area():
		# Dig around the reserved court; only its two authored doors cross it.
		var frontier: Array[Vector2i] = [a]
		var parents = {a:a}
		var directions = DIRS if random()<.5 else [Vector2i.DOWN,Vector2i.UP,Vector2i.RIGHT,Vector2i.LEFT]
		var head = 0
		while head<frontier.size() and not parents.has(b):
			var p = frontier[head]
			head += 1
			for d in directions:
				var next: Vector2i = p+d
				if next.x<2 or next.y<2 or next.x+CORRIDOR>size-2 or next.y+CORRIDOR>size-2: continue
				if court.grow(1).intersects(Rect2i(next,Vector2i(CORRIDOR,CORRIDOR))) or parents.has(next): continue
				parents[next] = p
				frontier.append(next)
		assert(parents.has(b),"Court bypass must connect")
		var cursor = b
		while true:
			carve(Rect2i(cursor,Vector2i(CORRIDOR,CORRIDOR)))
			if cursor==a: break
			cursor = parents[cursor]
	elif random()<.5:
		horizontal(a,b)
		vertical(Vector2i(b.x,a.y),b)
	else:
		vertical(a,b)
		horizontal(Vector2i(a.x,b.y),b)

func generate(run_seed: int, floor_index: int) -> void:
	cells.clear(); rooms.clear(); links.clear(); terrace.clear(); terrace_doors.clear()
	court = Rect2i(); court_obstacle = Rect2i(); stairs = Rect2i()
	rng_state = floor_seed(run_seed,floor_index+1)
	if floor_index==5:
		size = 30
		rooms.append(Rect2i(1,1,26,18))
		carve(rooms[0])
		start = Vector2i(14,17)
		exit_cell = Vector2i(14,3)
		return
	# Larger rooms and hallways need proportionally more floor area.
	size = roundi((44+TARGET_MINUTES[floor_index]*6)*1.2)
	if floor_index==2: court = Rect2i((size-28)/2,(size-15)/2,28,15)
	for attempt in 40+TARGET_MINUTES[floor_index]*8:
		var w = integer(ROOM_MIN,ROOM_MAX)
		var h = integer(ROOM_MIN,ROOM_MAX)
		var room = Rect2i(integer(2,size-w-3),integer(2,size-h-3),w,h)
		if court.has_area() and court.grow(5).intersects(room): continue
		var overlaps = false
		for other in rooms:
			if other.grow(3).intersects(room): overlaps = true; break
		if not overlaps: rooms.append(room)
	# Deterministic emergency fallback for pathological room rejection, never a
	# disconnected/empty floor. Normal original-sized seeds produce many rooms.
	if rooms.size()<2:
		rooms = [Rect2i(2,2,ROOM_MIN,ROOM_MIN),Rect2i(size-ROOM_MIN-4,size-ROOM_MIN-4,ROOM_MIN,ROOM_MIN)]
	for room in rooms: carve(room)
	for i in range(1,rooms.size()):
		connect_rooms(center(rooms[i-1]),center(rooms[i]))
		links.append(Vector2i(i-1,i))
	for i in maxi(1,rooms.size()/4):
		var a = integer(0,rooms.size()-1)
		var b = integer(0,rooms.size()-1)
		if a!=b:
			connect_rooms(center(rooms[a]),center(rooms[b]))
			links.append(Vector2i(a,b))
	start = center(rooms[0])
	var distance = -1.0
	for room in rooms:
		var at = center(room)
		if at.distance_squared_to(start)>distance:
			distance = at.distance_squared_to(start)
			exit_cell = at
	if court.has_area():
		carve(court)
		var door_y = court.position.y+(court.size.y-CORRIDOR)/2
		for side in 2:
			var outside = Vector2i(court.position.x-CORRIDOR-1 if side==0 else court.end.x+1,door_y)
			var nearest = Vector2i.ZERO
			var best = INF
			for room in rooms:
				var c = center(room)
				var d = absi(c.x-outside.x)+absi(c.y-outside.y)
				if d<best: best=d; nearest=c
			connect_rooms(outside,nearest)
			carve(Rect2i(court.position.x-1 if side==0 else court.end.x,door_y,1,CORRIDOR))
		court_obstacle = Rect2i(court.position+Vector2i((court.size.x-2)/2,(court.size.y-2)/2),Vector2i(2,2))
		for y in range(court_obstacle.position.y,court_obstacle.end.y):
			for x in range(court_obstacle.position.x,court_obstacle.end.x): cells.erase(Vector2i(x,y))
		rooms.append(court)
	if floor_index in [3,4]: add_terrace(floor_index==4)
	place_stairs()

func is_open(cell: Vector2i) -> bool:
	return cells.has(cell) or stairs.has_point(cell)

# The world point at the middle of the stair's foot.
func exit_position() -> Vector3:
	if not stairs.has_area(): return to_world(exit_cell)
	var side = Vector2i(stairs_dir.y,stairs_dir.x).abs()
	return to_world(exit_cell)+Vector3(side.x,0,side.y)*.5

func stair_candidate(room: Rect2i, dir: Vector2i, offset: int) -> Dictionary:
	# Footprint against the room edge that `dir` climbs toward.
	var rect: Rect2i
	if dir==Vector2i.UP: rect = Rect2i(room.position.x+offset,room.position.y,STAIR_WIDTH,STAIR_DEPTH)
	elif dir==Vector2i.DOWN: rect = Rect2i(room.position.x+offset,room.end.y-STAIR_DEPTH,STAIR_WIDTH,STAIR_DEPTH)
	elif dir==Vector2i.LEFT: rect = Rect2i(room.position.x,room.position.y+offset,STAIR_DEPTH,STAIR_WIDTH)
	else: rect = Rect2i(room.end.x-STAIR_DEPTH,room.position.y+offset,STAIR_DEPTH,STAIR_WIDTH)
	var side = Vector2i(absi(dir.y),absi(dir.x))
	var top = rect.position if dir in [Vector2i.UP,Vector2i.LEFT] else rect.end-Vector2i.ONE-side
	var foot = top-dir*STAIR_DEPTH
	var score = 0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if not cells.has(Vector2i(x,y)): return {}
	for i in range(-1,STAIR_WIDTH+1):
		var behind = top+dir+side*i
		var front = foot+side*i
		if i>=0 and i<STAIR_WIDTH:
			# A continuous wall behind the top, and open floor at the foot.
			if cells.has(behind) or not cells.has(front): return {}
		elif cells.has(behind): score -= 4
	# The camera looks toward -X/-Z, so walls on those sides face the player.
	if dir in [Vector2i.UP,Vector2i.LEFT]: score += 10
	var span = room.size.x if side.x==1 else room.size.y
	score -= absi(offset*2+STAIR_WIDTH-span)
	# Leave room to walk up to the foot rather than filling a shallow room.
	var depth = room.size.y if side.x==1 else room.size.x
	score -= 3*maxi(0,STAIR_DEPTH+3-depth)
	return {"rect":rect,"dir":dir,"foot":foot,"score":score}

func stays_connected(rect: Rect2i) -> bool:
	var first = start
	var queue: Array[Vector2i] = [first]
	var seen = {first:true}
	var open = cells.size()-rect.get_area()
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for d in DIRS:
			var next: Vector2i = cell+d
			if cells.has(next) and not rect.has_point(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size()==open

func place_stairs() -> void:
	# Farthest rooms first, so the ascent stays at the far end of the floor.
	var order: Array = []
	for room in rooms:
		if room==court or room==rooms[0]: continue
		order.append(room)
	order.sort_custom(func(a,b): return center(a).distance_squared_to(start)>center(b).distance_squared_to(start))
	for room in order:
		var best = {}
		for dir in [Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]:
			var span = room.size.x if dir.y!=0 else room.size.y
			var depth = room.size.y if dir.y!=0 else room.size.x
			if depth<=STAIR_DEPTH: continue
			for offset in range(0,span-STAIR_WIDTH+1):
				var option = stair_candidate(room,dir,offset)
				if option.is_empty() or (not best.is_empty() and option.score<=best.score): continue
				if not stays_connected(option.rect): continue
				best = option
		if best.is_empty(): continue
		stairs = best.rect
		stairs_dir = best.dir
		exit_cell = best.foot
		for y in range(stairs.position.y,stairs.end.y):
			for x in range(stairs.position.x,stairs.end.x): cells.erase(Vector2i(x,y))
		return

func add_terrace(east: bool) -> void:
	# Five-tile galleries around north+west, mirrored to north+east on floor 5.
	# Scenery beyond the galleries is rendered separately from walkable tiles.
	var side_x = size if east else -5
	terrace = [Rect2i(side_x,-5,5,size+5),Rect2i(0,-5,size,5)]
	for strip in terrace: carve(strip)
	for side in 2:
		for fraction in [.3,.7]:
			var along = floori(size*fraction)
			var door = Rect2i(size-1 if east else 0,along,1,CORRIDOR) if side==0 else Rect2i(along,0,CORRIDOR,1)
			terrace_doors.append(door)
			var target = start
			var best = INF
			for room in rooms:
				var c = center(room)
				var d = absi(c.x-door.position.x)+absi(c.y-door.position.y)
				if d<best: best=d; target=c
			if side==0:
				horizontal(door.position,target)
				carve(Rect2i(target.x,mini(door.position.y,target.y),CORRIDOR,absi(target.y-door.position.y)+CORRIDOR))
			else:
				vertical(door.position,target)
				carve(Rect2i(mini(door.position.x,target.x),target.y,absi(target.x-door.position.x)+CORRIDOR,CORRIDOR))

func to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x-start.x,0,cell.y-start.y+9)

func to_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x+.5)+start.x,floori(point.z+.5)+start.y-9)

func on_terrace(cell: Vector2i) -> bool:
	for strip in terrace:
		if strip.has_point(cell): return true
	return false
