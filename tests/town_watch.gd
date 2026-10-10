extends SceneTree
## The town's watch (scripts/town_watch.gd): the guards at the gates and the
## palace, six pairs walking the town, the watch changing every eight hours,
## and a guard spoken to.
const Data = preload("res://scripts/data.gd")
const Watch = preload("res://scripts/town_watch.gd")
const Guard = preload("res://scripts/town_guard.gd")
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)

func run_for(game, seconds: float, step: float = .1) -> void:
	var t = 0.0
	while t < seconds:
		game.world.watch.tick(step,game.player.position)
		t += step

func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/town-watch-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	game.mode = "playing"
	var world = game.world
	var watch = world.watch
	check(watch.posts.size() == 4 and watch.posts.all(func(p): return p.guards.size() == 2 and p.guards.all(func(g): return g.get_script() == Guard)),"Four posts, two guards at each: the town's gates and the palace's")
	check(watch.patrols.size() == Watch.PAIRS and watch.patrols.all(func(p): return p.guards.size() == 2),"Six pairs walk the town")
	check(watch.guards().size() == 20 and watch.guards().all(func(g): return g.animator.has_animation("Walk")),"Twenty guards in all, every one able to walk")
	# Walking the town, two by two.
	var started: Array = watch.patrols.map(func(p): return p.guards[0].position)
	run_for(game,40.0)
	var moved: int = 0
	for i in watch.patrols.size():
		if watch.patrols[i].guards[0].position.distance_to(started[i]) > 2.0: moved += 1
	check(moved >= 4,"The pairs walk about the town (%d of 6 moved on)" % moved)
	var together = true
	var footing = true
	for t in 40:
		run_for(game,.5)
		for p in watch.patrols:
			together = together and p.guards[0].position.distance_to(p.guards[1].position) < 4.0
			for g in p.guards: footing = footing and world.fits(g.position,.15) and not Watch.in_arena(g.position)
	check(together,"Each pair keeps together, the second a pace or two behind")
	check(footing,"They keep to open ground, and never cross the arena")
	# The watch changes: each post relieved by a pair, chosen at random.
	var on_watch: Array = watch.posts.map(func(p): return p.guards.duplicate())
	world.time = (watch.shift+1)*Watch.SHIFT+1.0
	watch.tick(.1,game.player.position)
	var relieving: Array = watch.patrols.filter(func(p): return p.state == "relieve")
	check(relieving.size() == 4 and relieving.map(func(p): return p.post).all(func(i): return i >= 0) and Array(relieving.map(func(p): return p.post)).size() == 4,"Every eight hours a walking pair sets out for each post")
	var coming: Array = []
	for i in 4: coming.append(relieving.filter(func(p): return p.post == i)[0].guards.duplicate())
	var taken = false
	var outside = true
	for t in 1500:
		run_for(game,.2)
		for g in watch.guards(): outside = outside and not Watch.in_arena(g.position)
		taken = true
		for i in 4:
			for k in 2: taken = taken and watch.posts[i].guards[k] in coming[i] and watch.posts[i].guards[k].position.distance_to(watch.posts[i].spots[k].at) < .06
		if taken: break
	check(taken,"Each pair walks to its post and takes the places of the two there")
	check(outside,"On their way to the posts, round the arena, not through it")
	var off_watch: Array = []
	for pair in on_watch: off_watch.append_array(pair)
	check(off_watch.all(func(g): return watch.patrols.any(func(p): return g in p.guards)),"The men relieved walk the town in their turn")
	run_for(game,2.0)
	var facing = true
	for i in 4:
		for k in 2: facing = facing and absf(angle_difference(watch.posts[i].guards[k].rotation.y,watch.posts[i].spots[k].yaw)) < .1 and not watch.posts[i].guards[k].walking
	check(facing,"On watch they stand, facing out as the post does")
	# Spoken to.
	var pair: Dictionary = watch.patrols.filter(func(p): return p.state == "walk")[0] if watch.patrols.any(func(p): return p.state == "walk") else watch.patrols[0]
	var man = pair.guards[0]
	game.player.position = man.position+Vector3(2,0,0)
	var camera: Camera3D = world.camera
	world.follow(game.player.position,1.0)
	check(watch.guard_at(camera,camera.unproject_position(man.position+Vector3.UP)) == man,"The cursor over a guard finds him")
	check(game.speech_cursor().get_width() == 32,"Over him the cursor is a speech bubble")
	game.talk_to(man)
	var held: Array = pair.guards.map(func(g): return g.position)
	run_for(game,Watch.TALK*.8)
	check(pair.guards[0].position.distance_to(held[0]) < .01 and pair.guards[1].position.distance_to(held[1]) < .01 and not pair.guards.any(func(g): return g.walking),"Spoken to, he stops, and the man walking with him")
	var way: Vector3 = game.player.position-man.position
	check(absf(angle_difference(man.rotation.y,atan2(way.x,way.z))) < .05,"He turns to the hero")
	check(game.hud.speeches.size() == 1 and game.hud.speeches[0].speaker == man and game.hud.speeches[0].panel.words == Watch.SAYING,"And says: "+Watch.SAYING)
	# (Typed in a letter at a time, as in the first Temple Ascension.)
	var bubble = game.hud.speeches[0].panel
	bubble.clock = 0.0; game.hud.show_speech(.2)
	var part: int = bubble.line.visible_characters
	game.hud.show_speech(.5)
	check(part > 0 and part < Watch.SAYING.length() and bubble.line.visible_characters > part,"The words type in over time (%d, then %d letters)" % [part,bubble.line.visible_characters])
	game.hud.show_speech(2.0)
	check(bubble.line.visible_characters == Watch.SAYING.length() and game.hud.speeches.size() == 1,"then stay, whole, to be read")
	game.hud.show_speech(bubble.lasts())
	check(game.hud.speeches.is_empty(),"The words go after a while")
	pair.state = "stand"; pair.timer = 0.0
	run_for(game,6.0)
	check(pair.guards[0].position.distance_to(held[0]) > .5,"Then they walk on")
	FileAccess.open("res://test-results/town-watch.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("TOWN_WATCH ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
