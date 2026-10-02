extends SkeletonModifier3D
## Keeps a unit's feet planted while it isn't travelling (standing, turning on
## the spot, attacking, flinching, and while one clip blends into another).
##
## Wherever the animation sets a foot down, the foot is pinned to that spot on
## the ground in the world, and two-bone IK bends the leg to keep it there as
## the body moves above it. When the animation lifts the foot, it is released
## and eases back onto the animated swing. If the body turns or shifts so far
## that the animated foot strays well away from its pinned spot, the foot takes
## a quick lifted step over to it, so turning in place reads as stepping round
## rather than pivoting on ice. While the unit runs, dashes or leaps, the feet
## follow the animation untouched (the run cycle is played at the unit's own
## ground speed instead, scripts/visual.gd).
##
## Runs as the skeleton's first modifier (before the cloth simulation), each
## tick through Skeleton3D.advance (scripts/visual.gd).

# Set each tick by the unit's Visual.
var enabled = true
# The ground's height, in the world.
var ground = 0.0

# How far above its rest height (metres, at life size) a foot may be and still
# count as set down.
const ANKLE_SLACK = .045
const BALL_SLACK = .035
# How far the animated foot may stray from its pinned spot, and how far it may
# turn from it, before the foot steps over.
const STRAY = .16
const TURN = .6
# A step's duration and the height its arc lifts the foot.
const STEP_TIME = .16
const STEP_LIFT = .06
# How quickly a foot is pinned and let go.
const GRAB_TIME = .06
const RELEASE_TIME = .1

var feet: Array = []

func setup(skeleton: Skeleton3D) -> void:
	feet.clear()
	for side in ["l","r"]:
		var foot = skeleton.find_bone("foot_"+side)
		var ball = skeleton.find_bone("ball_"+side)
		if foot < 0 or ball < 0: continue
		feet.append({
			"thigh":skeleton.find_bone("thigh_"+side),"calf":skeleton.find_bone("calf_"+side),
			"foot":foot,"ball":ball,
			"ankle_rest":skeleton.get_bone_global_rest(foot).origin.y,
			"ball_rest":skeleton.get_bone_global_rest(ball).origin.y,
			"pinned":false,"pin":Transform3D(),"weight":0.0,
			"step":-1.0,"step_from":Transform3D()})

static func smooth(u: float) -> float:
	u = clampf(u,0.0,1.0)
	return u*u*(3.0-2.0*u)

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or feet.is_empty(): return
	var to_world: Transform3D = skeleton.global_transform
	var size: float = to_world.basis.get_scale().x
	var to_skeleton: Transform3D = to_world.affine_inverse()
	for f in feet:
		var animated: Transform3D = to_world*skeleton.get_bone_global_pose(f.foot)
		var ball: Vector3 = to_world*skeleton.get_bone_global_pose(f.ball).origin
		var down: bool = animated.origin.y-ground < (f.ankle_rest+ANKLE_SLACK)*size and ball.y-ground < (f.ball_rest+BALL_SLACK)*size
		if not enabled:
			f.pinned = false
			f.step = -1.0
		elif f.pinned:
			if not down:
				# The animation lifts the foot: let it go.
				f.pinned = false
				f.step = -1.0
			elif f.step < 0.0:
				var stray = Vector2(animated.origin.x-f.pin.origin.x,animated.origin.z-f.pin.origin.z).length()/size
				var heading_now: Vector3 = animated.basis.z; heading_now.y = 0
				var heading_pin: Vector3 = f.pin.basis.z; heading_pin.y = 0
				var turned = heading_now.angle_to(heading_pin) if heading_now.length() > .01 and heading_pin.length() > .01 else 0.0
				# One foot steps at a time: the other waits until it lands.
				if (stray > STRAY or turned > TURN) and not feet.any(func(o): return o != f and o.step >= 0.0):
					f.step = 0.0
					f.step_from = f.pin
			if f.pinned and f.step >= 0.0:
				# Stepping over to where the animation wants the foot, lifted
				# on an arc, landing in its new place.
				f.step = minf(1.0,f.step+delta/STEP_TIME)
				var u = smooth(f.step)
				var moved: Transform3D = f.step_from.interpolate_with(animated,u)
				moved.origin.y += sin(f.step*PI)*STEP_LIFT*size
				f.pin = moved
				if f.step >= 1.0:
					f.step = -1.0
					f.pin = animated
		elif down:
			# Set down: pinned where it lands, which is where it is shown if
			# it was still easing off its last spot (so it never jumps).
			f.pinned = true
			f.pin = animated.interpolate_with(f.pin,f.weight) if f.weight > 0.0 else animated
			f.step = -1.0
		f.weight = move_toward(f.weight,1.0 if f.pinned else 0.0,delta/(GRAB_TIME if f.pinned else RELEASE_TIME))
		if f.weight <= 0.0: continue
		var target: Transform3D = animated.interpolate_with(f.pin,f.weight)
		reach(skeleton,f,to_skeleton*target)

# Two-bone IK: bends the thigh and calf so the ankle reaches `target` (in the
# skeleton's space), the knee kept in the plane the animation bent it in, and
# sets the foot's orientation to the target's.
func reach(skeleton: Skeleton3D, f: Dictionary, target: Transform3D) -> void:
	var thigh: Transform3D = skeleton.get_bone_global_pose(f.thigh)
	var calf: Transform3D = skeleton.get_bone_global_pose(f.calf)
	var foot: Transform3D = skeleton.get_bone_global_pose(f.foot)
	var hip: Vector3 = thigh.origin
	var knee: Vector3 = calf.origin
	var ankle: Vector3 = foot.origin
	var upper = knee.distance_to(hip)
	var lower = ankle.distance_to(knee)
	if upper < 1e-4 or lower < 1e-4: return
	var goal: Vector3 = target.origin
	var to_goal: Vector3 = goal-hip
	var length = clampf(to_goal.length(),absf(upper-lower)+1e-3,upper+lower-1e-3)
	if to_goal.length() < 1e-5: return
	var direction: Vector3 = to_goal.normalized()
	goal = hip+direction*length
	# The knee's bend: away from the line hip to ankle, as animated.
	var bend: Vector3 = knee-(hip+(ankle-hip).normalized()*(knee-hip).dot((ankle-hip).normalized()))
	bend = bend-direction*bend.dot(direction)
	if bend.length() < 1e-4: bend = Vector3(0,0,1)-direction*direction.z
	bend = bend.normalized()
	var along = (upper*upper-lower*lower+length*length)/(2.0*length)
	var new_knee: Vector3 = hip+direction*along+bend*sqrt(maxf(0.0,upper*upper-along*along))
	var swing1 := Quaternion((knee-hip).normalized(),(new_knee-hip).normalized())
	var new_thigh := Transform3D(Basis(swing1)*thigh.basis,hip)
	var shin: Vector3 = swing1*(ankle-knee)
	var swing2 := Quaternion(shin.normalized(),(goal-new_knee).normalized())
	var new_calf := Transform3D(Basis(swing2)*Basis(swing1)*calf.basis,new_knee)
	skeleton.set_bone_global_pose(f.thigh,new_thigh)
	skeleton.set_bone_global_pose(f.calf,new_calf)
	skeleton.set_bone_global_pose(f.foot,Transform3D(target.basis.orthonormalized().scaled_local(foot.basis.get_scale()),goal))
