extends SkeletonModifier3D
## Keeps a seated woman's hands on top of her lap (scripts/townsfolk.gd
## lap_lift). The library's sitting clips lay the hands on the thighs of the
## bare body; a woman's thighs are fuller, and her skirt stands up over them,
## so her hands sank into her lap and were lost in it. While she sits
## (`weight`), each hand that is where the clip rests it (`rest`, in the
## skeleton's space) is raised by `lift` (as far as it has to be to lie on
## her lap: measured once from her own meshes), the arm bending at shoulder
## and elbow to carry it there and the hand kept as the clip turns it. A hand
## the clip lifts from her lap (talking, reaching for a mug) is let be.
## Runs after the clip and before the arms' reach (scripts/arm_reach.gd), so
## a sip still takes the hand where it must go.
var weight = 0.0
var lift: Dictionary = {"l":0.0,"r":0.0}
var rest: Dictionary = {"l":Vector3.INF,"r":Vector3.INF}
# How near its resting place a hand must be to be raised fully, and past
# which it is not raised at all.
const NEAR = Vector2(.06,.18)

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or weight <= 0.0: return
	for side in ["l","r"]:
		if lift[side] <= 0.0 or rest[side] == Vector3.INF: continue
		var upper: int = skeleton.find_bone("upperarm_"+side)
		var lower: int = skeleton.find_bone("lowerarm_"+side)
		var hand: int = skeleton.find_bone("hand_"+side)
		if upper < 0 or lower < 0 or hand < 0: continue
		var shoulder: Transform3D = skeleton.get_bone_global_pose(upper)
		var elbow: Transform3D = skeleton.get_bone_global_pose(lower)
		var wrist: Transform3D = skeleton.get_bone_global_pose(hand)
		var near: float = 1.0-smoothstep(NEAR.x,NEAR.y,wrist.origin.distance_to(rest[side]))
		if near <= 0.0: continue
		var goal: Vector3 = wrist.origin+Vector3.UP*lift[side]*near*weight
		var a: float = shoulder.origin.distance_to(elbow.origin)
		var b: float = elbow.origin.distance_to(wrist.origin)
		var to_goal: Vector3 = goal-shoulder.origin
		var length: float = clampf(to_goal.length(),absf(a-b)+1e-3,a+b-1e-3)
		var direction: Vector3 = to_goal.normalized()
		goal = shoulder.origin+direction*length
		# The elbow kept bent the way it was.
		var bend: Vector3 = elbow.origin-shoulder.origin
		bend -= direction*bend.dot(direction)
		if bend.length() < 1e-4: continue
		var along: float = (a*a-b*b+length*length)/(2.0*length)
		var new_elbow: Vector3 = shoulder.origin+direction*along+bend.normalized()*sqrt(maxf(0.0,a*a-along*along))
		var swing1 := Quaternion((elbow.origin-shoulder.origin).normalized(),(new_elbow-shoulder.origin).normalized())
		skeleton.set_bone_global_pose(upper,Transform3D(Basis(swing1)*shoulder.basis,shoulder.origin))
		var forearm: Vector3 = swing1*(wrist.origin-elbow.origin)
		var swing2 := Quaternion(forearm.normalized(),(goal-new_elbow).normalized())
		skeleton.set_bone_global_pose(lower,Transform3D(Basis(swing2)*Basis(swing1)*elbow.basis,new_elbow))
		skeleton.set_bone_global_pose(hand,Transform3D(wrist.basis,goal))
