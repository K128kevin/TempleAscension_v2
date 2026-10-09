extends Node3D
## The rats of the arena basement: small brown-grey rats that keep to the
## foot of the walls, darting along them in short bursts and stopping to
## sniff, and scattering from the hero when he comes near. Only to be seen:
## not enemies, not struck, not in the way. One node keeps all of a floor's
## rats and moves them all in one pass; each is drawn by a one-instance
## MultiMesh of the one shared mesh and material (the shader,
## assets/shaders/rat_fur.gdshader, moves its legs, head and tail by the
## instance's data), small and where the rat is, so the torches about it are
## the ones that light it. A rat far from the hero is left where it is,
## unseen in the dark, until he comes nearer.
##
##   var rats = Rats.new(); game.world.add_child(rats); rats.setup(game,count,seed)

# How fast a rat darts (metres a second, least and most), and runs from him.
const DART = Vector2(2.5,3.5)
const FLEE_SPEED = 3.8
# How long it stops between darts (seconds), and how far a dart takes it.
const PAUSE = Vector2(.5,2.8)
const DASH = Vector2(1.2,4.5)
# He is too near within SCARE metres; it runs FLEE metres or so from him.
const SCARE = 3.0
const FLEE = Vector2(4.0,7.0)
# How far from a wall it keeps (its radius against the floor's cells), and
# how close to a wall a place counts as along it.
const RADIUS = .1
# How much larger than life they are drawn, to read at the game's distance.
const SIZE = 1.3
# Rats further than this from the hero are not moved.
const AWAKE_REACH = 25.0
# How fast it turns (radians a second), its legs' strides at a run (per
# metre), its sniffing and its tail's swing (radians a second).
const TURN = 16.0
const STRIDE = 26.0
const SNIFF = 9.0
const SWING = 7.0
# Places along the walls are kept in squares this many metres across, to
# find those near a rat without looking at them all.
const BUCKET = 6.0

var game
var world
var rng = RandomNumberGenerator.new()
# Each rat: its place, heading, what it is doing ("pause", "dart", "flee"),
# where it is going, how fast, how long it has left, its animation's phases
# and running blend, and what draws it.
var rats: Array[Dictionary] = []
# Floor along the walls: points beside a wall, and those in each bucket.
var edges: Array[Vector3] = []
var buckets: Dictionary = {}

func setup(game_node, count: int, seed: int) -> void:
	game = game_node
	world = game.world
	rng.seed = seed
	find_edges()
	rats.clear()
	for i in count:
		var at: Vector3 = edges[rng.randi_range(0,edges.size()-1)] if not edges.is_empty() else world.spawn
		var drawn = MultiMeshInstance3D.new()
		drawn.multimesh = MultiMesh.new()
		drawn.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		drawn.multimesh.use_custom_data = true
		drawn.multimesh.mesh = rat_mesh()
		drawn.multimesh.instance_count = 1
		# (Its bounds: about the rat, its tail swinging; never worked out anew.)
		drawn.multimesh.custom_aabb = AABB(Vector3(-.4,-.05,-.45),Vector3(.8,.3,.8))
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drawn.material_override = material()
		add_child(drawn)
		rats.append({"at":at,"heading":rng.randf_range(0,TAU),"doing":"pause","goal":at,"speed":0.0,
			"left":rng.randf_range(PAUSE.x,PAUSE.y),"gait":rng.randf_range(0,TAU),"run":0.0,
			"sniff":rng.randf_range(0,TAU),"swing":rng.randf_range(0,TAU),"seen":false,"drawn":drawn})
		place(i)

# Every floor point beside a wall (a cell with a wall on some side, pressed
# toward that wall as far as a rat can go), where the rats run.
func find_edges() -> void:
	edges.clear()
	buckets.clear()
	var layout = world.layout
	for cell in layout.cells:
		var at: Vector3 = layout.to_world(cell)
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if layout.cells.has(cell+d): continue
			var snug: Vector3 = at+Vector3(d.x,0,d.y)*(.5-RADIUS-.04)
			if world.fits(snug,RADIUS):
				edges.append(snug)
				var key = Vector2i(floori(snug.x/BUCKET),floori(snug.z/BUCKET))
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(snug)
	if edges.is_empty():
		for cell in layout.cells: edges.append(layout.to_world(cell))

func _process(dt: float) -> void:
	if game == null or not is_instance_valid(world): return
	tick(dt)

func tick(dt: float) -> void:
	if game.mode != "playing": return
	var hero: Vector3 = game.player.position if is_instance_valid(game.player) else Vector3.INF
	for i in rats.size():
		var r: Dictionary = rats[i]
		var near: bool = r.at.distance_squared_to(hero) < AWAKE_REACH*AWAKE_REACH
		if near: think(r,dt,hero)
		var seen: bool = near and world.can_see(r.at)
		if seen or r.seen != seen:
			r.seen = seen
			place(i)

# What a rat does this frame: scatters if he is too near, else darts along
# the wall to the next place or waits there sniffing.
func think(r: Dictionary, dt: float, hero: Vector3) -> void:
	r.left -= dt
	r.sniff += dt*SNIFF
	if r.doing != "flee" and r.at.distance_to(hero) < SCARE: flee(r,hero)
	if r.doing == "pause":
		if r.left <= 0: dart(r)
	else:
		var to: Vector3 = r.goal-r.at
		var gap: float = to.length()
		if gap < .08 or r.left <= 0:
			settle(r)
		else:
			var step: Vector3 = to/gap*minf(gap,r.speed*dt)
			var before: Vector3 = r.at
			r.at = world.move(r.at,step,RADIUS)
			var moved: float = before.distance_to(r.at)
			# (Run into a corner, it gives up and stops there.)
			if moved < step.length()*.2: settle(r)
			r.gait += moved*STRIDE
			if moved > .0001: r.heading = rotate_toward(r.heading,atan2(step.x,step.z),TURN*dt)
	var running: float = 1.0 if r.doing != "pause" else 0.0
	r.run = move_toward(r.run,running,dt*8.0)
	r.swing += dt*SWING*(1.0+r.run)

func settle(r: Dictionary) -> void:
	r.doing = "pause"
	r.speed = 0.0
	r.left = rng.randf_range(PAUSE.x,PAUSE.y)

# Off to another place along the walls near it, one it can run to straight.
func dart(r: Dictionary) -> void:
	var goal = pick(r.at,DASH,Vector3.INF,0.0)
	if goal == null:
		settle(r)
		return
	r.goal = goal
	r.doing = "dart"
	r.speed = rng.randf_range(DART.x,DART.y)
	r.left = r.at.distance_to(goal)/r.speed+.5

# Away from the hero, as fast as it can, to a place along the walls further
# from him; or, with none to be had, straight away from him.
func flee(r: Dictionary, hero: Vector3) -> void:
	var goal = pick(r.at,FLEE,hero,r.at.distance_to(hero)+1.5)
	if goal == null:
		var away: Vector3 = r.at-hero
		away.y = 0
		if away.length_squared() < .0001: away = Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))
		goal = r.at+away.normalized()*FLEE.x
	r.goal = goal
	r.doing = "flee"
	r.speed = FLEE_SPEED
	r.left = 2.5

# A place along the walls `span` metres from `from` (least and most) that a
# rat can run to in a straight line, and, given `hero`, at least `beyond`
# metres from him; null if a few tries find none.
func pick(from: Vector3, span: Vector2, hero: Vector3, beyond: float):
	var key = Vector2i(floori(from.x/BUCKET),floori(from.z/BUCKET))
	var reach: int = ceili(span.y/BUCKET)
	for attempt in 10:
		var near = Vector2i(key.x+rng.randi_range(-reach,reach),key.y+rng.randi_range(-reach,reach))
		var pool: Array = buckets.get(near,[])
		if pool.is_empty(): continue
		var spot: Vector3 = pool[rng.randi_range(0,pool.size()-1)]
		var gap: float = spot.distance_to(from)
		if gap < span.x or gap > span.y: continue
		if hero != Vector3.INF and spot.distance_to(hero) < beyond: continue
		if runnable(from,spot): return spot
	return null

# Whether a rat can run straight from `a` to `b` without meeting a wall.
func runnable(a: Vector3, b: Vector3) -> bool:
	var steps: int = maxi(1,ceili(a.distance_to(b)/.2))
	for k in range(1,steps+1):
		if not world.fits(a.lerp(b,float(k)/steps),RADIUS): return false
	return true

# Where it is drawn and which way it faces, its stride, sniffing and tail;
# or nothing, where the hero cannot see it.
func place(i: int) -> void:
	var r: Dictionary = rats[i]
	var drawn: MultiMeshInstance3D = r.drawn
	drawn.visible = r.seen
	if not r.seen: return
	drawn.position = r.at
	drawn.multimesh.set_instance_transform(0,Transform3D(Basis(Vector3.UP,r.heading).scaled(Vector3.ONE*SIZE),Vector3.ZERO))
	drawn.multimesh.set_instance_custom_data(0,Color(fposmod(r.gait,TAU),r.run,fposmod(r.sniff,TAU*10.0),fposmod(r.swing,TAU)))

func material() -> ShaderMaterial:
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		shared_material.shader = load("res://assets/shaders/rat_fur.gdshader")
	return shared_material

static var shared_material: ShaderMaterial
static var shared_mesh: ArrayMesh

func positions() -> Array:
	return rats.map(func(r): return r.at)

# --- The rat itself ---------------------------------------------------------------

# Facing +Z, standing on the floor at the origin: a long, low body, humped at
# the haunches, narrowing through the shoulders to a pointed snout; round
# ears; four short legs; a long, thin, naked tail trailing behind and down to
# the floor. About 0.24 m nose to rump, and the tail as long again.
const PROFILE = [
	# [z, half width, half height, height of its middle]
	[-.105,.004,.004,.036],[-.098,.022,.019,.038],[-.085,.034,.03,.041],[-.065,.042,.037,.043],
	[-.04,.045,.039,.043],[-.015,.042,.036,.041],[.012,.035,.031,.039],[.035,.027,.025,.038],
	[.05,.025,.024,.039],[.068,.027,.025,.04],[.085,.023,.021,.037],[.1,.016,.014,.032],
	[.114,.009,.008,.027],[.124,.0035,.0035,.024],[.128,.0,.0,.023]]
const AROUND = 12
static func rat_mesh() -> ArrayMesh:
	if shared_mesh != null: return shared_mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The body and head, turned about its length.
	var rings: Array = []
	for p in PROFILE:
		var ring: Array = []
		for j in AROUND:
			var a: float = TAU*j/AROUND
			var y: float = p[3]+sin(a)*p[2]
			ring.append(Vector3(cos(a)*p[1],maxf(y,.014),p[0]))
		rings.append(ring)
	for i in rings.size()-1:
		for j in AROUND:
			var k = (j+1)%AROUND
			quad(st,rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][k],Vector2.ZERO,Color(0,0,0))
	# The ears: two rounded flaps, standing up and back from the crown.
	for side in [-1.0,1.0]:
		var root = Vector3(side*.016,.057,.06)
		var fan: Array = []
		for j in 7:
			var a: float = PI*j/6.0
			fan.append(root+Vector3(side*cos(a)*.008+side*.004,sin(a)*.013,-sin(a)*.005))
		# (Both sides, the back a hair behind the front so each keeps its own
		# normal.)
		var behind = Vector3(0,0,-.0006)
		for j in 6:
			tri(st,root,fan[j],fan[j+1],Vector2.ZERO,Color(1,0,0))
			tri(st,root+behind,fan[j+1]+behind,fan[j]+behind,Vector2.ZERO,Color(1,0,0))
	# The eyes: black beads (COLOR.g), glossy.
	for side in [-1.0,1.0]: bead(st,Vector3(side*.017,.045,.09),.0042,Color(0,1,0))
	# The legs: short tapering stubs, with pale feet.
	var legs = [[.03,.022,.25],[.03,-.022,.5],[-.055,.03,.75],[-.055,-.03,1.0]]
	for leg in legs:
		var top = Vector3(leg[1],.03,leg[0])
		var foot = Vector3(leg[1]*1.15,.002,leg[0]+.008)
		tube(st,[top,foot],[.008,.005],5,Vector2(0,leg[2]),Color(.35,0,0),false)
		tube(st,[foot,foot+Vector3(0,0,.014)],[.0045,.003],4,Vector2(0,leg[2]),Color(1,0,0),false)
	# The tail: thin and naked, down to the floor and trailing behind.
	var spine: Array = []
	var radii: Array = []
	for i in 11:
		var t: float = i/10.0
		spine.append(Vector3(0,lerpf(.033,.004,smoothstep(0.0,.45,t)),-.1-t*.22))
		radii.append(lerpf(.0068,.0014,t))
	tube(st,spine,radii,5,Vector2.ZERO,Color(1,0,0),true)
	# (Shared corners are made one, so the coat is shaded smooth.)
	st.index()
	st.generate_normals()
	shared_mesh = st.commit()
	return shared_mesh

static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv: Vector2, color: Color) -> void:
	for v in [a,b,c]:
		st.set_uv(uv)
		st.set_uv2(Vector2(color.r,color.g))
		st.add_vertex(v)

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Vector2, color: Color) -> void:
	tri(st,a,b,c,uv,color)
	tri(st,a,c,d,uv,color)

# A tube along `spine` (radius `radii` at each point); `along` gives UV.x
# from 0 to 1 down it (the tail's).
static func tube(st: SurfaceTool, spine: Array, radii: Array, sides: int, uv: Vector2, color: Color, along: bool) -> void:
	var rings: Array = []
	for i in spine.size():
		var forward: Vector3 = (spine[mini(i+1,spine.size()-1)]-spine[maxi(i-1,0)]).normalized()
		var side: Vector3 = forward.cross(Vector3.UP)
		if side.length() < .01: side = Vector3.RIGHT
		side = side.normalized()
		var up: Vector3 = side.cross(forward).normalized()
		var ring: Array = []
		for j in sides:
			var a: float = TAU*j/sides
			ring.append(spine[i]+(side*cos(a)+up*sin(a))*radii[i])
		rings.append(ring)
	for i in rings.size()-1:
		var u0: float = float(i)/(rings.size()-1) if along else 0.0
		var u1: float = float(i+1)/(rings.size()-1) if along else 0.0
		for j in sides:
			var k = (j+1)%sides
			quad_uv(st,[rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][k]],[u0,u1,u1,u0],uv.y,color)

static func quad_uv(st: SurfaceTool, corners: Array, u: Array, v: float, color: Color) -> void:
	for n in [0,1,2,0,2,3]:
		st.set_uv(Vector2(u[n],v))
		st.set_uv2(Vector2(color.r,color.g))
		st.add_vertex(corners[n])

static func bead(st: SurfaceTool, at: Vector3, radius: float, color: Color) -> void:
	var top = at+Vector3.UP*radius
	var bottom = at-Vector3.UP*radius
	var ring: Array = []
	for j in 6:
		var a: float = TAU*j/6.0
		ring.append(at+Vector3(cos(a),0,sin(a))*radius)
	for j in 6:
		var k = (j+1)%6
		tri(st,top,ring[k],ring[j],Vector2.ZERO,color)
		tri(st,bottom,ring[j],ring[k],Vector2.ZERO,color)
