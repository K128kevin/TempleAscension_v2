extends RefCounted
## A slain man falls limp: his limbs become physical bodies jointed as a man's
## are (Godot's physical bones, made as he dies), and his skeleton follows them
## down. They collide with the temple's floor, walls and props, as the statues'
## fallen stones do (Temple.ensure_debris_collision), and with nothing else.
const WORLD_LAYER = 1
const BODY_LAYER = 4
# Each part is a capsule along its bone, as far as the bone `to` (and `more`
# metres past it), hung from the part above it by its `joint`: a "cone" swings
# `swing` degrees any way from where the bone lies at rest and twists `twist`
# about itself; a "hinge" (a knee, an elbow) only folds, by up to `fold`
# degrees. The bones between two parts (the neck, a collarbone) are carried
# by the part above.
const PARTS = [
	{"bone":"pelvis","to":"spine_01","radius":.13,"mass":11.0},
	{"bone":"spine_01","to":"spine_03","radius":.12,"mass":10.0,"joint":"cone","swing":25.0,"twist":20.0},
	{"bone":"spine_03","to":"neck_01","radius":.14,"mass":13.0,"joint":"cone","swing":25.0,"twist":20.0},
	{"bone":"Head","to":"Head","more":.2,"radius":.1,"mass":5.0,"joint":"cone","swing":40.0,"twist":35.0},
	{"bone":"upperarm_l","to":"lowerarm_l","radius":.05,"mass":2.2,"joint":"cone","swing":85.0,"twist":40.0},
	{"bone":"lowerarm_l","to":"hand_l","more":.08,"radius":.04,"mass":1.6,"joint":"hinge","fold":140.0},
	{"bone":"upperarm_r","to":"lowerarm_r","radius":.05,"mass":2.2,"joint":"cone","swing":85.0,"twist":40.0},
	{"bone":"lowerarm_r","to":"hand_r","more":.08,"radius":.04,"mass":1.6,"joint":"hinge","fold":140.0},
	{"bone":"thigh_l","to":"calf_l","radius":.075,"mass":7.5,"joint":"cone","swing":55.0,"twist":15.0},
	{"bone":"calf_l","to":"foot_l","radius":.055,"mass":4.0,"joint":"hinge","fold":135.0},
	{"bone":"foot_l","to":"ball_l","more":.08,"radius":.04,"mass":1.1,"joint":"cone","swing":30.0,"twist":10.0},
	{"bone":"thigh_r","to":"calf_r","radius":.075,"mass":7.5,"joint":"cone","swing":55.0,"twist":15.0},
	{"bone":"calf_r","to":"foot_r","radius":.055,"mass":4.0,"joint":"hinge","fold":135.0},
	{"bone":"foot_r","to":"ball_r","more":.08,"radius":.04,"mass":1.1,"joint":"cone","swing":30.0,"twist":10.0},
]
# A joint's frame in its bone's own: a cone twists about the frame's X, a
# hinge folds about its Z. Every bone of the rig lies along its own Y, and its
# knees and elbows fold about their own X.
const JOINT_FRAME = Basis(Vector3(0,1,0),Vector3(0,0,1),Vector3(1,0,0))
# How much of the blow's velocity the chest and head take over the rest of
# him, toppling him away from it.
const TOPPLE = {"spine_03":.7,"Head":1.0}
const BLAST = 4.0
const BLAST_SHARE = .6
static var flesh: PhysicsMaterial

# The bodies of `skeleton`, jointed and still: null if it is not a man's.
# Joints take the pose they are made in as the middle of their range, so they
# are made with the skeleton at rest, which is then posed again as he stood.
static func make(skeleton: Skeleton3D) -> PhysicalBoneSimulator3D:
	for part in PARTS:
		if skeleton.find_bone(part.bone) < 0 or skeleton.find_bone(part.to) < 0: return null
	var posed: Array = []
	for bone in skeleton.get_bone_count(): posed.append(skeleton.get_bone_pose(bone))
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	var simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	skeleton.add_child(simulator)
	for part in PARTS: simulator.add_child(body(skeleton,part))
	for bone in posed.size(): skeleton.set_bone_pose(bone,posed[bone])
	skeleton.force_update_all_bone_transforms()
	return simulator

static func body(skeleton: Skeleton3D, part: Dictionary) -> PhysicalBone3D:
	var from: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone(part.bone)).origin
	var to: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone(part.to)).origin
	var length: float = from.distance_to(to)+part.get("more",0.0)
	var bone = PhysicalBone3D.new()
	bone.name = "Ragdoll_"+part.bone
	bone.bone_name = part.bone
	bone.body_offset = Transform3D(Basis.IDENTITY,Vector3(0,length*.5,0))
	match part.get("joint",""):
		"cone":
			bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			bone.set("joint_constraints/swing_span",part.swing)
			bone.set("joint_constraints/twist_span",part.twist)
		"hinge":
			bone.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			bone.set("joint_constraints/angular_limit_enabled",true)
			# (The hinge measures the part above against this one: folding
			# is a negative angle.)
			bone.set("joint_constraints/angular_limit_lower",-part.fold)
			bone.set("joint_constraints/angular_limit_upper",0.0)
	bone.joint_rotation = JOINT_FRAME.get_euler()
	var capsule = CapsuleShape3D.new()
	capsule.radius = part.radius
	capsule.height = maxf(length,part.radius*2.0)
	var shape = CollisionShape3D.new()
	shape.shape = capsule
	bone.add_child(shape)
	bone.mass = part.mass
	if flesh == null:
		flesh = PhysicsMaterial.new()
		flesh.friction = .9
		flesh.bounce = 0.0
	bone.friction = flesh.friction
	bone.bounce = flesh.bounce
	# A body has no muscle to hold it, but is not a puppet's loose sticks.
	bone.linear_damp = .1
	bone.angular_damp = 3.0
	bone.collision_layer = BODY_LAYER
	bone.collision_mask = WORLD_LAYER
	return bone

# Lets go of him, with the velocity of the blow that felled him (as a
# statue's stones are thrown: StoneFragment.impact).
static func drop(simulator: PhysicalBoneSimulator3D, impact: Vector3) -> void:
	simulator.physical_bones_start_simulation()
	# A blast that scatters a statue's stones throws a man off his feet, not
	# across the hall.
	if impact.length() > BLAST: impact *= BLAST_SHARE
	for bone in simulator.get_children():
		if bone is PhysicalBone3D:
			bone.linear_velocity = impact*(1.0+TOPPLE.get(String(bone.bone_name),0.0))

static func bodies(simulator: PhysicalBoneSimulator3D) -> Array:
	return simulator.get_children().filter(func(bone): return bone is PhysicalBone3D)
