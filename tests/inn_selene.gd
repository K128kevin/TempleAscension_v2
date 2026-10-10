extends SceneTree
## Anya's inn: the candles lit on its tables and its bar, and Selene, who
## works for Anya (scripts/townsfolk.gd chores): she clears a mug left where
## no one sits, carrying it to the bar, and wipes down a table no one is at,
## her rag going round and round over its top.
const Data = preload("res://scripts/data.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Kit = preload("res://scripts/world_art.gd")
var passed = 0
var failed: Array[String] = []
# The hour, kept here: the steps below go on from it.
var hour = 0.0
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)

func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/inn-selene-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	var world = game.world
	var folk = world.townsfolk
	hour = Daylight.MORNING+300.0
	world.set_time(hour)
	folk.tick(.1,Vector3(-262,0,144))
	# The candles.
	var lit: Array = world.get_children().filter(func(n): return n.name.begins_with("LitCandles"))
	var flames = 0
	var lights = 0
	for candle in lit:
		flames += candle.flames.size()
		if candle.light != null: lights += 1
	var tables: Array = []
	for seat in folk.seats:
		if not seat.table in tables: tables.append(seat.table)
	var on_tables = tables.all(func(t): return lit.any(func(c): return Vector2(c.position.x-t.x,c.position.z-t.z).length() < .1 and c.light != null and c.flames.size() == 3))
	check(on_tables and flames >= 9 and lights == tables.size(),"The candles on the inn's tables are lit, three flames and a little light each; the bar's too (%d flames, %d lights)" % [flames,lights])
	check(lit.all(func(c): return c.flames.all(func(f): return f.visible and f.mesh != null)),"Every flame burns")
	# Selene (the day begun, she has come in from her house to her place).
	var selene = folk.selene
	var run = func(seconds: float, until: Callable) -> bool:
		var t = 0.0
		while t < seconds:
			hour += .1
			t += .1
			world.set_time(hour)
			folk.tick(.1,Vector3(-262,0,144))
			if until.call(): return true
		return false
	var at_work = run.call(60.0,func(): return selene.state == "idle")
	check(selene != null and selene.body.name == "Selene" and at_work and folk.inn.has_point(Vector2(selene.at.x,selene.at.z)),"Selene works in the inn")
	check(folk.named_at(selene.at).get("name","") == "Selene","Her name shows over her")
	check(selene.body.skeleton.find_children("Apron","MeshInstance3D",true,false).size() == 1,"She wears an apron")
	# A mug left where no one sits: she fetches it to the bar.
	var empty: Array = folk.seats.filter(func(s): return s.taken == null)
	check(not empty.is_empty(),"There is an empty place at a table")
	var seat: Dictionary = empty[0]
	var mug = Kit.prop("mug",.17)
	folk.set_down(mug,seat)
	seat.left = mug
	var held = run.call(60.0,func(): return selene.body.held == mug)
	check(held,"She comes for the mug left at an empty place and takes it up")
	var shelved = run.call(30.0,func(): return folk.washing.any(func(w): return w.mug == mug))
	check(shelved and mug.position.distance_to(folk.counter) < .6,"and sets it on the bar to be washed")
	var washed = run.call(90.0,func(): return not is_instance_valid(mug) or mug.is_queued_for_deletion())
	check(washed,"and in time she carries it to the wash")
	# A table no one is at: she wipes it, round and round.
	var table: Vector3 = tables[0]
	for walker in folk.people:
		if not walker.seat.is_empty() and walker.seat.table == table:
			folk.release(walker)
			walker.at = folk.haunts[0].at
			walker.state = "pause"
			walker.timer = 1000.0
			walker.body.play("Idle")
	# (No one else comes in to sit meanwhile.)
	for walker in folk.people:
		if walker.seat.is_empty() and walker.state in ["pause","walk","halt"]:
			walker.state = "pause"
			walker.timer = 1000.0
	for s in folk.seats:
		if s.table == table: folk.clear_mug(s)
	for t in folk.wiped: folk.wiped[t] = -folk.WIPE_REST
	for other in tables:
		if other != table: folk.wiped[other] = folk.chore_clock+10000.0
	var wiping = run.call(90.0,func(): return selene.state == "wipe")
	check(wiping and selene.body.held == folk.rag,"At a table no one is at she sets to wiping it, her rag in hand")
	var spots: Array = []
	var hand: int = selene.body.skeleton.find_bone("hand_l")
	# (Her arm reaches as the skeleton is posed, its modifiers applied: read
	# then, not between.)
	var skeleton: Skeleton3D = selene.body.skeleton
	var wad: Node3D = folk.rag.get_child(0)
	var read = func(): spots.append(wad.global_position)
	for f in 110:
		hour += 1.0/60
		world.set_time(hour)
		folk.tick(1.0/60,Vector3(-262,0,144))
		if f == 40: skeleton.skeleton_updated.connect(read)
		await process_frame
	skeleton.skeleton_updated.disconnect(read)
	var low = INF
	var high = -INF
	var middle = Vector3.ZERO
	for p in spots:
		low = minf(low,p.y); high = maxf(high,p.y)
		middle += p/spots.size()
	var spread = 0.0
	for p in spots: spread = maxf(spread,Vector2(p.x-middle.x,p.z-middle.z).length())
	check(low > .84 and high < .93 and spread > .04 and spread < .2,"Her rag goes round and round on the table's top (%.2f to %.2f m up, %.2f m about)" % [low,high,spread])
	var done = run.call(30.0,func(): return selene.state in ["to_post","idle"] and folk.wiped[table] > 0.0)
	check(done and selene.body.held == null,"Then she puts the rag away and goes back to her place")
	# She goes home at night.
	hour = Daylight.NIGHT+200.0
	world.set_time(hour)
	folk.tick(.1,Vector3(-262,0,144))
	var home = run.call(200.0,func(): return selene.state == "indoors")
	check(home and not selene.body.visible,"At night, the inn shut, she goes home")
	FileAccess.open("res://test-results/inn-selene.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("INN_SELENE ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
