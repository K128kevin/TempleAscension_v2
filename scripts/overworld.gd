extends Node3D
## The outdoor world the temple stands in: a town at the western end, the
## open desert, and the temple's front at the eastern end, on one continuous
## map. X runs east and Z south. A river runs down the town's west side and
## round the desert's south, and mountains close it in on the north and east;
## rock rims the rest. Game drives it through the same interface as a temple
## floor (scripts/temple.gd).
##
## Playable ground is mostly flat, with the palace hill and the camp dune.
## What stands there is raised to its height (`lift`), as are the hero and
## camera, while paths and collision stay on the plane. Beyond the map's
## rock rim, distant terrain extends the ground and forms the horizon.
const Art = preload("res://scripts/assets.gd")
const Kit = preload("res://scripts/world_art.gd")
const Desert = preload("res://scripts/world_desert.gd")
const Horizon = preload("res://scripts/world_horizon.gd")
const Town = preload("res://scripts/world_town.gd")
const Palace = preload("res://scripts/world_palace.gd")
const Front = preload("res://scripts/world_temple_front.gd")
const Wilds = preload("res://scripts/world_wilds.gd")
const Mountains = preload("res://scripts/world_mountains.gd")
const River = preload("res://scripts/world_river.gd")
const Townsfolk = preload("res://scripts/townsfolk.gd")
const Watch = preload("res://scripts/town_watch.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Reflections = preload("res://scripts/reflections.gd")
const GLOW_COLOUR = Front.GLOW
# `level` of the outdoor world, where a temple floor has its index.
const OUTDOORS = -2
# The map's extent in metres.
const WEST = -452
const EAST = 148
const NORTH = -204
const SOUTH = 340
const WIDTH = EAST-WEST
const DEPTH = SOUTH-NORTH
# The town's gate in its east wall, and the temple's door in its west front:
# the two ends of the desert crossing.
const TOWN_GATE = Vector3(-180,0,0)
const TEMPLE_DOOR = Vector3(76,0,0)
# The lost caravan, on the track in the middle of the desert.
const CARAVAN = Vector3(-52,0,-15)
# South of the town's wall, through the south gate at the end of an alley,
# lies the desert a new character wakes in, open to the one the track
# crosses. A great dune stands in it and looks down on the town: its middle,
# its half-size (east-west, north-south) and its height. (`SOUTH_GAP`: the
# alley's end, inside the gate.)
const SOUTH_GAP = Vector3(-226,0,100)
const DUNE = Vector3(-262,0,175)
const DUNE_RADII = Vector2(110,75)
const DUNE_HEIGHT = 22.0
# Where a new character wakes: on top of the dune, by his campfire
# (Data.new_character).
const START = Vector3(-262,0,173)
# The mouth of the bandits' cave, at the head of a defile in the desert's
# northern rocks, before the temple.
const CAVE = Vector3(20,0,-80)
# The stair down to the arena's basement, under its south-eastern stands.
const BASEMENT_STAIR = Vector3(-227.5,0,22.2)
# Where the hero stands, and the way he faces, on coming back out of each
# place.
const OUTSIDE = {"temple":{"at":Vector3(72.5,0,0),"facing":-PI/2},"cave":{"at":Vector3(20,0,-72.5),"facing":0.0},"basement":{"at":Vector3(-230.1,0,25.1),"facing":2.4}}
# Where the hero stands, from the door, on stepping back out of the temple.
const THRESHOLD = Vector3(-3.5,0,0)
# The palace hill: the middle of its level top, half that top's size
# (east-west, north-south), the width of the slope round it, and its height.
# (tools/make_hill.py builds its ground from the same numbers.)
const HILL = Vector3(-254,0,-114)
const HILL_HALF = Vector2(40,22)
const HILL_SLOPE = 12.0
const HILL_HEIGHT = 5.5
# The open ground round the hill reaches this far east and west of its
# middle, and this far north.
const HILL_REACH = Vector2(58,-158)
# The town is closed by a wall, not the rim's rocks (scripts/world_town.gd
# town_wall): along its north side at `WALL_NORTH` and its south side at
# `WALL_SOUTH`, and round the palace hill's ground; on the west the river
# bounds it. Within `walled` no rim rock is raised.
const WALL_NORTH = -78.0
const WALL_SOUTH = 108.0
func walled(at: Vector3) -> bool:
	# (Its east end takes in the gate wall's own corner.)
	if at.x >= TOWN_GATE.x+1.5 or at.z >= WALL_SOUTH+12.0: return false
	# (North of the town, west of the palace hill's ground, the river runs
	# down between rocks.)
	return at.z > WALL_NORTH-3.0 or at.x > HILL.x-HILL_REACH.x-3.0

# The river (scripts/world_river.gd): its middle runs down the town's west
# side at about RIVER_X, bends round at RIVER_BEND (the middle of the bend,
# RIVER_TURN across), and runs east along the desert's south at about
# RIVER_Z, into the mountains. It is RIVER_HALF*2 wide.
const RIVER_X = -378.0
const RIVER_BEND = Vector2(-336,232)
const RIVER_TURN = 42.0
const RIVER_Z = 274.0
const RIVER_HALF = 7.0
# The mountains' foot on the east, behind the temple and running down to the
# river: `MOUNTAIN_EAST` its line behind the temple, from where it turns
# south-west at `MOUNTAIN_TURN` (z) along `MOUNTAIN_SLANT` (metres west for
# each metre south).
const MOUNTAIN_EAST = 86.0
const MOUNTAIN_TURN = 48.0
const MOUNTAIN_SLANT = .56
# How far the rocks reach beyond the edge of the open ground: past anything
# the camera can see from inside.
const RIM = 44.0
# One-metre cells shared by movement, sight and paths.
const OPEN = 0
const SOLID = 1 # Blocks movement and sight.
const LOW = 2 # Blocks movement only: water, low walls, furniture.
var cells = PackedByteArray()
# How far inside the open ground each cell is (negative: among the rocks).
var margins = PackedFloat32Array()
# How far each cell is from the river's middle (river_side).
var river_sides = PackedFloat32Array()
# The ground shader's control map, a byte per channel and cell.
var paint = PackedByteArray()
const PAVING = 0
const TRACK = 1
const SHADE = 2
const WATER = 3
# Which way the water flows at each cell, two bytes (east, south) from 0 to
# 255 about 128 (still): the river's current (scripts/world_river.gd).
var flow = PackedByteArray()
var nav = AStarGrid2D.new()
var noise = FastNoiseLite.new()
var rng = RandomNumberGenerator.new()
var camera: Camera3D
var zoom = 19.0
var level = OUTDOORS
var spawn = Vector3.ZERO
var bounds = Rect2(WEST,NORTH,WIDTH,DEPTH)
var sun: DirectionalLight3D
# The sun's shadow map is laid on a grid fixed to the world's middle; a sun
# turned a little every frame slides that grid under every shadow out here
# (the arena stands 254m from the middle: a fifth of a texel a frame), and
# the shadows' edges crawl back and forth, seeming to shake. So the sun is
# turned only every SUN_STEP seconds, in steps too small to see.
const SUN_STEP = .1
var environment: Environment
# What metal and polish reflect (scripts/reflections.gd), through the day.
var reflection_sky: ShaderMaterial
# The time of day shown (Daylight's clock), how far it is night, and the
# fires: each {"light", "flame", "glow", "reach", "energy"}.
var time = 0.0
var night = -1.0
var fires: Array[Dictionary] = []
var glow_texture: GradientTexture2D
# What a fire's light falls on: everything but the ground (layer 2).
const FIRE_LAYERS = 1
const GROUND_LAYER = 2
var ground: Node3D
# Its material: the water in it reflects the sky (set_time).
var ground_material: ShaderMaterial
var hill: Node3D
# How many of this node's children are the world itself; whatever the game
# adds after them (effects, shots) is raised to the ground it appears on.
var fixtures = 0
# Members a temple floor has, which Game reads on any world.
var exit_point = Vector3.ZERO
var boss_point = Vector3.ZERO
var summon_points: Array[Vector3] = []
var occlusion_targets: Array = []
var fountain = null
# The camera stands to the south-west, so west and south faces are the ones
# seen: the temple's front, at the eastern end, faces the hero walking to it.
const VIEW = Vector3(-15.9,21,15.9)
const BACK = 1.4
# Named places, as {name, kind, at, radius}: the HUD captions them and tests
# find them.
var places: Array[Dictionary] = []
# Things tall enough to hide the hero from the camera, as {box, parts:[{mesh,
# whole, normal, faded, box}], hidden}; they turn see-through while they do.
var screens: Array[Dictionary] = []
# Buildings the hero can walk into (scripts/world_interiors.gd): the "area"
# each stands on, and its "roof" and "front" (the walls on the camera's
# side), lifted away while he is "inside".
var rooms: Array[Dictionary] = []
# The greengrocers' stalls (scripts/world_town.gd stall()), and who keeps
# them (scripts/townsfolk.gd).
var stalls: Array[Dictionary] = []
# The arena's seats, lifted away while the hero is under the stands; and what
# stands under them, seen only then.
var stand_seats: Array = []
var stand_fittings: Array = []
# Its outer wall on the camera's side, lifted away then too, as a room's
# front is: still casting its shadow, so the undercroft stays shaded.
var stand_front: Array = []
var under_stands = false
# The town's people (scripts/townsfolk.gd).
var townsfolk: Node3D
# The town's guards: those at its gates and the palace's (two to a post, in
# the order they were posted), and the pairs walking the town who relieve
# them (scripts/town_watch.gd).
var guard_posts: Array = []
var watch: Node3D
# Floors above the ground indoors: over its "area" a deck stands "low" high
# at "start" and climbs to "high" the way "along" points (a level one has no
# "along").
var decks: Array[Dictionary] = []
var screen_tick = 0.0
# Ground the rim's rocks leave alone: the temple stands there.
var keep_clear: Array[Rect2] = [Rect2(TEMPLE_DOOR.x-3.0,-39,74,78)]
# How far each part of the town has been let go (Kit.masonry's `wear`): the
# arena and the palace are kept spotless, the houses mostly are not.
var upkeep: Dictionary = {}
# Where each of the rim's rocks stands.
var rim_rocks = PackedVector3Array()
# Copies of one mesh drawn in batches, a batch for each patch of ground.
var batches: Dictionary = {}
const BATCH_SPAN = 28.0

func setup(_floor_index: int = OUTDOORS, _run_seed: int = 0) -> void:
	seed_noise()
	cells.resize(WIDTH*DEPTH)
	margins.resize(WIDTH*DEPTH)
	river_sides.resize(WIDTH*DEPTH)
	paint.resize(WIDTH*DEPTH*4)
	setup_sky()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	# Keep the complete distant dune mesh within the opening's view distance.
	camera.far = 3000
	add_child(camera)
	shape_ground()
	spawn = START
	# The town and the temple's court are laid out first, so the desert's
	# scrub and stones keep off their paving.
	Town.build(self)
	Palace.build(self)
	Front.build(self)
	Desert.build(self)
	Wilds.build(self)
	River.build(self)
	Mountains.build(self)
	flush_batches()
	lay_ground()
	nav.region = Rect2i(WEST,NORTH,WIDTH,DEPTH)
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for z in range(NORTH,SOUTH):
		for x in range(WEST,EAST):
			if cells[index(x,z)] != OPEN: nav.set_point_solid(Vector2i(x,z))
	townsfolk = Townsfolk.new()
	townsfolk.name = "Townsfolk"
	add_child(townsfolk)
	townsfolk.setup(self)
	watch = Watch.new()
	watch.name = "Watch"
	add_child(watch)
	watch.setup(self)
	fixtures = get_child_count()
	follow(spawn,1)

# The world is the same for every character.
func seed_noise() -> void:
	noise.seed = 20
	noise.frequency = .01
	rng.seed = 4177

# The height of the ground at a point: zero everywhere but on the palace hill,
# which rises smoothly over its slope to a level top, and on a floor above
# the ground indoors.
func height_at(x: float, z: float) -> float:
	var outside = Vector2(maxf(absf(x-HILL.x)-HILL_HALF.x,0.0),maxf(absf(z-HILL.z)-HILL_HALF.y,0.0)).length()
	var t = clampf(1.0-outside/HILL_SLOPE,0.0,1.0)
	var height = HILL_HEIGHT*t*t*(3.0-2.0*t)+dune_height(x,z)
	for deck in decks:
		if deck.area.has_point(Vector2(x,z)): return height+lerpf(deck.low,deck.high,clampf((Vector2(x,z)-deck.start).dot(deck.along),0.0,1.0))
	return height

# The dune's own height: a great, long, gently sloping mound (its sides
# never steeper than about one in two), with a small flat crown.
func dune_height(x: float, z: float) -> float:
	var t = clampf((1.0-Vector2((x-DUNE.x)/DUNE_RADII.x,(z-DUNE.z)/DUNE_RADII.y).length())/.92,0.0,1.0)
	return DUNE_HEIGHT*t*t*(3.0-2.0*t)

func lift(at: Vector3) -> float:
	return height_at(at.x,at.z)

# The sky's one light is the sun by day and the moon by night
# (scripts/daylight.gd); `set_time` moves and colours it.
func setup_sky() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.80,.66,.46)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.70,.78,.96)
	e.ambient_light_energy = .4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# (Its white point raised, so the brightest marble eases into white
	# rather than clipping to it.)
	e.tonemap_white = 1.3
	e.fog_enabled = false
	e.fog_sky_affect = 0.0
	# The image is sky only. The distant ground mesh supplies the horizon;
	# the sky shader concentrates the stars and moon into the opening view.
	# The same panorama supplies the night reflections.
	reflection_sky = Reflections.apply(e,"desert")
	reflection_sky.set_shader_parameter("night_panorama",load("res://assets/textures/desert_sky_only.png"))
	e.background_energy_multiplier = 1.0
	env.environment = e
	environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.name = "SkyLight"
	sun.light_color = Color(1.0,.92,.80)
	sun.light_energy = .95
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90
	sun.shadow_bias = .3
	sun.shadow_normal_bias = 4.0
	# The temple's torches cast hard, cheap shadows (project settings); the
	# sun's long shadows need a finer, filtered map.
	RenderingServer.directional_shadow_atlas_set_size(4096,true)
	# (Filtered finely enough that their edges show no teeth.)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	add_child(sun)
	set_time(Daylight.MORNING+400.0)

# Sets the sky to a time of the day's cycle: the sun's or the moon's place,
# colour and strength, the ambient light, the sky's colour, the morning's
# mist, and how far the fires light what is round them.
func set_time(clock: float) -> void:
	var sky: Dictionary = Daylight.sky(clock)
	time = Daylight.of_day(clock)
	sun.light_color = sky.light
	sun.light_energy = sky.energy
	sun.visible = sky.energy > .004
	var toward: Vector3 = Daylight.sky(floorf(clock/SUN_STEP)*SUN_STEP).toward
	if not sun.global_transform.basis.z.is_equal_approx(toward): sun.look_at_from_position(toward*100.0,Vector3.ZERO)
	environment.background_color = sky.sky
	environment.background_mode = Environment.BG_SKY if sky.night >= .999 else Environment.BG_COLOR
	# The water reflects the sky overhead: bluer than the dust at the horizon,
	# and as bright as the light it sheds.
	if ground_material != null:
		ground_material.set_shader_parameter("sky_colour",sky.sky.lerp(sky.ambient,.65)*clampf(sky.ambient_energy*2.2,.15,1.0))
	environment.ambient_light_color = sky.ambient
	environment.ambient_light_energy = sky.ambient_energy
	Reflections.daylight(reflection_sky,sky)
	environment.fog_enabled = sky.fog > .0002
	environment.fog_density = sky.fog
	environment.fog_light_color = sky.fog_colour
	if absf(sky.night-night) < .01 and (sky.night > 0.0) == (night > 0.0): return
	night = sky.night
	for fire in fires:
		fire.flame.base_energy = fire.energy*night
		fire.light.omni_range = fire.reach if night > 0.0 else 1.0
		fire.light.light_cull_mask = FIRE_LAYERS if night > 0.0 else 0
		fire.glow.material_override.albedo_color = Color(1.0,.62,.30,.8*night)

# A fire: its flame, the light it throws by night on whatever stands near
# (never by day, when the fire is seen and not its light), and the glow it
# lays on the ground then. `at` is where the flame burns, in the world;
# `size` the flame's, and `reach` how far its light carries.
func fire(at: Vector3, size: float, reach: float, energy: float, phase: float) -> Node3D:
	var light = OmniLight3D.new()
	light.light_energy = 0.0
	light.light_cull_mask = 0
	light.omni_range = 1.0
	light.omni_attenuation = 1.2
	var flame = preload("res://scripts/torch_flame.gd").new()
	flame.position = at
	flame.scale = Vector3.ONE*size
	light.position = at+Vector3.UP*.4
	add_child(light)
	flame.setup(light,phase)
	add_child(flame)
	# The ground is one slab, lit by too few lights at once to take every
	# fire's: each fire's glow is laid on it instead.
	var glow = MeshInstance3D.new()
	var sheet = PlaneMesh.new()
	sheet.size = Vector2.ONE*reach*1.7
	glow.mesh = sheet
	var lit = StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lit.albedo_texture = fire_glow()
	lit.albedo_color = Color(1.0,.62,.30,0.0)
	lit.disable_fog = true
	glow.material_override = lit
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(at.x,height_at(at.x,at.z)+.05,at.z)
	add_child(glow)
	fires.append({"light":light,"flame":flame,"glow":glow,"reach":reach,"energy":energy})
	night = -1.0
	return flame

func fire_glow() -> GradientTexture2D:
	if glow_texture == null:
		glow_texture = GradientTexture2D.new()
		glow_texture.width = 128; glow_texture.height = 128
		glow_texture.fill = GradientTexture2D.FILL_RADIAL
		glow_texture.fill_from = Vector2(.5,.5); glow_texture.fill_to = Vector2(1,.5)
		var fading = Gradient.new()
		fading.offsets = PackedFloat32Array([0,.12,.4,1])
		fading.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,.75),Color(1,1,1,.25),Color(1,1,1,0)])
		glow_texture.gradient = fading
	return glow_texture

func index(x: int, z: int) -> int:
	return (z-NORTH)*WIDTH+(x-WEST)

func on_map(x: int, z: int) -> bool:
	return x>=WEST and x<EAST and z>=NORTH and z<SOUTH

func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x+.5),floori(p.z+.5))

# How far north of the track the open desert reaches at `x`: its edge
# wanders in and out, and closes in on the temple's front. (At the town's
# gate it runs straight, for the gate wall to stand on.)
func half_width(x: float) -> float:
	var half = 60.0+9.0*noise.get_noise_1d(x*1.3)+4.0*noise.get_noise_1d(x*5.0+4000.0)
	half = lerpf(-WALL_NORTH,half,smoothstep(TOWN_GATE.x-22.0,TOWN_GATE.x+6.0,x))
	return lerpf(half,46.0,smoothstep(TEMPLE_DOOR.x-46.0,TEMPLE_DOOR.x,x))

# The mountains' foot on the east at `z` (see MOUNTAIN_EAST): straight
# behind the temple, turning in a broad curve to slant south-west.
func east_edge(z: float) -> float:
	var past = z-MOUNTAIN_TURN
	var turned = (sqrt(past*past+900.0)+past)*.5
	return MOUNTAIN_EAST-MOUNTAIN_SLANT*turned+3.0*noise.get_noise_1d(z*4.0+13000.0)

# How far a point lies from the river's middle, signed: positive on the
# town's and desert's side (east of it, then north), negative across it.
func river_side(x: float, z: float) -> float:
	# Down the town's side, wandering a little (measured square to its
	# course, where it runs aslant).
	var slant = river_x(z+1.0)-river_x(z)
	var down = (x-river_x(z))/sqrt(1.0+slant*slant)
	if z > RIVER_BEND.y: down = INF if x > RIVER_BEND.x else -INF
	# Round the bend.
	var round = RIVER_TURN-Vector2(x,z).distance_to(RIVER_BEND) if x <= RIVER_BEND.x and z >= RIVER_BEND.y else INF
	# And along the desert's south.
	var along = river_z(x)-z if x >= RIVER_BEND.x else INF
	var best = down
	for side in [round,along]:
		if absf(side) < absf(best): best = side
	return best

# The way the river flows past a point near it: down the town's side,
# round the bend and east.
func river_flow(x: float, z: float) -> Vector2:
	if z <= RIVER_BEND.y and (x < RIVER_BEND.x or absf(x-river_x(z)) < absf(river_z(x)-z)):
		return Vector2(river_x(z+1.0)-river_x(z),1.0).normalized()
	if x <= RIVER_BEND.x:
		var out = Vector2(x,z)-RIVER_BEND
		return Vector2(out.y,-out.x).normalized()
	return Vector2(1.0,river_z(x+1.0)-river_z(x)).normalized()

# (Its wandering eases off into the bend, to meet it.)
func river_x(z: float) -> float:
	# (Along the town, between its quays, it runs straighter.)
	var calm = 1.0-.7*smoothstep(WALL_NORTH-50.0,WALL_NORTH-10.0,z)*(1.0-smoothstep(WALL_SOUTH+10.0,WALL_SOUTH+50.0,z))
	# North of the town it bends away north-west, winding, into the
	# mountains.
	var past = WALL_NORTH-12.0-z
	var away = (sqrt(past*past+400.0)+past)*.5
	return RIVER_X+(2.5*sin(z*.021)+1.5*sin(z*.057+1.3))*calm*(1.0-smoothstep(RIVER_BEND.y-60.0,RIVER_BEND.y,z))-away*.5-9.0*sin(away*.045)

func river_z(x: float) -> float:
	var run = x-RIVER_BEND.x
	return RIVER_BEND.y+RIVER_TURN+(7.0*sin(run*.013)+2.0*sin(run*.041+.7))*smoothstep(0.0,50.0,run)

# How far inside the open ground a point is; negative among the rim's rocks
# and the mountains. (The river and what lies across it count as open: they
# are kept from the hero as water, not rock: shape_ground.)
func margin(x: float, z: float, side: float = NAN) -> float:
	# The town, between its walls and from its gate to the river. (Its bounds
	# run straight, for its wall to stand on.)
	var town = minf(minf(z-WALL_NORTH,WALL_SOUTH-z),TOWN_GATE.x+2.0-x)
	# North of the town the ground runs on, round the palace hill.
	var round_hill = minf(HILL_REACH.x-absf(x-HILL.x),minf(z-HILL_REACH.y,-60.0-z))
	# The desert, from the track's north edge (or, west of the town's gate,
	# the town's south wall) down to the river, and west of the mountains.
	var north = z+half_width(x) if x > TOWN_GATE.x else z-WALL_SOUTH-2.0
	var desert = minf(north,(east_edge(z)-x)*.87)
	# (The way through the south gate joins the town to it.)
	desert = maxf(desert,minf(9.0-absf(x-SOUTH_GAP.x),minf(z-SOUTH_GAP.z,WALL_SOUTH+8.0-z)))
	# A defile in the northern mountains leads to the cave's mouth.
	var defile = minf(7.5+1.5*noise.get_noise_1d(z*6.0+37000.0)-absf(x-CAVE.x),minf(z-CAVE.z,-40.0-z))
	var open = maxf(maxf(town,round_hill),maxf(desert,defile))
	# The river, and its far bank: north of the town it runs between rocks.
	if is_nan(side): side = river_side(x,z)
	if z < WALL_NORTH-2.0 and x < HILL.x-HILL_REACH.x-2.0:
		# West of the palace's ground, north of the town, the river's land
		# runs up to the mountains' foot, out of reach.
		open = maxf(open,z-north_front(x)-2.0)
	elif z < WALL_NORTH-4.0: open = maxf(open,RIVER_HALF+4.0-absf(side))
	elif side < RIVER_HALF+4.0: open = maxf(open,minf(RIVER_HALF+4.0-side,(east_edge(z)-x)*.87))
	return open

# Where the mountains' foot runs north of the town and the desert: a few
# metres back from the track's desert, and behind the palace hill.
func north_front(x: float) -> float:
	return lerpf(-168.0+6.0*noise.get_noise_1d(x*3.0+41000.0),-half_width(x)-3.0,smoothstep(-235.0,-145.0,x))

# How far into the mountains a point lies (negative short of their foot). Their
# foot keeps a little way back from the open ground's edge; they stand back
# from the temple, the cave's defile and the river's course through them.
func mountain_depth(x: float, z: float) -> float:
	# North of the track; at the town's end they turn away north.
	var north = north_front(x)-z
	var east = (x-east_edge(z))*.87-3.0
	var k = 14.0
	var h = clampf(.5+.5*(east-north)/k,0.0,1.0)
	var depth = lerpf(north,east,h)+k*h*(1.0-h)
	# The temple stands in a cove of them.
	var temple = Vector2(maxf(maxf(TEMPLE_DOOR.x-x,x-TEMPLE_DOOR.x-66.0),0.0),maxf(absf(z)-36.0,0.0)).length()
	depth = minf(depth,temple-9.0)
	# The defile's west wall (on the camera's side) climbs gently.
	if z > CAVE.z-6.0:
		var across = x-CAVE.x
		depth = minf(depth,(across-10.0)*1.1 if across > 0.0 else (-across-10.0)*.35)
	# The river's gorge.
	depth = minf(depth,(absf(river_side(x,z))-RIVER_HALF-3.0)*1.3)
	return depth

func margin_at(p: Vector3) -> float:
	var c = to_cell(p)
	return margins[index(c.x,c.y)] if on_map(c.x,c.y) else -RIM

# The worn track from the town gate to the temple door wanders across the
# desert, and runs straight into each.
func track_z(x: float) -> float:
	var free = smoothstep(TOWN_GATE.x+4.0,TOWN_GATE.x+70.0,x)*(1.0-smoothstep(TEMPLE_DOOR.x-80.0,TEMPLE_DOOR.x-22.0,x))
	return free*(11.0*sin(x*.021)+5.0*sin(x*.047+1.1))

# The open ground's outline, the river's course, the track across the
# desert, and the shade under the rim.
func shape_ground() -> void:
	for z in range(NORTH,SOUTH):
		for x in range(WEST,EAST):
			var side = river_side(x,z)
			var m = margin(x,z,side)
			var i = index(x,z)
			margins[i] = m
			river_sides[i] = side
			if m<1.0: cells[i] = SOLID
			# The river, and all across it, is out of reach; north of the
			# town, west of the palace's ground, its land is too.
			elif side < RIVER_HALF-.4 or (z < WALL_NORTH-1.0 and x < HILL.x-HILL_REACH.x-1.0): cells[i] = LOW
			paint[i*4+SHADE] = int(clampf(1.0-m/4.0,0.0,1.0)*150.0) if m>0 else 150
	for x in range(int(TOWN_GATE.x)-2,int(TEMPLE_DOOR.x)+1):
		var middle = track_z(x)
		for z in range(floori(middle)-5,ceili(middle)+6):
			var across = absf(z-middle)
			dab(TRACK,x,z,clampf(1.25-across/2.6,0.0,1.0))

# Raises a channel of the ground's control map at one cell.
func dab(channel: int, x: int, z: int, amount: float) -> void:
	if not on_map(x,z): return
	var i = index(x,z)*4+channel
	paint[i] = maxi(paint[i],int(clampf(amount,0.0,1.0)*255.0))

func dab_rect(channel: int, area: Rect2, amount: float = 1.0) -> void:
	for z in range(floori(area.position.y+.5),floori(area.end.y+.5)):
		for x in range(floori(area.position.x+.5),floori(area.end.x+.5)): dab(channel,x,z,amount)

# A soft-edged disc on a channel, full to `radius` and fading over `soft`.
func dab_disc(channel: int, at: Vector3, radius: float, soft: float = 1.5, amount: float = 1.0) -> void:
	var reach = ceili(radius+soft)
	var c = to_cell(at)
	for z in range(c.y-reach,c.y+reach+1):
		for x in range(c.x-reach,c.x+reach+1):
			var d = Vector2(x-at.x,z-at.z).length()
			dab(channel,x,z,amount*clampf(1.0-(d-radius)/maxf(soft,.01),0.0,1.0))

# One continuous mesh, flat under the map and rolling into distant hills,
# drawn by the desert ground shader from the control map.
func lay_ground() -> void:
	var image = Image.create_from_data(WIDTH,DEPTH,false,Image.FORMAT_RGBA8,paint)
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/desert_ground.gdshader")
	ground_material = material
	if not ground_hole.is_empty(): open_ground(ground_hole.at,ground_hole.half,ground_hole.yaw)
	material.set_shader_parameter("control",ImageTexture.create_from_image(image))
	material.set_shader_parameter("map_origin",Vector2(WEST,NORTH))
	material.set_shader_parameter("map_size",Vector2(WIDTH,DEPTH))
	if not flow.is_empty(): material.set_shader_parameter("flow_map",ImageTexture.create_from_image(Image.create_from_data(WIDTH,DEPTH,false,Image.FORMAT_RG8,flow)))
	material.set_shader_parameter("stone",load("res://assets/textures/limestone.png"))
	for sheet in ["sand_fine","sand_fine_normal","sand_gravel","sand_gravel_normal"]:
		material.set_shader_parameter(sheet,load("res://assets/textures/%s.jpg" % sheet))
	var grain = FastNoiseLite.new()
	grain.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	grain.frequency = .125
	grain.fractal_type = FastNoiseLite.FRACTAL_NONE
	grain.seed = 11
	var image_noise = grain.get_seamless_image(512,512)
	image_noise.generate_mipmaps()
	material.set_shader_parameter("noise_map",ImageTexture.create_from_image(image_noise))
	ground = Horizon.build(self,material)
	# The palace hill lies over the flat ground, a finger's width proud of
	# it where the two are level.
	var sloping: ShaderMaterial = material.duplicate()
	sloping.set_shader_parameter("sloped",1.0)
	hill = Art.model("hill",Vector3.ONE,sloping)
	hill.name = "PalaceHill"
	hill.position = HILL+Vector3.UP*.02
	for mesh in hill.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = GROUND_LAYER
	add_child(hill)
	add_child(dune_ground(sloping))

# An opening in the ground at `at`, `half` its half size (across, along),
# turned `yaw`: the ground is not drawn there (the basement's stair).
# (Opened before the ground is laid, it is kept until it is.)
var ground_hole = {}
func open_ground(at: Vector3, half: Vector2, yaw: float) -> void:
	ground_hole = {"at":at,"half":half,"yaw":yaw}
	if ground_material == null: return
	ground_material.set_shader_parameter("hole_center",Vector2(at.x,at.z))
	ground_material.set_shader_parameter("hole_half",half)
	ground_material.set_shader_parameter("hole_yaw",yaw)

# The dune's ground, lying over the slab as the hill's does: a sheet of
# two-metre squares raised to `dune_height`.
func dune_ground(material: Material) -> MeshInstance3D:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step = 2.0
	var across = ceili(DUNE_RADII.x/step)+1
	var down = ceili(DUNE_RADII.y/step)+1
	for j in range(-down,down+1):
		for i in range(-across,across+1):
			var x = DUNE.x+i*step
			var z = DUNE.z+j*step
			tool.set_normal(Vector3(dune_height(x-.5,z)-dune_height(x+.5,z),1.0,dune_height(x,z-.5)-dune_height(x,z+.5)).normalized())
			tool.set_uv(Vector2(x,z))
			tool.add_vertex(Vector3(x,dune_height(x,z)+.02,z))
	var wide = across*2+1
	for j in down*2:
		for i in across*2:
			var a = j*wide+i
			for corner in [a,a+1,a+wide+1,a,a+wide+1,a+wide]: tool.add_index(corner)
	var sheet = MeshInstance3D.new()
	sheet.name = "Dune"
	sheet.mesh = tool.commit()
	sheet.material_override = material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.layers = GROUND_LAYER
	return sheet

# ---- Building ----

# A kit model scaled to `size`, as Temple.place does; `yaw` in radians. It
# stands `at.y` above the ground there.
func place(id: String, at: Vector3, size: Vector3, material: Material = null, yaw: float = 0.0) -> Node3D:
	var node = Art.model(id,size,material)
	if material == null: Kit.dress(node)
	add_child(node)
	node.position = at+Vector3.UP*lift(at)
	node.rotation.y = yaw
	return node

# A kit model at its own proportions, `height` tall.
func prop(id: String, at: Vector3, height: float, yaw: float = 0.0) -> Node3D:
	return place(id,at,Kit.sized(id,height),null,yaw)

# One more copy of a single-mesh model, drawn in its patch's batch.
func batch(id: String, at: Transform3D, material: Material, shadows: bool = true) -> void:
	var key = "%s:%d:%d:%d:%s" % [id,material.get_instance_id(),floori(at.origin.x/BATCH_SPAN),floori(at.origin.z/BATCH_SPAN),shadows]
	if not batches.has(key): batches[key] = {"id":id,"material":material,"shadows":shadows,"transforms":[]}
	at.origin.y += lift(at.origin)
	batches[key].transforms.append(at)

func flush_batches() -> void:
	for group in batches.values():
		var copies = MultiMesh.new()
		copies.transform_format = MultiMesh.TRANSFORM_3D
		copies.mesh = Kit.mesh_of(group.id)
		copies.instance_count = group.transforms.size()
		for i in group.transforms.size(): copies.set_instance_transform(i,group.transforms[i])
		var node = MultiMeshInstance3D.new()
		node.multimesh = copies
		node.material_override = group.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	batches.clear()

# Where a unit model stands when scaled to `size`, turned by `yaw` and leaned
# by `tilt` about a level axis.
func stance(at: Vector3, size: Vector3, yaw: float, tilt: float = 0.0) -> Transform3D:
	var basis = Basis(Vector3.UP,yaw)*Basis.from_scale(size)
	if tilt != 0.0: basis = Basis(Vector3(cos(yaw*3.0),0,sin(yaw*3.0)),tilt)*basis
	return Transform3D(basis,at)

# A bronze fire bowl `width` across, burning with the temple torches' flame,
# on the ground or on a pedestal `pedestal` metres tall.
func brazier(at: Vector3, width: float, pedestal: float = 0.0) -> Node3D:
	if pedestal>0.0: place("pillar",at,Vector3(width*.8,pedestal,width*.8),Kit.masonry(Color(.90,.84,.72)))
	var bowl = place("fire_bowl",at+Vector3.UP*pedestal,Vector3(width,width*.84,width*.96),Art.bronze())
	for mesh in bowl.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if at.y<.5: block_disc(Vector3(at.x,0,at.z),maxf(.5,width*.5),LOW)
	fire(bowl.position+Vector3.UP*width*.7,width*1.9,width*8.0,1.6,fposmod(at.x*12.9898+at.z*78.233,100.0))
	return bowl

# A statue: one of the temple's figures (`kind`, as in Data.ENEMIES, with its
# `weapon`) standing still, `stature` times life size, facing `yaw`. It is
# the same carving at any size (the stone's grain grows with it), in the
# temple's dark stone or, `marble`, in white. `pose` is a clip of the figure's
# to hold in place of its stance (the lion's "Sit").
func statue(kind: String, weapon: String, at: Vector3, yaw: float, stature: float, marble: bool = false, pose: String = "") -> Node3D:
	# (A figure turns to face the way its parent does.)
	var stand = Node3D.new()
	stand.set_meta("statue",kind)
	stand.set_meta("marble",marble)
	add_child(stand)
	stand.position = at+Vector3.UP*lift(at)
	stand.rotation.y = yaw
	var figure = preload("res://scripts/visual.gd").new()
	stand.add_child(figure)
	figure.setup(true,Color.WHITE,weapon,stature,kind)
	if kind=="boss": figure.crown()
	figure.play(pose if figure.clips.has(pose) else figure.idle_action())
	# (Straight into the pose: a statue does not ease into it from another.)
	figure.animator.play(figure.clips[figure.state],0)
	figure.animator.seek(0,true)
	figure.advance(.4)
	figure.animator.pause()
	figure.set_process(false)
	stand.set_meta("pose",figure.state)
	for mesh in figure.find_children("*","MeshInstance3D",true,false):
		var stone: Material = mesh.material_override
		if not stone is ShaderMaterial: continue
		var key = "statue%d:%s:%f" % [stone.get_instance_id(),marble,stature]
		if not Kit.cache.has(key):
			var carved: ShaderMaterial = stone.duplicate()
			carved.set_shader_parameter("figure_scale",stature)
			carved.set_shader_parameter("pale",1.0 if marble else 0.0)
			Kit.cache[key] = carved
		mesh.material_override = Kit.cache[key]
	return stand

func block_cell(x: int, z: int, kind: int = SOLID) -> void:
	if not on_map(x,z): return
	var i = index(x,z)
	if kind==SOLID or cells[i]==OPEN: cells[i] = kind

# Closes the cells whose centres lie in `area` (metres, on the ground plane).
func block_rect(area: Rect2, kind: int = SOLID, shade: bool = true) -> void:
	for z in range(ceili(area.position.y),floori(area.end.y)+1):
		for x in range(ceili(area.position.x),floori(area.end.x)+1): block_cell(x,z,kind)
	if not shade: return
	for z in range(floori(area.position.y)-1,ceili(area.end.y)+2):
		for x in range(floori(area.position.x)-1,ceili(area.end.x)+2):
			var outside = Vector2(maxf(maxf(area.position.x-x,x-area.end.x),0.0),maxf(maxf(area.position.y-z,z-area.end.y),0.0)).length()
			dab(SHADE,x,z,.8*clampf(1.0-outside/1.6,0.0,1.0))

# The town's and the palace's walls and towers, as blocked: the rim's rocks
# keep clear of them (scripts/world_desert.gd rim).
var walls: Array[Rect2] = []
func wall(area: Rect2) -> void:
	block_rect(area)
	walls.append(area)

# How far a point is from the nearest wall (INF with none within `reach`).
func wall_distance(at: Vector3, reach: float) -> float:
	var nearest = INF
	var p = Vector2(at.x,at.z)
	for area in walls:
		if not area.grow(reach).has_point(p): continue
		var outside = Vector2(maxf(maxf(area.position.x-p.x,p.x-area.end.x),0.0),maxf(maxf(area.position.y-p.y,p.y-area.end.y),0.0))
		nearest = minf(nearest,outside.length())
	return nearest

func block_disc(at: Vector3, radius: float, kind: int = SOLID, shade: bool = true) -> void:
	var reach = ceili(radius)
	var c = to_cell(at)
	for z in range(c.y-reach,c.y+reach+1):
		for x in range(c.x-reach,c.x+reach+1):
			if Vector2(x-at.x,z-at.z).length()<=radius: block_cell(x,z,kind)
	if shade: dab_disc(SHADE,at,radius*.8,1.4,.75)

func open_rect(area: Rect2) -> void:
	for z in range(ceili(area.position.y),floori(area.end.y)+1):
		for x in range(ceili(area.position.x),floori(area.end.x)+1):
			if on_map(x,z): cells[index(x,z)] = OPEN

func add_place(title: String, kind: String, at: Vector3, radius: float) -> void:
	places.append({"name":title,"kind":kind,"at":at,"radius":radius})

# Registers nodes that can stand between the camera and the hero: while they
# do, they are drawn see-through.
func screen(nodes: Array) -> void:
	var parts: Array = []
	var box = AABB()
	for node in nodes:
		for mesh in node.find_children("*","MeshInstance3D",true,false)+([node] if node is MeshInstance3D else []):
			var normal: Array = []
			var faded: Array = []
			var whole: Material = mesh.material_override
			if whole != null:
				normal.append(whole)
				faded.append(Kit.faded(whole))
			else:
				for s in mesh.mesh.get_surface_count():
					var m: Material = mesh.get_active_material(s)
					normal.append(mesh.get_surface_override_material(s))
					faded.append(Kit.faded(m))
			var bounds_here: AABB = mesh.global_transform*mesh.get_aabb()
			box = bounds_here if parts.is_empty() else box.merge(bounds_here)
			parts.append({"mesh":mesh,"whole":whole != null,"normal":normal,"faded":faded,"box":bounds_here})
	if parts.is_empty(): return
	screens.append({"box":box,"parts":parts,"hidden":false})

# Registers a room's walls as screens (see-through when they stand before
# the hero outside); while he is in the room its "front" walls (the camera's
# side) are lifted away and its "back" walls never fade.
func screen_in_room(nodes: Array, room: Dictionary, side: String) -> void:
	var before = screens.size()
	screen(nodes)
	if screens.size() > before: screens[-1]["room"] = room
	if side == "front": room.front.append_array(nodes)

# ---- The interface Game drives ----

func fits(p: Vector3, radius: float = .4) -> bool:
	var lo = to_cell(p-Vector3(radius,0,radius))
	var hi = to_cell(p+Vector3(radius,0,radius))
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			if not on_map(x,z) or cells[index(x,z)] != OPEN: return false
	return true

func fits_for_visibility(p: Vector3, radius: float) -> bool:
	var lo = to_cell(p-Vector3(radius,0,radius))
	var hi = to_cell(p+Vector3(radius,0,radius))
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			if not on_map(x,z) or cells[index(x,z)] == SOLID: return false
	return true

func move(from: Vector3, step: Vector3, radius: float = .4) -> Vector3:
	var p = from
	var count = maxi(1,ceili(step.length()/.22))
	var s = step/count
	for i in count:
		if fits(p+s,radius): p += s
		else:
			if fits(p+Vector3(s.x,0,0),radius): p.x += s.x
			if fits(p+Vector3(0,0,s.z),radius): p.z += s.z
	return p

func clear_line(a: Vector3, b: Vector3) -> bool:
	var steps = maxi(1,ceili(a.distance_to(b)/.2))
	for i in range(steps+1):
		if not fits_for_visibility(a.lerp(b,float(i)/steps),.04): return false
	return true

# A way walked keeps a hair (.41) further from walls than he must (.4). Where
# he sets out from need only fit him: hard against a wall, he is as near as
# he may be, and a way out from there is a way.
func walk_line(a: Vector3, b: Vector3) -> bool:
	var steps = maxi(1,ceili(a.distance_to(b)/.2))
	for i in range(1 if fits(a,.4) else 0,steps+1):
		if not fits(a.lerp(b,float(i)/steps),.41): return false
	return true

func navigation_cell(at: Vector3, require_connection: bool) -> Vector2i:
	var center = Vector2i(clampi(roundi(at.x),WEST,EAST-1),clampi(roundi(at.z),NORTH,SOUTH-1))
	var best = Vector2i(-10000,-10000)
	var distance = INF
	for radius in range(7):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var cell = center+Vector2i(x,z)
				if not nav.is_in_boundsv(cell) or nav.is_point_solid(cell): continue
				var point = Vector3(cell.x,0,cell.y)
				if require_connection and not walk_line(at,point): continue
				var d = at.distance_squared_to(point)
				if d<distance:
					best = cell
					distance = d
		if best.x != -10000: break
	return best

# As on a temple floor: straight there when nothing is in the way, otherwise
# along the grid, cutting every corner that can be walked.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var destination = Vector3(clampf(to.x,WEST+.41,EAST-1.41),0,clampf(to.z,NORTH+.41,SOUTH-1.41))
	if walk_line(from,destination): return PackedVector3Array([destination])
	var start = navigation_cell(from,true)
	var end = navigation_cell(destination,false)
	var result = PackedVector3Array()
	if start.x == -10000 or end.x == -10000: return result
	var points = PackedVector3Array()
	for p in nav.get_point_path(start,end): points.append(Vector3(p.x,0,p.y))
	if points.is_empty(): return result
	if walk_line(points[-1],destination): points.append(destination)
	var anchor = from
	while not points.is_empty():
		var next = 0
		for i in range(points.size()-1,-1,-1):
			if walk_line(anchor,points[i]):
				next = i
				break
		anchor = points[next]
		result.append(anchor)
		for i in range(next+1): points.remove_at(0)
	return result

func pointer() -> Vector3:
	return ground_at(get_viewport().get_mouse_position())

# The point of the plane under a point of the screen: where the view's ray
# meets the ground, hill and all.
func ground_at(viewport_position: Vector2) -> Vector3:
	var origin = camera.project_ray_origin(viewport_position)
	var ray = camera.project_ray_normal(viewport_position)
	var hit = Plane(Vector3.UP,0).intersects_ray(origin,ray)
	if hit == null: return spawn
	for i in 4:
		var raised = Plane(Vector3.UP,lift(hit)).intersects_ray(origin,ray)
		if raised == null: break
		hit = raised
	return Vector3(hit.x,0,hit.z)

# Nothing outdoors is hidden by line of sight. (The game calls this every
# frame it is running: the townspeople go about their day.)
func update_visibility(pos: Vector3, delta: float) -> void:
	townsfolk.tick(delta,pos)
	watch.tick(delta,pos)

func can_see(_at: Vector3) -> bool:
	return true

func follow(pos: Vector3, delta: float) -> void:
	# Whatever the game has added on the hill is raised to its ground.
	for i in range(fixtures,get_child_count()):
		var node = get_child(i)
		if not node is Node3D or node.has_meta("grounded") or node.has_method("begin_strike"): continue
		node.set_meta("grounded",true)
		node.position.y += lift(node.position)
	pos += Vector3.UP*lift(pos)
	# Further back than it needs to be: a tall rock or wall near the bottom of
	# the view never crosses the camera's plane.
	camera.position = camera.position.lerp(pos+VIEW*BACK,minf(1,delta*8))
	camera.look_at(camera.position-VIEW)
	camera.size = lerpf(camera.size,zoom,minf(1,delta*8))
	# A building the hero is in stands open to the view.
	# Under the arena's stands he is indoors: the seats overhead and the
	# outer wall before him are lifted away.
	var under: bool = Town.under_stands(pos)
	if under != under_stands:
		under_stands = under
		for node in stand_seats: node.visible = not under
		for node in stand_fittings: node.visible = under
		for node in stand_front:
			for mesh in node.find_children("*","GeometryInstance3D",true,false)+([node] if node is GeometryInstance3D else []):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if under else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for room in rooms:
		var inside: bool = room.area.has_point(Vector2(pos.x,pos.z))
		if inside == room.inside: continue
		room.inside = inside
		room.roof.visible = not inside
		for node in room.front: node.visible = not inside
	screen_tick -= delta
	if screen_tick>0: return
	screen_tick = .1
	var targets: Array = [{"position":pos,"height":1.8}]+occlusion_targets
	for group in screens:
		var hides = false
		# Only what stands on the camera's side of someone, and near, can hide them.
		if group.has("room") and group.room.inside: hides = false
		else:
			for target in targets:
				var feet: Vector3 = target.position
				feet.y = lift(feet)
				var box: AABB = group.box
				if feet.x<box.position.x-1.0 or feet.z>box.end.z+1.0: continue
				if feet.x-box.end.x>box.size.y*1.2+3.0 or box.position.z-feet.z>box.size.y*1.2+3.0: continue
				for part in group.parts:
					for share in [.1,.55,1.0]:
						if part.box.intersects_segment(camera.position,feet+Vector3.UP*target.height*share): hides = true; break
					if hides: break
				if hides: break
		if hides == group.hidden: continue
		group.hidden = hides
		for part in group.parts:
			if part.whole: part.mesh.material_override = part.faded[0] if hides and part.faded[0] != null else part.normal[0]
			else:
				for s in part.normal.size(): part.mesh.set_surface_override_material(s,part.faded[s] if hides and part.faded[s] != null else part.normal[s])

# ---- Places ----

# The part of the world a point is in: "town", "desert" or "temple".
func region(at: Vector3) -> String:
	if at.z>SOUTH_GAP.z+8.0: return "desert"
	if at.x<TOWN_GATE.x: return "town"
	return "temple" if at.x>TEMPLE_DOOR.x-46.0 else "desert"

# The named place the hero is standing at (the smallest, where one lies
# inside another), or an empty dictionary.
func place_at(at: Vector3) -> Dictionary:
	var found = {}
	for spot in places:
		if spot.at.distance_to(at)<=spot.radius and (found.is_empty() or spot.radius<found.radius): found = spot
	return found

# Walking through the temple's door enters it.
func entering_temple(at: Vector3) -> bool:
	return at.x>=TEMPLE_DOOR.x+1.0 and absf(at.z-TEMPLE_DOOR.z)<4.0

# The place the hero walks into at `at`: "temple" through its door, "cave" at
# the cave's mouth, "basement" down the stair under the arena's stands; or
# nowhere ("").
func entrance(at: Vector3) -> String:
	if entering_temple(at): return "temple"
	if absf(at.x-CAVE.x)<3.2 and at.z<CAVE.z+3.4: return "cave"
	if at.distance_to(BASEMENT_STAIR)<1.5: return "basement"
	return ""
