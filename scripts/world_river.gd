extends RefCounted
## The river of the outdoor world (scripts/overworld.gd): it comes down out
## of the rocks north of the town, runs the length of the town's west side
## (its border there, where the town wall once stood), bends round the
## desert's south-west and runs east along its south into the mountains.
## The water is painted into the ground (the WATER channel; the ground
## shader carries it downstream along the FLOW map); its banks are green with
## reeds and grass, with palms and olives set back from the water, thickest on
## the far bank, which no one can reach.
const Kit = preload("res://scripts/world_art.gd")
const Desert = preload("res://scripts/world_desert.gd")
# The greens of what grows by the water: reeds, and grass further up the bank.
const REEDS = Color(.50,.58,.30)
const GRASS = Color(.58,.66,.34)

static func build(world) -> void:
	water(world)
	banks(world)

# The water: deepest in the middle, shallowing to wet sand at the edges; and
# the way it flows at each cell (down the town's side, then east), for the
# ground shader to carry its ripples along.
static func water(world) -> void:
	var half: float = world.RIVER_HALF
	world.flow = PackedByteArray()
	world.flow.resize(world.WIDTH*world.DEPTH*2)
	world.flow.fill(128)
	for z in range(world.NORTH,world.SOUTH):
		for x in range(world.WEST,world.EAST):
			var side: float = world.river_sides[world.index(x,z)]
			if absf(side) > half+3.0: continue
			world.dab(world.WATER,x,z,clampf((half+1.6-absf(side))/3.6,0.0,1.0))
			var i = world.index(x,z)*2
			var downstream: Vector2 = world.river_flow(x,z)
			world.flow[i] = int(clampf(downstream.x*.5+.5,0.0,1.0)*255.0)
			world.flow[i+1] = int(clampf(downstream.y*.5+.5,0.0,1.0)*255.0)

# Reeds at the water's edge, grass up the bank, and trees set back: palms and
# olives along the desert's side (none in the town, whose quay runs to the
# water), and a dense green strip all along the far side.
static func banks(world) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 5101
	var half: float = world.RIVER_HALF
	for i in 26000:
		var at = Vector3(rng.randf_range(world.WEST+2.0,world.EAST-2.0),0,rng.randf_range(world.NORTH+2.0,world.SOUTH-2.0))
		var c = world.to_cell(at)
		if not world.on_map(c.x,c.y): continue
		var cell = world.index(c.x,c.y)
		var side: float = world.river_sides[cell]
		var far = -side-half
		var near = side-half
		# (West of the palace's ground, north of the town, the land on the
		# near side is out of reach like the far bank, and grows the same.)
		var pocket: bool = at.z < world.WALL_NORTH-2.0 and at.x < world.HILL.x-world.HILL_REACH.x-2.0 and near > -1.0
		if pocket: far = near
		if far > 46.0 or (near > 14.0 and not pocket) or absf(side) < half-.6: continue
		# Not among the mountains' or the rim's rocks.
		if world.margins[cell] < 3.0: continue
		if far > -1.0 and world.mountain_depth(at.x,at.z) > -4.0: continue
		var town: bool = at.z > world.WALL_NORTH-2.0 and at.z < world.WALL_SOUTH+3.0 and side > 0.0
		if near > -1.0 and not pocket:
			# The near bank: the desert's side keeps its own scrub higher up,
			# and the town's is paved and kept clear but for a few reeds.
			if world.cells[cell] != world.OPEN or world.paint[cell*4+world.PAVING] > 60: continue
			if town and (near > 2.5 or rng.randf() < .6): continue
			if near < 2.6: reed(world,rng,at,near)
			elif rng.randf() < .7: Desert.tuft(world,at,GRASS*rng.randf_range(.85,1.08))
			elif not town and rng.randf() < .05 and near > 5.0:
				Desert.palm(world,at,rng.randf_range(6.5,9.5))
			continue
		# The far bank, out of reach: reeds, then a green strip of grass and
		# shrubs under palms and olives, thinning out into the sand.
		if far < 2.8:
			reed(world,rng,at,-far)
			continue
		var lush = 1.0-smoothstep(14.0,44.0,far)
		if rng.randf() > lush*.55+.06: continue
		var roll = rng.randf()
		if roll < .62: Desert.tuft(world,at,GRASS.lerp(Color(.86,.70,.42),1.0-lush)*rng.randf_range(.85,1.1))
		elif roll < .78: Desert.shrub(world,at)
		elif roll < .84: Desert.stone(world,at)
		elif roll < .93 and far > 6.0: Desert.palm(world,at,rng.randf_range(6.5,10.0))
		elif far > 8.0:
			var tree = world.prop("olive_a" if rng.randf() < .6 else "olive_b",at,rng.randf_range(3.6,5.6),rng.randf_range(0,TAU))
			world.screen([tree])

# A clump of reeds at the water's edge, `off` metres up the bank from it
# (negative: standing in the shallows): tall green grass, leaning a little.
static func reed(world, rng: RandomNumberGenerator, at: Vector3, off: float) -> void:
	if off < -1.2: return
	var key = "reed"
	if not Kit.cache.has(key):
		var m: StandardMaterial3D = Kit.shared("Grass").duplicate()
		m.albedo_color = REEDS
		Kit.cache[key] = m
	var height = rng.randf_range(1.0,1.9)*(1.0-clampf(off/4.0,0.0,.5))
	var size: Vector3 = Kit.sized("dry_grass",height)
	size.x *= .55; size.z *= .55
	world.batch("dry_grass",world.stance(at,size,rng.randf_range(0,TAU),rng.randf_range(-.1,.1)),Kit.cache[key],false)
