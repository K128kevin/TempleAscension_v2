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
				if nock.distance_to(wrist)>nock_error:
					nock_error = nock.distance_to(wrist)
					worst_nock_phase = i/120.0
		check(neck_gap>.12,"%s forearm clears neck/head (%.3fm)" % [clip,neck_gap])
		check(torso_gap>.14,"%s forearm clears torso (%.3fm)" % [clip,torso_gap])
		check(deepest>.34,"%s draws the string at least 34cm" % clip)
		check(nock_error<.035,"%s string follows draw hand (%.3fm error)" % [clip,nock_error])
		if nock_error>=.035: print("WORST_NOCK_PHASE ",clip," ",worst_nock_phase)
	for clip in ["BowRun","BowCrouch"]:
		check(actor.clips.has(clip),"Dedicated carry clip exists: "+clip)
		if not actor.clips.has(clip): continue
		var grip_error = 0.0
		var lowest_tip = INF
		var side_gap = INF
		var faces_forward = true
		for direction in 8:
			actor.rotation.y = direction*TAU/8
			for i in 31:
				pose(actor,clip,i/30.0)
				var grip: Vector3 = actor.weapon_item.global_transform*Visual.BOW_GRIP
				var hand_pose: Transform3D = actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("hand_l"))
				grip_error = maxf(grip_error,grip.distance_to(hand_pose*Visual.BOW_PALM))
				lowest_tip = minf(lowest_tip,(actor.weapon_item.global_transform*Vector3(0,0,0)).y)
				side_gap = minf(side_gap,(grip-bone(actor,"pelvis")).dot(actor.global_basis.x))
				faces_forward = faces_forward and (-actor.weapon_item.global_basis.x.normalized()).dot(actor.global_basis.z)>.9
		check(grip_error<.001,"Bow stays seated in moving palm in every direction: "+clip)
		check(lowest_tip>.05,"Bow lower tip clears ground: %s (%.3fm)" % [clip,lowest_tip])
		check(side_gap>.22,"Bow is carried beside the torso: %s (%.3fm)" % [clip,side_gap])
		check(faces_forward,"Carried bow keeps its curved front forward: "+clip)
	actor.rotation.y = 0
	actor.locomotion(true,false)
	check(actor.state=="BowRun","Moving selects bow carry animation")
	actor.locomotion(true,false,true)
	check(actor.state=="BowCrouch","Crouching selects bow carry animation")
	actor.locomotion(false,false)
	check(actor.state=="BowIdle","Stopping returns to bow ready stance")
	if "--render-bow" in OS.get_cmdline_user_args():
		for clip in ["BowShot","BowRapid","BowRun","BowCrouch"]:
			for i in 4:
				actors[i].rotation.y = [0.0,PI/2,-PI/2,PI][i]
				pose(actors[i],clip,.54 if clip=="BowRapid" else .60)
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/bow-%s-angles.png" % clip)
	FileAccess.open("res://test-results/bow-regression.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("BOW_REGRESSION ",passed.size()," passed; ",failed)
	scene.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
