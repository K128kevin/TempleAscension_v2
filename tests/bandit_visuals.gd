extends SceneTree
## The bandits (scripts/bandit.gd, tools/make_bandits.py): men and women in a
## raider's kit, fighting with the hero's clips. With --render-bandits the
## line-up is drawn to test-results/bandits-*.png.
const Visual = preload("res://scripts/visual.gd")
const Data = preload("res://scripts/data.gd")
const Bandit = preload("res://scripts/bandit.gd")
var passed = 0
var failures: Array = []
var render = false
func _initialize(): call_deferred("verify")
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failures.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func snapshot(name: String):
	if not render: return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/bandits-"+name+".png")

# Seeds whose bandits are of the wanted kind.
func seeds(who: String, count: int) -> Array:
	var out = []
	var seed = 1
	while out.size() < count:
		if Bandit.look(seed).who == who: out.append(seed)
		seed += 1
	return out

func pose(actor, clip: String, share: float) -> void:
	actor.state = clip
	actor.animator.play(actor.clips[clip],0)
	actor.animator.seek(actor.animator.current_animation_length*share,true)
	actor.animator.advance(0)
	actor.animator.pause()
	actor.skeleton.force_update_all_bone_transforms()
	actor.align_weapon()

func verify():
	render = "--render-bandits" in OS.get_cmdline_user_args()
	var scene = Node3D.new(); root.add_child(scene)
	var environment = WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.33,.29,.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.85,.8,.72)
	environment.environment.ambient_light_energy = .45
	scene.add_child(environment)
	var light = DirectionalLight3D.new(); light.rotation_degrees = Vector3(-40,-25,0); light.light_energy = 1.1; scene.add_child(light)
	var camera = Camera3D.new(); scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect = Camera3D.KEEP_WIDTH; camera.size = 7.2
	camera.position = Vector3(0,1.6,9); camera.look_at(Vector3(0,.95,0))
	check(Bandit.look(42) == Bandit.look(42),"A bandit looks the same each time it is met")
	var women = 0
	for seed in 200: if Bandit.look(seed).who == "woman": women += 1
	check(women > 50 and women < 110,"Bandits are men and women (%d women in 200)" % women)
	var line: Array = []
	for who in ["man","woman"]:
		for i in 3: line.append({"who":who,"seed":seeds(who,3)[i],"kind":"bandit_archer" if i == 2 else "bandit"})
	var actors: Array = []
	for index in line.size():
		var entry: Dictionary = line[index]
		var config: Dictionary = Data.ENEMIES[entry.kind]
		check(config.human == "bandit","%s wears the bandits' kit" % entry.kind)
		var actor = Visual.new(); scene.add_child(actor)
		actor.position.x = index*1.15-2.9
		actor.bandit_look = Bandit.look(entry.seed)
		actor.setup(false,Color.WHITE,config.weapon,config.size,"",config.human)
		actors.append(actor)
		var names = actor.skin_meshes.filter(func(m): return is_instance_valid(m)).map(func(m): return String(m.name))
		check(actor.bandit and actor.rig.scene_file_path.ends_with("bandit_%s.glb" % entry.who),"A %s's figure is the %s's" % [entry.who,entry.who])
		for part in ["Body","Tunic","Vest","Sash","Apron","Bracer_l","Bindings_r","Dagger","Quiver"]:
			check(part in names,"A %s bandit wears the %s" % [entry.who,part])
		check(not names.any(func(n): return n.begins_with("Ranger") or n.begins_with("Hero")),"No piece of the hero's kit but the quiver and dagger")
		for clip in ["Idle","Run","SwordIdle","SwordSwing","ArcherShot","RangerIdle","RangerRun","Hit","HitHead","HitStagger","Death"]:
			check(actor.clips.has(clip),"The %s bandit has the clip %s" % [entry.who,clip])
		check(actor.shield_item == null,"Bandits carry no shield")
		if config.weapon == "sword":
			check(actor.weapon_item != null and actor.weapon_item.scene_file_path.ends_with("sica.glb"),"A bandit's sword is a curved sica")
		var quiver = actor.quivers[0]
		check(quiver.visible == (config.weapon == "bow"),"The quiver is worn with the bow only")
	var heights = {}
	for i in actors.size():
		var actor = actors[i]
		var head: Vector3 = actor.skeleton.get_bone_global_rest(actor.skeleton.find_bone("Head")).origin
		heights[line[i].who] = head.y
	check(heights.woman < heights.man,"The women stand a little shorter than the men")
	for actor in actors: pose(actor,actor.idle_action(),0.0)
	await snapshot("idle")
	for actor in actors: pose(actor,"Run",.25)
	await snapshot("run")
	for actor in actors: pose(actor,"ArcherShot" if actor.weapon_kind == "bow" else "SwordSwing",.5)
	await snapshot("attack")
	for actor in actors:
		pose(actor,actor.idle_action(),0.0)
		actor.rotation.y = PI
	await snapshot("back")
	camera.size = 2.4; camera.position = Vector3(actors[0].position.x+.55,1.55,6); camera.look_at(Vector3(actors[0].position.x+.55,1.35,0))
	for actor in actors: actor.rotation.y = 0.0
	await snapshot("faces")
	print("BANDIT_VISUALS ",passed," passed; ",failures)
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
