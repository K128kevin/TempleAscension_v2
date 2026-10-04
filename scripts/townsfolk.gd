extends Node3D
## The town's people (scripts/townsperson.gd draws each).
##
## Twenty-five grown townspeople wander the street that rings the arena, the
## market and, now and then, an alley, stopping here and there; two who pass
## may stop a moment to talk. They drift in and out of the inn so that between
## three and eight of them are inside at any moment: one who comes in sits at
## a table and waits; Anya, the innkeeper, fills a mug at the barrels behind
## her bar, carries it over upright in her fist and sets it on the table in
## front of him; he drinks for a minute (lifting the mug to his mouth for a
## sip now and then and setting it down again), then leaves or waits for
## another. Six children run about the streets at their games (tag,
## follow-my-leader, and a rest in a huddle between them); they keep out of
## the inn. Orion, the blacksmith, works in the smithy: hammering at the
## anvil, sharpening a blade on the grindstone, and stoking the forge with
## an iron rod, going from one to the next. No one goes into the arena,
## through the palace gate or out of
## the town.
##
## At night they sleep (scripts/daylight.gd keeps the hour). Through the
## sunset and the first of the night each goes to bed in turn: four who lodge
## at the inn climb to the beds in its loft; those in rags, who have no roof,
## lie down on a straw pallet with its pillow and blanket along the foot of a
## house's wall or under a tree, a bundle of their things by their heads (laid
## out only while they sleep there); the rest go home, each into a house of his own.
## Orion finishes the job in hand and goes into the house nearest his smithy,
## the same every night. Anya, the inn emptied, goes into the kitchen behind
## her bar to her own bed. The children go early, together. Through the
## sunrise they get up and come out again, and the day goes on.
##
## Three stallholders keep the greengrocers' stalls below the market square
## (scripts/world_town.gd stall()). Each comes from his house after sunrise,
## sets out his wares and stands behind his counter; through the sunset he
## packs them away, throws sacking over the counter and goes home to bed. Now
## and then one of the townspeople with a house of his own stops at an open
## stall, talks a moment with its keeper, is handed a crate of what it sells,
## and carries it home; he comes out again a little later.
const Person = preload("res://scripts/townsperson.gd")
const Kit = preload("res://scripts/world_art.gd")
const Town = preload("res://scripts/world_town.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const Art = preload("res://scripts/assets.gd")
const Smith = preload("res://scripts/smith.gd")
const Daylight = preload("res://scripts/daylight.gd")
const ADULTS = 25
const CHILDREN = 6
# How many of the grown townspeople are in the inn at once.
const INN_LEAST = 3
const INN_MOST = 8
# How long a drink lasts, and a sip between whiles.
const DRINK_TIME = 60.0
const WALK = 1.15
const ANYA_WALK = 1.7
const CHILD_RUN = 3.0
# The chance that two who pass stop to talk, and how long before either may again.
const CHAT_CHANCE = .4
const CHAT_REST = 25.0
# The chance that one choosing where to go next heads for the inn, by how
# many are already in it or on their way; and that one who has finished a
# drink leaves, by how many are staying.
const INN_CHANCE = {4:.35,5:.22,6:.14,7:.07}
const LEAVE_CHANCE = {4:.3,5:.5,6:.65,7:.8,8:.92}
# When the grown go to bed (each at his own time between these) and get up;
# the children go together, early. Anya shuts the inn once it is empty, from
# this time, and is up before anyone.
const BEDTIME = Vector2(Daylight.SUNSET+40.0,Daylight.NIGHT+40.0)
const RISING = Vector2(15.0,150.0)
const CHILD_BEDTIME = Daylight.SUNSET+30.0
const CHILD_RISING = 110.0
const ANYA_BEDTIME = Daylight.NIGHT+20.0
const ANYA_RISING = 10.0
# Who lodges at the inn (by their place in LOOKS); those in rags this far
# gone sleep in the street. Of the children, these three do too.
const LODGERS = [11,12,13,23]
const HOMELESS_WEAR = .85
const STREET_CHILDREN = [0,2,4]
# Going to bed, asleep (lying down, or "indoors", unseen) and getting up.
const ABED = ["to_bed","lie_down","asleep","indoors","get_up","from_bed"]
# Lying down is getting up played backward, this much slower.
const LIE_RATE = .6
# How one sleeps: on the back, or on the left side or the right
# (scripts/townsperson.gd).
const SLEEP_POSES = ["Lie","LieLeft","LieRight"]
# One asleep on a bed lies on its mattress, this high, his feet this far
# toward its foot from its middle (he lies back from where he stood: his head
# about .9 m behind).
const MATTRESS = .54
const PILLOW = .3
# A jump of the clock larger than this (a game begun or loaded, the day
# hurried on) puts everyone at once where the hour has them.
const JUMP = 5.0
# The stallholders: one to each stall, in the order of world.stalls.
const KEEPERS = [
	{"who":"woman","garment":"Gown","cloth":Color(.46,.30,.20),"wear":.3,"hair":"Hair_Buns","hair_colour":Color(.12,.08,.05),
		"skin":"dark","belt":Color(.30,.20,.12),"size":.97,"seed":.31},
	{"who":"man","garment":"Robe","cloth":Color(.36,.38,.30),"wear":.35,"hair":"Hair_Buzzed","beard":true,"hair_colour":Color(.20,.14,.09),
		"skin":"light","tone":Color(1.0,.93,.86),"belt":Color(.30,.20,.12),"size":1.0,"seed":.52},
	{"who":"man","garment":"Tunic","cloth":Color(.50,.40,.28),"wear":.4,"hair":"Hair_SimpleParted","beard":true,"hair_colour":Color(.42,.41,.40),
		"skin":"dark","belt":Color(.25,.17,.10),"size":.98,"seed":.64}]
# They shut up shop through the sunset, before the rest go to bed, and open
# up once the sun is up.
const KEEPER_BEDTIME = Vector2(Daylight.SUNSET+5.0,Daylight.SUNSET+45.0)
const KEEPER_RISING = Vector2(40.0,90.0)
# How likely a stroller is to go to the stalls, each time he sets off.
const SHOP_CHANCE = .06
# How long a purchase takes (talk, then the crate handed over), and how
# long its buyer stays at home with it.
const BUY_TIME = 7.0
const HAND_OVER = 2.2
const AT_HOME = Vector2(12.0,30.0)
# Clothes: neutral, undyed or faded.
const CLOTHS = [Color(.74,.68,.56),Color(.52,.50,.47),Color(.42,.33,.25),Color(.60,.52,.40),Color(.42,.42,.30),Color(.38,.40,.42),Color(.50,.36,.28),Color(.78,.75,.68),Color(.30,.29,.27)]
const HAIRS = [Color(.07,.05,.04),Color(.13,.08,.05),Color(.2,.14,.09),Color(.26,.2,.14),Color(.42,.41,.4)]
# The twenty-five: [body, garment, cloth, wear, hair, beard, belt, skin]. Ten
# are in rags, nine in worn and patched clothes, six decently dressed.
const LOOKS = [
	["man","Sack",3,.95,"Hair_Buzzed",true,false,"dark"],["man","Sack",1,.9,"Hair_SimpleParted",false,false,"light"],
	["man","Tunic",8,.88,"",true,true,"light"],["woman","Shift",3,.92,"Hair_Buns",false,false,"dark"],
	["woman","Shift",1,.86,"Hair_Long",false,true,"light"],["man","Robe",2,.9,"Hair_SimpleParted",true,true,"dark"],
	["man","Tunic",0,.6,"Hair_SimpleParted",false,true,"light"],["man","Robe",5,.55,"",true,true,"light"],
	["woman","Gown",4,.6,"Hair_Long",false,true,"dark"],["woman","Gown",6,.5,"Hair_Buns",false,true,"light"],
	["man","Tunic",2,.62,"Hair_Buzzed",true,true,"dark"],
	["man","Tunic",7,.2,"Hair_SimpleParted",true,true,"light"],["woman","Gown",0,.15,"Hair_Long",false,true,"light"],
	["man","Robe",1,.22,"Hair_Buzzed",false,true,"dark"],["woman","Gown",5,.2,"Hair_Buns",false,true,"dark"],
	["man","Sack",8,.93,"",true,false,"light"],["woman","Shift",6,.88,"Hair_Long",false,false,"dark"],
	["man","Tunic",2,.9,"Hair_Buzzed",false,false,"light"],["woman","Shift",4,.95,"Hair_Buns",false,false,"light"],
	["man","Robe",3,.58,"Hair_SimpleParted",true,true,"dark"],["woman","Gown",1,.52,"Hair_Long",false,true,"light"],
	["man","Tunic",5,.64,"",false,true,"light"],["man","Sack",0,.56,"Hair_Buzzed",true,true,"dark"],
	["woman","Gown",7,.18,"Hair_Buns",false,true,"light"],["man","Tunic",6,.24,"Hair_SimpleParted",false,true,"dark"]]

class Walker:
	var body: Node3D
	var state = "pause"
	var route = PackedVector3Array()
	var timer = 0.0
	var speed = 1.15
	var pace = "Walk"
	var chat_rest = 0.0
	var partner: Walker
	var after = "pause"
	# The seat taken (or made for), its mug, and how the visit is going.
	var seat = {}
	var mug: Node3D
	var drinks = 0
	var sip = 0.0
	# A reach of the hand in stages (a sip, a mug set down): which, how far.
	var phase = ""
	var phase_time = 0.0
	var from = Vector3.ZERO
	var child = false
	var repath = 0.0
	# Where it sleeps (lay_beds): "kind" ("inn", "kitchen", "house" or
	# "ground"); "at", where it lies (or the door it goes in by) and "yaw",
	# which way; "side", where it stands to lie down and up again; "way", the
	# last steps there from the streets, and "out", the steps back. And when
	# it goes to bed and gets up, as times of the day.
	var bed = {}
	var bedtime = 0.0
	var rising = 0.0
	# Climbs the stair to the inn's loft: stands on the ground's height there.
	var climbs = false
	# The stall it keeps, or is buying at; and what it carries home from
	# there.
	var stall = {}
	var basket: Node3D
	var at: Vector3:
		get: return body.position
		set(value): body.position = value

var world
var rng = RandomNumberGenerator.new()
# The streets the townspeople keep to, as a grid of their own: the world's
# open ground in the town, less the arena, the palace hill and the smithy.
var grid = AStarGrid2D.new()
var region = Rect2i(-346,-90,166,170)
var haunts: Array[Dictionary] = []
var inn = Rect2()
var seats: Array[Dictionary] = []
var people: Array[Walker] = []
var children: Array[Walker] = []
var anya: Walker
# Orion, the blacksmith, and his work: the anvil he hammers at, the
# grindstone, and the forge he stokes.
var orion: Walker
var smith
# Anya's round: who she is taking a drink to, and where she stands.
var round: Array[Walker] = []
# Where the mug rides in her fist as she carries it, relative to her.
const CARRY = Vector3(.22,1.02,.3)
var post = Vector3.ZERO
var tap = Vector3.ZERO
var bar_end: Array[Vector3] = []
# The children's game: "tag", "follow" or "rest".
var play = {"mode":"rest","timer":4.0,"it":0,"spot":Vector3.ZERO,"next":"tag","freeze":0.0}
var check = 0.0
# Mugs not in a hand or on a table wait here, unseen.
var pantry: Node3D
# The hour last seen (Daylight's), or -1 before the first.
var last_time = -1.0
# The inn's kitchen, under the loft behind the bar, where Anya sleeps.
var kitchen = Rect2()

func setup(overworld) -> void:
	world = overworld
	rng.seed = 90210
	inn = world.rooms[0].area
	pantry = Node3D.new()
	pantry.visible = false
	add_child(pantry)
	lay_grid()
	mark_haunts()
	furnish()
	lay_service()
	var c = Interiors.INN
	post = Vector3(c.x+7.0,0,c.z+7.7)
	tap = Vector3(c.x+9.2,0,c.z+7.7)
	bar_end = [Vector3(c.x+11.9,0,c.z+7.7),Vector3(c.x+11.9,0,c.z+9.6)]
	anya = Walker.new()
	anya.body = figure({"who":"woman","garment":"Dress","under":"Blouse","cloth":Color(.36,.24,.15),"under_cloth":Color(.92,.9,.85),"wear":.06,
		"hair":"Hair_BuzzedFemale","braid":true,"hair_colour":Color(.06,.045,.035),"skin":"light","tone":Color(1.0,.95,.9),"size":.97,"seed":.11})
	anya.body.name = "Anya"
	anya.at = post
	anya.state = "post"
	anya.speed = ANYA_WALK
	anya.mug = Kit.prop("mug",.17)
	stow(anya.mug)
	# Orion: bald, black-bearded, heavy and strong, in a sleeveless brown tunic.
	orion = Walker.new()
	orion.body = figure({"who":"man","garment":"Sack","cloth":Color(.40,.27,.16),"wear":.35,"hair":"","beard":true,"hair_colour":Color(.05,.04,.035),
		"skin":"light","tone":Color(.95,.86,.78),"dirt":.45,"size":1.04,"bulk":1.0,"belt":Color(.25,.17,.1),"shoes":Color(.27,.17,.1),"seed":.77})
	orion.body.name = "Orion"
	smith = Smith.new()
	smith.setup(self,world,orion)
	for i in ADULTS:
		var look: Array = LOOKS[i]
		var wear: float = look[3]
		var walker = Walker.new()
		walker.body = figure({"who":look[0],"garment":look[1],"cloth":CLOTHS[look[2]],"wear":wear,"weave":"hessian" if wear>.8 else "linen",
			"hair":look[4],"beard":look[5],"hair_colour":HAIRS[rng.randi_range(0,HAIRS.size()-1)],"belt":(Color(.42,.36,.26) if wear>.5 else Color(.3,.2,.12)) if look[6] else null,
			"skin":look[7],"tone":Color(1.0,.93,.86) if look[7]=="light" else Color.WHITE,"dirt":clampf(wear*1.1-.1,0.0,1.0),"size":rng.randf_range(.93,1.02),"seed":rng.randf()})
		walker.body.name = "Townsperson%d" % i
		walker.speed = WALK*rng.randf_range(.88,1.12)
		people.append(walker)
		# Five begin at the inn's tables; the rest about the streets.
		if i%5 == 0:
			walker.seat = free_seat()
			walker.seat.taken = walker
			sit(walker)
		else:
			walker.at = haunts[rng.randi_range(0,haunts.size()-1)].at+Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.4,.4))
			walker.body.rotation.y = rng.randf_range(0,TAU)
			walker.timer = rng.randf_range(0.0,6.0)
	for i in CHILDREN:
		var girl = i%2 == 1
		var walker = Walker.new()
		walker.child = true
		walker.body = figure({"who":"woman" if girl else "man","garment":"Shift" if girl else "Sack","cloth":CLOTHS[[3,1,0,2,6,8][i]],"wear":[.92,.85,.8,.95,.9,.86][i],
			"weave":"hessian" if i%3==0 else "linen","hair":["Hair_SimpleParted","Hair_Long","Hair_Buzzed","Hair_Buns","Hair_SimpleParted","Hair_Long"][i],"hair_colour":HAIRS[i%HAIRS.size()],
			"skin":["light","dark","dark","light","dark","light"][i],"dirt":.85,"size":[.6,.57,.66,.62,.58,.64][i],"child":true,"seed":rng.randf()})
		walker.body.name = "Child%d" % i
		walker.at = haunts[3].at+Vector3(i*.9-1.4,0,rng.randf_range(-.5,.5))
		walker.speed = CHILD_RUN
		children.append(walker)
	play.spot = haunts[3].at
	lay_beds()
	hire_keepers()

func figure(look: Dictionary) -> Node3D:
	var person = Person.new()
	add_child(person)
	person.setup(look)
	return person

# ---- The streets ----

func closed(x: int, z: int) -> bool:
	if world.cells[world.index(x,z)] != world.OPEN: return true
	var arena = Vector2((x-Town.ARENA.x)/Town.ARENA_RADII.x,(z-Town.ARENA.z)/Town.ARENA_RADII.y)
	if arena.length() < 1.0 or z < -77 or x > -184: return true
	# (The smithy is open ground for Orion; no one else has business there.)
	return world.height_at(x,z) > .01

func lay_grid() -> void:
	grid.region = region
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for z in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if closed(x,z): grid.set_point_solid(Vector2i(x,z))
	# People keep off the walls: a cell beside one costs more to cross.
	for z in range(region.position.y+1,region.end.y-1):
		for x in range(region.position.x+1,region.end.x-1):
			if grid.is_point_solid(Vector2i(x,z)): continue
			for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if grid.is_point_solid(Vector2i(x,z)+step):
					grid.set_point_weight_scale(Vector2i(x,z),3.0)
					break

func open_at(at: Vector3) -> bool:
	var cell = Vector2i(floori(at.x+.5),floori(at.z+.5))
	return region.has_point(cell) and not grid.is_point_solid(cell)

# The open cell nearest a point (itself, if it is open), or the point.
func nearest_open(at: Vector3, reach: int = 4) -> Vector3:
	var cell = Vector2i(floori(at.x+.5),floori(at.z+.5))
	var best = at
	var least = INF
	for dz in range(-reach,reach+1):
		for dx in range(-reach,reach+1):
			var other = cell+Vector2i(dx,dz)
			if not region.has_point(other) or grid.is_point_solid(other): continue
			var distance = Vector2(other.x-at.x,other.y-at.z).length()
			if distance < least:
				least = distance
				best = Vector3(other.x,0,other.y)
	return best

func clear_way(a: Vector3, b: Vector3) -> bool:
	var steps = maxi(1,ceili(a.distance_to(b)/.4))
	var side = (b-a).normalized().cross(Vector3.UP)*.4
	for i in range(steps+1):
		var at = a.lerp(b,float(i)/steps)
		if not open_at(at) or not open_at(at+side) or not open_at(at-side): return false
	return true

# The way from one place to another by the streets, its corners cut where
# the ground between is open.
func way(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a = nearest_open(from)
	var b = nearest_open(to)
	var cells = grid.get_id_path(Vector2i(roundi(a.x),roundi(a.z)),Vector2i(roundi(b.x),roundi(b.z)))
	var out = PackedVector3Array()
	if cells.is_empty(): return out
	var points: Array[Vector3] = []
	for cell in cells: points.append(Vector3(cell.x,0,cell.y))
	var i = 0
	var here = from
	while i < points.size():
		var ahead = i
		while ahead+1 < points.size() and ahead-i < 14 and clear_way(here,points[ahead+1]): ahead += 1
		out.append(points[ahead])
		here = points[ahead]
		i = ahead+1
	return out

func mark_haunts() -> void:
	var reach = Town.ARENA_RADII+Vector2(Town.RING*.5,Town.RING*.5)
	for k in 28:
		var angle = k*TAU/28.0
		add_haunt(Town.ARENA+Vector3(cos(angle)*reach.x,0,sin(angle)*reach.y),"ring")
	for lane in Town.ALLEYS:
		var long = lane.size.x > lane.size.y
		for t in [.2,.5,.85]:
			add_haunt(Vector3(lane.position.x+lane.size.x*(t if long else .5),0,lane.position.y+lane.size.y*(.5 if long else t)),"alley")
	var market: Rect2 = Town.MARKET
	for spot in [Vector2(.25,.3),Vector2(.7,.35),Vector2(.4,.75),Vector2(.8,.8)]:
		add_haunt(Vector3(market.position.x+market.size.x*spot.x,0,market.position.y+market.size.y*spot.y),"market")
	add_haunt(Vector3(-197,0,0),"market")
	add_haunt(Vector3(-189,0,2),"market")

func add_haunt(at: Vector3, kind: String) -> void:
	var spot = nearest_open(at,5)
	if open_at(spot): haunts.append({"at":spot,"kind":kind})

# ---- The inn ----

# The seats at the inn's tables: where one sits (`at`), facing `face`; where
# he stands to sit down and get up (`step`); where his mug stands (`mug`).
func furnish() -> void:
	var c = Interiors.INN
	var west = Vector3(c.x+4.6,0,c.z+12.6)
	for side in [-1.0,1.0]:
		for along in [-.65,.65]: add_seat(west+Vector3(along,0,side*.98),Vector3(0,0,-side),.5,west)
	var east = Vector3(c.x+13.4,0,c.z+11.0)
	for seat in [Vector3(-.95,0,-.8),Vector3(-.95,0,.7),Vector3(.95,0,-.6),Vector3(.95,0,.8),Vector3(0,0,1.9)]:
		add_seat(east+seat,Vector3(-signf(seat.x),0,0) if absf(seat.x) > .1 else Vector3(0,0,-1),.55,east)

func add_seat(at: Vector3, face: Vector3, height: float, table: Vector3) -> void:
	var step = nearest_open(at-face*1.1,3)
	seats.append({"at":at,"face":face,"height":height,"step":step,"table":table,"taken":null,"left":null})

# Each seat's open side, where Anya stands to serve it, and where the mug is
# set down on the table: at the table's edge before the drinker, toward her.
func lay_service() -> void:
	for seat in seats:
		var side: Vector3 = seat.face.cross(Vector3.UP)
		var room = 0.0
		for sign in [1.0,-1.0]:
			var spot: Vector3 = seat.at+side*sign*.9
			var nearest = INF
			for other in seats:
				if other != seat: nearest = minf(nearest,other.at.distance_to(spot))
			if nearest > room:
				room = nearest
				seat.side = side*sign
		seat.serve = seat.at+seat.side*.55+seat.face*.25
		seat.mug = Vector3(seat.at.x,.87,seat.at.z)+seat.face*.55+seat.side*.22

func free_seat() -> Dictionary:
	var open = seats.filter(func(seat): return seat.taken == null)
	return {} if open.is_empty() else open[rng.randi_range(0,open.size()-1)]

func inside(walker: Walker) -> bool:
	return inn.has_point(Vector2(walker.at.x,walker.at.z))

# How many of the grown townspeople are in the inn.
func patrons() -> int:
	return people.filter(func(w): return inside(w)).size()

func inbound() -> int:
	return people.filter(func(w): return w.state == "to_inn" and not inside(w)).size()

# Those inside who are not on their way out.
func staying() -> int:
	return people.filter(func(w): return inside(w) and not w.state in ["stand_up","leaving"]).size()

func can_enter() -> bool:
	return patrons()+inbound() < INN_MOST and not free_seat().is_empty()

func can_leave() -> bool:
	return staying()-1 >= INN_LEAST

func go_to_inn(walker: Walker) -> bool:
	var seat = free_seat()
	if seat.is_empty(): return false
	var route = way(walker.at,seat.step)
	if route.is_empty(): return false
	seat.taken = walker
	walker.seat = seat
	walker.route = route
	walker.state = "to_inn"
	return true

# Seated at once (as the day begins).
func sit(walker: Walker) -> void:
	var seat: Dictionary = walker.seat
	walker.at = seat.at+seat.face*.3
	walker.body.rotation.y = atan2(seat.face.x,seat.face.z)
	walker.state = "wait"
	walker.body.play("Sit",0.0)
	clear_mug(seat)

func stow(mug: Node3D) -> void:
	if mug.get_parent() != null: mug.get_parent().remove_child(mug)
	pantry.add_child(mug)

func clear_mug(seat: Dictionary) -> void:
	if seat.left != null and is_instance_valid(seat.left): seat.left.queue_free()
	seat.left = null

# ---- Every frame ----

func tick(delta: float, hero: Vector3) -> void:
	delta = minf(delta,.1)
	var now: float = world.time
	if last_time < 0.0 or fposmod(now-last_time,Daylight.CYCLE) > JUMP: at_once()
	last_time = now
	for walker in people: tend(walker,delta)
	for keeper in keepers: keep(keeper,delta)
	bedding()
	serve(delta)
	# Orion goes to bed between jobs.
	if orion.state in ABED: retire(orion,delta)
	elif smith.plan.is_empty() and abed(orion): go_to_bed(orion)
	else: smith.tick(delta)
	# The children play while none of them is abed.
	if children.any(func(c): return c.state in ABED or abed(c)):
		for child in children:
			if child.state in ABED: retire(child,delta)
			elif abed(child): go_to_bed(child)
			elif child.state == "run":
				child.state = "idle"
				child.body.play("Idle")
	else: romp(delta)
	meet(delta)
	part(hero)
	check -= delta
	if check <= 0.0:
		check = .5
		# The inn is never let run low: the nearest stroller is called in.
		if staying()+inbound() <= INN_LEAST and can_enter():
			var strollers = people.filter(func(w): return w.state in ["walk","pause"] and not inside(w) and not abed(w))
			strollers.sort_custom(func(a, b): return a.at.distance_to(world.rooms[0].door) < b.at.distance_to(world.rooms[0].door))
			for walker in strollers:
				if go_to_inn(walker): break

# Walks a walker along its route; true once it has arrived.
func advance(walker: Walker, delta: float) -> bool:
	if walker.route.is_empty(): return true
	var to: Vector3 = walker.route[0]-walker.at
	to.y = 0
	var step = walker.speed*delta
	if to.length() <= step:
		walker.at = Vector3(walker.route[0].x,0,walker.route[0].z)
		walker.route.remove_at(0)
	else: walker.at += to.normalized()*step
	if walker.climbs: walker.at = Vector3(walker.at.x,world.lift(walker.at),walker.at.z)
	walker.body.turn_to(to,delta)
	walker.body.stride(walker.pace,walker.speed)
	return walker.route.is_empty()

func rest(walker: Walker, least: float, most: float) -> void:
	walker.state = "pause"
	walker.timer = rng.randf_range(least,most)
	walker.body.play("Arms" if rng.randf() < .25 else "Idle")

func wander(walker: Walker) -> void:
	var occupancy = staying()+inbound()
	if can_enter() and rng.randf() < INN_CHANCE.get(occupancy,1.0 if occupancy < 4 else 0.0) and go_to_inn(walker): return
	if rng.randf() < SHOP_CHANCE and go_shopping(walker): return
	# Mostly round the arena, sometimes the market, now and then an alley;
	# and somewhere not too near.
	var roll = rng.randf()
	var kind = "ring" if roll < .62 else ("market" if roll < .82 else "alley")
	var choices = haunts.filter(func(h): return h.kind == kind and h.at.distance_to(walker.at) > 12.0 and h.at.distance_to(walker.at) < 110.0)
	if choices.is_empty(): choices = haunts
	walker.route = way(walker.at,choices[rng.randi_range(0,choices.size()-1)].at+Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.4,.4)))
	if walker.route.is_empty(): rest(walker,1.0,3.0)
	else: walker.state = "walk"

func tend(walker: Walker, delta: float) -> void:
	if walker.state in ABED:
		retire(walker,delta)
		return
	# Bedtime: off home from the street (or from the way to the inn); one
	# waiting at a table gets up and goes, unless Anya is bringing his drink.
	if abed(walker):
		if walker.state in ["walk","pause","halt","leaving","to_inn","to_buy","buying","laden","from_home"]:
			go_to_bed(walker)
			return
		if walker.state == "wait" and not walker in round: leave(walker)
		# (At home with his shopping: he stays in for the night.)
		if walker.state == "home":
			walker.state = "indoors"
			walker.at = walker.bed.at
			return
	walker.chat_rest = maxf(0.0,walker.chat_rest-delta)
	walker.timer -= delta
	match walker.state:
		"pause":
			if walker.timer <= 0.0: wander(walker)
		"walk":
			if advance(walker,delta): rest(walker,2.0,9.0)
			# An occasional stop on the way.
			elif rng.randf() < delta*.012:
				walker.after = "walk"
				walker.state = "halt"
				walker.timer = rng.randf_range(2.0,5.0)
				walker.body.play("Idle")
		"halt":
			if walker.timer <= 0.0: walker.state = "walk"
		"chat":
			var other: Walker = walker.partner
			if other != null: walker.body.turn_to(other.at-walker.at,delta,5.0)
			if walker.timer <= 0.0:
				walker.partner = null
				walker.chat_rest = CHAT_REST
				walker.state = walker.after if not walker.route.is_empty() else "pause"
				if walker.state == "pause": walker.timer = rng.randf_range(1.0,3.0)
		"to_inn":
			if advance(walker,delta):
				walker.state = "sit_down"
				walker.timer = walker.body.length("SitDown")
				walker.from = walker.at
				walker.body.play("SitDown",.15)
				clear_mug(walker.seat)
		"sit_down":
			var seat: Dictionary = walker.seat
			var t = clampf(1.0-walker.timer/walker.body.length("SitDown"),0.0,1.0)
			walker.at = walker.from.lerp(seat.at+seat.face*.3,smoothstep(0.0,.7,t))
			walker.body.turn_to(seat.face,delta,10.0)
			if walker.timer <= 0.0:
				walker.state = "wait"
				walker.body.play("Sit")
		"wait":
			# (Anya brings the drink: see serve.) Those at a table with company talk.
			walker.body.reach(Vector3.ZERO,0.0,0.0)
			var company = people.any(func(w): return w != walker and w.state in ["wait","drink"] and w.seat.table == walker.seat.table)
			walker.body.play("SitTalk" if company and fmod(walker.timer,14.0) < -7.0 else "Sit")
		"drink":
			if walker.phase != "": sip(walker,delta)
			else:
				walker.sip -= delta
				if walker.sip <= 0.0:
					walker.sip = rng.randf_range(7.0,13.0)
					walker.phase = "reach"
					walker.phase_time = 0.0
			if walker.timer <= 0.0 and walker.phase == "":
				walker.drinks += 1
				var stays = staying()
				if abed(walker) or can_leave() and (walker.drinks >= 3 or rng.randf() < LEAVE_CHANCE.get(stays,1.0 if stays > 8 else 0.0)): leave(walker)
				else:
					walker.state = "wait"
					walker.timer = 0.0
					walker.body.play("Sit",.3)
		"stand_up":
			var seat: Dictionary = walker.seat
			var t = clampf(1.0-walker.timer/walker.body.length("StandUp"),0.0,1.0)
			walker.at = walker.from.lerp(seat.step,smoothstep(.3,1.0,t))
			if walker.timer <= 0.0:
				seat.taken = null
				walker.seat = {}
				walker.drinks = 0
				var outside = haunts.filter(func(h): return h.kind == "ring")
				walker.route = way(walker.at,outside[rng.randi_range(0,outside.size()-1)].at)
				walker.state = "leaving"
		"leaving":
			if advance(walker,delta): rest(walker,2.0,6.0)
			elif not inside(walker): walker.state = "walk"
		"to_buy","buying","laden","home","from_home": shop(walker,delta)

# A sip: the hand goes to the mug on the table, closes on its handle, lifts
# it to the mouth, sets it down again and lets go.
const SIP = {"reach":.55,"lift":.6,"sip":.9,"lower":.6,"return":.5}

func sip(walker: Walker, delta: float) -> void:
	var seat: Dictionary = walker.seat
	var body = walker.body
	walker.phase_time += delta
	var t = clampf(walker.phase_time/SIP[walker.phase],0.0,1.0)
	var eased = smoothstep(0.0,1.0,t)
	var on_table: Vector3 = body.hand_for(seat.mug+Vector3.UP*world.lift(seat.at))
	var head: Vector3 = body.skeleton.global_transform*body.skeleton.get_bone_global_pose(body.skeleton.find_bone("Head")).origin
	var at_mouth: Vector3 = body.hand_for(head+body.global_transform.basis*Vector3(0,-.17,.09))
	match walker.phase:
		"reach": body.reach(on_table,eased,eased)
		# (The elbow rises out from the side as the mug comes up.)
		"lift": body.reach(on_table.lerp(at_mouth,eased),1.0,1.0,eased)
		"sip": body.reach(at_mouth,1.0,1.0,1.0)
		"lower": body.reach(at_mouth.lerp(on_table,eased),1.0,1.0,1.0-eased)
		"return": body.reach(on_table,1.0-eased,1.0-eased)
	if t < 1.0: return
	walker.phase_time = 0.0
	match walker.phase:
		"reach":
			body.hold(walker.mug)
			walker.phase = "lift"
		"lift": walker.phase = "sip"
		"sip": walker.phase = "lower"
		"lower":
			set_down(walker.mug,seat)
			walker.phase = "return"
		"return": walker.phase = ""

# A mug stood on the table before a seat.
func set_down(mug: Node3D, seat: Dictionary) -> void:
	if mug.get_parent() != null: mug.get_parent().remove_child(mug)
	add_child(mug)
	mug.position = seat.mug+Vector3.UP*world.lift(seat.at)
	mug.rotation = Vector3(0,atan2(seat.face.x,seat.face.z)+PI/2,0)

func leave(walker: Walker) -> void:
	# The mug is left on the table for Anya to clear.
	var seat: Dictionary = walker.seat
	walker.body.reach(Vector3.ZERO,0.0,0.0)
	walker.phase = ""
	if walker.mug != null:
		set_down(walker.mug,seat)
		seat.left = walker.mug
		walker.mug = null
	walker.state = "stand_up"
	walker.timer = walker.body.length("StandUp")
	walker.from = walker.at
	walker.body.play("StandUp",.2)

# Anya: at her post behind the bar until someone is waiting; then to the
# barrels, where she fills a mug, carries it upright in her fist round the
# end of the bar to his seat, sets it on the table before him, and goes back
# for the next.
func serve(delta: float) -> void:
	if anya.state in ABED:
		retire(anya,delta)
		return
	anya.timer -= delta
	anya.phase_time += delta
	var body = anya.body
	match anya.state:
		"post":
			body.turn_to(Vector3(0,0,1),delta,6.0)
			if body.state != "Idle" and body.state != "Arms": body.play("Idle")
			var waiting = people.filter(func(w): return w.state == "wait")
			# Once the last has gone, she goes to bed.
			if abed(anya) and people.all(func(w): return not w.state in ["to_inn","sit_down","wait","drink"]): go_to_bed(anya)
			elif not waiting.is_empty() and anya.timer <= 0.0:
				round.clear()
				round.append(waiting[0])
				anya.route = PackedVector3Array([tap])
				anya.state = "to_tap"
		"to_tap":
			if advance(anya,delta):
				anya.state = "fill"
				anya.phase_time = 0.0
				body.play("Idle",.2)
		"fill":
			# Facing the barrels on their rack against the kitchen wall, she
			# holds the mug under the tap a moment.
			body.turn_to(Vector3(0,0,-1),delta,8.0)
			var t = anya.phase_time
			var spout: Vector3 = body.hand_for(body.global_transform*Vector3(.12,.95,.55))
			if t < .6: body.reach(spout,smoothstep(0.0,1.0,t/.6),smoothstep(0.0,1.0,t/.6))
			elif t < .8 and anya.body.held == null: body.hold(anya.mug)
			elif t >= 2.0:
				next_table(true)
		"carry":
			body.reach(body.hand_for(body.global_transform*CARRY),1.0,1.0)
			if advance(anya,delta):
				anya.state = "place"
				anya.phase_time = 0.0
				body.play("Idle",.2)
		"place":
			var patron: Walker = round[0]
			var seat: Dictionary = patron.seat
			body.turn_to(seat.mug-anya.at,delta,8.0)
			var carried: Vector3 = body.hand_for(body.global_transform*CARRY)
			var on_table: Vector3 = body.hand_for(seat.mug+Vector3.UP*world.lift(seat.at))
			var t = anya.phase_time
			if t < .7: body.reach(carried.lerp(on_table,smoothstep(0.0,1.0,t/.7)),1.0,1.0)
			elif t < .9:
				if body.held != null:
					# The mug stands before him; what was left on the table goes.
					body.hold(null)
					for other in seats:
						if other.table == seat.table and other.taken == null: clear_mug(other)
					if patron.state == "wait":
						if patron.mug != null: patron.mug.queue_free()
						patron.mug = anya.mug
						anya.mug = Kit.prop("mug",.17)
						stow(anya.mug)
						set_down(patron.mug,seat)
						patron.state = "drink"
						patron.timer = DRINK_TIME
						patron.sip = rng.randf_range(2.0,5.0)
					else: set_down(anya.mug,seat)
				body.reach(on_table,1.0,0.0)
			elif t < 1.4: body.reach(on_table,1.0-smoothstep(0.0,1.0,(t-.9)/.5),0.0)
			else:
				body.reach(on_table,0.0,0.0)
				round.remove_at(0)
				next_table(false)
		"return":
			body.reach(Vector3.ZERO,0.0,0.0)
			if advance(anya,delta):
				anya.state = "post"
				anya.timer = rng.randf_range(1.0,3.0)
				body.play("Idle")


func next_table(from_bar: bool) -> void:
	while not round.is_empty() and round[0].state != "wait": round.remove_at(0)
	var route = PackedVector3Array()
	if round.is_empty():
		# Back behind the bar.
		if anya.body.held != null:
			anya.body.hold(null)
			stow(anya.mug)
		route.append_array(way(anya.at,bar_end[1]))
		route.append_array(PackedVector3Array([bar_end[1],bar_end[0],post]))
		anya.state = "return"
	else:
		if from_bar: route.append_array(PackedVector3Array([bar_end[0],bar_end[1]]))
		var patron: Walker = round[0]
		route.append_array(way(bar_end[1] if from_bar else anya.at,patron.seat.serve))
		route.append(patron.seat.serve)
		anya.state = "carry"
	anya.route = route

# ---- Night ----

# Whether it is past its bedtime (or not yet its time to get up).
func abed(walker: Walker) -> bool:
	var t: float = world.time
	return t >= walker.bedtime or t < walker.rising

# Who sleeps where, and when each goes to bed and gets up.
func lay_beds() -> void:
	var sleep = RandomNumberGenerator.new()
	sleep.seed = 1207
	var c = Interiors.INN
	kitchen = Rect2(c.x+1.0,c.z+1.0,Interiors.INN_BAYS.x*Interiors.BAY-2.0,5.6)
	# The loft's four beds (scripts/world_interiors.gd), up the stair by the
	# east wall and along the loft: each lodger stands beside his bed, at its
	# foot's end, and lies down on it. In the morning he comes down and goes
	# out into the town.
	var foot = c+Vector3(18.0,0,13.4)
	var door: Vector3 = world.rooms[0].door
	var bottom = c+Vector3(18.0,0,12.6)
	var top = c+Vector3(18.0,0,6.6)
	var loft: Array[Dictionary] = []
	for i in 4:
		var middle = c+Vector3(3.1+i*4.3,Interiors.LOFT,2.35)
		var side = Vector3(middle.x+1.2,Interiors.LOFT,c.z+3.0)
		var landing = Vector3(side.x,0,c.z+4.6)
		loft.append({"kind":"inn","at":middle+Vector3(0,MATTRESS,PILLOW),"yaw":0.0,"side":side,"way":[foot,bottom,top,landing,side],
			"out":[landing,top,bottom,foot,Vector3(door.x+.5,0,c.z+14.6),door]})
	# Anya's, in the kitchen: from behind the bar, past its east end and the
	# casks by the stair, through the kitchen's door.
	var own: Vector3 = c+Interiors.ANYA_BED
	var beside = own+Vector3(1.15,0,.8)
	var through = [c+Vector3(12.6,0,7.65),c+Vector3(15.6,0,7.45),c+Vector3(16.75,0,6.9),c+Vector3(16.75,0,5.4)]
	var back = through.duplicate()
	back.reverse()
	anya.bed = {"kind":"kitchen","at":own+Vector3(0,MATTRESS,PILLOW),"yaw":0.0,"side":beside,"way":through+[beside],"out":back+[post]}
	anya.bedtime = ANYA_BEDTIME
	anya.rising = ANYA_RISING
	# The houses: Orion's is the one nearest his smithy; the others are
	# shared out among the rest.
	var homes: Array = world.places.filter(func(p): return p.kind == "house" and p.name == "house")
	var smithy: Vector3 = world.rooms[1].door
	homes.sort_custom(func(a, b): return a.at.distance_to(smithy) < b.at.distance_to(smithy))
	orion.bed = house_bed(homes.pop_front())
	orion.bedtime = sleep.randf_range(BEDTIME.x,BEDTIME.y)
	orion.rising = sleep.randf_range(RISING.x,RISING.y)
	for i in range(homes.size()-1,0,-1):
		var j = sleep.randi_range(0,i)
		var swap = homes[i]
		homes[i] = homes[j]
		homes[j] = swap
	var street: Array[Dictionary] = street_beds(sleep)
	for i in ADULTS:
		var walker: Walker = people[i]
		walker.bedtime = sleep.randf_range(BEDTIME.x,BEDTIME.y)
		walker.rising = sleep.randf_range(RISING.x,RISING.y)
		if i in LODGERS:
			walker.bed = loft.pop_front()
			walker.climbs = true
		elif LOOKS[i][3] >= HOMELESS_WEAR and not street.is_empty(): walker.bed = street.pop_back()
		else: walker.bed = house_bed(homes.pop_front())
	for i in CHILDREN:
		var child: Walker = children[i]
		child.bedtime = CHILD_BEDTIME
		child.rising = CHILD_RISING
		child.bed = street.pop_front() if i in STREET_CHILDREN and not street.is_empty() else house_bed(homes.pop_front())
	# Each street sleeper's pallet, and a bundle just beyond his head. (A spot
	# no one sleeps at has nothing laid out there.)
	for walker in people+children:
		if walker.bed.kind != "ground": continue
		var bed: Dictionary = walker.bed
		var ground: Vector3 = bed.at-Vector3.UP*PALLET
		bed.pad = pallet(ground,bed.along,sleep)
		bed.bundle = Kit.prop("bag",.36)
		add_child(bed.bundle)
		bed.bundle.rotation.y = sleep.randf_range(0,TAU)
		bed.bundle.position = ground-bed.along*(.3+.92*walker.body.size)
		bed.bundle.visible = false
	# In the loft and in the street each sleeps as he will: on his back, or on
	# his left side or his right.
	var turns = RandomNumberGenerator.new()
	turns.seed = 3307
	for walker in people+children:
		if walker.bed.kind in ["ground","inn"]: walker.body.sleep_pose = SLEEP_POSES[turns.randi_range(0,SLEEP_POSES.size()-1)]

# Going into a house (a place of the world's): to its doorstep, then to the
# door, where one goes in; and out to the doorstep again in the morning. The
# door is in the house's south face or its west one, whichever way the house
# stands from the step.
func house_bed(place: Dictionary) -> Dictionary:
	var step: Vector3 = nearest_open(place.at)
	var inward = Vector3(0,0,-1)
	var north: Vector2i = world.to_cell(place.at+Vector3(0,0,-2.0))
	if world.cells[world.index(north.x,north.y)] != world.SOLID: inward = Vector3(1,0,0)
	var door: Vector3 = place.at+inward*1.25
	return {"kind":"house","at":door,"yaw":atan2(inward.x,inward.z),"side":door,"way":[step,door],"out":[step]}

# Where those with no roof sleep: on the ground, on a straw pallet, a
# bundle of their things by their heads. Each lies along the foot of a wall
# of the town's houses and shops, or at the foot of a tree, well away from
# the arena, clear of doors, gates and the market, and apart from the others.
# The first three lie end to end along one wall (the street children's).
const ASLEEP_APART = 7.0
func street_beds(sleep: RandomNumberGenerator) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	var trees: Array[Dictionary] = []
	var line = {}
	for z in range(region.position.y+1,region.end.y-1):
		for x in range(region.position.x+1,region.end.x-1):
			var at = Vector3(x,0,z)
			if not sheltered(at): continue
			for into in [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]:
				var along = into.cross(Vector3.UP)
				# A wall the length of a body beside it, room to lie along it,
				# and the street still open beyond.
				if walled(at+into) and walled(at+into+along) and walled(at+into-along) \
					and open_at(at+along) and open_at(at-along) and open_at(at-into) and open_at(at-into*2.0):
					var spot = {"at":at-into*.15,"along":along,"into":into}
					walls.append(spot)
					line[[x,z,into]] = spot
	# At the foot of a tree: a palm by the streets, an olive or a dead tree out
	# at the town's edges.
	for node in world.get_children():
		if not node is Node3D or not (node.scene_file_path.get_file().begins_with("palm") or node.scene_file_path.get_file().get_basename() in ["olive_a","olive_b","dead_tree"]): continue
		var trunk = Vector3(node.position.x,0,node.position.z)
		if not region.has_point(Vector2i(roundi(trunk.x),roundi(trunk.z))): continue
		for k in 8:
			var out = Vector3(cos(k*TAU/8.0),0,sin(k*TAU/8.0))
			var along = out.cross(Vector3.UP)
			var at = trunk+out*1.15
			if open_at(at) and open_at(at+along) and open_at(at-along) and sheltered(at.round()):
				trees.append({"at":at,"along":along,"into":-out})
				break
	# The children's: three spots along one wall, two metres apart, as near
	# Beggars' Alley in the south-west as can be.
	var chosen: Array[Dictionary] = []
	var best = INF
	for key in line:
		var spot: Dictionary = line[key]
		var step = Vector3i(roundi(spot.along.x)*2,0,roundi(spot.along.z)*2)
		var run = [spot]
		for k in [1,2]:
			var next = [key[0]+step.x*k,key[1]+step.z*k,key[2]]
			if line.has(next): run.append(line[next])
		if run.size() < 3: continue
		var far = spot.at.distance_to(Vector3(-300,0,60))
		if far < best:
			best = far
			chosen.assign(run)
	for list in [walls,trees]:
		for k in range(list.size()-1,0,-1):
			var j = sleep.randi_range(0,k)
			var swap = list[k]
			list[k] = list[j]
			list[j] = swap
	# The rest by turns at a wall and under a tree.
	var pool: Array[Dictionary] = []
	for k in maxi(walls.size(),trees.size()):
		if k < trees.size(): pool.append(trees[k])
		if k < walls.size(): pool.append(walls[k])
	var rest: Array[Dictionary] = []
	for spot in pool:
		if (chosen+rest).all(func(c): return c.at.distance_to(spot.at) > ASLEEP_APART): rest.append(spot)
	# (The grown take theirs from the back: the first chosen, by turns under a
	# tree and at a wall.)
	rest.reverse()
	chosen.append_array(rest)
	var beds: Array[Dictionary] = []
	for spot in chosen:
		var at: Vector3 = spot.at
		# Head toward either end, as it falls.
		var along: Vector3 = spot.along*(1.0 if sleep.randf() < .5 else -1.0)
		# (He lies on the pallet, just off the ground. Its pallet and bundle
		# are made once someone is given the spot: lay_beds().)
		beds.append({"kind":"ground","at":at+Vector3.UP*PALLET,"yaw":atan2(along.x,along.z),"side":at,"way":[at],"out":[],"along":along})
	return beds

# Somewhere one might lie down for the night: open street, away from the
# arena (beyond its ring street), and clear of doors, gates and the markets.
func sheltered(at: Vector3) -> bool:
	if not open_at(at): return false
	var arena = Vector2(at.x-Town.ARENA.x,at.z-Town.ARENA.z)/(Town.ARENA_RADII+Vector2(Town.RING-3.0,Town.RING-3.0))
	if arena.length() < 1.0: return false
	var flat = Vector2(at.x,at.z)
	for place in world.places:
		if place.kind in ["house","shop","inn","gate","well","market"] and place.at.distance_to(at) < (12.0 if place.kind == "gate" else place.radius+2.5): return false
	# Nor on the way up to the elders' palace.
	if absf(at.x-world.HILL.x) < world.HILL_HALF.x+world.HILL_SLOPE and at.z < world.HILL.z+world.HILL_HALF.y+world.HILL_SLOPE+8.0: return false
	if world.rooms.any(func(room): return room.area.grow(2.0).has_point(flat) or room.door.distance_to(at) < 6.0): return false
	for market in [Town.MARKET,Town.GREENGROCERS]:
		if market.grow(2.0).has_point(flat): return false
	return true

# A building's wall (not the rock round the town: what stands well inside
# the open ground).
func walled(at: Vector3) -> bool:
	var cell: Vector2i = world.to_cell(at)
	return world.cells[world.index(cell.x,cell.y)] == world.SOLID and world.margin_at(at) > 2.0

# What one sleeps on in the street (tools/make_bedroll.py): a sheet of old
# sacking spread on the ground, creased and folded, a woollen blanket thrown
# half over it and a stuffed sack for a pillow at its head (toward -`along`),
# in the townspeople's photographed cloth (assets/shaders/cloth.gdshader),
# faded, stained and grimed.
const RAGS = [Color(.40,.37,.32),Color(.46,.40,.32),Color(.34,.33,.31),Color(.50,.45,.37),Color(.38,.38,.37),Color(.42,.33,.27)]
const BLANKETS = [Color(.42,.20,.14),Color(.30,.32,.36),Color(.46,.38,.24),Color(.30,.34,.26),Color(.52,.47,.40)]
# How far off the ground he lies on it.
const PALLET = .03
func pallet(at: Vector3, along: Vector3, sleep: RandomNumberGenerator) -> Node3D:
	var pad = Art.model("bedroll",Vector3.ONE)
	var sacking: Color = RAGS[sleep.randi_range(0,RAGS.size()-1)]*sleep.randf_range(.9,1.1)
	var blanket: Color = BLANKETS[sleep.randi_range(0,BLANKETS.size()-1)]*sleep.randf_range(.85,1.1)
	var seed = sleep.randf_range(0.0,10.0)
	for mesh in pad.find_children("*","MeshInstance3D",true,false):
		var woollen = mesh.name.begins_with("Blanket")
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/cloth.gdshader")
		m.set_shader_parameter("weave",load("res://assets/textures/cloth_%s.jpg" % ("linen" if woollen else "hessian")))
		m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
		m.set_shader_parameter("weave_scale",4.0 if woollen else 5.0)
		var dye: Color = blanket if woollen else sacking
		m.set_shader_parameter("dye",Vector3(dye.r,dye.g,dye.b))
		m.set_shader_parameter("wear",.45 if woollen else (.38 if mesh.name.begins_with("Pillow") else .55))
		m.set_shader_parameter("seed",seed)
		# The blanket is woven in a lozenge pattern of a paler thread.
		if woollen:
			m.set_shader_parameter("lattice",1.0)
			m.set_shader_parameter("band_dye",Vector3(dye.r,dye.g,dye.b)*1.25)
		var inside: ShaderMaterial = m.duplicate()
		inside.shader = load("res://assets/shaders/cloth_inside.gdshader")
		m.next_pass = inside
		mesh.material_override = m
	add_child(pad)
	pad.position = at
	pad.rotation.y = atan2(along.x,along.z)+sleep.randf_range(-.06,.06)
	pad.visible = false
	return pad

# A street sleeper's pallet and bundle are laid out while he lies there.
func bedding() -> void:
	for walker in people+children:
		if walker.bed.get("kind") != "ground": continue
		var down = walker.state in ["lie_down","asleep","get_up"]
		walker.bed.pad.visible = down
		walker.bed.bundle.visible = down

# Off to bed: by the streets to its bed's last steps, and along them.
func go_to_bed(walker: Walker) -> void:
	release(walker)
	var bed: Dictionary = walker.bed
	var route = PackedVector3Array()
	if bed.kind != "kitchen": route = way(walker.at,bed.way[0])
	route.append_array(PackedVector3Array(bed.way))
	walker.route = route
	walker.state = "to_bed"
	if walker.child:
		walker.speed = WALK*1.2
		walker.pace = "Walk"
	if walker == orion: orion.body.figure.position.y = 0.0

# Going to bed, asleep, and getting up.
func retire(walker: Walker, delta: float) -> void:
	walker.timer -= delta
	var bed: Dictionary = walker.bed
	var body = walker.body
	var lying: float = body.length("GetUp")
	match walker.state:
		"to_bed":
			if advance(walker,delta):
				if bed.kind == "house":
					# In at the door.
					body.visible = false
					walker.state = "indoors"
				else:
					walker.state = "lie_down"
					walker.timer = lying/LIE_RATE
					walker.from = walker.at
					body.lie_down(LIE_RATE)
		"lie_down":
			var t = clampf(1.0-walker.timer*LIE_RATE/lying,0.0,1.0)
			walker.at = walker.from.lerp(bed.at,smoothstep(.15,.8,t))
			body.rotation.y = lerp_angle(body.rotation.y,bed.yaw,minf(1.0,delta*6.0))
			if walker.timer <= 0.0:
				walker.state = "asleep"
				body.rotation.y = bed.yaw
				body.play("Lie",.4)
		"asleep","indoors":
			if not abed(walker): rise(walker)
		"get_up":
			var t = clampf(1.0-walker.timer/lying,0.0,1.0)
			walker.at = bed.at.lerp(bed.side,smoothstep(.2,.85,t))
			if walker.timer <= 0.0:
				walker.route = PackedVector3Array(bed.out)
				walker.state = "from_bed"
		"from_bed":
			if advance(walker,delta): up(walker)

# Morning: out of the door, or up off the bed or the ground.
func rise(walker: Walker) -> void:
	var body = walker.body
	if walker.bed.kind == "house":
		body.visible = true
		walker.at = walker.bed.at
		body.rotation.y = walker.bed.yaw+PI
		walker.route = PackedVector3Array(walker.bed.out)
		walker.state = "from_bed"
	else:
		walker.state = "get_up"
		walker.timer = body.length("GetUp")
		body.play("GetUp",.4)

# Up and out: back to the day.
func up(walker: Walker) -> void:
	walker.route = PackedVector3Array()
	if walker == anya:
		anya.state = "post"
		anya.timer = rng.randf_range(1.0,3.0)
		anya.body.play("Idle")
	# (Orion goes back to his work: scripts/smith.gd takes him there.)
	elif walker == orion: orion.state = "work"
	elif walker.child:
		walker.state = "idle"
		walker.body.play("Idle")
	# A stallholder goes to his stall.
	elif walker in keepers:
		walker.route = way(walker.at,walker.stall.keeper)
		walker.route.append(walker.stall.keeper)
		walker.state = "to_stall"
	else: rest(walker,1.0,4.0)

# Lets go of whatever it was about: a talk, a seat at the inn and its mug,
# the drink Anya was carrying.
func release(walker: Walker) -> void:
	walker.partner = null
	walker.phase = ""
	walker.body.reach(Vector3.ZERO,0.0,0.0)
	if walker.body.held != null: walker.body.hold(null)
	if not walker.seat.is_empty():
		walker.seat.taken = null
		walker.seat = {}
	walker.drinks = 0
	# Shopping put down, a stall's customer gone.
	if walker.basket != null:
		walker.basket.queue_free()
		walker.basket = null
	walker.pace = "Walk"
	if not walker in keepers and not walker.stall.is_empty():
		if walker.stall.get("customer") == walker: walker.stall.customer = null
		walker.stall = {}
	if walker == anya:
		round.clear()
		stow(anya.mug)
	elif walker.mug != null:
		walker.mug.queue_free()
		walker.mug = null

# Abed at once (the clock has jumped).
func tuck(walker: Walker) -> void:
	release(walker)
	var bed: Dictionary = walker.bed
	var body = walker.body
	if walker == orion:
		smith.down_tools()
		body.figure.position.y = 0.0
	walker.route = PackedVector3Array()
	walker.at = bed.at
	body.rotation.y = bed.yaw
	if bed.kind == "house":
		body.visible = false
		walker.state = "indoors"
	else:
		body.visible = true
		walker.state = "asleep"
		body.play("Lie",0.0)

# Up at once (the clock has jumped): just out of the house, or off the stair,
# or up beside where it slept.
func rouse(walker: Walker) -> void:
	var bed: Dictionary = walker.bed
	walker.body.visible = true
	walker.at = bed.out[-1] if not bed.out.is_empty() else bed.side
	up(walker)

# The clock has jumped (a game begun or loaded, the day hurried on): each is
# put at once where the hour has him, as though he had gone there.
func at_once() -> void:
	for walker in people+children+[anya,orion]+keepers:
		if abed(walker) and not walker.state in ["asleep","indoors"]: tuck(walker)
		elif not abed(walker) and walker.state in ABED: rouse(walker)
	# The stalls are open or shut as the hour has them, their keepers behind
	# the open ones.
	for keeper in keepers:
		if keeper.state in ABED:
			set_open(keeper.stall,false)
			continue
		if keeper.state != "keep":
			keeper.route = PackedVector3Array()
			keeper.at = keeper.stall.keeper
			keeper.body.rotation.y = atan2(keeper.stall.front.x,keeper.stall.front.z)
			stand(keeper)
		set_open(keeper.stall,true)
	# Some are at the inn's tables, as when the day began.
	if people.any(func(w): return w.state in ["sit_down","wait","drink"]): return
	for i in people.size():
		var walker: Walker = people[i]
		if i%5 != 0 or abed(walker) or not walker.state in ["walk","pause"]: continue
		var seat = free_seat()
		if seat.is_empty(): break
		walker.seat = seat
		seat.taken = walker
		sit(walker)

# ---- The greengrocers ----

var keepers: Array[Walker] = []

# A stallholder for each stall, living in the free house nearest it.
func hire_keepers() -> void:
	var taken: Array = (people+children+[orion]).filter(func(w): return w.bed.get("kind") == "house").map(func(w): return w.bed.at)
	var homes: Array = world.places.filter(func(p): return p.kind == "house" and p.name == "house")
	var hours = RandomNumberGenerator.new()
	hours.seed = 3307
	for i in mini(KEEPERS.size(),world.stalls.size()):
		var stall: Dictionary = world.stalls[i]
		stall.customer = null
		var keeper = Walker.new()
		keeper.body = figure(KEEPERS[i])
		keeper.body.name = "Stallholder%d" % i
		keeper.stall = stall
		keeper.speed = WALK*hours.randf_range(.92,1.05)
		keeper.at = stall.keeper
		var free = homes.filter(func(h): return taken.all(func(t): return house_bed(h).at.distance_to(t) > .5))
		free.sort_custom(func(a, b): return a.at.distance_to(stall.at) < b.at.distance_to(stall.at))
		keeper.bed = house_bed(free[0])
		taken.append(keeper.bed.at)
		keeper.bedtime = hours.randf_range(KEEPER_BEDTIME.x,KEEPER_BEDTIME.y)
		keeper.rising = hours.randf_range(KEEPER_RISING.x,KEEPER_RISING.y)
		keepers.append(keeper)
		stand(keeper)

# Its wares out on the counter (open), or packed away under sacking.
func set_open(stall: Dictionary, open: bool) -> void:
	stall.open = open
	for ware in stall.wares: ware.visible = open
	for sheet in stall.cover: sheet.visible = not open

func stand(keeper: Walker) -> void:
	keeper.state = "keep"
	keeper.timer = rng.randf_range(4.0,10.0)
	keeper.body.play("Idle")

# A stallholder's day: to his stall, setting out his wares, serving, and
# packing up again at dusk and going home.
func keep(keeper: Walker, delta: float) -> void:
	if keeper.state in ABED:
		retire(keeper,delta)
		return
	keeper.timer -= delta
	var stall: Dictionary = keeper.stall
	var reach: float = keeper.body.length("Reach")
	match keeper.state:
		"to_stall":
			if advance(keeper,delta):
				keeper.state = "opening"
				keeper.timer = reach*2.0
				keeper.body.play("Reach")
		"opening","closing":
			# Twice over the counter: setting out the crates, or packing them
			# away and throwing the sacking over.
			keeper.body.turn_to(stall.front,delta,6.0)
			if keeper.timer <= reach and keeper.body.state == "Reach" and keeper.phase == "":
				keeper.phase = "again"
				keeper.body.state = ""
				keeper.body.play("Reach",.2)
				set_open(stall,keeper.state == "opening")
			if keeper.timer <= 0.0:
				keeper.phase = ""
				if keeper.state == "opening": stand(keeper)
				else: go_to_bed(keeper)
		"keep":
			var customer: Walker = stall.customer
			if customer != null and customer.state == "buying":
				keeper.body.turn_to(customer.at-keeper.at,delta,5.0)
				keeper.body.play("Reach" if customer.timer < HAND_OVER else "Talk")
			else:
				keeper.body.turn_to(stall.front,delta,4.0)
				if abed(keeper) and customer == null:
					keeper.state = "closing"
					keeper.timer = reach*2.0
					keeper.body.play("Reach")
				elif keeper.timer <= 0.0:
					keeper.timer = rng.randf_range(5.0,12.0)
					keeper.body.play("Arms" if rng.randf() < .35 else "Idle")
				elif not keeper.body.state in ["Idle","Arms"]: keeper.body.play("Idle")

# Off to an open stall nobody else is buying at; only one with a house to
# take his shopping home to goes.
func go_shopping(walker: Walker) -> bool:
	if walker.child or walker.bed.get("kind") != "house" or abed(walker): return false
	var open = world.stalls.filter(func(s): return s.get("open",false) and s.get("customer") == null)
	if open.is_empty(): return false
	var stall: Dictionary = open[rng.randi_range(0,open.size()-1)]
	var route = way(walker.at,stall.buyer)
	if route.is_empty(): return false
	route.append(stall.buyer)
	stall.customer = walker
	walker.stall = stall
	walker.route = route
	walker.state = "to_buy"
	return true

# At the stall, home with a crate of what it sells, and out again.
func shop(walker: Walker, delta: float) -> void:
	var stall: Dictionary = walker.stall
	match walker.state:
		"to_buy":
			# (A stall shut while he was on his way: he goes about his day.)
			if not stall.get("open",false):
				release(walker)
				rest(walker,1.0,3.0)
			elif advance(walker,delta):
				walker.state = "buying"
				walker.timer = BUY_TIME
				walker.body.play("Talk")
		"buying":
			walker.body.turn_to(-stall.front,delta,6.0)
			if walker.timer < HAND_OVER and walker.body.state != "Reach": walker.body.play("Reach")
			if walker.timer <= 0.0:
				stall.customer = null
				walker.basket = produce(stall.goods[0])
				add_child(walker.basket)
				walker.pace = "Carry"
				walker.route = way(walker.at,walker.bed.way[0])
				walker.route.append_array(PackedVector3Array(walker.bed.way))
				walker.state = "laden"
		"laden":
			var home = advance(walker,delta)
			carry(walker)
			if home:
				# In at his door, the crate with him.
				walker.basket.queue_free()
				walker.basket = null
				walker.pace = "Walk"
				walker.body.visible = false
				walker.state = "home"
				walker.timer = rng.randf_range(AT_HOME.x,AT_HOME.y)
		"home":
			if walker.timer <= 0.0:
				walker.body.visible = true
				walker.at = walker.bed.at
				walker.body.rotation.y = walker.bed.yaw+PI
				walker.route = PackedVector3Array(walker.bed.out)
				walker.stall = {}
				walker.state = "from_home"
		"from_home":
			if advance(walker,delta): rest(walker,2.0,6.0)

# A small crate of a stall's goods, to be carried home.
func produce(goods: String) -> Node3D:
	if goods == "carrots": return Kit.prop("carrot_crate",.26)
	var crate = Kit.prop("farm_crate",.15)
	Kit.produce(crate,Town.FRUIT[goods])
	return crate

# The crate held out in front in both hands, as the carrying walk holds it.
func carry(walker: Walker) -> void:
	var skeleton: Skeleton3D = walker.body.skeleton
	var hands = Vector3.ZERO
	for side in ["hand_l","hand_r"]: hands += (skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(side))).origin
	walker.basket.global_position = hands*.5+Vector3.DOWN*.05
	walker.basket.rotation.y = walker.body.rotation.y

# ---- Talk ----

# Two who pass each other may stop and talk a moment.
func meet(_delta: float) -> void:
	for i in people.size():
		var a: Walker = people[i]
		if a.state != "walk" or a.chat_rest > 0.0: continue
		for j in range(i+1,people.size()):
			var b: Walker = people[j]
			if b.state != "walk" or b.chat_rest > 0.0 or a.at.distance_to(b.at) > 2.6: continue
			if rng.randf() < CHAT_CHANCE:
				var time = rng.randf_range(4.0,9.0)
				for pair in [[a,b],[b,a]]:
					var walker: Walker = pair[0]
					walker.partner = pair[1]
					walker.after = "walk"
					walker.state = "chat"
					walker.timer = time
				a.body.play("Talk")
				b.body.play("Idle" if rng.randf() < .4 else "Talk")
			else:
				# They pass with a nod; no second chance for a while.
				a.chat_rest = CHAT_REST*.5
				b.chat_rest = CHAT_REST*.5
			break

# No two stand in the same spot, and all give way to the hero.
func part(hero: Vector3) -> void:
	var loose: Array[Walker] = []
	for walker in people+children+[anya]:
		if walker.state in ["walk","pause","halt","chat","leaving","to_inn","run","idle"]: loose.append(walker)
	for i in loose.size():
		var a: Walker = loose[i]
		var away: Vector3 = a.at-Vector3(hero.x,0,hero.z)
		if away.length() < .75 and away.length() > .01: nudge(a,away.normalized()*(.75-away.length()))
		for j in range(i+1,loose.size()):
			var b: Walker = loose[j]
			var apart: Vector3 = a.at-b.at
			var gap = .62 if not (a.state == "chat" and b.state == "chat") else .95
			if apart.length() >= gap or apart.length() < .01: continue
			var push = apart.normalized()*(gap-apart.length())*.5
			nudge(a,push)
			nudge(b,-push)

func nudge(walker: Walker, by: Vector3) -> void:
	if open_at(walker.at+by): walker.at += by

# ---- The children ----

func romp(delta: float) -> void:
	play.timer -= delta
	play.freeze = maxf(0.0,play.freeze-delta)
	if play.timer <= 0.0:
		if play.mode == "rest":
			play.mode = play.next
			play.next = "follow" if play.mode == "tag" else "tag"
			play.timer = rng.randf_range(32.0,55.0)
			play.it = rng.randi_range(0,CHILDREN-1)
			for child in children: child.route = PackedVector3Array()
		else:
			# A rest in a huddle at the nearest corner.
			var middle = Vector3.ZERO
			for child in children: middle += child.at/CHILDREN
			var nearest = haunts[0]
			for haunt in haunts:
				if haunt.at.distance_to(middle) < nearest.at.distance_to(middle): nearest = haunt
			play.spot = nearest.at
			play.mode = "rest"
			play.timer = rng.randf_range(9.0,15.0)
			for i in CHILDREN: children[i].route = way(children[i].at,play.spot+Vector3(cos(i*TAU/CHILDREN),0,sin(i*TAU/CHILDREN))*1.0)
	for i in CHILDREN:
		var child: Walker = children[i]
		child.repath -= delta
		child.state = "run"
		match play.mode:
			"rest":
				child.speed = CHILD_RUN*.8
				if child.route.is_empty():
					child.state = "idle"
					child.body.turn_to(play.spot-child.at,delta,6.0)
					# They take turns to show off.
					child.body.play("Dance" if int(play.timer/3.0)%CHILDREN == i else "Talk")
			"tag":
				var it: Walker = children[play.it]
				if i == play.it:
					child.speed = CHILD_RUN*1.12
					if play.freeze > 0.0:
						# Just caught: he counts before he gives chase.
						child.state = "idle"
						child.route = PackedVector3Array()
						child.body.play("Idle")
					elif child.repath <= 0.0:
						child.repath = .6
						var quarry: Walker = null
						for other in children:
							if other != child and (quarry == null or other.at.distance_to(child.at) < quarry.at.distance_to(child.at)): quarry = other
						child.route = way(child.at,quarry.at)
						if quarry.at.distance_to(child.at) < 1.2:
							play.it = children.find(quarry)
							play.freeze = 2.0
							for other in children: other.repath = 0.0
				else:
					child.speed = CHILD_RUN
					if child.route.is_empty() or (child.repath <= 0.0 and it.at.distance_to(child.at) < 7.0):
						child.repath = 2.5
						child.route = way(child.at,flee(child,it))
			"follow":
				if i == 0:
					child.speed = CHILD_RUN*.85
					if child.route.is_empty():
						var choices = haunts.filter(func(h): return h.at.distance_to(child.at) > 15.0 and h.at.distance_to(child.at) < 70.0)
						child.route = way(child.at,choices[rng.randi_range(0,choices.size()-1)].at)
				else:
					var ahead: Walker = children[i-1]
					child.speed = CHILD_RUN*(1.05 if ahead.at.distance_to(child.at) > 3.0 else .85)
					if ahead.at.distance_to(child.at) < 1.5: child.route = PackedVector3Array()
					elif child.repath <= 0.0:
						child.repath = .5
						child.route = way(child.at,ahead.at)
		if child.state == "run":
			if child.route.is_empty():
				child.state = "idle"
				child.body.play("Idle")
			else:
				child.pace = "Jog" if child.speed > 2.0 else "Walk"
				advance(child,delta)

# Where a child runs from the one who is "it": a corner well away from him.
func flee(child: Walker, it: Walker) -> Vector3:
	var best = haunts[0].at
	var most = -INF
	for k in 8:
		var haunt: Dictionary = haunts[rng.randi_range(0,haunts.size()-1)]
		var away = haunt.at.distance_to(it.at)-haunt.at.distance_to(child.at)*.6
		if haunt.at.distance_to(child.at) < 55.0 and away > most:
			most = away
			best = haunt.at
	return best

# ---- For the HUD ----

# The named townsperson at a point of the ground (only Anya has a name).
func named_at(point: Vector3) -> Dictionary:
	# (Not while she is in the kitchen, under the loft; nor Orion indoors.)
	if not kitchen.has_point(Vector2(anya.at.x,anya.at.z)) and Vector2(point.x-anya.at.x,point.z-anya.at.z).length() < 1.1: return {"name":"Anya","at":anya.at+Vector3.UP*1.9}
	if orion.body.visible and Vector2(point.x-orion.at.x,point.z-orion.at.z).length() < 1.2: return {"name":"Orion","at":orion.at+Vector3.UP*2.0}
	return {}
