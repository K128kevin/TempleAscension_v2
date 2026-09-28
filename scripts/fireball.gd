extends Node3D
## The Oracle's fire spell: a lobbed fireball that bursts where the ground
## telegraph was drawn. Advanced by Game on the combat clock; damage lands on
## impact through Game.area_damage. Every visible piece is a billboard, particle
## or light; no mesh geometry is generated.
const SHADER = preload("res://assets/shaders/fireball.gdshader")
const Art = preload("res://scripts/assets.gd")
const EXPLOSION_TIME = .75
const LIFETIME_AFTER_IMPACT = 4.0
static var soft_dot: GradientTexture2D

var game
var origin = Vector3.ZERO
var target = Vector3.ZERO
var radius = 2.2
var damage = 0.0
var flight_time = .6
var arc = 1.5
var age = 0.0
var exploded = false
var since_impact = 0.0

var core: MeshInstance3D
var core_material: ShaderMaterial
var carry_light: OmniLight3D
var trail: CPUParticles3D
var burst: MeshInstance3D
var burst_material: ShaderMaterial
var flash: OmniLight3D
var sparks: CPUParticles3D
var smoke: CPUParticles3D
var shock: Sprite3D
var scorch: Sprite3D

func setup(owner_game, from: Vector3, to: Vector3, blast_radius: float, blast_damage: float, seconds: float) -> void:
	game = owner_game
	origin = from
	target = to+Vector3.UP*.35
	radius = blast_radius
	damage = blast_damage
	flight_time = seconds
	arc = 1.1+from.distance_to(to)*.08
	name = "OracleFireball"
	core_material = fire_material(0.0)
	core = billboard(core_material,.75)
	carry_light = OmniLight3D.new()
	carry_light.light_color = Color(1,.52,.18)
	carry_light.light_energy = 1.8
	carry_light.omni_range = 4.5
	carry_light.omni_attenuation = 1.4
	add_child(carry_light)
	trail = particles(48,.4,false,true)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = .12
	trail.direction = Vector3.UP
	trail.spread = 180
	trail.initial_velocity_min = .2
	trail.initial_velocity_max = .7
	trail.gravity = Vector3(0,1.4,0)
	trail.scale_amount_min = .25
	trail.scale_amount_max = .45
	trail.scale_amount_curve = shrink_curve()
	trail.color_ramp = ramp([0,.25,.6,1],[Color(1,.62,.22,.55),Color(1,.4,.08,.45),Color(.55,.12,.03,.25),Color(.1,.08,.07,0)])
	position = origin
	game.sound.play("dash-whoosh",-17)

func fire_material(burst_amount: float) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("burst",burst_amount)
	m.set_shader_parameter("seed",fposmod(origin.x*3.17+origin.z*1.91,50.0))
	return m

func billboard(material: ShaderMaterial, size: float) -> MeshInstance3D:
	var quad = QuadMesh.new()
	var node = MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3.ONE*size
	add_child(node)
	return node

func particles(count: int, lifetime: float, one_shot: bool, additive: bool) -> CPUParticles3D:
	if soft_dot == null:
		soft_dot = GradientTexture2D.new()
		soft_dot.width = 64; soft_dot.height = 64
		soft_dot.fill = GradientTexture2D.FILL_RADIAL
		soft_dot.fill_from = Vector2(.5,.5); soft_dot.fill_to = Vector2(1,.5)
		soft_dot.gradient = Gradient.new()
		soft_dot.gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0)])
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_texture = soft_dot
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad = QuadMesh.new()
	quad.material = material
	var p = CPUParticles3D.new()
	p.mesh = quad
	p.amount = count
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func shrink_curve() -> Curve:
	var c = Curve.new()
	c.add_point(Vector2(0,1)); c.add_point(Vector2(1,0))
	return c

func ramp(offsets: Array, colors: Array) -> Gradient:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

# Returns false once every part of the effect has finished.
func tick(dt: float) -> bool:
	age += dt
	if not exploded:
		var u = minf(1.0,age/flight_time)
		position = origin.lerp(target,u)+Vector3.UP*arc*4.0*u*(1.0-u)
		core_material.set_shader_parameter("flame_time",age)
		carry_light.light_energy = 1.8*(1.0+sin(age*23.0)*.08)
		visible = game.world.can_see(position)
		if u>=1.0: explode()
		return true
	since_impact += dt
	var t = since_impact
	var p = minf(1.0,t/EXPLOSION_TIME)
	burst_material.set_shader_parameter("flame_time",age)
	burst_material.set_shader_parameter("progress",p)
	burst.scale = Vector3.ONE*radius*lerpf(.8,2.3,1.0-pow(1.0-p,3.0))
	burst.visible = p<1.0
	flash.light_energy = 7.0*exp(-t*7.0)
	var ring = minf(1.0,t/.35)
	shock.scale = Vector3.ONE*lerpf(.35,1.25,1.0-pow(1.0-ring,2.0))
	shock.modulate.a = .9*(1.0-ring)
	scorch.modulate.a = .6*clampf((LIFETIME_AFTER_IMPACT-t)/1.5,0.0,1.0)*minf(1.0,t*8.0)
	visible = game.world.can_see(target)
	return t<LIFETIME_AFTER_IMPACT

func _process(_delta: float) -> void:
	# Particles run on the engine clock; hold them while combat is paused.
	var running = game!=null and game.mode=="playing"
	for p in [trail,sparks,smoke]:
		if is_instance_valid(p): p.speed_scale = 1.0 if running else 0.0

func explode() -> void:
	exploded = true
	position = target
	core.visible = false
	carry_light.visible = false
	trail.emitting = false
	game.area_damage(target,radius,damage,false)
	game.sound.play("whirl-impact",-9)
	burst_material = fire_material(1.0)
	burst = billboard(burst_material,radius*.55)
	flash = OmniLight3D.new()
	flash.light_color = Color(1,.55,.2)
	flash.omni_range = radius*3.2
	flash.omni_attenuation = 1.3
	flash.position = Vector3.UP*.7
	add_child(flash)
	sparks = particles(40,.75,true,true)
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 75
	sparks.initial_velocity_min = 3.5
	sparks.initial_velocity_max = 7.5
	sparks.gravity = Vector3(0,-9.0,0)
	sparks.scale_amount_min = .07
	sparks.scale_amount_max = .13
	sparks.color_ramp = ramp([0,.4,1],[Color(1,.95,.6,1),Color(1,.5,.1,.9),Color(.7,.15,.03,0)])
	sparks.emitting = true
	smoke = particles(16,1.7,true,false)
	smoke.explosiveness = .85
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = radius*.35
	smoke.direction = Vector3.UP
	smoke.spread = 180
	smoke.initial_velocity_min = .5
	smoke.initial_velocity_max = 1.3
	smoke.gravity = Vector3(0,1.1,0)
	smoke.damping_min = .8
	smoke.damping_max = 1.2
	smoke.scale_amount_min = .9
	smoke.scale_amount_max = 1.5
	var grow = Curve.new(); grow.add_point(Vector2(0,.45)); grow.add_point(Vector2(1,1.6))
	smoke.scale_amount_curve = grow
	smoke.color_ramp = ramp([0,.15,1],[Color(.22,.18,.15,0),Color(.16,.14,.12,.6),Color(.09,.08,.08,0)])
	smoke.emitting = true
	# Ground shockwave from the existing seal VFX, and a fading scorch mark.
	shock = Art.seal(radius*2.2,Color(1,.6,.2,.9))
	shock.position = Vector3.DOWN*.3
	add_child(shock)
	scorch = Sprite3D.new()
	var dark = GradientTexture2D.new()
	dark.width = 128; dark.height = 128
	dark.fill = GradientTexture2D.FILL_RADIAL
	dark.fill_from = Vector2(.5,.5); dark.fill_to = Vector2(1,.5)
	dark.gradient = ramp([0,.55,1],[Color(.05,.03,.02,.85),Color(.07,.04,.03,.5),Color(.08,.05,.03,0)])
	scorch.texture = dark
	scorch.pixel_size = radius*1.7/128.0
	scorch.rotation.x = -PI/2
	scorch.position = Vector3.DOWN*.32
	scorch.shaded = false
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scorch.modulate.a = 0
	add_child(scorch)
