extends RefCounted
## Shared particle helpers for spell effects. Particles are camera-facing soft
## dots; nothing here builds mesh geometry.
static var soft_dot: GradientTexture2D
# Additive dots draw with their own shader (assets/shaders/particle_glow.gdshader),
# one material for all.
static var glow_material: ShaderMaterial

static func particles(parent: Node3D, count: int, lifetime: float, one_shot: bool, additive: bool) -> CPUParticles3D:
	if soft_dot == null:
		soft_dot = GradientTexture2D.new()
		soft_dot.width = 64; soft_dot.height = 64
		soft_dot.fill = GradientTexture2D.FILL_RADIAL
		soft_dot.fill_from = Vector2(.5,.5); soft_dot.fill_to = Vector2(1,.5)
		soft_dot.gradient = Gradient.new()
		soft_dot.gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0)])
	if glow_material == null:
		glow_material = ShaderMaterial.new()
		glow_material.shader = preload("res://assets/shaders/particle_glow.gdshader")
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The particle billboard mode ignores each particle's scale in the
	# Compatibility renderer; a regular billboard that keeps scale honors it.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_texture = soft_dot
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad = QuadMesh.new()
	quad.material = glow_material if additive else material
	var p = CPUParticles3D.new()
	p.mesh = quad
	p.amount = count
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

static func ramp(offsets: Array, colors: Array) -> Gradient:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

static func curve(start: float, finish: float) -> Curve:
	var c = Curve.new()
	c.max_value = maxf(1.0,maxf(start,finish))
	c.add_point(Vector2(0,start)); c.add_point(Vector2(1,finish))
	return c

# Blood from a wound at `at` (in `parent`'s space), thrown `away` from the
# blow: drops that fly drawn out into streaks (assets/shaders/blood_drop.gdshader)
# out of a brief red mist, and spatter the floor (at height `ground`) where
# they come down, to lie there a few seconds (blood_splat.gdshader). The drops'
# emitter is returned; the mist and the splats are not `parent`'s own emitters.
const BLOOD_SPREAD = 60.0
const SPLAT_LIES = 5.0
const SPLAT_DRIES = 1.5
static var drop_material: ShaderMaterial
static var splat_shader: Shader
static var splat_mesh: QuadMesh
static func blood(parent: Node3D, at: Vector3, away: Vector3, heavy: bool = false, ground: float = 0.0) -> CPUParticles3D:
	away.y = 0
	var way: Vector3 = (away.normalized()+Vector3.UP*.5).normalized() if away.length_squared() > .0001 else Vector3.UP
	var fastest: float = 6.0 if heavy else 4.6
	if drop_material == null:
		drop_material = ShaderMaterial.new()
		drop_material.shader = preload("res://assets/shaders/blood_drop.gdshader")
	var p = particles(parent,84 if heavy else 44,.85,true,false)
	p.mesh = p.mesh.duplicate()
	p.mesh.material = drop_material
	p.position = at
	p.explosiveness = .92
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = .1
	p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY,true)
	p.direction = way
	p.spread = BLOOD_SPREAD
	p.initial_velocity_min = 1.2; p.initial_velocity_max = fastest
	p.gravity = Vector3(0,-9.8,0)
	p.scale_amount_min = .05; p.scale_amount_max = .2 if heavy else .16
	p.scale_amount_curve = curve(1.0,.6)
	p.color_ramp = ramp([0,.8,1],[Color(.36,.012,.012,1),Color(.24,.006,.006,1),Color(.2,0,0,0)])
	p.emitting = true
	p.finished.connect(p.queue_free)
	# The fine spray about the wound.
	var mist = particles(p,14 if heavy else 8,.32,true,false)
	mist.explosiveness = .95
	mist.direction = way
	mist.spread = 40
	mist.initial_velocity_min = .6; mist.initial_velocity_max = 2.2
	mist.gravity = Vector3(0,-2.0,0)
	mist.scale_amount_min = .25; mist.scale_amount_max = .5 if heavy else .4
	mist.scale_amount_curve = curve(.5,1.4)
	mist.color_ramp = ramp([0,.25,1],[Color(.3,.01,.01,0),Color(.3,.01,.01,.3),Color(.22,0,0,0)])
	mist.emitting = true
	# Where some of the drops come down.
	if splat_shader == null:
		splat_shader = preload("res://assets/shaders/blood_splat.gdshader")
		splat_mesh = QuadMesh.new()
		splat_mesh.orientation = PlaneMesh.FACE_Y
	var floor = Node3D.new()
	floor.name = "BloodSplats"
	parent.add_child(floor)
	var last = 0.0
	for i in 12 if heavy else 6:
		var velocity: Vector3 = (way+Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*.7).normalized()*randf_range(1.2,fastest)
		var fall: float = (velocity.y+sqrt(velocity.y*velocity.y+19.6*maxf(0.0,at.y-ground)))/9.8
		var splat = MeshInstance3D.new()
		splat.mesh = splat_mesh
		splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var finish = ShaderMaterial.new()
		finish.shader = splat_shader
		finish.set_shader_parameter("seed",randf()*40.0)
		finish.set_shader_parameter("fade",0.0)
		splat.material_override = finish
		# Drawn out the way the drop was going as it struck.
		var size: float = randf_range(.14,.34 if heavy else .28)
		splat.scale = Vector3(size,1.0,size*randf_range(1.2,1.9))
		splat.rotation.y = atan2(velocity.x,velocity.z)
		splat.position = Vector3(at.x+velocity.x*fall,ground+.012+.001*i,at.z+velocity.z*fall)
		floor.add_child(splat)
		var life = floor.create_tween()
		life.tween_interval(fall)
		life.tween_property(finish,"shader_parameter/fade",1.0,.06)
		life.tween_interval(SPLAT_LIES)
		life.tween_property(finish,"shader_parameter/fade",0.0,SPLAT_DRIES)
		last = maxf(last,fall)
	floor.create_tween().tween_callback(floor.queue_free).set_delay(last+.06+SPLAT_LIES+SPLAT_DRIES+.1)
	return p

# Particles run on the engine clock; hold them while combat is paused.
static func hold_when_paused(game, emitters: Array) -> void:
	var running = game!=null and game.mode=="playing"
	for p in emitters:
		if is_instance_valid(p): p.speed_scale = 1.0 if running else 0.0

const SOFT_GLOW = preload("res://assets/shaders/soft_glow.gdshader")
# A soft glow facing the eye, added onto what is behind it
# (assets/shaders/soft_glow.gdshader): `size` metres across and tall, as its
# scale (change the scale to change it); its "strength" fades it.
static func soft_glow(color: Color, size: Vector2) -> MeshInstance3D:
	var material = ShaderMaterial.new()
	material.shader = SOFT_GLOW
	material.set_shader_parameter("tint",color)
	var glow = MeshInstance3D.new()
	glow.mesh = QuadMesh.new()
	glow.material_override = material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.scale = Vector3(size.x,size.y,1.0)
	return glow
