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
		actor.setup(i>=2,Color.WHITE,"spear" if i>=2 else "sword",1,"gladiator" if i>=2 else "")
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
	# The gladiator carries a spear and a tall scutum, upright and facing forward.
	for i in [2,3]:
		var actor=actors[i]; var shield: Node3D=actor.shield_item
		check(actor.state=="SpearShieldIdle" and actor.weapon_kind=="spear" and shield.scene_file_path.ends_with("scutum.glb"),"Gladiator stands with spear and scutum: %d" % i)
		check(shield.global_basis.y.normalized().dot(Vector3.UP)>.9 and shield.global_basis.z.normalized().dot(actor.global_basis.z)>.8,"Scutum is held upright, facing forward: %d" % i)
	for clip in ["SpearShieldIdle","Run","SpearLunge","Hit","HitHead"]:
		for phase in [0.0,.25,.5,.75]:
			for i in [2,3]: pose(actors[i],clip,phase)
			await frames(1)
			for i in [2,3]:
				var actor=actors[i]
				var forearm: Vector3=(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("lowerarm_l"))).origin
				check((actor.shield_item.global_transform*Vector3(0,.5,0)).distance_to(forearm)<.5,"Scutum stays strapped to the forearm: %s %.2f / %d" % [clip,phase,i])
	for clip in ["Idle","SwordIdle","Run","Crouch","SwordSwing","SwordSlash"]:
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
