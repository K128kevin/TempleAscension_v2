extends SkeletonModifier3D
## Lays a hand open and flat, its fingers out straight as they are at rest,
## as far as `weight` says: Selene's palm pressed down on her rag as she
## wipes, or turned up under a stack of plates (scripts/townsfolk.gd). The
## library's clips hold a hand loosely curled, which on a rag looked like a
## claw. Runs after the arm's reach (scripts/arm_reach.gd), which may curl the
## same fingers round a handle.
# (The thumb is left as the clip has it: laid out at rest it points down,
# into what the palm lies on.)
const FINGERS = ["index","middle","ring","pinky"]
var side = "l"
var weight = 0.0
var bones: Array[int] = []

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or weight <= 0.0: return
	if bones.is_empty():
		for finger in FINGERS:
			for joint in 3:
				var bone = skeleton.find_bone("%s_0%d_%s" % [finger,joint+1,side])
				if bone >= 0: bones.append(bone)
	for bone in bones:
		var flat: Quaternion = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(flat,weight))
