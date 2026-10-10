extends SceneTree
## A patron at the inn takes a sip (scripts/townsfolk.gd sip), deliberately:
## with the hand on the mug's side of him, the fingers closed round its
## handle, the wrist straight all the while (the mug tipped by the whole arm),
## the near edge of the rim brought to his lips and the mug tipped back as he
## drinks, never pressed into his face; and neither his upper arm nor his
## forearm ever goes into his body.
const Data = preload("res://scripts/data.gd")
# How deep into his trunk (a capsule up his spine, TRUNK thick) the arm may
# come; how far out from the shoulder the elbow must stand, and how far above
# it it may rise, as he drinks.
const TRUNK = .13
const INTO = .03
const ELBOW_OUT = .03
const ELBOW_HIGH = .12
# The wrist's bend (degrees) at most; how near the rim comes to his lips at
# the sip; how far the mug tips (degrees) at least; how near the handle stays
# to the middle of his fist while it is held; how far (a capsule up his head,
# HEAD thick) the mug may come into it.
const WRIST = 10.0
const LIPS = .02
const TIPPED = 25.0
const FIST = .03
const HEAD = .085
const INTO_HEAD = .005
var passed = 0
var failed: Array[String] = []
var shown = {}
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)
func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/inn-sip-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	game.mode = "playing"
	var folk = game.world.townsfolk
	var sides_seen = {}
	for si in range(folk.seats.size()):
		var walker = folk.people[si]
		var seat = folk.seats[si]
		walker.seat = seat
		folk.sit(walker)
		walker.mug = preload("res://scripts/world_art.gd").prop("mug",.17)
		folk.set_down(walker.mug,seat)
		var body = walker.body
		var sk: Skeleton3D = body.skeleton
		for i in 10: await process_frame
		var near = folk.drinking_side(body,walker.mug.global_position)
		var mug_local: Vector3 = body.global_transform.affine_inverse()*walker.mug.global_position
		var hand_local = func(side: String) -> Vector3: return body.global_transform.affine_inverse()*(sk.global_transform*sk.get_bone_global_pose(sk.find_bone("hand_"+side)).origin)
		check(signf(hand_local.call(near).x) == signf(mug_local.x),"Seat %d: he drinks with the hand on the mug's side (%s)" % [si,near])
		sides_seen[near] = true
		var side: String = near
		# (The bones as last shown, his reaching arm worked out.)
		var read = func():
			for n in ["spine_01","neck_01","Head","upperarm_"+side,"lowerarm_"+side,"hand_"+side]: shown[n] = sk.global_transform*sk.get_bone_global_pose(sk.find_bone(n))
		sk.skeleton_updated.connect(read)
		walker.phase = "reach"; walker.phase_time = 0.0
		var deepest = -1.0
		var wrist_most = 0.0
		var fist_far = 0.0
		var head_into = -1.0
		var rim_gap = INF
		var tipped = 0.0
		var elbow = Vector3.ZERO
		for f in 900:
			if walker.phase == "": break
			var phase = walker.phase
			folk.sip(walker,1.0/60)
			await process_frame
			if shown.is_empty(): continue
			var shoulder: Vector3 = shown["upperarm_"+side].origin
			var elbow_at: Vector3 = shown["lowerarm_"+side].origin
			var wrist_at: Transform3D = shown["hand_"+side]
			for k in 9:
				var t = float(k+1)/10.0
				for limb in [[shoulder,elbow_at,.45],[elbow_at,wrist_at.origin,0.0]]:
					if t < limb[2]: continue
					var p: Vector3 = limb[0].lerp(limb[1],t)
					deepest = maxf(deepest,TRUNK-p.distance_to(Geometry3D.get_closest_point_to_segment(p,shown.spine_01.origin,shown.neck_01.origin)))
			var arm = body.arms[side]
			if arm.weight > .99 and arm.measured:
				# The wrist's bend: the fingers' way against the forearm's.
				var fingers: Vector3 = (wrist_at.basis*arm.along).normalized()
				wrist_most = maxf(wrist_most,rad_to_deg(fingers.angle_to((wrist_at.origin-elbow_at).normalized())))
			if phase in ["lift","sip","lower"] and body.held == walker.mug:
				var held: Transform3D = walker.mug.global_transform
				fist_far = maxf(fist_far,(held*body.MUG_HANDLE).distance_to(wrist_at*arm.palm))
				# The mug's body against his head (a capsule from its root up).
				var crown: Vector3 = shown.Head.origin+shown.Head.basis.y.normalized()*.16
				for y in [.1,.4,.7,.95]:
					for a in 8:
						var ring = Vector3(-.125+.5*cos(a*TAU/8.0)*.75,y,.5*sin(a*TAU/8.0))
						var p: Vector3 = held*ring
						head_into = maxf(head_into,HEAD-p.distance_to(Geometry3D.get_closest_point_to_segment(p,shown.Head.origin,crown)))
				if phase == "sip":
					var up: Vector3 = held.basis.y.normalized()
					var lips: Vector3 = body.lips()
					var rim: Vector3 = held*body.MUG_RIM
					var toward: Vector3 = lips-rim
					toward -= up*toward.dot(up)
					rim_gap = minf(rim_gap,(rim+toward.normalized()*body.MUG_RIM_RADIUS).distance_to(lips))
					tipped = maxf(tipped,rad_to_deg(up.angle_to(Vector3.UP)))
					if absf(walker.phase_time-folk.SIP.sip*.5) < .01:
						var frame: Basis = body.global_transform.basis.orthonormalized()
						elbow = frame.inverse()*(elbow_at-shoulder)
		sk.skeleton_updated.disconnect(read)
		shown.clear()
		var out: float = absf(elbow.x)
		check(walker.phase == "" and walker.mug.get_parent() == folk,"Seat %d: the sip ends with the mug back on the table" % si)
		check(deepest < INTO,"Seat %d: his arm never goes into his body (%.3f m at most)" % [si,maxf(deepest,0.0)])
		check(out > ELBOW_OUT and elbow.y < ELBOW_HIGH,"Seat %d: drinking, his elbow is held out from his side (%.2f m), not above his shoulder (%.2f m)" % [si,out,elbow.y])
		check(wrist_most < WRIST,"Seat %d: his wrist stays straight with his forearm (%.1f° at most)" % [si,wrist_most])
		check(fist_far < FIST,"Seat %d: his fist stays closed round the handle (%.3f m off at most)" % [si,fist_far])
		check(rim_gap < LIPS,"Seat %d: the rim comes to his lips (%.3f m)" % [si,rim_gap])
		check(tipped > TIPPED,"Seat %d: and is tipped back as he sips (%.0f°)" % [si,tipped])
		check(head_into < INTO_HEAD,"Seat %d: the mug never goes into his face (%.3f m at most)" % [si,maxf(head_into,0.0)])
		folk.leave(walker)
		seat.taken = null
	check(sides_seen.size() == 2,"Some drink with the left hand, some with the right, as the mug stands")
	print("INN_SIP ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
