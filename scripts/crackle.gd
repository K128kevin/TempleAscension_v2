extends Node3D
## Lightning Shot's crackle where it strikes: a few small arcs of electricity
## jumping about the spot for as long as its sound is heard
## (assets/audio/lightning-zap.wav), each a short jagged thread of light that
## flickers, snaps out and strikes again somewhere else nearby, the last of
## them dying away as the sound fades. A flickering blue light goes with them.
## Thin ribbons of light drawn afresh each frame, as the lightning leaping
## between enemies is (scripts/ranger_fx.gd bolt); it does no damage.
const ZAP = preload("res://assets/audio/lightning-zap.wav")
# How long the sound's own fade is (tools/make_sounds.py ZAP_FADE): the arcs
# thin out and die with it.
const FADE = .6
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
var arcs: Array = []
var redraw = 0.0
var mesh: ImmediateMesh
var material: StandardMaterial3D
var flash: OmniLight3D

static func make(at: Vector3) -> Node3D:
	var node = new()
	node.position = at
	node.lasting = ZAP.get_length()
	node.mesh = ImmediateMesh.new()
	node.material = StandardMaterial3D.new()
	node.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material.vertex_color_use_as_albedo = true
	node.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	node.material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var threads = MeshInstance3D.new()
	threads.mesh = node.mesh
	threads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(threads)
	node.flash = OmniLight3D.new()
	node.flash.light_color = Color(.6,.8,1)
	node.flash.omni_range = 3.5
	node.flash.position = Vector3.UP*.9
	node.add_child(node.flash)
	node.tick(0.0)
	return node

# How strong it still is: whole until the sound starts to fade, then eased
# away with it.
func strength() -> float:
	var fading = clampf((age-(lasting-FADE))/FADE,0.0,1.0)
	return cos(fading*PI)*.5+.5

# A new arc between two points about the spot, low by the ground or up about
# the body it struck, sometimes grounding itself.
func spark() -> Dictionary:
	var a = Vector3(randf_range(-1,1),0,randf_range(-1,1)).limit_length(1.0)*REACH+Vector3.UP*randf_range(.1,1.7)
	var way = Vector3(randf_range(-1,1),randf_range(-.7,.7),randf_range(-1,1)).normalized()
	var b: Vector3 = a+way*randf_range(.35,.9)
	if randf() < .3: b = Vector3(a.x+randf_range(-.4,.4),.03,a.z+randf_range(-.4,.4))
	b.y = maxf(b.y,.03)
	return {"a":a,"b":b,"left":randf_range(LIFE.x,LIFE.y)}

func tick(dt: float) -> bool:
	age += dt
	var power = strength()
	for i in range(arcs.size()-1,-1,-1):
		arcs[i].left -= dt
		if arcs[i].left <= 0: arcs.remove_at(i)
	# (Fewer and fewer strike again as it fades.)
	while arcs.size() < ceili(ARCS*power) and age < lasting:
		if arcs.size() > 0 and randf() > power: break
		arcs.append(spark())
	redraw -= dt
	if redraw <= 0 or dt == 0.0:
		redraw = REDRAW
		draw(power)
	flash.light_energy = 1.8*power*randf_range(.4,1.0) if not arcs.is_empty() else 0.0
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
