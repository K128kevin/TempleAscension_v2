extends Node3D
## War Cry's ring: the red glow gathered on the hero's blade
## (scripts/blade_glow.gd) bursting from it as he shouts and racing out over
## the ground as a ring of red light, with a low wall of red haze on its
## front, across the whole area the cry reaches. It runs out as fast as a
## blow's shockwave does (scripts/shockwave.gd): away quickly, slowing as it
## nears the edge, where it fades, the red wash it left behind dying after it
## (assets/shaders/war_cry.gdshader). A red flash lights the hero as it
## bursts.
const Shockwave = preload("res://scripts/shockwave.gd")
const GLOW = Color(1.0,.12,.06)
# How high the wall of haze stands as it sets out.
const WALL = .8
# How long the red wash lingers after the front has reached the edge.
const LINGER = .35
var age = 0.0
var reach = 1.0
var ground: MeshInstance3D
var wall: MeshInstance3D
var flash: OmniLight3D

static func make(at: Vector3, reach: float) -> Node3D:
	var node = new()
	node.position = at+Vector3.UP*.05
	node.reach = reach
	var steps = 96
	# The ground the cry covers: rings of a disc out to its reach.
	var disc = ImmediateMesh.new()
	var rings = 40
	for r in rings:
		disc.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for s in steps+1:
			var angle = TAU*s/steps
			for edge in [r,r+1]:
				var out = float(edge)/rings
				disc.surface_set_uv(Vector2(out,float(s)/steps))
				disc.surface_add_vertex(Vector3(sin(angle),0,cos(angle))*out*reach)
		disc.surface_end()
	node.ground = sheet(disc,false)
	node.add_child(node.ground)
	# The wall on the front: a ring a metre across, widened to the front.
	var strip = ImmediateMesh.new()
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s in steps+1:
		var angle = TAU*s/steps
		for up in [0.0,1.0]:
			strip.surface_set_uv(Vector2(up,float(s)/steps))
			strip.surface_add_vertex(Vector3(sin(angle),up,cos(angle))*Vector3(1.0+.08*up,1,1.0+.08*up))
	strip.surface_end()
	node.wall = sheet(strip,true)
	node.add_child(node.wall)
	node.flash = OmniLight3D.new()
	node.flash.light_color = GLOW
	node.flash.omni_range = 6.0
	node.flash.position = Vector3.UP*1.2
	node.flash.shadow_enabled = false
	node.add_child(node.flash)
	node.show_front()
	return node

static func sheet(mesh: Mesh, standing: bool) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/war_cry.gdshader")
	material.set_shader_parameter("wall",standing)
	m.material_override = material
	return m

# How far out the front is (a share of the reach), as a shockwave's runs.
func front() -> float:
	var u = clampf(age/Shockwave.SWEEP,0.0,1.0)
	return 1.0-pow(1.0-u,2.6)

func show_front() -> void:
	var out = front()
	var u = clampf(age/Shockwave.SWEEP,0.0,1.0)
	# Bright from the start, fading as it nears the edge and after it.
	var strength = smoothstep(0.0,.04,u)*(1.0-smoothstep(Shockwave.SWEEP*.8,Shockwave.SWEEP+LINGER,age))
	ground.material_override.set_shader_parameter("front",out)
	ground.material_override.set_shader_parameter("strength",strength)
	# (The band keeps about the same width on the ground however far it reaches.)
	ground.material_override.set_shader_parameter("band",clampf(.45/reach,.03,.12))
	wall.scale = Vector3(maxf(.05,out*reach),WALL*(1.0-.5*u),maxf(.05,out*reach))
	wall.material_override.set_shader_parameter("strength",strength*(1.0-smoothstep(.7,1.0,u)))
	wall.visible = u < 1.0
	flash.light_energy = 4.0*pow(maxf(0.0,1.0-age/.3),2.0)
	flash.visible = age < .3

func tick(dt: float) -> bool:
	age += dt
	show_front()
	return age >= Shockwave.SWEEP+LINGER+.05
