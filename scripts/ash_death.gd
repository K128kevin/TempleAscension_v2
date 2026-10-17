extends Node3D
## The hero burned to ash by the basement's lasers (Game.kill_player), after
## the laser death in the 2D game Boulders, and timed as it is (its 24
## frames at 12 a second; its death sound, laser-death): the moment the beam
## touches him he goes molten red and yellow and begins to crumble, from the
## head down, sinking into himself as he does (MELT); by COLLAPSED he is a
## burning heap on the floor under a column of grey smoke, and the flames die
## down to embers in a dark heap of ash as the smoke thins (assets/shaders/
## ash_crumble.gdshader). The death screen comes at DURATION.
const Vfx = preload("res://scripts/vfx.gd")
const DURATION = 2.0
# How long he takes to crumble away, how long the molten glow takes to cool
# off him, and how far down into himself he sinks meanwhile.
const MELT = .75
const COOL = .9
const SINK = .3
const COLLAPSED = .7
const HEIGHT = 2.0
# When the heap gathers (from, to); how long its fire burns on it after he
# has fallen; how long its embers glow.
const HEAP = Vector2(.3,.8)
const FIRE = .6
const SMOULDER = 2.5
var crumble: ShaderMaterial

# Burns `body` (an actor) away where he stands in `world`.
static func burn(world: Node3D, body: Node3D) -> Node3D:
	var fx = new()
	world.add_child(fx)
	fx.start(body)
	return fx

func start(body: Node3D) -> void:
	name = "AshDeath"
	global_position = body.visual.global_position
	crumble = ShaderMaterial.new()
	crumble.shader = load("res://assets/shaders/ash_crumble.gdshader")
	crumble.set_shader_parameter("ground",global_position.y)
	crumble.set_shader_parameter("height",HEIGHT*body.visual.rig.scale.y)
	crumble.set_shader_parameter("progress",0.0)
	crumble.set_shader_parameter("heat",1.0)
	# Molten at once,
	for mesh in body.visual.find_children("*","MeshInstance3D",true,false):
		mesh.material_overlay = null
		mesh.material_override = crumble
	# crumbling and sinking into himself from the first,
	var fall = create_tween().set_parallel()
	fall.tween_method(func(v): crumble.set_shader_parameter("progress",v),0.0,1.0,MELT).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(body.visual,"scale",Vector3(1.0+SINK*.4,1.0-SINK,1.0+SINK*.4),MELT).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_method(func(v): crumble.set_shader_parameter("heat",v),1.0,0.0,COOL)
	fall.chain().tween_callback(func(): body.visual.visible = false)
	flare()
	embers()
	floor_fire()
	smoke()
	heap()

# The beam's touch: flame licking up all over him and a hot light, dying away.
func flare() -> void:
	var flame: CPUParticles3D = Vfx.particles(self,30,.45,false,true)
	flame.position = Vector3.UP*.95
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flame.emission_box_extents = Vector3(.24,.8,.24)
	flame.direction = Vector3.UP
	flame.spread = 25
	flame.initial_velocity_min = .5; flame.initial_velocity_max = 1.3
	flame.gravity = Vector3(0,1.5,0)
	flame.scale_amount_min = .14; flame.scale_amount_max = .28
	flame.scale_amount_curve = Vfx.curve(1.0,.2)
	flame.color_ramp = Vfx.ramp([0,.25,.7,1],[Color(1,.85,.45,.6),Color(1,.45,.1,.55),Color(.8,.15,.03,.3),Color(.3,.05,.02,0)])
	flame.emitting = true
	var light = OmniLight3D.new()
	light.light_color = Color(1,.45,.15)
	light.light_energy = 2.6
	light.omni_range = 5.0
	light.position = Vector3.UP*1.0
	add_child(light)
	var fade = create_tween()
	fade.tween_property(light,"position",Vector3.UP*.4,COLLAPSED)
	fade.parallel().tween_property(light,"light_energy",1.6,COLLAPSED)
	fade.tween_property(light,"light_energy",.3,FIRE)
	fade.tween_property(light,"light_energy",0.0,SMOULDER)
	var stop = create_tween()
	stop.tween_interval(MELT*.8)
	stop.tween_callback(func(): flame.emitting = false)

# Embers flying up from him as he crumbles, and flakes of ash drifting down.
func embers() -> void:
	var sparks: CPUParticles3D = Vfx.particles(self,60,1.1,false,true)
	sparks.position = Vector3.UP*.8
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(.25,.7,.25)
	sparks.direction = Vector3.UP
	sparks.spread = 40
	sparks.initial_velocity_min = .5; sparks.initial_velocity_max = 1.6
	sparks.gravity = Vector3(0,.8,0)
	sparks.damping_min = .4; sparks.damping_max = .9
	sparks.scale_amount_min = .04; sparks.scale_amount_max = .08
	sparks.color_ramp = Vfx.ramp([0,.5,1],[Color(1,.85,.4,1),Color(1,.45,.1,.8),Color(.6,.12,.03,0)])
	sparks.emitting = true
	var flakes: CPUParticles3D = Vfx.particles(self,50,1.2,false,false)
	flakes.position = Vector3.UP*.9
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flakes.emission_box_extents = Vector3(.25,.7,.25)
	flakes.direction = Vector3(0,-1,0)
	flakes.spread = 70
	flakes.initial_velocity_min = .1; flakes.initial_velocity_max = .5
	flakes.gravity = Vector3(0,-1.8,0)
	flakes.scale_amount_min = .05; flakes.scale_amount_max = .09
	flakes.color_ramp = Vfx.ramp([0,.7,1],[Color(.08,.07,.07,1),Color(.3,.29,.28,.9),Color(.42,.41,.4,0)])
	flakes.emitting = true
	var run = create_tween()
	run.tween_interval(MELT)
	run.tween_callback(func(): flakes.emitting = false)
	run.tween_interval(FIRE)
	run.tween_callback(func(): sparks.emitting = false)

# Once he has fallen, a low fire burns on the heap he has become, dying down.
func floor_fire() -> void:
	var fire: CPUParticles3D = Vfx.particles(self,40,.55,false,true)
	fire.position = Vector3.UP*.1
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = .38
	fire.direction = Vector3.UP
	fire.spread = 15
	fire.initial_velocity_min = .6; fire.initial_velocity_max = 1.2
	fire.gravity = Vector3(0,1.2,0)
	fire.scale_amount_min = .14; fire.scale_amount_max = .28
	fire.scale_amount_curve = Vfx.curve(1.0,.1)
	fire.color_ramp = Vfx.ramp([0,.2,.6,1],[Color(1,.8,.35,.5),Color(1,.42,.08,.55),Color(.85,.15,.03,.3),Color(.3,.04,.02,0)])
	var run = create_tween()
	run.tween_interval(MELT*.5)
	run.tween_callback(func(): fire.emitting = true)
	run.tween_interval(MELT*.5+FIRE)
	run.tween_callback(func(): fire.emitting = false)

# Grey smoke rising off him in a column as he burns, thinning away.
func smoke() -> void:
	var puff = CPUParticles3D.new()
	puff.mesh = Vfx.smoke_quad()
	puff.amount = 30
	puff.lifetime = 2.0
	puff.local_coords = false
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.position = Vector3.UP*.9
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = .3
	puff.direction = Vector3.UP
	puff.spread = 10
	puff.gravity = Vector3(0,.6,0)
	puff.initial_velocity_min = .5; puff.initial_velocity_max = 1.0
	puff.angular_velocity_min = -30; puff.angular_velocity_max = 30
	puff.scale_amount_min = .4; puff.scale_amount_max = .65
	puff.scale_amount_curve = Vfx.curve(.5,2.4)
	puff.color_ramp = Vfx.ramp([0,.15,.6,1],[Color(.2,.19,.19,0),Color(.32,.31,.3,.65),Color(.42,.41,.4,.35),Color(.5,.49,.48,0)])
	add_child(puff)
	puff.emitting = true
	var run = create_tween()
	run.tween_property(puff,"position",Vector3.UP*.3,COLLAPSED)
	run.tween_interval(FIRE)
	run.tween_callback(func(): puff.emitting = false)

# The drift of ash: a flattened half-ball, its rim pushed out and in, its
# top heaped and dimpled, by noise.
static var drift_shape: ArrayMesh
static func drift_mesh() -> ArrayMesh:
	if drift_shape != null: return drift_shape
	var sphere = SphereMesh.new()
	sphere.radius = .55
	sphere.height = 1.1
	sphere.radial_segments = 48
	sphere.rings = 20
	var arrays: Array = sphere.get_mesh_arrays()
	var lumps = FastNoiseLite.new()
	lumps.seed = 3
	lumps.frequency = 1.4
	lumps.fractal_octaves = 3
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in points.size():
		var p: Vector3 = points[k]
		var flat = Vector2(p.x,p.z)
		var round_way: Vector2 = flat.normalized() if flat.length() > .001 else Vector2.ZERO
		var spread: float = 1.0+.22*lumps.get_noise_2dv(round_way*.9)+.08*lumps.get_noise_2dv(flat*3.0)
		var height: float = maxf(p.y,0.0)*.32*(1.0+.5*lumps.get_noise_2dv(flat*4.0+Vector2(7,7)))
		points[k] = Vector3(p.x*spread,height,p.z*spread)
	arrays[Mesh.ARRAY_VERTEX] = points
	var tool = SurfaceTool.new()
	tool.create_from_arrays(arrays)
	tool.generate_normals()
	drift_shape = tool.commit()
	return drift_shape

# The heap of ash he leaves: a low drift, dark and glowing with embers as it
# gathers under him, the glow going out of it.
func heap() -> void:
	var pile = Node3D.new()
	pile.scale = Vector3.ONE*.01
	add_child(pile)
	var ash = StandardMaterial3D.new()
	ash.albedo_color = Color(.27,.27,.28)
	var grain = NoiseTexture2D.new()
	grain.width = 128; grain.height = 128
	grain.seamless = true
	grain.noise = FastNoiseLite.new()
	grain.noise.frequency = .09
	grain.color_ramp = Vfx.ramp([0,.55,1],[Color(.25,.24,.24),Color(.7,.69,.68),Color(1.3,1.3,1.3)])
	ash.albedo_texture = grain
	ash.uv1_triplanar = true
	ash.uv1_scale = Vector3.ONE*2.5
	ash.roughness = 1.0
	# Still hot as it gathers, a dull red glow through it, cooling (the
	# embers' sparks are the glowing motes over it).
	ash.emission_enabled = true
	ash.emission = Color(.55,.12,.03)
	ash.emission_energy_multiplier = .9
	# (A low drift, not a mound: one heap, highest where he stood, its edge
	# ragged where it thins out over the floor.)
	var drift = MeshInstance3D.new()
	drift.mesh = drift_mesh()
	drift.material_override = ash
	pile.add_child(drift)
	var glowing: CPUParticles3D = Vfx.particles(self,14,.9,false,true)
	glowing.position = Vector3.UP*.08
	glowing.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glowing.emission_sphere_radius = .35
	glowing.direction = Vector3.UP
	glowing.spread = 30
	glowing.initial_velocity_min = .05; glowing.initial_velocity_max = .25
	glowing.gravity = Vector3.ZERO
	glowing.scale_amount_min = .03; glowing.scale_amount_max = .06
	glowing.color_ramp = Vfx.ramp([0,.4,1],[Color(1,.6,.2,0),Color(1,.45,.1,.9),Color(.6,.1,.02,0)])
	var grow = create_tween()
	grow.tween_interval(HEAP.x)
	grow.tween_callback(func(): glowing.emitting = true)
	grow.tween_property(pile,"scale",Vector3.ONE,HEAP.y-HEAP.x).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow.tween_property(ash,"emission_energy_multiplier",0.0,1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow.tween_callback(func(): glowing.emitting = false)
