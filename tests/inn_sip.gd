extends SceneTree
## A patron at the inn takes a sip (scripts/townsfolk.gd sip): the mug comes
## up to his lips and tips, his elbow held out from his side and a little
## below his shoulder, and neither his upper arm nor his forearm ever goes
## into his body, from reaching for the mug to letting go of it.
const Data = preload("res://scripts/data.gd")
# How deep into his trunk (a capsule up his spine, TRUNK thick) the arm may
# come; how far out from the shoulder the elbow must stand, and how far above
# it it may rise, as he drinks.
const TRUNK = .13
const INTO = .03
const ELBOW_OUT = .03
const ELBOW_HIGH = .1
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
	for si in [0,3,6]:
		var walker = folk.people[si]
		var seat = folk.seats[si]
		walker.seat = seat
		folk.sit(walker)
		walker.mug = preload("res://scripts/world_art.gd").prop("mug",.17)
		folk.set_down(walker.mug,seat)
		var sk: Skeleton3D = walker.body.skeleton
		# (The bones as last shown, his reaching arm worked out.)
		var read = func():
			for n in ["spine_01","neck_01","upperarm_l","lowerarm_l","hand_l"]: shown[n] = sk.global_transform*sk.get_bone_global_pose(sk.find_bone(n)).origin
		sk.skeleton_updated.connect(read)
		for i in 10: await process_frame
		walker.phase = "reach"; walker.phase_time = 0.0
		var deepest = -1.0
		var elbow = Vector3.ZERO
		var wrist = Vector3.ZERO
		var tipped = 0.0
		for f in 600:
			if walker.phase == "": break
			var phase = walker.phase
			folk.sip(walker,1.0/60)
			await process_frame
			var shoulder: Vector3 = shown.upperarm_l
			for k in 9:
				var t = float(k+1)/10.0
				for limb in [[shoulder,shown.lowerarm_l,.45],[shown.lowerarm_l,shown.hand_l,0.0]]:
					if t < limb[2]: continue
					var p: Vector3 = limb[0].lerp(limb[1],t)
					deepest = maxf(deepest,TRUNK-p.distance_to(Geometry3D.get_closest_point_to_segment(p,shown.spine_01,shown.neck_01)))
			if phase == "sip" and absf(walker.phase_time-folk.SIP.sip*.5) < .01:
				var frame: Basis = walker.body.global_transform.basis.orthonormalized()
				elbow = frame.inverse()*(shown.lowerarm_l-shoulder)
				wrist = frame.inverse()*(shown.hand_l-shoulder)
				tipped = walker.body.arm.grip.get_euler().x
		sk.skeleton_updated.disconnect(read)
		var out: float = elbow.x*signf((walker.body.global_transform.basis.orthonormalized().inverse()*(shown.upperarm_l-shown.spine_01)).x)
		check(deepest < INTO,"Seat %d: his arm never goes into his body (%.3f m at most)" % [si,maxf(deepest,0.0)])
		check(out > ELBOW_OUT and elbow.y < ELBOW_HIGH,"Seat %d: drinking, his elbow is held out from his side (%.2f m), not above his shoulder (%.2f m)" % [si,out,elbow.y])
		check(wrist.y > .1,"Seat %d: the mug comes up to his mouth (wrist %.2f m over the shoulder)" % [si,wrist.y])
		check(absf(tipped) > .2,"Seat %d: and tips to his lips" % si)
		seat.taken = null
	print("INN_SIP ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
