extends MeshInstance3D
## The beer in a mug (scripts/townsfolk.gd: Anya pours it, a drinker sips it
## down): its surface, a level disc kept horizontal however the mug is held
## (top-level, placed afresh every moment: settle), as wide as the mug inside
## and drawn out the way the mug leans (a cylinder cut by a level plane is an
## ellipse), its middle on the mug's own axis at the height its `fill` (0
## empty, 1 full) says, and never above the low side of the rim, so tipped to
## the lips it comes to the rim there. Amber, with a head of foam on a fresh
## pour (FOAM_FROM full and above) that goes as it is drunk.
const Person = preload("res://scripts/townsperson.gd")
# Inside the mug (its own unit box): how far up its floor stands, and how
# far below the rim a full one comes; how wide it is inside, as a share of
# the rim (Person.MUG_RIM_RADIUS); how far a lean may draw the surface out.
const FLOOR = .1
const BRIM = .07
const INSIDE = .86
const STRETCH = 2.2
const FOAM_FROM = .72
const AMBER = Color(.56,.31,.07)
const FOAM = Color(.93,.88,.76)
static var disc: CylinderMesh

var mug: Node3D
var fill = 0.0:
	set(value):
		fill = clampf(value,0.0,1.0)
		visible = fill > .005
		if visible and is_inside_tree(): settle()
		var head: float = smoothstep(FOAM_FROM,1.0,fill)
		material.albedo_color = AMBER.lerp(FOAM,head)
		material.roughness = lerpf(.18,.85,head)
var material = StandardMaterial3D.new()

# The beer in `mug`, made if it has none (`fill` then 0).
static func of(mug: Node3D):
	if mug.has_meta("beer") and is_instance_valid(mug.get_meta("beer")): return mug.get_meta("beer")
	var beer = new()
	beer.name = "Beer"
	beer.mug = mug
	if disc == null:
		disc = CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = .002
		disc.radial_segments = 18
		disc.rings = 1
	beer.mesh = disc
	beer.material.metallic_specular = .6
	beer.material_override = beer.material
	beer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beer.top_level = true
	mug.add_child(beer)
	mug.set_meta("beer",beer)
	beer.fill = 0.0
	beer.settle()
	return beer

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
	if not visible or not is_instance_valid(mug) or not mug.is_inside_tree(): return
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
