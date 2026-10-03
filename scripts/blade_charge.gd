extends Node3D
## Ground Slam's gathering charge on the hero's blade, after the lightning of
## Thunderfury: a pale blue plasma glow sheathing the blade, brightest round
## its lower part, with branching lightning crackling out from it into the air,
## forking as it goes, and a cold light, all as strong as `intensity` (0 to 1),
## which scripts/visual.gd raises as he lifts the sword and drives it down. As
## the blade meets the ground the charge breaks off it, lightning racing out
## over the ground for a moment. Drawn only; nothing about the skill depends
## on it. It is carried on the blade (attach()).

const Vfx = preload("res://scripts/vfx.gd")
const GLOW = Color(.4,.68,1.0)
# Lightning as it is: a main channel crinkled at every scale, forking into
# branches, each thinner and dimmer than the one it leaves and tapering away
# to nothing, which fork again; every one a ribbon brightest white along its
# middle, fading through blue to clear at its edges.
# Bolts at full strength (fewer below it: a few on the raise, many on the
# slam), and how often they are redrawn, so they flicker and jump.
const BOLTS = 4
const BOLT_EVERY = .045
# How far out from the blade a bolt reaches (metres, at full strength).
const BOLT_REACH = .4
# A main channel's width (edge to edge), how far its crinkles stray (a share
# of each stretch's length), how many times it is crinkled, how deep the
# forks go, and how much thinner and dimmer each fork is than its parent.
const BOLT_WIDTH = .02
const ROUGHNESS = .24
const DETAIL = 5
const FORK_DEPTH = 2
const FORK_WIDTH = .5
const FORK_BRIGHTNESS = .6
const CORE = Color(.85,.94,1.0)
const HALO = Color(.25,.5,1.0)
const HALO_SHARE = .3
# The charge breaking off over the ground: how long it crackles, how many
# main channels, how far they run and how wide they are.
const GROUND_TIME = .3
const GROUND_BOLTS = 4
const GROUND_REACH = 1.6
const GROUND_WIDTH = .03

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
	glow = Vfx.particles(self,36,.24,false,true)
	glow.local_coords = true
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	glow.direction = Vector3.UP
	glow.spread = 180
	glow.initial_velocity_min = 0.0
	glow.initial_velocity_max = .12
	glow.gravity = Vector3.ZERO
	glow.scale_amount_min = .14
	glow.scale_amount_max = .24
	glow.color_ramp = Vfx.ramp([0,.3,1],[Color(GLOW,0),Color(GLOW,.32),Color(GLOW,0)])
	# Brightest round the lower blade, where the lightning gathers.
	core = Vfx.particles(self,12,.3,false,true)
	core.local_coords = true
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.direction = Vector3.UP
	core.spread = 180
	core.initial_velocity_min = 0.0
	core.initial_velocity_max = .05
	core.gravity = Vector3.ZERO
	core.scale_amount_min = .26
	core.scale_amount_max = .38
	core.color_ramp = Vfx.ramp([0,.35,1],[Color(.75,.9,1,0),Color(.7,.87,1,.4),Color(.5,.75,1,0)])
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

# A tick: how charged the blade is.
func step(dt: float, strength: float) -> void:
	intensity = clampf(strength,0.0,1.0)
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
	glow.scale_amount_max = .18+.14*intensity
	bolts.visible = on
	ground_bolts.visible = ground_left > 0.0

# How much light the blade sheds (0 to 1), set as it is shown (Visual).
func shed_light(amount: float) -> void:
	lit = clampf(amount,0.0,1.0)
	light.light_energy = .7*lit
	light.visible = lit > .02

# The blade's point, in the world.
func tip() -> Vector3:
	return to_global(point)

# The blade meets the ground at `at`: the charge breaks off it, lightning
# running out over the ground.
func discharge(at: Vector3) -> void:
	ground_left = GROUND_TIME
	ground_at = at
	bolt_clock = 0.0

# Lightning about the blade: channels leaping out from its lower part into
# the air, forking as they go, as many as the charge is strong.
func draw_bolts() -> void:
	var mesh: ImmediateMesh = bolts.mesh
	mesh.clear_surfaces()
	var length = inner.distance_to(point)
	var count = roundi(BOLTS*intensity*intensity)
	if count == 0 or length < .01: return
	var view = view_direction(bolts)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in count:
		# Mostly from the lower blade, out and a little along it.
		var from = Vector3(0,lerpf(-.5,.15,pow(randf(),1.6))*length,0)
		var out = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()
		var reach = BOLT_REACH*randf_range(.5,1.0)*(.5+.5*intensity)
		var to = from+out*reach+Vector3(0,randf_range(-.35,.35)*length,0)
		bolt_tree(mesh,from,to,BOLT_WIDTH,1.0,FORK_DEPTH,view,.4)
	mesh.surface_end()

# The charge breaking off over the ground: channels running out from where
# the blade struck, forking, fewer and shorter as it fades.
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
		var run = Vector3(cos(angle),0,sin(angle))*GROUND_REACH*randf_range(.5,1.0)*(.5+.5*left)
		bolt_tree(mesh,Vector3(0,.05,0),run+Vector3(0,.05,0),GROUND_WIDTH,left,FORK_DEPTH,view,.2)
	mesh.surface_end()

# A channel from `from` to `to`, crinkled at every scale (each stretch's
# middle thrown aside by a share of its length, again and again), then its
# forks: off at an angle from points along it, a shorter way, thinner and
# dimmer, forking again while `depth` lasts. `rise` is how far up or down a
# channel may stray (a share of across): less over the ground.
func bolt_tree(mesh: ImmediateMesh, from: Vector3, to: Vector3, width: float, brightness: float, depth: int, view: Vector3, rise: float) -> void:
	var path: Array = [from,to]
	for level in DETAIL:
		var finer: Array = [path[0]]
		for i in path.size()-1:
			var a: Vector3 = path[i]; var b: Vector3 = path[i+1]
			var along: Vector3 = b-a
			var aside = Vector3(randf_range(-1,1),randf_range(-rise,rise),randf_range(-1,1))
			aside -= along.normalized()*aside.dot(along.normalized())
			finer.append((a+b)*.5+aside*along.length()*ROUGHNESS)
			finer.append(b)
		path = finer
	# A main channel narrows a little to its end; a fork to nothing.
	draw_channel(mesh,path,view,width,width*(.45 if depth == FORK_DEPTH else 0.0),brightness)
	if depth <= 0: return
	var whole = from.distance_to(to)
	for f in randi_range(1,3) if depth == FORK_DEPTH else randi_range(0,2):
		var k = randi_range(path.size()/8,path.size()*3/4)
		var start: Vector3 = path[k]
		var heading: Vector3 = (path[mini(k+2,path.size()-1)]-path[maxi(k-2,0)]).normalized()
		var turn = Vector3(randf_range(-1,1),randf_range(-rise,rise),randf_range(-1,1))
		turn = (turn-heading*turn.dot(heading)).normalized()
		var angle = deg_to_rad(randf_range(20,55))
		var way: Vector3 = heading*cos(angle)+turn*sin(angle)
		bolt_tree(mesh,start,start+way*whole*randf_range(.25,.5),width*FORK_WIDTH,brightness*FORK_BRIGHTNESS,depth-1,view,rise)

# One channel along `path`: a ribbon turned to the camera, `start_width` wide
# at its start narrowing to `end_width`, its colour (the light it adds)
# brightest white along the middle, pale blue halfway out, nothing at the
# edges.
func draw_channel(mesh: ImmediateMesh, path: Array, view: Vector3, start_width: float, end_width: float, brightness: float) -> void:
	var middle: Color = CORE*brightness
	var half: Color = HALO*(HALO_SHARE*brightness)
	middle.a = 1.0; half.a = 1.0
	var edge = Color(0,0,0,1)
	var stops = [[-1.0,edge],[-.5,half],[0.0,middle],[.5,half],[1.0,edge]]
	# Each point's sideways reach, across the channel's run there (so the
	# ribbon bends unbroken round each kink).
	var across: Array = []
	for i in path.size():
		var run: Vector3 = path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]
		var side: Vector3 = run.cross(view)
		side = side.normalized() if side.length() > 1e-6 else Vector3.ZERO
		across.append(side*lerpf(start_width,end_width,float(i)/(path.size()-1))*.5)
	for j in path.size()-1:
		for k in stops.size()-1:
			var a0: Vector3 = path[j]+across[j]*stops[k][0]; var a1: Vector3 = path[j]+across[j]*stops[k+1][0]
			var b0: Vector3 = path[j+1]+across[j+1]*stops[k][0]; var b1: Vector3 = path[j+1]+across[j+1]*stops[k+1][0]
			for corner in [[a0,stops[k][1]],[a1,stops[k+1][1]],[b1,stops[k+1][1]],[a0,stops[k][1]],[b1,stops[k+1][1]],[b0,stops[k][1]]]:
				mesh.surface_set_color(corner[1])
				mesh.surface_add_vertex(corner[0])

# Toward the camera, in `node`'s space.
func view_direction(node: Node3D) -> Vector3:
	var camera = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null: return Vector3.BACK
	return (node.global_basis.inverse()*(camera.global_basis.z)).normalized()
