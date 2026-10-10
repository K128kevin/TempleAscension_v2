extends Node3D
## The town's watch: the guards at its gates and the palace's (scripts/
## world_town.gd guard, two to a post), and PAIRS more who walk the town two
## by two (scripts/town_guard.gd). A pair walks to one of the places the
## townsfolk go (scripts/townsfolk.gd haunts) by the streets (never through
## the arena: path), the second
## man a pace or two behind the first; stands there a while, looking about;
## and goes on to another.
##
## Every third of a day (SHIFT: eight hours) the watch changes: for each post
## a pair still walking is chosen at random, walks there, and takes the
## places of the two on watch, who then walk the town in their turn.
##
## The hero may speak to any of them (scripts/game.gd talk_to): the man turns
## to him, stops a while (and the man walking with him), and says so
## (SAYING, over his head).
const Guard = preload("res://scripts/town_guard.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Town = preload("res://scripts/world_town.gd")
const PAIRS = 6
const SHIFT = Daylight.CYCLE/3.0
const WALK = 1.2
# How far the second man keeps behind the first, and how long a pair stands
# at a place (seconds) before going on.
const BEHIND = 1.5
const STAND = Vector2(4.0,10.0)
# Arrived: within this of the spot; come to relieve a post, within this of
# the man there.
const NEAR = .3
const RELIEF_NEAR = 1.6
# Spoken to: how long he stops, and what he says.
const TALK = 4.0
const SAYING = "Keep your eye out for filthy bandits, they're everywhere..."
# How near (screen pixels, about his middle) the cursor must be to pick him.
const PICK = 48.0

var world
var rng = RandomNumberGenerator.new()
# Each post: its two men and where each stands (`spots`: position, facing).
var posts: Array = []
# Each pair walking: its two men; what they are about ("stand", "walk", or
# "relieve" a post); their way (the first man's); how long they stand on.
var patrols: Array = []
var shift = -1
# Each man spoken to, and how long he stays stopped.
var talking: Dictionary = {}

func setup(overworld) -> void:
	world = overworld
	rng.seed = 7311
	lay_grid()
	for i in range(0,world.guard_posts.size()-1,2):
		var pair: Array = [world.guard_posts[i],world.guard_posts[i+1]]
		posts.append({"guards":pair,"spots":pair.map(func(g): return {"at":g.position,"yaw":g.rotation.y})})
	var haunts: Array = world.townsfolk.haunts
	for p in PAIRS:
		var men: Array = []
		var at: Vector3 = haunts[rng.randi_range(0,haunts.size()-1)].at
		for k in 2:
			var man = Guard.new()
			man.name = "PatrolGuard"
			add_child(man)
			var spot: Vector3 = at+Vector3(k*.9,0,k*.4)
			man.position = spot+Vector3.UP*world.lift(spot)
			man.rotation.y = rng.randf_range(0,TAU)
			man.setup(rng.randf())
			men.append(man)
		patrols.append({"guards":men,"state":"stand","route":PackedVector3Array(),"timer":rng.randf_range(0,STAND.y),"post":-1,"trail":[]})

# Every man of the watch, at his post or walking.
func guards() -> Array:
	var all: Array = []
	for post in posts: all.append_array(post.guards)
	for patrol in patrols: all.append_array(patrol.guards)
	return all

func tick(delta: float, _hero: Vector3) -> void:
	delta = minf(delta,.1)
	var now = int(Daylight.of_day(world.time)/SHIFT)
	if shift >= 0 and now != shift: change_watch()
	shift = now
	for man in talking.keys():
		talking[man] -= delta
		if talking[man] <= 0.0: talking.erase(man)
	for patrol in patrols: walk_patrol(patrol,delta)
	for post in posts:
		for k in 2: keep_post(post.guards[k],post.spots[k],delta)

# A man at a post: come to relieve it, he walks the last of the way to his
# own spot; on it, he faces out as the post does (and back so, once he has
# said his piece to the hero).
func keep_post(man: Node3D, spot: Dictionary, delta: float) -> void:
	if talking.has(man): return
	var way: Vector3 = spot.at-man.position
	way.y = 0
	if way.length() > .05:
		var at: Vector3 = man.position+way.normalized()*minf(way.length(),WALK*delta)
		at.y = world.lift(at)
		man.position = at
		man.turn_to(way,delta)
		man.walk(WALK)
		return
	man.stand()
	man.rotation.y = lerp_angle(man.rotation.y,spot.yaw,minf(1.0,delta*4.0))

# The watch changes: each post's pair is to be relieved by a pair still
# walking, chosen at random.
func change_watch() -> void:
	var free: Array = patrols.filter(func(p): return p.state != "relieve")
	for i in posts.size():
		if free.is_empty(): return
		var patrol: Dictionary = free.pop_at(rng.randi_range(0,free.size()-1))
		patrol.state = "relieve"
		patrol.post = i
		head_for(patrol,posts[i].spots[0].at)

func head_for(patrol: Dictionary, goal: Vector3) -> void:
	var lead = patrol.guards[0]
	var route: PackedVector3Array = path(Vector3(lead.position.x,0,lead.position.z),goal)
	# (Its last step is onto the spot itself, kept clear of everyone else.)
	if route.is_empty() or Vector2(route[-1].x-goal.x,route[-1].z-goal.z).length() > .05: route.append(Vector3(goal.x,0,goal.z))
	patrol.route = route
	patrol.trail = [lead.position]
	if patrol.state != "relieve": patrol.state = "walk"

func walk_patrol(patrol: Dictionary, delta: float) -> void:
	var lead = patrol.guards[0]
	var second = patrol.guards[1]
	# Spoken to, the pair stands.
	if talking.has(lead) or talking.has(second):
		for man in patrol.guards: man.stand()
		return
	if patrol.state == "stand":
		for man in patrol.guards: man.stand()
		patrol.timer -= delta
		if patrol.timer <= 0.0:
			var haunts: Array = world.townsfolk.haunts
			head_for(patrol,haunts[rng.randi_range(0,haunts.size()-1)].at)
		return
	# (Come to a post, he is there once he is near it: the man he relieves
	# stands on the spot itself.)
	if patrol.route.is_empty() or (patrol.state == "relieve" and lead.position.distance_to(posts[patrol.post].spots[0].at) < RELIEF_NEAR):
		arrive(patrol)
		return
	step(lead,patrol.route,delta)
	var trail: Array = patrol.trail
	if trail.is_empty() or trail[-1].distance_to(lead.position) > .1: trail.append(lead.position)
	follow(second,trail,delta)

# One man's step along `route`, a walk's length every moment (what is left
# of it at a point he reaches carried on toward the next, so he keeps one
# pace round every corner).
func step(man: Node3D, route: PackedVector3Array, delta: float) -> void:
	var at = Vector3(man.position.x,0,man.position.z)
	var reach: float = WALK*delta
	var way = Vector3.ZERO
	while reach > 0.0 and not route.is_empty():
		way = route[0]-at
		if way.length() > reach:
			at += way.normalized()*reach
			break
		reach -= way.length()
		at = route[0]
		route.remove_at(0)
	man.position = at+Vector3.UP*world.lift(at)
	man.turn_to(way,delta)
	man.walk(WALK)

# The second man keeps BEHIND the first, along the very way the first has
# walked (`trail`, the first man's footsteps, newest last): he makes for the
# point that far back along it, no faster than CATCH_UP times a walk, and
# his stride follows how fast he actually goes, so he never starts and stops
# from one moment to the next.
const CATCH_UP = 1.3
func follow(man: Node3D, trail: Array, delta: float) -> void:
	var lead = patrol_lead_of(man)
	var goal: Vector3 = lead.position
	var left = BEHIND
	var back: Vector3 = lead.position
	var oldest = 0
	for i in range(trail.size()-1,-1,-1):
		var span: float = back.distance_to(trail[i])
		if span >= left:
			goal = back.lerp(trail[i],left/span)
			left = 0.0
			oldest = i
			break
		left -= span
		back = trail[i]
	if left > 0.0: goal = back
	# (Footsteps further back than the one before his goal are forgotten.)
	for i in oldest: trail.pop_front()
	var way: Vector3 = goal-man.position
	way.y = 0
	var reach: float = minf(way.length(),WALK*CATCH_UP*delta)
	if reach < .002:
		man.stand()
		return
	var at: Vector3 = man.position+way.normalized()*reach
	at.y = world.lift(at)
	man.position = at
	man.turn_to(way,delta)
	man.walk(reach/delta)

func patrol_lead_of(man: Node3D) -> Node3D:
	for patrol in patrols:
		if patrol.guards[1] == man: return patrol.guards[0]
	return man

# The way's end: a pair walking stands a while; a pair come to relieve a
# post takes it (each man then walking on to his own place there), and the
# two relieved walk the town in their turn.
func arrive(patrol: Dictionary) -> void:
	if patrol.state != "relieve":
		patrol.state = "stand"
		patrol.timer = rng.randf_range(STAND.x,STAND.y)
		return
	var post: Dictionary = posts[patrol.post]
	var relieved: Array = post.guards
	post.guards = patrol.guards
	patrol.guards = relieved
	patrol.state = "walk"
	patrol.post = -1
	var haunts: Array = world.townsfolk.haunts
	head_for(patrol,haunts[rng.randi_range(0,haunts.size()-1)].at)

# --- Their ways ----------------------------------------------------------------

# The watch keeps to the streets: their ways are the world's (Overworld.nav)
# over the town and the palace's grounds (GROUND), but never through the
# arena (its oval, ARENA_MARGIN out past its outer wall), which they walk
# round.
const GROUND = Rect2i(-350,-125,190,220)
const ARENA_MARGIN = 1.04
var grid = AStarGrid2D.new()
func lay_grid() -> void:
	grid.region = GROUND.intersection(world.nav.region)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for z in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var cell = Vector2i(x,z)
			if world.nav.is_point_solid(cell) or in_arena(Vector3(x,0,z)): grid.set_point_solid(cell)

static func in_arena(at: Vector3) -> bool:
	return Vector2((at.x-Town.ARENA.x)/Town.ARENA_RADII.x,(at.z-Town.ARENA.z)/Town.ARENA_RADII.y).length() < ARENA_MARGIN

# Whether a man may walk straight from `a` to `b`: nothing in the way, and
# not across the arena.
func clear(a: Vector3, b: Vector3) -> bool:
	if not world.walk_line(a,b): return false
	var steps: int = ceili(a.distance_to(b)/.5)
	for i in steps+1:
		if in_arena(a.lerp(b,float(i)/maxi(steps,1))): return false
	return true

func cell_near(at: Vector3, connected: bool) -> Vector2i:
	var center = Vector2i(roundi(at.x),roundi(at.z))
	var best = Vector2i(-10000,-10000)
	var distance = INF
	for radius in range(7):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var cell = center+Vector2i(x,z)
				if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
				var point = Vector3(cell.x,0,cell.y)
				if connected and not clear(at,point): continue
				var d = at.distance_squared_to(point)
				if d < distance:
					best = cell
					distance = d
		if best.x != -10000: break
	return best

# As Overworld.path: straight there when nothing is in the way, otherwise
# along the grid, cutting every corner that can be walked.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if clear(from,to): return PackedVector3Array([to])
	var start = cell_near(from,true)
	if start.x == -10000: start = cell_near(from,false)
	var end = cell_near(to,false)
	var result = PackedVector3Array()
	if start.x == -10000 or end.x == -10000: return result
	var points = PackedVector3Array()
	for p in grid.get_point_path(start,end): points.append(Vector3(p.x,0,p.y))
	if points.is_empty(): return result
	if clear(points[-1],to): points.append(to)
	var anchor = from
	while not points.is_empty():
		var next = 0
		for i in range(points.size()-1,-1,-1):
			if clear(anchor,points[i]):
				next = i
				break
		anchor = points[next]
		result.append(anchor)
		for i in range(next+1): points.remove_at(0)
	return result

# --- Speaking to them ------------------------------------------------------------

# The man of the watch nearest the cursor at `screen` (within PICK pixels
# of him, head to foot), or null.
func guard_at(camera: Camera3D, screen: Vector2):
	var best = null
	var nearest = PICK
	for man in guards():
		if not man.visible or camera.is_position_behind(man.position): continue
		var head: Vector2 = camera.unproject_position(man.position+Vector3.UP*1.8)
		var foot: Vector2 = camera.unproject_position(man.position)
		var d: float = Geometry2D.get_closest_point_to_segment(screen,foot,head).distance_to(screen)
		if d < nearest:
			nearest = d
			best = man
	return best

# Spoken to by the hero (at `hero`): he turns to him and stops a while, as
# does the man walking with him.
func talk_to(man: Node3D, hero: Vector3) -> void:
	talking[man] = TALK
	var way = hero-man.position
	man.rotation.y = atan2(way.x,way.z)
	man.stand()
	for patrol in patrols:
		if man in patrol.guards:
			for other in patrol.guards: talking[other] = TALK
