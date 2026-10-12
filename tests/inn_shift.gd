extends SceneTree
## A long shift at Anya's inn (scripts/townsfolk.gd), from the morning into
## the evening: neither Anya nor Selene ever walks or stands in a bench or a
## stool (their seats, as the furniture truly stands, not as the streets'
## coarse grid has it), however they go about the room; Selene clears away
## every mug, plate and bottle left about that no one is using, and leaves
## alone what a drinker is using; and she wipes down the places at the tables
## that no one is using. Neither woman ever walks or stands in the bar's
## counter (its top's overhang and all), they never run into each other (no
## nearer than APART, middle to middle), and neither is held up on her way
## for more than HELD seconds. Plates Selene carries rest on her upturned
## palm: nothing of her hand, forearm or sleeve ever comes up through them.
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const STEP = .1
const SHIFT = 1500.0
# How wide a body is about its middle, at the least; how near two may come;
# how long one may be held up on her way; how far her arm may come up into
# the lowest plate she carries, past its underside.
const BODY = .15
const APART = .45
# (A thing just left about, or where Anya is just now serving, may wait.)
const LEFT_LONG = 90.0
const HELD = 3.0
const INTO_PLATE = .002
const GAP = .005
# (Her palm is hollowed a little, under the rest.)
const PALM_GAP = .008
# The counter's top, and how thick a body is about the waist from its spine.
const TOP = 1.12
const WAIST = .1
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

# How far a body `radius` about `at` comes into a rectangle (negative: how
# far it keeps out of it), its corners round as a body's edge is.
func into_round(box: Rect2, at: Vector3, radius: float) -> float:
	return radius+into(box,at)

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
	# The bar's counter: its two long tables, top and all.
	var counter: Array[Rect2] = []
	for node in world.get_children():
		if not node is Node3D or node.scene_file_path.get_file().get_basename() != "table_long": continue
		if not inn.has_point(Vector2(node.position.x,node.position.z)): continue
		var box = AABB()
		var first = true
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var part: AABB = mesh.global_transform*mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		counter.append(Rect2(box.position.x,box.position.z,box.size.x,box.size.z))
	check(counter.size() == 2,"The bar's counter found (%d pieces)" % counter.size())
	# Selene's hand and forearm as they are drawn (her body's points, and her
	# sleeve's, that hang from her left forearm, hand and fingers, read as
	# she is posed), against the lowest plate on her palm: nothing of them
	# above its underside, and the top of her hand no further below it than
	# GAP, her palm than PALM_GAP (the plate rests on it, not over it).
	var selene = folk.selene
	var sk: Skeleton3D = selene.body.skeleton
	var arm_points: Array = []
	for mesh in sk.find_children("*","MeshInstance3D",true,false):
		if mesh.skin == null or not mesh.name in ["Body",selene.body.look.get("under",""),selene.body.look.garment]: continue
		var arrays = mesh.mesh.surface_get_arrays(0)
		var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size()/pts.size()
		var names = []
		for b in mesh.skin.get_bind_count():
			var i = mesh.skin.get_bind_bone(b)
			if i < 0: i = sk.find_bone(mesh.skin.get_bind_name(b))
			names.append(sk.get_bone_name(i))
		for v in pts.size():
			var most = 0.0
			var top = ""
			var bind = []
			for k in per:
				if weights[v*per+k] <= 0.0: continue
				bind.append([bones[v*per+k],weights[v*per+k]])
				if weights[v*per+k] > most:
					most = weights[v*per+k]
					top = names[bones[v*per+k]]
			if not top.ends_with("_l"): continue
			var hand: bool = ["hand","thumb","index","middle","ring","pinky"].any(func(part): return top.begins_with(part))
			if not hand and not top.begins_with("lowerarm"): continue
			arm_points.append({"mesh":mesh,"at":pts[v],"bind":bind,"hand":hand and mesh.name == "Body","part":top})
	var plate_into = {"most":-INF,"gap":-INF,"palm":-INF,"seen":0,"when":"","gap_when":""}
	var read_plates = func():
		var plates: Array = folk.tray.get_children().filter(func(n): return not n.is_queued_for_deletion() and n.visible)
		if plates.is_empty(): return
		var frame: Transform3D = plates[0].global_transform
		var size: Vector3 = frame.basis.get_scale()
		var into_frame: Transform3D = Transform3D(frame.basis.orthonormalized(),frame.origin).affine_inverse()
		var binds = {}
		var hand_top = -INF
		var palm_top = -INF
		for p in arm_points:
			var mesh: MeshInstance3D = p.mesh
			if not binds.has(mesh):
				var list = []
				for b in mesh.skin.get_bind_count():
					var i = mesh.skin.get_bind_bone(b)
					if i < 0: i = sk.find_bone(mesh.skin.get_bind_name(b))
					list.append(sk.global_transform*sk.get_bone_global_pose(i)*mesh.skin.get_bind_pose(b))
				binds[mesh] = list
			var placed = Vector3.ZERO
			for bw in p.bind: placed += (binds[mesh][bw[0]]*p.at)*bw[1]
			var local: Vector3 = into_frame*placed
			# (Under the plate's round, not under its rim's lip, the last of
			# it, which is turned up off the underside.)
			if Vector2(local.x,local.z).length() > size.x*.5*.94: continue
			if local.y > plate_into.most:
				plate_into.most = local.y
				plate_into.when = "%s t=%.2f, her %s (%s)" % [selene.state,selene.phase_time,p.part,mesh.name]
			if p.hand: hand_top = maxf(hand_top,local.y)
			if p.hand and p.part.begins_with("hand"): palm_top = maxf(palm_top,local.y)
		if hand_top > -INF and -hand_top > plate_into.gap:
			plate_into.gap = -hand_top
			plate_into.gap_when = "%s t=%.2f" % [selene.state,selene.phase_time]
		if palm_top > -INF: plate_into.palm = maxf(plate_into.palm,-palm_top)
		plate_into.seen += 1
	sk.skeleton_updated.connect(read_plates)
	var litter_at_start: int = folk.litter.size()
	check(litter_at_start >= 20,"Last night's mugs, plates and bottles are left about the inn (%d)" % litter_at_start)
	var hour: float = Daylight.MORNING+120.0
	world.set_time(hour)
	folk.tick(STEP,Vector3(-262,0,144))
	var worst = {"Anya":-INF,"Selene":-INF}
	var bar = {"Anya":-INF,"Selene":-INF}
	var bar_where = {"Anya":"","Selene":""}
	var nearest = {"gap":INF,"where":""}
	var held = {"Anya":0.0,"Selene":0.0}
	var held_most = {"Anya":0.0,"Selene":0.0}
	var held_where = {"Anya":"","Selene":""}
	var where = {"Anya":"","Selene":""}
	var last = {"Anya":folk.anya.at,"Selene":folk.selene.at}
	var taken_in_use = []
	var left_since = {}
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
		# Since when each thing has been left about for her to clear.
		if int(t/STEP)%10 == 0:
			var now_left = {}
			for l in folk.clearable(): now_left[l.node] = left_since.get(l.node,t)
			left_since = now_left
		folk.tick(STEP,Vector3(-262,0,144))
		for node in using:
			if is_instance_valid(node) and not folk.litter.any(func(l): return l.node == node) and not node in taken_in_use: taken_in_use.append(node)
		for i in folk.wiped:
			if folk.wiped[i] != before[i] and folk.wiped[i] > 0.0: wiped_places[i] = true
		if int(t/STEP)%50 == 0 or folk.tray.get_child_count() > 0: await process_frame
		# The two of them, middle to middle.
		if folk.anya.body.visible and folk.selene.body.visible and inn.has_point(Vector2(folk.anya.at.x,folk.anya.at.z)) and inn.has_point(Vector2(folk.selene.at.x,folk.selene.at.z)):
			var gap: float = Vector2(folk.anya.at.x-folk.selene.at.x,folk.anya.at.z-folk.selene.at.z).length()
			if gap < nearest.gap:
				nearest.gap = gap
				nearest.where = "Anya %s at %s, Selene %s at %s" % [folk.anya.state,(folk.anya.at-Interiors.INN).snapped(Vector3.ONE*.01),folk.selene.state,(folk.selene.at-Interiors.INN).snapped(Vector3.ONE*.01)]
		for who in ["Anya","Selene"]:
			var walker = folk.anya if who == "Anya" else folk.selene
			if not walker.body.visible or not inn.has_point(Vector2(walker.at.x,walker.at.z)):
				last[who] = walker.at
				continue
			# Held up on her way: a route still to go, and no ground made.
			if not walker.route.is_empty() and walker.at.distance_to(last[who]) < .01: held[who] += STEP
			else: held[who] = 0.0
			if held[who] > held_most[who]:
				held_most[who] = held[who]
				held_where[who] = "%s at %s" % [walker.state,(walker.at-Interiors.INN).snapped(Vector3.ONE*.01)]
			# Where it stands, and all along its step since.
			for k in 5:
				var at: Vector3 = last[who].lerp(walker.at,k/4.0)
				for box in counter:
					var deep: float = into_round(box,at,BODY)
					if deep > bar[who]:
						bar[who] = deep
						bar_where[who] = "%s at %s" % [walker.state,(at-Interiors.INN).snapped(Vector3.ONE*.01)]
				for box in seats:
					var deep: float = into_round(box,at,BODY)
					if deep > worst[who]:
						worst[who] = deep
						where[who] = "%s at %s (%s)" % [walker.state,(at-Interiors.INN).snapped(Vector3.ONE*.01),(box.get_center()-Vector2(Interiors.INN.x,Interiors.INN.z)).snapped(Vector2.ONE*.01)]
			# Her hips and waist, wherever she leans: never in the counter
			# below its top.
			var skel: Skeleton3D = walker.body.skeleton
			for bone in ["pelvis","spine_01","spine_02","spine_03"]:
				var at: Vector3 = skel.global_transform*skel.get_bone_global_pose(skel.find_bone(bone)).origin
				if at.y > TOP: continue
				for box in counter:
					var deep: float = into_round(box,at,WAIST)
					if deep > bar[who]:
						bar[who] = deep
						bar_where[who] = "%s: her %s at %s" % [walker.state,bone,(at-Interiors.INN).snapped(Vector3.ONE*.01)]
			last[who] = walker.at
	for who in ["Anya","Selene"]:
		check(worst[who] <= 0.0,"%s never walks or stands in a bench or a stool (%.3f m in at worst: %s)" % [who,maxf(worst[who],0.0),where[who]])
	sk.skeleton_updated.disconnect(read_plates)
	for who in ["Anya","Selene"]:
		check(bar[who] <= 0.0,"%s never walks or stands in the bar's counter (%.3f m in at worst: %s)" % [who,maxf(bar[who],0.0),bar_where[who]])
		check(held_most[who] <= HELD,"%s is never held up on her way for long (%.1f s at most: %s)" % [who,held_most[who],held_where[who]])
	check(nearest.gap >= APART,"Anya and Selene never run into each other (%.2f m apart at nearest: %s)" % [nearest.gap,nearest.where])
	print("PLATES ",plate_into)
	check(plate_into.seen > 20 and plate_into.most < INTO_PLATE,"Nothing of Selene's hand or arm comes up into the plates on her palm (%d looks; %.4f m into the lowest at most, %s)" % [plate_into.seen,maxf(plate_into.most,0.0),plate_into.when])
	check(plate_into.seen > 20 and plate_into.gap < GAP and plate_into.palm < PALM_GAP,"and they rest on her hand, not over it (%.4f m between her hand and the lowest at most, %s; her palm %.4f m under it at most)" % [plate_into.gap,plate_into.gap_when,plate_into.palm])
	var left: Array = folk.clearable().filter(func(l): return t-left_since.get(l.node,t) > LEFT_LONG)
	check(left.is_empty(),"Selene has cleared away everything left about that no one is using (%d left longer than %d s: %s)" % [left.size(),LEFT_LONG,left.map(func(l): return "%s at %s" % [l.kind,(l.node.global_position-Interiors.INN).snapped(Vector3.ONE*.01)])])
	check(folk.litter.size() < litter_at_start,"She has cleared %d of the %d things left about at the start" % [litter_at_start-folk.litter.size(),litter_at_start])
	check(taken_in_use.is_empty(),"and never takes away what a drinker is using (%d taken)" % taken_in_use.size())
	check(folk.empties.size() >= 3,"The bottles stand in the crate of empties (%d)" % folk.empties.size())
	check(wiped_places.size() >= 4,"She wipes down the places no one is using (%d of %d wiped)" % [wiped_places.size(),folk.seats.size()])
	FileAccess.open("res://test-results/inn-shift.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("INN_SHIFT ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
