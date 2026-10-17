extends Node3D
## The arena basement's last level's puzzle (Layout.basement_depths), after
## the 2D game Boulders: two great stone balls, one in the room at the end of
## each hallway north-west and north-east, and two pressure plates on the
## floor of the room in the middle. Laser beams, drawn as the Crowned Statue's
## gaze is (scripts/boss_laser.gd), fire across the hallway south; they go
## dark only while both plates are held down, by a boulder or by the hero
## standing on one, and light again the moment either lifts. A beam runs from
## its emitter until it meets a wall or a boulder; whoever walks into it dies.
##
## A boulder covers 2x2 tiles and is rolled a tile at a time on the floor's
## grid. E beside one takes hold of it (and E again lets go): holding it, a
## click on the floor is where to roll it, and he works out how (plan): he
## goes round to the side he must push from, sets his hands to it and walks
## it on, as many tiles as it takes, turning it at corners; where it lies
## against a wall the way it must go, he pulls it back off first (stepping
## backward with it), so that it is never wedged where it cannot be got
## behind. Each step he takes with it, he leans into it (or back from it),
## his hands flat on the stone (scripts/push_pose.gd).
const Layout = preload("res://scripts/layout.gd")
const Art = preload("res://scripts/assets.gd")
const Kit = preload("res://scripts/world_art.gd")
const Gaze = preload("res://scripts/boss_laser.gd")
const BOULDER_RADIUS = .92
# Tiles a second, pushed and pulled.
const PUSH_SPEED = 2.6
const PULL_SPEED = 1.8
# How near the hero must stand to take hold of a boulder (from its surface),
# and how far from its middle he stands to push it.
const GRIP_REACH = 1.3
const STAND = BOULDER_RADIUS+.42
# The planner: what a pull costs against a push (it is worked only where it
# must be), and how many places it weighs before it settles for the nearest
# it found; how far the hero looks to get round a boulder (tiles).
const PULL_COST = 4
const PLAN_LIMIT = 6000
const ROUND_REACH = 9
# The beams: their height, and how near a body must come to one to be struck.
const BEAM_HEIGHT = .95
const BEAM_TOUCH = .38
# How far a man must keep from a lit beam (the bandits will not walk into one).
const BEAM_KEEP = .55
const PULSE = .055
var game
var world
var layout
var boulders: Array[Dictionary] = []
var plates: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var lit = true
var mesh: ImmediateMesh
var materials: Array = []
var clock = 0.0
var last_hero = Vector3.INF
# The boulder he has hold of ({} if none), the moves still to make with it
# (each {"m": the way it goes, "pull": whether he pulls it}), and whether
# he is set against it (his hands on it) or still going round to it.
var held: Dictionary = {}
var moves: Array = []
var braced = false
var pose = null

# `kept`: boulders' top-left cells as saved, in place of where they start.
func setup(owner_game, owner_world, kept: Array = []) -> void:
	game = owner_game
	world = owner_world
	layout = world.layout
	name = "BasementPuzzle"
	var stone = ShaderMaterial.new()
	stone.shader = load("res://assets/shaders/stone_ball.gdshader")
	stone.set_shader_parameter("albedo_map",load("res://assets/textures/scan_%s_diff.jpg" % Kit.SCANS["boulder_a"]))
	stone.set_shader_parameter("detail_map",load("res://assets/textures/rock_detail.jpg"))
	stone.set_shader_parameter("tint",Vector3(.95,.88,.8))
	for i in layout.boulders.size():
		var cell: Vector2i = layout.boulders[i]
		if i < kept.size() and kept[i] is Vector2i and footprint_free(kept[i],i,true): cell = kept[i]
		var node = boulder_model(i,stone)
		add_child(node)
		var b = {"cell":cell,"node":node,"from":centre(cell),"to":centre(cell),"t":1.0,"speed":PUSH_SPEED,"dir":Vector2i.ZERO,"pull":false}
		node.position = b.to
		settle(node)
		boulders.append(b)
		world.visibility_nodes.append(node)
	for cell in layout.buttons:
		var plate = plate_model()
		add_child(plate.root)
		plate.root.position = centre(cell)
		plates.append({"cell":cell,"root":plate.root,"top":plate.top,"lamp":plate.lamp,"down":false,"sink":0.0})
		world.visibility_nodes.append(plate.root)
		world.visibility_cells[plate.root] = footprint(cell)
	for b in boulders: nav_mark(b.cell)
	materials = Gaze.pass_materials()
	mesh = ImmediateMesh.new()
	var drawn = MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drawn.extra_cull_margin = 64.0
	add_child(drawn)
	for laser in layout.lasers: beams.append(emitter(laser))
	settle_plates(null,1.0)
	lit = not all_down()
	for beam in beams: beam.light.light_energy = 1.6 if lit else .15

# --- Shapes ----------------------------------------------------------------------

# Where a 2x2 footprint, by its top-left cell, has its middle (on the floor).
func centre(cell: Vector2i) -> Vector3:
	return layout.to_world(cell)+Vector3(.5,0,.5)

static func footprint(cell: Vector2i) -> Array[Vector2i]:
	return [cell,cell+Vector2i.RIGHT,cell+Vector2i.DOWN,cell+Vector2i.ONE]

# A boulder: a great rough ball of stone, far from true: broad swells and
# flats over it (BOULDER_SWELL of its radius, by slow noise), knobbled and
# pitted over those (BOULDER_ROUGH), and a little longer one way than the
# others (BOULDER_SHAPE), in
# the cave's scanned rock; its middle at the node's origin, so that it rolls
# about it. One shape for both, turned differently.
const BOULDER_SWELL = .16
const BOULDER_ROUGH = .06
const BOULDER_SHAPE = Vector3(1.08,.94,.98)
static var ball: ArrayMesh
# Points spread over its surface, for finding which of it rests on the floor.
static var hull: PackedVector3Array
func boulder_model(index: int, stone: Material) -> Node3D:
	var root = Node3D.new()
	root.name = "Boulder%d" % index
	if ball == null:
		var sphere = SphereMesh.new()
		sphere.radius = BOULDER_RADIUS
		sphere.height = BOULDER_RADIUS*2.0
		sphere.radial_segments = 56
		sphere.rings = 28
		var arrays: Array = sphere.get_mesh_arrays()
		var lumps = FastNoiseLite.new()
		lumps.seed = 7
		lumps.frequency = 1.1
		lumps.fractal_octaves = 4
		var swells = FastNoiseLite.new()
		swells.seed = 21
		swells.frequency = .45
		swells.fractal_octaves = 2
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for k in points.size():
			var p: Vector3 = points[k]
			points[k] = p*BOULDER_SHAPE*(1.0+BOULDER_SWELL*swells.get_noise_3dv(p*2.0)+BOULDER_ROUGH*lumps.get_noise_3dv(p*2.0))
		arrays[Mesh.ARRAY_VERTEX] = points
		var tool = SurfaceTool.new()
		tool.create_from_arrays(arrays)
		tool.generate_normals()
		tool.generate_tangents()
		ball = tool.commit()
		for k in range(0,points.size(),5): hull.append(points[k])
	var rock = MeshInstance3D.new()
	rock.mesh = ball
	rock.material_override = stone
	root.add_child(rock)
	root.rotation = Vector3(index*1.7,index*2.3,index*.9)
	return root

# A pressure plate: a worn slab sunk in a frame of darker stone, a dull ember
# in a groove round it that brightens when it is pressed down.
func plate_model() -> Dictionary:
	var root = Node3D.new()
	var frame: Node3D = Art.model("floor",Vector3(2.0,.08,2.0),Art.material("stone",Color(.32,.3,.28)))
	frame.position = Vector3.DOWN*.02
	root.add_child(frame)
	var groove = MeshInstance3D.new()
	var ring = BoxMesh.new()
	ring.size = Vector3(1.78,.02,1.78)
	groove.mesh = ring
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color(.2,.06,.03)
	glow.emission_enabled = true
	glow.emission = Color(1,.3,.12)
	glow.emission_energy_multiplier = .4
	groove.material_override = glow
	# (Just below the top's rim, so that pressed down it shows only round its edge.)
	groove.position = Vector3.UP*-.03
	root.add_child(groove)
	var top: Node3D = Art.model("floor",Vector3(1.6,.14,1.6),Art.world_stone(Art.material("stone",Color(.6,.56,.5))))
	top.position = Vector3.UP*.02
	root.add_child(top)
	var lamp = OmniLight3D.new()
	lamp.light_color = Color(1,.4,.18)
	lamp.light_energy = .25
	lamp.omni_range = 2.2
	lamp.position = Vector3.UP*.3
	root.add_child(lamp)
	return {"root":root,"top":top,"lamp":glow}

# A laser's emitter, a bronze housing set in the wall beside `laser.cell`
# with a red eye, and a dark plate on the wall opposite where it ends.
func emitter(laser: Dictionary) -> Dictionary:
	var cell: Vector2i = laser.cell
	var dir: Vector2i = laser.dir
	var way = Vector3(dir.x,0,dir.y)
	var wall: Vector3 = layout.to_world(cell)-way*.5
	var housing: Node3D = Art.model("floor",Vector3(.22,.42,.42) if dir.x != 0 else Vector3(.42,.42,.22),Art.metal())
	housing.position = wall+way*.08+Vector3.UP*(BEAM_HEIGHT-.21)
	add_child(housing)
	var eye = MeshInstance3D.new()
	var lens = SphereMesh.new()
	lens.radius = .07
	lens.height = .14
	eye.mesh = lens
	var red = StandardMaterial3D.new()
	red.albedo_color = Color(.3,.02,.02)
	red.emission_enabled = true
	red.emission = Color(1,.12,.08)
	red.emission_energy_multiplier = 3.0
	eye.material_override = red
	eye.position = wall+way*.2+Vector3.UP*BEAM_HEIGHT
	add_child(eye)
	var light = OmniLight3D.new()
	light.light_color = Color(1,.2,.15)
	light.light_energy = 1.6
	light.omni_range = 2.6
	light.position = eye.position+way*.2
	add_child(light)
	var row: Array[Vector2i] = []
	var at: Vector2i = cell
	while layout.cells.has(at):
		row.append(at)
		at += dir
	for node in [housing,eye,light]:
		world.visibility_nodes.append(node)
		world.visibility_cells[node] = row
	return {"cell":cell,"dir":dir,"from":wall+way*.26+Vector3.UP*BEAM_HEIGHT,"eye":red,"light":light,"end":Vector3.ZERO,"seed":randf()*TAU,"cells":row}

# --- Each frame --------------------------------------------------------------------

func tick(dt: float) -> void:
	clock += dt
	var hero = game.player
	for b in boulders: roll(b,dt)
	if not held.is_empty():
		if hero.dead: let_go()
		else: work(dt)
	settle_plates(hero if not hero.dead else null,dt)
	var open: bool = all_down()
	if open == lit:
		lit = not open
		game.sound.play("lightning-zap",-8 if lit else -12)
		game.toast("The beams across the south hallway flare back to life." if lit else "The beams across the south hallway gutter and go dark.")
	for beam in beams:
		beam.end = beam_end(beam)
		beam.light.light_energy = move_toward(beam.light.light_energy,1.6 if lit else .15,dt*6.0)
		beam.eye.emission_energy_multiplier = 3.0 if lit else .3
	draw_beams()
	if lit and not hero.dead and last_hero != Vector3.INF and struck(last_hero,hero.position): game.kill_player("laser")
	last_hero = hero.position

func start_roll(b: Dictionary, cell: Vector2i, speed: float, pull: bool = false) -> void:
	nav_mark(b.cell)
	b.dir = cell-b.cell
	b.cell = cell
	b.from = b.to
	b.to = centre(cell)
	b.t = 0.0
	b.speed = speed
	b.pull = pull

func roll(b: Dictionary, dt: float) -> void:
	if b.t >= 1.0: return
	var before: Vector3 = here(b)
	b.t = minf(1.0,b.t+dt*b.speed)
	var after: Vector3 = here(b)
	var node: Node3D = b.node
	node.position = after
	if b.t >= 1.0:
		nav_mark(b.dir*-1+b.cell)
		nav_mark(b.cell)
	# Rolling: turned about the level line across its way, a radian for each
	# radius it has gone.
	var travel: Vector3 = after-before
	if travel.length_squared() > 0.0:
		var axis: Vector3 = Vector3.UP.cross(travel.normalized())
		node.basis = Basis(axis,travel.length()/BOULDER_RADIUS)*node.basis
		node.basis = node.basis.orthonormalized()
	settle(node)
	world.visibility_cells[node] = footprint(b.cell)

# A rough stone lies on its lowest point: its middle stands as high above the
# floor as that point lies below it, turned as it now is.
func settle(node: Node3D) -> void:
	var lowest = 0.0
	for p in hull: lowest = minf(lowest,(node.basis*p).y)
	node.position.y = -lowest

func here(b: Dictionary) -> Vector3:
	return b.from.lerp(b.to,b.t)

# Whether a boulder (`index`, not counted itself) may lie at `cell`: on floor,
# clear of the other boulder and of the living. (`starting`: as it is set
# down, before anyone stands about; `pulled`: the hero, stepping back out of
# its way as he pulls it, does not count.)
func footprint_free(cell: Vector2i, index: int, starting: bool = false, pulled: bool = false) -> bool:
	for c in footprint(cell):
		if not layout.cells.has(c) or not may_roll(c): return false
	var mid: Vector3 = centre(cell)
	for i in boulders.size():
		if i == index: continue
		if Rect2i(cell,Vector2i(2,2)).intersects(Rect2i(boulders[i].cell,Vector2i(2,2))): return false
	if starting: return true
	for e in game.enemies:
		if not e.dead and Vector2(e.position.x-mid.x,e.position.z-mid.z).length() < BOULDER_RADIUS+.45: return false
	if not pulled and is_instance_valid(game.player):
		var p: Vector3 = game.player.position
		if Vector2(p.x-mid.x,p.z-mid.z).length() < BOULDER_RADIUS+.35: return false
	return true

# Whether a body of `radius` at `p` would stand in a boulder.
func blocks(p: Vector3, radius: float) -> bool:
	for b in boulders:
		var at: Vector3 = here(b)
		if Vector2(p.x-at.x,p.z-at.z).length() < BOULDER_RADIUS+radius-.02: return true
	return false

# --- The plates and the beams --------------------------------------------------------

# Each plate is down while a boulder lies mostly on it (a tile off at most,
# one way) or the hero stands on it.
func settle_plates(hero, dt: float) -> void:
	for plate in plates:
		var mid: Vector3 = centre(plate.cell)
		var down = false
		for b in boulders:
			var at: Vector3 = here(b)
			if Vector2(at.x-mid.x,at.z-mid.z).length() <= 1.05: down = true
		if hero != null and absf(hero.position.x-mid.x) <= 1.0 and absf(hero.position.z-mid.z) <= 1.0: down = true
		if down != plate.down:
			plate.down = down
		plate.sink = move_toward(plate.sink,1.0 if down else 0.0,dt*8.0)
		plate.top.position.y = .02-.09*plate.sink
		plate.lamp.emission_energy_multiplier = .4+2.6*plate.sink

func all_down() -> bool:
	return not plates.is_empty() and plates.all(func(p): return p.down)

# Where a beam ends: at the first tile on its way that is wall or boulder.
func beam_end(beam: Dictionary) -> Vector3:
	var at: Vector2i = beam.cell
	var dir: Vector2i = beam.dir
	while layout.cells.has(at) and under_boulder(at).is_empty(): at += dir
	var way = Vector3(dir.x,0,dir.y)
	var face: Vector3 = layout.to_world(at)-way*.5
	# (Against a boulder, at its curve, not its square.)
	var stone: Dictionary = under_boulder(at)
	if not stone.is_empty(): face = beam.from+way*((here(stone)-beam.from).dot(way)-BOULDER_RADIUS*.9)
	return Vector3(face.x,BEAM_HEIGHT,face.z)

# The boulder lying on `cell` ({} if none).
func under_boulder(cell: Vector2i) -> Dictionary:
	for b in boulders:
		if Rect2i(b.cell,Vector2i(2,2)).has_point(cell): return b
		# (Rolling, it is in the way where it is going and where it was.)
		if b.t < 1.0 and Rect2i(b.cell-b.dir,Vector2i(2,2)).has_point(cell): return b
	return {}

func draw_beams() -> void:
	mesh.clear_surfaces()
	if not lit: return
	var camera: Camera3D = world.camera
	var pulse = floori(clock/PULSE)
	# (Only those in sight.)
	var shown: Array = range(beams.size()).filter(func(i): return world.cell_is_visible(beams[i].cell) or world.cell_is_visible(layout.to_cell(beams[i].end)))
	if shown.is_empty(): return
	for layer in 3:
		var width = [Gaze.GLOW_WIDTH,Gaze.BAND_WIDTH,Gaze.CORE_WIDTH][layer]
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,materials[layer])
		for i in shown: Gaze.ribbon(mesh,Gaze.lightning(beams[i].from,beams[i].end,pulse,i,beams[i].seed),width,camera)
		mesh.surface_end()

# Whether a body moving from `a` to `b` touches a lit beam.
func struck(a: Vector3, b: Vector3, reach: float = BEAM_TOUCH) -> bool:
	for beam in beams:
		var from = Vector2(beam.from.x,beam.from.z)
		var to = Vector2(beam.end.x,beam.end.z)
		var p = Vector2(a.x,a.z)
		var q = Vector2(b.x,b.z)
		if Geometry2D.segment_intersects_segment(p,q,from,to) != null: return true
		var near: Vector2 = Geometry2D.get_closest_point_to_segment(q,from,to)
		if near.distance_to(q) < reach: return true
	return false

# Whether a bandit may step from `a` to `b` (not into a lit beam).
func barred(a: Vector3, b: Vector3) -> bool:
	return lit and struck(a,b,BEAM_KEEP)

# The boulders' cells, to be saved.
func kept() -> Array:
	return boulders.map(func(b): return [b.cell.x,b.cell.y])

# --- Holding a boulder -----------------------------------------------------------------

# The boulder he stands close enough to take hold of ({} if none).
func near_boulder(at: Vector3) -> Dictionary:
	for b in boulders:
		if b.t >= 1.0 and Vector2(b.to.x-at.x,b.to.z-at.z).length() < BOULDER_RADIUS+GRIP_REACH: return b
	return {}

func take_hold(b: Dictionary) -> void:
	held = b
	moves.clear()
	braced = false
	if pose == null: pose = preload("res://scripts/push_pose.gd").new(game.player.visual)
	game.route.clear()
	game.target = null
	# Set against it from where he stands: a turn to face it squarely.
	var gap: Vector3 = b.to-game.player.position
	var way = Vector2i(signi(roundi(gap.x)),0) if absf(gap.x) >= absf(gap.z) else Vector2i(0,signi(roundi(gap.z)))
	if way == Vector2i.ZERO: way = Vector2i.UP
	var spot: Vector3 = b.to-Vector3(way.x,0,way.y)*STAND
	if world.fits(spot): game.route = world.path(game.player.position,spot)

func let_go() -> void:
	grinding(false)
	held = {}
	moves.clear()
	braced = false
	if pose != null: pose.release()

func holding() -> bool:
	return not held.is_empty()

# He is set against the stone, his hands on it: the puzzle, not his orders,
# turns him and walks him.
func gripping() -> bool:
	return holding() and braced

# A click on the floor while he holds the boulder: roll it there, or as near
# as it will go.
func roll_to(point: Vector3) -> void:
	if not holding(): return
	var goal: Vector2i = layout.to_cell(point-Vector3(.5,0,.5))
	moves = plan(held,goal)
	if moves.is_empty() and goal != held.cell: game.toast("The boulder cannot be rolled there.")

# Where he stands for a move of `m` from `cell`: behind it, to push it on;
# before it, to pull it back toward him.
func stand_point(cell: Vector2i, m: Vector2i, pull: bool) -> Vector3:
	return centre(cell)+Vector3(m.x,0,m.y)*(STAND if pull else -STAND)

# The tiles he stands on to move a boulder at `cell` by `m`: the two along
# its back (pushing) or its front (pulling).
static func stand_cells(cell: Vector2i, m: Vector2i, pull: bool) -> Array[Vector2i]:
	var foot: Array[Vector2i] = footprint(cell)
	var out: Array[Vector2i] = []
	for c in foot:
		var s: Vector2i = c+(m if pull else -m)
		if not s in foot: out.append(s)
	return out

# Whether a boulder may lie on `c` (Layout.rolling_room).
func may_roll(c: Vector2i) -> bool:
	return layout.rolling_room.is_empty() or layout.in_any(layout.rolling_room,c)

func open_tile(c: Vector2i, index: int) -> bool:
	if not layout.cells.has(c): return false
	for i in boulders.size():
		if i != index and Rect2i(boulders[i].cell,Vector2i(2,2)).has_point(c): return false
	return true

# Whether he can walk, with the boulder at `cell`, from `from` to any of
# `goals`, keeping within ROUND_REACH tiles of it.
func can_get_round(cell: Vector2i, index: int, from: Vector2i, goals: Array[Vector2i], memo: Dictionary) -> bool:
	if from in goals: return true
	var key = [cell,from,goals[0]]
	if memo.has(key): return memo[key]
	var block = Rect2i(cell,Vector2i(2,2))
	var seen = {from:true}
	var queue: Array[Vector2i] = [from]
	var found = false
	while not queue.is_empty() and not found:
		var at: Vector2i = queue.pop_front()
		for d in Layout.DIRS:
			var next: Vector2i = at+d
			if seen.has(next) or block.has_point(next) or not open_tile(next,index): continue
			if absi(next.x-cell.x) > ROUND_REACH or absi(next.y-cell.y) > ROUND_REACH: continue
			if next in goals:
				found = true
				break
			seen[next] = true
			queue.append(next)
	memo[key] = found
	return found

# The moves that take boulder `b` to `goal` (or, if it cannot get there, as
# near as it can), fewest first, pulls only where they must be made: an A*
# search over where the boulder lies and the way it last went, the hero
# going round it between moves where he can.
func plan(b: Dictionary, goal: Vector2i) -> Array:
	var index: int = boulders.find(b)
	var hero: Vector2i = layout.to_cell(game.player.position)
	if Rect2i(b.cell,Vector2i(2,2)).has_point(hero) or not layout.cells.has(hero):
		for d in Layout.DIRS:
			if open_tile(hero+d,index) and not Rect2i(b.cell,Vector2i(2,2)).has_point(hero+d): hero = hero+d; break
	var far = func(c: Vector2i) -> int: return absi(c.x-goal.x)+absi(c.y-goal.y)
	# A state: where the boulder lies and the move that put it there (-1 at
	# first); for each, its cost, where the hero then stands, and whence.
	var first = [b.cell,-1]
	var cost = {first:0}
	var stands = {first:hero}
	var parent = {}
	var buckets = {far.call(b.cell):[first]}
	var lowest: int = far.call(b.cell)
	var best = first
	var memo = {}
	var expanded = 0
	var options: Array = []
	for d in 4:
		for pulling in [false,true]: options.append({"m":Layout.DIRS[d],"pull":pulling,"code":d*2+(1 if pulling else 0)})
	while expanded < PLAN_LIMIT:
		while not buckets.has(lowest) or buckets[lowest].is_empty():
			buckets.erase(lowest)
			if buckets.is_empty(): break
			lowest = buckets.keys().min()
		if buckets.is_empty(): break
		var state: Array = buckets[lowest].pop_back()
		var cell: Vector2i = state[0]
		var g: int = cost[state]
		if lowest > g+far.call(cell): continue
		expanded += 1
		if far.call(cell) < far.call(best[0]) or (far.call(cell) == far.call(best[0]) and g < cost[best]): best = state
		if cell == goal: break
		for o in options:
			var m: Vector2i = o.m
			var to: Vector2i = cell+m
			var free = true
			for c in footprint(to):
				if not open_tile(c,index) or not may_roll(c): free = false
			if not free: continue
			var spots: Array[Vector2i] = stand_cells(cell,m,o.pull)
			if not spots.all(func(c): return open_tile(c,index)): continue
			# (Pulling, he steps back a tile as it comes.)
			if o.pull and not spots.all(func(c): return open_tile(c+m,index)): continue
			if state[1] != o.code and not can_get_round(cell,index,stands[state],spots,memo): continue
			var next = [to,o.code]
			var step: int = g+(PULL_COST if o.pull else 1)
			if cost.has(next) and cost[next] <= step: continue
			cost[next] = step
			stands[next] = spots[0]+m
			parent[next] = [state,{"m":m,"pull":o.pull}]
			var f: int = step+far.call(to)
			if not buckets.has(f): buckets[f] = []
			buckets[f].append(next)
			lowest = mini(lowest,f)
	var path: Array = []
	var at = best
	while parent.has(at):
		path.push_front(parent[at][1])
		at = parent[at][0]
	return path

# Each frame he holds a boulder: rolling it, he goes with it, leaning in;
# between moves he goes round to where the next is made from, sets himself
# and heaves it on.
func work(dt: float) -> void:
	var b: Dictionary = held
	var hero = game.player
	# Heard while it is being moved, as in Boulders: its two grinding
	# recordings looped together, quietly (boulder-roll-short and -medium).
	grinding(b.t < 1.0 or (braced and not moves.is_empty()))
	if b.t < 1.0:
		var way = Vector3(b.dir.x,0,b.dir.y)
		hero.position = here(b)+way*(STAND if b.pull else -STAND)
		hero.face(hero.position-way if b.pull else hero.position+way)
		braced = true
		hero.visual.walking = true
		pose.update(dt,true,b.node.position,BOULDER_RADIUS,b.pull)
		# (Pulling, he walks backward: the stride runs in reverse.)
		hero.visual.locomotion(true,false,false,1.0,-PULL_SPEED if b.pull else PUSH_SPEED)
		return
	var near: bool = Vector2(b.to.x-hero.position.x,b.to.z-hero.position.z).length() < STAND+.25
	if moves.is_empty():
		# Standing by it, his hands on it, until he lets go or is told where.
		braced = near and game.route.is_empty()
		if braced:
			hero.face(Vector3(b.to.x,0,b.to.z))
			hero.visual.locomotion(false,false)
		pose.update(dt,braced,b.node.position,BOULDER_RADIUS,false)
		return
	var move: Dictionary = moves[0]
	var spot: Vector3 = stand_point(b.cell,move.m,move.pull)
	if Vector2(spot.x-hero.position.x,spot.z-hero.position.z).length() > .15:
		# Round to it: his hands off the stone as he goes.
		braced = false
		pose.update(dt,false,b.node.position,BOULDER_RADIUS,false)
		if game.route.is_empty() or game.route[-1].distance_to(spot) > .05:
			game.route = world.path(hero.position,spot)
			if game.route.is_empty():
				moves.clear()
				game.toast("He cannot get round to that side of the boulder.")
		return
	if not game.route.is_empty(): return
	var index: int = boulders.find(b)
	var clear: bool = footprint_free(b.cell+move.m,index,false,move.pull)
	if move.pull:
		for c in stand_cells(b.cell,move.m,true):
			if not open_tile(c+move.m,index): clear = false
	if not clear:
		moves.clear()
		game.toast("Something is in the boulder's way.")
		return
	# Set against it, he heaves.
	braced = true
	hero.position = Vector3(spot.x,hero.position.y,spot.z)
	moves.pop_front()
	start_roll(b,b.cell+move.m,PULL_SPEED if move.pull else PUSH_SPEED,move.pull)

# Marks the tiles about a boulder at `cell` walkable or not on the floor's
# navigation, as it lies now (Temple.bar_gate does so for the gate).
func nav_mark(cell: Vector2i) -> void:
	if not world.nav.region.has_area(): return
	for y in range(cell.y-2,cell.y+4):
		for x in range(cell.x-2,cell.x+4):
			var at: Vector3 = layout.to_world(Vector2i(x,y))
			var point = Vector2i(roundi(at.x),roundi(at.z))
			if world.nav.is_in_boundsv(point): world.nav.set_point_solid(point,not world.fits(at,.4))

# The sound of a boulder grinding over the floor, from Boulders.
const GRIND = ["boulder-roll-short","boulder-roll-medium"]
const GRIND_VOLUME = -16.0
var grinding_now = false
func grinding(on: bool) -> void:
	if on == grinding_now: return
	grinding_now = on
	for id in GRIND: game.sound.looping(id,on,GRIND_VOLUME)

func _exit_tree() -> void:
	if grinding_now and is_instance_valid(game): grinding(false)
