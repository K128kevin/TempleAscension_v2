extends SceneTree
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
var passed: Array[String] = []
var failed: Array[String] = []
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/map-integration-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.run = Data.new_run(); game.run.seed = 12345
	game.load_floor()
	for floor_index in 6:
		game.run.floor = floor_index; game.run.position = [0,9]; game.run.dead = []; game.run.drops = []
		game.load_floor()
		var all_routes = true
		for enemy in game.enemies:
			var path: PackedVector3Array = game.world.path(game.world.spawn,enemy.position)
			all_routes = all_routes and not path.is_empty()
			var last: Vector3 = game.world.spawn
			for point in path:
				all_routes = all_routes and game.world.walk_line(last,point)
				last = point
		check(all_routes,"Every statue has a safe radius-aware route on floor %d" % [floor_index+1])
		var cells: Dictionary = game.world.layout.cells.duplicate()
		var positions: Array = []
		for enemy in game.enemies: positions.append(enemy.position)
		Data.gain_xp(game.run,maxi(0,Data.xp_at_level(3)-int(game.run.xp)))
		game.run.stats = [7,6,5,6,5]; game.run.points = (int(game.run.level)-1)*Data.STAT_POINTS-4
		game.retry_floor()
		var same = game.world.layout.cells==cells
		for i in game.enemies.size(): same = same and game.enemies[i].position==positions[i]
		check(same and game.run.stats==[7,6,5,6,5],"Retry preserves floor, roster and earned upgrades on floor %d" % [floor_index+1])
		if floor_index<5:
			var path: PackedVector3Array = game.world.path(game.world.spawn,game.world.exit_point)
			var at: Vector3 = game.world.spawn
			for point in path:
				var distance = at.distance_to(point)
				for step in ceili(distance/.09):
					at = game.world.move(at,(point-at).normalized()*minf(.09,at.distance_to(point)))
			check(at.distance_to(game.world.exit_point)<.05,"Actual movement traverses generated entrance-to-exit path on floor %d" % [floor_index+1])
	game.run = Data.new_run(); game.run.seed = 981
	game.load_floor()
	var killed: String = game.enemies[0].uid
	game.enemies[0].hit(10000)
	game.player.position = game.world.exit_point
	game.run.drops = [{"kind":"weapon","value":2,"id":"roundtrip-bow","position":[game.world.spawn.x,game.world.spawn.z]}]
	game.save_run()
	var cells: Dictionary = game.world.layout.cells.duplicate()
	var saved_position: Vector3 = game.player.position
	game.continue_run()
	check(game.world.layout.cells==cells and game.player.position==saved_position,"Save/continue preserves exact generated map and position")
	check(killed in game.run.dead and game.enemies[0].dead and game.pickups.size()==1,"Save/continue preserves defeated statues and pending drops")
	var old = Data.new_run(); old.version=1; old.seed=123; old.stats=[6,7,8,9]
	old.owned=[true,true,true,false]; old.dead=["0:0"]; old.position=[-17,-54]
	old.gems=["already-collected"]
	old.drops=[{"kind":"gem","value":1,"id":"old-loot","position":[-17,-54]}]
	Save.write(old)
	var loaded = Save.load_run()
	check(not loaded.is_empty() and loaded.version==Data.new_run().version,"Legacy saves migrate on load")
	game.run = loaded; game.load_floor()
	check(game.run.version==Data.new_run().version and game.player.position==game.world.spawn,"Legacy run migrates safely to the generated entrance")
	check(game.run.stats==[5,5,5,5,5] and game.run.points>0 and game.run.owned[2] and "0:0" in game.run.dead,"Migration preserves weapons and kills while refunding old stat bonuses")
	check(game.pickups.is_empty(),"Legacy permanent gem drops are retired")
	game.save_run(); game.continue_run()
	check(game.run.version==Data.new_run().version and game.world.fits(game.player.position),"Migrated save round-trips normally")
	FileAccess.open("res://test-results/map-integration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("MAP_INTEGRATION ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed.is_empty() else 1)
