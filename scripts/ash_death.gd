extends Node3D
## The hero burned to ash by the basement's lasers (Game.kill_player), after
## the death in the 2D game Boulders: he flares up in flame and chars black
## (CHAR_TIME), then crumbles from the head down (CRUMBLE, from and to,
## seconds in) in glowing flakes, embers flying up and black smoke with them,
## into a heap of grey ash that smoulders on the floor where he stood
## (assets/shaders/ash_crumble.gdshader). The death screen waits DURATION.
const Vfx = preload("res://scripts/vfx.gd")
const DURATION = 2.4
const CHAR_TIME = .45
const CRUMBLE = Vector2(.4,1.8)
const HEIGHT = 2.0
# When the heap of ash gathers (from, to), and how long it smoulders after.
const HEAP = Vector2(.8,1.9)
const SMOULDER = 4.0
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
	var meshes: Array = body.visual.find_children("*","MeshInstance3D",true,false)
	# He chars as the fire takes him,
	var soot = ShaderMaterial.new()
	soot.shader = load("res://assets/shaders/charred.gdshader")
	soot.set_shader_parameter("amount",0.0)
	for mesh in meshes: mesh.material_overlay = soot
	crumble = ShaderMaterial.new()
	crumble.shader = load("res://assets/shaders/ash_crumble.gdshader")
	crumble.set_shader_parameter("ground",global_position.y)
	crumble.set_shader_parameter("height",HEIGHT*body.visual.rig.scale.y)
	crumble.set_shader_parameter("progress",0.0)
	var steps = create_tween()
	steps.tween_method(func(v): soot.set_shader_parameter("amount",v),0.0,1.0,CHAR_TIME)
	# and, charred through, crumbles away.
	steps.tween_callback(func():
		for mesh in meshes:
			if not is_instance_valid(mesh): continue
			mesh.material_overlay = null
			mesh.material_override = crumble)
	var fall = create_tween()
	fall.tween_interval(CRUMBLE.x)
	fall.tween_method(func(v): crumble.set_shader_parameter("progress",v),0.0,1.0,CRUMBLE.y-CRUMBLE.x).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	fall.tween_callback(func(): body.visual.visible = false)
	flare()
	embers()
	smoke()
	heap()

# The flash of the beam taking him: a burst of flame about his body and a hot
# light that dies away.
func flare() -> void:
	var flame: CPUParticles3D = Vfx.particles(self,26,.5,true,true)
	flame.position = Vector3.UP*1.0
	flame.explosiveness = .7
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flame.emission_box_extents = Vector3(.28,.85,.28)
	flame.direction = Vector3.UP
	flame.spread = 35
	flame.initial_velocity_min = .4; flame.initial_velocity_max = 1.4
	flame.gravity = Vector3(0,1.5,0)
	flame.scale_amount_min = .16; flame.scale_amount_max = .32
	flame.scale_amount_curve = Vfx.curve(1.0,.2)
	flame.color_ramp = Vfx.ramp([0,.25,.7,1],[Color(1,.85,.5,.55),Color(1,.5,.12,.5),Color(.8,.18,.04,.25),Color(.3,.05,.02,0)])
	flame.emitting = true
	var light = OmniLight3D.new()
	light.light_color = Color(1,.5,.2)
	light.light_energy = 2.4
	light.omni_range = 5.0
	light.position = Vector3.UP*1.1
	add_child(light)
	var fade = create_tween()
	fade.tween_property(light,"light_energy",1.0,CHAR_TIME)
	fade.tween_property(light,"light_energy",.4,CRUMBLE.y-CHAR_TIME)
	fade.tween_property(light,"light_energy",0.0,SMOULDER)

# Embers flying up from him as he crumbles, and flakes of ash drifting down.
func embers() -> void:
	var sparks: CPUParticles3D = Vfx.particles(self,70,1.3,false,true)
	sparks.position = Vector3.UP*1.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(.25,.8,.25)
	sparks.direction = Vector3.UP
	sparks.spread = 40
	sparks.initial_velocity_min = .5; sparks.initial_velocity_max = 1.6
	sparks.gravity = Vector3(0,.8,0)
	sparks.damping_min = .4; sparks.damping_max = .9
	sparks.scale_amount_min = .04; sparks.scale_amount_max = .09
	sparks.color_ramp = Vfx.ramp([0,.5,1],[Color(1,.85,.4,1),Color(1,.45,.1,.8),Color(.6,.12,.03,0)])
	var flakes: CPUParticles3D = Vfx.particles(self,60,1.6,false,false)
	flakes.position = Vector3.UP*1.0
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flakes.emission_box_extents = Vector3(.25,.8,.25)
	flakes.direction = Vector3(0,-1,0)
	flakes.spread = 70
	flakes.initial_velocity_min = .1; flakes.initial_velocity_max = .5
	flakes.gravity = Vector3(0,-1.6,0)
	flakes.scale_amount_min = .05; flakes.scale_amount_max = .1
	flakes.color_ramp = Vfx.ramp([0,.7,1],[Color(.08,.07,.07,1),Color(.3,.29,.28,.9),Color(.42,.41,.4,0)])
	var run = create_tween()
	run.tween_interval(CRUMBLE.x)
	run.tween_callback(func():
		sparks.emitting = true
		flakes.emitting = true)
	run.tween_interval(CRUMBLE.y-CRUMBLE.x)
	run.tween_callback(func():
		sparks.emitting = false
		flakes.emitting = false)

# Black smoke rolling up off him while he burns, thinning to grey.
func smoke() -> void:
	var puff = CPUParticles3D.new()
	puff.mesh = Vfx.smoke_quad()
	puff.amount = 26
	puff.lifetime = 2.2
	puff.local_coords = false
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.position = Vector3.UP*1.1
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = .35
	puff.direction = Vector3.UP
	puff.spread = 15
	puff.gravity = Vector3(0,.5,0)
	puff.initial_velocity_min = .4; puff.initial_velocity_max = .9
	puff.angular_velocity_min = -30; puff.angular_velocity_max = 30
	puff.scale_amount_min = .45; puff.scale_amount_max = .7
	puff.scale_amount_curve = Vfx.curve(.5,2.4)
	puff.color_ramp = Vfx.ramp([0,.2,.6,1],[Color(.05,.04,.04,0),Color(.08,.07,.07,.75),Color(.25,.24,.23,.4),Color(.4,.39,.38,0)])
	add_child(puff)
	puff.emitting = true
	var run = create_tween()
	run.tween_interval(CRUMBLE.y)
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

# The heap of ash he leaves: low mounds of grey, gathering as he falls, a
# few embers glowing in it until they go out.
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
	grow.tween_interval(SMOULDER)
	grow.tween_callback(func(): glowing.emitting = false)
