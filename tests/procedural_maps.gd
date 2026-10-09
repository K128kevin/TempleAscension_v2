extends SceneTree
const Layout = preload("res://scripts/layout.gd")
const Temple = preload("res://scripts/temple.gd")
const Data = preload("res://scripts/data.gd")
var passed = 0
var failed: Array[String] = []
var samples: Array = []
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)
func reachable(layout) -> Dictionary:
	var seen = {layout.start:true}
	var queue: Array[Vector2i] = [layout.start]
	var head = 0
	while head<queue.size():
		var p = queue[head]
		head += 1
		for d in Layout.DIRS:
			var next: Vector2i = p+d
			if layout.cells.has(next) and not seen.has(next):
				seen[next] = true; queue.append(next)
	return seen
func test():
	var signatures: Dictionary = {}
	for sample in 40:
		var run_seed: int = [0,1,42,123,12345,0x7fffffff,0xffffffff][sample] if sample<7 else Layout.floor_seed(sample,6)
		for floor_index in 3:
			var layout = Layout.new()
			layout.generate(run_seed,floor_index)
			var label = "seed %d / floor %d" % [run_seed,floor_index+1]
			var connected = reachable(layout)
			check(connected.size()==layout.cells.size(),"Every floor tile connected: "+label)
			check(connected.has(layout.exit_cell),"Ascent reachable: "+label)
			check(layout.start.distance_to(layout.exit_cell)>20,"Distant ascent: "+label)
			check(layout.rooms.size()>=5,"Multiple distributed rooms: "+label)
			var roomy = true
			for room in layout.rooms: roomy = roomy and mini(room.size.x,room.size.y)>=Layout.ROOM_MIN
			check(roomy,"Rooms are at least %d tiles across: %s" % [Layout.ROOM_MIN,label])
			var flight: Rect2i = layout.stairs
			check(flight.size==(Vector2i(2,4) if layout.stairs_dir.y!=0 else Vector2i(4,2)),"Ascent stair has a full wall-height flight: "+label)
			var blocked = true; var backed = true
			for y in range(flight.position.y,flight.end.y):
				for x in range(flight.position.x,flight.end.x):
					blocked = blocked and not layout.cells.has(Vector2i(x,y))
					var above = Vector2i(x,y)+layout.stairs_dir
					if not flight.has_point(above): backed = backed and not layout.is_open(above)
			check(blocked and backed,"Stair is solid and climbs into a continuous wall: "+label)
			check(flight.has_point(layout.exit_cell+layout.stairs_dir) and not flight.has_point(layout.exit_cell),"Ascent point is the floor at the stair's foot: "+label)
			var well: Rect2i = layout.arrival
			var well_ok = well.has_area() and layout.rooms.any(func(r): return r.encloses(well)) and not well.grow(1).has_point(layout.start) and not well.intersects(layout.stairs)
			for y in range(well.position.y,well.end.y):
				for x in range(well.position.x,well.end.x): well_ok = well_ok and not layout.cells.has(Vector2i(x,y))
			if floor_index==0: check(not well.has_area(),"No stairwell leads up into the first floor: "+label)
			else: check(well_ok,"The arrival stairwell opens in the entrance room, clear of the spawn: "+label)
			var copy = Layout.new(); copy.generate(run_seed,floor_index)
			check(layout.cells==copy.cells and layout.rooms==copy.rooms and layout.start==copy.start and layout.exit_cell==copy.exit_cell,"Deterministic retry: "+label)
			var total = 0
			for count in Data.COUNTS[floor_index].values(): total += count
			check(layout.cells.size()>total*8,"Original floor density: "+label)
			var world = Temple.new(); world.layout = layout; world.spawn = layout.to_world(layout.start); world.exit_point = layout.to_world(layout.exit_cell)
			var rng = RandomNumberGenerator.new(); rng.seed = Layout.floor_seed(run_seed,floor_index+1)
			var sizes: Array = world.clump_sizes(total,twin(rng))
			check(sizes.reduce(func(a,b): return a+b,0)==total and sizes.all(func(n): return n>=Temple.CLUMPS.x and n<=Temple.CLUMPS.y),"Its enemies stand in clumps of 3 to 8 (%s): %s" % [sizes,label])
			var posts = world.statue_posts(total,rng)
			var safe = posts.size()==total
			for post in posts: safe = safe and world.fits(post.at,.45) and post.at.distance_to(world.spawn)>=9
			check(safe,"Complete reachable roster, safe entrance: "+label)
			var clumped = true; var apart = true
			for post in posts:
				var near = 0
				for other in posts:
					if other == post: continue
					var gap: float = post.at.distance_to(other.at)
					apart = apart and gap >= Temple.POST_GAP
					if gap <= Temple.CLUMP_REACH*2: near += 1
				clumped = clumped and near >= Temple.CLUMPS.x-1
			check(clumped and apart,"Enemies stand in clumps of three or more, none overlapping: "+label)
			world.free()
			if floor_index==Layout.COURT_FLOOR:
				var door_tiles = 0
				var court: Rect2i = layout.court
				for y in range(court.position.y,court.end.y):
					for x in [court.position.x-1,court.end.x]:
						if layout.cells.has(Vector2i(x,y)): door_tiles += 1
				for x in range(court.position.x,court.end.x):
					for y in [court.position.y-1,court.end.y]:
						if layout.cells.has(Vector2i(x,y)): door_tiles += 1
				check(door_tiles==2*Layout.CORRIDOR,"Court has exactly two hallway-width doors: "+label)
			if floor_index==Layout.TERRACE_FLOOR: check(layout.terrace.size()==3 and layout.terrace_doors.size()==6,"Gallery round three sides and six entrances: "+label)
			var signature = hash(layout.cells)
			check(not signatures.has(signature),"Different run/floor has distinct layout: "+label)
			signatures[signature] = true
			if run_seed==0: samples.append({"floor":floor_index+1,"rooms":layout.rooms.size(),"floor_tiles":layout.cells.size(),"map_size":layout.size,"statues":total})
	# The dungeons: the cave's clumps of three to eight, the arena basement's
	# smaller knots (two or three on its first level, two to five on its second).
	for place in ["cave","basement"]:
		for run_seed in [0,7,42,991,12345]:
			for level in 2:
				var dungeon = Layout.new(); dungeon.generate(run_seed,level,place)
				var label = "%s seed %d / level %d" % [place,run_seed,level+1]
				var world = Temple.new(); world.layout = dungeon; world.spawn = dungeon.to_world(dungeon.start); world.exit_point = dungeon.to_world(dungeon.exit_cell)
				var total = 0
				for count in Data.AREAS[place][level].counts.values(): total += count
				var span: Vector2i = Temple.CLUMPS if place == "cave" else Temple.BASEMENT_CLUMPS[level]
				var rng = RandomNumberGenerator.new(); rng.seed = Layout.floor_seed(run_seed,level+1+Layout.KINDS[place].salt)
				var sizes: Array = world.clump_sizes(total,twin(rng))
				check(sizes.reduce(func(a,b): return a+b,0)==total and sizes.all(func(n): return n>=span.x and n<=span.y),"Its enemies stand in knots of %d to %d (%s): %s" % [span.x,span.y,sizes,label])
				var posts = world.statue_posts(total,rng)
				var together = posts.size()==total
				for post in posts:
					var near = 0
					for other in posts:
						if other == post: continue
						var gap: float = post.at.distance_to(other.at)
						together = together and gap >= Temple.POST_GAP
						if gap <= Temple.CLUMP_REACH*2: near += 1
					together = together and near >= span.x-1
				check(together,"Every enemy stands with its clump, none overlapping: "+label)
				world.free()
	var arena = Layout.new(); arena.generate(123,Layout.SUMMIT)
	check(arena.rooms.size()==1 and reachable(arena).size()==arena.cells.size(),"Summit remains one connected original-sized arena")
	FileAccess.open("res://test-results/procedural-maps.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed,"samples":samples},"  "))
	print("PROCEDURAL_MAPS ",passed," passed; ",failed.size()," failed; samples ",samples)
	quit(0 if failed.is_empty() else 1)

# A generator in the same state as `rng`, to see what it will roll.
func twin(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var copy = RandomNumberGenerator.new(); copy.seed = rng.seed; copy.state = rng.state
	return copy
