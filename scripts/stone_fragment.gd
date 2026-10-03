extends RigidBody3D
## Stone chips use the imported rock's convex hull, and sleep once at rest.
const Art = preload("res://scripts/assets.gd")
const WORLD_LAYER = 1
const DEBRIS_LAYER = 2
const LIFETIME = 8.0
static var vertices = PackedVector3Array()
static var center = Vector3.ZERO
static var stone: PhysicsMaterial
var age = 0.0
var launch_impulse = Vector3.ZERO

# Launch velocity at contact, in world space. A ground blow lifts and throws
# fragments away from its impact point; ordinary hits give a small shove.
static func impact(direction: Vector3, blast: bool = false) -> Vector3:
	direction.y = 0
	if direction.length_squared() < .0001: direction = Vector3.FORWARD
	return direction.normalized()*(6.0 if blast else 1.3)+Vector3.UP*(3.4 if blast else .35)

static func make(parent: Node3D, at: Vector3, diameter: float, velocity: Vector3, spin: Vector3) -> RigidBody3D:
	var body = new()
	# The corpse can finish turning or being shoved without dragging the rocks.
	body.top_level = true
	body.position = at
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = WORLD_LAYER | DEBRIS_LAYER
	body.mass = maxf(.1,pow(diameter,3)*90.0)
	body.continuous_cd = true
	body.linear_damp = .18
	body.angular_damp = .65
	if stone == null:
		stone = PhysicsMaterial.new()
		stone.friction = .85
		stone.bounce = .22
	body.physics_material_override = stone
	parent.add_child(body)
	var rock = Art.model("rock",Vector3.ONE*diameter,Art.statue_material())
	body.add_child(rock)
	if vertices.is_empty():
		for mesh in rock.find_children("*","MeshInstance3D",true,false):
			var local: Transform3D = rock.global_transform.affine_inverse()*mesh.global_transform
			for vertex in mesh.mesh.get_faces(): vertices.append(local*vertex)
		var bounds = AABB(vertices[0],Vector3.ZERO)
		for vertex in vertices: bounds = bounds.expand(vertex)
		center = bounds.get_center()
	rock.position = -center*diameter
	var points = PackedVector3Array()
	for vertex in vertices: points.append((vertex-center)*diameter)
	var hull = ConvexPolygonShape3D.new()
	hull.points = points
	hull.margin = .005
	var collision = CollisionShape3D.new()
	collision.shape = hull
	body.add_child(collision)
	body.launch_impulse = velocity*body.mass
	body.angular_velocity = spin
	return body

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# The first physics step has the hull's mass and inertia ready. Applying
	# the impulse during construction would still use the default inverse mass.
	if launch_impulse != Vector3.ZERO:
		state.apply_central_impulse(launch_impulse)
		launch_impulse = Vector3.ZERO

func _physics_process(dt: float) -> void:
	age += dt
	# Also retire pieces thrown over a parapet or down a stairwell.
	if age >= LIFETIME or global_position.y < -30.0: queue_free()
