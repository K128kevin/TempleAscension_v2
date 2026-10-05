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

# A spray of blood from a wound at `at` (in `parent`'s space), thrown `away`
# from the blow: dark drops that arc, fall and are gone.
static func blood(parent: Node3D, at: Vector3, away: Vector3, heavy: bool = false) -> CPUParticles3D:
	away.y = 0
	var p = particles(parent,56 if heavy else 30,.65,true,false)
	p.position = at
	p.explosiveness = .92
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = .1
	p.direction = (away.normalized()+Vector3.UP*.5).normalized() if away.length_squared() > .0001 else Vector3.UP
	p.spread = 60
	p.initial_velocity_min = 1.2; p.initial_velocity_max = 6.0 if heavy else 4.6
	p.gravity = Vector3(0,-9.8,0)
	p.scale_amount_min = .09; p.scale_amount_max = .3 if heavy else .23
	p.scale_amount_curve = curve(1.0,.55)
	p.color_ramp = ramp([0,.75,1],[Color(.4,.02,.02,.95),Color(.28,.01,.01,.9),Color(.2,0,0,0)])
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

# Particles run on the engine clock; hold them while combat is paused.
static func hold_when_paused(game, emitters: Array) -> void:
	var running = game!=null and game.mode=="playing"
	for p in emitters:
		if is_instance_valid(p): p.speed_scale = 1.0 if running else 0.0
