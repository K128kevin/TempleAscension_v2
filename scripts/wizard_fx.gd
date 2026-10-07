extends RefCounted
## What the wizard's spells look like (scripts/skills.gd makes these and
## ticks or frees them): ice on the floor, bolts of ice in flight and their
## shattering, enemies frozen in ice, spikes rising from the floor, streams of
## frost, the frost that swirls about him; fire bursting out in a ring, a
## tornado of flame, the heat of Blazing Speed, a burn; lightning hurled,
## jolting from a rod, crackling round a shield. Particles, sprites, ribbons
## of light and the imported crystal mesh; nothing here does any damage.
const Vfx = preload("res://scripts/vfx.gd")
const Art = preload("res://scripts/assets.gd")
const RangerFx = preload("res://scripts/ranger_fx.gd")
const Crackle = preload("res://scripts/crackle.gd")
const StaticArcs = preload("res://scripts/static_arcs.gd")
const ShieldBubble = preload("res://scripts/shield_bubble.gd")
const Shockwave = preload("res://scripts/shockwave.gd")
const FROST = Color(.72,.9,1.0)
const FLAME = Color(1.0,.55,.18)
const SPARK = Color(.62,.82,1.0)

static var ice_material: StandardMaterial3D
static func ice() -> StandardMaterial3D:
	if ice_material == null:
		ice_material = StandardMaterial3D.new()
		ice_material.albedo_color = Color(.74,.9,1.0,.78)
		ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice_material.emission_enabled = true
		ice_material.emission = Color(.35,.62,.9)
		ice_material.emission_energy_multiplier = .6
		ice_material.roughness = .12
		ice_material.metallic_specular = .8
	return ice_material

static func ground_sprite(parent: Node3D, diameter: float, gradient: Gradient) -> Sprite3D:
	var texture = GradientTexture2D.new()
	texture.width = 128; texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5); texture.fill_to = Vector2(1,.5)
	texture.gradient = gradient
	var sprite = Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = diameter/128.0
	sprite.rotation.x = -PI/2
	sprite.position = Vector3.UP*.03
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	return sprite

# --- Ice -----------------------------------------------------------------------

# Frost on the floor: a sheet of ice `radius` wide frozen over it
# (assets/shaders/ice_sheet.gdshader), that spreads out as it is laid and
# breaks up as it melts over `seconds` (the game keeps its own record of where
# the ice lies). The shader draws the ice from where it lies in the world, so
# patches laid over one another make one even sheet.
class Patch extends Node3D:
	var age = 0.0
	var life = 10.0
	var sheet: MeshInstance3D
	func tick(dt: float) -> bool:
		age += dt
		var ice: ShaderMaterial = sheet.material_override
		ice.set_shader_parameter("grow",minf(1.0,age/.2))
		ice.set_shader_parameter("melt",clampf(1.0-(life-age)/1.5,0.0,1.0))
		return age >= life
static var ice_sheet_shader: Shader
# `ground(x, z)` is the floor's height there: a wide sheet is laid over the
# lie of the land rather than flat.
static func patch(at: Vector3, radius: float, seconds: float, ground: Callable = Callable()) -> Node3D:
	var node = Patch.new()
	node.position = at
	node.life = seconds
	if ice_sheet_shader == null: ice_sheet_shader = preload("res://assets/shaders/ice_sheet.gdshader")
	# (A little over its width: its ragged rim reaches past it.)
	var side: float = radius*2.3
	var cells: int = clampi(ceili(side/.6),1,24)
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in cells+1:
		for i in cells+1:
			var uv = Vector2(float(i)/cells,float(j)/cells)
			var x: float = (uv.x-.5)*side
			var z: float = (uv.y-.5)*side
			var y: float = float(ground.call(at.x+x,at.z+z))-at.y if ground.is_valid() else 0.0
			tool.set_normal(Vector3.UP)
			tool.set_uv(uv)
			tool.add_vertex(Vector3(x,y,z))
	for j in cells:
		for i in cells:
			var a = j*(cells+1)+i
			tool.add_index(a); tool.add_index(a+1); tool.add_index(a+cells+1)
			tool.add_index(a+1); tool.add_index(a+cells+2); tool.add_index(a+cells+1)
	node.sheet = MeshInstance3D.new()
	node.sheet.mesh = tool.commit()
	node.sheet.position = Vector3.UP*.035
	node.sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ice = ShaderMaterial.new()
	ice.shader = ice_sheet_shader
	ice.set_shader_parameter("grow",0.0)
	ice.set_shader_parameter("radius",radius)
	# (Drawn before every other effect, so fire, spikes, scorch and the
	# rest show over the ice rather than under it.)
	ice.render_priority = Material.RENDER_PRIORITY_MIN
	node.sheet.material_override = ice
	node.add_child(node.sheet)
	return node

# A bolt of ice in flight: a cold trail, frost smoking off it and glinting
# motes of ice shed behind it, and a light.
static func ice_trail(node: Node3D) -> void:
	var trail = Vfx.particles(node,30,.35,false,true)
	trail.direction = Vector3.ZERO
	trail.spread = 180
	trail.gravity = Vector3(0,-.6,0)
	trail.initial_velocity_min = .1; trail.initial_velocity_max = .5
	trail.scale_amount_min = .12; trail.scale_amount_max = .22
	trail.scale_amount_curve = Vfx.curve(1.0,0.0)
	trail.color = Color(.75,.92,1,.85)
	trail.scale = Vector3.ONE/node.scale
	trail.emitting = true
	var mist = Vfx.particles(node,40,.75,false,false)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = .08
	mist.direction = Vector3.UP
	mist.spread = 180
	mist.gravity = Vector3(0,-.35,0)
	mist.initial_velocity_min = .05; mist.initial_velocity_max = .3
	mist.damping_min = .5; mist.damping_max = 1.0
	mist.scale_amount_min = .16; mist.scale_amount_max = .3
	mist.scale_amount_curve = Vfx.curve(.6,1.5)
	mist.color_ramp = Vfx.ramp([0,.2,1],[Color(.85,.95,1,0),Color(.85,.95,1,.4),Color(.8,.92,1,0)])
	mist.scale = Vector3.ONE/node.scale
	mist.emitting = true
	var glints = Vfx.particles(node,36,.9,false,true)
	glints.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glints.emission_sphere_radius = .1
	glints.spread = 180
	glints.gravity = Vector3(0,-.5,0)
	glints.initial_velocity_min = .2; glints.initial_velocity_max = .7
	glints.scale_amount_min = .03; glints.scale_amount_max = .06
	glints.color_ramp = Vfx.ramp([0,.5,1],[Color(.95,1,1,1),Color(.7,.9,1,.8),Color(.6,.85,1,0)])
	glints.scale = Vector3.ONE/node.scale
	glints.emitting = true
	var glow = OmniLight3D.new()
	glow.light_color = FROST
	glow.light_energy = 1.3
	glow.omni_range = 2.8
	node.add_child(glow)

# Ice shattering at `at`: shards flung out and frost mist.
static func shatter(parent: Node3D, at: Vector3, size: float) -> Node3D:
	var shards = Vfx.particles(parent,26,.7,true,false)
	shards.position = at
	shards.explosiveness = 1.0
	shards.direction = Vector3.UP
	shards.spread = 90
	shards.gravity = Vector3(0,-9.0,0)
	shards.initial_velocity_min = size*2.0; shards.initial_velocity_max = size*4.5
	shards.scale_amount_min = .06; shards.scale_amount_max = .14
	shards.color_ramp = Vfx.ramp([0,.6,1],[Color(.9,.97,1,1),Color(.75,.9,1,.9),Color(.7,.88,1,0)])
	shards.emitting = true
	shards.finished.connect(shards.queue_free)
	var mist = RangerFx.burst(parent,at,Color(.82,.93,1,.6),size*1.3,14)
	mist.finished.connect(mist.queue_free)
	var flash = OmniLight3D.new()
	flash.light_color = FROST
	flash.light_energy = 2.5
	flash.omni_range = size*3.0
	shards.add_child(flash)
	flash.create_tween().tween_property(flash,"light_energy",0.0,.3)
	return shards

# An enemy frozen solid: crystals of ice closed about it from the floor up
# (a thicker block for a prison), with frost breathing off it.
static func ice_block(size: float, prison: bool) -> Node3D:
	var node = Node3D.new()
	var count = 9 if prison else 6
	for i in count:
		var angle = TAU*i/count+i*.7
		var crystal = Art.model("gem",Vector3(.34,1.9*size*(.8+fposmod(i*.37,1.0)*.35),.34)*(1.25 if prison else 1.0),ice())
		node.add_child(crystal)
		crystal.position = Vector3(sin(angle),0,cos(angle))*(.22 if prison else .18)*size
		crystal.rotation = Vector3(.12*sin(i*2.1),angle,.1*cos(i*1.3))
	var breath = Vfx.particles(node,10,1.6,false,false)
	breath.position = Vector3.UP*size*.5
	breath.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	breath.emission_sphere_radius = .4*size
	breath.direction = Vector3.DOWN
	breath.spread = 40
	breath.gravity = Vector3(0,-.3,0)
	breath.initial_velocity_min = .1; breath.initial_velocity_max = .3
	breath.scale_amount_min = .3; breath.scale_amount_max = .5
	breath.color_ramp = Vfx.ramp([0,.3,1],[Color(.85,.95,1,0),Color(.85,.95,1,.35),Color(.85,.95,1,0)])
	breath.emitting = true
	var glow = OmniLight3D.new()
	glow.light_color = FROST
	glow.light_energy = 1.0
	glow.omni_range = 3.0*size
	glow.position = Vector3.UP*size
	node.add_child(glow)
	return node

# Ice Spikes: spikes thrown up out of the floor across `radius` about `at`,
# from the middle outward, held, and sunk again.
class Spikes extends Node3D:
	const RISE = .3
	const HOLD = .9
	const SINK = .7
	var age = 0.0
	var spikes: Array = []
	var flash: OmniLight3D
	func tick(dt: float) -> bool:
		age += dt
		var left = false
		for s in spikes:
			var since = age-s.at
			var grow = clampf(since/.1,0.0,1.0)
			var sink = clampf((since-HOLD)/SINK,0.0,1.0)
			var h = 0.0 if since<0 else (1.0-pow(1.0-grow,2.0))*(1.0-sink*sink)
			s.node.scale = Vector3(s.size.x,maxf(.001,s.size.y*h),s.size.z)
			s.node.visible = h>.002
			left = left or sink<1.0
		flash.light_energy = 4.0*clampf(1.0-age/.6,0.0,1.0)
		return not left
# A spike of ice, a unit high: a crystal of uneven facets standing on its
# foot, a little waisted above it, drawn up to a needle point. Each of a few
# shapes is made once and shared (`shape` picks one).
static var crystal_meshes: Array = []
static var crystal_shader: Shader
static func crystal_mesh(shape: int) -> ArrayMesh:
	if crystal_meshes.is_empty():
		for k in 4:
			var rng = RandomNumberGenerator.new()
			rng.seed = 7919*(k+1)
			var sides: int = 5+k%3
			# Each facet's own reach, so no two edges stand alike.
			var reach: Array = []
			for i in sides: reach.append(rng.randf_range(.7,1.15))
			# Up its length: its width there (a share of its foot's) and height.
			var rings: Array = [[1.0,0.0],[.92,.12],[.78,.42],[.5,.7],[.22,.88]]
			var tip = Vector3(rng.randf_range(-.06,.06),1.0,rng.randf_range(-.06,.06))
			var tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var ring_points: Array = []
			for r in rings:
				var points: Array = []
				for i in sides:
					var angle: float = TAU*i/sides+k
					points.append(Vector3(cos(angle)*reach[i]*r[0],r[1],sin(angle)*reach[i]*r[0])+tip*Vector3(1,0,1)*r[1])
				ring_points.append(points)
			# Flat facets: each triangle its own corners.
			for j in rings.size()-1:
				for i in sides:
					var a: Vector3 = ring_points[j][i]
					var b: Vector3 = ring_points[j][(i+1)%sides]
					var c: Vector3 = ring_points[j+1][i]
					var d: Vector3 = ring_points[j+1][(i+1)%sides]
					for v in [a,c,b,b,c,d]: tool.add_vertex(v)
			for i in sides:
				for v in [ring_points[-1][i],tip,ring_points[-1][(i+1)%sides]]: tool.add_vertex(v)
			tool.generate_normals()
			crystal_meshes.append(tool.commit())
	return crystal_meshes[shape%crystal_meshes.size()]

static func spikes(at: Vector3, radius: float) -> Node3D:
	var node = Spikes.new()
	node.position = at
	var seed = fposmod(at.x*3.7+at.z*1.3,TAU)
	var count = int(radius*radius*11)
	if crystal_shader == null: crystal_shader = preload("res://assets/shaders/ice_crystal.gdshader")
	for i in count:
		var angle = seed+i*2.399
		var out = radius*sqrt((i+.5)/count)
		var spike = MeshInstance3D.new()
		spike.mesh = crystal_mesh(i)
		var look = ShaderMaterial.new()
		look.shader = crystal_shader
		look.set_shader_parameter("seed",fposmod(i*7.31+seed*3.0,50.0))
		spike.material_override = look
		node.add_child(spike)
		# Slender and tall, the tallest toward the middle, each leaning out.
		var tall: float = (.8+fposmod(i*.41,1.0)*.7)*(1.15-.35*out/radius)
		var wide: float = .1+fposmod(i*.73,1.0)*.07
		spike.scale = Vector3(wide,tall,wide)
		spike.position = Vector3(sin(angle),0,cos(angle))*out
		var outward = Vector3(sin(angle),0,cos(angle))
		var lean: float = .15+.35*out/radius+.1*sin(i*1.7)
		spike.basis = Basis(outward.cross(Vector3.UP).normalized() if out>.05 else Vector3.RIGHT,-lean)*Basis(Vector3.UP,i*1.3)*Basis.from_scale(spike.scale)
		node.spikes.append({"node":spike,"size":spike.scale,"at":Spikes.RISE*out/radius})
		spike.scale.y = .001
	node.flash = OmniLight3D.new()
	node.flash.light_color = FROST
	node.flash.omni_range = radius*2.5
	node.flash.position = Vector3.UP*1.2
	node.add_child(node.flash)
	var mist = RangerFx.burst(node,Vector3.UP*.3,Color(.85,.95,1,.5),radius*1.6,22)
	mist.finished.connect(mist.queue_free)
	return node

# A stream of frost from `from` along `way` for `length` metres: particles
# driven out fast, thinning into mist, and a cold light at its end. Moved
# each frame by the channel that holds it (aim()).
class Stream extends Node3D:
	var core: CPUParticles3D
	var mist: CPUParticles3D
	var tip: OmniLight3D
	var length = 10.0
	func aim(from: Vector3, way: Vector3, reach: float) -> void:
		position = from
		length = reach
		var speed = reach/.45
		for p in [core,mist]:
			p.direction = way
			p.initial_velocity_min = speed*.9; p.initial_velocity_max = speed*1.05
		tip.position = way*reach*.9
	func stop() -> void:
		core.emitting = false
		mist.emitting = false
		tip.light_energy = 0.0
		create_tween().tween_callback(queue_free).set_delay(.6)
static func stream(parent: Node3D, broad: bool) -> Stream:
	var node = Stream.new()
	parent.add_child(node)
	node.core = Vfx.particles(node,110 if broad else 70,.45,false,true)
	node.core.direction = Vector3.FORWARD
	node.core.spread = 10 if broad else 5
	node.core.gravity = Vector3.ZERO
	node.core.scale_amount_min = .2 if broad else .12; node.core.scale_amount_max = .45 if broad else .28
	node.core.scale_amount_curve = Vfx.curve(.5,1.4)
	node.core.color_ramp = Vfx.ramp([0,.15,.7,1],[Color(.9,.97,1,.5),Color(.72,.9,1,.4),Color(.62,.85,1,.22),Color(.6,.85,1,0)])
	node.core.emitting = true
	node.mist = Vfx.particles(node,70,.9,false,false)
	node.mist.direction = Vector3.FORWARD
	node.mist.spread = 18 if broad else 10
	node.mist.gravity = Vector3(0,-.4,0)
	node.mist.damping_min = 6.0; node.mist.damping_max = 9.0
	node.mist.scale_amount_min = .5; node.mist.scale_amount_max = 1.1
	node.mist.scale_amount_curve = Vfx.curve(.4,1.8)
	node.mist.color_ramp = Vfx.ramp([0,.3,1],[Color(.85,.95,1,0),Color(.85,.95,1,.4),Color(.85,.95,1,0)])
	node.mist.emitting = true
	node.tip = OmniLight3D.new()
	node.tip.light_color = FROST
	node.tip.light_energy = 1.8
	node.tip.omni_range = 4.0
	node.add_child(node.tip)
	return node

# Ice Storm: frost whirling about the wizard out to `radius`, and the floor
# iced under him, while it lasts (follows him: its parent is his figure).
static func storm(body: Node3D, radius: float) -> Node3D:
	var node = Node3D.new()
	body.add_child(node)
	var whirl = Vfx.particles(node,120,1.6,false,true)
	whirl.local_coords = true
	whirl.position = Vector3.UP*.2
	whirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	whirl.emission_ring_axis = Vector3.UP
	whirl.emission_ring_radius = radius*.9
	whirl.emission_ring_inner_radius = radius*.3
	whirl.emission_ring_height = .2
	whirl.direction = Vector3.UP
	whirl.spread = 10
	whirl.gravity = Vector3(0,.9,0)
	whirl.initial_velocity_min = .4; whirl.initial_velocity_max = 1.0
	whirl.orbit_velocity_min = .45; whirl.orbit_velocity_max = .7
	whirl.scale_amount_min = .07; whirl.scale_amount_max = .18
	whirl.scale_amount_curve = Vfx.curve(1.0,0.0)
	whirl.color_ramp = Vfx.ramp([0,.3,1],[Color(1,1,1,0),Color(.72,.88,1,.7),Color(.6,.85,1,0)])
	whirl.emitting = true
	var mist = Vfx.particles(node,40,1.8,false,false)
	mist.local_coords = true
	mist.position = Vector3.UP*.3
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	mist.emission_ring_axis = Vector3.UP
	mist.emission_ring_radius = radius
	mist.emission_ring_inner_radius = radius*.5
	mist.emission_ring_height = .1
	mist.gravity = Vector3(0,.2,0)
	mist.orbit_velocity_min = .3; mist.orbit_velocity_max = .5
	mist.scale_amount_min = .7; mist.scale_amount_max = 1.3
	mist.color_ramp = Vfx.ramp([0,.3,1],[Color(.85,.95,1,0),Color(.85,.95,1,.3),Color(.85,.95,1,0)])
	mist.emitting = true
	ground_sprite(node,radius*2.1,Vfx.ramp([0,.6,1],[Color(.8,.92,1,.5),Color(.78,.9,1,.3),Color(.8,.92,1,0)]))
	var glow = OmniLight3D.new()
	glow.light_color = FROST
	glow.light_energy = 1.6
	glow.omni_range = radius*1.8
	glow.position = Vector3.UP*1.4
	node.add_child(glow)
	return node

# --- Fire ----------------------------------------------------------------------

# Blast Wave: a ring of flame bursting out from `at` to `radius`: the
# shockwave's racing front in fire, embers hurled out with it, a flash, and
# smoke.
static func flame_ring(at: Vector3, radius: float) -> Node3D:
	var wave: Node3D = Shockwave.make(at,radius)
	for mesh in wave.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial:
			mesh.material_override.set_shader_parameter("tint",Color(1.0,.5,.15,.9))
			mesh.material_override.set_shader_parameter("crack_glow",Color(1.0,.45,.1))
	for light in wave.find_children("*","OmniLight3D",true,false): light.light_color = FLAME
	var embers = Vfx.particles(wave,90,.8,true,true)
	embers.explosiveness = .95
	embers.position = Vector3.UP*.5
	embers.direction = Vector3(1,0,0)
	embers.spread = 180
	embers.flatness = .85
	embers.initial_velocity_min = radius*1.6; embers.initial_velocity_max = radius*2.2
	embers.damping_min = radius*1.2; embers.damping_max = radius*1.8
	embers.gravity = Vector3(0,.8,0)
	embers.scale_amount_min = .14; embers.scale_amount_max = .34
	embers.scale_amount_curve = Vfx.curve(1.0,.2)
	embers.color_ramp = Vfx.ramp([0,.3,.7,1],[Color(1,.95,.7,1),Color(1,.55,.15,.9),Color(.8,.2,.03,.6),Color(.2,.05,0,0)])
	embers.emitting = true
	var smoke = Vfx.particles(wave,30,1.6,true,false)
	smoke.explosiveness = .9
	smoke.position = Vector3.UP*.4
	smoke.direction = Vector3(1,0,0)
	smoke.spread = 180
	smoke.flatness = .7
	smoke.initial_velocity_min = radius*.9; smoke.initial_velocity_max = radius*1.4
	smoke.damping_min = radius; smoke.damping_max = radius*1.5
	smoke.gravity = Vector3(0,.9,0)
	smoke.scale_amount_min = .8; smoke.scale_amount_max = 1.4
	smoke.scale_amount_curve = Vfx.curve(.5,1.6)
	smoke.color_ramp = Vfx.ramp([0,.2,1],[Color(.2,.16,.14,0),Color(.15,.13,.12,.5),Color(.08,.07,.07,0)])
	smoke.emitting = true
	return wave

# Fire Tornado: a column of flame `radius` wide turning about `at` for
# `seconds`, embers flung off it, smoke off its crown, a scorch beneath, and
# its light. Its fire is a volume of tongues of flame like the torches', much
# larger (assets/shaders/tornado_flame.gdshader), each whirled up a spiral
# ring a funnel that is slender at its foot and flares toward its crown; the
# funnel's axis twists about like a corkscrew and its crown trails behind as
# it travels. The tongues and embers are moved here, on the combat clock, so
# pausing freezes the fire.
class Tornado extends Node3D:
	var age = 0.0
	var life = 6.0
	var radius = 2.0
	var twist = 0.0
	# Where it is heading (Skills moves it), so its crown trails behind.
	var travel = Vector3.ZERO
	var trail = Vector2.ZERO
	# The tongues: each one's height, angle round the column, how far out it
	# rides (a share of the funnel's width), age, lifetime, how fast it rises
	# and whirls, its size, and its seed.
	var fire: MultiMeshInstance3D
	var rise := PackedFloat32Array()
	var angle := PackedFloat32Array()
	var out := PackedFloat32Array()
	var lived := PackedFloat32Array()
	var lasts := PackedFloat32Array()
	var climb := PackedFloat32Array()
	var whirl := PackedFloat32Array()
	var size := PackedFloat32Array()
	var marks := PackedFloat32Array()
	# The embers: drawn in the world, so they are left behind as it travels.
	var sparks: MultiMeshInstance3D
	var spark_at := PackedVector3Array()
	var spark_way := PackedVector3Array()
	var spark_lived := PackedFloat32Array()
	var spark_lasts := PackedFloat32Array()
	var spark_size := PackedFloat32Array()
	var spark_due = 0.0
	var smoke: CPUParticles3D
	var glow: OmniLight3D
	var scorch: Sprite3D
	var heat: Gradient
	var cooling: Gradient

	# The funnel's half-width at `h` (0 its foot, 1 its crown).
	func width(h: float) -> float:
		return radius*(.12+.88*pow(h,1.8)+.14*exp(-h*12.0))

	# Its axis at `h`: a bend that winds round it like a corkscrew and slowly
	# turns, more the higher it goes, a quicker wobble on top, and its crown
	# trailing behind.
	func axis(h: float) -> Vector3:
		var sway: float = pow(h,1.4)
		var turn: float = age*1.6+twist+h*2.8
		var bend: float = .6+sin(age*.7+twist)*.2
		return Vector3((cos(turn)*bend+sin(h*6.1-age*2.6+twist*2.0)*.14)*sway+trail.x*h*h,
			0,(sin(turn)*bend+cos(h*5.3-age*2.4)*.14)*sway+trail.y*h*h)

	# A new tongue, low in the column: most kindle at its foot, a few higher.
	func kindle(i: int) -> void:
		rise[i] = TORNADO_HEIGHT*pow(randf(),2.2)*.55
		angle[i] = randf()*TAU
		# (Most on its skin, some through its heart.)
		out[i] = randf_range(.8,1.08) if randf()<.8 else randf_range(.2,.7)
		lived[i] = 0.0
		lasts[i] = randf_range(.9,1.6)
		climb[i] = randf_range(2.4,3.6)
		whirl[i] = randf_range(6.0,8.5)
		size[i] = randf_range(.75,1.2)
		marks[i] = randf()*50.0
		# Some cling to its foot, whirling round low and slow and flaring out
		# over the ground where the funnel meets it.
		if randf()<.2:
			rise[i] = randf()*.2
			out[i] = randf_range(.7,1.7)
			lasts[i] = randf_range(.6,1.1)
			climb[i] = randf_range(.4,.9)

	func fling(at: Vector3, way: Vector3) -> void:
		var i: int = spark_lived.find(-1.0)
		if i<0: return
		spark_at[i] = at
		spark_way[i] = way
		spark_lived[i] = 0.0
		spark_lasts[i] = randf_range(1.0,2.2)
		spark_size[i] = randf_range(.07,.12)

	func tick(dt: float) -> bool:
		age += dt
		var strength: float = minf(1.0,age/.5)*clampf((life-age)/.9,0.0,1.0)
		var burning: bool = age<life
		glow.light_energy = 3.6*strength*(1.0+sin(age*19.0)*.12)
		scorch.modulate.a = .55*minf(1.0,age/.6)*clampf((life+2.5-age)/2.0,0.0,1.0)
		trail = trail.lerp(-Vector2(travel.x,travel.z)*.9,minf(1.0,dt*2.0))
		smoke.emitting = burning
		var where: Vector3 = global_position if is_inside_tree() else position
		var buffer: PackedFloat32Array = fire.multimesh.buffer
		var count: int = rise.size()
		var lit = 0
		for i in count:
			lived[i] += dt
			if lived[i]>=lasts[i] or rise[i]>=TORNADO_HEIGHT:
				# (As it dies down no more kindle, and its fire burns out.)
				if burning: kindle(i)
				else: lasts[i] = -1.0
			var b = i*20
			if lasts[i]<0:
				buffer[b] = 0.0; buffer[b+5] = 0.0; buffer[b+15] = 0.0
				continue
			var u: float = lived[i]/lasts[i]
			# It rises faster as it goes, and whirls round faster where the
			# funnel is narrow.
			var h: float = rise[i]/TORNADO_HEIGHT
			rise[i] += climb[i]*(1.0+u*.8)*dt
			var spin: float = whirl[i]*(1.3-.65*h)
			angle[i] += spin*dt
			var reach: float = width(h)*out[i]*(1.0+.12*sin(marks[i]+age*3.0))
			var ring = Vector3(cos(angle[i]),0,sin(angle[i]))
			var at: Vector3 = axis(h)+ring*reach+Vector3.UP*rise[i]
			var way: Vector3 = Vector3(-ring.z,0,ring.x)*reach*spin+Vector3.UP*climb[i]
			# It swells as it kindles and gutters as it dies, larger high up.
			var swell: float = sqrt(sin(PI*u))*size[i]*strength
			var across: float = radius*(.2+.34*h)*swell
			var along: float = across*(1.3+minf(way.length()*.05,.6))
			var color: Color = heat.sample(clampf(1.0-h*.55-u*.35+(1.0-out[i])*.25+(marks[i]-25.0)*.006,0.0,1.0))
			buffer[b] = across; buffer[b+1] = 0; buffer[b+2] = 0; buffer[b+3] = at.x
			buffer[b+4] = 0; buffer[b+5] = along; buffer[b+6] = 0; buffer[b+7] = at.y
			buffer[b+8] = 0; buffer[b+9] = 0; buffer[b+10] = 1; buffer[b+11] = at.z
			buffer[b+12] = color.r; buffer[b+13] = color.g; buffer[b+14] = color.b; buffer[b+15] = color.a
			buffer[b+16] = way.x; buffer[b+17] = way.y; buffer[b+18] = way.z; buffer[b+19] = marks[i]
			lit += 1
			# Now and then an ember is flung off it, whirling on as it flies.
			if burning and h<.7 and randf()<dt*1.1:
				fling(where+at,Vector3(-ring.z,0,ring.x)*reach*spin*.55+ring*randf_range(1.0,2.5)+Vector3.UP*randf_range(1.5,3.5))
		fire.multimesh.buffer = buffer
		var lights: PackedFloat32Array = sparks.multimesh.buffer
		for i in spark_lived.size():
			var b = i*20
			if spark_lived[i]<0:
				lights[b] = 0.0; lights[b+5] = 0.0
				continue
			spark_lived[i] += dt
			var u: float = spark_lived[i]/spark_lasts[i]
			if u>=1.0:
				spark_lived[i] = -1.0
				lights[b] = 0.0; lights[b+5] = 0.0
				continue
			# Carried up on the heat, slowed by the air, drifting as it cools.
			var drift: Vector3 = spark_way[i]
			drift += Vector3(sin(age*3.0+i)*.8,1.1,cos(age*2.6+i*1.7)*.8)*dt
			drift *= 1.0-minf(1.0,1.1*dt)
			spark_way[i] = drift
			spark_at[i] += drift*dt
			var p: Vector3 = spark_at[i]
			var s: float = spark_size[i]*(1.0-u*.5)
			var color: Color = cooling.sample(u)
			lights[b] = s; lights[b+1] = 0; lights[b+2] = 0; lights[b+3] = p.x
			lights[b+4] = 0; lights[b+5] = s*(1.0+minf(drift.length()*.6,3.0)); lights[b+6] = 0; lights[b+7] = p.y
			lights[b+8] = 0; lights[b+9] = 0; lights[b+10] = 1; lights[b+11] = p.z
			lights[b+12] = color.r; lights[b+13] = color.g; lights[b+14] = color.b; lights[b+15] = color.a
			lights[b+16] = drift.x; lights[b+17] = drift.y; lights[b+18] = drift.z; lights[b+19] = 0
		sparks.multimesh.buffer = lights
		for m in [fire,sparks]: (m.material_override as ShaderMaterial).set_shader_parameter("flame_time",age)
		fire.visible = lit>0
		return age >= life+2.5
const TORNADO_HEIGHT = 6.0
# Tongues of flame in a tornado, and embers it can have in the air at once.
const TORNADO_TONGUES = 320
const TORNADO_EMBERS = 90
static func flame_cloud(parent: Node3D, count: int, ember: bool, bounds: AABB) -> MultiMeshInstance3D:
	var cloud = MultiMeshInstance3D.new()
	cloud.multimesh = MultiMesh.new()
	cloud.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cloud.multimesh.use_colors = true
	cloud.multimesh.use_custom_data = true
	cloud.multimesh.mesh = QuadMesh.new()
	cloud.multimesh.instance_count = count
	cloud.multimesh.custom_aabb = bounds
	cloud.custom_aabb = bounds
	var buffer = PackedFloat32Array()
	buffer.resize(count*20)
	cloud.multimesh.buffer = buffer
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/tornado_flame.gdshader")
	material.set_shader_parameter("ember",1.0 if ember else 0.0)
	cloud.material_override = material
	parent.add_child(cloud)
	return cloud
static func tornado(at: Vector3, radius: float, seconds: float) -> Node3D:
	var node = Tornado.new()
	node.position = at
	node.life = seconds
	node.radius = radius
	node.twist = randf()*40.0
	# Hot white-yellow at its root, through orange, to a dull red as it cools.
	node.heat = Vfx.ramp([0,.25,.55,.8,1],[Color(.5,.08,.01,.15),Color(.9,.24,.03,.45),Color(1,.42,.06,.6),Color(1,.62,.16,.6),Color(1,.8,.4,.55)])
	node.cooling = Vfx.ramp([0,.5,1],[Color(1,.85,.5,1),Color(1,.45,.1,.9),Color(.6,.1,.02,0)])
	node.fire = flame_cloud(node,TORNADO_TONGUES,false,AABB(Vector3(-radius*3,-1,-radius*3),Vector3(radius*6,TORNADO_HEIGHT+3,radius*6)))
	for list in [node.rise,node.angle,node.out,node.lived,node.lasts,node.climb,node.whirl,node.size,node.marks]: list.resize(TORNADO_TONGUES)
	for i in TORNADO_TONGUES:
		node.kindle(i)
		# (Already at every stage of their lives, so it does not kindle all at once.)
		node.lived[i] = randf()*node.lasts[i]
		node.rise[i] += node.climb[i]*node.lived[i]
	# The embers are drawn in the world, wherever they were flung.
	node.sparks = flame_cloud(node,TORNADO_EMBERS,true,AABB(Vector3(-1000,-100,-1000),Vector3(2000,200,2000)))
	node.sparks.top_level = true
	for list in [node.spark_lived,node.spark_lasts,node.spark_size]: list.resize(TORNADO_EMBERS)
	for list in [node.spark_at,node.spark_way]: list.resize(TORNADO_EMBERS)
	node.spark_lived.fill(-1.0)
	# Thick black smoke boiling off its crown, left behind as it travels.
	node.smoke = Vfx.particles(node,60,3.0,false,false)
	node.smoke.position = Vector3.UP*TORNADO_HEIGHT*.72
	node.smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	node.smoke.emission_sphere_radius = radius*.7
	node.smoke.direction = Vector3.UP
	node.smoke.spread = 35
	node.smoke.gravity = Vector3(0,.6,0)
	node.smoke.initial_velocity_min = .6; node.smoke.initial_velocity_max = 1.4
	node.smoke.scale_amount_min = 1.4; node.smoke.scale_amount_max = 2.4
	node.smoke.scale_amount_curve = Vfx.curve(.5,1.8)
	node.smoke.color_ramp = Vfx.ramp([0,.15,1],[Color(.16,.12,.1,0),Color(.1,.085,.08,.6),Color(.06,.055,.05,0)])
	node.smoke.emitting = true
	node.glow = OmniLight3D.new()
	node.glow.light_color = FLAME
	node.glow.omni_range = radius*4.0
	node.glow.position = Vector3.UP*2.0
	node.add_child(node.glow)
	node.scorch = ground_sprite(node,radius*2.2,Vfx.ramp([0,.55,1],[Color(.05,.03,.02,.9),Color(.07,.04,.03,.5),Color(.08,.05,.03,0)]))
	node.scorch.modulate.a = 0
	return node

# Blazing Speed: flame licking up round him and embers streaming off as he runs.
static func blaze(body: Node3D) -> Node3D:
	var heat = Vfx.particles(body,60,.6,false,true)
	heat.position = Vector3.UP*.5
	heat.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	heat.emission_sphere_radius = .4
	heat.direction = Vector3.UP
	heat.spread = 30
	heat.gravity = Vector3(0,2.0,0)
	heat.initial_velocity_min = .6; heat.initial_velocity_max = 1.6
	heat.scale_amount_min = .18; heat.scale_amount_max = .36
	heat.scale_amount_curve = Vfx.curve(1.0,0.0)
	heat.color_ramp = Vfx.ramp([0,.4,1],[Color(1,.85,.4,.9),Color(1,.45,.12,.8),Color(.7,.15,.03,0)])
	heat.emitting = true
	var glow = OmniLight3D.new()
	glow.light_color = FLAME
	glow.light_energy = 1.4
	glow.omni_range = 3.5
	glow.position = Vector3.UP*.6
	heat.add_child(glow)
	return heat

# Ignition's explosion: quick and sharp, over in under half a second. A
# white-hot flash swells into a ball of fire that cools through orange and
# red as it spreads (the fireball's burst, scripts/fireball.gd, run faster),
# a bright ring races out along the floor, embers fly out in every
# direction, and a little smoke is left. Ticked in Skills.waves.
const FIREBALL_SHADER = preload("res://assets/shaders/fireball.gdshader")
class Ignition extends Node3D:
	# How long the fireball swells and cools, and the ring runs.
	const BURST = .38
	const RING = .24
	var radius = 2.0
	var age = 0.0
	var ball: MeshInstance3D
	var ball_material: ShaderMaterial
	var core: MeshInstance3D
	var ring: MeshInstance3D
	var flash: OmniLight3D

	func dress() -> void:
		ball_material = ShaderMaterial.new()
		ball_material.shader = FIREBALL_SHADER
		ball_material.set_shader_parameter("burst",1.0)
		ball_material.set_shader_parameter("seed",randf()*50.0)
		ball = MeshInstance3D.new()
		ball.mesh = QuadMesh.new()
		ball.material_override = ball_material
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
		# The white-hot heart of it, gone in a blink.
		core = Vfx.soft_glow(Color(1,.85,.55,1),Vector2.ONE)
		add_child(core)
		# The ring racing out along the floor: bright at its edge, clear within.
		ring = glow_sprite(Vfx.ramp([0,.62,.8,.9,1],[Color(1,.5,.1,0),Color(1,.55,.15,.0),Color(1,.8,.4,.9),Color(1,.5,.12,.5),Color(1,.3,.05,0)]),false)
		ring.rotation.x = -PI/2
		ring.position.y = -.75
		flash = OmniLight3D.new()
		flash.light_color = Color(1,.62,.25)
		# (Soft: a strong light falls in squares on the floor's tiles.)
		flash.omni_range = radius*2.5
		add_child(flash)
		var embers = Vfx.particles(self,36,.55,true,true)
		embers.explosiveness = 1.0
		embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		embers.emission_sphere_radius = .2
		embers.direction = Vector3.UP
		embers.spread = 180
		embers.initial_velocity_min = 5.0; embers.initial_velocity_max = 10.0
		embers.damping_min = 6.0; embers.damping_max = 9.0
		embers.gravity = Vector3(0,-6.0,0)
		embers.scale_amount_min = .05; embers.scale_amount_max = .11
		embers.color_ramp = Vfx.ramp([0,.4,1],[Color(1,.97,.7,1),Color(1,.55,.12,.9),Color(.6,.12,.02,0)])
		embers.emitting = true
		var smoke = Vfx.particles(self,8,1.1,true,false)
		smoke.explosiveness = .9
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = radius*.3
		smoke.direction = Vector3.UP
		smoke.spread = 180
		smoke.initial_velocity_min = .4; smoke.initial_velocity_max = 1.0
		smoke.gravity = Vector3(0,1.2,0)
		smoke.scale_amount_min = .6; smoke.scale_amount_max = 1.0
		smoke.scale_amount_curve = Vfx.curve(.5,1.5)
		smoke.color_ramp = Vfx.ramp([0,.2,1],[Color(.2,.16,.13,0),Color(.15,.13,.11,.5),Color(.09,.08,.08,0)])
		smoke.emitting = true
		tick(0.0)

	# A glowing disc a metre across (scaled as it goes), added onto what is
	# behind it: facing the eye, or lying flat.
	func glow_sprite(gradient: Gradient, facing: bool) -> MeshInstance3D:
		var texture = GradientTexture2D.new()
		texture.width = 128; texture.height = 128
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(.5,.5); texture.fill_to = Vector2(1,.5)
		texture.gradient = gradient
		var glow = StandardMaterial3D.new()
		glow.albedo_texture = texture
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		if facing: glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var disc = MeshInstance3D.new()
		disc.mesh = QuadMesh.new()
		disc.material_override = glow
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc)
		return disc

	func tick(dt: float) -> bool:
		age += dt
		var p: float = minf(1.0,age/BURST)
		ball_material.set_shader_parameter("progress",p)
		ball_material.set_shader_parameter("flame_time",age*3.0)
		ball.scale = Vector3.ONE*radius*lerpf(.35,1.25,1.0-pow(1.0-p,3.0))
		ball.visible = p<1.0
		var blink: float = clampf(age/.12,0.0,1.0)
		core.scale = Vector3.ONE*radius*lerpf(.9,1.6,blink)
		core.material_override.set_shader_parameter("strength",1.6*(1.0-blink))
		core.visible = blink<1.0
		var r: float = clampf(age/RING,0.0,1.0)
		ring.scale = Vector3.ONE*radius*lerpf(.3,2.4,1.0-pow(1.0-r,2.0))
		ring.material_override.albedo_color.a = 1.0-r*r
		ring.visible = r<1.0
		flash.light_energy = 2.2*exp(-age*12.0)
		return age>1.3

static func ignition(parent: Node3D, at: Vector3, radius: float) -> Node3D:
	var burst = Ignition.new()
	burst.radius = radius
	burst.position = at
	parent.add_child(burst)
	burst.dress()
	return burst

# The wizard's teleport (Game.teleport): where he goes from, a flash and a
# column of pale violet light that he is drawn up into and is gone; where he
# arrives, the same flash, the light gathering down into him with a ring
# of sparks flung out across the floor. Over in half a second; ticked in
# Skills.waves.
class Blink extends Node3D:
	const LIFE = 1.2
	var arriving = false
	var age = 0.0
	var column: MeshInstance3D
	var glow: OmniLight3D

	func dress() -> void:
		# A soft pillar of light: a tall glow turned always to face the eye
		# (faint: it is added onto what is behind it, and must not hide him).
		column = Vfx.soft_glow(Color(.7,.62,1,.55),Vector2(1.0,3.0))
		column.position.y = 1.2
		add_child(column)
		glow = OmniLight3D.new()
		glow.light_color = Color(.72,.66,1)
		glow.omni_range = 3.0
		glow.position.y = 1.0
		add_child(glow)
		# Motes drawn up into the column as he goes, or flung out as he comes.
		var motes = Vfx.particles(self,40,.5,true,true)
		motes.explosiveness = .9
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		motes.emission_sphere_radius = .45 if not arriving else .15
		motes.position.y = .2 if arriving else 1.0
		motes.direction = Vector3.UP
		motes.spread = 25.0 if not arriving else 90.0
		motes.flatness = 0.0 if not arriving else .85
		motes.initial_velocity_min = 2.0 if not arriving else 3.0
		motes.initial_velocity_max = 4.5 if not arriving else 5.5
		motes.damping_min = 4.0; motes.damping_max = 7.0
		motes.gravity = Vector3(0,2.0 if not arriving else -1.0,0)
		motes.scale_amount_min = .04; motes.scale_amount_max = .09
		motes.color_ramp = Vfx.ramp([0,.4,1],[Color(1,1,1,1),Color(.75,.7,1,.9),Color(.55,.5,1,0)])
		motes.emitting = true
		tick(0.0)

	func tick(dt: float) -> bool:
		age += dt
		var u: float = clampf(age/.35,0.0,1.0)
		# Going, the column thins and rises away; arriving, it narrows down
		# into him.
		var thin: float = 1.0-u
		column.scale = Vector3(1.0*thin*(1.0 if arriving else 1.0+u*.3),3.0*(1.0+(u*.6 if not arriving else -u*.4)),1.0)
		column.position.y = 1.2+(u*.8 if not arriving else -u*.4)
		column.visible = u<1.0
		glow.light_energy = 1.0*exp(-age*7.0)
		return age>=LIFE

static func blink(parent: Node3D, at: Vector3, arriving: bool) -> Node3D:
	var flash = Blink.new()
	flash.arriving = arriving
	flash.position = at
	parent.add_child(flash)
	flash.dress()
	return flash

# Burning (Pyromaniac's cost): small flames on the hero while it lasts.
static func burning(body: Node3D) -> Node3D:
	var fire = Vfx.particles(body,24,.5,false,true)
	fire.position = Vector3.UP*1.0
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = .3
	fire.direction = Vector3.UP
	fire.spread = 20
	fire.gravity = Vector3(0,1.6,0)
	fire.initial_velocity_min = .3; fire.initial_velocity_max = .8
	fire.scale_amount_min = .12; fire.scale_amount_max = .24
	fire.scale_amount_curve = Vfx.curve(1.0,0.0)
	fire.color_ramp = Vfx.ramp([0,.5,1],[Color(1,.8,.35,.9),Color(1,.4,.1,.7),Color(.5,.1,.02,0)])
	fire.emitting = true
	return fire

# --- Lightning -------------------------------------------------------------------

# A bolt hurled from `a` to `b`: the ranger's jagged ribbon, and the crackle
# where it strikes (the crackle is returned, to be ticked; the bolt fades
# itself).
static func bolt(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var ribbon: Node3D = RangerFx.bolt(parent,a,b)
	ribbon.create_tween().tween_callback(ribbon.queue_free).set_delay(.2)
	var crackle = Crackle.make(b-Vector3.UP*.9)
	parent.add_child(crackle)
	return crackle

# Sparks shed along a hurled bolt's path from `a` to `b`, falling away and
# going out (Lightning Bolt).
static func bolt_sparks(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var sparks = Vfx.particles(parent,70,.5,true,true)
	sparks.position = a
	sparks.explosiveness = .9
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	var along = PackedVector3Array()
	for i in 24:
		along.append((b-a)*(i+randf())/24.0+Vector3(randf()-.5,randf()-.5,randf()-.5)*.15)
	sparks.emission_points = along
	sparks.spread = 180
	sparks.gravity = Vector3(0,-3.0,0)
	sparks.initial_velocity_min = .4; sparks.initial_velocity_max = 1.6
	sparks.scale_amount_min = .03; sparks.scale_amount_max = .06
	sparks.color_ramp = Vfx.ramp([0,.4,1],[Color(1,1,1,1),Color(.65,.85,1,.9),Color(.4,.6,1,0)])
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	return sparks

# A jolt leaping from one enemy to the next (Lightning Rod, Conductive Ice).
static func jolt(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var ribbon: Node3D = RangerFx.bolt(parent,a,b)
	ribbon.create_tween().tween_callback(ribbon.queue_free).set_delay(.18)

# Lightning Shield: a thin bubble of light about him, crackling with
# electricity where it absorbs a blow (scripts/shield_bubble.gd).
static func lightning_shield(body: Node3D) -> Node3D:
	return ShieldBubble.make(body)

# Lightning Rod's mark: static crawling over the marked enemy while it holds
# (scripts/static_arcs.gd; its enemy ticks it).
static func rod_mark(body: Node3D, skeleton: Skeleton3D, size: float) -> Node3D:
	return StaticArcs.make(body,skeleton,size)

# Lightning Rod's stroke: a great bolt of lightning out of the sky onto `at`
# (the marked enemy's feet), flickering as it strikes, struck again an
# instant later and fading, its forks spreading above; a flash that lights
# all about, arcs crackling where it struck and a scorch beneath. Ticked on
# the combat clock (Skills' waves) and freed when done.
class SkyStrike extends Node3D:
	var age = 0.0
	# When it flashes (the stroke, and the return strokes down the same
	# channel), as [start, end] in seconds; it glows faintly between.
	const STROKES = [[0.0,.09],[.14,.2],[.27,.31]]
	const LIFE = .55
	var top = Vector3.ZERO
	var mesh: ImmediateMesh
	var material: StandardMaterial3D
	var flash: OmniLight3D
	var crackle: Node3D
	var scorch: Sprite3D
	var channel: Array = []
	var forks: Array = []
	func lay() -> void:
		# Its channel: a jagged line, its zigzag coarse high up and fine low.
		channel = [top]
		var steps = 30
		var drift = Vector3.ZERO
		for i in range(1,steps+1):
			var u: float = float(i)/steps
			# (Each step kinks it sharply aside, and it wanders off its line.)
			var kink = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()*randf_range(.25,.75)
			drift = drift*.7+kink
			channel.append(top.lerp(Vector3.ZERO,u)+drift*(1.0-u*u*u))
		channel[-1] = Vector3.UP*.1
		forks = []
		for f in 6:
			var from: int = randi_range(2,steps-8)
			var way = Vector3(randf_range(-1,1),-randf_range(.6,1.3),randf_range(-1,1)).normalized()
			var points: Array = [channel[from]]
			for k in randi_range(4,8):
				way = (way+Vector3(randf_range(-.5,.5),randf_range(-.25,.15),randf_range(-.5,.5))).normalized()
				points.append(points[-1]+way*randf_range(.35,.8))
			forks.append(points)
	func brightness() -> float:
		for s in STROKES:
			if age >= s[0] and age <= s[1]: return 1.0-(age-s[0])/(s[1]-s[0])*.35
		return .25*clampf(1.0-age/LIFE,0.0,1.0)
	func tick(dt: float) -> bool:
		age += dt
		var lit: float = brightness()
		# Each return stroke takes a slightly new path down the channel.
		for s in STROKES:
			if age-dt < s[0] and age >= s[0] and s[0] > 0.0:
				for i in range(1,channel.size()-1): channel[i] += Vector3(randf_range(-.12,.12),0,randf_range(-.12,.12))
		mesh.clear_surfaces()
		if age < LIFE:
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
			ribbon(channel,.32,Color(.3,.5,1,.25*lit))
			ribbon(channel,.13,Color(.6,.8,1,.7*lit))
			ribbon(channel,.05,Color(.95,.98,1,lit))
			for f in forks:
				ribbon(f,.08,Color(.5,.7,1,.45*lit))
				ribbon(f,.025,Color(.85,.93,1,.85*lit))
			mesh.surface_end()
		flash.light_energy = 9.0*lit if age < LIFE else 0.0
		crackle.tick(dt)
		scorch.modulate.a = .6*clampf(1.0-(age-1.2)/1.0,0.0,1.0)
		return age >= 2.2
	# A ribbon along `points`, drawn twice at right angles so it shows from
	# any side.
	func ribbon(points: Array, width: float, color: Color) -> void:
		for i in points.size()-1:
			var p: Vector3 = points[i]
			var q: Vector3 = points[i+1]
			var along = (q-p).normalized()
			var side = along.cross(Vector3.FORWARD).normalized() if absf(along.dot(Vector3.FORWARD)) < .95 else Vector3.RIGHT
			for across in [side*width*.5,along.cross(side).normalized()*width*.5]:
				for v in [p-across,p+across,q+across,p-across,q+across,q-across]:
					mesh.surface_set_color(color)
					mesh.surface_add_vertex(v)
static func sky_strike(parent: Node3D, at: Vector3) -> Node3D:
	var node = SkyStrike.new()
	node.position = at
	node.top = Vector3(randf_range(-1.5,1.5),16.0,randf_range(-1.5,1.5))
	node.lay()
	node.mesh = ImmediateMesh.new()
	node.material = StandardMaterial3D.new()
	node.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material.vertex_color_use_as_albedo = true
	node.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	node.material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var bolt = MeshInstance3D.new()
	bolt.mesh = node.mesh
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (Its own bounds, up into the sky, so it is never culled as off screen.)
	bolt.custom_aabb = AABB(Vector3(-4,-1,-4),Vector3(8,19,8))
	node.add_child(bolt)
	node.flash = OmniLight3D.new()
	node.flash.light_color = Color(.7,.85,1)
	node.flash.omni_range = 10.0
	node.flash.position = Vector3.UP*2.5
	node.add_child(node.flash)
	node.crackle = Crackle.make(Vector3.ZERO)
	node.add_child(node.crackle)
	node.scorch = ground_sprite(node,2.2,Vfx.ramp([0,.5,1],[Color(.04,.04,.06,.9),Color(.06,.06,.08,.45),Color(.08,.08,.1,0)]))
	parent.add_child(node)
	node.tick(0.0)
	return node

# --- The hurled spells (Fireball, Ice Bolt, Lightning Bolt) ---------------------

# The casting hand alight as he gathers a hurled spell: flame licking up off
# it, frost smoking from it, or sparks snapping about it, each with its
# glow. It follows his left hand (Visual.bow_hold) and, once the spell is
# loosed (`release`), dies away; Skills frees it.
class HandAura extends Node3D:
	var visual
	var element = ""
	var glow: OmniLight3D
	var emitters: Array = []
	var age = 0.0
	var released = -1.0
	func release() -> void:
		if released >= 0.0: return
		released = 0.0
		for e in emitters: e.emitting = false
	func follow() -> void:
		if is_instance_valid(visual) and visual.skeleton != null: global_position = visual.bow_hold("l")[0]
	func _process(delta: float) -> void:
		age += delta
		follow()
		var energy: float = 1.6*(1.0+sin(age*21.0)*.12)
		if element == "lightning": energy = 1.0+randf()*1.6
		elif element == "ice": energy = 1.3
		if released >= 0.0:
			released += delta
			energy *= maxf(0.0,1.0-released/.2)
		glow.light_energy = energy*minf(1.0,age/.12)

static func hand_aura(parent: Node3D, visual: Node3D, element: String) -> HandAura:
	var aura = HandAura.new()
	aura.visual = visual
	aura.element = element
	parent.add_child(aura)
	aura.follow()
	match element:
		"fire":
			var flames = Vfx.particles(aura,44,.45,false,true)
			flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			flames.emission_sphere_radius = .07
			flames.direction = Vector3.UP
			flames.spread = 25
			flames.gravity = Vector3(0,2.2,0)
			flames.initial_velocity_min = .3; flames.initial_velocity_max = .8
			flames.scale_amount_min = .1; flames.scale_amount_max = .22
			flames.scale_amount_curve = Vfx.curve(1.0,0.0)
			flames.color_ramp = Vfx.ramp([0,.3,.7,1],[Color(1,.9,.55,.95),Color(1,.55,.15,.85),Color(.8,.2,.04,.5),Color(.3,.05,.02,0)])
			var embers = Vfx.particles(aura,12,.7,false,true)
			embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			embers.emission_sphere_radius = .08
			embers.direction = Vector3.UP
			embers.spread = 60
			embers.gravity = Vector3(0,1.0,0)
			embers.initial_velocity_min = .5; embers.initial_velocity_max = 1.2
			embers.scale_amount_min = .03; embers.scale_amount_max = .05
			embers.color_ramp = Vfx.ramp([0,.6,1],[Color(1,.85,.4,1),Color(1,.45,.1,.8),Color(.6,.1,.02,0)])
			aura.emitters = [flames,embers]
		"ice":
			var mist = Vfx.particles(aura,26,.8,false,false)
			mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			mist.emission_sphere_radius = .07
			mist.spread = 180
			mist.gravity = Vector3(0,-.4,0)
			mist.initial_velocity_min = .05; mist.initial_velocity_max = .25
			mist.scale_amount_min = .1; mist.scale_amount_max = .2
			mist.scale_amount_curve = Vfx.curve(.6,1.5)
			mist.color_ramp = Vfx.ramp([0,.2,1],[Color(.85,.95,1,0),Color(.85,.95,1,.5),Color(.8,.92,1,0)])
			var glints = Vfx.particles(aura,22,.6,false,true)
			glints.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			glints.emission_sphere_radius = .1
			glints.spread = 180
			glints.gravity = Vector3(0,-.3,0)
			glints.initial_velocity_min = .1; glints.initial_velocity_max = .4
			glints.scale_amount_min = .03; glints.scale_amount_max = .06
			glints.color_ramp = Vfx.ramp([0,.5,1],[Color(.95,1,1,1),Color(.7,.9,1,.8),Color(.6,.85,1,0)])
			var core = Vfx.particles(aura,8,.3,false,true)
			core.spread = 180
			core.initial_velocity_min = 0.0; core.initial_velocity_max = .05
			core.scale_amount_min = .16; core.scale_amount_max = .24
			core.color_ramp = Vfx.ramp([0,.5,1],[Color(.6,.85,1,0),Color(.6,.85,1,.45),Color(.6,.85,1,0)])
			aura.emitters = [mist,glints,core]
		_:
			var sparks = Vfx.particles(aura,40,.16,false,true)
			sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			sparks.emission_sphere_radius = .05
			sparks.spread = 180
			sparks.initial_velocity_min = 1.0; sparks.initial_velocity_max = 2.4
			sparks.scale_amount_min = .025; sparks.scale_amount_max = .05
			sparks.color_ramp = Vfx.ramp([0,.4,1],[Color(1,1,1,1),Color(.65,.85,1,.9),Color(.4,.6,1,0)])
			var core = Vfx.particles(aura,10,.12,false,true)
			core.spread = 180
			core.initial_velocity_min = 0.0; core.initial_velocity_max = .1
			core.scale_amount_min = .14; core.scale_amount_max = .24
			core.color_ramp = Vfx.ramp([0,.5,1],[Color(.8,.92,1,0),Color(.7,.85,1,.6),Color(.6,.8,1,0)])
			aura.emitters = [sparks,core]
	for e in aura.emitters: e.emitting = true
	aura.glow = OmniLight3D.new()
	aura.glow.light_color = {"fire":FLAME,"ice":FROST}.get(element,SPARK)
	aura.glow.omni_range = 2.2
	aura.glow.light_energy = 0.0
	aura.add_child(aura.glow)
	return aura

# Where a hurled spell strikes, what it leaves rising into the sky: embers
# and wisps of flame, motes of ice glinting in a breath of cold vapour, or
# sparks still crackling as they float up.
static func rising(parent: Node3D, at: Vector3, element: String) -> Node3D:
	var motes = Vfx.particles(parent,50,2.2,true,true)
	motes.position = at
	motes.explosiveness = .7
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = .45
	motes.direction = Vector3.UP
	motes.spread = 35
	motes.damping_min = .5; motes.damping_max = 1.0
	motes.scale_amount_curve = Vfx.curve(1.0,.3)
	var wisps = Vfx.particles(motes,18,1.1,true,element != "ice")
	wisps.explosiveness = .8
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = .35
	wisps.direction = Vector3.UP
	wisps.spread = 30
	match element:
		"fire":
			motes.gravity = Vector3(0,1.2,0)
			motes.initial_velocity_min = 1.2; motes.initial_velocity_max = 3.2
			motes.scale_amount_min = .07; motes.scale_amount_max = .14
			motes.color_ramp = Vfx.ramp([0,.3,.75,1],[Color(1,.9,.5,1),Color(1,.55,.15,.9),Color(.8,.2,.04,.5),Color(.4,.06,.02,0)])
			wisps.gravity = Vector3(0,2.0,0)
			wisps.initial_velocity_min = 1.0; wisps.initial_velocity_max = 2.4
			wisps.scale_amount_min = .4; wisps.scale_amount_max = .7
			wisps.scale_amount_curve = Vfx.curve(1.0,0.0)
			wisps.color_ramp = Vfx.ramp([0,.35,1],[Color(1,.75,.35,.8),Color(1,.4,.08,.55),Color(.5,.1,.03,0)])
		"ice":
			motes.lifetime = 2.4
			motes.gravity = Vector3(0,.5,0)
			motes.initial_velocity_min = .6; motes.initial_velocity_max = 1.8
			motes.scale_amount_min = .06; motes.scale_amount_max = .11
			motes.color_ramp = Vfx.ramp([0,.5,1],[Color(.95,1,1,1),Color(.7,.9,1,.8),Color(.6,.85,1,0)])
			wisps.lifetime = 1.4
			wisps.gravity = Vector3(0,.6,0)
			wisps.initial_velocity_min = .4; wisps.initial_velocity_max = .9
			wisps.damping_min = .5; wisps.damping_max = 1.0
			wisps.scale_amount_min = .3; wisps.scale_amount_max = .6
			wisps.scale_amount_curve = Vfx.curve(.5,1.5)
			wisps.color_ramp = Vfx.ramp([0,.2,1],[Color(.85,.93,1,0),Color(.85,.93,1,.35),Color(.85,.93,1,0)])
		_:
			motes.lifetime = 1.6
			motes.gravity = Vector3(0,.8,0)
			motes.initial_velocity_min = .8; motes.initial_velocity_max = 2.2
			motes.scale_amount_min = .05; motes.scale_amount_max = .1
			motes.color_ramp = Vfx.ramp([0,.15,.3,.5,1],[Color(1,1,1,1),Color(.5,.7,1,.4),Color(.9,.97,1,1),Color(.6,.8,1,.7),Color(.4,.6,1,0)])
			# (A quick spray of sparks, where it struck.)
			wisps.lifetime = .3
			wisps.explosiveness = 1.0
			wisps.spread = 180
			wisps.gravity = Vector3(0,-4.0,0)
			wisps.initial_velocity_min = 3.0; wisps.initial_velocity_max = 6.0
			wisps.scale_amount_min = .03; wisps.scale_amount_max = .05
			wisps.color_ramp = Vfx.ramp([0,.5,1],[Color(1,1,1,1),Color(.65,.85,1,.9),Color(.4,.6,1,0)])
	motes.emitting = true
	wisps.emitting = true
	motes.finished.connect(motes.queue_free)
	return motes
