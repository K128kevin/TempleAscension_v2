extends MeshInstance3D
## The beer in a mug (scripts/townsfolk.gd: Anya pours it, a drinker sips it
## down): its surface, a level disc kept horizontal however the mug is held
## (top-level, placed afresh every moment: settle), as wide as the mug inside
## and drawn out the way the mug leans (a cylinder cut by a level plane is an
## ellipse), its middle on the mug's own axis at the height its `fill` (0
## empty, 1 full) says, and never above the low side of the rim, so tipped to
## the lips it comes to the rim there. Its look is assets/shaders/beer.gdshader:
## a head of foam (`head` 1) on a fresh pour, built up as it is poured, drunk
## away with the first sips (it is gone below FOAM_FROM full) to dark amber
## beer with a ring of foam at the wall and a scum of bubbles; and as the
## beer goes down, foam is left clinging to the mug's wall above it in lacy
## rings (`lace`, assets/shaders/beer_lace.gdshader).
const Person = preload("res://scripts/townsperson.gd")
# Inside the mug (its own unit box): how far up its floor stands (the bottom
# is thick), and how far below the rim a full one comes; how wide it is
# inside, as a share of the rim (Person.MUG_RIM_RADIUS: the beer's edge runs
# into the staves, and the lace stands just off them, BORE); how far a lean
# may draw the surface out.
const FLOOR = .27
const BRIM = .07
const INSIDE = .86
const BORE = .75
const STRETCH = 2.2
const FOAM_FROM = .72
# How full a pour is before its head has formed.
const HEADED = .45
static var disc: ArrayMesh
static var tube: CylinderMesh
static var surface_shader: Shader
static var lace_shader: Shader
static var count = 0

var mug: Node3D
var head = 0.0
# The highest it has stood since it was poured (for the lace).
var highest = 0.0
var fill = 0.0:
	set(value):
		value = clampf(value,0.0,1.0)
		# Poured, its head builds; drunk, it goes.
		if value > fill: head = maxf(head,smoothstep(.1,HEADED,value))
		else: head = minf(head,smoothstep(FOAM_FROM,1.0,value))
		if value <= .005: highest = 0.0
		highest = maxf(highest,value)
		fill = value
		visible = fill > .005
		material.set_shader_parameter("head",head)
		if visible and is_inside_tree(): settle()
var material = ShaderMaterial.new()
var lace: MeshInstance3D
var lace_material = ShaderMaterial.new()

# The beer in `mug`, made if it has none (`fill` then 0).
static func of(mug: Node3D):
	if mug.has_meta("beer") and is_instance_valid(mug.get_meta("beer")): return mug.get_meta("beer")
	var beer = new()
	beer.name = "Beer"
	beer.mug = mug
	if disc == null:
		disc = round_disc(6,28)
		surface_shader = load("res://assets/shaders/beer.gdshader")
		lace_shader = load("res://assets/shaders/beer_lace.gdshader")
		tube = CylinderMesh.new()
		tube.cap_top = false
		tube.cap_bottom = false
		tube.radial_segments = 20
		tube.rings = 1
	count += 1
	beer.mesh = disc
	beer.material.shader = surface_shader
	beer.material.set_shader_parameter("seed",fmod(count*1.618,10.0))
	beer.material_override = beer.material
	beer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beer.top_level = true
	mug.add_child(beer)
	mug.set_meta("beer",beer)
	beer.make_lace()
	beer.fill = 0.0
	beer.settle()
	return beer

# A flat disc of unit radius, in `rings` rings of `around` points (so its
# foam can stand up in the middle).
static func round_disc(rings: int, around: int) -> ArrayMesh:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var point = func(ring: int, k: int) -> Vector3:
		var r: float = float(ring)/rings
		var a: float = TAU*k/around
		return Vector3(cos(a)*r,0,sin(a)*r)
	for ring in rings:
		for k in around:
			var quad = [point.call(ring,k),point.call(ring+1,k),point.call(ring+1,k+1),point.call(ring,k),point.call(ring+1,k+1),point.call(ring,k+1)]
			for v in quad:
				tool.set_uv(Vector2(v.x,v.z)*.5+Vector2(.5,.5))
				tool.add_vertex(v)
	return tool.commit()

# The tube the lace is drawn on, inside the mug's bore from its floor to
# its brim (in metres, though the mug is sized out of true: its scale
# undone).
func make_lace() -> void:
	lace = MeshInstance3D.new()
	lace.name = "Lace"
	lace.mesh = tube
	lace_material.shader = lace_shader
	lace_material.set_shader_parameter("seed",fmod(count*2.414,10.0))
	lace.material_override = lace_material
	lace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mug.add_child(lace)
	var size: Vector3 = mug.transform.basis.get_scale()
	var bore: float = (Person.MUG_RIM.y-FLOOR)*size.y
	var radius: float = Person.MUG_RIM_RADIUS*BORE
	# (The tube's own radius is .5 and its height 2, about its middle.)
	lace.transform = Transform3D(Basis.from_scale(Vector3(radius*2.0/size.x,bore*.5/size.y,radius*2.0/size.z)),Person.MUG_BASE+Vector3(0,(FLOOR+Person.MUG_RIM.y)*.5,0))
	lace_material.set_shader_parameter("half_bore",bore*.5)
	lace.visible = false

# How full `mug` is (0 if it holds none).
static func left_in(mug: Node3D) -> float:
	if mug == null or not is_instance_valid(mug) or not mug.has_meta("beer"): return 0.0
	var beer = mug.get_meta("beer")
	return beer.fill if is_instance_valid(beer) else 0.0

# Settled late in each frame, and again just before it is drawn, after
# whatever has moved the mug (a drinker's hand is posed late in the frame).
func _process(_delta: float) -> void:
	settle()

func _enter_tree() -> void:
	process_priority = 1000
	if not RenderingServer.frame_pre_draw.is_connected(settle): RenderingServer.frame_pre_draw.connect(settle)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(settle): RenderingServer.frame_pre_draw.disconnect(settle)

func settle() -> void:
	if not is_instance_valid(mug) or not mug.is_inside_tree(): return
	# The lace, from where the beer stands now up to where it stood (metres
	# up the bore from its floor).
	if is_instance_valid(lace):
		var full: float = (Person.MUG_RIM.y-BRIM-FLOOR)*mug.transform.basis.get_scale().y
		lace.visible = highest-fill > .03
		lace_material.set_shader_parameter("low",fill*full)
		lace_material.set_shader_parameter("high",highest*full)
	if not visible: return
	var frame: Transform3D = mug.global_transform
	var up: Vector3 = frame.basis.y.normalized()
	var rim: Vector3 = frame*Person.MUG_RIM
	var floor_at: Vector3 = frame*(Person.MUG_BASE+Vector3(0,FLOOR,0))
	var brim: Vector3 = frame*(Person.MUG_RIM-Vector3(0,BRIM,0))
	var radius: float = Person.MUG_RIM_RADIUS*INSIDE
	# Its middle on the mug's axis, as high as it is full, but never above
	# the rim's low side (tipped to the lips, there it brims).
	var lip: float = rim.y-radius*sqrt(maxf(1.0-up.y*up.y,0.0))
	var height: float = fill
	if brim.y > floor_at.y+.001: height = minf(height,(lip-floor_at.y)/(brim.y-floor_at.y))
	var at: Vector3 = floor_at.lerp(brim,maxf(height,0.0))
	# The way it leans, and how far: the level surface drawn out along it.
	var lean: Vector3 = Vector3(up.x,0,up.z)
	var slope: float = clampf(up.y,1.0/STRETCH,1.0)
	var along: Vector3 = lean.normalized() if lean.length() > .001 else Vector3.RIGHT
	var across: Vector3 = Vector3.UP.cross(along).normalized()
	global_transform = Transform3D(Basis(along*radius/slope,Vector3.UP,across*radius),at)
