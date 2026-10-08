extends RefCounted
## The desert of the outdoor world (scripts/overworld.gd): the rock rim that
## walls the whole basin in, and what lies on the sand between the town and
## the temple.
const Kit = preload("res://scripts/world_art.gd")
# Scanned desert boulders, and a twenty-metre run of scanned cliff.
const ROCKS = ["boulder_a","boulder_b","boulder_c","boulder_d"]
const STONES = ["stone_a","stone_b","stone_c"]
# The same stone, a little paler or darker from rock to rock.
const ROCK_TINTS = [Color(1.06,.98,.9),Color(.9,.84,.78)]
# The camera looks from the south-west: rocks on those sides stand between it
# and the open ground, so they start low and rise away from it.
const TOWARD_CAMERA = Vector2(-.7071,.7071)

static func build(world) -> void:
	rim(world)
	caravan(world)
	oasis(world)
	ruins(world)
	waymarks(world)
	outcrops(world)
	scatter(world)

# Boulders and crags fill a band all round the open ground: sheer on the far
# (north and east) sides, a rising slope of rock on the camera's sides.
static func rim(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var step = 4.0
	var z = world.NORTH+2.0
	while z<world.SOUTH-2.0:
		var x = world.WEST+2.0
		while x<world.EAST-2.0:
			var at = Vector3(x+rng.randf_range(-1.6,1.6),0,z+rng.randf_range(-1.6,1.6))
			x += step
			var depth = -world.margin_at(at)
			if depth<-.3 or depth>world.RIM: continue
			var reserved = false
			for area in world.keep_clear:
				if area.grow(5.0).has_point(Vector2(at.x,at.z)): reserved = true
			if reserved: continue
			var c = world.to_cell(at)
			if not world.on_map(c.x-1,c.y-1) or not world.on_map(c.x+1,c.y+1): continue
			var inward = Vector2(world.margins[world.index(c.x+1,c.y)]-world.margins[world.index(c.x-1,c.y)],world.margins[world.index(c.x,c.y+1)]-world.margins[world.index(c.x,c.y-1)])
			if inward.length()<.01: continue
			inward = inward.normalized()
			var near = (-inward).dot(TOWARD_CAMERA)>.12
			var width: float
			var height: float
			if near:
				width = lerpf(4.2,12.0,clampf(depth/24.0,0,1))*rng.randf_range(.8,1.25)
				height = clampf(1.3+depth*.7,1.3,13.0)*rng.randf_range(.75,1.15)
			else:
				width = lerpf(6.0,13.0,clampf(depth/20.0,0,1))*rng.randf_range(.8,1.25)
				height = lerpf(6.5,18.0,clampf(depth/16.0,0,1))*rng.randf_range(.75,1.25)
			# Bigger rocks stand further apart.
			if rng.randf()>step*step/(width*width*.42): continue
			# A rock at the very edge is pushed back until it only just overhangs.
			var short = width*.4-depth
			if short>0: at -= Vector3(inward.x,0,inward.y)*short
			var size = Vector3(width,height,width*rng.randf_range(.8,1.2))
			at.y = -height*.14
			world.rim_rocks.append(at)
			var tint: Color = ROCK_TINTS[rng.randi_range(0,1)]
			if not near and depth<16.0 and rng.randf()<.55:
				# The far walls are faced with runs of cliff, laid along the edge.
				var along = Vector2(-inward.y,inward.x)*(1.0 if rng.randf()<.5 else -1.0)
				size = Vector3(width*rng.randf_range(2.0,2.8),height*rng.randf_range(.9,1.2),width*rng.randf_range(.9,1.2))
				at.y = -size.y*.1
				world.batch("crag",world.stance(at,size,atan2(-along.y,along.x)),Kit.rock("crag",tint))
			else:
				var id: String = ROCKS[rng.randi_range(0,3)]
				world.batch(id,world.stance(at,size,rng.randf_range(0,TAU),rng.randf_range(-.12,.12)),Kit.rock(id,tint))
		z += step

# A lone rock on the open sand, as a node, so a tall one can turn see-through.
static func boulder(world, at: Vector3, width: float, height: float) -> Node3D:
	var rng: RandomNumberGenerator = world.rng
	var id: String = ROCKS[rng.randi_range(0,3)]
	var rock = world.place(id,at+Vector3.DOWN*height*.14,Vector3(width,height,width*rng.randf_range(.8,1.2)),Kit.rock(id,ROCK_TINTS[rng.randi_range(0,1)]),rng.randf_range(0,TAU))
	world.block_disc(at,width*.4)
	if height>2.4: world.screen([rock])
	return rock

# Whether a spot on the open sand is free for a landmark `radius` across.
static func clear_site(world, at: Vector3, radius: float) -> bool:
	if world.margin_at(at)<radius+5.0 or at.distance_to(world.CARAVAN)<radius+10.0: return false
	if absf(at.z-world.track_z(at.x))<radius+7.0: return false
	if at.x<world.TOWN_GATE.x+22.0 or at.x>world.TEMPLE_DOOR.x-58.0: return false
	for spot in world.places:
		if spot.at.distance_to(at)<spot.radius+radius+6.0: return false
	return true

# Outcrops break up the open sand: a few rocks leaning together.
static func outcrops(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var made = 0
	for attempt in 400:
		if made>=11: break
		var at = Vector3(rng.randf_range(world.TOWN_GATE.x+25.0,world.TEMPLE_DOOR.x-60.0),0,rng.randf_range(-60.0,60.0))
		if not clear_site(world,at,7.0): continue
		made += 1
		world.add_place("outcrop","outcrop",at,7.0)
		var big = rng.randf()<.35
		for i in rng.randi_range(2,5):
			var offset = Vector3(rng.randf_range(-4.5,4.5),0,rng.randf_range(-4.5,4.5))
			var width = rng.randf_range(2.2,5.5)*(1.5 if big and i==0 else 1.0)
			boulder(world,at+offset,width,width*rng.randf_range(.45,.8)*(1.3 if big and i==0 else 1.0))

# Where a new character wakes: a caravan's cart and load, left by the track.
static func caravan(world) -> void:
	var at: Vector3 = world.CARAVAN
	world.add_place("caravan","camp",at,9.0)
	var cart = world.prop("cart",at+Vector3(3.6,0,-3.2),2.5,.5)
	world.block_disc(at+Vector3(3.6,0,-3.2),1.5,world.LOW)
	for item in [["crate",Vector3(1.2,0,-4.2),.85,.3],["crate",Vector3(2.0,0,-5.0),.75,1.1],["barrel",Vector3(5.6,0,-1.4),.9,0.0],["bag",Vector3(.6,0,-3.2),.6,2.0],["urn",Vector3(5.0,0,-4.6),.7,0.0]]:
		world.prop(item[0],at+item[1],item[2],item[3])
		world.block_disc(at+item[1],.45,world.LOW)
	world.screen([cart])

# A pool ringed with palms, south of the track.
static func oasis(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var at = Vector3(-84,0,30)
	world.add_place("oasis","oasis",at,15.0)
	for lobe in [[Vector3.ZERO,5.2],[Vector3(4.5,0,2.0),3.6],[Vector3(-3.6,0,-2.2),3.0]]:
		world.dab_disc(world.WATER,at+lobe[0],lobe[1],2.6)
	var c = world.to_cell(at)
	for z in range(c.y-12,c.y+13):
		for x in range(c.x-12,c.x+13):
			if world.paint[world.index(x,z)*4+world.WATER]>150: world.block_cell(x,z,world.LOW)
	for i in 9:
		var angle = i*TAU/9.0+rng.randf_range(-.25,.25)
		var spot = at+Vector3(cos(angle),0,sin(angle))*rng.randf_range(8.5,11.5)
		palm(world,spot,rng.randf_range(6.0,8.5))
	for i in 26:
		var angle = rng.randf_range(0,TAU)
		var spot = at+Vector3(cos(angle),0,sin(angle))*rng.randf_range(7.0,14.0)
		tuft(world,spot,Color(.62,.72,.36))
	for i in 5:
		var angle = rng.randf_range(0,TAU)
		boulder(world,at+Vector3(cos(angle),0,sin(angle))*rng.randf_range(8.0,12.0),rng.randf_range(1.2,2.2),rng.randf_range(.6,1.1))

static func palm(world, at: Vector3, height: float) -> Node3D:
	var rng: RandomNumberGenerator = world.rng
	var tree = world.prop(["palm_a","palm_b","palm_c"][rng.randi_range(0,2)],at,height,rng.randf_range(0,TAU))
	world.block_disc(at,.5)
	# (Never see-through: a palm's slender trunk and high crown hide little,
	# and faded it looked to vanish.)
	return tree

static func tuft(world, at: Vector3, tint: Color = Color(.86,.70,.42)) -> void:
	var rng: RandomNumberGenerator = world.rng
	var key = "grass"+tint.to_html()
	if not Kit.cache.has(key):
		var m: StandardMaterial3D = Kit.shared("Grass").duplicate()
		m.albedo_color = tint
		Kit.cache[key] = m
	var height = rng.randf_range(.45,.95)
	world.batch("dry_grass",world.stance(at,Kit.sized("dry_grass",height),rng.randf_range(0,TAU)),Kit.cache[key],false)

# A loose stone lying on the sand.
static func stone(world, at: Vector3) -> void:
	var rng: RandomNumberGenerator = world.rng
	var id: String = STONES[rng.randi_range(0,2)]
	world.batch(id,world.stance(at+Vector3.DOWN*.03,Kit.SIZE[id]*rng.randf_range(1.6,4.2),rng.randf_range(0,TAU)),Kit.rock(id,ROCK_TINTS[rng.randi_range(0,1)],.3),false)

# A dry desert shrub, or a low clump of scrub.
static func shrub(world, at: Vector3) -> void:
	var rng: RandomNumberGenerator = world.rng
	if rng.randf()<.45:
		var id = "shrub_a" if rng.randf()<.5 else "shrub_b"
		world.batch(id,world.stance(at,Kit.sized(id,rng.randf_range(.7,1.25)),rng.randf_range(0,TAU)),Kit.shared("shrub_02"))
	else: world.batch("scrub",world.stance(at,Kit.sized("scrub",rng.randf_range(.35,.6)),rng.randf_range(0,TAU)),Kit.shared("wild_rooibos_bush"))

# Weathered limestone, for what an older people left in the sand.
static func ruin_stone() -> ShaderMaterial:
	return Kit.masonry(Color(.86,.76,.62))

# The stumps of a colonnade and a fallen wall, north of the track.
static func ruins(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var at = Vector3(4,0,-30)
	world.add_place("ruins","ruin",at,16.0)
	var stone = ruin_stone()
	world.dab_disc(world.PAVING,at,7.0,5.0,.8)
	for row in 2:
		for i in 5:
			var spot = at+Vector3(-10.0+i*5.0,0,-4.0+row*8.0)
			# Some columns still stand whole; most are broken off.
			var whole = rng.randf()<.4
			var height = 5.6 if whole else rng.randf_range(1.2,3.4)
			var column = world.place("column",spot,Vector3(1.15,height,1.15),stone,rng.randf_range(0,TAU))
			world.block_disc(spot,.7)
			if height>2.4: world.screen([column])
			if not whole and rng.randf()<.6:
				world.place("rubble",spot+Vector3(rng.randf_range(-1.6,1.6),0,rng.randf_range(1.0,2.0)),Vector3(2.4,.7,1.3),stone,rng.randf_range(0,TAU))
	var wall = world.place("wall_broken",at+Vector3(-4,0,-9.5),Vector3(6.0,3.6,1.0),stone)
	world.block_rect(Rect2(at.x-7.0,at.z-10.0,6.0,1.0))
	var stub = world.place("wall_half",at+Vector3(4.5,0,-9.5),Vector3(3.0,2.2,1.0),stone)
	world.block_rect(Rect2(at.x+3.0,at.z-10.0,3.0,1.0))
	world.screen([wall,stub])
	for i in 4: boulder(world,at+Vector3(rng.randf_range(-13,13),0,rng.randf_range(7.5,11.0)),rng.randf_range(1.4,2.6),rng.randf_range(.7,1.3))

# Pairs of old boundary stones mark the track, and flagstones still show
# through the sand near the town and the temple.
static func waymarks(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var stone = ruin_stone()
	var x = world.TOWN_GATE.x+38.0
	while x<world.TEMPLE_DOOR.x-40.0:
		var middle = Vector3(x,0,world.track_z(x))
		# The caravan stands on the track where the hero starts.
		if middle.distance_to(world.spawn)>14.0:
			for side in [-1.0,1.0]:
				var spot = middle+Vector3(rng.randf_range(-.6,.6),0,side*4.6)
				var height = rng.randf_range(1.5,2.6) if rng.randf()<.75 else rng.randf_range(.5,1.0)
				world.place("pillar",spot,Vector3(.9,height,.9),stone,rng.randf_range(-.2,.2))
				world.block_disc(spot,.5)
		x += 46.0

# Dry grass, shrubs, agaves, loose stones and a few dead trees over the open sand.
static func scatter(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var noise: FastNoiseLite = world.noise
	var leaves = Kit.shared("Leaves")
	for i in 3700:
		var at = Vector3(rng.randf_range(world.TOWN_GATE.x+3.0,world.TEMPLE_DOOR.x-6.0),0,rng.randf_range(-74.0,74.0))
		var c = world.to_cell(at)
		var cell = world.index(c.x,c.y)
		if world.cells[cell] != world.OPEN or world.margins[cell]<1.5: continue
		if world.paint[cell*4+world.TRACK]>40 or world.paint[cell*4+world.PAVING]>40 or world.paint[cell*4+world.WATER]>10: continue
		# The temple's court is kept clear.
		if at.x>world.TEMPLE_DOOR.x-36.0 and absf(at.z)<26.0 and rng.randf()<.8: continue
		# Growth gathers in patches and under the rim, and thins on the open dunes.
		var patch = noise.get_noise_2d(at.x*4.0,at.z*4.0)+clampf(1.0-world.margins[cell]/14.0,0.0,1.0)*.5
		var roll = rng.randf()
		if roll<.5:
			if patch>.05: tuft(world,at)
		elif roll<.83:
			stone(world,at)
		elif roll<.875:
			if patch>.12: shrub(world,at)
		elif roll<.945:
			if patch>.0 and at.distance_to(world.CARAVAN)>5.0:
				world.batch("agave",world.stance(at,Kit.sized("agave",rng.randf_range(.6,1.2)),rng.randf_range(0,TAU)),leaves)
		elif roll<.953 and at.distance_to(world.CARAVAN)>8.0:
			var id = "tree" if rng.randf()<.5 else "dead_tree"
			var tree = world.prop(id,at,rng.randf_range(3.2,5.2),rng.randf_range(0,TAU))
			world.block_disc(at,.45)
			world.screen([tree])
