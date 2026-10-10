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
# How far the elbow swings out from the body (0 down, as the arm hangs; 1
# well out to the side and forward, as a drinker's lifting a mug to his
# mouth), so the arm never folds into the chest.
var splay = 0.0
# How fast the fingers bend at each joint, by finger.
const FINGERS = ["index","middle","ring","pinky"]
const BEND = [.7,.75,.55]
# The axis a finger bends about, in its own bone's space.
var bend_axis = Vector3(-1,0,0)
# Holding a tool (Orion's hammer, a sword's hilt: scripts/smith.gd): `target`
# is then where the middle of the fist is, in the world, and `axis` the way
# the tool runs out of it on the thumb's side. The fist is turned so that
# the tool lies across the palm and the wrist stays straight with the
# forearm, wherever the arm has to come from.
var tool = false
var axis = Vector3.UP
# The hand's own measure, taken from its fingers at rest (in the hand bone's
# space): along the fingers, across the palm toward the thumb, and where a
# shaft closed in the fist lies.
var measured = false
var along = Vector3.UP
var across = Vector3.BACK
var palm = Vector3.ZERO

func measure(skeleton: Skeleton3D, hand: int) -> void:
	measured = true
	var inverse: Transform3D = skeleton.get_bone_global_rest(hand).affine_inverse()
	var at = func(bone: String) -> Vector3: return inverse*skeleton.get_bone_global_rest(skeleton.find_bone("%s_%s" % [bone,side])).origin
	var knuckle: Vector3 = at.call("middle_01")
	var span: Vector3 = at.call("index_01")-at.call("pinky_01")
	along = knuckle.normalized()
	across = (span-along*span.dot(along)).normalized()
	# The palm's side is the one the thumb's root lies on.
	var face: Vector3 = along.cross(across)
	if face.dot(at.call("thumb_02")-knuckle*.5) < 0.0: face = -face
	palm = knuckle*.62+face*.03

# The hand's turn (a basis in the skeleton's space) that lays its fingers
# along `fingers` and the line across its palm, toward the thumb, along `over`.
func turned(fingers: Vector3, over: Vector3) -> Basis:
	over = over.normalized()
	fingers = (fingers-over*fingers.dot(over)).normalized()
	return Basis(fingers.cross(over),fingers,over)*Basis(along.cross(across),along,across).inverse()

# Where the elbow goes for the wrist to be at `goal`: bent outward and down,
# away from the line of the arm.
func bent(shoulder: Vector3, elbow: Vector3, wrist: Vector3, goal: Vector3, a: float, b: float) -> Array:
	var to_goal: Vector3 = goal-shoulder
	var length = clampf(to_goal.length(),absf(a-b)+1e-3,a+b-1e-3)
	var direction: Vector3 = to_goal.normalized()
	goal = shoulder+direction*length
	var bend: Vector3 = elbow-(shoulder+(wrist-shoulder).normalized()*(elbow-shoulder).dot((wrist-shoulder).normalized()))
	bend = bend-direction*bend.dot(direction)
	var down = Vector3(0,-1,0)-direction*(-direction.y)
	bend = (bend.normalized()*.4+down.normalized()*.6) if bend.length() > 1e-4 else down
	if splay > 0.0:
		# Out to the arm's own side, a little forward and below the shoulder,
		# as a drinker's elbow is held out from his ribs: with the hand
		# brought in close (to the mouth), the elbow is not folded in across
		# the chest but stands off it.
		var out = Vector3(signf(shoulder.x)*1.3,-1.6,.2)
		bend = bend.normalized()*(1.0-splay*.8)+out.normalized()*splay*1.6
	bend = (bend-direction*bend.dot(direction)).normalized()
	var reach = (a*a-b*b+length*length)/(2.0*length)
	return [shoulder+direction*reach+bend*sqrt(maxf(0.0,a*a-reach*reach)),goal]

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
	var wanted: Vector3 = to_skeleton*target
	var held: Basis = (to_skeleton.basis*grip).orthonormalized()
	if tool:
		if not measured: measure(skeleton,hand)
		# The forearm's way to the tool decides how the fist is turned; the
		# wrist then sits back from the tool by the palm's depth.
		var over: Vector3 = (to_skeleton.basis*axis).normalized()
		for pass_ in 2:
			var first: Array = bent(shoulder.origin,elbow.origin,wrist.origin,wanted,a,b)
			held = turned(first[1]-first[0],over)
			wanted = to_skeleton*target-held*palm
	if (wanted-shoulder.origin).length() < 1e-5: return
	var solved: Array = bent(shoulder.origin,elbow.origin,wrist.origin,wrist.origin.lerp(wanted,weight),a,b)
	var new_elbow: Vector3 = solved[0]
	var goal: Vector3 = solved[1]
	var swing1 := Quaternion((elbow.origin-shoulder.origin).normalized(),(new_elbow-shoulder.origin).normalized())
	var new_shoulder := Transform3D(Basis(swing1)*shoulder.basis,shoulder.origin)
	var forearm: Vector3 = swing1*(wrist.origin-elbow.origin)
	var swing2 := Quaternion(forearm.normalized(),(goal-new_elbow).normalized())
	var new_elbow_pose := Transform3D(Basis(swing2)*Basis(swing1)*elbow.basis,new_elbow)
	skeleton.set_bone_global_pose(upper,new_shoulder)
	skeleton.set_bone_global_pose(lower,new_elbow_pose)
	var turn: Basis = Basis(wrist.basis.get_rotation_quaternion().slerp(held.get_rotation_quaternion(),weight)).scaled(wrist.basis.get_scale())
	skeleton.set_bone_global_pose(hand,Transform3D(turn,goal))
