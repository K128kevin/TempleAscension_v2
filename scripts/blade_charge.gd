extends Node3D
## Ground Slam's gathering charge on the hero's blade, after the lightning of
## Thunderfury: a pale blue plasma glow sheathing the blade, brightest round
## its lower part, with jagged lightning crackling out from it and back,
## forking as it goes, and a cold light, all as strong as `intensity` (0 to 1),
## which scripts/visual.gd raises as he lifts the sword and drives it down. As
## the blade meets the ground the charge breaks off it, lightning racing out
## over the ground for a moment. Drawn only; nothing about the skill depends
## on it. It is carried on the blade (attach()).

const Vfx = preload("res://scripts/vfx.gd")
const GLOW = Color(.4,.68,1.0)
# Bolts at full strength (fewer below it: a few on the raise, many on the
# slam), and how often they are redrawn, so they flicker and jump.
const BOLTS = 6
const BOLT_EVERY = .045
const BOLT_JOINTS = 14
# How far out from the blade a bolt loops (metres, at full strength).
const BOLT_REACH = .32
# Each bolt is a white-hot core in a wider blue glow.
const CORE = Color(.85,.94,1.0)
const HALO = Color(.3,.58,1.0)
const CORE_WIDTH = .007
const HALO_WIDTH = .036
# The charge breaking off over the ground: how long it crackles, how many
# bolts, and how far they run.
const GROUND_TIME = .3
const GROUND_BOLTS = 7
const GROUND_REACH = 1.6

var glow: CPUParticles3D
var core: CPUParticles3D
var light: OmniLight3D
var bolts: MeshInstance3D
var ground_bolts: MeshInstance3D
var bolt_clock = 0.0
var intensity = 0.0
# The light's share of it: none once the blade is down on the ground, where
# its light flared on the floor and glinted along the joints between tiles.
var lit = 0.0
# The blade, from its lower end to its point, in this node's space.
var inner = Vector3.ZERO
var point = Vector3.ZERO
var ground_left = 0.0
var ground_at = Vector3.ZERO

func _init() -> void:
	name = "BladeCharge"
	# The plasma sheathing the blade.
	glow = Vfx.particles(self,26,.24,false,true)
	glow.local_coords = true
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	glow.direction = Vector3.UP
	glow.spread = 180
	glow.initial_velocity_min = 0.0
	glow.initial_velocity_max = .12
	glow.gravity = Vector3.ZERO
	glow.scale_amount_min = .12
	glow.scale_amount_max = .2
	glow.color_ramp = Vfx.ramp([0,.3,1],[Color(GLOW,0),Color(GLOW,.2),Color(GLOW,0)])
	# Brightest round the lower blade, where the lightning gathers.
	core = Vfx.particles(self,8,.3,false,true)
	core.local_coords = true
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.direction = Vector3.UP
	core.spread = 180
	core.initial_velocity_min = 0.0
	core.initial_velocity_max = .05
	core.gravity = Vector3.ZERO
	core.scale_amount_min = .26
	core.scale_amount_max = .38
	core.color_ramp = Vfx.ramp([0,.35,1],[Color(.75,.9,1,0),Color(.7,.87,1,.22),Color(.5,.75,1,0)])
	light = OmniLight3D.new()
	light.light_color = GLOW
	light.omni_range = 2.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	add_child(light)
	bolts = bolt_mesh()
	add_child(bolts)
	ground_bolts = bolt_mesh()
	ground_bolts.top_level = true
	add_child(ground_bolts)
	show_strength()

func bolt_mesh() -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = ImmediateMesh.new()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	# Added light, its brightness already in the colour (see particle_glow.gdshader).
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.disable_fog = true
	m.material_override = material
	return m

# Carried on the blade itself (`weapon`, whose local Y runs up the blade from
# `from` to `to`), so it is drawn wherever the blade is: placed apart from it,
# a frame behind, it trailed a fast swing. The weapon is scaled unevenly; the
# charge is scaled back, so it is not stretched with it.
func attach(weapon: Node3D, from: float, to: float) -> void:
	if get_parent() != weapon:
		if get_parent() != null: get_parent().remove_child(self)
		weapon.add_child(self)
	var unscaled: Basis = weapon.global_basis.inverse()*weapon.global_basis.orthonormalized()
	transform = Transform3D(unscaled,Vector3(0,(from+to)*.5,0))
	var length: float = (weapon.global_basis*Vector3(0,to-from,0)).length()
	inner = Vector3(0,-length*.5,0)
	point = Vector3(0,length*.5,0)
	glow.emission_box_extents = Vector3(.025,length*.5,.025)
	core.position = Vector3(0,-length*.25,0)
	core.emission_sphere_radius = .06
	light.position = core.position

# A tick: how charged the blade is, and how much of that it sheds as light.
func step(dt: float, strength: float, lit_strength: float = -1.0) -> void:
	intensity = clampf(strength,0.0,1.0)
	lit = intensity if lit_strength < 0.0 else clampf(lit_strength,0.0,1.0)
	show_strength()
	ground_left = maxf(0.0,ground_left-dt)
	bolt_clock -= dt
	if bolt_clock <= 0.0:
		bolt_clock = BOLT_EVERY
		draw_bolts()
		draw_ground_bolts()

func show_strength() -> void:
	var on = intensity > .02
	glow.emitting = on
	core.emitting = on
	# (Particles fade in rather than thin out: their colour carries the strength.)
	glow.color = Color(1,1,1,clampf(intensity*1.3,0.0,1.0))
	core.color = Color(1,1,1,clampf(intensity*1.2,0.0,1.0))
	glow.scale_amount_max = .16+.1*intensity
	light.light_energy = .8*lit
	light.visible = lit > .02
	bolts.visible = on
	ground_bolts.visible = ground_left > 0.0

# The blade's point, in the world.
func tip() -> Vector3:
	return to_global(point)

# The blade meets the ground at `at`: the charge breaks off it, lightning
# running out over the ground.
func discharge(at: Vector3) -> void:
	ground_left = GROUND_TIME
	ground_at = at
	bolt_clock = 0.0

# Lightning about the blade: bolts leaping out from its lower part and back
# to it, kinked and forking, as many as the charge is strong.
func draw_bolts() -> void:
	var mesh: ImmediateMesh = bolts.mesh
	mesh.clear_surfaces()
	var length = inner.distance_to(point)
	var count = roundi(BOLTS*intensity*intensity)
	if count == 0 or length < .01: return
	var view = view_direction(bolts)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in count:
		# Mostly round the lower blade, a few further up it.
		var start = lerpf(-.5,.15,pow(randf(),1.6))*length
		var finish = start+randf_range(.12,.4)*length*(1.0 if randf() < .7 else -1.0)
		finish = clampf(finish,-.5*length,.5*length)
		var out = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()
		var reach = BOLT_REACH*randf_range(.45,1.0)*(.5+.5*intensity)
		var path = jagged(Vector3(0,start,0),Vector3(0,finish,0),out*reach,.035)
		draw_bolt(mesh,path,view,1.0)
		# A fork leaping off it, part of the way out.
		if randf() < .6:
			var from: Vector3 = path[randi_range(3,path.size()-4)]
			var away: Vector3 = Vector3(from.x,0,from.z).normalized() if Vector3(from.x,0,from.z).length() > .01 else out
			draw_bolt(mesh,jagged(from,from+away*randf_range(.08,.18)+Vector3(0,randf_range(-.1,.1),0),Vector3.ZERO,.03,6),view,.7)
	mesh.surface_end()

# The charge breaking off over the ground: bolts running out from where the
# blade struck, fewer and shorter as it fades.
func draw_ground_bolts() -> void:
	var mesh: ImmediateMesh = ground_bolts.mesh
	mesh.clear_surfaces()
	if ground_left <= 0.0: return
	ground_bolts.global_transform = Transform3D(Basis.IDENTITY,ground_at)
	var left = ground_left/GROUND_TIME
	var view = view_direction(ground_bolts)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in maxi(1,roundi(GROUND_BOLTS*left)):
		var angle = randf()*TAU
		var run = Vector3(cos(angle),0,sin(angle))*GROUND_REACH*randf_range(.4,1.0)*(.5+.5*left)
		var path = jagged(Vector3(0,.05,0),run+Vector3(0,.04,0),Vector3(0,randf_range(.05,.25),0),.07,12)
		draw_bolt(mesh,path,view,left)
	mesh.surface_end()

# A bolt's path from `from` to `to`, bowed out by `bulge` at its middle, each
# joint thrown off the line by up to `jitter`: lightning's sharp kinks.
func jagged(from: Vector3, to: Vector3, bulge: Vector3, jitter: float, joints: int = BOLT_JOINTS) -> Array:
	var path: Array = []
	for j in joints:
		var u = float(j)/(joints-1)
		var p = from.lerp(to,u)+bulge*sin(PI*u)
		if j > 0 and j < joints-1: p += Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*jitter
		path.append(p)
	return path

# One bolt: a wide blue halo and a thin white core, as ribbons turned to the
# camera.
func draw_bolt(mesh: ImmediateMesh, path: Array, view: Vector3, strength: float) -> void:
	for layer in [[HALO_WIDTH,HALO,.7],[CORE_WIDTH,CORE,1.0]]:
		var colour: Color = layer[1]*(layer[2]*strength)
		colour.a = 1.0
		for j in path.size()-1:
			var p: Vector3 = path[j]; var q: Vector3 = path[j+1]
			var across: Vector3 = (q-p).cross(view)
			if across.length() < 1e-5: continue
			across = across.normalized()*layer[0]
			for corner in [p-across,p+across,q+across,p-across,q+across,q-across]:
				mesh.surface_set_color(colour)
				mesh.surface_add_vertex(corner)

# Toward the camera, in `node`'s space.
func view_direction(node: Node3D) -> Vector3:
	var camera = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null: return Vector3.BACK
	return (node.global_basis.inverse()*(camera.global_basis.z)).normalized()
