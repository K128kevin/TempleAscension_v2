extends SceneTree
const Visual = preload("res://scripts/visual.gd")
var passed = 0
var failures: Array = []
var actors: Array = []
var render = false
func _initialize(): call_deferred("verify")
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failures.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func pose(actor, clip: String, phase: float):
	actor.state=clip; actor.animator.play(actor.clips[clip],0)
	actor.animator.seek(actor.animator.current_animation_length*phase,true)
	actor.animator.advance(0); actor.skeleton.force_update_all_bone_transforms(); actor.align_weapon()
# Running with a strapped scutum, the shield forearm must stay out before the
# body (it was once left at the stance's place as the body leaned into the
# run, sunk in the chest), with the board laid close along it rather than
# pushed out in front of it: how far the forearm stays clear of the torso
# (as capsules), and how far the board's back stands off it.
const TORSO = [["pelvis","spine_02",.15],["spine_02","spine_03",.15],["spine_03","neck_01",.16]]
func bone(actor, name: String) -> Vector3:
	return (actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(name))).origin
func forearm_clear(actor) -> float:
	var k: float = actor.rig.scale.x
	var worst = INF
	for i in 7:
		var p: Vector3 = bone(actor,"lowerarm_l").lerp(bone(actor,"hand_l"),i/6.0)
		for s in TORSO:
			worst = minf(worst,Geometry3D.get_closest_point_to_segment(p,bone(actor,s[0]),bone(actor,s[1])).distance_to(p)-(s[2]+.045)*k)
	return worst
func board_off_forearm(actor) -> float:
	var t: Transform3D = actor.shield_item.global_transform
	var box: AABB = actor.shield_box
	var thin = 0
	for axis in 3: if box.size[axis]*t.basis[axis].length() < box.size[thin]*t.basis[thin].length(): thin = axis
	var centre: Vector3 = t*box.get_center()
	var normal: Vector3 = t.basis[thin].normalized()
	if normal.dot(centre-bone(actor,"spine_02")) < 0: normal = -normal
	var back: float = -box.size[thin]*t.basis[thin].length()*.5
	var nearest = INF
	for i in 5:
		var p: Vector3 = bone(actor,"lowerarm_l").lerp(bone(actor,"hand_l"),i/4.0)
		nearest = minf(nearest,(centre-p).dot(normal)+back)
	return nearest/actor.rig.scale.x
# Runs a fresh statue on the spot for a while (its skeleton modifiers and
# all, as in the game): the least its forearm clears the torso by, the most
# the board stands off the forearm, and the least upright the board stands.
func run_check(kind: String) -> Array:
	var Data = load("res://scripts/data.gd")
	var holder = Node3D.new(); root.add_child(holder)
	var v = Visual.new(); holder.add_child(v)
	v.setup(true,Color.WHITE,Data.ENEMIES[kind].weapon,Data.ENEMIES[kind].size,kind)
	var result = [INF,0.0,1.0]
	var running = [false]
	v.skeleton.skeleton_updated.connect(func():
		if not running[0] or v.shield_box.size == Vector3.ZERO: return
		result[0] = minf(result[0],forearm_clear(v)); result[1] = maxf(result[1],board_off_forearm(v))
		result[2] = minf(result[2],v.shield_item.global_basis.y.normalized().dot(Vector3.UP)))
	for i in 150:
		running[0] = i > 60
		v.locomotion(i >= 30,false,false,1.0,3.56 if i >= 30 else 0.0)
		v.advance(1.0/60)
		await process_frame
	holder.queue_free()
	return result

# A gladiator standing, then striking as in the game (its stance between the
# frames re-aligned the way facing a target does it): the most the shield
# moves and turns from one frame to the next (relative to the body), the
# least far in front of the body it gets, and the most the shield arm reaches
# out (which it should only do running).
func swing_check() -> Array:
	var Data = load("res://scripts/data.gd")
	var holder = Node3D.new(); root.add_child(holder)
	var v = Visual.new(); holder.add_child(v)
	v.setup(true,Color.WHITE,"sword",Data.ENEMIES.gladiator.size,"gladiator")
	var result = [0.0,0.0,INF,0.0]
	var last = []
	var watching = [false]
	v.skeleton.skeleton_updated.connect(func():
		if not watching[0]: return
		var t: Transform3D = v.global_transform.affine_inverse()*v.shield_item.global_transform
		var centre: Vector3 = t*v.shield_box.get_center()
		if not last.is_empty():
			var a: Transform3D = last[0]
			result[0] = maxf(result[0],(t.origin-a.origin).length())
			result[1] = maxf(result[1],(t.basis.orthonormalized()*a.basis.orthonormalized().inverse()).get_rotation_quaternion().get_angle())
		result[2] = minf(result[2],centre.z)
		result[3] = maxf(result[3],v.arm_out)
		last.assign([t]))
	for i in 40:
		v.locomotion(false,false); v.advance(1.0/60); v.align_weapon(); await process_frame
	watching[0] = true
	var duration = .67
	v.play("ScutumSwordSwing",duration)
	var t = 0.0
	while t < duration+.5:
		v.locomotion(false,t < duration); v.advance(1.0/60)
		v.align_weapon(); v.align_weapon()
		await process_frame
		t += 1.0/60
	holder.queue_free()
	return result

func snapshot(name: String):
	if not render: return
	await frames(2); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/shield-"+name+".png")
func verify():
	render="--render-shields" in OS.get_cmdline_user_args()
	var scene=Node3D.new(); root.add_child(scene)
	var environment=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(.035,.04,.05)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_energy=.35
	scene.add_child(environment)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-25,0); light.light_energy=.8; scene.add_child(light)
	var camera=Camera3D.new(); scene.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect=Camera3D.KEEP_WIDTH; camera.size=8.4
	camera.position=Vector3(1.5,2.5,9); camera.look_at(Vector3(0,1,0))
	for i in 4:
		var actor=Visual.new(); scene.add_child(actor); actor.position.x=i*2.1-3.15; actor.rotation.y=PI if i%2 else 0
		actor.setup(i>=2,Color.WHITE,"sword",1,"gladiator" if i>=2 else "")
		actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actors.append(actor)
		var label=Label3D.new(); label.text="Warrior" if i<2 else "Gladiator"; label.position=Vector3(actor.position.x,-.2,0)
		label.font_size=40; label.pixel_size=.007; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; scene.add_child(label)
	await frames(2)
	for actor in actors: pose(actor,actor.idle_action(),.3)
	await frames(1)
	for i in [0,1]:
		var side: Vector3=actors[i].global_basis.x.normalized()
		check(actors[i].state=="SwordIdle" and actors[i].shield_item.global_basis.z.normalized().dot(side)>.9,"Sword-and-shield idle holds the shield facing sideways: %d" % i)
	# Running with the larger sword never swings the blade through the head.
	for i in [0,1]:
		var nearest = INF
		for step in 20:
			pose(actors[i],"SwordRun",step/20.0); await frames(1)
			var head: Vector3=(actors[i].skeleton.global_transform*actors[i].skeleton.get_bone_global_pose(actors[i].skeleton.find_bone("Head"))).origin+Vector3.UP*.08
			var sword: Node3D=actors[i].weapon_item
			nearest=minf(nearest,Geometry3D.get_closest_point_to_segment(head,sword.global_transform*Vector3.ZERO,sword.global_transform*Vector3.UP).distance_to(head))
		check(nearest>.3,"The sword clears the head while running (%.2fm): %d" % [nearest,i])
		actors[i].state="Idle"; actors[i].locomotion(true,false)
		check(actors[i].state=="SwordRun","A sword bearer runs with the sword carried low: %d" % i)
	# The gladiator carries a spear and a tall scutum, upright and facing forward.
	for i in [2,3]:
		var actor=actors[i]; var shield: Node3D=actor.shield_item
		check(actor.state=="ScutumSwordIdle" and actor.weapon_kind=="sword" and shield.scene_file_path.ends_with("scutum.glb"),"Gladiator stands with sword and scutum: %d" % i)
		check(shield.global_basis.y.normalized().dot(Vector3.UP)>.9 and shield.global_basis.z.normalized().dot(actor.global_basis.z)>.8,"Scutum is held upright, facing forward: %d" % i)
	# The centurion: a close-fitted armored soldier behind a tall tower shield.
	var centurion=Visual.new(); root.add_child(centurion); centurion.setup(true,Color.WHITE,"spear",1.2,"centurion")
	centurion.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["SpearShieldIdle","ShieldStab"]:
		pose(centurion,clip,.5); await frames(1)
		var tower: Node3D=centurion.shield_item
		check(tower.scene_file_path.ends_with("scutum.glb") and is_equal_approx(tower.global_basis.get_scale().y,Visual.TOWER_SIZE.y*centurion.rig.scale.y),"Centurion carries the tall tower shield: "+clip)
		check(tower.global_basis.y.normalized().dot(Vector3.UP)>.85,"Tower shield stays upright: "+clip)
	check(centurion.idle_action()=="SpearShieldIdle","Centurion stands in the shield-and-spear stance")
	centurion.queue_free()
	# Running, a shield bearer's forearm stays out before the body, carrying
	# the board out in front of the rising knees and the leaning chest rather
	# than the board leaving the arm.
	# Striking, the gladiator's scutum stays before him, moving smoothly: it
	# is not swung round behind him and back by a whole-body spin, nor
	# carried about by the arm reach meant for running.
	var swing = await swing_check()
	check(swing[0] < .12 and swing[1] < .2,"The gladiator's scutum moves smoothly through his swing (at most %.3fm and %.3f rad a frame)" % [swing[0],swing[1]])
	check(swing[2] > .15,"The gladiator's scutum stays before him through his swing (at least %.2fm in front)" % swing[2])
	check(swing[3] < .01,"Standing and striking, the gladiator's shield arm holds its guard (reaches out %.3fm)" % swing[3])
	for kind in ["gladiator","centurion"]:
		var r = await run_check(kind)
		check(r[0] > .02 and r[1] < .12,"Running, the %s's shield forearm stays out before his body (clear by %.3fm) with the shield along it (off it by %.3fm)" % [kind,r[0],r[1]])
		check(r[2] > .85,"Running, the %s's shield stays upright (%.3f)" % [kind,r[2]])
	for i in [2,3]:
		actors[i].state=actors[i].idle_action(); actors[i].locomotion(true,false)
		check(actors[i].state=="ScutumRun","Shield bearers run holding the shield: %d" % i)
	# (The arm as shown, with the skeleton's modifiers applied, and the board
	# laid on it: taken as the skeleton updates.)
	var shown = {}
	for i in [2,3]:
		var actor = actors[i]
		actor.skeleton.skeleton_updated.connect(func(): shown[i] = [bone(actor,"lowerarm_l"),bone(actor,"hand_l"),actor.shield_item.global_transform])
	for clip in ["ScutumSwordIdle","ScutumRun","SwordSwing","Hit","HitHead"]:
		for phase in [0.0,.25,.5,.75]:
			for i in [2,3]: pose(actors[i],clip,phase)
			await frames(1)
			for i in [2,3]:
				var forearm: Vector3 = shown[i][0]
				var wrist: Vector3 = shown[i][1]
				var board: Transform3D = shown[i][2]
				check((board*Vector3(0,.5,0)).distance_to(forearm)<.5,"Scutum stays strapped to the forearm: %s %.2f / %d" % [clip,phase,i])
				# Strapped, not gripped: the board lies flat along the forearm.
				check(absf(board.basis.z.normalized().dot((wrist-forearm).normalized()))<.2,"Scutum lies flat along the forearm: %s %.2f / %d" % [clip,phase,i])
	# A hit must not flip the shield: each shield reaction starts with the shield
	# facing where the sword-and-shield stance holds it.
	for i in [0,1]:
		pose(actors[i],"SwordIdle",0.0); await frames(1)
		var steady: Vector3=actors[i].shield_item.global_basis.z.normalized()
		for clip in ["ShieldHit","ShieldHitHead","ShieldHitStagger","ShieldHitKnockdown"]:
			pose(actors[i],clip,0.0); await frames(1)
			check(actors[i].shield_item.global_basis.z.normalized().dot(steady)>.9,"A hit keeps the shield facing out: %s / %d" % [clip,i])
		actors[i].state="SwordIdle"; actors[i].react("Hit",.3)
		check(actors[i].state=="ShieldHit","Shield bearers flinch with the shield arm held: %d" % i)
	for clip in ["Idle","SwordIdle","Run","SwordRun","Crouch","SwordSwing","SwordSlash","Cleave","Evade","ShieldHit","ShieldHitHead","ShieldHitStagger","ShieldHitKnockdown"]:
		for phase in [0.0,.15,.35,.55,.75,.95]:
			for actor in actors: pose(actor,clip,phase)
			await frames(1)
			for i in [0,1]:
				var actor=actors[i]; var shield=actor.shield_item
				var forearm: Transform3D=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("lowerarm_l"))
				var wrist: Vector3=(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("hand_l"))).origin
				var local_wrist: Vector3=shield.global_transform.affine_inverse()*wrist
				var center: Vector3=shield.global_transform*Vector3(0,.5,0)
				var along_arm: float=(center-forearm.origin).dot((wrist-forearm.origin).normalized())/forearm.origin.distance_to(wrist)
				check(absf(local_wrist.x)<.35 and local_wrist.y>.18 and local_wrist.y<.82,"Wrist is behind the shield interior, clear of the rim: %s %.2f / %d" % [clip,phase,i])
				check(along_arm>.35 and along_arm<.75,"Shield center rests over the forearm: %s %.2f / %d" % [clip,phase,i])
				check(shield.global_basis.z.normalized().dot(-forearm.basis.z.normalized())>.99,"Shield face stays on the outside of the forearm: %s %.2f / %d" % [clip,phase,i])
		for actor in actors: pose(actor,clip,.35)
		await snapshot(clip)
	for actor in actors.slice(0,2):
		actor.equip("bow"); await frames(1)
		check(actor.shield_item==null and not is_instance_valid(actor.shield_attachment),"Changing the hero's weapon removes the shield")
	print("SHIELD_REGRESSION ",passed," passed; ",failures)
	scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
