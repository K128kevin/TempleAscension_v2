extends SceneTree
## Two of the townspeople walking straight at each other along the same
## line give way and get past (scripts/townsfolk.gd advance, part), rather
## than walking in place, face to face.
const Data = preload("res://scripts/data.gd")
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)
func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/passing-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.run.clock = 500.0
	game.load_floor()
	game.mode = "playing"
	var world = game.world
	world.set_time(500.0)
	var folk = world.townsfolk
	# A long, open, straight stretch of street.
	var middle = Vector3.INF
	var along = Vector3.ZERO
	for h in folk.haunts:
		for d in [Vector3.RIGHT,Vector3.BACK,Vector3(1,0,1).normalized(),Vector3(1,0,-1).normalized()]:
			if folk.clear_way(h.at-d*5.0,h.at+d*5.0): middle = h.at; along = d; break
		if middle != Vector3.INF: break
	check(middle != Vector3.INF,"There is a straight stretch of street to try it on")
	var walkers: Array = folk.people.filter(func(w): return w.state in ["walk","pause"] and not folk.inside(w)).slice(0,2)
	var a = walkers[0]
	var b = walkers[1]
	a.at = middle-along*4.0; b.at = middle+along*4.0
	a.route = PackedVector3Array([middle+along*4.5]); b.route = PackedVector3Array([middle-along*4.5])
	a.state = "walk"; b.state = "walk"
	var a_past = false
	var b_past = false
	var closest = INF
	for t in 600:
		folk.tick(1.0/30,Vector3(-400,0,-400))
		closest = minf(closest,a.at.distance_to(b.at))
		a_past = a_past or (a.at-middle).dot(along) > 3.5
		b_past = b_past or (b.at-middle).dot(along) < -3.5
		if a_past and b_past: break
	check(a_past and b_past,"Walking straight at each other, both get past (%s, %s)" % [a_past,b_past])
	check(closest > .4,"and never walk into each other (%.2f m at the closest)" % closest)
	FileAccess.open("res://test-results/townsfolk-passing.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("TOWNSFOLK_PASSING ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
