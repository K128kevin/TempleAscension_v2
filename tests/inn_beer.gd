extends SceneTree
## Anya's inn, its mugs and its beer (scripts/townsfolk.gd, scripts/beer.gd):
## every mug keeps its own shape however it is held or set down; Anya pours
## each one full, and its beer goes down a sip at a time, its surface level
## and inside the mug, until it is drained and set by; Anya or Selene clears
## it; Selene is never idle while a mug waits to be cleared; and with every
## table taken and nothing to clear, she clears the bar's end and wipes the
## bar down.
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Kit = preload("res://scripts/world_art.gd")
const Beer = preload("res://scripts/beer.gd")
const Person = preload("res://scripts/townsperson.gd")
const STEP = .1
var passed = 0
var failed: Array[String] = []
var hour = 0.0
var game
var world
var folk
# The worst a mug's shape has been: its axes' lengths against its own size,
# and how far they are from square.
var stretched = 0.0
var skewed = 0.0
var worst = ""
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)

func _initialize(): call_deferred("test")

# Every mug in the inn: before the patrons, in hands, set by, on the bar.
func mugs() -> Array:
	var all: Array = []
	for walker in folk.people:
		if walker.mug != null and is_instance_valid(walker.mug): all.append(walker.mug)
	for seat in folk.seats:
		if seat.left != null and is_instance_valid(seat.left): all.append(seat.left)
	for w in folk.washing:
		if is_instance_valid(w.mug): all.append(w.mug)
	for body in [folk.anya.body,folk.selene.body]:
		if is_instance_valid(body.held) and body.held.name != "Rag": all.append(body.held)
	if is_instance_valid(folk.anya.mug) and folk.anya.mug.is_visible_in_tree(): all.append(folk.anya.mug)
	return all

func measure() -> void:
	var size: Vector3 = Kit.sized("mug",.17)
	for mug in mugs():
		if not mug.is_inside_tree(): continue
		var b: Basis = mug.global_transform.basis
		var lengths = Vector3(b.x.length(),b.y.length(),b.z.length())
		var off: float = maxf(absf(lengths.x/size.x-1.0),maxf(absf(lengths.y/size.y-1.0),absf(lengths.z/size.z-1.0)))
		var skew: float = maxf(absf(b.x.normalized().dot(b.y.normalized())),maxf(absf(b.y.normalized().dot(b.z.normalized())),absf(b.x.normalized().dot(b.z.normalized()))))
		if off > stretched or skew > skewed: worst = "%s under %s" % [mug.name,mug.get_parent().name]
		stretched = maxf(stretched,off)
		skewed = maxf(skewed,skew)

func run(seconds: float, until: Callable = func(): return false) -> bool:
	var t = 0.0
	while t < seconds:
		hour += STEP
		t += STEP
		world.set_time(hour)
		folk.tick(STEP,Vector3(-262,0,144))
		await process_frame
		measure()
		if until.call(): return true
	return false

func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/inn-beer-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	game.mode = "playing"
	world = game.world
	folk = world.townsfolk
	hour = Daylight.MORNING+300.0
	world.set_time(hour)
	folk.tick(.1,Vector3(-262,0,144))
	var selene = folk.selene
	var anya = folk.anya
	await run(60.0,func(): return selene.state == "idle" and anya.state == "post")
	# A patron sat down, starving (his frame narrower than it is tall), to
	# be served.
	var patron = folk.people.filter(func(w): return w.body.look.get("gaunt",0.0) > 0.0)[0]
	folk.release(patron)
	var seat: Dictionary = folk.seats[0]
	seat.taken = patron
	patron.seat = seat
	folk.sit(patron)
	var served = await run(60.0,func(): return patron.state == "drink" and patron.mug != null)
	check(served,"Anya brings the patron his drink")
	var beer = Beer.of(patron.mug) if served else null
	check(served and beer.fill > .99 and beer.visible,"His mug comes full of beer (%.2f)" % (beer.fill if beer else -1.0))
	check(served and beer.material.albedo_color.get_luminance() > Beer.AMBER.get_luminance()+.1,"with a head of foam on it")
	# A sip at a time it goes down, its surface level and inside the mug.
	var levels: Array = [1.0]
	var seen = {"level":true,"inside":true,"idle":0.0}
	var drained = await run(200.0,func():
		if patron.mug == null: return true
		var b = Beer.of(patron.mug)
		if b.fill < levels[-1]-.15 and patron.phase == "": levels.append(snappedf(b.fill,.01))
		if b.visible:
			var frame: Transform3D = patron.mug.global_transform
			seen.level = seen.level and b.global_transform.basis.y.normalized().dot(Vector3.UP) > .999
			var axis_a: Vector3 = frame*Person.MUG_BASE
			var axis_b: Vector3 = frame*Person.MUG_RIM
			var on_axis: Vector3 = Geometry3D.get_closest_point_to_segment(b.global_position,axis_a,axis_b)
			seen.inside = seen.inside and b.global_position.distance_to(on_axis) < .02 and b.global_position.y <= axis_b.y+.005
		return false)
	check(drained,"He drinks it down")
	check(levels.size() >= folk.SIPS and levels.size() <= folk.SIPS+1,"A sip at a time: %s" % [levels])
	check(seen.level,"The beer's surface stays level, however the mug is held")
	check(seen.inside,"and inside the mug, never above its rim")
	var empty: Node3D = seat.left
	check(empty != null and Beer.left_in(empty) <= .001,"Drained, the mug is set by on the table")
	var cleared = await run(60.0,func(): return not is_instance_valid(empty) or empty.is_queued_for_deletion() or selene.body.held == empty or anya.body.held == empty)
	check(cleared,"and Anya or Selene comes to clear it")
	# Selene is never idle while a mug waits.
	for i in 3:
		var other: Dictionary = folk.seats[i+3]
		if other.taken != null: continue
		var mug = Kit.prop("mug",.17)
		folk.set_down(mug,other,true)
		other.left = mug
	await run(90.0,func():
		var waiting = folk.seats.any(func(s): return s.left != null and is_instance_valid(s.left))
		if waiting and selene.state == "idle": seen.idle += STEP
		return not waiting)
	check(seen.idle < 1.5,"Selene is never idle while a mug waits to be cleared (%.1f s)" % seen.idle)
	check(folk.seats.all(func(s): return s.left == null),"She clears them all")
	# The tables all taken and nothing to clear: the bar.
	await run(30.0,func(): return selene.state == "idle")
	var spare: Array = folk.people.filter(func(w): return w.seat.is_empty() and not w in [patron])
	for s in folk.seats:
		if s.taken == null and not spare.is_empty():
			var sitter = spare.pop_back()
			folk.release(sitter)
			s.taken = sitter
			sitter.seat = s
			folk.sit(sitter)
	for i in 2:
		var mug = Kit.prop("mug",.17)
		folk.add_child(mug)
		mug.position = folk.counter+Vector3(.17*i,0,0)
		folk.washing.append({"mug":mug,"left":folk.WASHED})
	var set_on_bar: Array = folk.washing.map(func(w): return w.mug)
	folk.bar_wiped = folk.chore_clock-folk.BAR_REST
	var gathered = await run(60.0,func(): return selene.state in ["gather","to_tub","wash"] and folk.washing.is_empty())
	check(gathered,"Every table taken, she takes up the mugs at the bar's end")
	var washed = await run(30.0,func(): return set_on_bar.all(func(m): return not is_instance_valid(m) or m.is_queued_for_deletion()))
	check(washed,"and washes them in the tub behind the bar")
	var rag_path: Array = []
	var wiping = await run(60.0,func():
		if selene.state == "bar_wipe" and selene.body.held == folk.rag and selene.phase_time > .6 and selene.timer > .6: rag_path.append(folk.rag.global_position)
		return rag_path.size() > 25)
	var over_bar = rag_path.all(func(p): return absf(p.y-folk.BAR_TOP) < .12 and absf(p.z-(folk.Interiors.INN.z+8.5)) < .5)
	var round_and_round = rag_path.size() > 1 and rag_path.front().distance_to(rag_path[rag_path.size()/2]) > .03
	check(wiping and over_bar and round_and_round,"and wipes the bar top down with her rag, round and round (%d points)" % rag_path.size())
	var back = await run(60.0,func(): return selene.state == "idle" and selene.body.held == null)
	check(back,"then puts her rag away")
	check(stretched < .02 and skewed < .01,"No mug is ever stretched or skewed out of its shape (%.3f, %.3f: %s)" % [stretched,skewed,worst])
	print("INN_BEER ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
