extends SkeletonModifier3D
## A townsperson's arm reaching for something (scripts/townsperson.gd): the
## hand is carried to `target` (a point in the world) by two-bone IK, as far
## as `weight` says, and turned to `grip`, a basis in the world, so a mug in
## its fist stays upright; `curl` closes the fingers round the handle.
var side = "l"
var target = Vector3.ZERO
var weight = 0.0
var grip = Basis.IDENTITY
var curl = 0.0
# How fast the fingers bend at each joint, by finger.
const FINGERS = ["index","middle","ring","pinky"]
const BEND = [.7,.75,.55]
# The axis a finger bends about, in its own bone's space.
var bend_axis = Vector3(-1,0,0)

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or (weight <= 0.0 and curl <= 0.0): return
	if curl > 0.0:
		for finger in FINGERS:
			for joint in 3:
				var bone = skeleton.find_bone("%s_0%d_%s" % [finger,joint+1,side])
				if bone < 0: continue
				var turn = Quaternion(bend_axis,-curl*BEND[joint]*(1.0 if side == "l" else -1.0))
				skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*turn)
		for joint in 2:
			var bone = skeleton.find_bone("thumb_0%d_%s" % [joint+2,side])
			if bone >= 0: skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*Quaternion(bend_axis,-curl*.75*(1.0 if side == "l" else -1.0)))
	if weight <= 0.0: return
	var upper = skeleton.find_bone("upperarm_"+side)
	var lower = skeleton.find_bone("lowerarm_"+side)
	var hand = skeleton.find_bone("hand_"+side)
	var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
	var shoulder: Transform3D = skeleton.get_bone_global_pose(upper)
	var elbow: Transform3D = skeleton.get_bone_global_pose(lower)
	var wrist: Transform3D = skeleton.get_bone_global_pose(hand)
	var a = elbow.origin.distance_to(shoulder.origin)
	var b = wrist.origin.distance_to(elbow.origin)
	if a < 1e-4 or b < 1e-4: return
	var goal: Vector3 = wrist.origin.lerp(to_skeleton*target,weight)
	var to_goal: Vector3 = goal-shoulder.origin
	var length = clampf(to_goal.length(),absf(a-b)+1e-3,a+b-1e-3)
	if to_goal.length() < 1e-5: return
	var direction: Vector3 = to_goal.normalized()
	goal = shoulder.origin+direction*length
	# The elbow bends outward and down, away from the line of the arm.
	var bend: Vector3 = elbow.origin-(shoulder.origin+(wrist.origin-shoulder.origin).normalized()*(elbow.origin-shoulder.origin).dot((wrist.origin-shoulder.origin).normalized()))
	bend = bend-direction*bend.dot(direction)
	var down = Vector3(0,-1,0)-direction*(-direction.y)
	bend = (bend.normalized()*.4+down.normalized()*.6) if bend.length() > 1e-4 else down
	bend = (bend-direction*bend.dot(direction)).normalized()
	var along = (a*a-b*b+length*length)/(2.0*length)
	var new_elbow: Vector3 = shoulder.origin+direction*along+bend*sqrt(maxf(0.0,a*a-along*along))
	var swing1 := Quaternion((elbow.origin-shoulder.origin).normalized(),(new_elbow-shoulder.origin).normalized())
	var new_shoulder := Transform3D(Basis(swing1)*shoulder.basis,shoulder.origin)
	var forearm: Vector3 = swing1*(wrist.origin-elbow.origin)
	var swing2 := Quaternion(forearm.normalized(),(goal-new_elbow).normalized())
	var new_elbow_pose := Transform3D(Basis(swing2)*Basis(swing1)*elbow.basis,new_elbow)
	skeleton.set_bone_global_pose(upper,new_shoulder)
	skeleton.set_bone_global_pose(lower,new_elbow_pose)
	var held: Basis = (to_skeleton.basis*grip).orthonormalized()
	var turned: Basis = Basis(wrist.basis.get_rotation_quaternion().slerp(held.get_rotation_quaternion(),weight)).scaled(wrist.basis.get_scale())
	skeleton.set_bone_global_pose(hand,Transform3D(turned,goal))
