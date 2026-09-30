extends Node3D
## The Crowned Statue's gaze, drawn like Temple Ascension v1's laser: a red
## lightning beam in three passes (a faint broad glow, a red band and a bright
## core) whose path jitters sideways, re-rolled every 55 ms so the forks crawl
## along it. Here a beam leaves each of the boss's eyes; the two converge on
## the aim point and run on until they strike the floor or a wall. Red glows
## sit at the eyes and at the point of impact. Advanced by the boss's tick.
const PULSE = .055
const REACH = 28.0
const GLOW_WIDTH = .34
const BAND_WIDTH = .13
const CORE_WIDTH = .045
const JITTER = .07

var game
var boss
var clock = 0.0
var seed = 0.0
var mesh: ImmediateMesh
var materials: Array = []
var eye_lights: Array = []
var impact_light: OmniLight3D
var end_point = Vector3.ZERO

func setup(owner_game, owner_boss) -> void:
	game = owner_game
	boss = owner_boss
	name = "CrownGaze"
	top_level = true
	# Beam vertices are written in world space.
	global_transform = Transform3D.IDENTITY
	seed = randf()*TAU
	mesh = ImmediateMesh.new()
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 64.0
	add_child(node)
	for pass_color in [Color(1,.125,.125,.12),Color(.9,.125,.125,.52),Color(1,.36,.32,1)]:
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = pass_color
		m.no_depth_test = false
		materials.append(m)
	for i in 2:
		var eye = OmniLight3D.new()
		eye.light_color = Color(1,.2,.15)
		eye.light_energy = 1.4
		eye.omni_range = 1.4
		add_child(eye)
		eye_lights.append(eye)
	impact_light = OmniLight3D.new()
	impact_light.light_color = Color(1,.25,.2)
	impact_light.light_energy = 2.2
	impact_light.omni_range = 3.0
	add_child(impact_light)

# The boss's two eyes, from its head bone and facing.
func eyes() -> Array:
	var visual = boss.visual
	var size: float = visual.rig.scale.x
	var skeleton: Skeleton3D = visual.skeleton
	var head: Vector3 = (skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head"))).origin
	var facing: Basis = boss.global_basis.orthonormalized()
	var front: Vector3 = head+facing.z*.085*size+Vector3.UP*.045*size
	return [front+facing.x*.035*size,front-facing.x*.035*size]

# Where the beam ends along `angle`: through the player's chest height at the
# player's distance, on until the floor, a wall or its full reach.
func strike_point(angle: float, from: Vector3) -> Vector3:
	var across = Vector3(sin(angle),0,cos(angle))
	var start = Vector3(boss.position.x,0,boss.position.z)
	var player: Vector3 = game.player.position
	var distance = maxf(2.0,Vector2(player.x-start.x,player.z-start.z).length())
	var aim = start+across*distance+Vector3.UP*1.0
	var line = (aim-from).normalized()
	var length = REACH
	if line.y < -.001: length = minf(length,from.y/-line.y)
	# Stop at the first wall along the sweep.
	var step = .4
	var travelled = step
	while travelled < length:
		var probe = from+line*travelled
		if not game.world.fits_for_visibility(Vector3(probe.x,0,probe.z),.05): break
		travelled += step
	return from+line*minf(travelled,length)

func tick(dt: float, angle: float) -> void:
	clock += dt
	var sources = eyes()
	var middle: Vector3 = (sources[0]+sources[1])*.5
	end_point = strike_point(angle,middle)
	for i in 2: eye_lights[i].global_position = sources[i]
	impact_light.global_position = end_point+Vector3.UP*.3
	impact_light.light_energy = 2.2*(1.0+.15*sin(clock*37.0))
	var camera: Camera3D = game.world.camera
	var pulse = floori(clock/PULSE)
	mesh.clear_surfaces()
	for layer in 3:
		var width = [GLOW_WIDTH,BAND_WIDTH,CORE_WIDTH][layer]
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,materials[layer])
		for i in 2:
			ribbon(lightning(sources[i],end_point,pulse,i),width,camera)
		mesh.surface_end()

# A thin bolt from `from` to `to`, its offsets shifting every pulse.
func lightning(from: Vector3, to: Vector3, pulse: int, strand: int) -> PackedVector3Array:
	var points = PackedVector3Array([from])
	var line = to-from
	var length = line.length()
	if length < .01: return PackedVector3Array([from,to])
	var side = line.cross(Vector3.UP).normalized()
	if side.length_squared() < .5: side = Vector3.RIGHT
	var lift = side.cross(line).normalized()
	var segments = maxi(12,roundi(length/.8))
	for i in range(1,segments):
		var t = float(i)/segments
		var n1 = sin(i*12.9898+pulse*78.233+seed+strand*3.1)
		var n2 = sin(i*27.173-pulse*31.417+seed*1.7+strand*1.3)
		var offset = JITTER*((n1+n2*.55)/1.55)*sin(PI*t)
		var n3 = sin(i*7.31+pulse*19.7+seed*2.3+strand)
		points.append(from+line*t+side*offset+lift*offset*.6*n3)
	points.append(to)
	return points

# Camera-facing quads along the polyline.
func ribbon(points: PackedVector3Array, width: float, camera: Camera3D) -> void:
	var view = -camera.global_basis.z
	for i in points.size()-1:
		var a = points[i]; var b = points[i+1]
		var across = (b-a).cross(view).normalized()*width*.5
		mesh.surface_add_vertex(a-across); mesh.surface_add_vertex(a+across); mesh.surface_add_vertex(b+across)
		mesh.surface_add_vertex(a-across); mesh.surface_add_vertex(b+across); mesh.surface_add_vertex(b-across)
