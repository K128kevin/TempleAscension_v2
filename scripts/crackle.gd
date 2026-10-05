extends Node3D
## Lightning Shot's crackle where it strikes: a few small arcs of electricity
## jumping about the spot for as long as its sound is heard
## (assets/audio/lightning-zap.wav), each a short jagged thread of light that
## flickers, snaps out and strikes again somewhere else nearby, the last of
## them dying away as the sound fades. A flickering blue light goes with them.
##
## Thunder Slam drives the same arcs outward (`outward`): they spark out
## from the blow across the slam's arc, racing just behind its shockwave's
## front (scripts/shockwave.gd), and die as the front thins at its reach.
##
## Thin ribbons of light drawn afresh each frame, as the lightning leaping
## between enemies is (scripts/ranger_fx.gd bolt); it does no damage.
const Shockwave = preload("res://scripts/shockwave.gd")
const ZAP = preload("res://assets/audio/lightning-zap.wav")
# How long the sound's own fade is (tools/make_sounds.py ZAP_FADE): the arcs
# thin out and die with it.
const FADE = .6
# Thunder Slam's arcs: how many at once, and how long they go on crackling
# at the edge after the front has reached it, the last of that fading.
const OUTWARD_ARCS = 14
const OUTWARD_LINGER = .3
# Each of Thunder Slam's is short, and blinks out sooner than Lightning
# Shot's, to pop up again somewhere else.
const OUTWARD_LENGTH = Vector2(.25,.6)
const OUTWARD_LIFE = Vector2(.035,.09)
# How far from the spot the arcs reach, how many are alight at once, and
# how long each lasts before it jumps somewhere else.
const REACH = 1.3
const ARCS = 4
const LIFE = Vector2(.06,.16)
# Each arc's thread is drawn again this often, a little differently, so it
# crawls as it burns.
const REDRAW = .035
var age = 0.0
var lasting = 1.0
var fade = FADE
var count = ARCS
# Thunder Slam's: the way the blow goes, the half-angle of its arc and how far
# it reaches (zero reach: Lightning Shot's, about one spot).
var way = Vector3.FORWARD
var half = PI
var reach = 0.0
var arcs: Array = []
var redraw = 0.0
var mesh: ImmediateMesh
var material: StandardMaterial3D
var flash: OmniLight3D

static func make(at: Vector3) -> Node3D:
	var node = new()
	node.position = at
	node.lasting = ZAP.get_length()
	node.dress()
	return node

# Thunder Slam's arcs, out from `at` along `direction` across `degrees` of arc
# to `reach` metres.
static func outward(at: Vector3, direction: Vector3, degrees: float, reach: float) -> Node3D:
	var node = new()
	node.position = at
	node.way = direction.normalized() if direction.length() > .01 else Vector3.FORWARD
	node.half = deg_to_rad(degrees*.5)
	node.reach = reach
	node.count = OUTWARD_ARCS
	node.lasting = Shockwave.SWEEP+OUTWARD_LINGER
	node.fade = OUTWARD_LINGER+.15
	node.dress()
	return node

func dress() -> void:
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
	flash.omni_range = 3.5
	flash.position = Vector3.UP*.9
	add_child(flash)
	tick(0.0)

# How strong it still is: whole until the sound starts to fade (or Thunder
# Slam's front has reached its edge), then eased away.
func strength() -> float:
	var fading = clampf((age-(lasting-fade))/fade,0.0,1.0)
	return cos(fading*PI)*.5+.5

# A new arc between two points about the spot, low by the ground or up about
# the body it struck, sometimes grounding itself.
func spark() -> Dictionary:
	if reach > 0: return outward_spark()
	var a = Vector3(randf_range(-1,1),0,randf_range(-1,1)).limit_length(1.0)*REACH+Vector3.UP*randf_range(.1,1.7)
	var way = Vector3(randf_range(-1,1),randf_range(-.7,.7),randf_range(-1,1)).normalized()
	var b: Vector3 = a+way*randf_range(.35,.9)
	if randf() < .3: b = Vector3(a.x+randf_range(-.4,.4),.03,a.z+randf_range(-.4,.4))
	b.y = maxf(b.y,.03)
	return {"a":a,"b":b,"left":randf_range(LIFE.x,LIFE.y)}

# One of Thunder Slam's: a short arc low over the ground somewhere the front
# has passed, most often near it, pointing out along the way the blow went
# and hopping up off the floor or down onto it.
func outward_spark() -> Dictionary:
	var out = maxf(.8,Shockwave.spread(age)*reach)
	var length = randf_range(OUTWARD_LENGTH.x,OUTWARD_LENGTH.y)
	var from = minf(out*sqrt(randf_range(.1,1.0)),reach-length)
	var turn = randf_range(-half,half)
	var bend = clampf(turn+randf_range(-1,1)*length/maxf(from,.5)*.5,-half,half)
	var a: Vector3 = way.rotated(Vector3.UP,turn)*maxf(from,.3)+Vector3.UP*randf_range(.03,.22)
	var b: Vector3 = way.rotated(Vector3.UP,bend)*maxf(from,.3)+way.rotated(Vector3.UP,bend)*length+Vector3.UP*randf_range(.03,.4)
	return {"a":a,"b":b,"left":randf_range(OUTWARD_LIFE.x,OUTWARD_LIFE.y)}

func tick(dt: float) -> bool:
	age += dt
	var power = strength()
	for i in range(arcs.size()-1,-1,-1):
		arcs[i].left -= dt
		if arcs[i].left <= 0: arcs.remove_at(i)
	# (Fewer and fewer strike again as it fades.)
	while arcs.size() < ceili(count*power) and age < lasting:
		if arcs.size() > 0 and randf() > power: break
		arcs.append(spark())
	redraw -= dt
	if redraw <= 0 or dt == 0.0:
		redraw = REDRAW
		draw(power)
	flash.light_energy = 1.8*power*randf_range(.4,1.0) if not arcs.is_empty() else 0.0
	# (Thunder Slam's light runs out with its arcs.)
	if reach > 0:
		flash.position = way*Shockwave.spread(age)*reach*.75+Vector3.UP*.5
		flash.omni_range = 5.0
	return age >= lasting

func draw(power: float) -> void:
	mesh.clear_surfaces()
	if arcs.is_empty(): return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for arc in arcs:
		var points = jagged(arc.a,arc.b)
		# (A faint broad glow, and the white-blue core in it.)
		thread(points,.045,Color(.35,.6,1,.35*power))
		thread(points,.014,Color(.85,.94,1,.95*power))
		# Now and then a little fork off it.
		if randf() < .4:
			var from: Vector3 = points[randi_range(1,points.size()-2)]
			var fork = jagged(from,from+Vector3(randf_range(-1,1),randf_range(-.6,.3),randf_range(-1,1)).normalized()*randf_range(.15,.35))
			thread(fork,.01,Color(.7,.88,1,.8*power))
	mesh.surface_end()

func jagged(a: Vector3, b: Vector3) -> Array:
	var along: Vector3 = b-a
	var pieces = maxi(3,int(along.length()/.09))
	var points: Array = []
	for i in pieces+1:
		var u = float(i)/pieces
		var wander = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*along.length()*.12*sin(u*PI)
		points.append(a+along*u+wander)
	return points

# A ribbon `width` wide along `points`, drawn twice at right angles so it
# shows from any side.
func thread(points: Array, width: float, color: Color) -> void:
	mesh.surface_set_color(color)
	for i in points.size()-1:
		var p: Vector3 = points[i]
		var q: Vector3 = points[i+1]
		var along = (q-p).normalized()
		var side = along.cross(Vector3.UP).normalized() if absf(along.dot(Vector3.UP)) < .95 else Vector3.RIGHT
		for across in [side*width,along.cross(side).normalized()*width]:
			for v in [p-across,p+across,q+across,p-across,q+across,q-across]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(v)
