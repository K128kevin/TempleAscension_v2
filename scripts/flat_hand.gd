extends SkeletonModifier3D
## Lays a hand open and flat, its fingers out straight as they are at rest
## and its thumb laid out beside them in the palm's own plane, as far as
## `weight` says: Selene's palm pressed down on her rag as she wipes, or
## turned up under a stack of plates (scripts/townsfolk.gd). The library's
## clips hold a hand loosely curled (on a rag it looked like a claw), and
## its thumb, at rest, stands out from the palm (up through a plate on an
## upturned palm, down into the table under a rag). Runs after the arm's
## reach (scripts/arm_reach.gd), which may curl the same fingers round a
## handle.
const FINGERS = ["index","middle","ring","pinky"]
# How far the laid-out thumb points out to the side (toward its own side,
# across the palm), the rest of it along the fingers.
const THUMB_OUT = .55
var side = "l"
var weight = 0.0
# Plates carried on the palm: the wrist taken to WRIST from the shoulder as
# it stands now (ahead, below, out: in her own frame), moved on by `reach`
# (in the world), the elbow bent low and a little out beneath it, so the
# forearm comes up to the hand from below, and the hand turned to `level`
# (a basis in the world), as far as `level_weight` says.
const WRIST = Vector3(.03,-.07,.22)
var reach = Vector3.ZERO
# Whose hand it is (so her own frame is as she stands this moment, turned
# as she is now turned), and her hand turned up in that frame.
var figure: Node3D
var turned_up = Basis.IDENTITY
# Her own out (toward this hand's side) and forward, in the world.
var out = Vector3.RIGHT
var forward = Vector3.BACK
var level = Basis.IDENTITY
var level_weight = 0.0
var bones: Array[int] = []
var thumb: Array[int] = []
# The hand's own measure, in its bone's space: along the fingers, and
# across the palm toward the thumb.
var along = Vector3.UP
var across = Vector3.BACK
# Out of the palm, in the hand bone's space.
var face = Vector3.RIGHT
# Under plates, the fingers turned up off the line of the palm by FINGERS_UP
# (at their roots) and the thumb laid down off it by THUMB_DOWN, so the
# palm, its fingers and the thumb's root all bear the plate between them.
const FINGERS_UP = .05
const THUMB_DOWN = .5

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or (weight <= 0.0 and level_weight <= 0.0): return
	var hand: int = skeleton.find_bone("hand_"+side)
	if hand < 0: return
	if level_weight > 0.0: carry_level(skeleton,hand)
	if weight <= 0.0: return
	if bones.is_empty():
		for finger in FINGERS:
			for joint in 3:
				var bone = skeleton.find_bone("%s_0%d_%s" % [finger,joint+1,side])
				if bone >= 0: bones.append(bone)
		for joint in 3:
			var bone = skeleton.find_bone("thumb_0%d_%s" % [joint+1,side])
			if bone >= 0: thumb.append(bone)
		var inverse: Transform3D = skeleton.get_bone_global_rest(hand).affine_inverse()
		var at = func(name: String) -> Vector3: return inverse*skeleton.get_bone_global_rest(skeleton.find_bone("%s_%s" % [name,side])).origin
		along = at.call("middle_01").normalized()
		var span: Vector3 = at.call("index_01")-at.call("pinky_01")
		across = (span-along*span.dot(along)).normalized()
		face = along.cross(across)
		if face.dot(at.call("thumb_02")-at.call("middle_01")*.5) < 0.0: face = -face
	for bone in bones:
		var flat: Quaternion = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(flat,weight))
	if level_weight > 0.0: fingers_up(skeleton,hand)
	if thumb.size() < 2: return
	# The thumb: its root turned so that it points out along the palm's
	# plane, its joints straight.
	for k in range(1,thumb.size()):
		var flat: Quaternion = skeleton.get_bone_rest(thumb[k]).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(thumb[k],skeleton.get_bone_pose_rotation(thumb[k]).slerp(flat,weight))
	var palm: Basis = skeleton.get_bone_global_pose(hand).basis.orthonormalized()
	var root: Transform3D = skeleton.get_bone_global_pose(thumb[0])
	var tip: Vector3 = skeleton.get_bone_global_pose(thumb[1]).origin
	var now: Vector3 = (tip-root.origin).normalized()
	var want: Vector3 = (palm*(across*THUMB_OUT+along*(1.0-THUMB_OUT))).normalized()
	if level_weight > 0.0: want = (want-(palm*face).normalized()*THUMB_DOWN*level_weight).normalized()
	if now.length() < .5: return
	var turn = Quaternion(now,want)
	turn = Quaternion.IDENTITY.slerp(turn,weight)
	skeleton.set_bone_global_pose(thumb[0],Transform3D(Basis(turn)*root.basis,root.origin))

func carry_level(skeleton: Skeleton3D, hand: int) -> void:
	if figure != null:
		var frame: Basis = figure.global_transform.basis.orthonormalized()
		level = frame*turned_up
		out = frame.x
		forward = frame.z
	var upper: int = skeleton.find_bone("upperarm_"+side)
	var lower: int = skeleton.find_bone("lowerarm_"+side)
	if upper < 0 or lower < 0: return
	var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
	var shoulder: Transform3D = skeleton.get_bone_global_pose(upper)
	var elbow: Transform3D = skeleton.get_bone_global_pose(lower)
	var wrist: Transform3D = skeleton.get_bone_global_pose(hand)
	var a: float = shoulder.origin.distance_to(elbow.origin)
	var b: float = elbow.origin.distance_to(wrist.origin)
	var from_shoulder: Vector3 = skeleton.global_transform*shoulder.origin
	var wanted: Vector3 = from_shoulder+out*WRIST.x+Vector3.UP*WRIST.y+forward*WRIST.z+reach
	var goal: Vector3 = wrist.origin.lerp(to_skeleton*wanted,level_weight)
	var to_goal: Vector3 = goal-shoulder.origin
	var length: float = clampf(to_goal.length(),absf(a-b)+1e-3,a+b-1e-3)
	var direction: Vector3 = to_goal.normalized()
	goal = shoulder.origin+direction*length
	# (Below the line from shoulder to wrist, a little out to her side and
	# back: `level`'s own frame is hers, turned palm up.)
	var hint: Vector3 = (to_skeleton.basis*(Vector3.DOWN+out*.35-forward*.15)).normalized()
	var bend: Vector3 = hint-direction*hint.dot(direction)
	if bend.length() < 1e-4: return
	var along: float = (a*a-b*b+length*length)/(2.0*length)
	var new_elbow: Vector3 = shoulder.origin+direction*along+bend.normalized()*sqrt(maxf(0.0,a*a-along*along))
	var swing1 := Quaternion((elbow.origin-shoulder.origin).normalized(),(new_elbow-shoulder.origin).normalized())
	skeleton.set_bone_global_pose(upper,Transform3D(Basis(swing1)*shoulder.basis,shoulder.origin))
	var forearm: Vector3 = swing1*(wrist.origin-elbow.origin)
	var swing2 := Quaternion(forearm.normalized(),(goal-new_elbow).normalized())
	skeleton.set_bone_global_pose(lower,Transform3D(Basis(swing2)*Basis(swing1)*elbow.basis,new_elbow))
	var want: Basis = (to_skeleton.basis.orthonormalized()*level).orthonormalized()
	var turn: Quaternion = wrist.basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(),level_weight)
	skeleton.set_bone_global_pose(hand,Transform3D(Basis(turn).scaled(wrist.basis.get_scale()),goal))

# Each finger turned up at its root toward the palm's face.
func fingers_up(skeleton: Skeleton3D, hand: int) -> void:
	var up: Vector3 = (skeleton.get_bone_global_pose(hand).basis.orthonormalized()*face).normalized()
	for finger in FINGERS:
		var root: int = skeleton.find_bone("%s_01_%s" % [finger,side])
		var next: int = skeleton.find_bone("%s_02_%s" % [finger,side])
		if root < 0 or next < 0: continue
		var pose: Transform3D = skeleton.get_bone_global_pose(root)
		var way: Vector3 = (skeleton.get_bone_global_pose(next).origin-pose.origin).normalized()
		var axis: Vector3 = way.cross(up)
		if axis.length() < 1e-4: continue
		skeleton.set_bone_global_pose(root,Transform3D(Basis(axis.normalized(),FINGERS_UP*level_weight)*pose.basis,pose.origin))
