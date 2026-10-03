extends RigidBody3D
## Stone chips use the imported rock's convex hull, and sleep once at rest.
const Art = preload("res://scripts/assets.gd")
const WORLD_LAYER = 1
const DEBRIS_LAYER = 2
const LIFETIME = 8.0
# The rock's collision hull: a few of its outermost points about its centre
# (the model's every vertex made a hull far costlier to collide), and the
# hulls made from it, shared by every chip of a size.
static var hull_points = PackedVector3Array()
static var hulls: Dictionary = {}
static var center = Vector3.ZERO
static var extent = Vector3.ONE
# The rock's meshes and their places in the model, shown by every chip.
static var rock_meshes: Array = []
static var stone: PhysicsMaterial
# How many chips lie about the temple now. Past BUDGET, statues break into
# fewer, larger stones that collide with the temple but not with each other,
# so that many statues falling together do not stall the game.
const BUDGET = 216
# Past this many, a statue leaves only a few stones.
const LIMIT = 360
static var live = 0
var mask = WORLD_LAYER | DEBRIS_LAYER
var age = 0.0
var launch_impulse = Vector3.ZERO
var held = false
var launch_spin = Vector3.ZERO

# Launch velocity at contact, in world space. A ground blow lifts and throws
# fragments away from its impact point; ordinary hits give a small shove.
static func impact(direction: Vector3, blast: bool = false) -> Vector3:
	direction.y = 0
	if direction.length_squared() < .0001: direction = Vector3.FORWARD
	return direction.normalized()*(6.0 if blast else 1.3)+Vector3.UP*(3.4 if blast else .35)

# The outermost of `points` along directions all round: a hull of a few
# points in place of one of every vertex.
# (`coarse`: along the axes and the diagonals between all three only.)
static func outline(points: PackedVector3Array, coarse: bool = false) -> PackedVector3Array:
	var out = PackedVector3Array()
	for x in [-1,0,1]:
		for y in [-1,0,1]:
			for z in [-1,0,1]:
				if x == 0 and y == 0 and z == 0: continue
				if coarse and absi(x)+absi(y)+absi(z) == 2: continue
				var way = Vector3(x,y,z)
				var best = points[0]
				var reach = -INF
				for point in points:
					var d = point.dot(way)
					if d > reach: reach = d; best = point
				if not out.has(best): out.append(best)
	return out

static func prepare() -> void:
	if not rock_meshes.is_empty(): return
	var rock = Art.model("rock",Vector3.ONE)
	var vertices = PackedVector3Array()
	for mesh in rock.find_children("*","MeshInstance3D",true,false):
		var local = Transform3D.IDENTITY
		var node: Node = mesh
		while node != rock:
			local = node.transform*local
			node = node.get_parent()
		rock_meshes.append([mesh.mesh,local])
		for vertex in mesh.mesh.get_faces(): vertices.append(local*vertex)
	rock.free()
	var bounds = AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices: bounds = bounds.expand(vertex)
	center = bounds.get_center()
	for vertex in outline(vertices,true): hull_points.append(vertex-center)
	extent = bounds.size

# `light` chips (made past the BUDGET) collide with the temple only.
static func make(parent: Node3D, at: Vector3, diameter: float, velocity: Vector3, spin: Vector3, light: bool = false) -> RigidBody3D:
	prepare()
	var body = new()
	# The corpse can finish turning or being shoved without dragging the rocks.
	body.top_level = true
	body.position = at
	if light: body.mask = WORLD_LAYER
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = body.mask
	body.mass = maxf(.1,pow(diameter,3)*90.0)
	body.linear_damp = .18
	body.angular_damp = .65
	if stone == null:
		stone = PhysicsMaterial.new()
		stone.friction = .85
		stone.bounce = .22
	body.physics_material_override = stone
	for part in rock_meshes:
		var rock = MeshInstance3D.new()
		rock.mesh = part[0]
		rock.material_override = Art.statue_material()
		rock.transform = Transform3D(Basis.from_scale(Vector3.ONE*diameter),-center*diameter)*part[1]
		body.add_child(rock)
	# Chips of nearly a size share one hull (a light chip's, a plain box).
	var size = maxi(1,roundi(diameter*40.0))*(-1 if light else 1)
	if light and not hulls.has(size):
		var box = BoxShape3D.new()
		box.size = extent*(-size/40.0)*.85
		hulls[size] = box
	if not hulls.has(size):
		var points = PackedVector3Array()
		for point in hull_points: points.append(point*(size/40.0))
		var hull = ConvexPolygonShape3D.new()
		hull.points = points
		hull.margin = .005
		hulls[size] = hull
	var collision = CollisionShape3D.new()
	collision.shape = hulls[size]
	body.add_child(collision)
	body.launch_impulse = velocity*body.mass
	body.angular_velocity = spin
	body.launch_spin = spin
	parent.add_child(body)
	return body

func _enter_tree() -> void:
	live += 1

func _exit_tree() -> void:
	live -= 1

# Waiting inside the statue until its stone breaks loose there: still, unseen
# and touching nothing.
func hold() -> void:
	held = true
	freeze = true
	visible = false
	collision_layer = 0
	collision_mask = 0

func release() -> void:
	if not held: return
	held = false
	freeze = false
	visible = true
	collision_layer = DEBRIS_LAYER
	collision_mask = mask
	angular_velocity = launch_spin

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# The first physics step has the hull's mass and inertia ready. Applying
	# the impulse during construction would still use the default inverse mass.
	if launch_impulse != Vector3.ZERO:
		state.apply_central_impulse(launch_impulse)
		launch_impulse = Vector3.ZERO

func _physics_process(dt: float) -> void:
	if held: return
	age += dt
	# Also retire pieces thrown over a parapet or down a stairwell.
	if age >= LIFETIME or global_position.y < -30.0: queue_free()
