extends SceneTree
const Visual = preload("res://scripts/visual.gd")
func _initialize(): call_deferred("capture")
func capture():
	var scene = Node3D.new()
	root.add_child(scene)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.3,.33,.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .9
	scene.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	scene.add_child(sun)
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.6
	camera.position = Vector3(0,1.3,10); camera.look_at(Vector3(0,1.0,0))
	var actors = []
	for i in 6:
		var actor = Visual.new()
		scene.add_child(actor)
		actor.position = Vector3((i-2.5)*1.45,0,0)
		actor.setup(false,Color.WHITE,"dagger",1.0,"","ranger")
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actors.append(actor)
	for i in 5: await process_frame
	var sheets = {
		"dagger":["dagger",[["DaggerStab",.3],["DaggerStab",.45],["DaggerSlash",.3],["DaggerSlash",.42],["DaggerSlash",.52],["SkillAmbush",.38]]],
		"flurry":["dagger",[["SkillFlurry4",.16],["SkillFlurry4",.27],["SkillFlurry4",.35],["SkillFlurry4",.55],["SkillAmbush",.5],["SkillSandL",.32]]],
		"triple":["dagger",[["SkillTripleSlash",.1],["SkillTripleSlash",.22],["SkillTripleSlash",.4],["SkillTripleSlash",.58],["SkillTripleSlash",.68],["SkillTripleSlash",.84]]],
		"bow":["bow",[["SkillVolley",.5],["SkillVolley",.7],["SkillVolley",.78],["SkillSandR",.32],["SkillSandR",.56],["SneakIdle",.2]]],
		"misc":["dagger",[["SkillSandL",.56],["SneakIdle",.0],["SneakIdle",.5],["Idle",.0],["SkillHide",.5],["SkillHide",1.0]]]}
	for name in sheets:
		for turn in [-.6,-PI/2]:
			for i in 6:
				var actor = actors[i]
				if actor.weapon_kind != sheets[name][0]: actor.equip(sheets[name][0])
				var shot = sheets[name][1][i]
				actor.set_shadowed(shot[0]=="SneakIdle")
				actor.rotation.y = turn
				actor.state = shot[0]
				actor.animator.play(actor.clips[shot[0]],0)
				actor.animator.seek(actor.animator.get_animation(actor.clips[shot[0]]).length*shot[1],true)
				actor.animator.advance(0)
				actor.skeleton.force_update_all_bone_transforms()
				actor.align_weapon()
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/ranger-%s-%d.png" % [name,int(absf(turn)*10)])
	quit(0)
