extends RefCounted
## The wild places of the outdoor world (scripts/overworld.gd) that lie off
## the track: the desert south of the town, with the great dune and the camp
## a new character wakes at, and the mouth of the bandits' cave in the
## northern rocks.
const Art = preload("res://scripts/assets.gd")
const Kit = preload("res://scripts/world_art.gd")
const Desert = preload("res://scripts/world_desert.gd")

static func build(world) -> void:
	south_desert(world)
	camp(world)
	cave_mouth(world)

# The way out of the town's southern alley, trodden as far as the dune's
# foot, and what grows and lies on the sand beyond.
static func south_desert(world) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 9133
	var gap: Vector3 = world.SOUTH_GAP
	var foot = Vector3(world.DUNE.x+14.0,0,world.DUNE.z-world.DUNE_RADII.y-2.0)
	for i in 60:
		var t = i/59.0
		var at = Vector3(gap.x,0,gap.z+4.0).lerp(Vector3(gap.x,0,100.0),minf(t*2.0,1.0)).lerp(foot,maxf(t*2.0-1.0,0.0))
		world.dab_disc(world.TRACK,at+Vector3(sin(t*9.0)*1.2,0,0),1.6,2.0,.7*(1.0-t*.6))
	world.add_place("southern desert","desert",world.DUNE,world.DUNE_RADII.x)
	var leaves = Kit.shared("Leaves")
	for i in 900:
		var at = Vector3(world.DUNE.x+rng.randf_range(-62.0,62.0),0,rng.randf_range(gap.z+6.0,world.SOUTH_REACH.y+4.0))
		var c = world.to_cell(at)
		if not world.on_map(c.x,c.y): continue
		var cell = world.index(c.x,c.y)
		if world.cells[cell] != world.OPEN or world.margins[cell]<1.5 or world.paint[cell*4+world.TRACK]>40: continue
		# The dune's crown is bare sand, and the camp's ground is kept clear.
		var up = world.dune_height(at.x,at.z)
		if up>world.DUNE_HEIGHT*.55 or at.distance_to(world.START)<9.0: continue
		var roll = rng.randf()
		if roll<.5: Desert.tuft(world,at)
		elif roll<.84: Desert.stone(world,at)
		elif roll<.9: Desert.shrub(world,at)
		elif roll<.96: world.batch("agave",world.stance(at,Kit.sized("agave",rng.randf_range(.6,1.2)),rng.randf_range(0,TAU)),leaves)
		elif up<.3 and world.margins[cell]>6.0:
			if rng.randf()<.5: Desert.boulder(world,at,rng.randf_range(2.2,4.2),rng.randf_range(1.6,3.0))
			else:
				var tree = world.prop("dead_tree",at,rng.randf_range(3.2,4.8),rng.randf_range(0,TAU))
				world.block_disc(at,.45)
				world.screen([tree])

# The camp on the dune's crown: a fire ringed with stones, the log he sits
# on facing it and the town below, a sleeping pad, and his supplies.
static func camp(world) -> void:
	var at: Vector3 = world.START
	world.add_place("camp","camp",at,7.0)
	var charred = Kit.gritty(Color(.13,.10,.08),1.4,true)
	var bark = Kit.gritty(Color(.34,.24,.15),1.6,true)
	# The log he sits on (the hero is placed on it: it does not block him).
	var seat = log_of(world,at+Vector3(0,.2,.12),1.7,.21,0.0,bark)
	seat.name = "CampSeat"
	# The fire, a stride north of him.
	var fire_at = at+Vector3(0,0,-2.1)
	for i in 9:
		var angle = i*TAU/9.0
		var id: String = ["stone_a","stone_b","stone_c"][i%3]
		world.place(id,fire_at+Vector3(cos(angle)*.62,-.04,sin(angle)*.62),Kit.sized(id,.2+.05*(i%2)),Kit.rock(id,Color(.5,.46,.42)),angle*2.3)
	world.place("floor",fire_at+Vector3.UP*.012,Vector3(1.0,.02,1.0),Kit.gritty(Color(.07,.06,.06),1.0,true),.4)
	for i in 4: log_of(world,fire_at+Vector3(0,.12+.05*(i%2),0),.82,.07,i*PI/4+.3,charred,.28)
	var light = OmniLight3D.new()
	light.light_energy = 1.0
	light.light_cull_mask = 0
	light.omni_range = 1.0
	var fire = preload("res://scripts/torch_flame.gd").new()
	fire.position = fire_at+Vector3.UP*(world.lift(fire_at)+.2)
	fire.scale = Vector3.ONE*1.5
	light.position = fire.position
	world.add_child(light)
	fire.setup(light,3.7)
	world.add_child(fire)
	world.block_disc(fire_at,.75,world.LOW,false)
	world.dab_disc(world.SHADE,fire_at,1.0,1.2,.5)
	# The sleeping pad: a woven mat with a blanket rolled at its head.
	var pad_at = at+Vector3(-2.3,0,-.6)
	world.place("floor",pad_at+Vector3.UP*.015,Vector3(.85,.05,2.0),Kit.gritty(Color(.46,.33,.22),2.6,true),.5)
	world.place("floor",pad_at+Vector3.UP*.06,Vector3(.7,.035,1.25),Kit.gritty(Color(.36,.13,.10),2.6,true),.5)
	log_of(world,pad_at+Vector3(-.42,.11,-.76),.74,.11,.5+PI/2,Kit.gritty(Color(.52,.45,.34),2.4,true))
	# His supplies, on the fire's other side.
	for item in [["crate",Vector3(2.2,0,-.9),.62,.3],["bag",Vector3(2.9,0,-.1),.55,1.2],["bag",Vector3(2.1,0,.2),.48,2.6],["barrel",Vector3(3.0,0,-1.3),.72,0.0],["bucket",Vector3(1.5,0,-1.5),.3,.8],["pot",Vector3(.9,0,-2.3),.2,0.0]]:
		world.prop(item[0],at+item[1],item[2],item[3])
		if item[2]>.4: world.block_disc(at+item[1],.42,world.LOW,false)

# A log lying on the ground: `length` long, turned to `yaw`.
static func log_of(world, at: Vector3, length: float, radius: float, yaw: float, material: Material, tilt: float = 0.0) -> MeshInstance3D:
	var wood = CylinderMesh.new()
	wood.top_radius = radius*.92
	wood.bottom_radius = radius
	wood.height = length
	wood.radial_segments = 10
	var node = MeshInstance3D.new()
	node.mesh = wood
	node.material_override = material
	world.add_child(node)
	node.position = at+Vector3.UP*world.lift(at)
	node.rotation = Vector3(0,yaw,PI/2-tilt)
	return node

# The cave's mouth: a black opening under a slab of rock, between two great
# boulders, with the bandits' fires and plunder before it.
static func cave_mouth(world) -> void:
	var at: Vector3 = world.CAVE
	world.add_place("cave mouth","cave",at+Vector3(0,0,4),9.0)
	var tint = Color(.9,.84,.78)
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(.015,.012,.01)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.place("floor",at+Vector3(0,0,-.6),Vector3(7.0,3.6,.3),dark)
	world.dab_disc(world.SHADE,at+Vector3(0,0,.6),2.6,2.4,1.0)
	var rocks: Array = []
	# (The western rock, on the camera's side, stands back and lower, so the
	# opening is seen past it.)
	rocks.append(world.place("boulder_a",at+Vector3(-5.6,-.6,-2.0),Vector3(6.0,5.6,5.6),Kit.rock("boulder_a",tint),-.6))
	rocks.append(world.place("boulder_c",at+Vector3(5.6,-.6,-1.6),Vector3(6.4,7.4,6.0),Kit.rock("boulder_c",tint),.6))
	for side in [-1.0,1.0]: world.block_disc(at+Vector3(side*5.6,0,-.6),2.6)
	rocks.append(world.place("boulder_b",at+Vector3(0,2.9,-3.3),Vector3(13.0,4.6,7.0),Kit.rock("boulder_b",tint),.2))
	rocks.append(world.place("boulder_d",at+Vector3(-1.0,3.6,-9.5),Vector3(18.0,6.0,9.0),Kit.rock("boulder_d",tint),1.1))
	world.screen(rocks)
	for z in range(int(at.z)-9,int(at.z)-1):
		for x in range(int(at.x)-9,int(at.x)+10): world.block_cell(x,z)
	# The path in is trodden, and lit.
	for z in range(int(at.z),-40):
		world.dab_disc(world.TRACK,Vector3(at.x+sin(z*.3)*1.0,0,z),1.4,2.0,.75)
	for side in [-1.0,1.0]: world.brazier(at+Vector3(side*2.9,0,3.2),.8,.5)
	for item in [["crate",Vector3(-4.4,0,6.2),.85,.4],["crate",Vector3(-5.2,0,7.4),.7,1.3],["barrel",Vector3(4.6,0,6.8),.9,0.0],["bag",Vector3(4.0,0,8.0),.6,2.0],["weapon_stand",Vector3(5.2,0,9.4),1.25,-.6]]:
		world.prop(item[0],at+item[1],item[2],item[3])
		world.block_disc(at+item[1],.5,world.LOW)
