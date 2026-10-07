extends SkeletonModifier3D
## Closes the hero wizard's right fist round his staff, through every clip.
##
## His staff is held as a walking stick: at rest it stands before him, its
## top leaning back toward him a little (`upright`); running, it is carried
## along his swinging fist as the swordsman carries his sword, tipped up
## toward upright from the line of the fist (RAISE) so it is a diagonal
## across his stride rather than a couched lance (`carry`, 0 to 1, eased
## between the two by scripts/visual.gd). The clips turn the fist as they please (a cast's,
## or one clip's fading into the next), so a staff simply stood where it
## should be would pass through the back of the hand, or beside it. Here the
## hand is turned about the wrist so its grip (its own +Z, the line through
## the closed fist) lies along the way the staff should point; the game then
## lays the staff along that grip (Visual.align_walking_staff), so it always
## passes through the fist.
##
## Runs after the grip and the second hand, on the unit's clock.

# How far the carried staff is tipped from the line of the fist toward upright.
const RAISE = .25
# The way the staff stands at rest (world space, set by the unit's Visual).
var upright = Vector3.UP
# How far it is carried in the fist instead (0: at rest).
var carry = 0.0
var hand = -1

func setup(skeleton: Skeleton3D) -> void:
	hand = skeleton.find_bone("hand_r")

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or hand < 0: return
	var pose: Transform3D = skeleton.get_bone_global_pose(hand)
	var grip: Vector3 = pose.basis.z.normalized()
	var up: Vector3 = (skeleton.global_basis.inverse()*Vector3.UP).normalized()
	var rest: Vector3 = (skeleton.global_basis.inverse()*upright).normalized()
	var carried: Vector3 = grip.slerp(up,RAISE)
	var want: Vector3 = rest.slerp(carried,clampf(carry,0.0,1.0)).normalized()
	if grip.dot(want) > .99999: return
	skeleton.set_bone_global_pose(hand,Transform3D(Basis(Quaternion(grip,want))*pose.basis,pose.origin))
