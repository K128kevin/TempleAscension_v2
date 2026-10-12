extends SceneTree
## A long shift at Anya's inn (scripts/townsfolk.gd), from the morning into
## the evening: neither Anya nor Selene ever walks or stands in a bench or a
## stool (their seats, as the furniture truly stands, not as the streets'
## coarse grid has it), however they go about the room; Selene clears away
## every mug, plate and bottle left about that no one is using, and leaves
## alone what a drinker is using; and she wipes down the places at the tables
## that no one is using.
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const STEP = .1
const SHIFT = 1500.0
# How wide a body is about its middle, at the least.
const BODY = .15
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)

func _initialize(): call_deferred("test")

# How far a point is into a rectangle of the ground (negative: outside it).
func into(box: Rect2, at: Vector3) -> float:
	var out = Vector2(maxf(maxf(box.position.x-at.x,at.x-box.end.x),0.0),maxf(maxf(box.position.y-at.z,at.z-box.end.y),0.0))
	if out.length() > 0.0: return -out.length()
	return minf(minf(at.x-box.position.x,box.end.x-at.x),minf(at.z-box.position.y,box.end.y-at.z))

func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/inn-shift-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	game.mode = "playing"
	var world = game.world
	var folk = world.townsfolk
	# The seats, as they stand: every bench and stool in the inn, by its
	# meshes' bounds.
	var inn: Rect2 = world.rooms[0].area
	var seats: Array[Rect2] = []
	for node in world.get_children():
		if not node is Node3D or not node.scene_file_path.get_file().get_basename() in ["bench","stool"]: continue
		if not inn.has_point(Vector2(node.position.x,node.position.z)): continue
		var box = AABB()
		var first = true
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var part: AABB = mesh.global_transform*mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		seats.append(Rect2(box.position.x,box.position.z,box.size.x,box.size.z))
	check(seats.size() == 12,"The inn's benches and stools found (%d)" % seats.size())
	var litter_at_start: int = folk.litter.size()
	check(litter_at_start >= 20,"Last night's mugs, plates and bottles are left about the inn (%d)" % litter_at_start)
	var hour: float = Daylight.MORNING+120.0
	world.set_time(hour)
	folk.tick(STEP,Vector3(-262,0,144))
	var worst = {"Anya":-INF,"Selene":-INF}
	var where = {"Anya":"","Selene":""}
	var last = {"Anya":folk.anya.at,"Selene":folk.selene.at}
	var taken_in_use = []
	var wiped_places = {}
	var t = 0.0
	while t < SHIFT:
		hour += STEP
		t += STEP
		world.set_time(hour)
		# What a drinker is using, just before: never to be taken from him.
		var using = []
		for seat in folk.seats:
			if seat.taken == null or not seat.taken.state in ["drink","wait"]: continue
			for thing in folk.litter:
				var at: Vector3 = thing.node.global_position
				if Vector2(seat.mug.x-at.x,seat.mug.z-at.z).length() < folk.USE_REACH*.8: using.append(thing.node)
		var before: Dictionary = folk.wiped.duplicate()
		folk.tick(STEP,Vector3(-262,0,144))
		for node in using:
			if is_instance_valid(node) and not folk.litter.any(func(l): return l.node == node) and not node in taken_in_use: taken_in_use.append(node)
		for i in folk.wiped:
			if folk.wiped[i] != before[i] and folk.wiped[i] > 0.0: wiped_places[i] = true
		if int(t/STEP)%50 == 0: await process_frame
		for who in ["Anya","Selene"]:
			var walker = folk.anya if who == "Anya" else folk.selene
			if not walker.body.visible or not inn.has_point(Vector2(walker.at.x,walker.at.z)):
				last[who] = walker.at
				continue
			# Where it stands, and all along its step since.
			for k in 5:
				var at: Vector3 = last[who].lerp(walker.at,k/4.0)
				for box in seats:
					var deep: float = into(box.grow(BODY),at)
					if deep > worst[who]:
						worst[who] = deep
						where[who] = "%s at %s (%s)" % [walker.state,(at-Interiors.INN).snapped(Vector3.ONE*.01),(box.get_center()-Vector2(Interiors.INN.x,Interiors.INN.z)).snapped(Vector2.ONE*.01)]
			last[who] = walker.at
	for who in ["Anya","Selene"]:
		check(worst[who] <= 0.0,"%s never walks or stands in a bench or a stool (%.3f m in at worst: %s)" % [who,maxf(worst[who],0.0),where[who]])
	var left: Array = folk.clearable()
	check(left.is_empty(),"Selene has cleared away everything left about that no one is using (%d left: %s)" % [left.size(),left.map(func(l): return "%s at %s" % [l.kind,(l.node.global_position-Interiors.INN).snapped(Vector3.ONE*.01)])])
	check(folk.litter.size() < litter_at_start,"She has cleared %d of the %d things left about at the start" % [litter_at_start-folk.litter.size(),litter_at_start])
	check(taken_in_use.is_empty(),"and never takes away what a drinker is using (%d taken)" % taken_in_use.size())
	check(folk.empties.size() >= 3,"The bottles stand in the crate of empties (%d)" % folk.empties.size())
	check(wiped_places.size() >= 4,"She wipes down the places no one is using (%d of %d wiped)" % [wiped_places.size(),folk.seats.size()])
	FileAccess.open("res://test-results/inn-shift.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("INN_SHIFT ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
