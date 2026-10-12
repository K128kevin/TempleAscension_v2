extends Node3D
## The town's people (scripts/townsperson.gd draws each).
##
## Thirty grown townspeople wander the street that rings the arena, the
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
const Beer = preload("res://scripts/beer.gd")
const Daylight = preload("res://scripts/daylight.gd")
const ADULTS = 30
# (The five last of LOOKS are drawn by a die of their own, so the rest of the
# town comes out as it did before they came.)
const RAGGED_LATER = 25
const CHILDREN = 6
# How many of the grown townspeople are in the inn at once.
const INN_LEAST = 3
const INN_MOST = 8
# How long a drink lasts, and a sip between whiles. A mug of beer is drunk
# in SIPS sips, the last one emptying it; Anya fills it at the tap in POUR
# seconds.
const DRINK_TIME = 60.0
const SIPS = 5
const POUR = 1.1
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
# Those in rags this far gone are starving, too: thin to the bone
# (scripts/townsperson.gd starve).
const GAUNT_WEAR = .88
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
# The thirty: [body, garment, cloth, wear, hair, beard, belt, skin]. Fifteen
# are in rags (the last five came to the town since: RAGGED_LATER), nine in
# worn and patched clothes, six decently dressed.
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
	["woman","Gown",7,.18,"Hair_Buns",false,true,"light"],["man","Tunic",6,.24,"Hair_SimpleParted",false,true,"dark"],
	["man","Sack",2,.96,"Hair_SimpleParted",true,false,"dark"],["woman","Shift",8,.93,"Hair_Long",false,false,"light"],
	["man","Tunic",3,.91,"",true,true,"light"],["woman","Shift",2,.94,"Hair_Buns",false,false,"dark"],
	["man","Robe",8,.9,"Hair_Buzzed",false,true,"dark"]]

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
	# A loaf of Zeno's bread in its hand, for this long yet.
	var loaf_left = 0.0
	# Whether he is getting on (advance): where he was, the way he meant to
	# go and how far, and how long he has been kept back.
	var last_at = Vector3.ZERO
	var last_heading = Vector3.ZERO
	var last_step = 0.0
	var stuck = 0.0
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
# Selene, who works for Anya: she clears the mugs left on the tables and
# wipes them down (see chores).
var selene: Walker
# Orion, the blacksmith, and his work: the anvil he hammers at, the
# grindstone, and the forge he stokes.
var orion: Walker
var smith
# Anya's round: who she is taking a drink to, and where she stands.
var round: Array[Walker] = []
# (She holds a mug's handle under the tap with her upper arm forward,
# TAP_SWING, and carries it as Selene does: carried_at.)
# The drained mug she takes away from where she has just served.
var empty: Node3D
var post = Vector3.ZERO
var tap = Vector3.ZERO
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
	lay_floor()
	mark_haunts()
	furnish()
	lay_service()
	var c = Interiors.INN
	post = floor_nearest(Vector3(c.x+7.0,0,c.z+7.7))
	tap = floor_nearest(Vector3(c.x+9.2,0,c.z+7.7))
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
	var later = RandomNumberGenerator.new()
	later.seed = 4411
	for i in ADULTS:
		var die: RandomNumberGenerator = rng if i < RAGGED_LATER else later
		var look: Array = LOOKS[i]
		var wear: float = look[3]
		var walker = Walker.new()
		walker.body = figure({"who":look[0],"garment":look[1],"cloth":CLOTHS[look[2]],"wear":wear,"weave":"hessian" if wear>.8 else "linen",
			"hair":look[4],"beard":look[5],"hair_colour":HAIRS[die.randi_range(0,HAIRS.size()-1)],"belt":(Color(.42,.36,.26) if wear>.5 else Color(.3,.2,.12)) if look[6] else null,
			"skin":look[7],"tone":Color(1.0,.93,.86) if look[7]=="light" else Color.WHITE,"dirt":clampf(wear*1.1-.1,0.0,1.0),"size":die.randf_range(.93,1.02),"seed":die.randf(),
			"gaunt":1.0 if wear >= GAUNT_WEAR else 0.0})
		walker.body.name = "Townsperson%d" % i
		seat_hands(walker.body)
		walker.speed = WALK*die.randf_range(.88,1.12)
		people.append(walker)
		# Five begin at the inn's tables; the rest about the streets.
		if i%5 == 0 and i < RAGGED_LATER:
			walker.seat = free_seat()
			walker.seat.taken = walker
			sit(walker)
		else:
			walker.at = haunts[die.randi_range(0,haunts.size()-1)].at+Vector3(die.randf_range(-.4,.4),0,die.randf_range(-.4,.4))
			walker.body.rotation.y = die.randf_range(0,TAU)
			walker.timer = die.randf_range(0.0,6.0)
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
	hire_selene()
	hire_zeno()

func figure(look: Dictionary) -> Node3D:
	var person = Person.new()
	add_child(person)
	person.setup(look)
	return person

# ---- A woman's hands in her lap ----

# Sitting, the library's clip lays the hands on the bare body's thighs; a
# woman's skirt stands up over hers, and her hands were lost in her lap. So
# each woman who may sit at the inn is measured once (lap_lift: by the
# shape of what she wears) and her hands are kept on top of her lap while
# she sits (scripts/lap_hands.gd), LAP_CLEAR above it.
const LapHands = preload("res://scripts/lap_hands.gd")
const LAP_CLEAR = .012
const LAP_THIN = .025
# The bones whose flesh is the arm and hand themselves (not lap to lie on).
const ARM_BONES = ["clavicle","upperarm","lowerarm","hand","thumb","index","middle","ring","pinky"]
static var laps: Dictionary = {}

func seat_hands(body: Node3D) -> void:
	if body.look.who != "woman": return
	var key = "%s|%s|%.2f" % [body.look.garment,body.look.get("under",""),body.look.get("gaunt",0.0)]
	if not laps.has(key): laps[key] = lap_lift(body)
	var lap = LapHands.new()
	lap.name = "LapHands"
	lap.lift = laps[key].lift.duplicate()
	lap.rest = laps[key].rest.duplicate()
	body.skeleton.add_child(lap)
	body.skeleton.move_child(lap,body.arm.get_index())
	body.set_meta("lap",lap)

# How far each hand must rise, seated, to lie on her lap (in the skeleton's
# space), and where it rests then: from her body and clothes as the sitting
# clip poses them, the highest of their flesh or cloth over each part of
# her hand (not of the arm and hand themselves).
func lap_lift(body: Node3D) -> Dictionary:
	var skeleton: Skeleton3D = body.skeleton
	var animator: AnimationPlayer = body.animator
	animator.play("Sit",0.0)
	animator.seek(0.0,true)
	skeleton.force_update_all_bone_transforms()
	var samples = {"l":[],"r":[]}
	for side in samples:
		for bone in ["hand","index_02","middle_01","middle_02","middle_03","ring_02","pinky_02"]:
			var i = skeleton.find_bone("%s_%s" % [bone,side])
			if i >= 0: samples[side].append(skeleton.get_bone_global_pose(i).origin)
	# (How far each part of each hand must rise.)
	var needs = {"l":[],"r":[]}
	for side in samples:
		for at in samples[side]: needs[side].append(0.0)
	for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
		if mesh.skin == null or mesh.name in ["Eyes","Eyebrows","Braid","Belt"] or mesh.name.begins_with("Hair_"): continue
		var skin: Skin = mesh.skin
		var binds: Array[Transform3D] = []
		var bound: Array[bool] = []
		for b in skin.get_bind_count():
			var i = skin.get_bind_bone(b)
			if i < 0: i = skeleton.find_bone(skin.get_bind_name(b))
			binds.append(skeleton.get_bone_global_pose(i)*skin.get_bind_pose(b))
			var name: String = skeleton.get_bone_name(i)
			bound.append(ARM_BONES.any(func(part): return name.begins_with(part)))
		for surface in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if points.is_empty() or bones.is_empty(): continue
			var per: int = bones.size()/points.size()
			for v in range(0,points.size(),2):
				var placed = Vector3.ZERO
				var most = 0.0
				var arm = false
				for k in per:
					var w = weights[v*per+k]
					if w <= 0.0: continue
					placed += (binds[bones[v*per+k]]*points[v])*w
					if w > most:
						most = w
						arm = bound[bones[v*per+k]]
				if arm: continue
				for side in samples:
					for n in samples[side].size():
						var at: Vector3 = samples[side][n]
						if absf(placed.x-at.x) > .025 or absf(placed.z-at.z) > .025 or placed.y < at.y-.04 or placed.y > at.y+.1: continue
						needs[side][n] = maxf(needs[side][n],placed.y+LAP_CLEAR-at.y)
	# Enough for most of the hand to lie on top (one finger may lie in a
	# fold); less on a starving woman, whose clothes are drawn in with her
	# (scripts/townsperson.gd starve).
	var lift = {}
	for side in needs:
		var sorted: Array = needs[side].duplicate()
		sorted.sort()
		lift[side] = maxf(0.0,(sorted[int(sorted.size()*.7)] if not sorted.is_empty() else 0.0)-LAP_THIN*body.look.get("gaunt",0.0))
	var rest = {}
	for side in samples: rest[side] = samples[side][0] if not samples[side].is_empty() else Vector3.INF
	animator.play("Idle",0.0)
	body.state = "Idle"
	print_verbose("lap lift %s %s: %s" % [body.look.garment,body.look.get("under",""),lift])
	return {"lift":lift,"rest":rest}

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
	# (In the inn's common room, its own finer floor: lay_floor; its stair,
	# which the lodgers climb, is open ground for all it stands in the way of
	# any crossing the room.)
	if floor_area.has_point(Vector2(at.x,at.z)): return floor_open(at) or world.decks.any(func(deck): return deck.low != deck.high and deck.area.has_point(Vector2(at.x,at.z)))
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
# the ground between is open. Within the inn's common room, by its own floor
# (floor_way), in and out by its doorway.
func way(from: Vector3, to: Vector3) -> PackedVector3Array:
	var from_in: bool = floor_area.has_point(Vector2(from.x,from.z))
	var to_in: bool = floor_area.has_point(Vector2(to.x,to.z))
	if from_in and to_in: return floor_way(from,to)
	if to_in:
		var out: PackedVector3Array = street_way(from,door_in)
		out.append(door_in)
		out.append_array(floor_way(door_in,to))
		return out
	if from_in:
		var out: PackedVector3Array = floor_way(from,door_in)
		out.append_array(street_way(door_in,to))
		return out
	return street_way(from,to)

func street_way(from: Vector3, to: Vector3) -> PackedVector3Array:
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

# Each seat's open side; where the mug is set down on the table (at the
# table's edge before the drinker, toward that side); and where Anya stands
# to serve it and Selene to clear and wipe it: the free floor nearest the
# mug (stand_by), clear of the bench or stool and the table.
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
		seat.mug = Vector3(seat.at.x,.87,seat.at.z)+seat.face*.55+seat.side*.22
		seat.serve = stand_by(seat.mug)

# ---- The inn's floor ----

# The streets' grid is a metre to a cell: too coarse for the common room,
# where a bench stands a hand's breadth from its table. Its floor is laid out
# again, FLOOR_CELL to a cell, from where its furniture truly stands (every
# kit model standing on the floor there, by its bounds), each piece kept
# CLEARANCE clear of (a body's half-width and a little), and its walls too
# but for the doorway. Whoever walks there goes by it (floor_way), and every
# place Anya and Selene stand to serve, clear or wipe is on it (stand_by).
const FLOOR_CELL = .1
const CLEARANCE = .2
# The wash tub and the crate of empties behind the bar's west end, from the
# inn's corner (lay_tub).
const TUB = Vector3(1.55,0,7.35)
const TUB_RADIUS = .25
const EMPTIES = Vector3(1.4,0,8.07)
const EMPTIES_SIZE = Vector2(.51,.89)
var floor_grid = AStarGrid2D.new()
var floor_area = Rect2()
var floor_cells = Vector2i.ZERO
# Just inside the doorway, where the floor meets the streets' way in.
var door_in = Vector3.ZERO
# What stands on the floor, as rectangles of the ground; and of them the
# benches and stools, the seats.
var furniture: Array[Rect2] = []
var seat_boxes: Array[Rect2] = []

func lay_floor() -> void:
	var c = Interiors.INN
	floor_area = Rect2(c.x+1.0,c.z+6.6,Interiors.INN_BAYS.x*Interiors.BAY-2.0,c.z+Interiors.INN_BAYS.y*Interiors.BAY-1.0-(c.z+6.6))
	floor_cells = Vector2i(ceili(floor_area.size.x/FLOOR_CELL),ceili(floor_area.size.y/FLOOR_CELL))
	floor_grid.region = Rect2i(Vector2i.ZERO,floor_cells)
	floor_grid.cell_size = Vector2.ONE
	floor_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	floor_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	floor_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	floor_grid.update()
	var door: Vector3 = world.rooms[0].door
	door_in = Vector3(door.x,0,floor_area.end.y-.6)
	furniture.clear()
	seat_boxes.clear()
	for node in world.get_children():
		if not node is Node3D or not node.scene_file_path.begins_with("res://assets/models/props/"): continue
		var box = AABB()
		var first = true
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var part: AABB = mesh.global_transform*mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		if first: continue
		var centre: Vector3 = box.get_center()
		if not floor_area.has_point(Vector2(centre.x,centre.z)) or box.position.y > .5 or box.end.y < .15 or box.size.x > 6.0 or box.size.z > 6.0: continue
		var ground = Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
		furniture.append(ground)
		if node.scene_file_path.get_file().get_basename() in ["bench","stool"]: seat_boxes.append(ground)
	var tub = c+TUB
	var empties = c+EMPTIES
	furniture.append(Rect2(tub.x-TUB_RADIUS,tub.z-TUB_RADIUS,TUB_RADIUS*2.0,TUB_RADIUS*2.0))
	furniture.append(Rect2(empties.x-EMPTIES_SIZE.x*.5,empties.z-EMPTIES_SIZE.y*.5,EMPTIES_SIZE.x,EMPTIES_SIZE.y))
	# Each piece, and the walls (but the doorway), kept clear of.
	for box in furniture:
		var reach: Rect2 = box.grow(CLEARANCE)
		var low: Vector2i = floor_cell(Vector3(reach.position.x,0,reach.position.y))
		var high: Vector2i = floor_cell(Vector3(reach.end.x,0,reach.end.y))
		for z in range(maxi(low.y,0),mini(high.y+1,floor_cells.y)):
			for x in range(maxi(low.x,0),mini(high.x+1,floor_cells.x)):
				var at: Vector3 = floor_point(Vector2i(x,z))
				var off = Vector2(maxf(maxf(box.position.x-at.x,at.x-box.end.x),0.0),maxf(maxf(box.position.y-at.z,at.z-box.end.y),0.0))
				if off.length() < CLEARANCE: floor_grid.set_point_solid(Vector2i(x,z))
	for z in floor_cells.y:
		for x in floor_cells.x:
			var at: Vector3 = floor_point(Vector2i(x,z))
			var wall: float = minf(minf(at.x-floor_area.position.x,floor_area.end.x-at.x),at.z-floor_area.position.y)
			if floor_area.end.y-at.z < CLEARANCE and absf(at.x-door.x) > .9: wall = 0.0
			if wall < CLEARANCE: floor_grid.set_point_solid(Vector2i(x,z))

func floor_cell(at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x-floor_area.position.x)/FLOOR_CELL),floori((at.z-floor_area.position.y)/FLOOR_CELL))

func floor_point(cell: Vector2i) -> Vector3:
	return Vector3(floor_area.position.x+(cell.x+.5)*FLOOR_CELL,0,floor_area.position.y+(cell.y+.5)*FLOOR_CELL)

func floor_free(at: Vector3) -> bool:
	var cell: Vector2i = floor_cell(at)
	return floor_grid.region.has_point(cell) and not floor_grid.is_point_solid(cell)

# Whether one may stand at `at` in the common room at all: clear of its
# furniture by half CLEARANCE (the ways across it keep the whole of it).
func floor_open(at: Vector3) -> bool:
	for box in furniture:
		var off = Vector2(maxf(maxf(box.position.x-at.x,at.x-box.end.x),0.0),maxf(maxf(box.position.y-at.z,at.z-box.end.y),0.0))
		if off.length() < CLEARANCE*.5: return false
	return true

# The free place on the floor nearest `at` (itself, if it is free), as far
# as `reach` off; `at` itself if there is none.
func floor_nearest(at: Vector3, reach: float = 1.5) -> Vector3:
	if floor_free(at): return Vector3(at.x,0,at.z)
	var centre: Vector2i = floor_cell(at)
	var cells: int = ceili(reach/FLOOR_CELL)
	var best = Vector3(at.x,0,at.z)
	var least = INF
	for dz in range(-cells,cells+1):
		for dx in range(-cells,cells+1):
			var cell: Vector2i = centre+Vector2i(dx,dz)
			if not floor_grid.region.has_point(cell) or floor_grid.is_point_solid(cell): continue
			var point: Vector3 = floor_point(cell)
			var d: float = Vector2(point.x-at.x,point.z-at.z).length()
			if d < least:
				least = d
				best = point
	return best

# Whether the floor is free all along the straight way from `a` to `b`.
func floor_clear(a: Vector3, b: Vector3) -> bool:
	var steps: int = maxi(1,ceili(Vector2(b.x-a.x,b.z-a.z).length()/(FLOOR_CELL*.5)))
	for i in range(steps+1):
		if not floor_free(a.lerp(b,float(i)/steps)): return false
	return true

# The way across the common room from one place to another, round its
# furniture, its corners cut where the floor between is free. (From or to a
# place not on the free floor, by the free place nearest it.)
func floor_way(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out = PackedVector3Array()
	var a: Vector3 = floor_nearest(from)
	var b: Vector3 = floor_nearest(to)
	var cells: Array[Vector2i] = floor_grid.get_id_path(floor_cell(a),floor_cell(b))
	if cells.is_empty(): return out
	var points: Array[Vector3] = []
	for cell in cells: points.append(floor_point(cell))
	points[0] = a
	points[-1] = b
	if not floor_free(from) or from.distance_to(a) > .001: out.append(a)
	var here: Vector3 = a
	var i = 1
	while i < points.size():
		var ahead = i
		while ahead+1 < points.size() and floor_clear(here,points[ahead+1]): ahead += 1
		out.append(points[ahead])
		here = points[ahead]
		i = ahead+1
	return out

# Where one stands to reach something at `point` (on a table, on the bar):
# the free floor nearest it.
func stand_by(point: Vector3) -> Vector3:
	return floor_nearest(Vector3(point.x,0,point.z),2.0)

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
	chores(delta)
	zeno_tick(delta,hero)
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

# Walks a walker along its route; true once it has arrived. One kept back
# (another walking into him, pushing him back as he pushes on: part) for
# STUCK seconds goes round: a pace to his right (or left) first, then on.
const STUCK = .8
const DETOUR = .9
func advance(walker: Walker, delta: float) -> bool:
	if walker.route.is_empty():
		walker.last_step = 0.0
		return true
	var to: Vector3 = walker.route[0]-walker.at
	to.y = 0
	var step = walker.speed*delta
	# (How far he truly came since last time, toward where he was going.)
	var made: float = (walker.at-walker.last_at).dot(walker.last_heading)
	walker.stuck = walker.stuck+delta if walker.last_step > 0.0 and made < walker.last_step*.3 else maxf(0.0,walker.stuck-delta)
	if walker.stuck > STUCK and to.length() > DETOUR:
		walker.stuck = 0.0
		var right: Vector3 = to.normalized().cross(Vector3.UP)
		for side in [right,-right]:
			var round_by: Vector3 = walker.at+side*DETOUR+to.normalized()*DETOUR*.5
			if open_at(round_by) and clear_way(walker.at,round_by):
				walker.route.insert(0,Vector3(round_by.x,0,round_by.z))
				to = walker.route[0]-walker.at
				to.y = 0
				break
	walker.last_at = walker.at
	walker.last_heading = to.normalized() if to.length() > .001 else Vector3.ZERO
	walker.last_step = minf(step,to.length())
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
	# (Zeno's bread: thrown for with a die of his own, so the town's other
	# comings and goings fall as they did.)
	if walker.basket == null and bread_open(walker) and bread_rng.randf() < BREAD_CHANCE and buy_bread(walker): return
	if walker.basket == null and rng.randf() < SHOP_CHANCE and go_shopping(walker): return
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
	# (Seated, a woman's hands lie on her lap: seat_hands.)
	var lap = walker.body.get_meta("lap") if walker.body.has_meta("lap") else null
	if lap != null: lap.weight = move_toward(lap.weight,1.0 if walker.state in ["sit_down","wait","drink","stand_up"] else 0.0,delta*3.0)
	if walker.state in ABED:
		retire(walker,delta)
		return
	# Bedtime: off home from the street (or from the way to the inn); one
	# waiting at a table gets up and goes, unless Anya is bringing his drink.
	if abed(walker):
		if walker.state in ["walk","pause","halt","leaving","to_inn","to_buy","buying","laden","from_home","to_bread","bread"]:
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
	# A loaf bought of Zeno, eaten in a while.
	if walker.loaf_left > 0.0:
		walker.loaf_left -= delta
		if walker.loaf_left <= 0.0 and walker.basket != null and walker.basket.name == "Loaf":
			walker.body.hold(null)
			walker.basket.queue_free()
			walker.basket = null
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
			# The mug drained, he sets it by (for Anya or Selene to clear) and
			# has done with it.
			if walker.phase == "" and Beer.left_in(walker.mug) <= .001:
				walker.drinks += 1
				if walker.mug != null:
					set_down(walker.mug,walker.seat,true)
					walker.seat.left = walker.mug
					walker.mug = null
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
				# (Where he sat wants wiping: Selene.)
				var place: int = seats.find(seat)
				if wiped.has(place): wiped[place] = chore_clock-WIPE_REST
				walker.seat = {}
				walker.drinks = 0
				var outside = haunts.filter(func(h): return h.kind == "ring")
				walker.route = way(walker.at,outside[rng.randi_range(0,outside.size()-1)].at)
				walker.state = "leaving"
		"leaving":
			if advance(walker,delta): rest(walker,2.0,6.0)
			elif not inside(walker): walker.state = "walk"
		"to_buy","buying","laden","home","from_home": shop(walker,delta)
		"to_bread","bread": buy(walker,delta)

# A sip, made deliberately: the hand on the mug's side of him goes to it on
# the table and the fingers close round its handle; the arm lifts it,
# upright, until the near edge of its rim meets his lips (found again every
# moment, so it touches and never presses into his face); it is tipped back
# (TIP, the whole arm turning, the wrist kept straight: scripts/arm_reach.gd
# upright) while he drinks, and righted; it is set down again as it stood,
# and the hand lets go and goes back.
const SIP = {"reach":.7,"lift":.9,"sip":1.3,"lower":.8,"return":.6}
# How far the mug leans back as it comes to his lips, and at the sip.
const LEAN = .26
const TIP = .8
# How quickly the handle's place is found again as the mug turns in his fist
# (a share of the way, each moment); how far before his lips the rim comes
# up and goes down.
const TO_LIPS = .35
const APPROACH = .07
# (At the sip the rim rests on his lips, never pressed into them.)
const TOUCH = .006

func sip(walker: Walker, delta: float) -> void:
	var seat: Dictionary = walker.seat
	var body = walker.body
	var mug: Node3D = walker.mug
	walker.phase_time += delta
	var t = clampf(walker.phase_time/SIP[walker.phase],0.0,1.0)
	var eased = smoothstep(0.0,1.0,t)
	# The hand on the mug's side; the handle where the mug stands.
	if walker.phase == "reach" and walker.phase_time <= delta:
		body.set_meta("drink_side",drinking_side(body,mug.global_position))
		body.remove_meta("to_lips")
		body.set_meta("on_table",mug.global_transform*body.MUG_HANDLE)
	var side: String = body.get_meta("drink_side","l")
	var on_table: Vector3 = body.get_meta("on_table")
	var frame: Basis = body.global_transform.basis.orthonormalized()
	var forward: Vector3 = frame.z
	var out: Vector3 = frame.x*(1.0 if body.skeleton.get_bone_global_rest(body.skeleton.find_bone("hand_"+side)).origin.x > 0.0 else -1.0)
	var lips: Vector3 = body.lips()
	# Where the near edge of its rim is to be: at his lips for the sip, and
	# APPROACH before them as it comes up and goes down, so it comes to his
	# mouth from in front and never across his face.
	var approach: float = {"reach":APPROACH,"lift":lerpf(APPROACH,TOUCH,smoothstep(.6,1.0,t)),"sip":TOUCH,"lower":lerpf(TOUCH,APPROACH,smoothstep(0.0,.4,t)),"return":APPROACH}[walker.phase]
	var goal: Vector3 = lips+forward*approach
	# Where the handle must be for that: worked out from how the mug sits in
	# his fist now (its rim's edge nearest the goal, from the handle), eased.
	var at_mouth: Vector3 = body.get_meta("to_lips",lips+forward*.085+out*.075+Vector3.DOWN*.07)
	if mug.get_parent() != self and walker.phase in ["lift","sip","lower"]:
		var held: Transform3D = mug.global_transform
		var up: Vector3 = held.basis.y.normalized()
		var rim: Vector3 = held*body.MUG_RIM
		var toward: Vector3 = goal-rim
		toward -= up*toward.dot(up)
		var near: Vector3 = rim+toward.normalized()*body.MUG_RIM_RADIUS
		at_mouth = at_mouth.lerp(goal-(near-held*body.MUG_HANDLE),TO_LIPS)
		body.set_meta("to_lips",at_mouth)
	var lean = func(angle: float) -> Vector3: return (Vector3.UP*cos(angle)-forward*sin(angle)).normalized()
	match walker.phase:
		"reach": body.drink_reach(side,on_table,Vector3.UP,eased,smoothstep(.55,1.0,t))
		"lift":
			body.settle_grasp(smoothstep(0.0,.6,t))
			body.drink_reach(side,on_table.lerp(at_mouth,eased),lean.call(LEAN*eased),1.0,1.0)
		"sip":
			body.drink_reach(side,at_mouth,lean.call(lerpf(LEAN,TIP,smoothstep(0.0,.35,t)*(1.0-smoothstep(.65,1.0,t)))),1.0,1.0)
			# A mouthful's worth goes down while it is tipped to him.
			var beer = Beer.of(mug)
			var was: float = body.get_meta("beer_was",beer.fill)
			if walker.phase_time <= delta:
				was = beer.fill
				body.set_meta("beer_was",was)
			beer.fill = maxf(0.0,was-smoothstep(.3,.7,t)/SIPS)
		"lower":
			body.settle_grasp(1.0-smoothstep(.4,1.0,t))
			body.drink_reach(side,at_mouth.lerp(on_table,eased),lean.call(LEAN*(1.0-eased)),1.0,1.0)
		"return": body.drink_reach(side,on_table,Vector3.UP,1.0-smoothstep(.25,1.0,t),1.0-smoothstep(0.0,.4,t))
	if t < 1.0: return
	walker.phase_time = 0.0
	match walker.phase:
		"reach":
			body.grasp(mug,side,0.0)
			walker.phase = "lift"
		"lift": walker.phase = "sip"
		"sip": walker.phase = "lower"
		"lower":
			set_down(mug,seat)
			body.held = null
			walker.phase = "return"
		"return":
			body.let_go()
			walker.phase = ""

# Which hand ("l" or "r") is nearer the mug at `at`.
func drinking_side(body, at: Vector3) -> String:
	var hand_at = func(side: String) -> Vector3: return body.skeleton.global_transform*body.skeleton.get_bone_global_pose(body.skeleton.find_bone("hand_"+side)).origin
	return "l" if hand_at.call("l").distance_to(at) <= hand_at.call("r").distance_to(at) else "r"

# A mug stood on the table before a seat, its handle turned out toward the
# drinker's hand on that side (the mug's +X), a little back toward him.
# Set `aside` (an empty, or one left), it stands further in on the table and
# toward the other hand, out of the way of the next he is brought.
const ASIDE = Vector2(.15,.14)
func set_down(mug: Node3D, seat: Dictionary, aside: bool = false) -> void:
	if mug.get_parent() != null: mug.get_parent().remove_child(mug)
	add_child(mug)
	mug.transform = mug_pose(seat,aside)

# (Turned, then sized in its own frame, so it is never stretched.)
func mug_pose(seat: Dictionary, aside: bool = false) -> Transform3D:
	var handle: Vector3 = (seat.get("side",-seat.face)*.85-seat.face*.5).normalized()
	var at: Vector3 = seat.mug+(seat.face*ASIDE.x-seat.get("side",Vector3.ZERO)*ASIDE.y if aside else Vector3.ZERO)
	return Transform3D(Basis(Vector3.UP,atan2(-handle.z,handle.x))*Basis.from_scale(Kit.sized("mug",.17)),at+Vector3.UP*world.lift(seat.at))

func leave(walker: Walker) -> void:
	# The mug is left on the table for Anya to clear.
	var seat: Dictionary = walker.seat
	walker.body.reach(Vector3.ZERO,0.0,0.0)
	walker.phase = ""
	if walker.mug != null:
		set_down(walker.mug,seat,true)
		seat.left = walker.mug
		walker.mug = null
	walker.state = "stand_up"
	walker.timer = walker.body.length("StandUp")
	walker.from = walker.at
	walker.body.play("StandUp",.2)

# Anya: at her post behind the bar until someone is waiting; then to the
# barrels, where she fills a mug, carries it upright by its handle, her fist
# round it (take_up, in_fist: scripts/townsperson.gd's handle grip, as a
# drinker holds his), round the end of the bar to his seat (by the floor),
# sets it on the table before him, and goes back for the next.
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
				anya.route = way(anya.at,tap)
				anya.route.append(tap)
				anya.state = "to_tap"
		"to_tap":
			if advance(anya,delta):
				anya.state = "fill"
				anya.phase_time = 0.0
				body.play("Idle",.2)
		"fill":
			# Facing the barrels on their rack against the kitchen wall, she
			# holds the mug under the tap a moment, her fist round its handle.
			body.turn_to(Vector3(0,0,-1),delta,8.0)
			var t = anya.phase_time
			var under: Vector3 = body.global_transform*fist_ahead(body,"l",TAP_SWING)
			if t < .6: body.drink_reach("l",under,Vector3.UP,smoothstep(0.0,1.0,t/.6),smoothstep(0.0,1.0,t/.6))
			else:
				if body.held != anya.mug:
					take_up(body,anya.mug,"l")
					in_fist(anya.mug,Transform3D(),0.0)
					Beer.of(anya.mug).fill = 0.0
				body.drink_reach("l",under,Vector3.UP,1.0,1.0)
			# The beer runs in from the tap, a head of foam on it.
			if t >= .8: Beer.of(anya.mug).fill = smoothstep(0.0,1.0,(t-.8)/POUR)
			if t >= 2.0:
				next_table(true)
		"carry":
			body.drink_reach("l",body.global_transform*carried_at(body,"l"),Vector3.UP,1.0,1.0)
			if advance(anya,delta):
				anya.state = "place"
				anya.phase_time = 0.0
				body.play("Idle",.2)
		"place":
			# Down onto the table before him, turned as it is to stand (its
			# handle to his hand) as it comes down; her fingers open, and she
			# takes up the empty he has done with, if there is one.
			var patron: Walker = round[0]
			var seat: Dictionary = patron.seat
			body.turn_to(seat.mug-anya.at,delta,8.0)
			var carried: Vector3 = body.global_transform*carried_at(body,"l")
			var pose: Transform3D = mug_pose(seat)
			var on_table: Vector3 = pose*Person.MUG_HANDLE
			var t = anya.phase_time
			if t < .7:
				var down: float = smoothstep(0.0,1.0,t/.7)
				body.drink_reach("l",carried.lerp(on_table,down)+Vector3.UP*.05*sin(down*PI),Vector3.UP,1.0,1.0)
				if body.held == anya.mug: in_fist(anya.mug,pose,smoothstep(.45,1.0,down))
			elif t < .9:
				if body.held == anya.mug:
					in_fist(anya.mug,pose,1.0)
					body.held = null
					var mug: Node3D = anya.mug
					anya.mug = Kit.prop("mug",.17)
					stow(anya.mug)
					if patron.state == "wait":
						if patron.mug != null: patron.mug.queue_free()
						patron.mug = mug
						set_down(mug,seat)
						patron.state = "drink"
						patron.timer = DRINK_TIME
						patron.sip = rng.randf_range(2.0,5.0)
					else:
						# (He has gone: it is left standing, for Selene.)
						set_down(mug,seat)
						mug.set_meta("kind","mug")
						litter.append({"node":mug,"kind":"mug"})
					# His last, drained, she takes away with her.
					if seat.left != null and is_instance_valid(seat.left):
						empty = seat.left
						seat.left = null
				body.drink_reach("l",on_table+Vector3.UP*.03*smoothstep(.7,.9,t),Vector3.UP,1.0,1.0-smoothstep(.7,.9,t))
			elif empty != null and is_instance_valid(empty) and t < 1.7:
				var rest: Transform3D = empty.get_meta("rest") if body.held == empty else empty.global_transform
				var handle: Vector3 = rest*Person.MUG_HANDLE
				if t < 1.25:
					var to: float = smoothstep(0.0,1.0,(t-.9)/.35)
					body.drink_reach("l",on_table.lerp(handle,to)+Vector3.UP*.04*sin(to*PI),Vector3.UP,1.0,smoothstep(.6,1.0,to))
				else:
					if body.held != empty: take_up(body,empty,"l")
					var up: float = smoothstep(0.0,1.0,(t-1.25)/.45)
					in_fist(empty,rest,1.0-up)
					body.drink_reach("l",handle.lerp(carried,up),Vector3.UP,1.0,1.0)
			elif empty == null and t < 1.4: body.drink_reach("l",on_table+Vector3.UP*.03,Vector3.UP,1.0-smoothstep(.9,1.4,t),0.0)
			else:
				if body.held == null: body.let_go()
				elif body.held == empty: in_fist(empty,Transform3D(),0.0)
				round.remove_at(0)
				next_table(false)
		"return":
			# (Carrying back an empty, if she took one up; it goes to be washed.)
			if body.held != null: body.drink_reach("l",body.global_transform*carried_at(body,"l"),Vector3.UP,1.0,1.0)
			else: body.reach(Vector3.ZERO,0.0,0.0)
			if advance(anya,delta):
				if body.held != null:
					var washed: Node3D = body.held
					body.held = null
					washed.queue_free()
					body.reach(Vector3.ZERO,0.0,0.0)
				empty = null
				anya.state = "post"
				anya.timer = rng.randf_range(1.0,3.0)
				body.play("Idle")


func next_table(from_bar: bool) -> void:
	while not round.is_empty() and round[0].state != "wait": round.remove_at(0)
	var route = PackedVector3Array()
	# (An empty taken up is carried back behind the bar, to be washed; with
	# another to serve, it is put by at once.)
	if anya.body.held != null and anya.body.held == empty and not round.is_empty():
		anya.body.held = null
		empty.queue_free()
		empty = null
	if round.is_empty():
		# Back behind the bar.
		if anya.body.held != null and anya.body.held == anya.mug:
			anya.body.held = null
			stow(anya.mug)
		# (Round the bar's end by the floor: way.)
		route.append_array(way(anya.at,post))
		route.append(post)
		anya.state = "return"
	else:
		var patron: Walker = round[0]
		route.append_array(way(anya.at,patron.seat.serve))
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
	var later = RandomNumberGenerator.new()
	later.seed = 4412
	for i in ADULTS:
		var walker: Walker = people[i]
		var die: RandomNumberGenerator = sleep if i < RAGGED_LATER else later
		walker.bedtime = die.randf_range(BEDTIME.x,BEDTIME.y)
		walker.rising = die.randf_range(RISING.x,RISING.y)
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
	# no one sleeps at has nothing laid out there.) (The five come since are
	# seen to last.)
	var in_turn: Array = people.slice(0,RAGGED_LATER)+children+people.slice(RAGGED_LATER)
	for walker in in_turn:
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
	for walker in in_turn:
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
	# Selene goes to the inn, to her work; Zeno to his cart.
	elif walker == selene: to_work()
	elif walker == zeno: zeno_up()
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
	if walker == bread_customer: bread_customer = null
	walker.loaf_left = 0.0
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
		if is_instance_valid(empty): empty.queue_free()
		empty = null
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
	for walker in people+children+[anya,orion,selene]+keepers:
		if abed(walker) and not walker.state in ["asleep","indoors"]: tuck(walker)
		elif not abed(walker) and walker.state in ABED: rouse(walker)
	zeno_at_once()
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
				# (One still on his way to buy when it is time to shut finds it
				# shutting, and goes about his day.)
				if abed(keeper) and customer != null and customer.state == "to_buy":
					release(customer)
					rest(customer,1.0,3.0)
					customer = null
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
			# Walking into each other, each steps aside to his right as well,
			# so they slip past rather than shoving face to face.
			var aside = Vector3.ZERO
			if a.last_heading.dot(b.last_heading) < -.3: aside = a.last_heading.cross(Vector3.UP)*(gap-apart.length())*.5
			nudge(a,push+aside)
			nudge(b,-push-aside)

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

# The named townsperson at a point of the ground (Anya, Orion, Selene and Zeno).
func named_at(point: Vector3) -> Dictionary:
	# (Not while she is in the kitchen, under the loft; nor Orion indoors.)
	if not kitchen.has_point(Vector2(anya.at.x,anya.at.z)) and Vector2(point.x-anya.at.x,point.z-anya.at.z).length() < 1.1: return {"name":"Anya","at":anya.at+Vector3.UP*1.9}
	if orion.body.visible and Vector2(point.x-orion.at.x,point.z-orion.at.z).length() < 1.2: return {"name":"Orion","at":orion.at+Vector3.UP*2.0}
	if selene.body.visible and Vector2(point.x-selene.at.x,point.z-selene.at.z).length() < 1.1: return {"name":"Selene","at":selene.at+Vector3.UP*1.9}
	if zeno.body.visible and Vector2(point.x-zeno.at.x,point.z-zeno.at.z).length() < 1.1: return {"name":"Zeno","at":zeno.at+Vector3.UP*2.05}
	return {}

# ---- Selene ----

# Selene, who works for Anya: from the morning until the inn is shut she
# keeps its common room. Whatever is left about that no one is using (litter:
# last night's mugs, plates and bottles on the tables and the bar; a mug a
# drinker has drained and set by) she goes and clears, standing where she can
# reach it (stand_by, leaning to it): a mug in her fist by its handle, a
# bottle by its neck, one in each hand, or plates stacked on her left palm;
# mugs and plates go into the wash tub behind the bar's west end, bottles into
# the crate of empties beside it. A place at a table that no one sits at and
# nothing stands at, not wiped since its last drinker got up (or for
# WIPE_REST), she wipes down with her rag, round and round under her palm
# where a mug would stand (WIPE_TIME), going on to the table's other free
# places; the rag hangs from her apron's string between whiles. With nothing
# left about and every free place clean she wipes the bar down from behind
# it, and between whiles stands by the bar's west end, looking over the room.
# She lives in the house nearest the inn, comes to work a while after Anya is
# up (SELENE_RISING), and goes home once the inn is shut.
const SELENE_WALK = 1.45
const SELENE_RISING = ANYA_RISING+25.0
const WIPE_REST = 90.0
const WIPE_TIME = 4.0
# Her rag's round on the table (metres across, and seconds a turn), her palm
# on it this far above the top (the rag bunched under it); and how far she
# leans to it.
const WIPE_ROUND = .09
const WIPE_BEAT = 1.1
const WIPE_ABOVE = .012
const WIPE_LEAN = .12
const CHORE_LOOK = .5
# A thing within USE_REACH of where a drinker's mug stands is his. Of what
# is left about she takes, in one going, what lies within TAKE_REACH of the
# first thing (as much as her hands hold: PLATES on her palm); each taken up
# in TAKE seconds and put away in PUT. She leans to what is further than
# ARM_REACH from her, as far as LEAN_MOST.
const USE_REACH = .55
const TAKE_REACH = .7
const PLATES = 4
const TAKE = 1.1
const PUT = 1.0
const ARM_REACH = .3
const LEAN_MOST = .35
# How far forward the upper arm hangs as a thing is carried by its handle
# in the fist (fist_ahead: hers, and Anya's), and as Anya holds a mug under
# the tap; where her palm carries plates, in her own frame, and how far up
# each plate lies on the one below.
const CARRY_SWING = .25
const TAP_SWING = .75
const TRAY_CARRY = Vector3(.1,.95,.36)
const PLATE_STEP = .014
# (The lowest plate on her palm's pads and fingers, not in them.)
const ON_PALM = .022
# Her hand turned palm up, fingers forward (in her frame: the hand bone's X
# is out of the palm, its Y along the fingers, its Z toward the thumb).
const PALM_UP = Basis(Vector3(0,1,0),Vector3(0,0,1),Vector3(1,0,0))
# Her clothes, and her apron of linen over her skirt (scripts/townsperson.gd).
const SELENE_LOOK = {"who":"woman","garment":"Gown","under":"Blouse","cloth":Color(.30,.34,.30),"under_cloth":Color(.86,.83,.76),"wear":.12,
	"hair":"Hair_Buns","hair_colour":Color(.24,.15,.08),"skin":"light","tone":Color(.98,.9,.82),"belt":Color(.35,.24,.15),"size":.95,"seed":.43,
	"apron":Color(.8,.76,.66)}
var selene_spot = Vector3.ZERO
var rag: Node3D
# The rag as it hangs from her apron's string, between whiles.
var rag_hung: Node3D
# Where her palm is, wiping (the rag under it), and plates lie on it; and
# her left hand laid flat for either (scripts/flat_hand.gd).
var palm: Node3D
var tray: Node3D
var flat_hand: SkeletonModifier3D
var chore_rng = RandomNumberGenerator.new()
var chore_clock = 0.0
# What she is about: "clear" (the things she is taking up, where she stands
# for them and where they go: "picks", "stand", "to"; what is in each hand:
# "in"), "wipe" (the place she is at) or "bar"; the places she has still to
# wipe; when each place was last wiped (by its seat's index); and what is
# left about: [{node, kind}] (with "seat", a drained mug set by there).
var chore = {}
var wiping: Array = []
var wiped: Dictionary = {}
var litter: Array = []
# How far she leans, to wipe or to reach.
var lean_to = 0.0

func hire_selene() -> void:
	chore_rng.seed = 5150
	var c = Interiors.INN
	selene_spot = floor_nearest(c+Vector3(2.4,0,10.6))
	selene = Walker.new()
	selene.body = figure(SELENE_LOOK)
	selene.body.name = "Selene"
	selene.speed = SELENE_WALK
	selene.at = selene_spot
	selene.body.rotation.y = atan2(1.0,.4)
	idle(selene)
	rag = make_rag()
	stow(rag)
	rag_hung = hang_rag(selene.body)
	palm = Node3D.new()
	palm.name = "Palm"
	tray = Node3D.new()
	tray.name = "Tray"
	for holder in [palm,tray]: add_child(holder)
	var hand: Dictionary = palm_place(selene.body)
	# (Its up out of the back of her hand, or out of her palm.)
	selene.body.pin_to_hand(palm,"hand_l",Basis(Vector3(0,1,0),Vector3(-1,0,0),Vector3(0,0,1)),hand.at)
	selene.body.pin_to_hand(tray,"hand_l",Basis(Vector3(0,0,1),Vector3(1,0,0),Vector3(0,1,0)),hand.at)
	flat_hand = preload("res://scripts/flat_hand.gd").new()
	flat_hand.name = "FlatHand"
	selene.body.skeleton.add_child(flat_hand)
	lay_tub()
	for thing in world.rooms[0].get("litter",[]):
		thing.node.set_meta("kind",thing.kind)
		litter.append({"node":thing.node,"kind":thing.kind})
	# Her house: the free one nearest the inn.
	var taken: Array = (people+children+[orion]+keepers).filter(func(w): return w.bed.get("kind") == "house").map(func(w): return w.bed.at)
	var homes: Array = world.places.filter(func(p): return p.kind == "house" and p.name == "house")
	var free = homes.filter(func(h): return taken.all(func(t): return house_bed(h).at.distance_to(t) > .5))
	if free.is_empty(): free = homes
	var door: Vector3 = world.rooms[0].door
	free.sort_custom(func(a, b): return a.at.distance_to(door) < b.at.distance_to(door))
	selene.bed = house_bed(free[0])
	selene.bedtime = ANYA_BEDTIME
	selene.rising = SELENE_RISING
	for i in seats.size(): wiped[i] = -WIPE_REST

# Her rag: a square of old linen, grey with washing and wiping, damp, worn
# thin and frayed at its edges: bunched under her palm as she wipes (the
# middle gathered up into her hand, the rest lying on the table in creases
# that run in to it, a corner turned under), and hanging from her apron's
# string between whiles (hang_rag). Its cloth is the townspeople's
# (assets/shaders/cloth.gdshader), worn to holes.
const RAG_SIZE = Vector2(.34,.3)
const RAG_DYE = Color(.5,.47,.41)
const RAG_WEAR = .8
static var rag_material: ShaderMaterial
static func rag_cloth() -> ShaderMaterial:
	if rag_material != null: return rag_material
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/cloth.gdshader")
	m.set_shader_parameter("weave",load("res://assets/textures/cloth_linen.jpg"))
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("weave_scale",7.0)
	m.set_shader_parameter("weave_layer",12.0)
	m.set_shader_parameter("dye",Vector3(RAG_DYE.r,RAG_DYE.g,RAG_DYE.b))
	m.set_shader_parameter("wear",RAG_WEAR)
	m.set_shader_parameter("seed",3.7)
	m.set_shader_parameter("drape",.004)
	rag_material = m
	return m

# A sheet of cloth `size` across, made of `cells` squares a side, each point
# placed by `shape` (from its place on the sheet, -0.5…0.5 each way, to where
# it lies); its UVs in metres over the cloth, and its second UVs how near its
# edge a point is (1 at the edge, for the cloth's fraying) and how worn.
static func sheet(size: Vector2, cells: Vector2i, shape: Callable) -> ArrayMesh:
	var points: Array[Vector3] = []
	for j in cells.y+1:
		for i in cells.x+1: points.append(shape.call(Vector2(float(i)/cells.x-.5,float(j)/cells.y-.5)))
	var mesh = ArrayMesh.new()
	# Both its faces, each lit as the outside (this renderer lights a
	# two-sided surface's back from the wrong side).
	for back in [false,true]:
		var tool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in cells.y+1:
			for i in cells.x+1:
				var u = Vector2(float(i)/cells.x,float(j)/cells.y)
				var edge: float = 1.0-minf(minf(u.x,1.0-u.x)*size.x,minf(u.y,1.0-u.y)*size.y)/.035
				tool.set_uv(u*size)
				tool.set_uv2(Vector2(clampf(edge,0.0,1.0),.45))
				tool.add_vertex(points[j*(cells.x+1)+i])
		for j in cells.y:
			for i in cells.x:
				var a: int = j*(cells.x+1)+i
				var quad = [a,a+1,a+cells.x+2,a,a+cells.x+2,a+cells.x+1]
				if back: quad.reverse()
				for k in quad: tool.add_index(k)
		tool.generate_normals()
		tool.commit(mesh)
	return mesh

func make_rag() -> Node3D:
	var holder = Node3D.new()
	holder.name = "Rag"
	var cloth = MeshInstance3D.new()
	cloth.name = "Cloth"
	var crumple = FastNoiseLite.new()
	crumple.seed = 77
	crumple.frequency = 2.4
	var fine = FastNoiseLite.new()
	fine.seed = 31
	fine.frequency = 6.0
	cloth.mesh = sheet(RAG_SIZE,Vector2i(30,26),func(p: Vector2) -> Vector3:
		# A corner turned back over the rest, lying on top of it.
		var over: float = (p.x+p.y-.5)/sqrt(2.0)
		var flap: float = 0.0
		if over > 0.0:
			p -= Vector2(1,1).normalized()*over*2.0
			flap = 1.0
		# Gathered in toward her palm (a little off its middle), the more the
		# nearer: the cloth bunched up into her hand.
		var from: Vector2 = p-Vector2(-.06,.02)
		var r: float = from.length()
		var gather: float = .6*exp(-r*r*7.0)
		var spot: Vector2 = p*RAG_SIZE*(1.0-gather)
		# Its creases: ridges every way, crowded and high in the bunch, low
		# and loose out at its edges, which lift and curl a little.
		var ridge: float = pow(1.0-absf(crumple.get_noise_2d(p.x*3.0,p.y*3.0)),3.0)
		var small: float = pow(1.0-absf(fine.get_noise_2d(p.x*3.0,p.y*3.0)),2.0)
		var high: float = .016*exp(-r*r*22.0)+ridge*.011*(.35+.65*smoothstep(.55,.05,r))+small*.0035
		high += smoothstep(.38,.5,maxf(absf(p.x),absf(p.y)))*.006*(.5+crumple.get_noise_2d(p.y*5.0,p.x*5.0))
		spot += Vector2(fine.get_noise_2d(p.x*2.0+4.0,p.y*2.0),fine.get_noise_2d(p.x*2.0,p.y*2.0-3.0))*.012
		# (The turned corner on top, its fold rounded.)
		high += flap*(.007+.004*smoothstep(0.0,.03,over))
		return Vector3(spot.x,-.013+high,spot.y))
	cloth.material_override = rag_cloth()
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cloth)
	return holder

# Her rag hung over her apron's string at her left hip, folded over it, its
# two ends hanging down, swaying with her (on her pelvis).
func hang_rag(body: Node3D) -> Node3D:
	var skeleton: Skeleton3D = body.skeleton
	var pelvis: int = skeleton.find_bone("pelvis")
	var hang = BoneAttachment3D.new()
	hang.bone_name = "pelvis"
	skeleton.add_child(hang)
	var cloth = MeshInstance3D.new()
	cloth.name = "HungRag"
	var size = Vector2(.19,.46)
	cloth.mesh = sheet(size,Vector2i(8,18),func(p: Vector2) -> Vector3:
		# Down from the string and back up the other side: folded over at the
		# top, the two ends apart a little, in folds down its length.
		var down: float = (p.y+.5)*size.y
		var over: bool = down > size.y*.42
		var drop: float = down if not over else size.y*.84-down
		var out: float = .006 if not over else .02
		var fold: float = sin(p.x*17.0+drop*9.0+1.0)*.014*(.35+drop*2.5)+sin(p.x*37.0-drop*6.0)*.004
		var gather: float = 1.0-.45*exp(-drop*drop*300.0)
		return Vector3(p.x*size.x*gather*(1.0+drop*.5),-drop,out+fold+drop*.05))
	cloth.material_override = rag_cloth()
	hang.add_child(cloth)
	# (In the pelvis bone's own space, made where it hangs at rest: at her
	# left hip, before her, at her waist.)
	var waist: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("spine_01")).origin
	var toes: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("ball_l")).origin-skeleton.get_bone_global_rest(skeleton.find_bone("foot_l")).origin
	toes.y = 0.0
	var front: Vector3 = toes.normalized() if toes.length() > .01 else Vector3.BACK
	var left: Vector3 = Vector3.UP.cross(front)
	var hips: Vector3 = skeleton.get_bone_global_rest(pelvis).origin
	var at_rest = Transform3D(Basis(left,Vector3.UP,front).rotated(Vector3.UP,1.0),Vector3(hips.x,waist.y-.02,hips.z)+left*.18+front*.04)
	cloth.transform = skeleton.get_bone_global_rest(pelvis).affine_inverse()*at_rest
	return cloth

# Where her palm lies on what it holds flat (a rag under it, plates on it),
# in her left hand bone's space: its middle, just off its face.
func palm_place(body: Node3D) -> Dictionary:
	var reaching = body.drinking_arm("l")
	var face: Vector3 = reaching.along.cross(reaching.across)
	if face.dot(reaching.palm-reaching.along*reaching.palm.dot(reaching.along)) < 0.0: face = -face
	return {"at":reaching.along*reaching.palm.dot(reaching.along)*.8+face*.026,"face":face}

# Her hand turned palm down, fingers forward, as she wipes (in the world).
func palm_down(body: Node3D) -> Basis:
	return body.global_transform.basis*Basis(Vector3(0,-1,0),Vector3(0,0,1),Vector3(-1,0,0))

# Her left hand laid flat (palm down, or up: `turn`) with the middle of her
# palm at `point`, as far as `weight` says.
func lay_palm(body: Node3D, point: Vector3, turn: Basis, weight: float) -> void:
	var at: Vector3 = palm_place(body).at
	body.reach(point-turn*at,weight,0.0)
	body.arm.grip = turn

func idle(walker: Walker) -> void:
	walker.state = "idle"
	walker.timer = CHORE_LOOK
	walker.body.play("Idle",.3)

# In the morning, from her door to her place in the inn.
func to_work() -> void:
	selene.route = way(selene.at,selene_spot)
	selene.route.append(selene_spot)
	selene.state = "to_post"

func back_to_post() -> void:
	selene.body.let_go()
	selene.route = way(selene.at,selene_spot)
	selene.route.append(selene_spot)
	selene.state = "to_post"

# Whether anyone sits at a place (or is on his way to, or Anya is bringing
# him a drink).
func place_in_use(seat: Dictionary) -> bool:
	if seat.taken != null: return true
	return round.any(func(patron): return patron.seat == seat)

# ---- Things in hand ----

# Where the fist (the middle of it, where a handle is held) comes with the
# upper arm hanging `swing` (radians) forward of straight down and the
# forearm level, straight ahead: so a mug carried by its handle stands
# upright in it (scripts/arm_reach.gd upright: the forearm square to the
# handle). In the figure's own frame, from its arm's own lengths.
static var fists: Dictionary = {}
func fist_ahead(body: Node3D, side: String, swing: float) -> Vector3:
	var key = "%s%.3f%.3f%s%.2f" % [body.look.who,body.size,body.look.get("bulk",0.0)+body.look.get("gaunt",0.0),side,swing]
	if fists.has(key): return fists[key]
	var skeleton: Skeleton3D = body.skeleton
	var into: Transform3D = body.global_transform.affine_inverse()*skeleton.global_transform
	var rest = func(bone: String) -> Vector3: return into*skeleton.get_bone_global_rest(skeleton.find_bone(bone+"_"+side)).origin
	var shoulder: Vector3 = rest.call("upperarm")
	var upper: float = shoulder.distance_to(rest.call("lowerarm"))
	var reaching = body.drinking_arm(side)
	var hand: Transform3D = into*skeleton.get_bone_global_rest(skeleton.find_bone("hand_"+side))
	var fore: float = rest.call("lowerarm").distance_to(rest.call("hand"))+(hand.basis*reaching.palm).length()*.9
	var at: Vector3 = shoulder+Vector3(0,-upper*cos(swing),upper*sin(swing))+Vector3(0,0,fore)
	fists[key] = at
	return at

# Where a fist carries a thing by its handle, in the figure's own frame.
func carried_at(body: Node3D, side: String) -> Vector3:
	return fist_ahead(body,side,CARRY_SWING)

# A thing is held by its handle (a mug), by its neck (a bottle), or lies
# flat on the palm (a plate). Where it is held, in its own unit box.
const BOTTLE_NECK = Vector3(0,.78,0)
func grip_point(node: Node3D) -> Vector3:
	return BOTTLE_NECK if node.get_meta("kind","mug") == "bottle" else Person.MUG_HANDLE

func grip_at(node: Node3D) -> Vector3:
	return node.global_transform*grip_point(node)

# Into the `side` fist of `body`, as it stands now; it then lies as in_fist
# has it.
func take_up(body: Node3D, node: Node3D, side: String) -> void:
	body.drinking_arm(side)
	var handle: Node3D = body.handle_grips[side]
	var was: Transform3D = node.global_transform
	if node.get_parent() != null: node.get_parent().remove_child(node)
	handle.add_child(node)
	node.global_transform = was
	node.set_meta("rest",was)
	body.held = node

# How a thing in a fist lies: as the fist holds it, upright through it
# (`toward` 0), or as it stands at `pose` in the world (1), or between (as
# it is taken up from there, or set down there).
func in_fist(node: Node3D, pose: Transform3D, toward: float) -> void:
	var handle: Node3D = node.get_parent()
	if handle == null: return
	var size: Vector3 = node.transform.basis.get_scale()
	var fist = Transform3D(Basis.from_scale(size),-(Basis.from_scale(size)*grip_point(node)))
	var there: Transform3D = handle.global_transform.affine_inverse()*pose
	var turn: Quaternion = Quaternion.IDENTITY.slerp(there.basis.get_rotation_quaternion(),toward)
	node.transform = Transform3D(Basis(turn)*Basis.from_scale(size),fist.origin.lerp(there.origin,toward))

# Out of the hand, standing where it is.
func put_down(node: Node3D) -> void:
	var at: Transform3D = node.global_transform
	if node.get_parent() != null: node.get_parent().remove_child(node)
	add_child(node)
	node.global_transform = at

# Upright at `at`, turned `yaw`, at its own size.
func stood(node: Node3D, at: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(node.transform.basis.get_scale() if node.get_parent() == self else node.global_transform.basis.get_scale()),at)

# ---- Clearing ----

# Everything left about, as {node, kind} (and "seat", a drained mug set by
# at a place), that she may clear: nothing a drinker is using (within
# USE_REACH of where his mug stands; a drained mug of his own he has done
# with), nothing where Anya is serving or at her elbow at the bar.
func clearable() -> Array:
	var out: Array = []
	var serving: Dictionary = round[0].seat if not round.is_empty() and anya.state in ["carry","place"] else {}
	for i in range(litter.size()-1,-1,-1):
		if not is_instance_valid(litter[i].node) or litter[i].node.is_queued_for_deletion(): litter.remove_at(i)
	for thing in litter:
		var at: Vector3 = thing.node.global_position
		if anya_near(at): continue
		if seats.any(func(seat): return place_in_use(seat) and Vector2(seat.mug.x-at.x,seat.mug.z-at.z).length() < USE_REACH): continue
		out.append(thing)
	for seat in seats:
		if seat == serving or seat.left == null or not is_instance_valid(seat.left): continue
		seat.left.set_meta("kind","mug")
		out.append({"node":seat.left,"kind":"mug","seat":seat})
	return out

# Something to clear: the nearest, and what lies by it that goes where it
# goes, as much as her hands will hold (a mug or a bottle in each fist, her
# left palm under plates, the right hand then free for one more).
func clear_next() -> bool:
	var things: Array = clearable()
	if things.is_empty(): return false
	for thing in things: thing.stand = stand_by(thing.node.global_position)
	things.sort_custom(func(a, b): return a.stand.distance_to(selene.at) < b.stand.distance_to(selene.at))
	var first: Dictionary = things[0]
	var to: String = "crate" if first.kind == "bottle" else "tub"
	var picks: Array = []
	var plates = 0
	var fists = {"l":false,"r":false}
	for thing in things:
		if ("crate" if thing.kind == "bottle" else "tub") != to: continue
		if thing.node.global_position.distance_to(first.node.global_position) > TAKE_REACH: continue
		var side = ""
		if thing.kind == "plate":
			# The first onto her left palm; the rest by her right hand onto it.
			if fists.l or plates >= PLATES: continue
			plates += 1
			side = "l" if plates == 1 else "r"
		else:
			side = "r" if not fists.r else ("l" if not fists.l and plates == 0 else "")
			if side == "": continue
			fists[side] = true
		picks.append({"node":thing.node,"kind":thing.kind,"side":side,"seat":thing.get("seat",{})})
	# (The plates first, then what goes in the fists; claimed, so no one
	# else clears them meanwhile.)
	picks.sort_custom(func(a, b): return a.kind == "plate" and b.kind != "plate")
	for pick in picks:
		if not pick.seat.is_empty(): pick.seat.left = null
		for i in range(litter.size()-1,-1,-1):
			if litter[i].node == pick.node: litter.remove_at(i)
	chore = {"kind":"clear","picks":picks,"stand":first.stand,"to":to,"in":{"l":[],"r":[]},"i":0}
	selene.route = way(selene.at,first.stand)
	selene.route.append(first.stand)
	selene.state = "to_things"
	return true

# Where she stands to put things away, and where each goes.
func put_place() -> Vector3:
	return tub_stand if chore.to == "tub" else empties_stand

# How her hands hold what they have, as she walks or stands (all but `busy`,
# the hand at work).
func carry_pose(busy: String = "") -> void:
	var body = selene.body
	var held: Dictionary = chore.get("in",{"l":[],"r":[]})
	for side in ["l","r"]:
		if side == busy: continue
		if held[side].is_empty():
			if side == "r" and body.arms.has("r"):
				body.arms.r.weight = 0.0
				body.arms.r.curl = 0.0
			elif side == "l" and busy != "l": body.reach(Vector3.ZERO,0.0,0.0)
		elif not is_instance_valid(held[side][0]): continue
		elif held[side][0].get_meta("kind","") == "plate": lay_palm(body,body.global_transform*TRAY_CARRY,body.global_transform.basis*PALM_UP,1.0)
		else: body.drink_reach(side,body.global_transform*carried_at(body,side),Vector3.UP,1.0,1.0)

# How far she leans to reach `point` (more, the further it is from her).
func lean_for(point: Vector3) -> float:
	return clampf((Vector2(point.x-selene.at.x,point.z-selene.at.z).length()-ARM_REACH)*1.1,0.0,LEAN_MOST)

# Taking up what she came for, one thing after another: the hand goes to
# it, takes it, and brings it in (a plate onto those on her left palm).
func take_things(delta: float) -> void:
	var body = selene.body
	var picks: Array = chore.picks
	if chore.i >= picks.size():
		chore.i = 0
		selene.phase_time = 0.0
		selene.route = way(selene.at,put_place())
		selene.route.append(put_place())
		selene.state = "carry"
		lean_to = 0.0
		return
	var pick: Dictionary = picks[chore.i]
	var node: Node3D = pick.node
	if not is_instance_valid(node):
		chore.i += 1
		selene.phase_time = 0.0
		return
	var t: float = selene.phase_time
	var reach_t: float = smoothstep(0.0,1.0,t/(TAKE*.5))
	var bring_t: float = smoothstep(0.0,1.0,(t-TAKE*.5)/(TAKE*.5))
	var side: String = pick.side
	carry_pose(side if pick.kind != "plate" or chore.in.l.is_empty() else "")
	if not pick.has("from"): pick.from = node.global_transform
	var from: Transform3D = pick.from
	body.turn_to(from.origin-selene.at,delta,8.0)
	lean_to = lean_for(from.origin)
	if pick.kind == "plate":
		# By its near rim; then onto her palm, on top of the others.
		var rim: Vector3 = from.origin+Vector3(selene.at.x-from.origin.x,0,selene.at.z-from.origin.z).normalized()*.2+Vector3.UP*.02
		var on: Transform3D = tray.global_transform*Transform3D(Basis.from_scale(from.basis.get_scale()),Vector3.UP*(ON_PALM+PLATE_STEP*chore.in.l.size()))
		if t < TAKE*.5:
			body.drink_reach(side,rim,Vector3.UP,reach_t,reach_t*.6) if side == "r" else lay_palm(body,rim,body.global_transform.basis*Person.GRIP_HAND,reach_t)
		else:
			# (Level all the way, lifted clear of what else is on the table.)
			var path = Transform3D(from.basis,from.origin.lerp(on.origin,bring_t)+Vector3.UP*.08*sin(bring_t*PI))
			node.global_transform = path
			var under: Vector3 = path.origin+(rim-from.origin)
			if side == "r": body.drink_reach("r",under,Vector3.UP,1.0-smoothstep(.7,1.0,bring_t),.6)
			else: lay_palm(body,under.lerp(body.global_transform*TRAY_CARRY,bring_t),(body.global_transform.basis*Person.GRIP_HAND).slerp(body.global_transform.basis*PALM_UP,bring_t),1.0)
		if t >= TAKE:
			if node.get_parent() != tray:
				if node.get_parent() != null: node.get_parent().remove_child(node)
				tray.add_child(node)
			node.transform = Transform3D(Basis.from_scale(from.basis.get_scale()),Vector3.UP*(ON_PALM+PLATE_STEP*chore.in.l.size()))
			chore.in.l.append(node)
			if side == "r":
				body.arms.r.weight = 0.0
				body.arms.r.curl = 0.0
	else:
		# By its handle, or its neck; then up into the fist and in to her.
		var grip: Vector3 = from*grip_point(node)
		var carried: Vector3 = body.global_transform*carried_at(body,side)
		if t < TAKE*.5: body.drink_reach(side,grip,Vector3.UP,reach_t,smoothstep(.5,1.0,reach_t))
		else:
			if node.get_parent() == self or node.get_parent() == world: take_up(body,node,side)
			in_fist(node,from,1.0-bring_t)
			body.drink_reach(side,grip.lerp(carried,bring_t)+Vector3.UP*.04*sin(bring_t*PI),Vector3.UP,1.0,1.0)
		if t >= TAKE:
			in_fist(node,from,0.0)
			chore.in[side].append(node)
	if t >= TAKE:
		chore.i += 1
		selene.phase_time = 0.0

# Putting away what she carries, a hand at a time: into the tub (washed,
# and in to Anya: gone), or into the crate of empties, a bottle standing in
# each of its places (the oldest taken away when it is full).
func put_things(delta: float) -> void:
	var body = selene.body
	var target: Vector3 = tub_at if chore.to == "tub" else empties_at
	body.turn_to(target-selene.at,delta,8.0)
	lean_to = lean_for(target)
	var side: String = "r" if not chore.in.r.is_empty() else ("l" if not chore.in.l.is_empty() else "")
	if side == "":
		body.let_go()
		lean_to = 0.0
		chore = {}
		idle(selene)
		selene.timer = 0.0
		return
	carry_pose(side)
	var t: float = selene.phase_time
	var down_t: float = smoothstep(0.0,1.0,t/(PUT*.55))
	var back_t: float = smoothstep(0.0,1.0,(t-PUT*.55)/(PUT*.45))
	if chore.get("dunked",false) or (not chore.has("there") and chore.in[side][0].get_meta("kind","") == "plate"):
		# The stack let down into the water, and her hand out again.
		var water: Vector3 = tub_at+Vector3.UP*(TUB_WATER-.03)
		var carried: Vector3 = body.global_transform*TRAY_CARRY
		lay_palm(body,carried.lerp(water,down_t if t < PUT*.55 else 1.0-back_t),body.global_transform.basis*PALM_UP,1.0)
		if t >= PUT*.55 and not chore.get("dunked",false):
			chore.dunked = true
			for plate in chore.in.l: plate.queue_free()
		if t >= PUT:
			chore.in.l.clear()
			chore.erase("dunked")
			body.reach(Vector3.ZERO,0.0,0.0)
			selene.phase_time = 0.0
		return
	var carried: Vector3 = body.global_transform*carried_at(body,side)
	if not chore.has("there"):
		var node: Node3D = chore.in[side][0]
		var pose: Transform3D
		if node.has_meta("put"): pose = node.get_meta("put")
		elif chore.to == "tub": pose = stood(node,tub_at+Vector3(chore_rng.randf_range(-.05,.05),TUB_WATER-.1,chore_rng.randf_range(-.05,.05)),chore_rng.randf_range(0,TAU))
		else: pose = stood(node,empties_slot(),chore_rng.randf_range(0,TAU))
		node.set_meta("put",pose)
		var there: Vector3 = pose*grip_point(node)
		if t < PUT*.55:
			in_fist(node,pose,smoothstep(.6,1.0,down_t))
			body.drink_reach(side,carried.lerp(there,down_t),Vector3.UP,1.0,1.0)
		else:
			# Let go: in the water (and gone), or standing in the crate.
			in_fist(node,pose,1.0)
			put_down(node)
			node.global_transform = pose
			node.remove_meta("put")
			if body.held == node: body.held = null
			if chore.to == "tub": node.queue_free()
			else:
				empties.append(node)
				if empties.size() > EMPTIES_SLOTS.x*EMPTIES_SLOTS.y: empties.pop_front().queue_free()
			chore.there = there
	if chore.has("there"):
		var there: Vector3 = chore.there
		body.drink_reach(side,there.lerp(carried,back_t*.5)+Vector3.UP*.06*back_t,Vector3.UP,1.0-back_t,1.0-back_t)
	if t >= PUT:
		chore.in[side].pop_front()
		chore.erase("there")
		if side == "r":
			body.arms.r.weight = 0.0
			body.arms.r.curl = 0.0
		selene.phase_time = 0.0

# ---- Wiping ----

# A place she may wipe: no one sits there (or is coming to), nothing stands
# there, and it has not been wiped since its last drinker got up, or for
# WIPE_REST.
func wants_wiping(i: int) -> bool:
	var seat: Dictionary = seats[i]
	if place_in_use(seat) or chore_clock-wiped[i] < WIPE_REST: return false
	if seat.left != null and is_instance_valid(seat.left): return false
	return not litter.any(func(thing): return is_instance_valid(thing.node) and Vector2(seat.mug.x-thing.node.global_position.x,seat.mug.z-thing.node.global_position.z).length() < USE_REACH)

# The nearest place that wants wiping, and the others at its table that do.
func wipe_next() -> bool:
	var due: Array = range(seats.size()).filter(func(i): return wants_wiping(i))
	if due.is_empty(): return false
	due.sort_custom(func(a, b): return seats[a].serve.distance_to(selene.at) < seats[b].serve.distance_to(selene.at))
	var table: Vector3 = seats[due[0]].table
	wiping = due.filter(func(i): return seats[i].table == table)
	next_wipe()
	return true

func next_wipe() -> void:
	while not wiping.is_empty() and not wants_wiping(wiping[0]): wiping.pop_front()
	if wiping.is_empty():
		done_wiping()
		return
	var i: int = wiping.pop_front()
	chore = {"kind":"wipe","place":i}
	selene.route = way(selene.at,seats[i].serve)
	selene.route.append(seats[i].serve)
	selene.state = "to_table"

# The rag out from her apron's string into her hand, or back.
func rag_in_hand(holding: bool) -> void:
	rag_hung.visible = not holding
	if holding:
		if rag.get_parent() != null: rag.get_parent().remove_child(rag)
		palm.add_child(rag)
		rag.transform = Transform3D.IDENTITY
		selene.body.held = rag
	else:
		if selene.body.held == rag: selene.body.held = null
		stow(rag)

func done_wiping() -> void:
	wiping.clear()
	rag_in_hand(false)
	chore = {}
	lean_to = 0.0
	back_to_post()

# Wiping at `spot` (on a table or the bar top): her palm on the rag going
# round and round on the top, eased in over the first half second and out
# over the last (`time` gone, `left` to go).
func wipe_at(spot: Vector3, time: float, left: float, delta: float) -> void:
	var body = selene.body
	body.turn_to(spot-selene.at,delta,8.0)
	lean_to = lean_for(spot)
	var turn: float = time/WIPE_BEAT*TAU
	var at: Vector3 = spot+Vector3(cos(turn),0,sin(turn))*WIPE_ROUND+Vector3.UP*WIPE_ABOVE
	lay_palm(body,at,palm_down(body),smoothstep(0.0,.5,time)*smoothstep(0.0,.5,left))

# ---- The bar ----

# The bar, when there is nothing else for her: nothing to clear and no free
# place to wipe. She wipes the bar's top down from behind it at BAR_SPOTS
# places along its west half (BAR_WIPE_TIME at each), keeping clear of
# Anya's end and of Anya (ANYA_CLEAR). Not again for BAR_REST. Behind its
# west end stand the wash tub (TUB, its water TUB_WATER up) and the crate of
# empties (EMPTIES), the bottles standing in it in EMPTIES_SLOTS rows.
const BAR_REST = 60.0
const BAR_SPOTS = [3.7,4.9,6.1]
const BAR_TOP = 1.12
const BAR_ACROSS = 8.13
const BEHIND_BAR = 7.72
const BAR_WIPE_TIME = 3.0
const ANYA_CLEAR = 1.3
const TUB_WATER = .5
const EMPTIES_SLOTS = Vector2i(3,7)
const EMPTIES_HEIGHT = .3
var bar_wiped = -BAR_REST
var bar_spots: Array = []
var tub_at = Vector3.ZERO
var tub_stand = Vector3.ZERO
var empties_at = Vector3.ZERO
var empties_stand = Vector3.ZERO
var empties: Array = []
var empties_crate: Node3D

func lay_tub() -> void:
	var c = Interiors.INN
	tub_at = c+TUB
	tub_stand = floor_nearest(Vector3(c.x+2.3,0,c.z+7.55))
	var tub = Kit.prop("barrel",.62)
	tub.name = "WashTub"
	add_child(tub)
	tub.position = tub_at
	# Its water, dark and still, a little below the brim.
	var water = MeshInstance3D.new()
	var face = CylinderMesh.new()
	face.top_radius = .2; face.bottom_radius = .2; face.height = .01
	water.mesh = face
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(.12,.11,.09)
	dark.roughness = .1
	dark.metallic_specular = .8
	water.material_override = dark
	add_child(water)
	water.position = tub_at+Vector3.UP*.55
	# The crate the empties stand in, long side to the wall.
	empties_at = c+EMPTIES
	empties_stand = floor_nearest(empties_at+Vector3(.9,0,0))
	empties_crate = Kit.prop("crate_empty",EMPTIES_HEIGHT)
	empties_crate.name = "Empties"
	add_child(empties_crate)
	empties_crate.position = empties_at
	empties_crate.rotation.y = PI/2

# The crate's next free place for a bottle, on its floor.
func empties_slot() -> Vector3:
	var k: int = empties.size()%(EMPTIES_SLOTS.x*EMPTIES_SLOTS.y)
	var inner = Vector2(EMPTIES_SIZE.x-.1,EMPTIES_SIZE.y-.1)
	var across: float = (float(k%EMPTIES_SLOTS.x)+.5)/EMPTIES_SLOTS.x-.5
	var along: float = (float(k/EMPTIES_SLOTS.x)+.5)/EMPTIES_SLOTS.y-.5
	return empties_at+Vector3(across*inner.x,.03,along*inner.y)

# (Called away from it to clear something, she comes back to wipe the rest.)
func tend_bar() -> bool:
	if bar_spots.is_empty():
		if chore_clock-bar_wiped < BAR_REST: return false
		var c = Interiors.INN
		bar_spots = BAR_SPOTS.map(func(x): return Vector3(c.x+x,BAR_TOP,c.z+BAR_ACROSS))
	chore = {"kind":"bar"}
	next_bar_wipe()
	return true

func next_bar_wipe() -> void:
	if bar_spots.is_empty():
		done_bar()
		return
	# (Something to clear meanwhile, and she leaves the bar for it; Anya at
	# every place left to wipe, and she waits a moment for her to go.)
	var clear: Array = bar_spots.filter(func(spot): return not anya_near(spot))
	if not clearable().is_empty() or clear.is_empty():
		rag_in_hand(false)
		chore = {}
		lean_to = 0.0
		selene.body.let_go()
		idle(selene)
		selene.timer = 0.0
		return
	var spot: Vector3 = clear[0]
	bar_spots.erase(spot)
	chore.spot = spot
	# (Close behind the bar, where Anya stands to draw.)
	var stand = floor_nearest(Vector3(spot.x,0,Interiors.INN.z+BEHIND_BAR))
	selene.route = way(selene.at,stand)
	selene.route.append(stand)
	selene.state = "to_bar"

func done_bar() -> void:
	bar_wiped = chore_clock
	bar_spots.clear()
	rag_in_hand(false)
	chore = {}
	lean_to = 0.0
	selene.body.let_go()
	idle(selene)

func anya_near(spot: Vector3) -> bool:
	return Vector2(anya.at.x-spot.x,anya.at.z-spot.z).length() < ANYA_CLEAR

# Puts down whatever she is about (the inn shut, the clock jumped): what is
# in her hands goes in to be washed.
func drop_chores() -> void:
	selene.body.let_go()
	selene.body.figure.rotation.x = 0.0
	lean_to = 0.0
	for side in chore.get("in",{}):
		for node in chore.in[side]:
			if is_instance_valid(node): node.queue_free()
	if chore.get("kind","") == "clear":
		for pick in chore.picks:
			if is_instance_valid(pick.node) and pick.node.get_parent() != self and pick.node.get_parent() != world: pick.node.queue_free()
	rag_in_hand(false)
	selene.body.held = null
	chore = {}
	wiping.clear()
	bar_spots.clear()

func chores(delta: float) -> void:
	chore_clock += delta
	if selene.state in ABED:
		if not chore.is_empty() or selene.body.held != null or rag.get_parent() == palm: drop_chores()
		retire(selene,delta)
		return
	selene.timer -= delta
	selene.phase_time += delta
	var body = selene.body
	# She leans to the table as she wipes it, or to what she reaches for,
	# and straightens again.
	var lean: float = maxf(WIPE_LEAN,lean_to) if selene.state in ["wipe","bar_wipe"] else (lean_to if selene.state in ["take","put"] else 0.0)
	body.figure.rotation.x = move_toward(body.figure.rotation.x,lean,delta*.5)
	# Her hand flat on the rag, or under plates.
	var flat: bool = rag.get_parent() == palm or not tray.get_children().filter(func(n): return not n.is_queued_for_deletion()).is_empty()
	flat_hand.weight = move_toward(flat_hand.weight,1.0 if flat else 0.0,delta*4.0)
	match selene.state:
		"to_post":
			if advance(selene,delta): idle(selene)
		"idle":
			body.turn_to(Vector3(1.0,0,.4),delta,5.0)
			if body.state != "Idle" and body.state != "Arms": body.play("Idle")
			if selene.timer <= 0.0:
				selene.timer = CHORE_LOOK
				# Once the inn is shut and the last has gone, home to bed.
				if abed(selene) and people.all(func(w): return not w.state in ["to_inn","sit_down","wait","drink"]):
					drop_chores()
					go_to_bed(selene)
				elif not clear_next() and not wipe_next() and not tend_bar() and selene.at.distance_to(selene_spot) > .2: back_to_post()
		"to_things":
			carry_pose()
			# (Something she came for taken up by someone else, or come into
			# use: she leaves it.)
			if chore.picks.any(func(p): return not is_instance_valid(p.node)):
				chore.picks = chore.picks.filter(func(p): return is_instance_valid(p.node))
				if chore.picks.is_empty():
					chore = {}
					back_to_post()
					return
			if advance(selene,delta):
				selene.state = "take"
				selene.phase_time = 0.0
				body.play("Idle",.2)
		"take": take_things(delta)
		"carry":
			carry_pose()
			if advance(selene,delta):
				selene.state = "put"
				selene.phase_time = 0.0
				body.play("Idle",.2)
		"put": put_things(delta)
		"to_bar":
			if anya_near(chore.spot):
				bar_spots.append(chore.spot)
				next_bar_wipe()
			elif advance(selene,delta):
				selene.state = "bar_wipe"
				selene.phase_time = 0.0
				selene.timer = BAR_WIPE_TIME
				body.play("Idle",.2)
				rag_in_hand(true)
		"bar_wipe":
			if anya_near(chore.spot):
				body.let_go()
				bar_spots.append(chore.spot)
				next_bar_wipe()
				return
			wipe_at(chore.spot,selene.phase_time,selene.timer,delta)
			if selene.timer <= 0.0:
				body.let_go()
				next_bar_wipe()
		"to_table":
			if place_in_use(seats[chore.place]):
				next_wipe()
			elif advance(selene,delta):
				selene.state = "wipe"
				selene.phase_time = 0.0
				selene.timer = WIPE_TIME
				body.play("Idle",.2)
				rag_in_hand(true)
		"wipe":
			# Someone come to sit here: she leaves it be.
			var i: int = chore.place
			if place_in_use(seats[i]):
				body.let_go()
				next_wipe()
				return
			var seat: Dictionary = seats[i]
			wipe_at(seat.mug+Vector3.UP*(world.lift(seat.at)-.02),selene.phase_time,selene.timer,delta)
			if selene.timer <= 0.0:
				wiped[i] = chore_clock
				body.let_go()
				next_wipe()

# ---- Zeno ----

# Zeno, who sells bread from a handcart (scripts/bread_cart.gd): through the
# day he pushes it round the town's streets, stopping a while at the places
# the townsfolk go (ZENO_STOP); while he stands there, now and then one of
# them comes up to the cart (BREAD_CHANCE, each time one sets off somewhere),
# talks a moment and is handed a loaf, and goes on with it in his hand (for
# LOAF_KEPT). Every so often (CALL, give or take CALL_SPREAD), while no one is
# buying, he calls out his bread. At nightfall he pushes the cart home, parks
# it beside his door, tipped back onto its legs, and goes in; in the morning
# he comes out and takes it up again. His house is his alone.
const BreadCart = preload("res://scripts/bread_cart.gd")
const ZENO_WALK = WALK*.85
const ZENO_STOP = Vector2(14.0,28.0)
const BREAD_CHANCE = .05
const BREAD_REACH = 30.0
const BREAD_TIME = 6.0
const LOAF_KEPT = 60.0
const CALL = 20.0
const CALL_SPREAD = 3.0
const CRY = "Fresh bread for sale!"
# How near the hero must be for Zeno's call to be heard (shown over him).
const HEARD = 30.0
# How far behind the cart's axle he walks, his hands on its grips; and how
# fast the cart comes round to its way.
const BEHIND = 1.58
const CART_TURN = 2.6
const ZENO_LOOK = {"who":"man","garment":"Tunic","cloth":Color(.64,.58,.46),"wear":.22,"hair":"Hair_Buzzed","beard":true,"hair_colour":Color(.18,.12,.08),
	"skin":"light","tone":Color(1.0,.9,.8),"belt":Color(.35,.24,.15),"shoes":Color(.3,.21,.13),"size":1.0,"seed":.58,"apron":Color(.8,.76,.66)}
var zeno: Walker
var cart = {}
var cart_at = Vector3.ZERO
var cart_heading = 0.0
var cart_tilt = 0.0
# Where the cart stands for the night, beside his door, and which way.
var cart_home = Vector3.ZERO
var cart_home_heading = 0.0
var bread_rng = RandomNumberGenerator.new()
var bread_customer: Walker
# Whether any may come to buy (tests stop them, to hear him cry his bread).
var bread_buyers = true
var call_left = CALL
# How often he has called out, and how many loaves he has sold.
var calls = 0
var sold = 0

func hire_zeno() -> void:
	bread_rng.seed = 6061
	zeno = Walker.new()
	zeno.body = figure(ZENO_LOOK)
	zeno.body.name = "Zeno"
	BreadCart.put_on(BreadCart.straw_hat(),zeno.body)
	zeno.speed = ZENO_WALK
	cart = BreadCart.handcart(bread_rng)
	add_child(cart.node)
	# His house: a free one, nearest the market, which no one else sleeps in.
	var taken: Array = (people+children+[orion,selene]+keepers).filter(func(w): return w.bed.get("kind") == "house").map(func(w): return w.bed.at)
	var homes: Array = world.places.filter(func(p): return p.kind == "house" and p.name == "house")
	var free = homes.filter(func(h): return taken.all(func(t): return house_bed(h).at.distance_to(t) > .5))
	var market: Vector3 = Vector3(Town.MARKET.get_center().x,0,Town.MARKET.get_center().y)
	free.sort_custom(func(a, b): return a.at.distance_to(market) < b.at.distance_to(market))
	# (Of them, one with room beside its doorstep for the cart.)
	for home in free:
		var bed: Dictionary = house_bed(home)
		var spot = park_by(bed)
		if spot.is_empty(): continue
		zeno.bed = bed
		cart_home = spot.at
		cart_home_heading = spot.heading
		break
	if zeno.bed.is_empty():
		zeno.bed = house_bed(free[0])
		cart_home = nearest_open(zeno.bed.way[0],3)
		cart_home_heading = zeno.bed.yaw+PI/2
	zeno.bedtime = bread_rng.randf_range(KEEPER_BEDTIME.x,KEEPER_BEDTIME.y)
	zeno.rising = bread_rng.randf_range(KEEPER_RISING.x,KEEPER_RISING.y)
	# He begins at a place in the streets, his cart before him.
	var start: Vector3 = haunts.filter(func(h): return h.kind == "market")[0].at
	cart_at = start
	cart_heading = 0.0
	place_cart()
	follow_cart(0.0)
	sell()

# Room for the cart beside a house's doorstep: along the wall, clear of the
# door, all of it on open ground; {} if there is none.
func park_by(bed: Dictionary) -> Dictionary:
	var step: Vector3 = bed.way[0]
	var inward = Vector3(sin(bed.yaw),0,cos(bed.yaw))
	var along: Vector3 = inward.cross(Vector3.UP)
	# (Out from the wall a little, into the street, so it stands clear of it.)
	for out in [.7,1.1]:
		for side in [1.0,-1.0]:
			for reach in [1.8,2.4,3.0]:
				var at: Vector3 = step+along*side*reach-inward*out
				var heading: float = atan2(along.x*side,along.z*side)
				var ahead = Vector3(sin(heading),0,cos(heading))
				var clear = true
				for p in [at,at+ahead*.75,at-ahead*.9,at-ahead*1.7,at-inward*.5]:
					if not open_at(p): clear = false
				if clear: return {"at":at,"heading":heading}
	return {}

# The cart where it stands (and tipped onto its legs, `cart_tilt`); its
# wheels turned on by `rolled` metres.
func place_cart(rolled: float = 0.0) -> void:
	var node: Node3D = cart.node
	node.position = Vector3(cart_at.x,world.lift(cart_at),cart_at.z)
	node.rotation.y = cart_heading
	cart.body.rotation.x = cart_tilt
	for wheel in cart.wheels: wheel.rotation.x += rolled/BreadCart.WHEEL

# Zeno behind his cart, his hands on its grips (scripts/arm_reach.gd), or
# standing by it with them free (`hands` 0).
func follow_cart(delta: float, hands: float = 1.0) -> void:
	var ahead = Vector3(sin(cart_heading),0,cos(cart_heading))
	zeno.at = Vector3(cart_at.x,0,cart_at.z)-ahead*BEHIND
	zeno.body.rotation.y = cart_heading
	var frame: Transform3D = cart.body.global_transform
	for k in 2:
		var side: String = ["l","r"][k]
		# (His left hand on the cart's left grip: the cart's -X is his left.)
		var grip: Vector3 = cart.grips[1-k]
		var reaching = zeno.body.drinking_arm(side)
		reaching.tool = true
		reaching.upright = false
		reaching.target = frame*(grip-Vector3(0,BreadCart.WHEEL,0))
		reaching.axis = (frame.basis*Vector3(0,.3,1.0)).normalized()
		reaching.weight = move_toward(reaching.weight,hands,delta*3.0) if delta > 0.0 else hands
		reaching.curl = reaching.weight

func sell() -> void:
	zeno.state = "selling"
	zeno.timer = bread_rng.randf_range(ZENO_STOP.x,ZENO_STOP.y)
	zeno.body.play("Idle",.3)

# On to another place the townsfolk go, by the streets.
func push_on() -> void:
	var roll = bread_rng.randf()
	var kind = "ring" if roll < .55 else ("market" if roll < .85 else "alley")
	var choices = haunts.filter(func(h): return h.kind == kind and h.at.distance_to(cart_at) > 15.0 and h.at.distance_to(cart_at) < 90.0)
	if choices.is_empty(): choices = haunts.filter(func(h): return h.at.distance_to(cart_at) > 10.0)
	push_to(choices[bread_rng.randi_range(0,choices.size()-1)].at)

func push_to(goal: Vector3) -> void:
	zeno.route = way(cart_at,goal)
	zeno.route.append(goal)
	zeno.state = "push"

# The cart pushed along its way, its axle on it, coming round to it as it
# goes; true once it is there.
func roll(delta: float) -> bool:
	if zeno.route.is_empty(): return true
	var to: Vector3 = zeno.route[0]-cart_at
	to.y = 0
	var heading: float = atan2(to.x,to.z)
	var off: float = absf(angle_difference(cart_heading,heading))
	cart_heading = rotate_toward(cart_heading,heading,CART_TURN*delta)
	# (Slower while it comes round a corner.)
	var step: float = zeno.speed*delta*clampf(1.2-off,.25,1.0)
	var moved = minf(step,to.length())
	if to.length() <= step:
		cart_at = Vector3(zeno.route[0].x,0,zeno.route[0].z)
		zeno.route.remove_at(0)
	else: cart_at += to.normalized()*step
	place_cart(moved)
	zeno.body.stride("Walk",moved/maxf(delta,.0001))
	return zeno.route.is_empty()

func zeno_tick(delta: float, hero: Vector3) -> void:
	zeno.timer -= delta
	if zeno.state in ABED:
		retire(zeno,delta)
		return
	match zeno.state:
		"to_cart":
			# Out of his door, round to the back of the cart.
			if advance(zeno,delta):
				zeno.state = "take_up"
				zeno.timer = .8
				zeno.body.play("Idle",.2)
		"take_up":
			cart_tilt = move_toward(cart_tilt,0.0,delta*.4)
			place_cart()
			follow_cart(delta)
			if zeno.timer <= 0.0:
				cart_tilt = 0.0
				place_cart()
				push_on()
		"push":
			var there: bool = roll(delta)
			follow_cart(delta)
			if there: sell()
		"selling":
			follow_cart(delta,0.0 if bread_customer != null else 1.0)
			var customer: Walker = bread_customer
			if customer != null and customer.state == "bread":
				zeno.body.turn_to(customer.at-zeno.at,delta,5.0)
				zeno.body.play("Reach" if customer.timer < HAND_OVER else "Talk")
			elif customer == null:
				if abed(zeno): go_home()
				elif zeno.timer <= 0.0: push_on()
				elif not zeno.body.state in ["Idle","Arms"]: zeno.body.play("Idle",.3)
		"home_cart":
			var home: bool = roll(delta)
			follow_cart(delta)
			if home:
				zeno.state = "parking"
				zeno.timer = 1.0
				zeno.body.play("Idle",.2)
		"parking":
			cart_heading = rotate_toward(cart_heading,cart_home_heading,delta*1.5)
			cart_tilt = move_toward(cart_tilt,BreadCart.REST_TILT,delta*.4)
			place_cart()
			follow_cart(delta,0.0)
			if zeno.timer <= 0.0:
				cart_heading = cart_home_heading
				cart_tilt = BreadCart.REST_TILT
				place_cart()
				zeno.body.let_go()
				go_to_bed(zeno)
	# His cry, while no one is buying and he is about the streets.
	if zeno.state in ["push","selling"] and bread_customer == null:
		call_left -= delta
		if call_left <= 0.0:
			call_left = CALL+bread_rng.randf_range(-CALL_SPREAD,CALL_SPREAD)
			calls += 1
			cry(hero)

# Calls his bread: over his head, if the hero is near enough to hear.
func cry(hero: Vector3) -> void:
	if Vector2(hero.x-zeno.at.x,hero.z-zeno.at.z).length() > HEARD: return
	var game = world.get_parent()
	if game == null or game.get("hud") == null or not game.hud.has_method("speak"): return
	game.hud.speak(zeno.body,CRY)

# Home with the cart at nightfall, to park it by his door.
func go_home() -> void:
	zeno.route = way(cart_at,cart_home)
	zeno.route.append(cart_home)
	zeno.state = "home_cart"

# Out of his door in the morning: round behind the cart to take it up.
func zeno_up() -> void:
	var ahead = Vector3(sin(cart_heading),0,cos(cart_heading))
	var behind: Vector3 = Vector3(cart_at.x,0,cart_at.z)-ahead*BEHIND
	zeno.route = way(zeno.at,behind)
	zeno.route.append(behind)
	zeno.state = "to_cart"

# Whether one setting off might go to buy bread of him: he is stopped in the
# streets, no one else is buying, and he is not too far off.
func bread_open(walker: Walker) -> bool:
	return bread_buyers and zeno.state == "selling" and bread_customer == null and not walker.child and not abed(walker) and not abed(zeno) \
		and walker.at.distance_to(cart_at) < BREAD_REACH and not inside(walker)

# Off to the cart, to stand beside it, at its side by the handles.
func buy_bread(walker: Walker) -> bool:
	var ahead = Vector3(sin(cart_heading),0,cos(cart_heading))
	var side: Vector3 = ahead.cross(Vector3.UP)*(1.0 if bread_rng.randf() < .5 else -1.0)
	var stand_at: Vector3 = nearest_open(Vector3(cart_at.x,0,cart_at.z)+side*.85-ahead*.6,2)
	var route = way(walker.at,stand_at)
	if route.is_empty() and walker.at.distance_to(stand_at) > 1.0: return false
	route.append(stand_at)
	walker.route = route
	walker.state = "to_bread"
	bread_customer = walker
	return true

# At the cart: a word, a loaf handed over, and on his way with it.
func buy(walker: Walker, delta: float) -> void:
	match walker.state:
		"to_bread":
			# (Zeno gone on, or gone home: he goes about his day.)
			if zeno.state != "selling":
				release(walker)
				rest(walker,1.0,3.0)
			elif advance(walker,delta):
				walker.state = "bread"
				walker.timer = BREAD_TIME
				walker.body.play("Talk")
		"bread":
			walker.body.turn_to(cart_at-walker.at,delta,6.0)
			if walker.timer < HAND_OVER and walker.body.state != "Reach": walker.body.play("Reach")
			if walker.timer <= 0.0:
				bread_customer = null
				sold += 1
				var bread = BreadCart.loaf(bread_rng)
				walker.body.hold(bread)
				walker.basket = bread
				walker.loaf_left = LOAF_KEPT
				rest(walker,2.0,5.0)

# Night or day at once (the clock has jumped): the cart parked by his door
# and he indoors, or he out with it in the streets.
func zeno_at_once() -> void:
	if abed(zeno):
		if zeno.state in ["asleep","indoors"]: return
		if bread_customer != null: release(bread_customer)
		bread_customer = null
		cart_at = cart_home
		cart_heading = cart_home_heading
		cart_tilt = BreadCart.REST_TILT
		place_cart()
		zeno.body.let_go()
		tuck(zeno)
	elif zeno.state in ABED:
		zeno.body.visible = true
		cart_tilt = 0.0
		place_cart()
		follow_cart(0.0)
		sell()
