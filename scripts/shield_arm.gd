extends SkeletonModifier3D
## Carries a strapped shield out before the body with the arm it is strapped
## to, rather than letting the shield leave the arm.
##
## The board is laid along the left forearm (scripts/visual.gd strap_scutum).
## Where the body would come into it (the knees rising in a run, the chest
## leaning over it), the bearer's Visual sets `reach`: how far, and which way,
## the shield hand has to go to keep the board in front of them. Two-bone IK
## carries the hand that far from where the animation holds it, the shoulder
## where it is and the elbow bent in the plane the animation bent it in, so the
## forearm, and the shield on it, are held out ahead.
##
## Runs after the foot planter and the grip, on the unit's clock (scripts/visual.gd).

# Set each tick by the unit's Visual: the hand's offset, in the world.
var reach = Vector3.ZERO

var upper = -1
var lower = -1
var hand = -1

func setup(skeleton: Skeleton3D) -> void:
	upper = skeleton.find_bone("upperarm_l")
	lower = skeleton.find_bone("lowerarm_l")
	hand = skeleton.find_bone("hand_l")

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or upper < 0 or lower < 0 or hand < 0 or reach.length() < 1e-4: return
	var to_skeleton: Basis = skeleton.global_transform.basis.inverse()
	var arm: Transform3D = skeleton.get_bone_global_pose(upper)
	var fore: Transform3D = skeleton.get_bone_global_pose(lower)
	var fist: Transform3D = skeleton.get_bone_global_pose(hand)
	var shoulder: Vector3 = arm.origin
	var elbow: Vector3 = fore.origin
	var wrist: Vector3 = fist.origin
	var upper_length = elbow.distance_to(shoulder)
	var lower_length = wrist.distance_to(elbow)
	if upper_length < 1e-4 or lower_length < 1e-4: return
	var goal: Vector3 = wrist+to_skeleton*reach
	var to_goal: Vector3 = goal-shoulder
	if to_goal.length() < 1e-5: return
	var length = clampf(to_goal.length(),absf(upper_length-lower_length)+1e-3,upper_length+lower_length-1e-3)
	var direction: Vector3 = to_goal.normalized()
	goal = shoulder+direction*length
	# The elbow's bend: away from the line shoulder to wrist, as animated.
	var line: Vector3 = (wrist-shoulder).normalized()
	var bend: Vector3 = elbow-(shoulder+line*(elbow-shoulder).dot(line))
	bend = bend-direction*bend.dot(direction)
	if bend.length() < 1e-4: return
	bend = bend.normalized()
	var along = (upper_length*upper_length-lower_length*lower_length+length*length)/(2.0*length)
	var new_elbow: Vector3 = shoulder+direction*along+bend*sqrt(maxf(0.0,upper_length*upper_length-along*along))
	var swing1 := Quaternion((elbow-shoulder).normalized(),(new_elbow-shoulder).normalized())
	skeleton.set_bone_global_pose(upper,Transform3D(Basis(swing1)*arm.basis,shoulder))
	var forearm: Vector3 = swing1*(wrist-elbow)
	var swing2 := Quaternion(forearm.normalized(),(goal-new_elbow).normalized())
	skeleton.set_bone_global_pose(lower,Transform3D(Basis(swing2)*Basis(swing1)*fore.basis,new_elbow))
	# The fist keeps the way the animation turned it.
	skeleton.set_bone_global_pose(hand,Transform3D(fist.basis,goal))
