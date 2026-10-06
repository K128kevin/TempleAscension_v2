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

# Frost on the floor: a pale patch `radius` wide, glittering, that melts away
# over `seconds` (the game keeps its own record of where the ice lies).
class Patch extends Node3D:
	var age = 0.0
	var life = 10.0
	var sheet: Sprite3D
	var glints: CPUParticles3D
	func tick(dt: float) -> bool:
		age += dt
		var a: float = minf(1.0,age/.25)*clampf((life-age)/1.5,0.0,1.0)
		sheet.modulate.a = .85*a
		if is_instance_valid(glints): glints.emitting = age < life-1.5
		return age >= life
static func patch(at: Vector3, radius: float, seconds: float) -> Node3D:
	var node = Patch.new()
	node.position = at
	node.life = seconds
	node.sheet = ground_sprite(node,radius*2.0,Vfx.ramp([0,.5,.8,1],[Color(.7,.88,1,.95),Color(.62,.84,1,.85),Color(.66,.86,1,.5),Color(.7,.9,1,0)]))
	node.sheet.modulate.a = 0
	node.glints = Vfx.particles(node,int(radius*8),1.4,false,true)
	node.glints.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	node.glints.emission_sphere_radius = radius*.85
	node.glints.position = Vector3.UP*.08
	node.glints.direction = Vector3.UP
	node.glints.spread = 20
	node.glints.gravity = Vector3(0,.15,0)
	node.glints.initial_velocity_min = .05; node.glints.initial_velocity_max = .2
	node.glints.scale_amount_min = .03; node.glints.scale_amount_max = .07
	node.glints.color_ramp = Vfx.ramp([0,.5,1],[Color(1,1,1,0),Color(.85,.95,1,.9),Color(.7,.9,1,0)])
	node.glints.emitting = true
	return node

# A bolt of ice in flight: a cold trail and a light.
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
static func spikes(at: Vector3, radius: float) -> Node3D:
	var node = Spikes.new()
	node.position = at
	var seed = fposmod(at.x*3.7+at.z*1.3,TAU)
	var count = int(radius*radius*11)
	for i in count:
		var angle = seed+i*2.399
		var out = radius*sqrt((i+.5)/count)
		var spike = Art.model("gem",Vector3(.13,.7+fposmod(i*.41,1.0)*.6,.13),ice())
		node.add_child(spike)
		spike.position = Vector3(sin(angle),0,cos(angle))*out
		spike.rotation = Vector3(.25*sin(i*1.7),angle,.2*cos(i*.9))
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
# `seconds`, embers flung up round it, a scorch beneath, and its light.
class Tornado extends Node3D:
	var age = 0.0
	var life = 6.0
	var flames: CPUParticles3D
	var embers: CPUParticles3D
	var smoke: CPUParticles3D
	var glow: OmniLight3D
	var scorch: Sprite3D
	func tick(dt: float) -> bool:
		age += dt
		var strength: float = minf(1.0,age/.4)*clampf((life-age)/.8,0.0,1.0)
		glow.light_energy = 3.2*strength*(1.0+sin(age*19.0)*.12)
		scorch.modulate.a = .55*minf(1.0,age/.6)*clampf((life+2.5-age)/2.0,0.0,1.0)
		for p in [flames,embers,smoke]: p.emitting = age < life
		return age >= life+2.5
static func tornado(at: Vector3, radius: float, seconds: float) -> Node3D:
	var node = Tornado.new()
	node.position = at
	node.life = seconds
	node.flames = Vfx.particles(node,160,1.1,false,true)
	node.flames.local_coords = true
	node.flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	node.flames.emission_ring_axis = Vector3.UP
	node.flames.emission_ring_radius = radius*.8
	node.flames.emission_ring_inner_radius = radius*.2
	node.flames.emission_ring_height = .2
	node.flames.direction = Vector3.UP
	node.flames.spread = 6
	node.flames.gravity = Vector3(0,1.5,0)
	node.flames.initial_velocity_min = 1.8; node.flames.initial_velocity_max = 3.2
	node.flames.orbit_velocity_min = .8; node.flames.orbit_velocity_max = 1.2
	node.flames.radial_accel_min = -1.5; node.flames.radial_accel_max = -.5
	node.flames.scale_amount_min = .35; node.flames.scale_amount_max = .7
	node.flames.scale_amount_curve = Vfx.curve(1.0,.1)
	node.flames.color_ramp = Vfx.ramp([0,.25,.65,1],[Color(1,.95,.7,.9),Color(1,.55,.15,.9),Color(.9,.25,.04,.5),Color(.3,.08,.02,0)])
	node.flames.emitting = true
	node.embers = Vfx.particles(node,50,1.6,false,true)
	node.embers.local_coords = true
	node.embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	node.embers.emission_ring_axis = Vector3.UP
	node.embers.emission_ring_radius = radius
	node.embers.emission_ring_inner_radius = radius*.4
	node.embers.emission_ring_height = .3
	node.embers.direction = Vector3.UP
	node.embers.spread = 30
	node.embers.gravity = Vector3(0,2.0,0)
	node.embers.initial_velocity_min = 1.0; node.embers.initial_velocity_max = 2.5
	node.embers.orbit_velocity_min = .6; node.embers.orbit_velocity_max = 1.0
	node.embers.scale_amount_min = .05; node.embers.scale_amount_max = .11
	node.embers.color_ramp = Vfx.ramp([0,.6,1],[Color(1,.9,.5,1),Color(1,.45,.1,.9),Color(.6,.1,.02,0)])
	node.embers.emitting = true
	node.smoke = Vfx.particles(node,24,2.2,false,false)
	node.smoke.local_coords = true
	node.smoke.position = Vector3.UP*2.4
	node.smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	node.smoke.emission_sphere_radius = radius*.5
	node.smoke.direction = Vector3.UP
	node.smoke.spread = 25
	node.smoke.gravity = Vector3(0,1.0,0)
	node.smoke.orbit_velocity_min = .3; node.smoke.orbit_velocity_max = .5
	node.smoke.scale_amount_min = .8; node.smoke.scale_amount_max = 1.5
	node.smoke.scale_amount_curve = Vfx.curve(.5,1.8)
	node.smoke.color_ramp = Vfx.ramp([0,.2,1],[Color(.2,.16,.14,0),Color(.14,.12,.11,.45),Color(.08,.07,.07,0)])
	node.smoke.emitting = true
	node.glow = OmniLight3D.new()
	node.glow.light_color = FLAME
	node.glow.omni_range = radius*3.5
	node.glow.position = Vector3.UP*1.5
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

# A burst of fire at `at` (Ignition, a fireball striking).
static func ignite(parent: Node3D, at: Vector3, radius: float) -> Node3D:
	var fire = RangerFx.burst(parent,at,Color(1,.55,.15,.9),radius*1.4,30)
	fire.finished.connect(fire.queue_free)
	var sparks = Vfx.particles(parent,24,.6,true,true)
	sparks.position = at
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 80
	sparks.gravity = Vector3(0,-7.0,0)
	sparks.initial_velocity_min = 2.5; sparks.initial_velocity_max = 5.0
	sparks.scale_amount_min = .06; sparks.scale_amount_max = .12
	sparks.color_ramp = Vfx.ramp([0,.5,1],[Color(1,.95,.6,1),Color(1,.5,.1,.9),Color(.6,.1,.02,0)])
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	var flash = OmniLight3D.new()
	flash.light_color = FLAME
	flash.light_energy = 4.0
	flash.omni_range = radius*3.0
	flash.position = Vector3.UP*.6
	fire.add_child(flash)
	flash.create_tween().tween_property(flash,"light_energy",0.0,.35)
	return fire

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

# A jolt leaping from one enemy to the next (Lightning Rod, Conductive Ice).
static func jolt(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var ribbon: Node3D = RangerFx.bolt(parent,a,b)
	ribbon.create_tween().tween_callback(ribbon.queue_free).set_delay(.18)

# Lightning Shield: sparks circling the wizard and small arcs snapping
# about him while it holds (its parent is his figure).
static func lightning_shield(body: Node3D) -> Node3D:
	var node = Node3D.new()
	body.add_child(node)
	var sparks = Vfx.particles(node,40,1.2,false,true)
	sparks.local_coords = true
	sparks.position = Vector3.UP*1.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_axis = Vector3.UP
	sparks.emission_ring_radius = .75
	sparks.emission_ring_inner_radius = .6
	sparks.emission_ring_height = 1.6
	sparks.gravity = Vector3.ZERO
	sparks.orbit_velocity_min = .9; sparks.orbit_velocity_max = 1.4
	sparks.scale_amount_min = .05; sparks.scale_amount_max = .1
	sparks.color_ramp = Vfx.ramp([0,.5,1],[Color(1,1,1,0),Color(.75,.88,1,1),Color(.6,.8,1,0)])
	sparks.emitting = true
	var glow = OmniLight3D.new()
	glow.light_color = SPARK
	glow.light_energy = .9
	glow.omni_range = 3.0
	glow.position = Vector3.UP*1.1
	node.add_child(glow)
	return node

# Lightning Rod: sparks snapping about the marked enemy while it holds.
static func rod_mark(size: float) -> Node3D:
	var node = Node3D.new()
	var sparks = Vfx.particles(node,18,.5,false,true)
	sparks.position = Vector3.UP*1.2*size
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = .45*size
	sparks.gravity = Vector3.ZERO
	sparks.direction = Vector3.UP
	sparks.spread = 180
	sparks.initial_velocity_min = .3; sparks.initial_velocity_max = 1.2
	sparks.scale_amount_min = .04; sparks.scale_amount_max = .09
	sparks.color_ramp = Vfx.ramp([0,.5,1],[Color(1,1,1,1),Color(.7,.86,1,.9),Color(.6,.8,1,0)])
	sparks.emitting = true
	var glow = OmniLight3D.new()
	glow.light_color = SPARK
	glow.light_energy = .7
	glow.omni_range = 2.5
	glow.position = Vector3.UP*1.2*size
	node.add_child(glow)
	return node
