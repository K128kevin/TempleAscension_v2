extends RefCounted
## What the ranger's skills look like (scripts/skills.gd makes these and
## frees them when their moment is over): what his arrows carry in flight,
## Volley's arrows, lightning leaping between enemies, thrown sand, smoke,
## Frenzy's heat about him and Power Shot gathering at the bow. Soft particles
## and thin ribbons of light; nothing here does any damage.
const Vfx = preload("res://scripts/vfx.gd")
const Art = preload("res://scripts/assets.gd")

# What each kind of arrow trails behind it: [colour, how many, how big].
const TRAILS = {"power":[Color(1,.9,.55,.9),28,.2],"lightning":[Color(.55,.8,1,.95),30,.16],"slow":[Color(.6,.9,1,.8),18,.14],
	"weaken":[Color(.75,.4,1,.85),18,.14],"tranq":[Color(.45,1,.5,.8),16,.12]}

# Dresses one of the hero's arrows for what it carries: a trail of motes, and
# for lightning and the power shot a light of its own.
static func arrow(node: Node3D, kind: String) -> void:
	if not TRAILS.has(kind): return
	var look: Array = TRAILS[kind]
	var trail = Vfx.particles(node,look[1],.3,false,true)
	trail.direction = Vector3.ZERO
	trail.spread = 180
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = .1; trail.initial_velocity_max = .5
	trail.scale_amount_min = look[2]; trail.scale_amount_max = look[2]*1.6
	trail.scale_amount_curve = Vfx.curve(1.0,0.0)
	trail.color = look[0]
	# (The arrow model is scaled to its size; the motes are not to be.)
	trail.scale = Vector3.ONE/node.scale
	trail.emitting = true
	if kind in ["power","lightning"]:
		var glow = OmniLight3D.new()
		glow.light_color = look[0]
		glow.light_energy = 1.6
		glow.omni_range = 3.0
		node.add_child(glow)

# A puff of smoke or dust bursting out at `at`: `size` metres across.
static func burst(parent: Node3D, at: Vector3, color: Color, size: float, count: int) -> Node3D:
	var puff = Vfx.particles(parent,count,.9,true,false)
	puff.position = at
	puff.explosiveness = .95
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = size*.2
	puff.direction = Vector3.UP
	puff.spread = 180
	puff.gravity = Vector3(0,.4,0)
	puff.initial_velocity_min = size*.4; puff.initial_velocity_max = size*1.1
	puff.damping_min = 2.0; puff.damping_max = 3.0
	puff.scale_amount_min = size*.35; puff.scale_amount_max = size*.6
	puff.scale_amount_curve = Vfx.curve(.6,1.5)
	puff.color_ramp = Vfx.ramp([0,.15,1],[Color(color.r,color.g,color.b,0),color,Color(color.r,color.g,color.b,0)])
	puff.emitting = true
	return puff

# A handful of sand flung from `at` along `way`, spreading as it goes.
static func sand(parent: Node3D, at: Vector3, way: Vector3) -> Node3D:
	var grit = Vfx.particles(parent,60,.55,true,false)
	grit.position = at
	grit.explosiveness = .9
	grit.direction = way+Vector3.UP*.15
	grit.spread = 22
	grit.gravity = Vector3(0,-3.0,0)
	grit.initial_velocity_min = 4.0; grit.initial_velocity_max = 7.5
	grit.damping_min = 3.0; grit.damping_max = 5.0
	grit.scale_amount_min = .08; grit.scale_amount_max = .22
	grit.color_ramp = Vfx.ramp([0,.1,1],[Color(.86,.74,.5,0),Color(.86,.74,.5,.9),Color(.8,.7,.5,0)])
	grit.emitting = true
	return grit

# Lightning from `a` to `b`: a jagged ribbon of light, drawn twice at right
# angles so it shows from any side, and a flash where it lands.
static func bolt(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var node = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(.7,.88,1,.95)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var along: Vector3 = b-a
	var side: Vector3 = along.cross(Vector3.UP).normalized() if absf(along.normalized().dot(Vector3.UP)) < .95 else Vector3.RIGHT
	var points: Array = []
	var pieces = maxi(4,int(along.length()/.7))
	for i in pieces+1:
		var u = float(i)/pieces
		var wander = (side*randf_range(-.28,.28)+Vector3.UP*randf_range(-.28,.28))*sin(u*PI)
		points.append(a+along*u+wander)
	for across in [side,Vector3.UP]:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP,material)
		for point in points:
			mesh.surface_add_vertex(point-across*.05)
			mesh.surface_add_vertex(point+across*.05)
		mesh.surface_end()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var flash = OmniLight3D.new()
	flash.light_color = Color(.6,.8,1)
	flash.light_energy = 2.5
	flash.omni_range = 4.0
	flash.position = b
	node.add_child(flash)
	return node

# Frenzy: embers rising about him while it lasts.
static func aura(body: Node3D) -> Node3D:
	var heat = Vfx.particles(body,26,.8,false,true)
	heat.position = Vector3.UP*.9
	heat.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	heat.emission_sphere_radius = .45
	heat.direction = Vector3.UP
	heat.spread = 25
	heat.gravity = Vector3(0,1.2,0)
	heat.initial_velocity_min = .5; heat.initial_velocity_max = 1.4
	heat.scale_amount_min = .1; heat.scale_amount_max = .22
	heat.scale_amount_curve = Vfx.curve(1.0,0.0)
	heat.color = Color(1,.35,.12,.85)
	heat.emitting = true
	return heat

# Power Shot gathering at the bow through `seconds` of aiming: motes drawn in
# to the arrow, and a light growing there.
static func charge(body: Node3D, seconds: float) -> Node3D:
	var gather = Vfx.particles(body,22,.5,false,true)
	gather.position = Vector3(0,1.45,.75)
	gather.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	gather.emission_sphere_radius = .7
	gather.local_coords = true
	gather.gravity = Vector3.ZERO
	gather.radial_accel_min = -9.0; gather.radial_accel_max = -6.0
	gather.scale_amount_min = .07; gather.scale_amount_max = .16
	gather.color = Color(1,.9,.55,.9)
	gather.emitting = true
	var glow = OmniLight3D.new()
	glow.light_color = Color(1,.85,.5)
	glow.light_energy = 0.0
	glow.omni_range = 3.5
	gather.add_child(glow)
	glow.create_tween().tween_property(glow,"light_energy",2.2,maxf(.1,seconds))
	return gather

# One of Volley's arrows: coming down (the skill moves it), or leaving the
# bow up into the air, the `index`th of the flight.
static func falling(parent: Node3D) -> Node3D:
	var shaft = Art.model("arrow",Art.ARROW_SIZE)
	parent.add_child(shaft)
	shaft.visible = false
	return shaft

static func rising(parent: Node3D, from: Vector3, way: Vector3, index: int) -> Node3D:
	var shaft = Art.model("arrow",Art.ARROW_SIZE)
	parent.add_child(shaft)
	shaft.position = from
	var aim: Vector3 = (way.rotated(Vector3.UP,(index%5-2)*.07)+Vector3.UP*1.6).normalized()
	shaft.look_at(from-aim,Vector3.FORWARD)
	shaft.create_tween().tween_property(shaft,"position",from+aim*14.0,.3)
	return shaft
