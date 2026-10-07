extends Node3D
## Lightning Shield (scripts/skills.gd): a thin, translucent bubble of light
## about the wizard while it lasts. Each time it absorbs a blow, electricity
## crackles across its surface from where the blow landed: forking threads
## of light running out over the shell, crawling as they are drawn afresh,
## and fading, the shell lighting up round the spot (its shader's `flare`)
## with a flash of cold light.
##
## A child of the hero's figure, so it goes where he does. Ticked by Skills
## on the combat clock (`tick`); `crackle` is called as a blow is absorbed.
## Given out (spent or run out: `give_out`), it fades over FADE, its last
## crackle seen through, and is gone (`tick` returns true).
const SHADER = preload("res://assets/shaders/shield_bubble.gdshader")
# The bubble's middle (above his feet), its half-width and half-height.
const MIDDLE = 1.0
const RADIUS = 1.0
const HEIGHT = 1.2
# A crackle: how long it lasts, how many threads run out from where the blow
# landed, and how far round the shell they reach (radians).
const CRACKLE = .42
const THREADS = 9
const REACH = Vector2(.7,1.7)
# Its threads are drawn again this often, a little differently, so they crawl.
const REDRAW = .04
const FADE = .45

var shell: MeshInstance3D
var shell_material: ShaderMaterial
var mesh: ImmediateMesh
var material: StandardMaterial3D
var flash: OmniLight3D
var age = 0.0
var redraw = 0.0
var ending = false
var gone = 0.0
# Crackles alight: {"from" (a direction from the middle), "ends" (where each
# thread runs to), "left"}.
var crackles: Array = []

static func make(body: Node3D) -> Node3D:
	var bubble = new()
	body.add_child(bubble)
	bubble.dress()
	return bubble

func dress() -> void:
	position = Vector3.UP*MIDDLE
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	shell_material = ShaderMaterial.new()
	shell_material.shader = SHADER
	shell = MeshInstance3D.new()
	shell.mesh = sphere
	shell.material_override = shell_material
	shell.scale = Vector3(RADIUS,HEIGHT,RADIUS)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
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
	flash.light_energy = 0.0
	add_child(flash)

# A point on the shell (in its own space) in direction `d`, a little out.
func on_shell(d: Vector3, out: float = 1.02) -> Vector3:
	return Vector3(d.x*RADIUS,d.y*HEIGHT,d.z*RADIUS)*out

# A blow absorbed, coming from `toward` (a world point: whoever struck, or
# anywhere if it is not known).
func crackle(toward = null) -> void:
	var from: Vector3 = Vector3(randf_range(-1,1),randf_range(-.4,.6),randf_range(-1,1))
	if toward is Vector3 and is_inside_tree(): from = to_local(toward)
	from = from.normalized() if from.length() > .01 else Vector3.FORWARD
	var ends: Array = []
	for i in THREADS:
		var side: Vector3 = from.cross(Vector3.UP if absf(from.y) < .9 else Vector3.RIGHT).normalized()
		var axis: Vector3 = side.rotated(from,TAU*(i+randf()*.6)/THREADS)
		ends.append(from.rotated(axis,randf_range(REACH.x,REACH.y)))
	crackles.append({"from":from,"ends":ends,"left":CRACKLE})
	redraw = 0.0
	draw()

func give_out() -> void:
	ending = true

func tick(dt: float) -> bool:
	age += dt
	if ending: gone += dt
	shell_material.set_shader_parameter("shell_time",age)
	shell_material.set_shader_parameter("strength",1.0-minf(1.0,gone/FADE))
	shell.scale = Vector3(RADIUS,HEIGHT,RADIUS)*(1.0+gone*.25)
	for i in range(crackles.size()-1,-1,-1):
		crackles[i].left -= dt
		if crackles[i].left <= 0: crackles.remove_at(i)
	var strength = 0.0
	for c in crackles: strength = maxf(strength,c.left/CRACKLE)
	shell_material.set_shader_parameter("flare",strength)
	if not crackles.is_empty(): shell_material.set_shader_parameter("hit_dir",crackles[-1].from)
	flash.light_energy = .6*strength*strength
	redraw -= dt
	if redraw <= 0:
		redraw = REDRAW
		draw()
	return ending and gone >= maxf(FADE,crackles.size()*CRACKLE)

func draw() -> void:
	mesh.clear_surfaces()
	if crackles.is_empty(): return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for c in crackles:
		var fade: float = c.left/CRACKLE
		for end in c.ends:
			# (Each thread runs out only so far as the crackle has spread.)
			var spread: float = clampf((1.0-fade)*4.0+.35,0.0,1.0)
			var points: Array = path(c.from,c.from.slerp(end,spread))
			thread(points,.03,Color(.35,.6,1,.3*fade))
			thread(points,.007,Color(.9,.96,1,fade))
			if randf() < .5:
				var at: Vector3 = (points[randi_range(1,points.size()-2)]/Vector3(RADIUS,HEIGHT,RADIUS)).normalized()
				var away: Vector3 = at.cross(Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))).normalized()
				thread(path(at,at.rotated(away,randf_range(.15,.4))),.005,Color(.7,.88,1,.8*fade))
	mesh.surface_end()

# A jagged way over the shell between two directions from its middle.
func path(a: Vector3, b: Vector3) -> Array:
	var pieces: int = maxi(5,int(a.angle_to(b)/.06))
	var points: Array = []
	for i in pieces+1:
		var u: float = float(i)/pieces
		var d: Vector3 = a.slerp(b,u)
		var wander: Vector3 = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*.07*sin(u*PI)
		points.append(on_shell((d+wander).normalized()))
	return points

# A ribbon `width` wide along `points`, drawn twice at right angles so it
# shows from any side.
func thread(points: Array, width: float, color: Color) -> void:
	for i in points.size()-1:
		var p: Vector3 = points[i]
		var q: Vector3 = points[i+1]
		var along = (q-p).normalized()
		var side = along.cross(p.normalized()).normalized()
		for across in [side*width,p.normalized()*width]:
			for v in [p-across,p+across,q+across,p-across,q+across,q-across]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(v)
