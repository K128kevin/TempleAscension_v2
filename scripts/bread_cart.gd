extends RefCounted
## Zeno's things (scripts/townsfolk.gd, Zeno): his handcart of bread, its
## loaves, and his straw hat.
##
## The handcart is a timber one, built here plank by plank. It faces +Z, the
## way it is pushed, its origin on the ground under its axle. Its bed of
## boards (BED: across, thick, long) stands BED_HIGH, with plank sides and
## ends and a post at each corner, on two beams that run back past its end
## and up to the push handles' grips (GRIPS, either side). It runs on two big
## spoked wheels (WHEEL across), iron-tyred, on an axle a little behind the
## bed's middle, and rests, parked, on two legs under its back end (tipped
## back onto them: REST_TILT). In the bed a linen cloth, and on it the day's
## loaves, long and round, heaped two deep.
const Art = preload("res://scripts/assets.gd")
const BED = Vector3(.86,.04,1.25)
const BED_HIGH = .5
const BED_AHEAD = .16
const SIDES = .24
const WHEEL = .37
const GRIPS = Vector3(.22,1.0,-1.28)
const LEG_GAP = .07
const REST_TILT = -.15
const LOAVES = 22
static var cache: Dictionary = {}

static func wood(tint: Color) -> StandardMaterial3D:
	var key = "wood"+tint.to_html()
	if cache.has(key): return cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/wood_planks.png")
	m.albedo_color = tint
	m.roughness = .88
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE*1.6
	cache[key] = m
	return m

static func iron() -> StandardMaterial3D:
	if cache.has("iron"): return cache.iron
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(.16,.15,.14)
	m.metallic = .55
	m.roughness = .6
	cache.iron = m
	return m

static func block(parent: Node3D, size: Vector3, at: Vector3, material: Material, turn: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var box = BoxMesh.new()
	box.size = size
	var piece = MeshInstance3D.new()
	piece.mesh = box
	piece.material_override = material
	piece.transform = Transform3D(turn,at)
	parent.add_child(piece)
	return piece

# A round pole of `radius` from `a` to `b`.
static func pole(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var rod = CylinderMesh.new()
	rod.top_radius = radius
	rod.bottom_radius = radius
	rod.height = a.distance_to(b)
	rod.radial_segments = 10
	rod.rings = 1
	var piece = MeshInstance3D.new()
	piece.mesh = rod
	piece.material_override = material
	var up: Vector3 = (b-a).normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < .9 else Vector3.RIGHT).normalized()
	piece.transform = Transform3D(Basis(side,up,side.cross(up)),(a+b)*.5)
	parent.add_child(piece)
	return piece

# The handcart: {"node" (moved about), "body" (tipped onto its legs when
# parked), "wheels" (each turned as it rolls), "grips" (the handles' ends,
# in the cart's own space)}.
static func handcart(rng: RandomNumberGenerator) -> Dictionary:
	var root = Node3D.new()
	root.name = "BreadCart"
	var body = Node3D.new()
	body.position = Vector3(0,WHEEL,0)
	root.add_child(body)
	var timber = wood(Color(.62,.47,.33))
	var dark = wood(Color(.42,.31,.22))
	var middle = Vector3(0,BED_HIGH-WHEEL,BED_AHEAD)
	# The bed: five boards, a finger's gap between.
	var boards = 5
	var width: float = BED.x/boards
	for i in boards:
		block(body,Vector3(width-.012,BED.y,BED.z),middle+Vector3(-BED.x*.5+width*(i+.5),0,0),timber)
	# Two planks to each side, and to each end; a post at each corner.
	for side in [-1.0,1.0]:
		for k in 2:
			block(body,Vector3(.03,SIDES*.5-.01,BED.z),middle+Vector3(side*(BED.x*.5+.015),BED.y*.5+SIDES*(.25+k*.5),0),timber)
		for end in [-1.0,1.0]:
			block(body,Vector3(.05,SIDES+.06,.05),middle+Vector3(side*(BED.x*.5+.02),SIDES*.5,end*(BED.z*.5-.02)),dark)
	for end in [-1.0,1.0]:
		for k in 2:
			block(body,Vector3(BED.x,SIDES*.5-.01,.03),middle+Vector3(0,BED.y*.5+SIDES*(.25+k*.5),end*(BED.z*.5+.015)),timber)
	# The beams under it, running back and up as the handles, a worn grip at
	# each end.
	var back_end: float = BED_AHEAD-BED.z*.5
	for side in [-1.0,1.0]:
		var under = Vector3(side*GRIPS.x,BED_HIGH-WHEEL-BED.y*.5-.035,BED_AHEAD+BED.z*.5-.02)
		var tail = Vector3(side*GRIPS.x,BED_HIGH-WHEEL-BED.y*.5-.035,back_end)
		block(body,Vector3(.06,.06,under.z-tail.z),(under+tail)*.5,dark)
		var grip = Vector3(side*GRIPS.x,GRIPS.y-WHEEL,GRIPS.z)
		pole(body,tail,grip,.028,dark)
		pole(body,grip.lerp(tail,.16),grip+(grip-tail).normalized()*.04,.032,wood(Color(.30,.22,.16)))
		# A leg under its back end, to rest on.
		var hip = Vector3(side*GRIPS.x,BED_HIGH-WHEEL-BED.y*.5-.06,back_end+.08)
		block(body,Vector3(.05,hip.y+WHEEL-LEG_GAP,.05),hip-Vector3(0,(hip.y+WHEEL-LEG_GAP)*.5,0),dark)
	# The axle and the two wheels: hub, eight spokes, a felloe and its tyre.
	pole(body,Vector3(-BED.x*.5-.1,0,0),Vector3(BED.x*.5+.1,0,0),.025,iron())
	var wheels: Array = []
	for side in [-1.0,1.0]:
		var wheel = Node3D.new()
		wheel.position = Vector3(side*(BED.x*.5+.08),0,0)
		body.add_child(wheel)
		var on_axis = Basis(Vector3(0,-1,0),Vector3(1,0,0),Vector3(0,0,1))
		var hub = CylinderMesh.new()
		hub.top_radius = .06; hub.bottom_radius = .07; hub.height = .1; hub.radial_segments = 12
		var hub_piece = MeshInstance3D.new()
		hub_piece.mesh = hub
		hub_piece.material_override = dark
		hub_piece.basis = on_axis
		wheel.add_child(hub_piece)
		for k in 8:
			var angle: float = k*TAU/8.0
			var out = Vector3(0,cos(angle),sin(angle))
			pole(wheel,out*.05,out*(WHEEL-.05),.016,timber)
		for ring in [[WHEEL-.065,WHEEL-.02,timber],[WHEEL-.022,WHEEL,iron()]]:
			var torus = TorusMesh.new()
			torus.inner_radius = ring[0]; torus.outer_radius = ring[1]
			torus.rings = 28; torus.ring_segments = 6
			var round_piece = MeshInstance3D.new()
			round_piece.mesh = torus
			round_piece.material_override = ring[2]
			round_piece.basis = on_axis
			wheel.add_child(round_piece)
		wheels.append(wheel)
	# The cloth, and the loaves on it.
	var linen = StandardMaterial3D.new()
	linen.albedo_texture = load("res://assets/textures/cloth_linen.jpg")
	linen.albedo_color = Color(.5,.38,.25)
	linen.roughness = 1.0
	block(body,Vector3(BED.x-.06,.012,BED.z-.08),middle+Vector3(0,BED.y*.5+.006,0),linen)
	# (A layer laid side by side in rows across the bed, the rest heaped on it.)
	for i in LOAVES:
		var low: bool = i < 14
		var high: float = BED.y*.5+.012+(.05 if low else .11)
		var spot: Vector3
		if low: spot = Vector3(-.27+(i%3)*.27+rng.randf_range(-.03,.03),high,-.5+(i/3)*.25+rng.randf_range(-.03,.03))
		else: spot = Vector3(rng.randf_range(-.24,.24),high,rng.randf_range(-.35,.35))
		var bread = loaf(rng)
		bread.position = middle+spot
		bread.rotation = Vector3(rng.randf_range(-.15,.15),rng.randf_range(0,TAU),rng.randf_range(-.1,.1))
		body.add_child(bread)
	return {"node":root,"body":body,"wheels":wheels,"grips":[Vector3(-GRIPS.x,GRIPS.y,GRIPS.z),Vector3(GRIPS.x,GRIPS.y,GRIPS.z)]}

# A loaf: long and scored, or round; its crust baked brown, paler where it
# split. Its middle at its origin.
static func loaf(rng: RandomNumberGenerator) -> MeshInstance3D:
	var round_loaf: bool = rng.randf() < .35
	var shape = SphereMesh.new()
	shape.radius = .08
	shape.height = .11
	shape.radial_segments = 14
	shape.rings = 7
	var bread = MeshInstance3D.new()
	bread.name = "Loaf"
	bread.mesh = shape
	bread.scale = Vector3(1.05,.78,1.05) if round_loaf else Vector3(.82,.74,1.75)
	if not cache.has("crust"):
		var crust = ShaderMaterial.new()
		crust.shader = load("res://assets/shaders/crust.gdshader")
		cache.crust = crust
	bread.material_override = cache.crust
	return bread

# A wide-brimmed hat of plaited straw (assets/shaders/straw.gdshader): its
# crown CROWN high and HEAD_ROUND across at its band, its brim BRIM out from
# the band, drooping a little at the edge; a band of dark cord round it. Its
# origin at the middle of the crown's foot (where it sits on the head).
const CROWN = .11
const HEAD_ROUND = .105
const BRIM = .17
static func straw_hat() -> Node3D:
	var hat = Node3D.new()
	hat.name = "StrawHat"
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A profile from the crown's top to the brim's edge: [radius, height],
	# with how far along the winding (UV.y) each point is.
	var profile: Array = [[0.0,CROWN+.012],[HEAD_ROUND*.55,CROWN+.008],[HEAD_ROUND*.9,CROWN-.01],[HEAD_ROUND*.97,CROWN*.5],[HEAD_ROUND,0.0],
		[HEAD_ROUND+BRIM*.35,-.006],[HEAD_ROUND+BRIM*.75,-.018],[HEAD_ROUND+BRIM,-.034],[HEAD_ROUND+BRIM+.006,-.03]]
	var along: Array = [0.0]
	for i in range(1,profile.size()):
		along.append(along[-1]+Vector2(profile[i][0]-profile[i-1][0],profile[i][1]-profile[i-1][1]).length())
	var segments = 36
	for i in profile.size()-1:
		for k in segments:
			var corners = [[i,k],[i+1,k],[i+1,k+1],[i,k],[i+1,k+1],[i,k+1]]
			for c in corners:
				var p: Array = profile[c[0]]
				var angle: float = float(c[1])/segments*TAU
				var radius: float = p[0]*(1.0+.03*sin(angle*3.0+1.0)*smoothstep(HEAD_ROUND,HEAD_ROUND+BRIM,p[0]))
				tool.set_uv(Vector2(float(c[1])/segments,along[c[0]]/along[-1]))
				tool.add_vertex(Vector3(cos(angle)*radius,p[1],sin(angle)*radius))
	tool.generate_normals()
	var straw = MeshInstance3D.new()
	straw.mesh = tool.commit()
	if not cache.has("straw"):
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/straw.gdshader")
		cache.straw = m
	straw.material_override = cache.straw
	hat.add_child(straw)
	var cord = CylinderMesh.new()
	cord.top_radius = HEAD_ROUND*.985; cord.bottom_radius = HEAD_ROUND+.003; cord.height = .022; cord.radial_segments = 36
	var band = MeshInstance3D.new()
	band.mesh = cord
	band.position = Vector3(0,.016,0)
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(.24,.16,.1)
	dark.roughness = .9
	band.material_override = dark
	hat.add_child(band)
	return hat

# Puts the hat on a townsperson (scripts/townsperson.gd): on his head bone,
# its crown's foot a little below the top of his head (found from the head's
# own vertices), tipped back a touch.
const SITS = .075
static func put_on(hat: Node3D, body: Node3D) -> void:
	var skeleton: Skeleton3D = body.skeleton
	var head: int = skeleton.find_bone("Head")
	var top = -INF
	var middle = Vector3.ZERO
	var count = 0
	for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
		if mesh.name != "Body" or mesh.skin == null: continue
		var bind = -1
		for b in mesh.skin.get_bind_count():
			if mesh.skin.get_bind_name(b) == "Head" or mesh.skin.get_bind_bone(b) == head: bind = b
		var arrays = mesh.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size()/maxi(points.size(),1)
		for i in points.size():
			var on_head = 0.0
			for k in per:
				if bones[i*per+k] == bind: on_head += weights[i*per+k]
			if on_head > .5:
				top = maxf(top,points[i].y)
				middle += points[i]
				count += 1
	middle /= maxi(count,1)
	var attach = BoneAttachment3D.new()
	attach.bone_name = "Head"
	skeleton.add_child(attach)
	attach.add_child(hat)
	var at_rest = Transform3D(Basis(Vector3.RIGHT,-.12),Vector3(middle.x,top-SITS,middle.z-.01))
	hat.transform = skeleton.get_bone_global_rest(head).affine_inverse()*at_rest
