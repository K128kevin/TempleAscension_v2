extends SceneTree
const Visual = preload("res://scripts/visual.gd")
var passed: Array = []
var failed: Array = []
var actors: Array = []

func _initialize(): call_deferred("test")

func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func pose(actor,clip: String,phase: float):
	actor.state = clip
	actor.animator.play(actor.clips[clip],0)
	actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
	actor.animator.advance(0)
	actor.skeleton.force_update_all_bone_transforms()
	actor.align_weapon()

func bone(actor,id: String) -> Vector3:
	return (actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(id))).origin

func gap(a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> float:
	var points = Geometry3D.get_closest_points_between_segments(a,b,c,d)
	return points[0].distance_to(points[1])

func test():
	var scene = Node3D.new()
	root.add_child(scene)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.035,.045,.06)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = .7
	scene.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	sun.light_energy = 1.2
	scene.add_child(sun)
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.9
	camera.position = Vector3(0,2,10)
	camera.look_at(Vector3(0,.9,0))
	for i in 4:
		var actor = Visual.new()
		scene.add_child(actor)
		actor.position.x = (i-1.5)*1.7
		actor.setup(false,Color.WHITE,"bow")
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actors.append(actor)
	var actor = actors[0]
	for clip in ["BowShot","BowRapid"]:
		var neck_gap = INF
		var torso_gap = INF
		var deepest = 0.0
		var nock_error = 0.0
		var worst_nock_phase = 0.0
		for i in 121:
			pose(actor,clip,i/120.0)
			var elbow = bone(actor,"lowerarm_r")
			var wrist = bone(actor,"hand_r")
			neck_gap = minf(neck_gap,gap(elbow,wrist,bone(actor,"neck_01"),bone(actor,"Head")))
			torso_gap = minf(torso_gap,gap(elbow,wrist,bone(actor,"spine_01"),bone(actor,"neck_01")))
			var string = actor.bow_strings[0]
			var draw: float = string.mesh.get_blend_shape_value(string.index)
			deepest = maxf(deepest,draw*.36)
			if actor.nocked_arrow.visible:
				var nock: Vector3 = actor.weapon_item.global_transform*Vector3(.5+draw*1.44,.5+draw*.06/1.3,0)
				# The draw hand's fingers hold the string.
				var fingers: Vector3 = actor.draw_fingers()
				if nock.distance_to(fingers)>nock_error:
					nock_error = nock.distance_to(fingers)
					worst_nock_phase = i/120.0
		# Drawn to the jaw, the forearm runs beside the face, clear of the
		# neck and head's centre line by more than the jaw's half-width.
		check(neck_gap>.085,"%s forearm clears neck/head (%.3fm)" % [clip,neck_gap])
		check(torso_gap>.14,"%s forearm clears torso (%.3fm)" % [clip,torso_gap])
		check(deepest>.34,"%s draws the string at least 34cm" % clip)
		check(nock_error<.035,"%s string follows draw hand (%.3fm error)" % [clip,nock_error])
		if nock_error>=.035: print("WORST_NOCK_PHASE ",clip," ",worst_nock_phase)
	# The archer statue stands, runs and crouches as the ranger does, its bow
	# carried in the left fist beside it: seated in the fist, square to the
	# forearm, the lower tip off the ground and clear of the body.
	var statue = Visual.new()
	scene.add_child(statue)
	statue.setup(true,Color.WHITE,"bow",1,"archer")
	statue.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(statue.idle_action()=="RangerIdle","An archer statue idles as the ranger does")
	pose(statue,"RangerIdle",0.0)
	for clip in ["RangerIdle","RangerRun","RangerCrouch"]:
		var grip_error = 0.0
		var lowest_tip = INF
		var squareness = 0.0
		var body_gap = INF
		for direction in 4:
			statue.rotation.y = direction*TAU/4
			for i in 31:
				pose(statue,clip,i/30.0)
				var t: Transform3D = statue.weapon_item.global_transform
				grip_error = maxf(grip_error,(t*Visual.BOW_GRIP).distance_to(statue.bow_hold("l")[0]))
				lowest_tip = minf(lowest_tip,minf((t*Vector3(0,0,0)).y,(t*Vector3(0,1,0)).y))
				var forearm: Vector3 = (bone(statue,"hand_l")-bone(statue,"lowerarm_l")).normalized()
				squareness = maxf(squareness,absf(t.basis.y.normalized().dot(forearm)))
				for limb in [["spine_01","neck_01",.16],["thigh_l","calf_l",.09],["calf_l","foot_l",.07]]:
					body_gap = minf(body_gap,gap(t*Vector3(0,0,0),t*Vector3(0,1,0),bone(statue,limb[0]),bone(statue,limb[1]))-limb[2])
		check(grip_error<.05,"The archer statue's bow stays in its left fist: %s (%.3fm)" % [clip,grip_error])
		check(squareness<.17,"The archer statue's bow stays square to the forearm: %s (%.3f)" % [clip,squareness])
		check(lowest_tip>.05,"Bow lower tip clears ground: %s (%.3fm)" % [clip,lowest_tip])
		check(body_gap>0,"The archer statue's bow stays clear of its body: %s (%.3fm)" % [clip,body_gap])
	statue.rotation.y = 0
	statue.locomotion(true,false)
	check(statue.state=="RangerRun","A moving archer statue runs as the ranger does")
	statue.locomotion(true,false,true)
	check(statue.state=="RangerCrouch","A crouching archer statue crouches as the ranger does")
	statue.locomotion(false,false)
	check(statue.state=="RangerIdle","An archer statue stops in the ranger's idle")
	# The ranger stands, runs and crouches as the warrior does, the bow in his
	# right hand beside him; he holds it out in the left only to shoot.
	actor.rotation.y = 0
	actor.locomotion(false,false)
	check(actor.state=="RangerIdle","The ranger idles as the warrior does, bow in his left hand")
	actor.locomotion(true,false)
	check(actor.state=="RangerRun","The ranger runs as the warrior does")
	actor.locomotion(true,false,true)
	check(actor.state=="RangerCrouch","The ranger crouches as the warrior does")
	# Carried, the bow is fixed in the fist: the same angle to the hand in
	# every frame, the stave square to the forearm, and clear of his body.
	# (Switching from a shot to the idle starts the bow arm lowering; posing
	# clips directly lets no time pass, so finish it first.)
	actor.advance(1.0)
	var carry_error = 0.0
	var square = 0.0
	var turn = 0.0
	var clearance = INF
	var held = null
	for clip in ["RangerIdle","RangerRun","RangerCrouch"]:
		for i in 31:
			pose(actor,clip,i/30.0)
			var grip: Vector3 = actor.weapon_item.global_transform*Visual.BOW_GRIP
			carry_error = maxf(carry_error,grip.distance_to(actor.bow_hold("l")[0]))
			var stave: Vector3 = actor.weapon_item.global_basis.y.normalized()
			var forearm: Vector3 = (bone(actor,"hand_l")-bone(actor,"lowerarm_l")).normalized()
			square = maxf(square,absf(stave.dot(forearm)))
			var hand: Basis = (actor.skeleton.global_transform.basis*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("hand_l")).basis).orthonormalized()
			var in_hand: Basis = hand.inverse()*actor.weapon_item.global_basis.orthonormalized()
			if held == null: held = in_hand
			turn = maxf(turn,in_hand.get_rotation_quaternion().angle_to(held.get_rotation_quaternion()))
			var tips = [actor.weapon_item.global_transform*Vector3(0,0,0),actor.weapon_item.global_transform*Vector3(0,1,0)]
			var string = [actor.weapon_item.global_transform*Vector3(.5,0,0),actor.weapon_item.global_transform*Vector3(.5,1,0)]
			for limb in [["spine_01","neck_01",.16],["thigh_l","calf_l",.09],["calf_l","foot_l",.07]]:
				for line in [tips,string]:
					clearance = minf(clearance,gap(line[0],line[1],bone(actor,limb[0]),bone(actor,limb[1]))-limb[2])
	# Rigid in the hand, the grip shifts only as the curled fingers flex (the
	# run and crouch curl them a little tighter than the idle).
	check(carry_error<.05,"The carried bow stays in the ranger's left fist (%.3fm)" % carry_error)
	# Square to the hand; the wrist bends up to about 9 degrees from the
	# forearm (most in the crouch).
	check(square<.17,"The carried bow stays square to the forearm (%.3f)" % square)
	check(turn<.02,"The carried bow keeps one grip angle in the hand (%.3f rad)" % turn)
	check(clearance>0,"The carried bow stays clear of the ranger's body (%.3fm)" % clearance)
	if "--render-bow" in OS.get_cmdline_user_args():
		for clip in ["BowShot","BowRapid","BowRun","BowCrouch"]:
			for i in 4:
				actors[i].rotation.y = [0.0,PI/2,-PI/2,PI][i]
				pose(actors[i],clip,.54 if clip=="BowRapid" else .60)
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/bow-%s-angles.png" % clip)
	FileAccess.open("res://test-results/bow-regression.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	# Held out (raised to shoot, or a statue archer's through every clip), the
	# bow turns about the grip as needed to keep its limbs and string outside
	# the legs.
	var archer = Visual.new()
	scene.add_child(archer)
	archer.setup(true,Color.WHITE,"bow",1.0,"archer")
	archer.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var leg_gap = INF
	for pair in [[actor,"ArcherShot"],[actor,"BowShot"],[actor,"BowRapid"],[archer,"ArcherShot"],[archer,"Hit"]]:
		var who = pair[0]
		var k = who.rig.scale.x
		# Posed as stills, without the unit's clock (in play the turn that
		# clears the legs is eased in over time).
		who.anim_clock = 0.0
		for i in 41:
			pose(who,pair[1],i/40.0)
			var t: Transform3D = who.weapon_item.global_transform
			var grip: Vector3 = t*Visual.BOW_GRIP
			# (The fist itself may rest against a thigh.)
			for line in [[grip.lerp(t*Vector3(.25,0,0),.2),t*Vector3(.25,0,0)],[grip.lerp(t*Vector3(.25,1,0),.2),t*Vector3(.25,1,0)],[t*Vector3(.5,0,0),t*Vector3(.5,1,0)]]:
				for limb in [["thigh_l","calf_l",.08],["thigh_r","calf_r",.08],["calf_l","foot_l",.06],["calf_r","foot_r",.06]]:
					leg_gap = minf(leg_gap,gap(line[0],line[1],bone(who,limb[0]),bone(who,limb[1]))-limb[2]*k)
	check(leg_gap>0,"A held bow stays outside the legs (%.3fm)" % leg_gap)
	archer.queue_free()
	print("BOW_REGRESSION ",passed.size()," passed; ",failed)
	scene.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
