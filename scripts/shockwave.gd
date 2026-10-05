extends Node3D
## The shockwave of a blow on the ground (Leap's landing, Thunder Slam,
## Shockwave): everything in the blow goes into the ground at once. A flash
## where it lands; the floor cracked about it, the cracks glowing and dying
## away (blue with the blade's charge for Thunder Slam: `plasma`); a column of
## dust thrown straight up; and one front of pressed air racing out across
## the whole area the blow reaches, like a sonic boom: a hard pale edge over
## the ground with a low wall of haze standing on it, all round for the leap
## and across the arc ahead for the slam, quick at first and slowing as it
## thins to nothing at the blow's reach (assets/shaders/shockwave.gdshader).
const Vfx = preload("res://scripts/vfx.gd")
# How long the front takes to cross the area, and the cracks to die.
const SWEEP = .55
const CRACKS = 1.3
# The front's wall of haze: how high it stands as it sets out.
const WALL = 1.1
const DUST = Color(.93,.9,.84,.85)
# How far round past either side of a slice's arc the ground is drawn, for its
# cracks to run on out past the arc's edge, each stopping where it will.
const SPILL = 30.0
const CHARGE = Color(.45,.72,1.0)
const EMBER = Color(1.0,.62,.3)
var age = 0.0
var life = 1.0
var reach = 1.0
var ground: MeshInstance3D
var wall: MeshInstance3D
var flash: OmniLight3D
var plasma = false

# `plasma` (Thunder Slam): the blade's charge is driven into the ground with
# the blow, and shows in the cracks and the flash.
static func make(at: Vector3, reach: float, direction: Vector3 = Vector3.ZERO, degrees: float = 360.0, plasma: bool = false) -> Node3D:
	var node = new()
	node.position = at+Vector3.UP*.04
	node.reach = reach
	node.plasma = plasma
	node.life = maxf(SWEEP,CRACKS)
	var way: Vector3 = direction.normalized() if direction.length() > .01 else Vector3.FORWARD
	# (The slice is built about +Z and turned to face the blow's way.)
	node.rotation.y = atan2(way.x,way.z)
	var half = deg_to_rad(degrees*.5)
	var steps = maxi(12,int(96*degrees/360.0))
	var glow: Color = CHARGE if plasma else EMBER
	# The ground under the blow, out to its reach: rings of a slice, drawn
	# SPILL degrees wider either side (UV.y still 0 to 1 across the arc
	# itself, beyond it below 0 and past 1) for the cracks alone.
	var spill = deg_to_rad(SPILL) if degrees < 360.0 else 0.0
	var span = steps+int(ceil(steps*spill/maxf(half,.01)))
	var disc = ImmediateMesh.new()
	var rings = 28
	for r in rings:
		disc.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for s in span+1:
			var angle = lerpf(-half-spill,half+spill,float(s)/span)
			for edge in [r,r+1]:
				var out = float(edge)/rings
				disc.surface_set_uv(Vector2(out,(angle+half)/(2.0*half)))
				disc.surface_add_vertex(Vector3(sin(angle),0,cos(angle))*out*reach)
		disc.surface_end()
	node.ground = sheet(disc,false,glow)
	node.ground.material_override.set_shader_parameter("crack_reach",clampf((3.2 if plasma else 2.2)/reach,.12,.6))
	node.ground.material_override.set_shader_parameter("reach",reach)
	node.ground.material_override.set_shader_parameter("arc",2.0*half)
	node.add_child(node.ground)
	# The wall standing on the front: a strip a metre across, widened to the
	# front's distance as it runs out.
	var strip = ImmediateMesh.new()
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s in steps+1:
		var angle = lerpf(-half,half,float(s)/steps)
		for up in [0.0,1.0]:
			strip.surface_set_uv(Vector2(up,float(s)/steps))
			# (Leaning out over the way it goes, as a wave's crest does.)
			strip.surface_add_vertex(Vector3(sin(angle),up,cos(angle))*Vector3(1.0+.1*up,1,1.0+.1*up))
	strip.surface_end()
	node.wall = sheet(strip,true,glow)
	node.add_child(node.wall)
	# The flash of it, and the dust thrown straight up from where it landed.
	node.flash = OmniLight3D.new()
	node.flash.light_color = Color(.7,.85,1.0) if plasma else Color(1.0,.85,.6)
	node.flash.omni_range = 7.0
	node.flash.position = (way*.4 if degrees < 360.0 else Vector3.ZERO)+Vector3.UP*.6
	node.flash.shadow_enabled = false
	node.add_child(node.flash)
	var column = Vfx.particles(node,26,.7,true,false)
	column.mesh.size = Vector2.ONE
	column.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	column.emission_sphere_radius = .35
	column.direction = Vector3.UP
	column.spread = 28
	column.initial_velocity_min = 3.5
	column.initial_velocity_max = 8.0
	column.damping_min = 7.0
	column.damping_max = 11.0
	column.gravity = Vector3(0,-1.5,0)
	column.scale_amount_min = .5
	column.scale_amount_max = 1.2
	column.scale_amount_curve = Vfx.curve(.5,1.3)
	column.color_ramp = Vfx.ramp([0.0,.12,1.0],[Color(.7,.62,.5,0),Color(.7,.62,.5,.5),Color(.62,.56,.48,0)])
	column.explosiveness = .96
	column.emitting = true
	node.show_front()
	return node

static func sheet(mesh: Mesh, standing: bool, glow: Color) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/shockwave.gdshader")
	material.set_shader_parameter("wall",standing)
	material.set_shader_parameter("tint",DUST)
	material.set_shader_parameter("crack_glow",Vector3(glow.r,glow.g,glow.b))
	m.material_override = material
	return m

# How far out the front is (a share of the reach): away fast, slowing as it goes.
func front() -> float:
	return spread(age)

# How far out the front is, `seconds` after the blow, of the whole reach.
static func spread(seconds: float) -> float:
	var u = clampf(seconds/SWEEP,0.0,1.0)
	return 1.0-pow(1.0-u,2.6)

func show_front() -> void:
	var out = front()
	var u = clampf(age/SWEEP,0.0,1.0)
	# It thins as it spreads, and is gone as it reaches the edge.
	var strength = (1.0-smoothstep(.55,1.0,u))*smoothstep(0.0,.06,u)
	ground.material_override.set_shader_parameter("front",out)
	ground.material_override.set_shader_parameter("strength",strength)
	# The cracks flare as the blow lands and die away after it.
	var cracked = clampf(age/CRACKS,0.0,1.0)
	ground.material_override.set_shader_parameter("crack_strength",(1.0 if plasma else .55)*pow(1.0-cracked,1.6))
	wall.scale = Vector3(maxf(.05,out*reach),WALL*(1.0-.6*u),maxf(.05,out*reach))
	wall.material_override.set_shader_parameter("strength",strength)
	flash.light_energy = (5.0 if plasma else 3.5)*pow(maxf(0.0,1.0-age/.22),2.0)
	flash.visible = age < .22

func tick(dt: float) -> bool:
	age += dt
	show_front()
	return age >= life+.1
