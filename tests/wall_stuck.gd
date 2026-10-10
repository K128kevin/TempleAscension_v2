extends SceneTree
## The hero is never stuck at a wall: wherever he stands (pressed against a
## wall, a prop or a corner, or dashed into one), a click away sends him
## walking. On a temple floor, the arena basement's (with its statues, pots
## and crates) and outdoors in the town.
const Data = preload("res://scripts/data.gd")
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)

# Spots hard against something solid: where the hero may stand (they fit him)
# but only just (a hair nearer than a way keeps from walls).
func tight_spots(world, around: Vector3, reach: float, rng: RandomNumberGenerator, count: int) -> Array:
	var spots: Array = []
	for attempt in 40000:
		if spots.size() >= count: break
		var p = around+Vector3(rng.randf_range(-reach,reach),0,rng.randf_range(-reach,reach))
		if world.fits(p,.4) and not world.fits(p,.41): spots.append(p)
	return spots

# He walks from `from` toward `to` by a click's route; how far he gets in
# `seconds`.
func walk(game, from: Vector3, to: Vector3, seconds: float) -> float:
	game.player.position = from
	game.player.busy = 0
	game.target = null
	game.route = game.world.path(from,to)
	var t = 0.0
	while t < seconds:
		game.player_control(1.0/30)
		t += 1.0/30
	return game.player.position.distance_to(from)

func place(game, place: String, floor_index: int) -> void:
	game.run.place = place; game.run.floor = floor_index; game.run.position = [0,9]
	if place == "world": game.run.position = [-230,10]
	game.load_floor()
	game.mode = "playing"
	for e in game.enemies: e.dead = true; e.visible = false

func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/wall-stuck-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_run("warrior"); game.run.seed = 4242
	var rng = RandomNumberGenerator.new(); rng.seed = 11
	for where in [["temple",0],["basement",0],["world",0]]:
		place(game,where[0],where[1])
		var world = game.world
		var home: Vector3 = game.player.position
		var label = "%s %d" % where
		var spots: Array = tight_spots(world,home,14.0 if where[0] != "world" else 20.0,rng,40)
		check(spots.size() >= 20,"Spots hard against walls are found to test (%d): %s" % [spots.size(),label])
		var no_way = 0
		var stuck = 0
		for spot in spots:
			if world.path(spot,home).is_empty(): no_way += 1
			elif walk(game,spot,home,1.5) < .5: stuck += 1
		check(no_way == 0,"From hard against a wall there is always a way (%d without): %s" % [no_way,label])
		check(stuck == 0,"and he walks it, away from the wall (%d stuck): %s" % [stuck,label])
		# Dashed into the walls about him, he walks on afterwards.
		var dash_stuck = 0
		for k in 12:
			game.player.position = home
			game.dash_cooldown = 0
			var way = Vector3(cos(k*TAU/12),0,sin(k*TAU/12))
			game.dash(home+way*6.0)
			for f in 60: game.player_control(1.0/30)
			var after: Vector3 = game.player.position
			if walk(game,after,home,2.0) < minf(.5,after.distance_to(home)*.5): dash_stuck += 1
		check(dash_stuck == 0,"Dashed into a wall, he can walk away (%d stuck): %s" % [dash_stuck,label])
	FileAccess.open("res://test-results/wall-stuck.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("WALL_STUCK ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
