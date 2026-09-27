extends SceneTree
const Visual = preload("res://scripts/visual.gd")
const Motion = preload("res://scripts/combat_animation.gd")
var actors: Array = []
var passed: Array = []
var failed: Array = []
func _initialize(): call_deferred("capture")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func pose(actor,clip: String,phase: float):
	actor.state = clip
	actor.animator.play(actor.clips[clip],0)
	actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
	actor.animator.advance(0)
	actor.skeleton.force_update_all_bone_transforms()
	actor.align_weapon()
func capture():
	var scene = Node3D.new()
	root.add_child(scene)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.035,.045,.06)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = .65
	scene.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	sun.light_energy = 1.2
	scene.add_child(sun)
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	camera.position = Vector3(3,3,10)
	camera.look_at(Vector3(0,.85,0))
	var ui = CanvasLayer.new()
	scene.add_child(ui)
	var title = Label.new()
	title.position = Vector2(35,30)
	title.add_theme_font_size_override("font_size",30)
	ui.add_child(title)
	for i in 4:
		var actor = Visual.new()
		scene.add_child(actor)
		actor.position = Vector3((i-1.5)*2.1,0,0)
		actor.setup(false,Color.WHITE,"sword")
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actors.append(actor)
	await frames(5)
	for weapon in 4:
		for special in [false,true]:
			var profile = Motion.profile(weapon,special,0)
			var clip: String = profile.clip
			title.text = "%s — %.2f seconds" % [clip,profile.duration]
			var phases = [.12,.35,profile.contacts[0],.84]
			for i in 4:
				actors[i].equip(["spear","sword","bow","axe"][weapon])
				pose(actors[i],clip,phases[i])
			await frames(2)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/attack-%s.png" % clip)
			var actor = actors[0]
			var previous = Vector3.ZERO
			var travel = 0.0
			var stable = true
			var max_draw = 0.0
			for i in 61:
				pose(actor,clip,i/60.0)
				await frames(1)
				var tip: Vector3 = actor.weapon_item.global_transform*Vector3(0,1,0)
				if weapon==2: tip = (actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("hand_r"))).origin
				if i>0: travel += tip.distance_to(previous)
				previous = tip
				if weapon==2:
					stable = stable and actor.weapon_item.global_basis.y.normalized().dot(Vector3.UP)>.999 and (-actor.weapon_item.global_basis.x.normalized()).dot(Vector3.BACK)>.999
					for string in actor.bow_strings: max_draw = maxf(max_draw,string.mesh.get_blend_shape_value(string.index))
			if weapon in [1,3]:
				pose(actor,clip,profile.contacts[0])
				await frames(2)
				var contact_tip: Vector3 = actor.weapon_item.global_transform*Vector3(0,1,0)-actor.global_position
				check(contact_tip.z>1.0 and absf(contact_tip.x)<.8,"Blade reaches in front at damage contact: "+clip)
			check(profile.duration>=.6,"Full readable duration for "+clip)
			check(travel>(1.0 if weapon in [1,3] else .12),"Visible weapon motion for %s (%.2fm)" % [clip,travel])
			if weapon==2:
				check(stable,"Bow never flips or tilts backward throughout "+clip)
				check(max_draw>.95,"Bowstring visibly draws in "+clip)
				check(not actor.nocked_arrow.visible,"Nocked arrow clears after release in "+clip)
	# Check attachment orientation while aiming in every octant, including left.
	var bow = actors[0]
	bow.equip("bow")
	for direction in 8:
		bow.rotation.y = direction*TAU/8
		for special in [false,true]:
			var clip: String = Motion.profile(2,special,0).clip
			var stable = true
			for f in 30:
				pose(bow,clip,f/30.0)
				stable = stable and (-bow.weapon_item.global_basis.x.normalized()).dot(bow.global_basis.z)>.999
			check(stable,"Bow alignment %s direction %d" % [clip,direction])
	var report = {"passed":passed,"failed":failed}
	FileAccess.open("res://test-results/attack-animation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ATTACK_ANIMATION ",passed.size()," passed; ",failed)
	quit(0 if failed.is_empty() else 1)
