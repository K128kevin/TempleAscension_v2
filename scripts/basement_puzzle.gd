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
## A boulder is rolled a tile at a time on the floor's grid (it covers 2x2
## tiles), the way the hero leans into it (walking into it for PUSH_LEAN
## seconds). Rolled into a wall or the other boulder, it rebounds a tile back
## toward him, shoving him back, so that it can never be wedged where it
## cannot be got behind.
const Layout = preload("res://scripts/layout.gd")
const Art = preload("res://scripts/assets.gd")
const Kit = preload("res://scripts/world_art.gd")
const Gaze = preload("res://scripts/boss_laser.gd")
const BOULDER_RADIUS = .92
const PUSH_LEAN = .18
# Metres a second, rolling on and rebounding.
const ROLL_SPEED = 2.2
const REBOUND_SPEED = 1.2
# How near the hero must be to lean into a boulder, beyond touching it, and
# how squarely he must be walking into it.
const LEAN_REACH = .14
const LEAN_SQUARE = .55
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
var lean_time = 0.0
var last_hero = Vector3.INF

# `kept`: boulders' top-left cells as saved, in place of where they start.
func setup(owner_game, owner_world, kept: Array = []) -> void:
	game = owner_game
	world = owner_world
	layout = world.layout
	name = "BasementPuzzle"
	var stone: Material = Kit.rock("boulder_a",Color(.86,.8,.72),0.0)
	for i in layout.boulders.size():
		var cell: Vector2i = layout.boulders[i]
		if i < kept.size() and kept[i] is Vector2i and footprint_free(kept[i],i,true): cell = kept[i]
		var node = boulder_model(i,stone)
		add_child(node)
		var b = {"cell":cell,"node":node,"from":centre(cell),"to":centre(cell),"t":1.0,"speed":ROLL_SPEED,"dir":Vector2i.ZERO}
		node.position = b.to+Vector3.UP*BOULDER_RADIUS
		boulders.append(b)
		world.visibility_nodes.append(node)
	for cell in layout.buttons:
		var plate = plate_model()
		add_child(plate.root)
		plate.root.position = centre(cell)
		plates.append({"cell":cell,"root":plate.root,"top":plate.top,"lamp":plate.lamp,"down":false,"sink":0.0})
		world.visibility_nodes.append(plate.root)
		world.visibility_cells[plate.root] = footprint(cell)
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

# A boulder: one of the cave's rocks, rounded and sized to a ball, its
# middle at the node's origin so that it rolls about it.
func boulder_model(index: int, stone: Material) -> Node3D:
	var root = Node3D.new()
	root.name = "Boulder%d" % index
	var id: String = ["boulder_c","boulder_a"][index%2]
	var rock: Node3D = Art.model(id,Vector3.ONE*BOULDER_RADIUS*2.0,stone)
	root.add_child(rock)
	var box = AABB()
	var first = true
	for part in rock.find_children("*","MeshInstance3D",true,false):
		# (Its place within the rock, the rock not yet in the tree.)
		var into = Transform3D.IDENTITY
		var node: Node = part
		while node != rock:
			into = node.transform*into
			node = node.get_parent()
		var local: AABB = into*part.get_aabb()
		box = local if first else box.merge(local)
		first = false
	rock.position = -(rock.transform.basis*box.get_center())
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
	groove.position = Vector3.UP*.07
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
	if not hero.dead: lean(dt)
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

# The hero leaning into a boulder: walking into it, squarely, for PUSH_LEAN
# seconds rolls it on a tile the way he leans.
func lean(dt: float) -> void:
	var hero: Vector3 = game.player.position
	var intent: Vector3 = game.walk_intent
	var pushing = null
	var way = Vector2i.ZERO
	if intent.length_squared() > .01:
		for b in boulders:
			if b.t < 1.0: continue
			var gap: Vector3 = b.to-hero
			gap.y = 0
			if gap.length() > BOULDER_RADIUS+.4+LEAN_REACH: continue
			var dir = Vector2i(signi(roundi(gap.x)),0) if absf(gap.x) >= absf(gap.z) else Vector2i(0,signi(roundi(gap.z)))
			if dir == Vector2i.ZERO: continue
			if intent.normalized().dot(Vector3(dir.x,0,dir.y)) < LEAN_SQUARE: continue
			pushing = b
			way = dir
			break
	if pushing == null:
		lean_time = 0.0
		return
	lean_time += dt
	if lean_time < PUSH_LEAN: return
	lean_time = 0.0
	push(pushing,way)

func push(b: Dictionary, dir: Vector2i) -> void:
	var index: int = boulders.find(b)
	if footprint_free(b.cell+dir,index):
		game.sound.play("rock-impact",-20)
		start_roll(b,b.cell+dir,ROLL_SPEED)
		return
	# Into a wall or the other boulder: it knocks and rebounds a tile toward
	# him, shoving him back, if he and it have the room.
	game.sound.play("rock-impact",-10)
	var back = Vector3(-dir.x,0,-dir.y)
	var hero = game.player
	var clear: Vector3 = world.move(hero.position,back*1.05)
	if clear.distance_to(hero.position) < 1.0 or not footprint_free(b.cell-dir,index,false,true): return
	hero.shove(back,1.0)
	start_roll(b,b.cell-dir,REBOUND_SPEED)

func start_roll(b: Dictionary, cell: Vector2i, speed: float) -> void:
	b.dir = cell-b.cell
	b.cell = cell
	b.from = b.to
	b.to = centre(cell)
	b.t = 0.0
	b.speed = speed

func roll(b: Dictionary, dt: float) -> void:
	if b.t >= 1.0: return
	var before: Vector3 = here(b)
	b.t = minf(1.0,b.t+dt*b.speed)
	var after: Vector3 = here(b)
	var node: Node3D = b.node
	node.position = after+Vector3.UP*BOULDER_RADIUS
	# Rolling: turned about the level line across its way, a radian for each
	# radius it has gone.
	var travel: Vector3 = after-before
	if travel.length_squared() > 0.0:
		var axis: Vector3 = Vector3.UP.cross(travel.normalized())
		node.basis = Basis(axis,travel.length()/BOULDER_RADIUS)*node.basis
		node.basis = node.basis.orthonormalized()
	world.visibility_cells[node] = footprint(b.cell)

func here(b: Dictionary) -> Vector3:
	return b.from.lerp(b.to,smoothstep(0.0,1.0,b.t))

# Whether a boulder (`index`, not counted itself) may lie at `cell`: on floor,
# clear of the other boulder and of the living. (`starting`: as it is set
# down, before anyone stands about; `rebound`: the hero, being shoved back
# out of the way, does not count.)
func footprint_free(cell: Vector2i, index: int, starting: bool = false, rebound: bool = false) -> bool:
	for c in footprint(cell):
		if not layout.cells.has(c): return false
	var mid: Vector3 = centre(cell)
	for i in boulders.size():
		if i == index: continue
		if Rect2i(cell,Vector2i(2,2)).intersects(Rect2i(boulders[i].cell,Vector2i(2,2))): return false
	if starting: return true
	for e in game.enemies:
		if not e.dead and Vector2(e.position.x-mid.x,e.position.z-mid.z).length() < BOULDER_RADIUS+.45: return false
	if not rebound and is_instance_valid(game.player):
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
			if hero != null: game.sound.play("rock-impact",-16)
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
