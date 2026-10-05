extends SkeletonModifier3D
## Keeps the second hand on the haft of a two-handed weapon.
##
## The weapon is carried by the right hand (scripts/visual.gd arm()); the left
## holds it too, a fixed way along the haft. The clips are keyed so
## (tools/import_heavy.py, tools/import_pike.py), but between two clips, as
## one fades into the next, the hands drift apart. The left hand is carried
## back onto the haft (its palm to the point `along` metres up the weapon from
## the right fist; toward the butt if negative) by two-bone IK, the elbow bent
## in the plane the animation bent it in, the fist turned as the clip turns it.
##
## Runs after the foot planter and the grip, on the unit's clock.

# How firmly the hand is held there (0: as animated).
var weight = 0.0
var along = 0.0
# Where the haft passes through a fist, in the hand's own space.
const PALM = Vector3(0,.075,0)

var upper = -1
var lower = -1
var hand = -1
var lead = -1

func setup(skeleton: Skeleton3D) -> void:
	upper = skeleton.find_bone("upperarm_l")
	lower = skeleton.find_bone("lowerarm_l")
	hand = skeleton.find_bone("hand_l")
	lead = skeleton.find_bone("hand_r")

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or weight <= 0.0 or hand < 0: return
	var arm: Transform3D = skeleton.get_bone_global_pose(upper)
	var fore: Transform3D = skeleton.get_bone_global_pose(lower)
	var fist: Transform3D = skeleton.get_bone_global_pose(hand)
	var wanted: Vector3 = skeleton.get_bone_global_pose(lead)*(PALM+Vector3(0,0,along))-fist.basis*PALM
	var shoulder: Vector3 = arm.origin
	var elbow: Vector3 = fore.origin
	var wrist: Vector3 = fist.origin
	var upper_length = elbow.distance_to(shoulder)
	var lower_length = wrist.distance_to(elbow)
	if upper_length < 1e-4 or lower_length < 1e-4: return
	var goal: Vector3 = wrist.lerp(wanted,weight)
	var to_goal: Vector3 = goal-shoulder
	if to_goal.length() < 1e-5: return
	var length = clampf(to_goal.length(),absf(upper_length-lower_length)+1e-3,upper_length+lower_length-1e-3)
	var direction: Vector3 = to_goal.normalized()
	goal = shoulder+direction*length
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
	skeleton.set_bone_global_pose(hand,Transform3D(fist.basis,goal))
