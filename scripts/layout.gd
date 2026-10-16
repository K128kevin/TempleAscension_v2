extends RefCounted
## Room/corridor topology adapted from the original game's LevelGen.ts.
## Coordinates are one-metre tiles; visible geometry is supplied by Temple.
const DIRS = [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
# What is generated: a floor of the temple (three, and the summit), or a
# level of one of the dungeons the hero goes down into (two each). How large
# each floor is (its target minutes), how wide its hallways are, and a salt
# that keeps one place's floors unlike another's.
const KINDS = {"temple":{"minutes":[3,5,8],"corridor":5,"salt":0},
	"basement":{"minutes":[3,4],"corridor":3,"salt":40},
	"cave":{"minutes":[3,5],"corridor":3,"salt":80}}
# The temple's floors: the fountain court's, the terraces', and the summit.
const COURT_FLOOR = 1
const TERRACE_FLOOR = 2
const SUMMIT = 3
# Hallway width (the temple's; `corridor` is this floor's) and room size
# range, in tiles.
const CORRIDOR = 5
var corridor = CORRIDOR
var kind = "temple"
var summit = false
# A dungeon is gone down into: its far stair descends, and its lowest level
# has none.
var descending = false
var last = false
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
# The stairwell the hero climbed from the floor below: a flight descending into
# an opening in the entrance room, its deep end against a wall. Its cells are
# removed from `cells` like the ascent's.
var arrival = Rect2i()
# The floor tile at the arrival flight's foot (in a dungeon, where the way
# back up is taken).
var arrival_foot = Vector2i.ZERO
# The first floor's way out to the desert: a short passage through a wall of
# the entrance room, ending at the temple's door. Its cells are open floor;
# `entry_dir` points out through the door.
var entry = Rect2i()
var entry_dir = Vector2i.LEFT
const ENTRY_WIDTH = 3
const ENTRY_DEPTH = 2
var level_index = 0
const PLAYGROUND = -1
var arrival_dir = Vector2i.UP
const STAIR_WIDTH = 2
const STAIR_DEPTH = 4
var size = 50
var court = Rect2i()
var court_obstacle = Rect2i()
var terrace: Array[Rect2i] = []
var terrace_doors: Array[Rect2i] = []
var rng_state = 0
# The arena's basement (see generate_basement). `halls` are its hallways'
# straight stretches. On its first level the hallway that rings it comes, at
# the far side from the entrance, to a gate (`gate`, a passage of floor
# GATE_WIDTH across, `gate_dir` pointing through it) into the arena's middle:
# the hallway in, its rooms and the `vault` of the stair down (all `sealed`).
var halls: Array[Rect2i] = []
var gate = Rect2i()
var gate_dir = Vector2i.DOWN
var vault = Rect2i()
var sealed: Array[Rect2i] = []
# Its last level's puzzle: two `buttons` (2x2 plates, by their top-left
# cells) on the floor of the room he comes down into, two `boulders` (2x2,
# likewise) in the rooms at the ends of the hallways north-west and
# north-east, and the `lasers` across the hallway south (each {"cell": the
# floor cell beside its emitter, "dir": the way it fires}), dark only while
# both buttons are held down. Beyond them, the `elite_room` and where its
# three stand (`elite_posts`: the swordsman, the archer, the healer). No
# other bandit stands in the `quiet` rects, and nothing solid is set down in
# the `kept_clear` ones (the boulders' ways).
var buttons: Array[Vector2i] = []
var boulders: Array[Vector2i] = []
var lasers: Array[Dictionary] = []
var elite_room = Rect2i()
var elite_posts: Array[Vector2i] = []
var quiet: Array[Rect2i] = []
var kept_clear: Array[Rect2i] = []

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
	carve(Rect2i(mini(a.x,b.x),a.y,absi(a.x-b.x)+1,corridor))

func vertical(a: Vector2i, b: Vector2i) -> void:
	carve(Rect2i(a.x,mini(a.y,b.y),corridor,absi(a.y-b.y)+1))

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
				if next.x<2 or next.y<2 or next.x+corridor>size-2 or next.y+corridor>size-2: continue
				if court.grow(1).intersects(Rect2i(next,Vector2i(corridor,corridor))) or parents.has(next): continue
				parents[next] = p
				frontier.append(next)
		assert(parents.has(b),"Court bypass must connect")
		var cursor = b
		while true:
			carve(Rect2i(cursor,Vector2i(corridor,corridor)))
			if cursor==a: break
			cursor = parents[cursor]
	elif random()<.5:
		horizontal(a,b)
		vertical(Vector2i(b.x,a.y),b)
	else:
		vertical(a,b)
		horizontal(Vector2i(a.x,b.y),b)

func generate(run_seed: int, floor_index: int, place: String = "temple") -> void:
	cells.clear(); rooms.clear(); links.clear(); terrace.clear(); terrace_doors.clear(); halls.clear(); sealed.clear()
	buttons.clear(); boulders.clear(); lasers.clear(); elite_posts.clear(); quiet.clear(); kept_clear.clear()
	court = Rect2i(); court_obstacle = Rect2i(); stairs = Rect2i(); arrival = Rect2i(); entry = Rect2i(); gate = Rect2i(); vault = Rect2i(); elite_room = Rect2i()
	kind = place
	var plan: Dictionary = KINDS[kind]
	corridor = plan.corridor
	descending = kind != "temple"
	summit = kind == "temple" and floor_index == SUMMIT
	last = descending and floor_index == plan.minutes.size()-1
	rng_state = floor_seed(run_seed,floor_index+1+plan.salt)
	level_index = floor_index
	# The debug playground: one open, flat square.
	if floor_index==PLAYGROUND:
		size = 34
		rooms.append(Rect2i(1,1,32,32))
		carve(rooms[0])
		start = Vector2i(17,20)
		exit_cell = start
		return
	if summit:
		size = 30
		rooms.append(Rect2i(1,1,26,18))
		carve(rooms[0])
		start = Vector2i(14,17)
		exit_cell = Vector2i(14,3)
		return
	if kind == "basement":
		generate_basement()
		return
	# Larger rooms and hallways need proportionally more floor area.
	var minutes: int = plan.minutes[floor_index]
	size = roundi((44+minutes*6)*1.2)
	# The fountain court, on the temple's second floor.
	if kind == "temple" and floor_index == COURT_FLOOR: court = Rect2i((size-28)/2,(size-15)/2,28,15)
	for attempt in 40+minutes*8:
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
		var door_y = court.position.y+(court.size.y-corridor)/2
		for side in 2:
			var outside = Vector2i(court.position.x-corridor-1 if side==0 else court.end.x+1,door_y)
			var nearest = Vector2i.ZERO
			var best = INF
			for room in rooms:
				var c = center(room)
				var d = absi(c.x-outside.x)+absi(c.y-outside.y)
				if d<best: best=d; nearest=c
			connect_rooms(outside,nearest)
			carve(Rect2i(court.position.x-1 if side==0 else court.end.x,door_y,1,corridor))
		court_obstacle = Rect2i(court.position+Vector2i((court.size.x-2)/2,(court.size.y-2)/2),Vector2i(2,2))
		for y in range(court_obstacle.position.y,court_obstacle.end.y):
			for x in range(court_obstacle.position.x,court_obstacle.end.x): cells.erase(Vector2i(x,y))
		rooms.append(court)
	if kind == "temple" and floor_index == TERRACE_FLOOR: add_terrace()
	place_stairs()

func is_open(cell: Vector2i) -> bool:
	return cells.has(cell) or stairs.has_point(cell) or arrival.has_point(cell)

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
	# (A dungeon's lowest level has no way further down.)
	if not last: place_ascent()
	# The first floor is at ground level: no stair leads into it, and its
	# door opens on the world outside. (The arena basement is under the
	# ground even at its first level: a stair climbs from it to the stands.)
	if level_index > 0 or kind == "basement": place_arrival()
	else: place_entry()

# The door passage leaves the entrance room through solid wall, as near the
# middle of a side as it can, on a side the camera sees if one is free. If
# hallways open on every side of that room, it leaves the nearest stretch of
# wall anywhere else.
func place_entry() -> void:
	var room: Rect2i = rooms[0]
	var sides = [Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN]
	for dir in sides:
		var span = room.size.y if dir.x!=0 else room.size.x
		var offsets: Array = range(0,span-ENTRY_WIDTH+1)
		offsets.sort_custom(func(a,b): return absi(a*2+ENTRY_WIDTH-span)<absi(b*2+ENTRY_WIDTH-span))
		for offset in offsets:
			var mouth: Vector2i
			if dir==Vector2i.LEFT: mouth = Vector2i(room.position.x,room.position.y+offset)
			elif dir==Vector2i.RIGHT: mouth = Vector2i(room.end.x-1,room.position.y+offset)
			elif dir==Vector2i.UP: mouth = Vector2i(room.position.x+offset,room.position.y)
			else: mouth = Vector2i(room.position.x+offset,room.end.y-1)
			if try_entry(mouth,dir): return
	var floor_cells: Array = cells.keys()
	floor_cells.sort_custom(func(a,b):
		var da = a.distance_squared_to(start)
		var db = b.distance_squared_to(start)
		return da<db or (da==db and (a.x<b.x or (a.x==b.x and a.y<b.y))))
	for mouth in floor_cells:
		for dir in sides:
			if try_entry(mouth,dir): return

# Carves the passage out through the wall beyond `mouth` (the first of the
# floor cells across its opening) if solid rock surrounds it and there is
# floor to arrive on.
func try_entry(mouth: Vector2i, dir: Vector2i) -> bool:
	var side = Vector2i(absi(dir.y),absi(dir.x))
	var first = mouth+dir
	var last = mouth+side*(ENTRY_WIDTH-1)+dir*ENTRY_DEPTH
	var rect = Rect2i(Vector2i(mini(first.x,last.x),mini(first.y,last.y)),(first-last).abs()+Vector2i.ONE)
	if rect.position.x<1 or rect.position.y<1 or rect.end.x>size-1 or rect.end.y>size-1: return false
	var around: Rect2i = rect.grow(1)
	for y in range(around.position.y,around.end.y):
		for x in range(around.position.x,around.end.x):
			var cell = Vector2i(x,y)
			var across = (cell-mouth).x*side.x+(cell-mouth).y*side.y
			var behind = (cell-mouth).x*dir.x+(cell-mouth).y*dir.y
			# The opening itself is floor; beyond that line everything round the
			# passage is rock.
			if behind==0:
				if across>=0 and across<ENTRY_WIDTH and not cells.has(cell): return false
			elif is_open(cell): return false
	# Two more cells of floor inside the opening, to arrive on.
	for back in range(1,3):
		for across in ENTRY_WIDTH:
			if not cells.has(mouth+side*across-dir*back): return false
	entry = rect
	entry_dir = dir
	carve(entry)
	return true

# Whether a cell is the passage's last, against the door.
func at_door(cell: Vector2i) -> bool:
	return entry.has_area() and entry.has_point(cell) and not entry.has_point(cell+entry_dir)

# The floor just inside the room from the passage, where the hero arrives.
func entry_position() -> Vector3:
	var middle = to_world(entry.position)+Vector3(entry.size.x-1,0,entry.size.y-1)*.5
	return middle-Vector3(entry_dir.x,0,entry_dir.y)*(ENTRY_DEPTH*.5+2.0)

# The arrival stairwell, in the entrance room clear of the spawn tile, or, if
# it has no room for one, in the nearest room other than the ascent's.
func place_arrival() -> void:
	var order: Array = rooms.filter(func(r): return r!=court and not r.encloses(stairs))
	order.sort_custom(func(a,b): return center(a).distance_squared_to(start)<center(b).distance_squared_to(start))
	for room in order:
		if try_arrival(room): return

func try_arrival(room: Rect2i) -> bool:
	var best = {}
	for dir in [Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]:
		var span = room.size.x if dir.y!=0 else room.size.y
		var depth = room.size.y if dir.y!=0 else room.size.x
		if depth<=STAIR_DEPTH: continue
		for offset in range(0,span-STAIR_WIDTH+1):
			var option = stair_candidate(room,dir,offset)
			if option.is_empty() or (not best.is_empty() and option.score<=best.score): continue
			if option.rect.grow(1).has_point(start) or not stays_connected(option.rect): continue
			best = option
	if best.is_empty(): return false
	arrival = best.rect
	arrival_dir = best.dir
	arrival_foot = best.foot
	for y in range(arrival.position.y,arrival.end.y):
		for x in range(arrival.position.x,arrival.end.x): cells.erase(Vector2i(x,y))
	return true

func place_ascent() -> void:
	# Farthest rooms first, so the ascent stays at the far end of the floor.
	var order: Array = []
	for room in rooms:
		if room==court or room==rooms[0]: continue
		# (Behind a gate, the stair is in the vault.)
		if vault.has_area() and room!=vault: continue
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

func add_terrace() -> void:
	# Five-tile galleries round three sides of the building: west, north and
	# east. Scenery beyond them is rendered separately from walkable tiles.
	terrace = [Rect2i(-5,-5,5,size+5),Rect2i(-5,-5,size+10,5),Rect2i(size,-5,5,size+5)]
	for strip in terrace: carve(strip)
	# Two doors out onto each side.
	for side in ["west","north","east"]:
		for fraction in [.3,.7]:
			var along = floori(size*fraction)
			var door: Rect2i
			if side == "west": door = Rect2i(0,along,1,corridor)
			elif side == "east": door = Rect2i(size-1,along,1,corridor)
			else: door = Rect2i(along,0,corridor,1)
			terrace_doors.append(door)
			var target = start
			var best = INF
			for room in rooms:
				var c = center(room)
				var d = absi(c.x-door.position.x)+absi(c.y-door.position.y)
				if d<best: best=d; target=c
			if side != "north":
				horizontal(door.position,target)
				carve(Rect2i(target.x,mini(door.position.y,target.y),corridor,absi(target.y-door.position.y)+corridor))
			else:
				vertical(door.position,target)
				carve(Rect2i(mini(door.position.x,target.x),target.y,absi(target.x-door.position.x)+corridor,corridor))

# The world point at the middle of the arrival flight's foot.
func arrival_position() -> Vector3:
	var side = Vector2i(arrival_dir.y,arrival_dir.x).abs()
	return to_world(arrival_foot)+Vector3(side.x,0,side.y)*.5

func to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x-start.x,0,cell.y-start.y+9)

func to_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x+.5)+start.x,floori(point.z+.5)+start.y-9)

func on_terrace(cell: Vector2i) -> bool:
	for strip in terrace:
		if strip.has_point(cell): return true
	return false

# --- The arena's basement ------------------------------------------------------

# Its first level lies under the arena and is as big as it is: an oval OVAL
# tiles out each way from its middle (the arena's outer wall,
# Town.ARENA_RADII), with a wall's breadth to spare. A hallway MAIN_HALL wide
# rings the middle, its centre line the oval RING (squared off a little,
# RING_SQUARE) stepped round on a grid of
# RING_STEP tiles, so that it runs in long straight stretches and turns in
# steps at the oval's shoulders. Off both sides of its longer stretches
# (RING_ROOMS_FROM tiles or more), passages `corridor` wide and BRANCH long
# lead to rooms BRANCH_ROOM a side (now and then, BRANCH_SKIP, a stretch of
# wall is left bare). The way in, down the stair from under the stands, is
# the ENTRANCE room off the ring's south side. At its far side, the north,
# the gate (GATE_WIDTH across) opens on a hallway INNER_HALL wide running
# south into the middle, with rooms off it too; in the middle (a little south
# of it, CENTER_SOUTH, for the hallway's rooms) is the vault of the stair
# down, CENTER_ROOM a side.
const OVAL = Vector2(45,39)
const RING = Vector2(30,20)
const RING_STEP = 5
# How square the ring's oval is drawn (2, an ellipse): squarer, its stretches
# north and south run long and its shoulders keep out of the middle.
const RING_SQUARE = 3.0
const MAIN_HALL = 6
const RING_ROOMS_FROM = 12
const BRANCH = Vector2i(2,4)
const BRANCH_ROOM = Vector2i(7,10)
const BRANCH_SKIP = .15
const BRANCH_PASSES = 5
# (The hallway in, and the last level's arms, are short for their rooms:
# they are tried for more often.)
const CLOSE_PASSES = 6
const ENTRANCE = Vector2i(10,8)
const GATE_WIDTH = 4
const INNER_HALL = 4
const CENTER_ROOM = 10
const CENTER_SOUTH = 2
# Its last level begins in a room START_ROOM a side, where the stair comes
# down. Hallways DEPTHS_HALL wide (room for a boulder and a man beside it)
# leave it: south, LASER_HALL long, across which the lasers fire (at
# LASER_ROWS into it), to the ELITE_ROOM; and north-west and north-east,
# each in stretches turning north and outward by turns (ARM_RUNS long), with
# rooms off them, to an END_ROOM holding a boulder.
const START_ROOM = 15
const DEPTHS_HALL = 5
const LASER_HALL = 18
const LASER_ROWS = [3,5,7]
const ELITE_ROOM = Vector2i(17,13)
const ARM_RUNS = [Vector2i(7,9),Vector2i(12,15),Vector2i(9,11),Vector2i(12,15),Vector2i(5,7)]
const END_ROOM = 11
# Whether side rooms must keep within the oval (on the first level).
var bounded = false

func generate_basement() -> void:
	if last: basement_depths()
	else: basement_ring()

func basement_ring() -> void:
	bounded = true
	var parts: Array[Rect2i] = []
	var corners: Array[Vector2i] = ring_corners()
	var stretches: Array = []
	for i in corners.size():
		var a: Vector2i = corners[i]
		var b: Vector2i = corners[(i+1)%corners.size()]
		stretches.append([a,b])
		parts.append(stretch(a,b,MAIN_HALL))
	var ring_halls: Array[Rect2i] = parts.duplicate()
	var south: int = roundi(RING.y/RING_STEP)*RING_STEP
	var north: int = -south
	var low: int = MAIN_HALL/2
	var high: int = MAIN_HALL-1-low
	# The way in, off the south side.
	var entrance = Rect2i(-ENTRANCE.x/2,south+high+3,ENTRANCE.x,ENTRANCE.y)
	var into = Rect2i(-2,south+high+1,4,2)
	parts.append_array([into,entrance])
	# Through the gate in the north side, the hallway in to the vault.
	var gate_rect = Rect2i(-GATE_WIDTH/2,north+high+1,GATE_WIDTH,1)
	var center_room = Rect2i(-CENTER_ROOM/2,CENTER_SOUTH-CENTER_ROOM/2,CENTER_ROOM,CENTER_ROOM)
	var inner = Rect2i(-INNER_HALL/2,gate_rect.end.y,INNER_HALL,center_room.position.y-gate_rect.end.y)
	parts.append_array([gate_rect,inner,center_room])
	# Rooms off the hallway in first (they are sealed behind the gate), then
	# off the ring.
	var inner_rooms: Array = []
	for pass_number in CLOSE_PASSES:
		rooms_along(Vector2i(0,inner.position.y),Vector2i(0,inner.end.y-1),INNER_HALL,parts,inner_rooms)
	var ring_rooms: Array = []
	for pass_number in BRANCH_PASSES:
		for line in stretches:
			if absi(line[1].x-line[0].x)+absi(line[1].y-line[0].y) >= RING_ROOMS_FROM: rooms_along(line[0],line[1],MAIN_HALL,parts,ring_rooms)
	var shift: Vector2i = settle(parts)
	rooms.append(moved(entrance,shift))
	for found in ring_rooms: rooms.append(moved(found.room,shift))
	for found in inner_rooms:
		rooms.append(moved(found.room,shift))
		sealed.append(moved(found.room,shift))
		sealed.append(moved(found.passage,shift))
	rooms.append(moved(center_room,shift))
	for r in ring_halls: halls.append(moved(r,shift))
	halls.append(moved(inner,shift))
	for r in parts: carve(moved(r,shift))
	vault = rooms[-1]
	gate = moved(gate_rect,shift)
	gate_dir = Vector2i.DOWN
	sealed.append_array([vault,gate,moved(inner,shift)])
	start = center(rooms[0])
	exit_cell = center(vault)
	place_stairs()

func basement_depths() -> void:
	bounded = false
	var parts: Array[Rect2i] = []
	var half: int = START_ROOM/2
	var room = Rect2i(-half,-half,START_ROOM,START_ROOM)
	var low: int = DEPTHS_HALL/2
	var down = Rect2i(-low,room.end.y,DEPTHS_HALL,LASER_HALL)
	var elites = Rect2i(-ELITE_ROOM.x/2,down.end.y,ELITE_ROOM.x,ELITE_ROOM.y)
	parts.append_array([room,down,elites])
	# The two arms, north-west and north-east, and the rooms at their ends.
	var arm_halls: Array[Rect2i] = []
	var arm_lines: Array = []
	var ends: Array[Rect2i] = []
	var stones: Array[Vector2i] = []
	for side in [-1,1]:
		var p = Vector2i(side*(half-low-1),room.position.y)
		for k in ARM_RUNS.size():
			var run: int = integer(ARM_RUNS[k].x,ARM_RUNS[k].y)
			var q: Vector2i = p+(Vector2i(0,-run) if k%2==0 else Vector2i(side*run,0))
			arm_lines.append([p,q])
			arm_halls.append(stretch(p,q,DEPTHS_HALL))
			p = q
		var end_room = Rect2i(p.x-END_ROOM/2,p.y-low-END_ROOM,END_ROOM,END_ROOM)
		ends.append(end_room)
		stones.append(center(end_room)-Vector2i.ONE)
	parts.append_array(arm_halls)
	parts.append_array(ends)
	var side_rooms: Array = []
	for pass_number in CLOSE_PASSES:
		for line in arm_lines: rooms_along(line[0],line[1],DEPTHS_HALL,parts,side_rooms)
	var shift: Vector2i = settle(parts)
	rooms.append(moved(room,shift))
	for found in side_rooms: rooms.append(moved(found.room,shift))
	for r in ends: rooms.append(moved(r,shift))
	elite_room = moved(elites,shift)
	rooms.append(elite_room)
	for r in arm_halls: halls.append(moved(r,shift))
	halls.append(moved(down,shift))
	for r in parts: carve(moved(r,shift))
	for cell in stones: boulders.append(cell+shift)
	var hall_in: Rect2i = moved(down,shift)
	for k in LASER_ROWS.size():
		var y: int = hall_in.position.y+LASER_ROWS[k]
		lasers.append({"cell":Vector2i(hall_in.position.x if k%2==0 else hall_in.end.x-1,y),"dir":Vector2i.RIGHT if k%2==0 else Vector2i.LEFT})
	var middle: int = elite_room.position.x+elite_room.size.x/2
	elite_posts = [Vector2i(middle,elite_room.position.y+4),Vector2i(middle-5,elite_room.position.y+8),Vector2i(middle+5,elite_room.position.y+8)]
	quiet = [hall_in,elite_room]
	kept_clear = [rooms[0]]
	kept_clear.append_array(halls.slice(0,arm_halls.size()))
	for r in ends: kept_clear.append(moved(r,shift))
	start = center(rooms[0])
	exit_cell = start
	place_stairs()
	place_buttons()

# The two buttons, either side of the room's middle, clear of the stair.
func place_buttons() -> void:
	for row in [1,3,-1,-3,5]:
		var pair: Array[Vector2i] = [start+Vector2i(-5,row),start+Vector2i(4,row)]
		var free = true
		for plate in pair:
			for cell in [plate,plate+Vector2i.RIGHT,plate+Vector2i.DOWN,plate+Vector2i.ONE]:
				if not cells.has(cell) or arrival.grow(1).has_point(cell) or cell.distance_to(arrival_foot) < 2.0: free = false
		if free:
			buttons = pair
			return
	buttons = [start+Vector2i(-5,1),start+Vector2i(4,1)]

# The ring's corners, going round: the oval RING, its points snapped to the
# RING_STEP grid, each step between them turned at its outer corner.
func ring_corners() -> Array[Vector2i]:
	var loop: Array[Vector2i] = []
	for i in 72:
		var t: float = TAU*i/72.0
		var q = Vector2i(snap(signf(cos(t))*pow(absf(cos(t)),2.0/RING_SQUARE)*RING.x),snap(signf(sin(t))*pow(absf(sin(t)),2.0/RING_SQUARE)*RING.y))
		if loop.is_empty() or loop[-1] != q: loop.append(q)
	if loop[-1] == loop[0]: loop.pop_back()
	var path: Array[Vector2i] = []
	for i in loop.size():
		var a: Vector2i = loop[i]
		var b: Vector2i = loop[(i+1)%loop.size()]
		path.append(a)
		if a.x != b.x and a.y != b.y:
			var outer = Vector2i(b.x,a.y)
			var inner = Vector2i(a.x,b.y)
			path.append(outer if oval_measure(outer,RING) >= oval_measure(inner,RING) else inner)
	var corners: Array[Vector2i] = []
	for i in path.size():
		var into: Vector2i = (path[i]-path[i-1]).sign()
		var out: Vector2i = (path[(i+1)%path.size()]-path[i]).sign()
		if into != out: corners.append(path[i])
	return corners

# To the RING_STEP grid, halves toward the middle (so that the ring is laid
# out alike each side of it, whatever the rounding of its sines).
static func snap(v: float) -> int:
	return signi(roundi(v))*roundi(absf(v)/RING_STEP-.001)*RING_STEP

static func oval_measure(p: Vector2i, radii: Vector2) -> float:
	return (Vector2(p)/radii).length_squared()

# Whether every tile of `r` lies within the arena's oval, a wall's breadth in.
func inside_oval(r: Rect2i) -> bool:
	var radii: Vector2 = OVAL-Vector2.ONE
	for corner in [r.position,Vector2i(r.end.x,r.position.y),Vector2i(r.position.x,r.end.y),r.end]:
		if oval_measure(corner,radii) > 1.0: return false
	return true

# A straight stretch of hallway `width` wide, its centre line from `a` to `b`
# (its tiles running from width/2 below that line to the rest above).
static func stretch(a: Vector2i, b: Vector2i, width: int) -> Rect2i:
	var low: int = width/2
	return Rect2i(a.min(b)-Vector2i(low,low),(b-a).abs()+Vector2i(width,width))

# Side rooms along both sides of a stretch from `a` to `b`, `width` wide: a
# room's breadth on past each one laid out, a step or two past each that
# will not fit. Each is added to `parts` and `found`.
func rooms_along(a: Vector2i, b: Vector2i, width: int, parts: Array[Rect2i], found: Array) -> void:
	var run: int = absi(b.x-a.x)+absi(b.y-a.y)
	var along: Vector2i = (b-a)/maxi(run,1)
	var across = Vector2i(absi(along.y),absi(along.x))
	var low: int = width/2
	var high: int = width-1-low
	for way in [1,-1]:
		var offset: int = integer(low+2,low+4)
		while offset <= run-high-2:
			var room: Dictionary = branch(a+along*offset,across*way,width,parts) if random() > BRANCH_SKIP else {}
			if room.is_empty():
				offset += integer(2,4)
				continue
			parts.append(room.passage)
			parts.append(room.room)
			found.append(room)
			offset += (room.room.size.x if along.x != 0 else room.room.size.y)+integer(2,5)

# A passage `corridor` wide leaving a hallway `width` wide at `at` (on its
# centre line) toward `out`, and a room at its end, meeting it somewhere along
# its near wall, if neither runs into anything already laid out (`parts`) nor,
# on the first level, out of the oval; {} if they would.
func branch(at: Vector2i, out: Vector2i, width: int, parts: Array[Rect2i]) -> Dictionary:
	var side = Vector2i(absi(out.y),absi(out.x))
	var low: int = width/2
	var high: int = width-1-low
	var long: int = integer(BRANCH.x,BRANCH.y)
	var mouth: Vector2i = at+out*(high+1 if out.x+out.y > 0 else low+1)
	var tail: Vector2i = mouth+out*(long-1)
	var passage = Rect2i(mouth.min(tail)-side*(corridor/2),(tail-mouth).abs()+Vector2i.ONE+side*(corridor-1))
	var w: int = integer(BRANCH_ROOM.x,BRANCH_ROOM.y)
	var h: int = integer(BRANCH_ROOM.x,BRANCH_ROOM.y)
	var first: Vector2i = tail+out
	var shift: int = integer(1,maxi(1,(w if side.x == 1 else h)-corridor-1))
	var corner: Vector2i
	if side.x == 1: corner = Vector2i(at.x-corridor/2-shift,first.y if out.y > 0 else first.y-h+1)
	else: corner = Vector2i(first.x if out.x > 0 else first.x-w+1,at.y-corridor/2-shift)
	var room = Rect2i(corner,Vector2i(w,h))
	if bounded and not inside_oval(room): return {}
	for other in parts:
		if other.grow(2).intersects(room) or other.intersects(passage): return {}
		if other.grow(1).intersects(passage) and not other.has_point(at): return {}
	return {"passage":passage,"room":room}

# How far to move the level laid out about its middle (`parts`) to lie clear
# of the map's edge; sets the map's size.
func settle(parts: Array[Rect2i]) -> Vector2i:
	var low = Vector2i(1<<30,1<<30)
	var high = -low
	for r in parts:
		low = low.min(r.position)
		high = high.max(r.end)
	size = maxi(high.x-low.x,high.y-low.y)+6
	return Vector2i(3,3)-low

static func moved(r: Rect2i, shift: Vector2i) -> Rect2i:
	return Rect2i(r.position+shift,r.size)

# Whether `cell` lies behind the first level's gate.
func behind_gate(cell: Vector2i) -> bool:
	return sealed.any(func(r): return r.has_point(cell))

func in_any(list: Array[Rect2i], cell: Vector2i) -> bool:
	return list.any(func(r): return r.has_point(cell))
