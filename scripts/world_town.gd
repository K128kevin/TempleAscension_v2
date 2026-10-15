extends RefCounted
## The town at the western end of the outdoor world (scripts/overworld.gd).
## The arena stands at its centre, kept up at the elders' expense, with their
## box in its north stands; a broad street rings it. The inn, two shops and the
## houses stand round that street and along the alleys that run off it, and
## most of them are in a poor way: stained, cracked, some fallen in. A market
## square with the well fills the south-east corner, the greengrocers' stalls
## below it, and a wall with one gate
## closes the town off from the desert. A wall rings the whole town besides,
## its corners towered (town_wall): along its north and south sides, its west
## end, and out round the palace hill's ground; a second gate in its south
## side opens on the alley to the southern desert. Two guards stand at each
## gate. From the
## arena's north gate a road
## climbs to the elders' palace (scripts/world_palace.gd). The town's people
## have yet to arrive.
const Kit = preload("res://scripts/world_art.gd")
const Desert = preload("res://scripts/world_desert.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const Guard = preload("res://scripts/town_guard.gd")
const Art = preload("res://scripts/assets.gd")
# One wall module of the kit is this wide and tall.
const BAY = 4.0
# What the town's walls are built and washed with.
const LIMEWASH = Color(.80,.77,.71)
const CREAM = Color(.78,.72,.61)
const OCHRE = Color(.74,.63,.48)
const MUD = Color(.68,.57,.44)
const DUN = Color(.72,.65,.54)
# Every door and shutter is bare or oiled wood, in one brown or another.
const BROWN = Color(.30,.19,.11)
const WOODS = [Color(.30,.19,.11),Color(.23,.15,.09),Color(.38,.26,.15),Color(.34,.27,.20),Color(.37,.21,.12),Color(.27,.20,.14)]
# How far a wall has been let go, for Kit.masonry: the arena and the palace
# are kept spotless; the town is not.
const KEPT = .06
const WORN = .5
# The arena's dressed stone, and the royal crimson.
const ARENA_STONE = Color(.88,.83,.74)
const CRIMSON = Color(.42,.06,.08)
# The arena, at the centre of the town. Its oval of sand is sixty metres by
# forty-eight: room for the hero and a crowd of fighters.
const ARENA = Vector3(-254,0,0)
const ARENA_FLOOR = Vector2(30,24)
# The wall round the sand, which the lowest seats stand on.
const PODIUM = 3.0
# Two banks of seating rise behind it: each this deep, and this much higher.
const TIER = Vector2(6.5,3.6)
# The arena's outer wall, two storeys of arcade, and its outer radii.
const ARENA_WALL = 11.6
const ARENA_RADII = Vector2(45.2,39.2)
# Segments round the oval; a gate at each compass point.
const ARENA_BAYS = 60
const ARENA_GATES = [0,15,30,45]
# The bays the royal box takes up, over the north gate.
const BOX_BAYS = [44,45,46]
# The doorway from each gateway into the space under the stands: how far in
# from the outer wall it starts and ends.
const UNDER_DOOR = Vector2(3.2,6.0)
# Half the royal box's width, and the height of its floor.
const BOX_HALF = 7.1
const BOX_FLOOR = 6.6
const THRONES = 5
# The thrones' height (tools/make_throne.py's elders' throne, its seat at a
# chair's height), how far apart they stand, and the height of the
# marble-topped table before them.
const THRONE_HEIGHT = 1.19
const THRONE_SPACING = 1.3
const TABLE_HEIGHT = .78
# The street that rings the arena: the buildings stand along its far side.
const RING = 14.0
const MARKET = Rect2(-205,38,21,24)
# The alleys off the ring street, each lane's rectangle: the four lanes north
# and south of it, West Street out to the river, the quay along the river and
# the lane behind its houses, South Street, and the lanes inside the south
# wall either side of its gate.
const ALLEYS = [Rect2(-214,-76,4,36),Rect2(-298,-76,4,36),Rect2(-298,40,4,46),Rect2(-228,46,4,58),Rect2(-366,-2.5,54,5),
	Rect2(-370,-76,6,182),Rect2(-354,-76,4,162),Rect2(-366,86,180,5),Rect2(-366,102,128,4),Rect2(-218,102,32,4)]
# The letters of a face: w wall, d door, s shuttered window, a arched recess,
# o open arched window, p open portal, b a wall broken down.
const MODULES = {"w":"wall","d":"wall_door","s":"wall_window","a":"wall_arched","o":"wall_archwindow","p":"arch","b":"wall_broken"}

static func build(world) -> void:
	streets(world)
	gate_wall(world)
	town_wall(world)
	south_gate(world)
	arena(world)
	royal_box(world)
	market(world)
	greengrocers(world)
	inn(world)
	armorer(world)
	provisioner(world)
	houses(world)
	greenery(world)

# A flat-roofed block of wall modules. `corner` is its north-west corner on
# the ground and `bays` its size in modules; `south` and `west` spell the
# faces the camera sees, a string for each storey, bottom first. Its north
# and east faces, which the camera never sees, are built only when `open`
# (a roofless shell, seen into from above). `wear` is how far it has been let
# go. Returns its nodes.
static func block(world, corner: Vector3, bays: Vector2i, south: Array, west: Array, tint: Color, wood: Color, base: float = 0.0, wear: float = WORN, open: bool = false) -> Array:
	var ground: float = world.lift(corner)
	var material = Kit.masonry(tint,wood,.4,snappedf(wear,.05),ground)
	var size = Vector2(bays.x*BAY,bays.y*BAY)
	var nodes: Array = []
	var storeys = south.size()
	for storey in storeys:
		var y = base+storey*BAY
		for i in bays.x:
			var x = corner.x+BAY*.5+i*BAY
			nodes.append(world.place(MODULES[south[storey][i]],Vector3(x,y,corner.z+size.y-.5),Vector3(BAY,BAY,1),material))
			if open: nodes.append(world.place("wall_broken" if i%2==0 else "wall",Vector3(x,y,corner.z+.5),Vector3(BAY,BAY,1),material,PI))
		for i in bays.y:
			var z = corner.z+BAY*.5+i*BAY
			nodes.append(world.place(MODULES[west[storey][i]],Vector3(corner.x+.5,y,z),Vector3(BAY,BAY,1),material,-PI/2))
			if open: nodes.append(world.place("wall" if i%2==0 else "wall_broken",Vector3(corner.x+size.x-.5,y,z),Vector3(BAY,BAY,1),material,PI/2))
	# The roof lies below the top course, which stands round it as a parapet.
	if not open:
		nodes.append(world.place("floor",Vector3(corner.x+size.x*.5,base+storeys*BAY-1.0,corner.z+size.y*.5),Vector3(size.x-1.0,.3,size.y-1.0),Kit.masonry(tint*Color(.9,.87,.82),wood,.4,snappedf(wear,.05),ground)))
	if base==0.0: world.block_rect(Rect2(corner.x,corner.z,size.x,size.y))
	return nodes

# Where to stand in front of bay `bay` of a block's south or west face.
static func doorstep(corner: Vector3, bays: Vector2i, face: String, bay: int) -> Vector3:
	if face=="south": return Vector3(corner.x+BAY*.5+bay*BAY,0,corner.z+bays.y*BAY+1.4)
	return Vector3(corner.x-1.4,0,corner.z+BAY*.5+bay*BAY)

# A small thing standing on the ground: furniture, pots, a stall.
static func item(world, id: String, at: Vector3, height: float, yaw: float = 0.0, solid: float = .45) -> Node3D:
	var node = world.prop(id,at,height,yaw)
	if solid>0: world.block_disc(Vector3(at.x,0,at.z),solid,world.LOW)
	return node

# A cloth hung flat on a south (`yaw` 0) or west (`yaw` -PI/2) wall.
static func hanging(world, id: String, at: Vector3, height: float, yaw: float, dye: Color = Color(.50,.13,.10)) -> Node3D:
	var node = world.prop(id,at,height,yaw)
	Kit.dye(node,dye)
	return node

# A length of wall built of the kit's modules, each near its own four metres
# square so its carved stones keep their shape: centred on `middle` at the
# wall's foot, `length` long and `height` high, facing as `yaw` turns it.
static func wall_run(world, middle: Vector3, length: float, height: float, thickness: float, material: Material, yaw: float = 0.0) -> Array:
	var columns = maxi(1,roundi(length/BAY))
	var rows = maxi(1,roundi(height/3.6))
	var along = Vector3(cos(yaw),0,-sin(yaw))
	var nodes: Array = []
	for row in rows:
		for column in columns:
			var at = middle+along*((column+.5)/columns-.5)*length+Vector3.UP*row*height/rows
			nodes.append(world.place("wall",at,Vector3(length/columns,height/rows,thickness),material,yaw))
	return nodes

# Whether a point lies between the arena's wall and the buildings round it.
static func on_ring(x: float, z: float) -> bool:
	var offset = Vector2(x-ARENA.x,z-ARENA.z)
	return (offset/ARENA_RADII).length()>=1.0 and (offset/(ARENA_RADII+Vector2(RING,RING))).length()<=1.0

static func streets(world) -> void:
	# The ring street and the main street in from the gate are paved; the
	# alleys are trodden dirt, with what is left of their paving.
	for z in range(int(ARENA.z-ARENA_RADII.y-RING)-1,int(ARENA.z+ARENA_RADII.y+RING)+2):
		for x in range(int(ARENA.x-ARENA_RADII.x-RING)-1,int(ARENA.x+ARENA_RADII.x+RING)+2):
			if on_ring(x,z): world.dab(world.PAVING,x,z,.9)
	world.dab_rect(world.PAVING,Rect2(-200,-5,24,10))
	world.dab_rect(world.PAVING,MARKET)
	world.dab_rect(world.PAVING,Rect2(-208,34,6,8),.8)
	for alley in ALLEYS:
		var lane: Rect2 = alley
		world.dab_rect(world.TRACK,lane.grow(1.0),.85)
		world.dab_rect(world.PAVING,lane,.42)
		world.add_place("alley","alley",Vector3(lane.get_center().x,0,lane.get_center().y),maxf(lane.size.x,lane.size.y)*.5)
	# Outside the gate the paving gives way to the track.
	for x in range(-176,-166):
		for z in range(-4,5): world.dab(world.PAVING,x,z,.75-(x+176)*.07)

# The wall across the mouth of the basin, with the gate in its middle.
static func gate_wall(world) -> void:
	var material = Kit.masonry(CREAM,BROWN,.4,.65)
	var x = world.TOWN_GATE.x
	# (From corner to corner of the town's wall, no further.)
	var z = world.WALL_NORTH
	while z<world.WALL_SOUTH-.1:
		var bay = minf(BAY,world.WALL_SOUTH-z)
		var middle = z+bay*.5
		z += bay
		if absf(middle)<5.0 or world.margin_at(Vector3(x,0,middle))<-9.0: continue
		var piece = world.place("wall",Vector3(x,0,middle),Vector3(bay,5.6,1.4),material,-PI/2)
		world.wall(Rect2(x-.7,middle-bay*.5,1.4,bay))
		world.screen([piece])
	# Two towers flank the gateway, joined by a lintel over the road.
	var towers: Array = []
	for side in [-1.0,1.0]:
		var at = Vector3(x,0,side*6.2)
		towers.append(world.place("pillar_decorated",at,Vector3(3.6,8.6,3.4),material,-PI/2))
		world.wall(Rect2(x-1.7,at.z-1.8,3.4,3.6))
		world.brazier(at+Vector3(-2.8,0,side*.2),1.0,1.1)
		hanging(world,"cloth_red",Vector3(x-1.85,2.6,side*6.2),4.4,-PI/2,Color(.44,.14,.10))
		# A guard before each tower, on the town side, watching the way through.
		guard(world,Vector3(x-2.3,0,side*4.75),Vector3(-.45,0,-side),.25+side*.2)
	towers.append(world.place("wall",Vector3(x,6.2,0),Vector3(9.4,1.5,1.4),material,-PI/2))
	world.screen(towers)
	world.add_place("town gate","gate",Vector3(x,0,0),7.0)

# The wall round the town, where the rim's rocks would stand (the world's
# `walled`): built of the gate wall's modules, a tower at every corner. It
# runs along the north and south sides from the gate wall west to the river,
# where each ends in a tower at the water, but for the palace hill's ground,
# which the elders' white wall closes (Palace.precinct); the south gate
# (south_gate) fills a gap left in the south side.
# It is old: its stone far more worn than the gate's, its top uneven, and
# here and there a stretch fallen into a ragged breach (ruin).
static func town_wall(world) -> void:
	var material = Kit.masonry(CREAM,BROWN,.4,.92)
	var north: float = world.WALL_NORTH
	var south: float = world.WALL_SOUTH
	var east: float = world.TOWN_GATE.x
	var hill_west: float = world.HILL.x-world.HILL_REACH.x
	var hill_east: float = world.HILL.x+world.HILL_REACH.x
	var hill_north: float = world.HILL_REACH.y
	# Each side runs out to the river and ends in a tower at the water.
	# (Round the palace hill's ground the elders' own white wall stands
	# instead: Palace.precinct.)
	var runs: Array = [
		[Vector3(east,0,north),Vector3(hill_east,0,north)],
		[Vector3(hill_west,0,north),Vector3(river_end(world,north),0,north)],
		[Vector3(river_end(world,south),0,south),Vector3(east,0,south)]]
	# The south gate's own wall and towers take its stretch of the south side.
	var openings: Array = [Rect2(SOUTH_GATE.x-20.0,south-2.0,40.0,4.0)]
	var towers: Array = []
	for corners in runs:
		walls_between(world,corners,openings,material)
		# A tower at every corner but the gate wall's north end, among the
		# rocks.
		for i in corners.size():
			var corner: Vector3 = corners[i]
			if corner != Vector3(east,0,north) and not (corner.z == north and absf(absf(corner.x-world.HILL.x)-world.HILL_REACH.x) < .1): towers.append(corner)
	for at in towers:
		var tower = world.place("pillar_decorated",at,Vector3(3.6,8.6,3.4),material)
		world.wall(Rect2(at.x-1.8,at.z-1.7,3.6,3.4))
		world.screen([tower])

# Where a wall along `z` ends at the river: a little way into the water.
static func river_end(world, z: float) -> float:
	return roundf(world.river_x(z)+world.RIVER_HALF-1.0)

# The wall from corner to corner of `corners`, bay by bay, leaving `openings`.
static func walls_between(world, corners: Array, openings: Array, material: Material) -> void:
	for i in corners.size()-1:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[i+1]
		var along: Vector3 = (b-a).normalized()
		var length: float = a.distance_to(b)
		var yaw: float = 0.0 if absf(along.x) > .5 else -PI/2
		var run = 0.0
		while run < length-.1:
			var bay: float = minf(BAY,length-run)
			var middle: Vector3 = a+along*(run+bay*.5)
			run += bay
			var skipped = false
			for opening in openings:
				if opening.has_point(Vector2(middle.x,middle.z)): skipped = true
			if skipped: continue
			# (The wall's worn line along its length decides a bay's state,
			# the same every time: whole and capped where it still stands to
			# its full height, its top crumbled wherever it is lower.)
			var along_x: bool = yaw == 0.0
			var length_way = Vector3(cos(yaw),0,-sin(yaw))
			# (Its wear eases off toward the towers and the gates' walls,
			# which stand whole, so it rises to meet them.)
			var profile = func(offset: float) -> float:
				var p: Vector3 = middle+length_way*offset
				var near = minf(p.distance_to(a),p.distance_to(b))
				for opening in openings:
					var box: Rect2 = opening
					near = minf(near,Vector2(maxf(maxf(box.position.x-p.x,p.x-box.end.x),0.0),maxf(maxf(box.position.y-p.z,p.z-box.end.y),0.0)).length())
				return WALL_FULL-(WALL_FULL-wall_top(p,along_x))*smoothstep(1.5,14.0,near)
			var lowest = WALL_FULL
			for k in 9: lowest = minf(lowest,profile.call(bay*(k/8.0-.5)))
			var piece: Node3D
			if lowest >= WALL_FULL-.01: piece = world.place("wall",middle,Vector3(bay,WALL_FULL,1.4),material,yaw)
			# Worn a little, the wall's own courses are worn down with the line
			# (its cap chipped, then gone); further down, it is crumbled stone.
			elif lowest > WALL_FULL-WORN_DEPTH: piece = worn_wall(world,middle,bay,yaw,profile,material)
			else: piece = ruin(world,middle,bay,yaw,profile,material)
			world.wall(Rect2(middle.x-(bay*.5 if yaw == 0.0 else .7),middle.z-(.7 if yaw == 0.0 else bay*.5),bay if yaw == 0.0 else 1.4,1.4 if yaw == 0.0 else bay))
			world.screen([piece])

# The town wall's height along its length: its full height (WALL_FULL)
# where it still stands whole, worn down over long stretches, here and there
# broken into a deep breach, and uneven everywhere it has crumbled. A wall
# along x reads its line by x, one along z by z (each line its own).
const WALL_FULL = 6.0
static var wear_noise: Array = []
static func wall_top(at: Vector3, along_x: bool) -> float:
	if wear_noise.is_empty():
		for k in 4:
			var n = FastNoiseLite.new()
			n.seed = 300+k
			n.frequency = [.018,.013,.15,.06][k]
			n.fractal_octaves = [2,1,2,1][k]
			wear_noise.append(n)
	var s: float = (at.x if along_x else at.z)+(at.z if along_x else at.x)*3.7
	var wear = smoothstep(-.1,.7,wear_noise[0].get_noise_1d(s))
	var breach = smoothstep(.3,.95,wear_noise[1].get_noise_1d(s+500.0))
	var rough = wear_noise[2].get_noise_1d(s)
	var loss = wear*2.1+breach*breach*3.2+rough*.35*clampf(wear*2.5+breach,0.0,1.0)
	# Here and there along the whole wall its cap is chipped.
	var chipped = smoothstep(.25,.7,wear_noise[3].get_noise_1d(s+90.0))*(.25+.2*(wear_noise[2].get_noise_1d(s*3.0)*.5+.5))
	return clampf(WALL_FULL-maxf(loss,chipped),1.3,WALL_FULL)

# How far down a bay's line may run and its own courses still be worn to it
# (worn_wall), rather than crumbled (ruin).
const WORN_DEPTH = 1.1

# A bay of the town wall worn down to `profile` (as ruin's): the wall
# module itself, every point of it above the line brought down to it, a
# little unevenly, so its cap is chipped where the line dips under it and
# gone where it runs lower, and the courses go on unbroken into the crumbled
# bays beside it.
static var wall_arrays: Array = []
static func worn_wall(world, middle: Vector3, bay: float, yaw: float, profile: Callable, material: Material) -> Node3D:
	if wall_arrays.is_empty(): wall_arrays = Kit.mesh_of("wall").surface_get_arrays(0)
	var arrays: Array = wall_arrays.duplicate()
	var source: PackedVector3Array = wall_arrays[Mesh.ARRAY_VERTEX]
	var vertices = PackedVector3Array()
	vertices.resize(source.size())
	for i in source.size():
		var v: Vector3 = source[i]*Vector3(bay,WALL_FULL,1.4)
		var top: float = profile.call(v.x)+.05*sin(v.x*7.3+v.z*11.0)
		if v.y > top: v.y = top
		vertices[i] = v
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	world.add_child(node)
	node.position = middle+Vector3.UP*world.lift(middle)
	node.rotation.y = yaw
	return node

# A crumbled bay of the town wall, `bay` long and 1.4 thick, centred on
# `middle` at its foot and turned by `yaw` as a wall module is. Its top is
# what is left of its courses, following `profile` (its height at an offset
# along it from its middle), one piece with no seams: its two faces each
# broken to their own line just off it, the rubble core between them lower,
# here and there a stretch chipped further down. The stones it shed lie at its
# foot, the more the lower it has fallen.
const RUIN_SINK = .3
# Texels of the wall kit's palette that are plain stone, light to dark (the
# masonry shader reads the palette's light and dark stones faintly).
const RUIN_STONES = [Vector2(.627,.004),Vector2(.107,.004),Vector2(.002,.04)]
static func ruin(world, middle: Vector3, bay: float, yaw: float, profile: Callable, material: Material, lowest: float = 1.2, highest: float = WALL_FULL-.03) -> Node3D:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(middle.x*10.0),roundi(middle.z*10.0)))
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Its top, sampled along it: the front and back faces each broken to
	# their own line a little off the wall's, the rubble core between them a
	# little lower, and here and there a stretch chipped further down.
	var count: int = maxi(2,ceili(bay/.3))
	var front: Array = []
	var back: Array = []
	var core: Array = []
	var chip = 0.0
	var chip_left = 0
	var low = WALL_FULL
	for i in count+1:
		var x = -bay*.5+bay*i/count
		var line: float = profile.call(x)
		if chip_left <= 0 and rng.randf() < .07:
			chip = rng.randf_range(.12,.4)
			chip_left = rng.randi_range(2,4)
		var dip = chip if chip_left > 0 else 0.0
		chip_left -= 1
		# (Its ends hold to the line exactly, to meet the next bay's.)
		var edge = i == 0 or i == count
		if edge: dip = 0.0
		var f = clampf(line-dip-(0.0 if edge else rng.randf_range(0.0,.1)),lowest,highest)
		var k = clampf(line-dip*.6-(0.0 if edge else rng.randf_range(0.0,.16)),lowest,highest)
		front.append(f)
		back.append(k)
		core.append(maxf(minf(f,k)-(.06 if edge else rng.randf_range(.04,.14)),lowest*.5))
		low = minf(low,minf(f,k))
	var stone: Vector2 = RUIN_STONES[rng.randi()%2]
	tool.set_uv(stone)
	var quad = func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
		for tri in [[a,b,c],[a,c,d]]:
			var p: Array = tri
			if (p[1]-p[0]).cross(p[2]-p[0]).dot(out) > 0.0: p = [p[0],p[2],p[1]]
			for v in p: tool.add_vertex(v)
	for i in count:
		var x0 = -bay*.5+bay*i/count
		var x1 = -bay*.5+bay*(i+1)/count
		# The faces.
		quad.call(Vector3(x0,-RUIN_SINK,.7),Vector3(x1,-RUIN_SINK,.7),Vector3(x1,front[i+1],.7),Vector3(x0,front[i],.7),Vector3(0,0,1))
		quad.call(Vector3(x0,-RUIN_SINK,-.7),Vector3(x1,-RUIN_SINK,-.7),Vector3(x1,back[i+1],-.7),Vector3(x0,back[i],-.7),Vector3(0,0,-1))
		# The broken top, front edge to core to back edge.
		quad.call(Vector3(x0,front[i],.7),Vector3(x1,front[i+1],.7),Vector3(x1,core[i+1],0),Vector3(x0,core[i],0),Vector3(0,1,0))
		quad.call(Vector3(x0,core[i],0),Vector3(x1,core[i+1],0),Vector3(x1,back[i+1],-.7),Vector3(x0,back[i],-.7),Vector3(0,1,0))
	# Its ends, against what stands either side.
	for end in [[0,-1.0],[count,1.0]]:
		var x = bay*.5*end[1]
		var j: int = end[0]
		quad.call(Vector3(x,-RUIN_SINK,.7),Vector3(x,front[j],.7),Vector3(x,core[j],0),Vector3(x,-RUIN_SINK,0),Vector3(end[1],0,0))
		quad.call(Vector3(x,-RUIN_SINK,0),Vector3(x,core[j],0),Vector3(x,back[j],-.7),Vector3(x,-RUIN_SINK,-.7),Vector3(end[1],0,0))
	tool.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = material
	world.add_child(node)
	node.position = middle+Vector3.UP*world.lift(middle)
	node.rotation.y = yaw
	node.set_meta("ruin",true)
	# The stones it shed, either side, the more the lower it has fallen:
	# a heap of rubble against its foot, and dressed blocks fallen whole and
	# lying where they rolled.
	var along = Vector3(cos(yaw),0,-sin(yaw))
	var across = Vector3(sin(yaw),0,cos(yaw))
	var shed = clampf((WALL_FULL-.4-low)/3.0,0.0,1.0)
	if shed < .08: return node
	for side in [-1.0,1.0]:
		var heap = middle+along*rng.randf_range(-bay*.25,bay*.25)+across*side*rng.randf_range(1.0,1.4)
		world.place("rubble",heap,Vector3(rng.randf_range(2.2,3.2),rng.randf_range(.4,.8)*shed+.15,rng.randf_range(1.0,1.5)),material,yaw+rng.randf_range(-.3,.3))
		for i in roundi(rng.randf_range(2.0,5.0)*shed):
			var block = MeshInstance3D.new()
			block.mesh = worn_block(Vector3(rng.randf_range(.45,.8),rng.randf_range(.28,.42),rng.randf_range(.32,.5)),rng,RUIN_STONES[rng.randi()%RUIN_STONES.size()])
			block.material_override = material
			world.add_child(block)
			var spot = middle+along*rng.randf_range(-bay*.45,bay*.45)+across*side*rng.randf_range(.95,2.6)
			block.position = spot+Vector3.UP*(world.lift(spot)-.06)
			block.rotation = Vector3(rng.randf_range(-.25,.25),rng.randf_range(0,TAU),rng.randf_range(-.25,.25))
	return node

# The gate in the town's south wall at the end of the southern alley, built
# as the town gate is: a stretch of wall, two towers flanking the way
# through, joined by a lintel. Its guards stand outside, facing the desert.
const SOUTH_GATE = Vector3(-226,0,108)
static func south_gate(world) -> void:
	var material = Kit.masonry(CREAM,BROWN,.4,.65)
	var g: Vector3 = SOUTH_GATE
	var x = g.x-20.0
	while x<g.x+20.0:
		var middle = x+BAY*.5
		x += BAY
		if absf(middle-g.x)<5.0 or world.margin_at(Vector3(middle,0,g.z))<-9.0: continue
		var piece = world.place("wall",Vector3(middle,0,g.z),Vector3(BAY,5.6,1.4),material)
		world.wall(Rect2(middle-BAY*.5,g.z-.7,BAY,1.4))
		world.screen([piece])
	var towers: Array = []
	for side in [-1.0,1.0]:
		var at = Vector3(g.x+side*6.2,0,g.z)
		towers.append(world.place("pillar_decorated",at,Vector3(3.6,8.6,3.4),material))
		world.wall(Rect2(at.x-1.8,g.z-1.7,3.6,3.4))
		world.brazier(at+Vector3(side*.2,0,2.8),1.0,1.1)
		hanging(world,"cloth_red",Vector3(at.x,2.6,g.z+1.85),4.4,0.0,Color(.44,.14,.10))
		guard(world,Vector3(g.x+side*4.75,0,g.z+2.3),Vector3(-side*.5,0,1),.6+side*.2)
	towers.append(world.place("wall",Vector3(g.x,6.2,g.z),Vector3(9.4,1.5,1.4),material))
	world.screen(towers)
	# The way through is paved, giving way to the track on either side.
	for z in range(int(g.z)-4,int(g.z)+5):
		for along in range(-4,5): world.dab(world.PAVING,int(g.x)+along,z,.85-absf(z-g.z)*.09)
	world.add_place("south gate","gate",g,7.0)

# A gate guard (scripts/town_guard.gd) standing at `at`, facing along `facing`.
# His spear and shield stand with him; nothing walks through them.
static func guard(world, at: Vector3, facing: Vector3, variant: float) -> Node3D:
	var man = Guard.new()
	man.name = "GateGuard"
	world.add_child(man)
	man.position = at+Vector3.UP*world.lift(at)
	man.rotation.y = atan2(facing.x,facing.z)
	man.setup(variant)
	world.block_disc(at+man.basis*Vector3(.1,0,.15),.65,world.LOW)
	# (Two to a post, one after the other: scripts/town_watch.gd.)
	world.guard_posts.append(man)
	return man

# A point on the arena's oval at `angle`, `inset` metres inside its outer wall.
static func oval(angle: float, inset: float = 0.0) -> Vector3:
	return ARENA+Vector3(cos(angle)*(ARENA_RADII.x-inset),0,sin(angle)*(ARENA_RADII.y-inset))

# The arena: two storeys of arcade round an oval of sand, with two banks of
# stone seating raised on a wall above it. A gate pierces it at each compass
# point: the eastern one faces the town gate, the northern one the palace
# road. Its stone is dressed and kept clean.
static func arena(world) -> void:
	var material = Kit.masonry(ARENA_STONE,BROWN,.4,KEPT)
	var shaded = Kit.masonry(ARENA_STONE*Color(.84,.82,.78),BROWN,.4,KEPT)
	world.upkeep["arena"] = KEPT
	var step = TAU/ARENA_BAYS
	var upper = 1.2+TIER.x*.5
	var lower = 1.2+TIER.x*1.5
	var podium = 1.2+TIER.x*2.0+.5
	for i in ARENA_BAYS:
		var angle = i*step
		# The modules face out along the oval's normal.
		var out = Vector3(cos(angle)/ARENA_RADII.x,0,sin(angle)/ARENA_RADII.y).normalized()
		var yaw = atan2(out.x,out.z)
		var gate = i in ARENA_GATES
		var nodes: Array = []
		var a = oval(angle-step*.5)
		var b = oval(angle+step*.5)
		var chord = a.distance_to(b)
		var middle = (a+b)*.5
		var storey = ARENA_WALL*.5
		nodes.append(world.place("arch" if gate else "wall_arched",middle-out*.6,Vector3(chord+.25,storey,1.2),material,yaw))
		nodes.append(world.place("wall_archwindow",middle-out*.6+Vector3.UP*storey,Vector3(chord+.25,storey,1.2),material,yaw))
		nodes.append(world.place("pillar",a-out*.6,Vector3(1.4,ARENA_WALL+.7,1.4),material,yaw))
		# (The royal box takes the place of the seats above the north gate.)
		if i in BOX_BAYS: pass
		elif gate:
			# The way in runs between two walls, under the open sky. They step
			# down with the seating they hold back.
			for side in [-1.0,1.0]:
				var edge = angle+side*step*.5
				var along = (oval(edge)-oval(edge,podium+.5)).normalized()
				# (A doorway in each lets into the space under the stands; the
				# royal box's walls close the north gate's.)
				var tall = PODIUM+TIER.y*2.0+.5
				var runs: Array = [[1.0,1.2+TIER.x,tall,0.0],[1.2+TIER.x,1.2+TIER.x*2.0,PODIUM+TIER.y+.5,0.0],[1.2+TIER.x*2.0,podium+.5,PODIUM+.9,0.0]]
				if not i in BOX_BAYS: runs = [[1.0,UNDER_DOOR.x,tall,0.0],[UNDER_DOOR.x,UNDER_DOOR.y,tall-2.9,2.9],[UNDER_DOOR.y,1.2+TIER.x,tall,0.0]]+runs.slice(1)
				for run in runs:
					var wall_at = (oval(edge,run[0])+oval(edge,run[1]))*.5
					nodes.append(world.place("floor",wall_at+Vector3.UP*run[3],Vector3(run[1]-run[0]+.1,run[2],.9),shaded,atan2(-along.z,along.x)))
		else:
			# The kit's flight climbs toward its own -Z: here, up to the wall.
			var seats_yaw = atan2(-out.x,-out.z)
			for bank in [[upper,PODIUM+TIER.y],[lower,PODIUM]]:
				var width = oval(angle-step*.5,bank[0]).distance_to(oval(angle+step*.5,bank[0]))
				var seat_at = (oval(angle-step*.5,bank[0])+oval(angle+step*.5,bank[0]))*.5
				var seats = world.place("stairs",seat_at+Vector3.UP*bank[1],Vector3(width+.35,TIER.y,TIER.x),material,seats_yaw)
				world.stand_seats.append(seats)
				nodes.append(seats)
			# The wall the seats stand on, with a parapet above the sand.
			var foot = oval(angle-step*.5,podium).distance_to(oval(angle+step*.5,podium))
			var foot_at = (oval(angle-step*.5,podium)+oval(angle+step*.5,podium))*.5
			nodes.append(world.place("wall",foot_at,Vector3(foot+.3,PODIUM+.9,1.0),shaded,yaw))
		world.screen(nodes)
		# Under the stands the hero is indoors: the outer wall on the camera's
		# side (with a gateway's walls there) is lifted away, as a room's
		# front is (world.stand_front).
		if out.dot(Vector3(world.VIEW.x,0,world.VIEW.z).normalized()) > -.1:
			world.stand_front.append_array(nodes if gate else nodes.slice(0,3))
	# The ring's outer wall and the wall round the sand are solid. Between
	# them, under the seats, runs a paved and shadowed undercroft, reached by
	# a doorway in each side of the gateways.
	for z in range(int(ARENA.z-ARENA_RADII.y)-1,int(ARENA.z+ARENA_RADII.y)+2):
		for x in range(int(ARENA.x-ARENA_RADII.x)-1,int(ARENA.x+ARENA_RADII.x)+2):
			var offset = Vector2(x-ARENA.x,z-ARENA.z)
			if (offset/(ARENA_RADII+Vector2(.6,.6))).length()>1.0: continue
			if (offset/ARENA_FLOOR).length()<1.0:
				world.dab(world.TRACK,x,z,.9)
				continue
			var in_gate = false
			var in_door = false
			var in_wall = false
			for i in ARENA_GATES:
				var along = Vector2(cos(i*step),sin(i*step))
				var out = offset.dot(along)
				var aside = absf(offset.cross(along))
				if out<=0: continue
				if aside<1.9: in_gate = true
				elif aside<3.1:
					var reach = ARENA_RADII.x if i%30==0 else ARENA_RADII.y
					if not i in BOX_BAYS and out>reach-UNDER_DOOR.y+.3 and out<reach-UNDER_DOOR.x-.3: in_door = true
					else: in_wall = true
			if in_gate: world.dab(world.PAVING,x,z,.85)
			elif in_door or (not in_wall and under_stands(Vector3(x,0,z))):
				world.dab(world.PAVING,x,z,.8)
				world.dab(world.SHADE,x,z,.55)
			else: world.block_cell(x,z)
	undercroft(world,material)
	world.add_place("arena","arena",ARENA,ARENA_FLOOR.y)
	# What the fighters train with stands round the edge of the sand.
	for spot in [[-.9,"dummy",1.9],[.5,"weapon_stand",1.25],[2.3,"dummy",1.9],[2.75,"dummy",1.9],[3.6,"weapon_stand",1.25],[5.4,"weapon_stand",1.25]]:
		var at = ARENA+Vector3(cos(spot[0])*(ARENA_FLOOR.x-1.8),0,sin(spot[0])*(ARENA_FLOOR.y-1.8))
		item(world,spot[1],at,spot[2],-spot[0]+PI/2,.5)
	# Fire burns at every gate, in gilded bowls.
	for i in ARENA_GATES:
		var angle = i*step
		var across = Vector3(-sin(angle),0,cos(angle))
		for side in [-1.0,1.0]:
			var bowl = world.brazier(oval(angle,-2.2)+across*side*3.9,1.0,1.1)
			for mesh in bowl.find_children("*","MeshInstance3D",true,false): mesh.material_override = Kit.gold()

# Whether a point is under the arena's stands: between its outer wall and the
# wall round the sand, clear of the royal box.
static func under_stands(at: Vector3) -> bool:
	var offset = Vector2(at.x-ARENA.x,at.z-ARENA.z)
	if (offset/(ARENA_RADII-Vector2(2.2,2.2))).length()>=1.0 or (offset/(ARENA_RADII-Vector2(13.7,13.7))).length()<=1.0: return false
	return not (offset.y<0 and absf(offset.x)<BOX_HALF+1.0)

# What stands under the stands: a pier under every other rib of the seating,
# fires along the inner wall, the fighters' stores, and in the south-east the
# stair down to the basement. (Seen only from inside: world.stand_fittings.)
# The opening of the stair down to the basement (across, along) and how far
# down its flight goes; its kerbs' height, and the tone of their stone and
# the steps' (the paving's own limestone, as the floor under the stands is).
const STAIR_OPENING = Vector2(2.6,3.6)
const STAIR_DEPTH = 2.6
const KERB_HEIGHT = .38
const KERB_TONE = Color(.7,.65,.58)

# A block of old stone `size` big, standing on its base at the origin: its
# top edges and corners worn round (WEAR deep) and its faces a little uneven
# (ROUGH), so it sits in the ground as stone long trodden past does, not as
# a cut box. `stone`, if given, is the wall kit palette's texel it is painted from.
const WEAR = .07
const ROUGH = .012
static func worn_block(size: Vector3, rng: RandomNumberGenerator, stone: Vector2 = Vector2(-1,-1)) -> ArrayMesh:
	var box = BoxMesh.new()
	box.size = size
	box.subdivide_width = maxi(2,int(size.x/.12))
	box.subdivide_height = 4
	box.subdivide_depth = maxi(2,int(size.z/.12))
	var tool = SurfaceTool.new()
	tool.create_from(box,0)
	var data = MeshDataTool.new()
	var mesh = tool.commit()
	data.create_from_surface(mesh,0)
	var half: Vector3 = size*.5
	var seed: float = rng.randf()*100.0
	for i in data.get_vertex_count():
		var p: Vector3 = data.get_vertex(i)
		# Rounded toward a box WEAR inside its top and sides (never its base).
		var inner = Vector3(clampf(p.x,-half.x+WEAR,half.x-WEAR),clampf(p.y,-half.y,half.y-WEAR),clampf(p.z,-half.z+WEAR,half.z-WEAR))
		var out: Vector3 = p-inner
		if out.length() > WEAR: p = inner+out.normalized()*WEAR
		# (Uneven by where it is, so the faces' shared edges stay closed.)
		var bump = sin(p.x*23.0+seed)*cos(p.z*19.0-seed)*sin(p.y*29.0+seed*.5)
		if p.y > -half.y+.01: p += (p-Vector3(0,p.y,0)).normalized()*ROUGH*bump+Vector3.UP*ROUGH*.5*bump
		data.set_vertex(i,p+Vector3.UP*half.y)
		# (A block of the town wall's: plain stone of the kit's palette.)
		if stone.x >= 0.0: data.set_vertex_uv(i,stone)
	var worn = ArrayMesh.new()
	data.commit_to_surface(worn)
	tool = SurfaceTool.new()
	tool.create_from(worn,0)
	tool.generate_normals()
	return tool.commit()
static func undercroft(world, material: Material) -> void:
	var step = TAU/ARENA_BAYS
	var before = world.get_child_count()
	for i in ARENA_BAYS:
		var angle = (i+.5)*step
		var near_gate = false
		for gate in ARENA_GATES:
			if absi(i-gate) <= 1 or absi(i+1-gate) <= 1 or i == ARENA_BAYS-1 or i == ARENA_BAYS-2: near_gate = true
		var at = oval(angle,7.9)
		if near_gate or not under_stands(at) or at.distance_to(world.BASEMENT_STAIR)<6.0: continue
		if i%2 == 0:
			world.place("pillar",at,Vector3(1.2,PODIUM,1.2),material,-angle)
			world.block_disc(at,.7,world.SOLID,false)
		elif i%6 == 1:
			var bowl = world.brazier(oval(angle,12.6),.8)
			for mesh in bowl.find_children("*","MeshInstance3D",true,false): mesh.material_override = Kit.gold()
		elif i%6 == 3:
			var out = Vector3(cos(angle),0,sin(angle))
			for item in [["crate",0.0,.85],["barrel",1.1,.9],["crate",-1.0,.7]]:
				var spot = oval(angle+item[1]*.022,3.4)
				world.prop(item[0],spot,item[2],angle+item[1])
				world.block_disc(spot,.5,world.LOW,false)
	# The stair to the basement: a kerbed well opened in the ground
	# (world.open_ground), its flight of steps going down from its open side
	# (the stair's +Z) into the dark, lined with stone, a dark floor at its
	# foot (STAIR_DEPTH down).
	var stair: Vector3 = world.BASEMENT_STAIR
	var turn = Basis(Vector3.UP,PI/4)
	world.open_ground(stair,STAIR_OPENING*.5,PI/4)
	# (Its stone the paving's own, dulled by the years, not the stands' pale
	# dressed blocks.)
	var worn = Art.material("stone",KERB_TONE)
	var flight = world.place("stairs",stair+Vector3.DOWN*STAIR_DEPTH,Vector3(STAIR_OPENING.x,STAIR_DEPTH,STAIR_OPENING.y),worn,PI/4+PI)
	var lining = Kit.gritty(ARENA_STONE*Color(.32,.3,.28),1.6,true)
	for wall in [[Vector3(STAIR_OPENING.x*.5+.14,0,0),Vector3(.28,STAIR_DEPTH,STAIR_OPENING.y+.56)],[Vector3(-STAIR_OPENING.x*.5-.14,0,0),Vector3(.28,STAIR_DEPTH,STAIR_OPENING.y+.56)],[Vector3(0,0,-STAIR_OPENING.y*.5-.14),Vector3(STAIR_OPENING.x,STAIR_DEPTH,.28)]]:
		world.place("floor",stair+turn*wall[0]+Vector3.DOWN*STAIR_DEPTH,wall[1]-Vector3(0,.02,0),lining,PI/4)
	var depths = StandardMaterial3D.new()
	depths.albedo_color = Color(.03,.028,.025)
	world.place("floor",stair+Vector3.DOWN*(STAIR_DEPTH+.1),Vector3(STAIR_OPENING.x+.6,.1,STAIR_OPENING.y+.6),depths,PI/4)
	flight.name = "BasementFlight"
	# Its kerbs: worn blocks, low and rounded at the top (worn_block), sunk a
	# little into the ground, with the dust of the floor drifted against them.
	var rng = RandomNumberGenerator.new()
	rng.seed = 2207
	for side in [[Vector3(1.5,0,0),.42,3.9],[Vector3(-1.5,0,0),.42,3.9],[Vector3(0,0,-1.95),3.4,.42]]:
		var kerb = MeshInstance3D.new()
		kerb.mesh = worn_block(Vector3(side[1],KERB_HEIGHT,side[2]),rng)
		kerb.material_override = worn
		world.add_child(kerb)
		kerb.position = stair+side[0].rotated(Vector3.UP,PI/4)+Vector3.DOWN*.03
		kerb.rotation.y = PI/4
	world.dab_disc(world.SHADE,stair,2.6,1.6,.4)
	for side in [-1.0,1.0]:
		world.brazier(stair+Vector3(side*2.4,0,-2.2).rotated(Vector3.UP,PI/4),.75,.6)
	world.add_place("basement stair","basement",stair,5.0)
	for index in range(before,world.get_child_count()):
		var node = world.get_child(index)
		if node is Node3D:
			node.visible = false
			world.stand_fittings.append(node)

# The royal box, in the north stands over the gate the palace road comes in
# by: a pavilion of white marble where the elders sit to watch the games,
# with five gilded thrones behind a marble-topped table, gilded columns and
# rails, and a crimson canopy and hangings.
static func royal_box(world) -> void:
	var marble = Kit.marble()
	var gold = Kit.gold()
	var crimson = Kit.gritty(CRIMSON,2.2,true)
	var x = ARENA.x
	var back = ARENA.z-ARENA_RADII.y+1.2
	var front = ARENA.z-ARENA_FLOOR.y-.5
	var middle = (back+front)*.5
	var depth = front-back
	var nodes: Array = []
	# The gate runs through under the box, between two marble walls.
	for side in [-1.0,1.0]:
		nodes.append(world.place("floor",Vector3(x+side*2.75,0,middle),Vector3(1.0,BOX_FLOOR-.4,depth),marble))
		# The box's front, to either side of the tunnel's mouth, and its parapet.
		nodes += wall_run(world,Vector3(x+side*(BOX_HALF+2.25)*.5,0,front),BOX_HALF-2.25,BOX_FLOOR+1.0,.9,marble)
		# Its side walls stand taller toward the back, with the stands.
		nodes += wall_run(world,Vector3(x+side*(BOX_HALF-.45),0,middle),depth,BOX_FLOOR+1.0,.9,marble,-side*PI/2)
		nodes += wall_run(world,Vector3(x+side*(BOX_HALF-.45),BOX_FLOOR+1.0,back+2.8),5.6,4.6,.9,marble,-side*PI/2)
	nodes.append(world.place("wall",Vector3(x,4.6,front),Vector3(4.6,BOX_FLOOR-3.6,.9),marble))
	nodes.append(world.place("floor",Vector3(x,BOX_FLOOR+1.0,front),Vector3(BOX_HALF*2.0+.3,.14,1.05),gold))
	var floor_slab = world.place("floor",Vector3(x,BOX_FLOOR-.4,middle),Vector3(BOX_HALF*2.0,.4,depth),marble)
	floor_slab.name = "RoyalBox"
	nodes.append(floor_slab)
	nodes.append(world.place("floor",Vector3(x,BOX_FLOOR,middle+1.2),Vector3(8.6,.05,depth-3.0),crimson))
	# The back wall, hung with crimson, under a gilded cornice.
	nodes += wall_run(world,Vector3(x,BOX_FLOOR,back+.5),BOX_HALF*2.0,5.6,.9,marble)
	nodes.append(world.place("floor",Vector3(x,BOX_FLOOR+5.6,back+.5),Vector3(BOX_HALF*2.0+.4,.35,1.4),gold))
	for offset in [-4.5,0.0,4.5]:
		nodes.append(hanging(world,"cloth_red",Vector3(x+offset,BOX_FLOOR+1.1,back+1.02),4.1,0.0,CRIMSON))
	# A canopy shades the back of the box, on gilded columns, leaving the
	# thrones in view; two more columns stand free at the front, each carrying
	# a fire.
	for side in [-1.0,1.0]:
		for z in [back+1.6,back+5.0]:
			nodes.append(world.place("column",Vector3(x+side*6.2,BOX_FLOOR,z),Vector3(.75,4.6,.75),gold))
		nodes.append(world.place("column",Vector3(x+side*6.2,BOX_FLOOR,front-1.2),Vector3(.75,3.0,.75),gold))
		var bowl = world.brazier(Vector3(x+side*6.2,BOX_FLOOR+3.0,front-1.2),1.0)
		for mesh in bowl.find_children("*","MeshInstance3D",true,false): mesh.material_override = gold
		nodes.append(bowl)
	nodes.append(world.place("floor",Vector3(x,BOX_FLOOR+4.6,back+2.8),Vector3(BOX_HALF*2.0-.6,.12,5.4),crimson))
	nodes.append(world.place("floor",Vector3(x,BOX_FLOOR+4.48,back+5.4),Vector3(BOX_HALF*2.0-.2,.34,.45),gold))
	# The five elders' thrones, in a row facing the sand: marble and gilt,
	# velvet-cushioned, of a man's size and all alike (their seats are of the
	# inn's seats' height).
	var seats = front-4.45
	for i in THRONES:
		var offset = (i-(THRONES-1)*.5)*THRONE_SPACING
		var throne = world.place("throne_elder",Vector3(x+offset,BOX_FLOOR,seats),Vector3.ONE*THRONE_HEIGHT/Kit.SIZE.throne_elder.y,null,0.0)
		throne.set_meta("throne",true)
		nodes.append(throne)
	# Before them a long table on gilded legs, topped with a single slab of
	# veined marble overhanging it a little all round.
	var reach = (THRONES-1)*THRONE_SPACING+1.0
	var table_at = seats+1.2
	for side in [-1.0,1.0]:
		var frame = world.place("table",Vector3(x+side*reach*.25,BOX_FLOOR,table_at),Vector3(reach*.5,TABLE_HEIGHT-.06,.86),gold)
		frame.set_meta("elders_table",true)
		nodes.append(frame)
	var top = world.place("floor",Vector3(x,BOX_FLOOR+TABLE_HEIGHT-.06,table_at),Vector3(reach+.16,.06,1.0),marble)
	top.set_meta("elders_table",true)
	nodes.append(top)
	world.screen(nodes)
	world.add_place("elders' box","royal_box",Vector3(x,0,front+3.0),5.0)

# The market square, in the town's south-east corner: stalls, and the well.
static func market(world) -> void:
	var middle = Vector3(MARKET.get_center().x,0,MARKET.get_center().y)
	var well = item(world,"well",middle,3.3,PI*.25,1.5)
	world.screen([well])
	world.add_place("well","well",middle,3.2)
	for spot in [[Vector3(-3.4,0,1.2),.5],[Vector3(2.6,0,-2.4),.4]]:
		item(world,"bucket",middle+spot[0],spot[1],1.0,0.0)
	# Stalls along the square's east side, their counters to the square, under
	# faded awnings.
	var stalls: Array = []
	for i in 4:
		var at = Vector3(MARKET.end.x-2.2,0,MARKET.position.y+3.6+i*5.4)
		stalls.append(item(world,"stall",at,3.0,PI/2,1.3))
		Kit.dye(stalls[-1],[Color(.44,.20,.15),Color(.56,.46,.28),Color(.34,.33,.30),Color(.42,.34,.22)][i])
		var ware = item(world,["farm_crate","crate","urn","bag"][i],at+Vector3(-1.9,0,1.5),[.3,.7,.8,.7][i],.4*i,.4)
		if i == 0: Kit.produce(ware)
	world.screen(stalls)
	item(world,"cart",Vector3(MARKET.position.x+3.0,0,MARKET.end.y-3.5),2.5,2.5,1.5)
	for spot in [Vector3(MARKET.position.x+6.0,0,MARKET.end.y-2.4),Vector3(MARKET.position.x+7.2,0,MARKET.end.y-3.6)]:
		item(world,"barrel",spot,.95)
	for side in [0.0,1.0]:
		item(world,"bench",middle+Vector3(-5.0+side*8.0,0,5.5),.55,0.0,.9)

# The greengrocers: three stalls of fruit and vegetables below the market
# square, just inside the south gate, round an aisle that runs from the square
# down to the way through the gate. Each is kept by a stallholder
# (scripts/townsfolk.gd), who stands behind its counter by day; at night its
# wares are packed away and sacking thrown over its counter.
# (Kept north of the rocks at the town's southern edge, which would hide its
# aisle from the camera.)
const GREENGROCERS = Rect2(-212,62,12,10)
const STALL_HEIGHT = 3.0
# The stall's counter top, a share of its height (the props kit's model).
const COUNTER = .317*STALL_HEIGHT
# How the stall model is turned for its counter to face +Z.
const STALL_YAW = 0.0
# The props kit's apples, turned to the market's other fruit (assets/shaders/
# produce.gdshader); carrots are carrots.
const FRUIT = {"apples":Color(0,0,0,0),"oranges":Color(.92,.42,.05),"lemons":Color(.9,.76,.16),"pomegranates":Color(.52,.07,.08),
	"onions":Color(.74,.52,.27),"figs":Color(.32,.15,.25)}
static func greengrocers(world) -> void:
	# [where it stands, which way its counter faces, its wares, its awning]
	# In a row down the east side, their counters to the aisle and the camera
	# (a stall's back is hung with its awning's cloth, which would hide its
	# keeper).
	var plans = [[Vector3(-202.3,0,63.3),Vector3(-1,0,0),["oranges","apples","lemons"],Color(.50,.30,.15)],
		[Vector3(-202.3,0,67.3),Vector3(-1,0,0),["carrots","onions","carrots"],Color(.38,.38,.30)],
		[Vector3(-202.3,0,71.3),Vector3(-1,0,0),["pomegranates","figs","apples"],Color(.48,.15,.11)]]
	for plan in plans: world.stalls.append(stall(world,plan[0],plan[1],plan[2],plan[3]))
	# Their stock along the west side, against the houses' wall: crates and
	# sacks, and a barrel of apples.
	var rng: RandomNumberGenerator = world.rng
	var stock = [["crate_empty",.2],["bag",.62],["carrot_crate",.36],["bag",.55],["apple_barrel",.82],["crate_empty",.2]]
	for i in stock.size():
		var at = Vector3(GREENGROCERS.position.x+.7,0,GREENGROCERS.position.y+1.6+i*1.35)
		var thing = item(world,stock[i][0],at,stock[i][1],rng.randf_range(0,TAU),.45)
		if stock[i][0] in ["carrot_crate","apple_barrel"]: Kit.produce(thing)
	var middle = GREENGROCERS.get_center()
	world.add_place("greengrocers","market",Vector3(middle.x,0,middle.y),5.5)
	world.dab_rect(world.PAVING,GREENGROCERS.grow(-1.0),.55)

# One stall: its counter (facing `front`) laid with a crate of each of its
# wares, more on the ground at one end, empty crates stacked behind. Returns
# where it stands ("at"), its "front", where its keeper stands ("keeper") and
# a customer ("buyer"), what it sells ("goods"), its "wares" (shown while it
# is open) and its "cover" (while it is shut).
static func stall(world, at: Vector3, front: Vector3, goods: Array, awning: Color) -> Dictionary:
	var rng: RandomNumberGenerator = world.rng
	var along = front.cross(Vector3.UP)
	var yaw = atan2(front.x,front.z)+STALL_YAW
	var node = item(world,"stall",at,STALL_HEIGHT,yaw,0.0)
	Kit.dye(node,awning)
	world.screen([node])
	# Only the counter stops the way: the keeper's place behind it is open.
	var depth = Kit.sized("stall",STALL_HEIGHT).z
	var width = Kit.sized("stall",STALL_HEIGHT).x
	var corners = [at+front*depth*.5+along*width*.5,at-front*depth*.5-along*width*.5]
	world.block_rect(Rect2(minf(corners[0].x,corners[1].x),minf(corners[0].z,corners[1].z),absf(corners[0].x-corners[1].x),absf(corners[0].z-corners[1].z)),world.LOW)
	var wares: Array = []
	for i in goods.size():
		var spot = at+along*((i-(goods.size()-1)*.5)*.68)+front*.12+Vector3.UP*COUNTER
		wares.append(crate(world,goods[i],spot,yaw+rng.randf_range(-.12,.12)))
	# On the ground at its side: a barrel or a stack of crates of the first.
	var side = at+along*(width*.5+.55)+front*.2
	if goods[0] == "carrots":
		wares.append(crate(world,"carrots",side,yaw+.3,0.0))
		wares.append(crate(world,"carrots",side+Vector3.UP*.22,yaw+.1,0.0))
		wares.append(item(world,"bag",side-front*.75,.62,rng.randf_range(0,TAU),0.0))
	else:
		var barrel = item(world,"apple_barrel",side,.82,rng.randf_range(0,TAU),0.0)
		Kit.produce(barrel,FRUIT[goods[0]])
		wares.append(barrel)
	world.block_disc(side,.45,world.LOW)
	# The empties, stacked behind it.
	var back = at-front*(depth*.5+.4)+along*.5
	for k in 3: item(world,"crate_empty",back+Vector3.UP*k*.2,.2,yaw+rng.randf_range(-.2,.2),0.0)
	world.block_disc(back,.4,world.LOW)
	# Its cover for the night: sacking thrown over the counter.
	var cover: Array = []
	for half in [-1.0,1.0]:
		var sheet = Art.model("cloth_blue",Vector3(1.25,1.15,.04))
		Kit.dress(sheet)
		Kit.dye(sheet,Color(.40,.34,.25))
		world.add_child(sheet)
		var lying = Basis(front,along,front.cross(along))
		sheet.basis = Basis(lying.x*1.25,lying.y*1.15,lying.z*.04)
		# (Each sheet runs from its own end along the counter.)
		sheet.position = at+along*(.02 if half > 0.0 else -1.17)+Vector3.UP*(COUNTER+.03+world.lift(at))
		sheet.visible = false
		cover.append(sheet)
	# Its keeper stands at its other end, beside the counter: behind it, the
	# awning would hide him from the camera.
	return {"at":at,"front":front,"keeper":at-along*(width*.5+.42)+front*.1,"buyer":at+front*(depth*.5+.75),"goods":goods,"wares":wares,"cover":cover}

# A crate of produce (or a crate of carrots), its height set by the crate.
static func crate(world, goods: String, at: Vector3, yaw: float, solid: float = 0.0) -> Node3D:
	if goods == "carrots": return item(world,"carrot_crate",at,.36,yaw,solid)
	var node = item(world,"farm_crate",at,.21,yaw,solid)
	Kit.produce(node,FRUIT[goods])
	return node

# The inn, north-west of the arena on the ring street. Its door stands open
# (scripts/world_interiors.gd furnishes it).
static func inn(world) -> void:
	world.upkeep["inn"] = .55
	var room: Dictionary = Interiors.inn(world,LIMEWASH,WOODS[0])
	var door: Vector3 = room.door
	# (What hangs on the front wall goes when the wall does.)
	var cloths: Array = []
	for side in [-3.0,3.0]: cloths.append(hanging(world,"cloth_blue",door+Vector3(side,3.0,-.85),2.4,0.0,Color(.36,.30,.20)))
	world.screen_in_room(cloths,room,"front")
	world.add_place("inn","inn",door,4.0)
	# The cellar's barrels by the wall.
	item(world,"barrel_rack",door+Vector3(8.2,0,-.5),1.3,0.0,.9)
	item(world,"barrel",door+Vector3(-8.4,0,-.5),.95)
	item(world,"urn",door+Vector3(2.4,0,-.5),.9,0.0,.4)

# The smithy, east of the palace road, its door open too, with a practice
# dummy and a rack outside.
static func armorer(world) -> void:
	world.upkeep["armorer"] = .6
	var room: Dictionary = Interiors.smithy(world,OCHRE,WOODS[1])
	var door: Vector3 = room.door
	world.screen_in_room([hanging(world,"cloth_red",door+Vector3(3.2,2.9,-.85),2.4,0.0,Color(.40,.18,.12))],room,"front")
	world.add_place("blacksmith","shop",door,4.0)
	item(world,"weapon_stand",door+Vector3(6.4,0,-.3),1.25,0.0,.8)
	item(world,"dummy",door+Vector3(-4.6,0,1.2),1.9,.5,.5)
	item(world,"barrel",door+Vector3(-2.6,0,-.5),.9)

# The provisioner's, on the main street just inside the gate, its door to the
# arena.
static func provisioner(world) -> void:
	var corner = Vector3(-195,0,8)
	var bays = Vector2i(2,3)
	var nodes = block(world,corner,bays,["sw"],["sda"],CREAM,WOODS[2],0.0,.5)
	world.upkeep["provisioner"] = .5
	var door = doorstep(corner,bays,"west",1)
	nodes.append(hanging(world,"cloth_red",door+Vector3(.85,2.9,-2.1),2.4,-PI/2,Color(.52,.42,.24)))
	world.screen(nodes)
	world.add_place("provisioner","shop",door,4.0)
	item(world,"crate",door+Vector3(.2,0,3.0),.9,.2)
	item(world,"crate",door+Vector3(-.5,0,3.9),.75,1.0)
	item(world,"bag",door+Vector3(.3,0,-2.9),.75,0.0,.4)
	item(world,"bag",door+Vector3(-.4,0,-3.5),.65,1.4,.4)
	item(world,"urn",door+Vector3(.4,0,-4.3),1.0,0.0,.4)
	item(world,"farm_crate",door+Vector3(-.3,0,4.9),.3,.6,.4)

# One face of a house, `bays` modules long: its door (if it has one), a
# shuttered window or two, and bare wall, broken down where it is worst.
static func face(world, bays: int, door: bool, wear: float) -> String:
	var rng: RandomNumberGenerator = world.rng
	var letters = ""
	var door_bay = rng.randi_range(0,bays-1) if door else -1
	for i in bays:
		if i==door_bay: letters += "d"
		elif wear>.8 and rng.randf()<.45: letters += "b"
		else: letters += "s" if rng.randf()<lerpf(.7,.35,wear) else "w"
	return letters

# A house: `door` is the face its door is in ("south" or "west"), `storeys`
# its height, `wear` how far it has gone. A `ruin` has lost its roof.
static func house(world, corner: Vector3, bays: Vector2i, door: String, storeys: int, wear: float, ruin: bool = false) -> Array:
	var rng: RandomNumberGenerator = world.rng
	# The better-kept houses still have their limewash; the rest are bare.
	var tint: Color = [LIMEWASH,CREAM][rng.randi_range(0,1)] if wear<.6 else [MUD,DUN,OCHRE,LIMEWASH*Color(.9,.88,.84)][rng.randi_range(0,3)]
	var wood: Color = WOODS[rng.randi_range(0,WOODS.size()-1)]
	var south: Array = []
	var west: Array = []
	for storey in storeys:
		south.append(face(world,bays.x,door=="south" and storey==0,wear))
		west.append(face(world,bays.y,door=="west" and storey==0,wear))
	var nodes = block(world,corner,bays,south,west,tint,wood,0.0,wear,ruin)
	var bay = (south[0] if door=="south" else west[0]).find("d")
	var step = doorstep(corner,bays,door,bay)
	world.screen(nodes)
	world.upkeep.houses.append(wear)
	world.add_place("fallen house" if ruin else "house","house",step,2.6)
	var beside = Vector3(2.0,0,-.4) if door=="south" else Vector3(.4,0,2.0)
	# What gathers at a poor door: rubble from its own walls, a broken pot,
	# sacking. A better one keeps a pot or a barrel there.
	if wear<.6: item(world,["urn","barrel","crate"][rng.randi_range(0,2)],step+beside,.85,rng.randf_range(0,TAU))
	else:
		if rng.randf()<.7:
			var pile = world.place("rubble",step+beside+Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.3,.3)),Vector3(rng.randf_range(1.6,2.6),rng.randf_range(.45,.8),rng.randf_range(1.0,1.5)),Kit.masonry(tint,wood,.4,1.0),rng.randf_range(0,TAU))
			world.block_disc(pile.position,.8,world.LOW)
		if rng.randf()<.5: item(world,"urn_broken",step-beside*.8+Vector3(rng.randf_range(-.3,.3),0,rng.randf_range(-.3,.3)),.22,rng.randf_range(0,TAU),0.0)
		if rng.randf()<.4: item(world,"bag",step-beside*1.3,.6,rng.randf_range(0,TAU),.4)
	if ruin:
		# The roof lies inside where it fell.
		var middle = corner+Vector3(bays.x*BAY*.5,0,bays.y*BAY*.5)
		for i in 3: world.place("rubble",middle+Vector3(rng.randf_range(-1.6,1.6),0,rng.randf_range(-1.6,1.6)),Vector3(rng.randf_range(2.2,3.4),rng.randf_range(.6,1.2),rng.randf_range(1.4,2.2)),Kit.masonry(tint,wood,.4,1.0),rng.randf_range(0,TAU))
	return [tint,wood]

# Houses line the alleys, both sides, and fill the gaps along the ring
# street; out west they line the river's quay and the lane behind, and in the
# south both sides of South Street. Most are in a poor way; a few are kept up.
static func houses(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	world.upkeep["houses"] = []
	# [north-west corner, bays, the face with the door, storeys]
	var plans = [
		# Tanners' Lane, north-west: west side, then east side.
		[Vector3(-308,0,-72),Vector2i(2,2),"south",1],[Vector3(-308,0,-62),Vector2i(2,2),"south",2],[Vector3(-308,0,-52),Vector2i(2,2),"south",1],
		[Vector3(-292,0,-74),Vector2i(2,2),"west",1],[Vector3(-292,0,-64),Vector2i(2,2),"west",1],[Vector3(-292,0,-54),Vector2i(2,2),"west",2],
		# Potters' Row, north-east.
		[Vector3(-224,0,-72),Vector2i(2,2),"south",1],[Vector3(-224,0,-62),Vector2i(2,2),"south",1],[Vector3(-224,0,-52),Vector2i(2,2),"south",2],
		[Vector3(-208,0,-74),Vector2i(2,2),"west",2],[Vector3(-208,0,-64),Vector2i(2,2),"west",1],[Vector3(-208,0,-54),Vector2i(2,2),"west",1],
		# Beggars' Alley, south-west.
		[Vector3(-308,0,44),Vector2i(2,2),"south",1],[Vector3(-308,0,54),Vector2i(2,2),"south",1],[Vector3(-308,0,64),Vector2i(2,2),"south",1],
		[Vector3(-292,0,46),Vector2i(2,2),"west",1],[Vector3(-292,0,56),Vector2i(2,2),"west",2],[Vector3(-292,0,66),Vector2i(2,2),"west",1],
		# Dyers' Lane, south-east.
		[Vector3(-238,0,54),Vector2i(2,2),"south",1],[Vector3(-238,0,64),Vector2i(2,2),"south",1],
		[Vector3(-222,0,46),Vector2i(2,2),"west",2],[Vector3(-222,0,56),Vector2i(2,2),"west",1],[Vector3(-222,0,66),Vector2i(2,2),"west",1],
		# West Street: north side, then south side.
		[Vector3(-326,0,-12),Vector2i(2,2),"south",1],[Vector3(-337,0,-12),Vector2i(2,2),"south",1],
		[Vector3(-326,0,4),Vector2i(2,2),"west",1],[Vector3(-337,0,4),Vector2i(2,2),"south",1],
		# Along the ring street and the main street.
		[Vector3(-264,0,57),Vector2i(3,2),"south",1],[Vector3(-276,0,58),Vector2i(2,2),"south",2],
		[Vector3(-195,0,-16),Vector2i(2,2),"west",1],[Vector3(-195,0,-30),Vector2i(2,2),"west",1],[Vector3(-196,0,24),Vector2i(2,2),"west",1],
		# The river front, along the quay.
		[Vector3(-362,0,-74),Vector2i(2,2),"west",1],[Vector3(-362,0,-64),Vector2i(2,3),"west",2],[Vector3(-362,0,-50),Vector2i(2,2),"west",1],
		[Vector3(-362,0,-40),Vector2i(2,2),"west",2],[Vector3(-362,0,-30),Vector2i(2,3),"west",1],[Vector3(-362,0,-14),Vector2i(2,2),"west",1],
		[Vector3(-362,0,4),Vector2i(2,2),"west",2],[Vector3(-362,0,14),Vector2i(2,3),"west",1],[Vector3(-362,0,28),Vector2i(2,2),"west",1],
		[Vector3(-362,0,38),Vector2i(2,2),"west",1],[Vector3(-362,0,48),Vector2i(2,3),"west",2],[Vector3(-362,0,62),Vector2i(2,2),"west",1],
		[Vector3(-362,0,72),Vector2i(2,3),"west",1],
		# Behind them, along the back lane.
		[Vector3(-350,0,-72),Vector2i(2,2),"west",1],[Vector3(-350,0,-60),Vector2i(2,2),"west",1],[Vector3(-350,0,-46),Vector2i(2,3),"west",2],
		[Vector3(-350,0,-32),Vector2i(2,2),"west",1],[Vector3(-350,0,-20),Vector2i(2,2),"south",1],[Vector3(-350,0,6),Vector2i(2,2),"west",1],
		[Vector3(-350,0,18),Vector2i(2,2),"west",2],[Vector3(-350,0,30),Vector2i(2,3),"west",1],[Vector3(-350,0,46),Vector2i(2,2),"west",1],
		[Vector3(-350,0,58),Vector2i(2,2),"west",1],[Vector3(-350,0,70),Vector2i(2,2),"west",1],
		# South Street, its north side.
		[Vector3(-350,0,78),Vector2i(2,2),"south",1],[Vector3(-338,0,78),Vector2i(3,2),"south",2],[Vector3(-322,0,78),Vector2i(2,2),"south",1],
		[Vector3(-310,0,78),Vector2i(2,2),"south",1],[Vector3(-290,0,78),Vector2i(2,2),"south",2],[Vector3(-278,0,78),Vector2i(3,2),"south",1],
		[Vector3(-262,0,78),Vector2i(2,2),"south",1],[Vector3(-250,0,78),Vector2i(2,2),"south",1],[Vector3(-240,0,78),Vector2i(2,2),"south",2],
		[Vector3(-220,0,78),Vector2i(2,2),"south",1],[Vector3(-208,0,78),Vector2i(2,2),"south",1],[Vector3(-196,0,78),Vector2i(2,2),"west",1],
		# And its south side, against the wall, their doors on the lane inside it.
		[Vector3(-362,0,94),Vector2i(2,2),"south",1],[Vector3(-350,0,94),Vector2i(3,2),"south",1],[Vector3(-334,0,94),Vector2i(2,2),"south",2],
		[Vector3(-322,0,94),Vector2i(2,2),"south",1],[Vector3(-310,0,94),Vector2i(3,2),"south",1],[Vector3(-292,0,94),Vector2i(2,2),"south",1],
		[Vector3(-280,0,94),Vector2i(2,2),"south",2],[Vector3(-268,0,94),Vector2i(3,2),"south",1],[Vector3(-252,0,94),Vector2i(2,2),"south",1],
		[Vector3(-240,0,94),Vector2i(2,2),"south",1],[Vector3(-220,0,94),Vector2i(2,2),"south",1],[Vector3(-208,0,94),Vector2i(2,2),"south",2],
		[Vector3(-196,0,94),Vector2i(2,2),"south",1]]
	for i in plans.size():
		var plan = plans[i]
		# One house in four is kept up; the rest run from shabby to derelict.
		var wear = rng.randf_range(.3,.45) if i%4==1 else rng.randf_range(.65,1.0)
		# A few have come down: to their foundations, or half fallen in.
		if plan[0] in FOUNDATIONS: foundation(world,plan[0],plan[1])
		elif plan[0] in COLLAPSED: collapsed(world,plan[0],plan[1],plan[2],plan[3],maxf(wear,.75))
		else: house(world,plan[0],plan[1],plan[2],plan[3],wear)
	# Out at the town's edges, houses have fallen in and been left.
	house(world,Vector3(-324,0,-38),Vector2i(2,2),"south",1,1.0,true)
	house(world,Vector3(-192,0,-56),Vector2i(2,2),"south",1,1.0,true)
	house(world,Vector3(-322,0,26),Vector2i(2,2),"south",1,1.0,true)
	house(world,Vector3(-350,0,-8),Vector2i(2,1),"south",1,1.0,true)
	house(world,Vector3(-336,0,46),Vector2i(2,2),"south",1,1.0,true)

# The houses that have come down: to their foundations (FOUNDATIONS), or
# half fallen in (COLLAPSED), by their north-west corners.
const FOUNDATIONS = [Vector3(-362,0,38),Vector3(-322,0,94),Vector3(-290,0,78),Vector3(-208,0,-64)]
const COLLAPSED = [Vector3(-350,0,30),Vector3(-262,0,78),Vector3(-224,0,-62),Vector3(-362,0,62)]

# A house gone to its foundations: the stumps of its walls all round, knee
# high and broken, rubble heaped within and its dressed blocks scattered.
static func foundation(world, corner: Vector3, bays: Vector2i) -> void:
	var rng: RandomNumberGenerator = world.rng
	var tint: Color = [MUD,DUN,OCHRE][rng.randi_range(0,2)]
	var material = Kit.masonry(tint,BROWN,.4,1.0,world.lift(corner))
	var size = Vector2(bays.x*BAY,bays.y*BAY)
	var phase = rng.randf_range(0.0,10.0)
	var stump = func(offset: float) -> float: return .45+.3*sin(offset*1.1+phase)+.15*sin(offset*2.9+phase*2.0)
	for side in [[Vector3(size.x*.5,0,size.y-.7),size.x,0.0],[Vector3(size.x*.5,0,.7),size.x,0.0],[Vector3(.7,0,size.y*.5),size.y,-PI/2],[Vector3(size.x-.7,0,size.y*.5),size.y,-PI/2]]:
		var middle: Vector3 = corner+side[0]
		var node = ruin(world,middle,side[1],side[2],stump,material,.2,1.3)
		world.screen([node])
		var along_x = side[2] == 0.0
		world.block_rect(Rect2(middle.x-(side[1]*.5 if along_x else .7),middle.z-(.7 if along_x else side[1]*.5),side[1] if along_x else 1.4,1.4 if along_x else side[1]),world.LOW)
	var middle = corner+Vector3(size.x*.5,0,size.y*.5)
	for i in 3:
		var heap = world.place("rubble",middle+Vector3(rng.randf_range(-size.x*.25,size.x*.25),0,rng.randf_range(-size.y*.25,size.y*.25)),Vector3(rng.randf_range(2.0,3.2),rng.randf_range(.5,1.0),rng.randf_range(1.4,2.2)),material,rng.randf_range(0,TAU))
		world.block_disc(heap.position,1.0,world.LOW)
	# (Heaped full of its own rubble, it cannot be walked into.)
	world.block_rect(Rect2(corner.x,corner.z,size.x,size.y),world.LOW,false)
	world.add_place("fallen house","house",corner+Vector3(-1.6,0,size.y*.5),size.length()*.5)

# A house half fallen in: its west part stands, roofed, walled off where the
# rest came down; the east bay is a shell, its walls breaking away from the
# standing part's height down to little at the far corner, its roof fallen in
# and lying in the rubble.
static func collapsed(world, corner: Vector3, bays: Vector2i, door: String, storeys: int, wear: float) -> void:
	var rng: RandomNumberGenerator = world.rng
	var standing = Vector2i(bays.x-1,bays.y)
	var colours: Array = house(world,corner,standing,door,storeys,wear)
	var ground: float = world.lift(corner)
	var material = Kit.masonry(colours[0],colours[1],.4,snappedf(wear,.05),ground)
	var size = Vector2(bays.x*BAY,bays.y*BAY)
	var x0 = corner.x+standing.x*BAY
	var height = storeys*BAY
	# The standing part's own east wall, where it was open to the rest.
	var inner: Array = []
	for storey in storeys:
		for i in bays.y:
			inner.append(world.place("wall",Vector3(x0-.5,storey*BAY,corner.z+BAY*.5+i*BAY),Vector3(BAY,BAY,1),material,PI/2))
	world.screen(inner)
	# Its fallen bay's walls: high against the standing part, low far from it.
	var falling = func(offset: float) -> float:
		var t = clampf((offset+BAY*.5)/BAY,0.0,1.0)
		return lerpf(height-.6,1.0,smoothstep(0.0,1.0,t))+.25*sin(offset*2.3)
	var corner_low = func(offset: float) -> float: return 1.1+.35*sin(offset*1.7+1.0)+.4*clampf(-offset/(size.y*.5),0.0,1.0)
	var walls: Array = []
	walls.append(ruin(world,Vector3(x0+BAY*.5,0,corner.z+size.y-.7),BAY,0.0,falling,material,.6,height))
	walls.append(ruin(world,Vector3(x0+BAY*.5,0,corner.z+.7),BAY,0.0,falling,material,.6,height))
	walls.append(ruin(world,Vector3(corner.x+size.x-.7,0,corner.z+size.y*.5),size.y,-PI/2,corner_low,material,.6,height))
	world.screen(walls)
	world.block_rect(Rect2(x0,corner.z,BAY,size.y))
	# The roof that fell, broken and tilted on its rubble.
	var middle = Vector3(x0+BAY*.5,0,corner.z+size.y*.5)
	var slab = world.place("floor",middle+Vector3(rng.randf_range(-.4,.4),.7,rng.randf_range(-.6,.6)),Vector3(BAY*.8,.3,size.y*.45),Kit.masonry(colours[0]*Color(.9,.87,.82),colours[1],.4,snappedf(wear,.05),ground))
	slab.rotation = Vector3(rng.randf_range(-.25,.25),rng.randf_range(-.3,.3),rng.randf_range(.18,.35))
	for i in 3:
		world.place("rubble",middle+Vector3(rng.randf_range(-1.2,1.2),0,rng.randf_range(-size.y*.3,size.y*.3)),Vector3(rng.randf_range(2.0,3.0),rng.randf_range(.6,1.2),rng.randf_range(1.4,2.2)),material,rng.randf_range(0,TAU))

# Palms along the ring street, and dry grass, stones and litter wherever the
# ground is bare.
static func greenery(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var reach = ARENA_RADII+Vector2(RING-1.6,RING-1.6)
	for i in 22:
		var angle = (i+.5)*TAU/22.0
		var at = ARENA+Vector3(cos(angle)*reach.x,0,sin(angle)*reach.y)
		# Not across the four streets that lead to the arena's gates.
		if absf(at.x-ARENA.x)<7.0 or absf(at.z-ARENA.z)<7.0 or not world.fits(at,1.2): continue
		# Nor before an open door.
		if world.rooms.any(func(room): return room.door.distance_to(at)<7.0): continue
		Desert.palm(world,at,rng.randf_range(7.0,9.0))
	for spot in [Vector3(-186,0,-10),Vector3(-186,0,10),Vector3(MARKET.position.x+2.0,0,MARKET.position.y+2.0),Vector3(MARKET.position.x+9.0,0,MARKET.end.y-1.5)]:
		if world.fits(spot,1.0): Desert.palm(world,spot,rng.randf_range(7.0,9.0))
	for spot in [Vector3(-190,0,-48),Vector3(-188,0,-62),Vector3(-324,0,-40),Vector3(-322,0,52),Vector3(-246,0,68)]:
		if not world.fits(spot,1.0): continue
		var tree = world.prop("dead_tree" if rng.randf()<.5 else "olive_a",spot,rng.randf_range(4.2,5.4),rng.randf_range(0,TAU))
		world.block_disc(spot,.6)
		world.screen([tree])
	for i in 1400:
		var at = Vector3(rng.randf_range(-370.0,-183.0),0,rng.randf_range(-86.0,world.WALL_SOUTH-1.0))
		var c = world.to_cell(at)
		var cell = world.index(c.x,c.y)
		if world.cells[cell] != world.OPEN or world.paint[cell*4+world.PAVING]>120: continue
		# Nothing grows or lies about indoors.
		if world.rooms.any(func(room): return room.area.has_point(Vector2(at.x,at.z))): continue
		# The arena's sand is raked clean.
		if (Vector2(at.x-ARENA.x,at.z-ARENA.z)/ARENA_RADII).length()<1.0: continue
		var lane = world.paint[cell*4+world.TRACK]>30 or world.paint[cell*4+world.PAVING]>30
		if lane:
			# Litter in the alleys: fallen stones and broken pots.
			if rng.randf()<.5: Desert.stone(world,at)
			elif rng.randf()<.12: world.prop("urn_broken",at,.2,rng.randf_range(0,TAU))
		elif rng.randf()<.6: Desert.tuft(world,at)
		else: Desert.stone(world,at)
