extends Node3D
## Lightning Rod's mark (scripts/actor.gd make_rod): static crawling over the
## marked enemy while it lasts. A few short arcs of electricity snap between
## points on its body, each riding the bones it joins so it moves with the
## figure, flickering as it is drawn afresh, blinking out and striking again
## somewhere else; now and then one leaps off the body to the ground. A cold
## flickering light and a few sparks go with them.
##
## Thin ribbons of light, as Lightning Shot's crackle is drawn
## (scripts/crackle.gd). Ticked by its enemy on the combat clock (`tick`).
const Vfx = preload("res://scripts/vfx.gd")
# How many arcs are alight at once, how long each lasts before it jumps
# somewhere else, how far apart the points it joins may be (in metres, for
# a body of size 1) and how far off the bones the arcs ride, over the skin.
const ARCS = 6
const LIFE = Vector2(.05,.16)
const SPAN = Vector2(.2,.7)
const SKIN = .15
# Its threads are drawn again this often, a little differently, so they crawl.
const REDRAW = .035
# The bones arcs never land on: fingers, twist and helper bones.
const SKIP = ["finger","thumb","index","middle","ring","pinky","twist","ik","root","prop","weapon"]

var body: Node3D
var skeleton: Skeleton3D
var size = 1.0
var bones: PackedInt32Array = PackedInt32Array()
# Each arc: the two places it joins ([bone, offset] or a point on the ground),
# and how long it has left.
var arcs: Array = []
var redraw = 0.0
var mesh: ImmediateMesh
var material: StandardMaterial3D
var flash: OmniLight3D
var sparks: CPUParticles3D

static func make(owner_body: Node3D, skeleton_of_it: Skeleton3D, body_size: float) -> Node3D:
	var node = new()
	node.body = owner_body
	node.skeleton = skeleton_of_it
	node.size = body_size
	node.dress()
	return node

func dress() -> void:
	top_level = true
	if skeleton != null:
		for bone in skeleton.get_bone_count():
			var bone_name: String = skeleton.get_bone_name(bone).to_lower()
			if SKIP.any(func(k): return k in bone_name): continue
			bones.append(bone)
	mesh = ImmediateMesh.new()
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var threads = MeshInstance3D.new()
	threads.mesh = mesh
	threads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(threads)
	flash = OmniLight3D.new()
	flash.light_color = Color(.6,.8,1)
	flash.omni_range = 2.8*size
	add_child(flash)
	sparks = Vfx.particles(self,14,.4,false,true)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = .4*size
	sparks.gravity = Vector3(0,-3,0)
	sparks.direction = Vector3.UP
	sparks.spread = 180
	sparks.initial_velocity_min = .4; sparks.initial_velocity_max = 1.4
	sparks.scale_amount_min = .03; sparks.scale_amount_max = .06
	sparks.color_ramp = Vfx.ramp([0,.5,1],[Color(1,1,1,1),Color(.7,.86,1,.9),Color(.6,.8,1,0)])
	sparks.emitting = true

# Where a joined place is now: on a bone, out over the skin, or on the ground.
func place(end) -> Vector3:
	if end is Vector3: return end
	return (skeleton.global_transform*skeleton.get_bone_global_pose(end[0])).origin+end[1]

func middle() -> Vector3:
	return body.global_position+Vector3.UP*1.1*size if is_instance_valid(body) else global_position

# A place on the body: on one of its bones, pushed out from its middle so it
# lies over the skin. (A figure with no bones: about a body-sized column.)
func on_body(near = null) -> Array:
	if bones.is_empty() or skeleton == null:
		var at: Vector3 = middle()+Vector3(randf_range(-1,1),randf_range(-.9,.8),randf_range(-1,1))*Vector3(.3,1,.3)*size
		return [at]
	var bone: int = bones[randi()%bones.size()]
	if near != null:
		# A bone near the other end, so the arc runs along the body.
		for tries in 8:
			var other: int = bones[randi()%bones.size()]
			var gap: float = place([other,Vector3.ZERO]).distance_to(near)
			if gap > SPAN.x*size and gap < SPAN.y*size:
				bone = other
				break
	var at: Vector3 = place([bone,Vector3.ZERO])
	var out: Vector3 = at-middle()
	out.y *= .3
	var lift: Vector3 = (out.normalized() if out.length() > .01 else Vector3.RIGHT)*SKIN*size
	lift += Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*.05*size
	return [bone,lift]

func spark() -> Dictionary:
	var a = on_body()
	var a_at: Vector3 = a[0] if a.size() == 1 else place(a)
	var b
	if randf() < .12 and is_instance_valid(body):
		# Grounding itself: down from the body to the floor beside it.
		b = Vector3(a_at.x+randf_range(-.5,.5)*size,body.global_position.y+.03,a_at.z+randf_range(-.5,.5)*size)
	else:
		var other = on_body(a_at)
		b = other[0] if other.size() == 1 else other
	return {"a":a[0] if a.size() == 1 else a,"b":b,"left":randf_range(LIFE.x,LIFE.y)}

func tick(dt: float) -> void:
	# (It finds its body's bones once it is in the scene with it.)
	if not is_inside_tree(): return
	if is_instance_valid(body): global_position = middle()
	for i in range(arcs.size()-1,-1,-1):
		arcs[i].left -= dt
		if arcs[i].left <= 0: arcs.remove_at(i)
	while arcs.size() < ARCS:
		if not arcs.is_empty() and randf() < .3: break
		arcs.append(spark())
	redraw -= dt
	if redraw <= 0 or dt == 0.0:
		redraw = REDRAW
		draw()
	flash.light_energy = randf_range(.2,.55) if not arcs.is_empty() else 0.0

func draw() -> void:
	mesh.clear_surfaces()
	if arcs.is_empty(): return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for arc in arcs:
		var points = jagged(place(arc.a),place(arc.b))
		# (A faint broad glow, and the white-blue core in it.)
		thread(points,.05*size,Color(.35,.6,1,.4))
		thread(points,.016*size,Color(.88,.95,1,1))
		if randf() < .35:
			var from: Vector3 = points[randi_range(1,points.size()-2)]
			var fork = jagged(from,from+Vector3(randf_range(-1,1),randf_range(-.6,.6),randf_range(-1,1)).normalized()*randf_range(.1,.25)*size)
			thread(fork,.008*size,Color(.7,.88,1,.8))
	mesh.surface_end()

func jagged(a: Vector3, b: Vector3) -> Array:
	var along: Vector3 = b-a
	var pieces = maxi(3,int(along.length()/.06))
	var points: Array = []
	for i in pieces+1:
		var u = float(i)/pieces
		var wander = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*along.length()*.15*sin(u*PI)
		points.append(a+along*u+wander-global_position)
	return points

# A ribbon `width` wide along `points`, drawn twice at right angles so it
# shows from any side.
func thread(points: Array, width: float, color: Color) -> void:
	for i in points.size()-1:
		var p: Vector3 = points[i]
		var q: Vector3 = points[i+1]
		var along = (q-p).normalized()
		var side = along.cross(Vector3.UP).normalized() if absf(along.dot(Vector3.UP)) < .95 else Vector3.RIGHT
		for across in [side*width,along.cross(side).normalized()*width]:
			for v in [p-across,p+across,q+across,p-across,q+across,q-across]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(v)
