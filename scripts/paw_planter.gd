extends "res://scripts/foot_planter.gd"
## The Lion Guardian's feet: the foot planter (scripts/foot_planter.gd) for an
## animal on four legs.
##
## Each paw the animation sets down is pinned to its spot on the ground, and
## two-bone IK bends the leg to keep it there while the body moves above it:
## rearing to strike, flinching, turning on the spot. A paw the body leaves
## too far behind steps over, one at a time.
##
## Driven over the ground by a blow, the lion walks with it as the other units
## do, on four legs: the diagonal pairs of paws step in turn (a fore paw with
## the opposite hind paw), each landing a little ahead of the body the way it
## is carried, so one struck from the front backs away, one struck from the
## side steps across. Its body rocks the way it is driven.

const LEGS = [
	["upperarm_l","forearm_l","forepaw_l","foretoes_l",0],["upperarm_r","forearm_r","forepaw_r","foretoes_r",1],
	["thigh_l","shin_l","hindpaw_l","hindtoes_l",1],["thigh_r","shin_r","hindpaw_r","hindtoes_r",0]]
# How far the animated paw may stray from its pinned spot before it steps
# over (metres, at life size); carried, a pair steps much sooner.
const PAW_STRAY = .2
const PAW_STEP_TIME = .15
const PAW_STEP_LIFT = .09
# The pair of paws that stepped last while carried, and the one stepping now.
var last_pair = -1
var stepping_pair = -1

func setup(skeleton: Skeleton3D) -> void:
	feet.clear()
	rock_bone = "spine"
	for leg in LEGS:
		var toes = skeleton.find_bone(leg[3])
		if toes < 0: continue
		# (`foot` is the paw, from the wrist or hock down; `ball` its toes,
		# whose joint is what stands on the ground.)
		feet.append({
			"thigh":skeleton.find_bone(leg[0]),"calf":skeleton.find_bone(leg[1]),"foot":skeleton.find_bone(leg[2]),"ball":toes,"pair":leg[4],
			"ball_rest":skeleton.get_bone_global_rest(toes).origin.y,
			"pinned":false,"pin":Vector3.ZERO,"weight":0.0,"step":-1.0,"step_from":Vector3.ZERO,"gait":false,"way":Vector3.ZERO,"target":Transform3D()})

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or feet.is_empty(): return
	var to_world: Transform3D = skeleton.global_transform
	var size: float = to_world.basis.get_scale().x
	var to_skeleton: Transform3D = to_world.affine_inverse()
	var pace = Vector3(velocity.x,0,velocity.z)
	var way: Vector3 = pace.normalized() if pace.length() > .05 else Vector3.ZERO
	var gait = carried and way != Vector3.ZERO
	# Carried, which pair steps next: the other one from the last, or to begin
	# with the pair of the paw furthest along the way the body is going.
	var now_stepping = -1
	for f in feet:
		if f.step >= 0.0: now_stepping = f.pair
	if now_stepping < 0 and stepping_pair >= 0: last_pair = stepping_pair
	stepping_pair = now_stepping
	var next_pair = -1
	if not gait: last_pair = -1
	elif stepping_pair >= 0: next_pair = stepping_pair
	elif last_pair >= 0: next_pair = 1-last_pair
	else:
		var furthest = -INF
		for f in feet:
			if f.pinned and f.pin.dot(way) > furthest:
				furthest = f.pin.dot(way)
				next_pair = f.pair
	for f in feet:
		var animated: Vector3 = to_world*skeleton.get_bone_global_pose(f.ball).origin
		var floor_height: float = ground+f.ball_rest*size
		var down: bool = animated.y-floor_height < BALL_SLACK*size
		if not enabled:
			f.pinned = false
			f.step = -1.0
		elif f.pinned:
			if not down:
				# The animation lifts the paw: let it go.
				f.pinned = false
				f.step = -1.0
			elif f.step < 0.0:
				var later: Vector3 = animated+owed
				var stray = minf(Vector2(animated.x-f.pin.x,animated.z-f.pin.z).length(),Vector2(later.x-f.pin.x,later.z-f.pin.z).length())/size
				# Standing, one paw steps at a time; carried, the two of a
				# pair step together, and the other pair waits for them.
				var due = stray > PAW_STRAY
				if gait: due = (f.pair == next_pair and stray > GAIT_STRAY) or stray > PAW_STRAY*1.5
				var blocked = feet.any(func(o): return o != f and o.step >= 0.0 and not (gait and o.pair == f.pair))
				if due and not blocked:
					f.step = 0.0
					f.step_from = f.pin
					f.gait = gait
					f.way = way
					stepping_pair = f.pair
			if f.pinned and f.step >= 0.0:
				# Stepping over to where the animation wants the paw, lifted on
				# an arc; carried, it lands a little ahead of where the body
				# will be, as far as it goes.
				var landing: Vector3 = animated
				if f.gait and carried:
					var time_left = (1.0-f.step)*PAW_STEP_TIME
					landing += f.way*minf(owed.length(),pace.length()*(time_left+PAW_STEP_TIME*GAIT_LEAD))
				landing.y = floor_height
				f.step = minf(1.0,f.step+delta/PAW_STEP_TIME)
				f.pin = f.step_from.lerp(landing,smooth(f.step))+Vector3.UP*sin(f.step*PI)*PAW_STEP_LIFT*size
				if f.step >= 1.0:
					f.step = -1.0
					f.pin = landing
		elif down:
			# Set down: pinned where it lands, which is where it is shown if
			# it was still easing off its last spot (so it never jumps).
			f.pinned = true
			f.pin = animated.lerp(f.pin,f.weight) if f.weight > 0.0 else animated
			f.step = -1.0
		f.weight = move_toward(f.weight,1.0 if f.pinned else 0.0,delta/(GRAB_TIME if f.pinned else RELEASE_TIME))
		# The paw keeps the angle the animation gives it, standing on the pin.
		var paw: Transform3D = to_world*skeleton.get_bone_global_pose(f.foot)
		paw.origin += animated.lerp(f.pin,f.weight)-animated
		f.target = to_skeleton*paw
	# Its forelegs hang from the spine that rocks, so the body rocks first
	# and the legs then reach back to their paws.
	rock(skeleton,to_skeleton,delta)
	for f in feet:
		if f.weight > 0.0: reach(skeleton,f,f.target)
