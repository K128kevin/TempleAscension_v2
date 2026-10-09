extends SceneTree
## The arena basement's rats (scripts/rats.gd): where they are put, how they
## run along the walls and from the hero, that they stand still while the
## game is paused and are hidden where he cannot see, and what they cost.
const Data = preload("res://scripts/data.gd")
const Rats = preload("res://scripts/rats.gd")
var passed = 0
var failed: Array[String] = []
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed += 1
	else:
		failed.append(message)
		push_error(message)

func see(game, at: Vector3) -> void:
	for i in 40: game.world.update_visibility(at,.1)

func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/rats-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_run("warrior"); game.run.seed = 4242
	game.run.place = "basement"; game.run.floor = 0
	game.load_floor()
	game.mode = "playing"
	for e in game.enemies: e.dead = true; e.visible = false
	var world = game.world
	var rats = Rats.new()
	world.add_child(rats)
	rats.set_process(false)
	rats.setup(game,30,11)
	check(rats.rats.size() == 30 and rats.rats.all(func(r): return world.fits(r.at,Rats.RADIUS)),"Thirty rats are put on the floor")
	var by_walls: int = rats.rats.filter(func(r):
		var cell: Vector2i = world.layout.to_cell(r.at)
		return [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN].any(func(d): return not world.layout.cells.has(cell+d))).size()
	check(by_walls == 30,"Each starts at the foot of a wall (%d)" % by_walls)
	var copy = Rats.new()
	world.add_child(copy)
	copy.set_process(false)
	copy.setup(game,30,11)
	check(copy.positions() == rats.positions(),"Where they start is fixed by the seed")
	copy.queue_free()
	# Gathered about the hero, they run about and stay on the floor.
	var hero: Vector3 = world.spawn
	game.player.position = hero+Vector3(0,0,40)
	var near: Array = rats.edges.filter(func(e): return e.distance_to(hero) < 14.0 and e.distance_to(hero) > 5.0)
	for i in rats.rats.size(): rats.rats[i].at = near[(i*13)%near.size()]
	var start: Array = rats.positions()
	game.player.position = hero
	see(game,hero)
	var stayed = true
	for f in 600:
		rats.tick(1.0/60)
		for r in rats.rats: stayed = stayed and world.fits(r.at,Rats.RADIUS*.9)
	var moved: int = 0
	for i in rats.rats.size():
		if rats.rats[i].at.distance_to(start[i]) > .5: moved += 1
	check(moved >= 20,"In ten seconds most have darted off somewhere (%d of 30)" % moved)
	check(stayed,"None ever leaves the floor or goes into a wall")
	check(rats.rats.any(func(r): return r.doing == "pause") or rats.rats.any(func(r): return r.doing == "dart"),"They dart and stop by turns")
	# He comes up to one: it runs from him.
	var rat: Dictionary = rats.rats[0]
	rat.doing = "pause"; rat.left = 10.0
	var spot: Vector3 = Vector3.INF
	for d in [Vector3(.8,0,0),Vector3(-.8,0,0),Vector3(0,0,.8),Vector3(0,0,-.8)]:
		if world.fits(rat.at+d,.4): spot = rat.at+d; break
	check(spot != Vector3.INF,"There is room to stand beside a rat")
	game.player.position = spot
	var before: float = rat.at.distance_to(spot)
	rats.tick(1.0/60)
	check(rat.doing == "flee","Too near, it bolts")
	for f in 60: rats.tick(1.0/60)
	check(rat.at.distance_to(spot) > before+1.5,"and gets away from him (%.1f m)" % rat.at.distance_to(spot))
	# Paused, they hold still.
	game.player.position = hero
	game.mode = "character"
	var held: Array = rats.positions()
	for f in 120: rats.tick(1.0/60)
	check(rats.positions() == held,"While the game is paused they hold still")
	game.mode = "playing"
	# Out of his sight they are not drawn; in it, they are.
	see(game,hero)
	var hidden = Vector3.INF
	var shown = Vector3.INF
	for e in rats.edges:
		var gap: float = e.distance_to(hero)
		if hidden == Vector3.INF and gap > 10.0 and gap < 20.0 and not world.can_see(e): hidden = e
		if shown == Vector3.INF and gap > 3.5 and gap < 8.0 and world.can_see(e): shown = e
	check(hidden != Vector3.INF and shown != Vector3.INF,"There are places along the walls in his sight and out of it")
	rats.rats[1].at = hidden; rats.rats[1].doing = "pause"; rats.rats[1].left = 10.0
	rats.rats[2].at = shown; rats.rats[2].doing = "pause"; rats.rats[2].left = 10.0
	rats.tick(1.0/60)
	check(not rats.rats[1].drawn.visible and rats.rats[2].drawn.visible,"Hidden where he cannot see, drawn where he can")
	check(not rats.rats.any(func(r): return r in game.enemies) and rats.get_children().all(func(n): return n is MultiMeshInstance3D and n.multimesh.mesh == Rats.rat_mesh() and n.material_override == rats.material()),"Not enemies; all one mesh and one material")
	# Thirty, all near him, for ten seconds of frames.
	for i in rats.rats.size(): rats.rats[i].at = near[(i*7)%near.size()]
	var clock: int = Time.get_ticks_usec()
	for f in 600: rats.tick(1.0/60)
	var spent: float = (Time.get_ticks_usec()-clock)/1000.0
	print("RATS_COST %.1f ms for 600 frames of 30 rats" % spent)
	check(spent < 600.0,"Thirty rats cost under a millisecond a frame (%.2f ms)" % (spent/600.0))
	FileAccess.open("res://test-results/rats.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("RATS ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
