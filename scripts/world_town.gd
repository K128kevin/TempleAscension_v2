extends RefCounted
## The town at the western end of the outdoor world (scripts/overworld.gd).
## The arena stands at its centre, kept up at the elders' expense, with their
## box in its north stands; a broad street rings it. The inn, two shops and the
## houses stand round that street and along the alleys that run off it, and
## most of them are in a poor way: stained, cracked, some fallen in. A market
## square with the well fills the south-east corner, and a wall with one gate
## closes the town off from the desert; a second gate shuts the gap in the
## rocks at the end of the southern alley. Two guards stand at each. From the
## arena's north gate a road
## climbs to the elders' palace (scripts/world_palace.gd). The town's people
## have yet to arrive.
const Kit = preload("res://scripts/world_art.gd")
const Desert = preload("res://scripts/world_desert.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const Guard = preload("res://scripts/town_guard.gd")
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
# The thrones' height (a chair's seat about half way up it), how far apart
# they stand, and the height of the marble-topped table before them.
const THRONE_HEIGHT = 1.1
const THRONE_SPACING = 1.3
const TABLE_HEIGHT = .78
# The street that rings the arena: the buildings stand along its far side.
const RING = 14.0
const MARKET = Rect2(-205,38,21,24)
# The alleys off the ring street: each lane's rectangle.
const ALLEYS = [Rect2(-214,-76,4,36),Rect2(-298,-76,4,36),Rect2(-298,40,4,36),Rect2(-228,46,4,30),Rect2(-340,-2.5,28,5)]
# The letters of a face: w wall, d door, s shuttered window, a arched recess,
# o open arched window, p open portal, b a wall broken down.
const MODULES = {"w":"wall","d":"wall_door","s":"wall_window","a":"wall_arched","o":"wall_archwindow","p":"arch","b":"wall_broken"}

static func build(world) -> void:
	streets(world)
	gate_wall(world)
	south_gate(world)
	arena(world)
	royal_box(world)
	market(world)
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
	var z = -96.0
	while z<96.0:
		var middle = z+BAY*.5
		z += BAY
		if absf(middle)<5.0 or world.margin_at(Vector3(x,0,middle))<-9.0: continue
		var piece = world.place("wall",Vector3(x,0,middle),Vector3(BAY,5.6,1.4),material,-PI/2)
		world.block_rect(Rect2(x-.7,middle-BAY*.5,1.4,BAY))
		world.screen([piece])
	# Two towers flank the gateway, joined by a lintel over the road.
	var towers: Array = []
	for side in [-1.0,1.0]:
		var at = Vector3(x,0,side*6.2)
		towers.append(world.place("pillar_decorated",at,Vector3(3.6,8.6,3.4),material,-PI/2))
		world.block_rect(Rect2(x-1.7,at.z-1.8,3.4,3.6))
		world.brazier(at+Vector3(-2.8,0,side*.2),1.0,1.1)
		hanging(world,"cloth_red",Vector3(x-1.85,2.6,side*6.2),4.4,-PI/2,Color(.44,.14,.10))
		# A guard before each tower, on the town side, watching the way through.
		guard(world,Vector3(x-2.3,0,side*4.75),Vector3(-.45,0,-side),.25+side*.2)
	towers.append(world.place("wall",Vector3(x,6.2,0),Vector3(9.4,1.5,1.4),material,-PI/2))
	world.screen(towers)
	world.add_place("town gate","gate",Vector3(x,0,0),7.0)

# The gate across the gap in the rocks at the end of the southern alley, built
# as the town gate is: a wall from rock to rock, two towers flanking the way
# through, joined by a lintel. Its guards stand outside, facing the desert.
const SOUTH_GATE = Vector3(-226,0,82)
static func south_gate(world) -> void:
	var material = Kit.masonry(CREAM,BROWN,.4,.65)
	var g: Vector3 = SOUTH_GATE
	var x = g.x-20.0
	while x<g.x+20.0:
		var middle = x+BAY*.5
		x += BAY
		if absf(middle-g.x)<5.0 or world.margin_at(Vector3(middle,0,g.z))<-9.0: continue
		var piece = world.place("wall",Vector3(middle,0,g.z),Vector3(BAY,5.6,1.4),material)
		world.block_rect(Rect2(middle-BAY*.5,g.z-.7,BAY,1.4))
		world.screen([piece])
	var towers: Array = []
	for side in [-1.0,1.0]:
		var at = Vector3(g.x+side*6.2,0,g.z)
		towers.append(world.place("pillar_decorated",at,Vector3(3.6,8.6,3.4),material))
		world.block_rect(Rect2(at.x-1.8,g.z-1.7,3.6,3.4))
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
	# The stair to the basement: a kerbed well in the floor, its steps going
	# down into the dark.
	var stair: Vector3 = world.BASEMENT_STAIR
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(.02,.02,.025)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.place("floor",stair+Vector3.UP*.05,Vector3(2.6,.04,3.6),dark,PI/4)
	# (The ground is one slab: the steps are drawn on the dark, each dimmer
	# than the one above it.)
	for i in 5:
		var tread = Kit.gritty(ARENA_STONE*Color(.8,.8,.8)*(.9-i*.19),1.6,true)
		world.place("floor",stair+Vector3(0,.07,1.45-i*.62).rotated(Vector3.UP,PI/4),Vector3(2.5,.03,.56),tread,PI/4)
	for side in [[Vector3(1.5,0,0),.4,3.9],[Vector3(-1.5,0,0),.4,3.9],[Vector3(0,0,-1.95),3.4,.4]]:
		var offset: Vector3 = side[0].rotated(Vector3.UP,PI/4)
		world.place("floor",stair+offset,Vector3(side[1],.5,side[2]),material,PI/4)
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
	# The five elders' thrones, in a row facing the sand: gilded chairs of a
	# man's size, all alike (the inn's seats are of the same height).
	var seats = front-4.2
	for i in THRONES:
		var offset = (i-(THRONES-1)*.5)*THRONE_SPACING
		var throne = world.place("chair",Vector3(x+offset,BOX_FLOOR,seats),Kit.sized("chair",THRONE_HEIGHT),gold,0.0)
		throne.set_meta("throne",true)
		nodes.append(throne)
	# Before them a long table on gilded legs, topped with a single slab of
	# veined marble overhanging it a little all round.
	var reach = (THRONES-1)*THRONE_SPACING+1.0
	var table_at = seats+.95
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
		item(world,["farm_crate","crate","urn","bag"][i],at+Vector3(-1.9,0,1.5),[.3,.7,.8,.7][i],.4*i,.4)
	world.screen(stalls)
	item(world,"cart",Vector3(MARKET.position.x+3.0,0,MARKET.end.y-3.5),2.5,2.5,1.5)
	for spot in [Vector3(MARKET.position.x+6.0,0,MARKET.end.y-2.4),Vector3(MARKET.position.x+7.2,0,MARKET.end.y-3.6)]:
		item(world,"barrel",spot,.95)
	for side in [0.0,1.0]:
		item(world,"bench",middle+Vector3(-5.0+side*8.0,0,5.5),.55,0.0,.9)

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
static func house(world, corner: Vector3, bays: Vector2i, door: String, storeys: int, wear: float, ruin: bool = false) -> void:
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

# Houses line the alleys, both sides, and fill the gaps along the ring
# street. Most are in a poor way; a few are kept up.
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
		[Vector3(-195,0,-16),Vector2i(2,2),"west",1],[Vector3(-195,0,-30),Vector2i(2,2),"west",1],[Vector3(-196,0,24),Vector2i(2,2),"west",1]]
	for i in plans.size():
		var plan = plans[i]
		# One house in four is kept up; the rest run from shabby to derelict.
		var wear = rng.randf_range(.3,.45) if i%4==1 else rng.randf_range(.65,1.0)
		house(world,plan[0],plan[1],plan[2],plan[3],wear)
	# Out at the town's edges, houses have fallen in and been left.
	house(world,Vector3(-324,0,-38),Vector2i(2,2),"south",1,1.0,true)
	house(world,Vector3(-192,0,-56),Vector2i(2,2),"south",1,1.0,true)
	house(world,Vector3(-322,0,26),Vector2i(2,2),"south",1,1.0,true)

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
	for i in 900:
		var at = Vector3(rng.randf_range(-344.0,-183.0),0,rng.randf_range(-86.0,76.0))
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
