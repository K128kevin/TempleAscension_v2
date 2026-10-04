extends SceneTree
## The outdoor world: the town in the west, the desert, the temple's front in
## the east, the rock rim round all of it, and the door between it and the
## temple's first floor.
const Data = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Layout = preload("res://scripts/layout.gd")
const Overworld = preload("res://scripts/overworld.gd")
const Temple = preload("res://scripts/temple.gd")
const Town = preload("res://scripts/world_town.gd")
const Palace = preload("res://scripts/world_palace.gd")
const Daylight = preload("res://scripts/daylight.gd")
var game
var passed = 0
var failed: Array[String] = []

func _initialize(): call_deferred("test")

func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)

# Steps the game until `done` holds, at most `seconds` of game time.
func play(done: Callable, seconds: float) -> bool:
	var left = seconds
	while left>0:
		if done.call(): return true
		game._process(.05)
		left -= .05
	return done.call()

# Whether a colour is a brown: red over green over blue, and not vivid.
func brown(c) -> bool:
	return c.r>c.g and c.g>c.b and c.r<.5 and c.r-c.b<.3

# The town's woodwork, the elders' box, the palace on its hill, the alleys,
# and the gap between the two.
func town_checks():
	game.run = Data.new_character("warrior")
	game.load_floor()
	var world = game.world
	var masonry = load("res://assets/shaders/masonry.gdshader")
	var marble = Overworld.Kit.marble()
	var gold = Overworld.Kit.gold()
	# 1. Every door and shutter is brown.
	var woods: Dictionary = {}
	var gilded = 0
	var marbled = 0
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		var m = mesh.material_override
		if m == gold: gilded += 1
		if m == marble: marbled += 1
		if m is ShaderMaterial and m.shader == masonry: woods[m.get_shader_parameter("wood")] = true
	var all_brown = Town.WOODS.all(brown)
	for wood in woods: all_brown = all_brown and brown(wood)
	check(all_brown and woods.size()>=4,"Every door and shutter in the world is a shade of brown (%d woods)" % woods.size())

	# 2. The elders' box, in the north stands.
	var box = world.get_node_or_null("RoyalBox")
	var in_north_stands = false
	if box != null:
		var offset = Vector2(box.position.x-Town.ARENA.x,box.position.z-Town.ARENA.z)
		in_north_stands = absf(offset.x)<1.0 and offset.y<-Town.ARENA_FLOOR.y and (offset/Town.ARENA_RADII).length()<1.0 and box.position.y>Town.PODIUM
	check(in_north_stands,"A raised box stands in the arena's north stands, above the sand")
	var thrones = 0
	var sculptures = 0
	var facing_sand = true
	var throne_heights: Array = []
	var marble_top = false
	for node in world.get_children():
		if not node is Node3D: continue
		var inside = absf(node.position.x-Town.ARENA.x)<Town.BOX_HALF and node.position.z<Town.ARENA.z-Town.ARENA_FLOOR.y and node.position.z>Town.ARENA.z-Town.ARENA_RADII.y and node.position.y>=Town.BOX_FLOOR-.5
		if not inside: continue
		if node.has_meta("throne"):
			thrones += 1
			throne_heights.append(node.scale.y*Overworld.Kit.SIZE.chair.y)
			# A chair's seat is on its own +Z side: the sand is south of the box.
			facing_sand = facing_sand and (node.global_transform.basis*Vector3.BACK).normalized().distance_to(Vector3.BACK)<.01
		if node.has_meta("elders_table") and node.find_children("*","MeshInstance3D",true,false)[0].material_override == marble: marble_top = true
		if node.has_meta("statue") and node.get_meta("statue")=="lion" and node.get_meta("marble"): sculptures += 1
	check(facing_sand,"The thrones face the sand")
	# Chairs of a man's size, like the inn's seats, the middle one no larger.
	check(throne_heights.size()==5 and throne_heights.all(func(h): return is_equal_approx(h,throne_heights[0]) and h>.9 and h<1.3),"The thrones are alike and of a man's size (%s)" % [throne_heights])
	check(marble_top,"A marble-topped table stands before the thrones")
	check(thrones==5 and sculptures==0 and box != null and box.find_children("*","MeshInstance3D",true,false)[0].material_override == marble,"The box is marble, with five thrones and no statues (%d)" % sculptures)
	# Its walls are built of modules near the kit's own four metres square, and
	# its marble is laid at one size in the world: nothing is stretched.
	var stretched = 0
	var pieces = 0
	var wall_mesh = Overworld.Kit.mesh_of("wall")
	for node in world.get_children():
		if not node is Node3D or node is MultiMeshInstance3D: continue
		if absf(node.position.x-Town.ARENA.x)>Town.BOX_HALF+1.0 or node.position.z>Town.ARENA.z-Town.ARENA_FLOOR.y+1.0 or node.position.z<Town.ARENA.z-Town.ARENA_RADII.y: continue
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh != wall_mesh or mesh.material_override != marble: continue
			pieces += 1
			if node.scale.x>5.6 or node.scale.x/node.scale.y>2.2: stretched += 1
	check(pieces>=12 and stretched==0 and marble.uv1_world_triplanar,"The box's marble walls are built of unstretched pieces (%d of %d stretched)" % [stretched,pieces])
	check(gilded>=40 and marbled>=40,"Gold and marble are used on the box and the palace (%d gilded, %d marble)" % [gilded,marbled])
	var box_place: Dictionary = world.places.filter(func(s): return s.kind=="royal_box")[0]
	game.player.position = box_place.at
	game.hud.tick(0)
	check(game.hud.prompt.text=="" and world.fits(box_place.at),"Below the box, on the sand, the HUD names nothing")

	# 3. A road runs north from the arena's north gate, up a hill, to the palace.
	var palace: Dictionary = world.places.filter(func(s): return s.kind=="palace")[0]
	var north_gate = Town.ARENA+Vector3(0,0,-Town.ARENA_RADII.y-3.0)
	var road = world.path(north_gate,palace.at)
	check(not road.is_empty() and road[-1].distance_to(palace.at)<.5 and palace.at.z<Town.ARENA.z-Town.ARENA_RADII.y-40.0 and absf(palace.at.x-Town.ARENA.x)<2.0,"The palace stands north of the arena, and can be walked to from its north gate")
	var paved = true
	var climbing = true
	var last = -1.0
	var z = north_gate.z
	while z>palace.at.z:
		paved = paved and world.paint[world.index(roundi(Town.ARENA.x),roundi(z))*4+Overworld.PAVING]>150
		paved = paved and world.walk_line(Vector3(Town.ARENA.x,0,z),Vector3(Town.ARENA.x,0,z-1.0))
		var h: float = world.height_at(Town.ARENA.x,z)
		climbing = climbing and h>=last-.001
		last = h
		z -= 1.0
	check(paved,"The road is paved and open all the way")
	check(climbing and world.height_at(north_gate.x,north_gate.z)==0.0 and is_equal_approx(world.lift(palace.at),Overworld.HILL_HEIGHT) and Overworld.HILL_HEIGHT>=5.0 and Overworld.HILL_HEIGHT<=10.0,"It climbs a small hill: the palace stands %.0f m above the town" % Overworld.HILL_HEIGHT)
	check(world.height_at(Town.ARENA.x,Town.ARENA.z-Town.ARENA_RADII.y-Town.RING)==0.0 and world.height_at(Overworld.CARAVAN.x,Overworld.CARAVAN.z)==0.0,"The town and the desert stay level")
	# The hill's ground is the mesh tools/make_hill.py built from the same numbers.
	var matches = true
	var hill_mesh: MeshInstance3D = world.hill.find_children("*","MeshInstance3D",true,false)[0]
	var points: PackedVector3Array = hill_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in points:
		var at: Vector3 = hill_mesh.global_transform*point
		matches = matches and absf(at.y-.02-world.height_at(at.x,at.z))<.02
	check(matches and points.size()>1000,"The hill's ground matches the height the world reports (%d points)" % points.size())
	var terrace = world.get_node_or_null("PalaceTerrace")
	check(terrace != null and is_equal_approx(terrace.position.y,Overworld.HILL_HEIGHT),"The palace is built on the hilltop")
	# The road up is short: about half what it first was (105 m from the gate).
	var climb = length_of(road,north_gate)
	check(climb>=46.0 and climb<=60.0,"The road from the arena's north gate to the palace is about 53 m (%.0f m)" % climb)
	# Every statue of the town, the box, the road and the palace is a marble
	# lion, carved like the temple's own (the same shader, pale), each facing
	# the way it was set.
	var statue_shader = load("res://assets/shaders/statue_stone.gdshader")
	var lions = 0
	var others = 0
	var carved = true
	var on_road = 0
	var sentries = 0
	var sitting = true
	for node in world.get_children():
		if not node is Node3D or not node.has_meta("statue") or node.position.x>Overworld.TOWN_GATE.x: continue
		var figure = node.get_child(0)
		if node.get_meta("statue")=="centurion" and node.get_meta("marble"):
			# The two marble centurions stand at the palace gate, facing the town.
			if absf(node.position.z-Palace.WALL_Z)<6.0 and absf(node.position.x-Town.ARENA.x)<14.0 and is_zero_approx(node.rotation.y) and not figure.quadruped: sentries += 1
			continue
		if node.get_meta("statue")=="lion" and node.get_meta("marble"): lions += 1
		else: others += 1
		if node.position.z<Palace.WALL_Z+6.0: on_road += 1
		sitting = sitting and node.get_meta("pose")=="Sit"
		carved = carved and is_zero_approx(figure.rotation.y) and figure.quadruped
		for mesh in figure.skin_meshes:
			var m: ShaderMaterial = mesh.material_override
			carved = carved and m.shader==statue_shader and m.get_shader_parameter("pale")==1.0 and m.get_shader_parameter("body_normal").resource_path.ends_with("lion_normal.png")
	check(lions==4 and others==0 and on_road==4,"Every other statue on the palace road and at the palace is a marble lion (%d, %d of them north of the town)" % [lions,on_road])
	check(sentries==2,"Two marble centurions stand either side of the palace gate (%d)" % sentries)
	# A sitting lion's haunches are on the ground: its hips are far lower
	# than a standing one's.
	var seated = true
	for node in world.get_children():
		if node is Node3D and node.has_meta("statue") and node.get_meta("statue")=="lion":
			var figure = node.get_child(0)
			var hips: Vector3 = figure.skeleton.get_bone_global_pose(figure.skeleton.find_bone("hips")).origin
			var shoulder: Vector3 = figure.skeleton.get_bone_global_pose(figure.skeleton.find_bone("upperarm_l")).origin
			seated = seated and hips.y<.4 and shoulder.y>.75
	check(sitting and seated,"Every lion statue in the town sits on its haunches")
	check(carved,"The marble lions are the temple lion's own carving, in white")
	# The temple's guardians: the centurion's own carved stone, three times
	# life size, both looking west, away from the temple, down the road.
	var guards: Array = world.get_children().filter(func(n): return n is Node3D and n.has_meta("statue") and n.get_meta("statue")=="centurion" and not n.get_meta("marble"))
	var same_way = guards.size()==2
	var same_stone = guards.size()==2
	var centurion_stone: ShaderMaterial = Overworld.Art.statue_material(true,"warrior")
	for guard in guards:
		var looks: Vector3 = guard.global_transform.basis*guard.get_child(0).transform.basis*Vector3.BACK
		same_way = same_way and looks.normalized().distance_to(Vector3.LEFT)<.01 and guard.position.x<Overworld.TEMPLE_DOOR.x
		for mesh in guard.get_child(0).skin_meshes:
			var m: ShaderMaterial = mesh.material_override
			for parameter in ["stone_texture","scale_texture","body_normal","kit_height","body_detail","rest_pose"]:
				same_stone = same_stone and m.shader==centurion_stone.shader and m.get_shader_parameter(parameter)==centurion_stone.get_shader_parameter(parameter)
			same_stone = same_stone and m.get_shader_parameter("figure_scale")==3.0 and m.get_shader_parameter("pale")==0.0
	check(same_way,"Both temple guardians face west, away from the temple, down the road")
	check(same_stone,"They are carved in the centurions' own stone, enlarged with them")
	# On the hill the hero's figure stands on the raised ground, and a click
	# lands where it points.
	game.player.position = palace.at
	game.set_process(true)
	for i in 4: await process_frame
	game.set_process(false)
	check(is_equal_approx(game.player.position.y,0.0) and is_equal_approx(game.player.visual.position.y,Overworld.HILL_HEIGHT),"On the hill the hero's figure stands at the ground's height")
	var aim = palace.at+Vector3(4,0,3)
	var screen: Vector2 = world.camera.unproject_position(aim+Vector3.UP*world.lift(aim))
	check(world.ground_at(screen).distance_to(aim)<.2,"A click on the hill lands on the ground it points at")
	game.hud.tick(0)
	check(game.hud.prompt.text=="","Before the palace the HUD names nothing")
	game.player.position = Overworld.CARAVAN
	game.set_process(true)
	for i in 3: await process_frame
	game.set_process(false)
	check(game.player.visual.position.y==0.0,"Back on level ground he stands at its level")

	# 4. Alleys run off the ring street, with houses on both sides.
	var alleys: Array = world.places.filter(func(s): return s.kind=="alley")
	var lined = 0
	var reached = 0
	var ring: Vector2 = Town.ARENA_RADII+Vector2(Town.RING*.5,Town.RING*.5)
	for alley in Town.ALLEYS:
		var lane: Rect2 = alley
		var along_z = lane.size.y>lane.size.x
		var sides = {-1:0,1:0}
		for spot in world.places:
			if spot.kind!="house": continue
			var p = Vector2(spot.at.x,spot.at.z)
			var across = (p.x-lane.get_center().x) if along_z else (p.y-lane.get_center().y)
			var along = (p.y-lane.get_center().y) if along_z else (p.x-lane.get_center().x)
			if absf(along)<=(lane.size.y if along_z else lane.size.x)*.5+4.0 and absf(across)<16.0: sides[1 if across>0 else -1] += 1
		if sides[-1]>=2 and sides[1]>=2: lined += 1
		var middle = Vector3(lane.get_center().x,0,lane.get_center().y)
		var toward = Vector2(middle.x-Town.ARENA.x,middle.z-Town.ARENA.z).angle()
		var on_ring = Town.ARENA+Vector3(cos(toward)*ring.x,0,sin(toward)*ring.y)
		if world.fits(middle) and not world.path(on_ring,middle).is_empty(): reached += 1
	check(alleys.size()>=4 and lined==Town.ALLEYS.size() and reached==Town.ALLEYS.size(),"Alleys run off the ring street with houses on both sides (%d alleys, %d lined, %d reached)" % [alleys.size(),lined,reached])

	# 5. The town is in a poor way; the arena and the palace are kept up.
	var wears: Array = world.upkeep.houses
	var rough = wears.filter(func(w): return w>=.65).size()
	var kept = wears.filter(func(w): return w<.5).size()
	var mean = 0.0
	for w in wears: mean += w/wears.size()
	check(world.upkeep.arena<=.1 and world.upkeep.palace<=.1,"The arena and the palace are kept spotless")
	check(wears.size()>=30 and rough>=wears.size()*.6 and kept>=4 and mean>=.6,"Most houses are run down, though not all (%d of %d rough, %d kept up)" % [rough,wears.size(),kept])
	check(world.upkeep.inn>=.5 and world.upkeep.armorer>=.5 and mean-world.upkeep.palace>=.5,"The gap between the town and its rulers is wide")
	var ruins = world.places.filter(func(s): return s.name=="fallen house").size()
	check(ruins>=2,"Some houses have fallen in (%d)" % ruins)

func length_of(route: PackedVector3Array, from: Vector3) -> float:
	var total = 0.0
	var at = from
	for point in route:
		total += at.distance_to(point)
		at = point
	return total

func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/overworld-save")
	DirAccess.remove_absolute(Save.directory.path_join("run.json"))
	DirAccess.remove_absolute(Save.directory.path_join("run.backup.json"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true

	# A new character starts on the dune south of the town, by his campfire.
	var fresh = Data.new_character("warrior")
	check(fresh.place=="world" and Vector3(fresh.position[0],0,fresh.position[1])==Overworld.START and Save.valid(fresh),"A new character starts outside the temple, at the camp on the dune")
	check(Data.new_run().place=="temple","A bare run still starts on the temple's first floor")
	game.run = fresh
	game.load_floor()
	var world = game.world
	check(world is Overworld and game.outdoors() and game.mode=="playing","A run outside the temple loads the outdoor world")
	check(game.player.position==Overworld.START and world.fits(game.player.position),"The hero stands at the start, on open ground")
	check(game.enemies.is_empty() and game.boss==null and game.remaining()==0,"No statue stands outside the temple")
	var gate: Vector3 = Overworld.TOWN_GATE
	var door: Vector3 = Overworld.TEMPLE_DOOR
	var middle = (gate.x+door.x)*.5
	check(gate.x<Overworld.CARAVAN.x and Overworld.CARAVAN.x<door.x and absf(Overworld.CARAVAN.x-middle)<(door.x-gate.x)*.1,"The lost caravan lies midway between the town in the west and the temple in the east")
	# The southern desert and its dune.
	var crown: float = world.height_at(Overworld.START.x,Overworld.START.z)
	check(crown>Overworld.DUNE_HEIGHT*.95 and Overworld.DUNE_HEIGHT>=6.0 and Overworld.START.z>Town.ARENA.z+Town.ARENA_RADII.y+Town.RING+20.0 and absf(Overworld.START.x-Town.ARENA.x)<20.0,"The start is on top of a great dune south of the town (%.1f m up)" % crown)
	check(world.get_node_or_null("Dune") != null and world.height_at(Overworld.DUNE.x,Overworld.DUNE.z-Overworld.DUNE_RADII.y-1.0)==0.0 and is_equal_approx(game.player.visual.position.y,crown),"The dune's ground is drawn, and the hero stands on it")
	check(game.player.visual.resting and game.player.visual.state=="Rest" and game.run.get("resting",false) and world.get_node_or_null("CampSeat") != null,"He sits by his campfire")
	var camp: Dictionary = world.place_at(Overworld.START)
	check(not camp.is_empty() and camp.kind=="camp","The camp is a place on the dune's crown")
	var down = world.path(Overworld.START,gate+Vector3(-6,0,0))
	check(not down.is_empty() and world.region(Overworld.START)=="desert" and world.margin_at(Vector3(Overworld.DUNE.x,0,Town.ARENA.z+Town.ARENA_RADII.y+Town.RING+26.0))<0.0,"The southern desert is walled off from the town by rock, but for the way through at an alley's end")
	game.route = PackedVector3Array([Overworld.START+Vector3(0,0,3)])
	play(func(): return not game.player.visual.resting,2.0)
	check(not game.player.visual.resting and not game.run.has("resting"),"He gets up the moment he moves")
	game.player.position = Overworld.START
	game.route = PackedVector3Array()

	# The desert: about a minute's run from the town gate to the temple door.
	var from = gate+Vector3(2,0,0)
	var to = door+Vector3(-2,0,0)
	var crossing = world.path(from,to)
	var seconds = length_of(crossing,from)/game.PLAYER_RUN_SPEED
	check(not crossing.is_empty() and crossing[-1].distance_to(to)<.5,"The desert can be crossed from the town gate to the temple door")
	check(seconds>=38.0 and seconds<=48.0,"Crossing the desert takes about three quarters of a minute (%.1f s)" % seconds)
	var halfway = world.path(Overworld.CARAVAN,to)
	check(not halfway.is_empty() and absf(length_of(halfway,Overworld.CARAVAN)/game.PLAYER_RUN_SPEED-seconds*.5)<8.0,"From the caravan the temple is half the crossing away")

	# The rim: everything walkable is one connected basin, walled by rock.
	var seen = {}
	var start_cell = world.to_cell(Overworld.START)
	var queue: Array[Vector2i] = [start_cell]
	seen[start_cell] = true
	var head = 0
	var escaped = false
	var shallow = false
	while head<queue.size():
		var cell = queue[head]
		head += 1
		if cell.x<=Overworld.WEST+2 or cell.x>=Overworld.EAST-3 or cell.y<=Overworld.NORTH+2 or cell.y>=Overworld.SOUTH-3: escaped = true
		if world.margins[world.index(cell.x,cell.y)]<1.0 and not world.keep_clear[0].has_point(Vector2(cell.x,cell.y)): shallow = true
		for step in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+step
			if seen.has(next) or not world.on_map(next.x,next.y) or world.cells[world.index(next.x,next.y)]!=Overworld.OPEN: continue
			seen[next] = true
			queue.append(next)
	check(not escaped and not shallow,"No walkable ground reaches the edge of the map or passes the rim")
	var open_cells = 0
	for z in range(Overworld.NORTH,Overworld.SOUTH):
		for x in range(Overworld.WEST,Overworld.EAST):
			if world.cells[world.index(x,z)]==Overworld.OPEN: open_cells += 1
	check(seen.size()>=open_cells-40,"The open ground is one connected basin (%d of %d cells)" % [seen.size(),open_cells])
	var blocked_all_round = true
	for probe in [Vector3(0,0,-200),Vector3(0,0,200),Vector3(-400,0,0),Vector3(300,0,30),Vector3(120,0,-150),Vector3(-250,0,160)]:
		var reached: Vector3 = world.move(Overworld.CARAVAN,probe-Overworld.CARAVAN)
		blocked_all_round = blocked_all_round and world.margin_at(reached)>=.5 and reached.distance_to(probe)>20.0
	check(blocked_all_round,"Running at the rim from the start stops at it on every side")
	var rocks: int = world.rim_rocks.size()
	var near_rim = 0
	# Where the rim's rocks stand, in ten-metre squares.
	var stones: Dictionary = {}
	for at in world.rim_rocks:
		if world.margin_at(at)<3.0: near_rim += 1
		var square = Vector2i(floori(at.x/10.0),floori(at.z/10.0))
		if not stones.has(square): stones[square] = []
		stones[square].append(Vector2(at.x,at.z))
	check(rocks>=600 and near_rim==rocks,"The rim is built of rock, and only the rim (%d rocks)" % rocks)
	# Along the rim, every stretch of the edge has rock standing on it.
	var bare = 0
	var edges = 0
	for z in range(Overworld.NORTH+4,Overworld.SOUTH-4,3):
		for x in range(Overworld.WEST+4,Overworld.EAST-4,3):
			var m: float = world.margins[world.index(x,z)]
			if m>1.0 or m<-1.0 or world.keep_clear[0].grow(8.0).has_point(Vector2(x,z)): continue
			edges += 1
			var covered = false
			var square = Vector2i(floori(x/10.0),floori(z/10.0))
			for dz in range(-1,2):
				for dx in range(-1,2):
					for stone in stones.get(square+Vector2i(dx,dz),[]):
						if stone.distance_to(Vector2(x,z))<9.0: covered = true
			if not covered: bare += 1
	check(edges>200 and bare==0,"Rock stands along the whole edge of the open ground (%d of %d stretches bare)" % [bare,edges])

	# The town: an inn, two shops, houses and the arena, west of the gate.
	var kinds = {}
	var in_town = true
	for spot in world.places:
		kinds[spot.kind] = kinds.get(spot.kind,0)+1
		if spot.kind in ["inn","shop","house","arena","well"]:
			in_town = in_town and spot.at.x<gate.x and world.region(spot.at)=="town"
			if spot.kind not in ["arena","well"]: in_town = in_town and seen.has(world.to_cell(spot.at))
	check(kinds.get("inn",0)==1 and kinds.get("shop",0)==2 and kinds.get("house",0)>=3 and kinds.get("arena",0)==1,"The town has an inn, two shops, houses and an arena")
	check(in_town,"Every town building is west of the gate, with a doorstep that can be walked to")
	var sand = 0
	var arena_reached = seen.has(world.to_cell(Town.ARENA))
	var inner: Vector2 = Town.ARENA_FLOOR
	var widest = 0
	var deepest = 0
	for z in range(int(Town.ARENA.z-inner.y),int(Town.ARENA.z+inner.y)+1):
		for x in range(int(Town.ARENA.x-inner.x),int(Town.ARENA.x+inner.x)+1):
			if (Vector2(x-Town.ARENA.x,z-Town.ARENA.z)/inner).length()<.97 and world.cells[world.index(x,z)]==Overworld.OPEN: sand += 1
	for x in range(int(Town.ARENA.x-inner.x)-2,int(Town.ARENA.x+inner.x)+3):
		if world.walk_line(Town.ARENA,Vector3(x,0,Town.ARENA.z)): widest += 1
	for z in range(int(Town.ARENA.z-inner.y)-2,int(Town.ARENA.z+inner.y)+3):
		if world.walk_line(Town.ARENA,Vector3(Town.ARENA.x,0,z)): deepest += 1
	check(arena_reached and widest>=56 and deepest>=44 and sand>=2000,"The arena's sand is large enough for a crowd to fight on (%d by %d m, %d m² clear)" % [widest,deepest,sand])
	# The arena is the middle of the town: the buildings stand all round it,
	# beyond the street that rings it.
	var sides = {"north":0,"south":0,"east":0,"west":0}
	var low = Vector3(INF,0,INF)
	var high = Vector3(-INF,0,-INF)
	var clear_of_arena = true
	for spot in world.places:
		if spot.kind not in ["inn","shop","house"]: continue
		var offset: Vector3 = spot.at-Town.ARENA
		low = Vector3(minf(low.x,spot.at.x),0,minf(low.z,spot.at.z))
		high = Vector3(maxf(high.x,spot.at.x),0,maxf(high.z,spot.at.z))
		clear_of_arena = clear_of_arena and (Vector2(offset.x,offset.z)/Town.ARENA_RADII).length()>1.0
		if absf(offset.x)/Town.ARENA_RADII.x>absf(offset.z)/Town.ARENA_RADII.y: sides["east" if offset.x>0 else "west"] += 1
		else: sides["south" if offset.z>0 else "north"] += 1
	var middle_of_town = (low+high)*.5
	check(sides.north>=2 and sides.south>=2 and sides.east>=2 and sides.west>=2 and clear_of_arena,"Buildings stand on every side of the arena %s" % [sides])
	check(absf(middle_of_town.x-Town.ARENA.x)<12.0 and absf(middle_of_town.z-Town.ARENA.z)<12.0,"The arena is at the centre of the town")
	# A street runs all the way round it, and each of its four gates leads in.
	var lap = true
	var reach: Vector2 = Town.ARENA_RADII+Vector2(Town.RING*.5,Town.RING*.5)
	var previous = Town.ARENA+Vector3(reach.x,0,0)
	for i in range(1,73):
		var angle = i*TAU/72.0
		var next = Town.ARENA+Vector3(cos(angle)*reach.x,0,sin(angle)*reach.y)
		lap = lap and not world.path(previous,next).is_empty() and world.paint[world.index(roundi(next.x),roundi(next.z))*4+Overworld.PAVING]>100
		previous = next
	check(lap,"A paved street rings the arena")
	var gates = 0
	for i in Town.ARENA_GATES:
		var angle = i*TAU/Town.ARENA_BAYS
		var outside = Town.ARENA+Vector3(cos(angle)*(Town.ARENA_RADII.x+3.0),0,sin(angle)*(Town.ARENA_RADII.y+3.0))
		if world.walk_line(outside,Town.ARENA+Vector3(cos(angle)*(Town.ARENA_FLOOR.x-3.0),0,sin(angle)*(Town.ARENA_FLOOR.y-3.0))): gates += 1
	check(gates==4,"Four gates lead straight through the stands onto the sand")
	# The stands: two banks of seating raised on a wall above the sand.
	var seats = 0
	var lowest = INF
	var highest = 0.0
	var stairs_mesh = Overworld.Kit.mesh_of("stairs")
	for node in world.get_children():
		if not node is Node3D or node is MultiMeshInstance3D: continue
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh != stairs_mesh or (Vector2(node.position.x-Town.ARENA.x,node.position.z-Town.ARENA.z)/Town.ARENA_RADII).length()>1.0: continue
			seats += 1
			lowest = minf(lowest,node.position.y)
			highest = maxf(highest,node.position.y+node.scale.y)
	check(seats==(Town.ARENA_BAYS-Town.ARENA_GATES.size()-2)*2 and lowest>=2.5 and highest>=9.5,"Two raised banks of seating ring the sand (from %.1f m up to %.1f m)" % [lowest,highest])
	check(world.region(Vector3(gate.x-8,0,0))=="town" and world.region(Overworld.START)=="desert" and world.region(door+Vector3(-10,0,0))=="temple","The world names its three parts")
	check(world.walk_line(gate+Vector3(-6,0,0),gate+Vector3(6,0,0)) and not world.fits(gate+Vector3(0,0,14)),"The town wall has one open gateway")

	# The camera looks from the south-west, so the temple's west front faces it.
	world.follow(Overworld.START,1)
	check(world.camera.position.x<Overworld.START.x and world.camera.position.z>Overworld.START.z,"The camera looks from the south-west, at the temple's front")
	game.hud.tick(0)
	check(game.hud.objective.text=="" and game.hud.status.text=="" and "east" in game.hud.direction.text and game.hud.prompt.text=="","Outdoors the HUD names no place, and points to the temple and the town")
	game.player.position = Vector3(Town.MARKET.get_center().x,0,Town.MARKET.get_center().y+5.0)
	game.hud.tick(0)
	check(game.hud.objective.text=="" and game.hud.status.text=="","Nor is the town named")
	var inn: Dictionary = world.places.filter(func(s): return s.kind=="inn")[0]
	game.player.position = inn.at
	game.hud.tick(0)
	check(game.hud.prompt.text=="" and game.hud.status.text=="","Nor the inn at its door")

	# The inn and the smithy stand open, and are furnished inside.
	var Interiors = load("res://scripts/world_interiors.gd")
	check(world.rooms.size()==2 and world.rooms.all(func(room): return world.fits(room.door) and room.area.grow(2.0).has_point(Vector2(room.door.x,room.door.z))),"The inn and the smithy each have an open doorway")
	var common = Interiors.INN+Vector3(8.0,0,12.0)
	var forge_floor = Interiors.SMITHY+Vector3(8.0,0,8.0)
	check(world.fits(common) and not world.path(world.rooms[0].door,common).is_empty() and world.fits(forge_floor) and not world.path(world.rooms[1].door,forge_floor).is_empty(),"The hero can walk in through each door")
	world.follow(common,1)
	var inn_screens = world.screens.filter(func(g): return g.get("room") == world.rooms[0])
	check(world.rooms[0].inside and not world.rooms[0].roof.visible and world.rooms[0].front.size()>=10 and world.rooms[0].front.all(func(node): return not node.visible) and world.rooms[1].roof.visible and world.rooms[1].front.all(func(node): return node.visible),"Inside the inn its roof and near walls are lifted away, and only its own")
	check(not inn_screens.is_empty() and inn_screens.all(func(g): return not g.hidden),"Its far walls stand as they are")
	world.follow(world.rooms[0].door+Vector3(0,0,3.0),1)
	check(not world.rooms[0].inside and world.rooms[0].roof.visible and world.rooms[0].front.all(func(node): return node.visible),"Outside again, it is whole")
	var loft = Interiors.INN+Vector3(10.0,0,5.4)
	var stair_foot = Interiors.INN+Vector3(18.0,0,12.9)
	var stair_middle = Interiors.INN+Vector3(18.0,0,9.75)
	check(world.fits(loft) and is_equal_approx(world.lift(loft),Interiors.LOFT) and is_zero_approx(world.lift(common)) and is_zero_approx(world.lift(stair_foot)),"The inn's loft stands a storey above its floor")
	check(absf(world.lift(stair_middle)-Interiors.LOFT*.5)<.1 and not world.path(common,loft).is_empty(),"A stair climbs to it (%.2f m up half way)" % world.lift(stair_middle))
	var furniture = {}
	for node in world.get_children():
		if node is Node3D and node.scene_file_path != "" and world.rooms.any(func(room): return room.area.has_point(Vector2(node.position.x,node.position.z))):
			var id = node.scene_file_path.get_file().get_basename()
			furniture[id] = furniture.get(id,0)+1
	check(furniture.get("table",0)>=2 and furniture.get("table_long",0)>=2 and furniture.get("stool",0)>=8 and furniture.get("bed",0)>=3,"The inn has tables, a bar and beds (%s)" % str(furniture))
	var beds_upstairs = world.get_children().filter(func(node): return node is Node3D and node.scene_file_path.get_file().get_basename()=="bed" and absf(node.position.y-Interiors.LOFT)<.05).size()
	check(beds_upstairs>=3,"Its beds are upstairs (%d)" % beds_upstairs)
	var arms = 0
	for id in ["sword","sword_long","axe","hand_axe","axe_bronze","shield","shield_round","scutum","pickaxe"]: arms += furniture.get(id,0)
	check(furniture.get("anvil_log",0)+furniture.get("anvil",0)>=3 and furniture.get("workbench",0)>=2 and furniture.get("whetstone",0)==1 and arms>=20,"The smithy has its anvils, benches, a grindstone and arms hung all about (%d)" % arms)
	var fires = world.get_children().filter(func(node): return node.name.begins_with("AnimatedTorchFlame") and world.rooms[1].area.has_point(Vector2(node.position.x,node.position.z))).size()
	check(fires==1,"A fire burns in its forge")

	# The town's people.
	var folk = world.townsfolk
	check(folk.people.size()==25 and folk.children.size()==6 and folk.anya != null and folk.anya.body.name=="Anya","Twenty-five townspeople, six children and Anya the innkeeper are about")
	var anya_look: Dictionary = folk.anya.body.look
	check(anya_look.who=="woman" and anya_look.garment=="Dress" and anya_look.under=="Blouse" and anya_look.braid and anya_look.hair_colour.r<.1 and anya_look.cloth.r>anya_look.cloth.b*1.8 and anya_look.under_cloth.r>.85,"Anya: a young woman, dark hair in a braid, a white blouse under a brown dress")
	var ragged = folk.people.filter(func(w): return w.body.look.wear>=.8).size()
	var neat = folk.people.filter(func(w): return w.body.look.wear<=.3).size()
	var orion_look: Dictionary = folk.orion.body.look
	check(folk.orion.body.name=="Orion" and orion_look.hair=="" and orion_look.beard and orion_look.hair_colour.r<.08 and orion_look.bulk>=1.0 and orion_look.garment=="Sack" and orion_look.cloth.r>orion_look.cloth.b*2.0,"Orion the blacksmith: bald, black-bearded, heavy, in a sleeveless brown tunic")
	check(ragged>=9 and neat>=5 and folk.children.all(func(c): return c.body.look.wear>=.75 and c.body.look.size<.7),"Many are in rags, some decently dressed; the children are poor and small")
	# Three minutes of town life, by day (a new character wakes in the night).
	world.set_time(Daylight.MORNING+400.0)
	var least = 99
	var most = 0
	var served = 0
	var chats = 0
	var strayed = 0
	var kids_in = 0
	var walled = 0
	var was = {}
	for step in 3600:
		folk.tick(.05,Overworld.START)
		var n: int = folk.patrons()
		least = mini(least,n)
		most = maxi(most,n)
		for w in folk.people:
			if w.state=="drink" and not was.get(w.body.name,false): served += 1
			was[w.body.name] = w.state=="drink"
			if w.state=="chat" and not was.get(w.body.name+"c",false): chats += 1
			was[w.body.name+"c"] = w.state=="chat"
		for w in folk.people+folk.children:
			var a = Vector2((w.at.x-Town.ARENA.x)/Town.ARENA_RADII.x,(w.at.z-Town.ARENA.z)/Town.ARENA_RADII.y)
			if a.length()<1.0 or w.at.z<-77 or w.at.x>Overworld.TOWN_GATE.x: strayed += 1
			if step%20==0 and not w.state in ["sit_down","wait","drink","stand_up"] and not folk.open_at(w.at): walled += 1
		for c in folk.children:
			if folk.inside(c): kids_in += 1
	check(least>=3 and most<=8,"Between three and eight are in the inn at every moment (%d to %d)" % [least,most])
	check(served>=6,"Anya has served drinks to those at the tables (%d)" % served)
	check(chats>=2,"Townspeople who pass stop to talk (%d chats)" % (chats/2))
	# Orion's day: he takes a sword down from the wall and beats it on the
	# anvil, works the forge's coals, and grinds the sword on the turning stone.
	var smith = folk.smith
	var tasks = {}
	var held = {}
	var blade_low = INF
	var head_low = INF
	var turned = 0.0
	var wheel_was: Basis = smith.wheel.basis
	var anvil_top: float = smith.places.face.y
	for step in 3600:
		folk.tick(.05,Overworld.START)
		if smith.plan.is_empty(): continue
		var doing: Dictionary = smith.plan[0]
		if not doing.has("work"): continue
		tasks[doing.work] = true
		for side in smith.hands: held[doing.work+":"+side] = smith.hands[side].tool
		if doing.work == "hammer":
			for m in smith.tools.sword.node.find_children("*","MeshInstance3D",true,false): blade_low = minf(blade_low,(m.global_transform*m.get_aabb()).position.y)
			for m in smith.tools.hammer.node.find_children("*","MeshInstance3D",true,false):
				if m.get_parent().position.y > .2: head_low = minf(head_low,(m.global_transform*m.get_aabb()).position.y)
		if doing.work == "grind":
			turned += wheel_was.x.normalized().angle_to(smith.wheel.basis.x.normalized())
			wheel_was = smith.wheel.basis
	check(tasks.has("hammer") and tasks.has("grind") and tasks.has("stoke") and world.rooms[1].area.has_point(Vector2(folk.orion.at.x,folk.orion.at.z)),"Orion goes between the anvil, the grindstone and the forge, and stays in his smithy (%s)" % str(tasks.keys()))
	check(held.get("hammer:l","")=="sword" and held.get("hammer:r","")=="hammer" and held.get("grind:r","")=="sword" and held.get("stoke:r","")=="rod","He holds the sword he took down in his left hand and the hammer in his right at the anvil, the sword in his right at the grindstone, the rod at the forge (%s)" % str(held))
	check(absf(blade_low-anvil_top)<.004,"The sword lies on the anvil's face, not in it (%.3fm above)" % (blade_low-anvil_top))
	check(absf(head_low-(anvil_top+smith.SWORD.z))<.012,"The hammer's face comes down onto the blade, and no further (%.3fm above it)" % (head_low-anvil_top-smith.SWORD.z))
	check(turned>20.0,"The grindstone turns while he grinds (%.0f radians)" % turned)
	# His tools are their own size in his hand, not stretched with his broad
	# figure: the hammer a forearm long, the blade and the rod about a metre.
	var tool_sizes = {}
	for tool in smith.tools:
		var longest = 0.0
		for m in smith.tools[tool].node.find_children("*","MeshInstance3D",true,false):
			var box: AABB = m.global_transform*m.get_aabb()
			longest = maxf(longest,maxf(box.size.x,maxf(box.size.y,box.size.z)))
		tool_sizes[tool] = snappedf(longest,.01)
		check(smith.tools[tool].node.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Orion's tool is unskewed: "+tool)
	check(tool_sizes.hammer < .5 and tool_sizes.sword < 1.0 and tool_sizes.rod < 1.15,"Orion's hammer, blade and rod are true to size (%s)" % str(tool_sizes))
	check(folk.orion.body.look.has("shoes") and folk.orion.body.figure.position.y > .05,"Orion wears shoes, and stands on the smithy's tiles rather than in them")
	check(strayed==0 and kids_in==0 and walled==0,"No one enters the arena, the palace hill or the desert; the children keep out of the inn; none walk through walls (%d, %d, %d)" % [strayed,kids_in,walled])

	# Night: everyone goes to bed through the evening, and gets up again
	# through the sunrise.
	var everyone: Array = folk.people+folk.children+[folk.anya,folk.orion]
	var beds_by_kind = {}
	for w in everyone: beds_by_kind[w.bed.kind] = beds_by_kind.get(w.bed.kind,0)+1
	check(beds_by_kind.get("inn",0)==4 and beds_by_kind.get("ground",0)>=10 and beds_by_kind.get("house",0)>=10 and folk.anya.bed.kind=="kitchen" and folk.orion.bed.kind=="house","Four lodge in the inn's loft, those in rags sleep on the ground, the rest at home; Anya in her kitchen (%s)" % str(beds_by_kind))
	var house_doors = {}
	for w in everyone:
		if w.bed.kind=="house": house_doors[snapped(w.bed.at,Vector3.ONE*.1)] = true
	check(house_doors.size()==beds_by_kind.get("house",0),"No two share a house's door")
	var houses = world.places.filter(func(p): return p.kind=="house" and p.name=="house")
	var orion_home = houses[0]
	for p in houses:
		if p.at.distance_to(world.rooms[1].door)<orion_home.at.distance_to(world.rooms[1].door): orion_home = p
	check(folk.orion.bed.way[0].distance_to(orion_home.at)<1.5,"Orion's house is the one orion_home his smithy")
	var anya_bed = world.get_children().filter(func(n): return n is Node3D and n.scene_file_path.get_file().get_basename()=="bed" and Vector2(n.position.x,n.position.z).distance_to(Vector2(folk.anya.bed.at.x,folk.anya.bed.at.z))<.6)
	check(anya_bed.size()==1 and absf(anya_bed[0].position.y)<.05 and folk.kitchen.has_point(Vector2(anya_bed[0].position.x,anya_bed[0].position.z)),"Anya's bed stands in the kitchen behind the bar, on its floor")
	# The evening, minute by minute.
	var t: float = Daylight.SUNSET+20.0
	world.set_time(t)
	folk.tick(.1,Overworld.START)
	check(everyone.all(func(w): return not w.state in folk.ABED and w.body.visible),"Before the evening all are up")
	var climbed = false
	while t < Daylight.NIGHT+260.0:
		t += .1
		world.set_time(t)
		folk.tick(.1,Overworld.START)
		for w in folk.people:
			if w.climbs and w.state=="to_bed" and w.at.y>1.0 and w.at.y<Interiors.LOFT-.5: climbed = true
	var asleep = everyone.filter(func(w): return w.state in ["asleep","indoors"])
	for w in everyone:
		if not w.state in ["asleep","indoors"]: print("AWAKE ",w.body.name," ",w.state," ",w.at," ",w.route.size())
	check(asleep.size()==everyone.size(),"By the middle of the night everyone is in bed (%d of %d)" % [asleep.size(),everyone.size()])
	check(climbed,"The lodgers climb the inn's stair to the loft")
	var on_beds = 0
	for w in folk.people:
		if w.bed.kind!="inn" or w.state!="asleep": continue
		var bed = world.get_children().filter(func(n): return n is Node3D and n.scene_file_path.get_file().get_basename()=="bed" and absf(n.position.y-Interiors.LOFT)<.05 and Vector2(n.position.x,n.position.z).distance_to(Vector2(w.at.x,w.at.z))<.6)
		if bed.size()==1 and absf(w.at.y-Interiors.LOFT-folk.MATTRESS)<.01 and w.body.state=="Lie": on_beds += 1
	check(on_beds==4,"Each lodger lies on a bed of his own in the loft (%d)" % on_beds)
	check(folk.anya.state=="asleep" and folk.anya.at.distance_to(folk.anya.bed.at)<.01 and folk.anya.body.state=="Lie","Anya lies asleep in her bed in the kitchen")
	check(folk.orion.state=="indoors" and not folk.orion.body.visible and folk.orion.at.distance_to(folk.orion.bed.at)<.01 and folk.smith.tools.values().all(func(tool): return tool.hand==""),"Orion has put his tools away and gone into his house")
	var grounded = everyone.filter(func(w): return w.bed.kind=="ground")
	check(grounded.all(func(w): return w.state=="asleep" and w.body.visible and w.body.state=="Lie" and absf(w.at.y)<.01 and folk.open_at(w.at)),"The homeless lie asleep on the ground in the open street")
	check(folk.people.all(func(w): return not w.state in ["sit_down","wait","drink","stand_up"]) and folk.seats.all(func(seat): return seat.taken==null),"The inn's tables are empty")
	check(folk.named_at(folk.anya.at).is_empty() and folk.named_at(folk.orion.at).is_empty(),"Neither is named while out of sight")
	# Through the sunrise to the morning.
	t = Daylight.CYCLE-2.0
	world.set_time(t)
	folk.tick(.1,Overworld.START)
	while t < Daylight.CYCLE+Daylight.SUNRISE+60.0:
		t += .1
		world.set_time(t)
		folk.tick(.1,Overworld.START)
	for w in everyone:
		if w.state in folk.ABED: print("ABED ",w.body.name," ",w.state," ",w.at," ",w.route.size())
	check(everyone.all(func(w): return not w.state in folk.ABED and w.body.visible),"By morning all are up and about again")
	check(folk.anya.state in ["post","to_tap","fill","carry","place","return"] and folk.inn.has_point(Vector2(folk.anya.at.x,folk.anya.at.z)) and not folk.kitchen.has_point(Vector2(folk.anya.at.x,folk.anya.at.z)),"Anya is back behind her bar")
	check(folk.orion.state=="work" and not folk.smith.plan.is_empty(),"Orion is back at his work")
	check(folk.people.all(func(w): return absf(w.at.y)<.01),"The lodgers are down from the loft")
	# The hour jumped: at once where it has them.
	world.set_time(Daylight.NIGHT+300.0)
	folk.tick(.1,Overworld.START)
	check(everyone.all(func(w): return w.state in ["asleep","indoors"]) and folk.orion.at.distance_to(folk.orion.bed.at)<.01,"Hurried on to the night, all are at once in bed, Orion in the same house")
	world.set_time(Daylight.MORNING+400.0)
	folk.tick(.1,Overworld.START)
	check(everyone.all(func(w): return not w.state in folk.ABED and w.body.visible) and folk.patrons()>=3,"And on to the morning, all are up, and some at the inn's tables")

	# The save keeps the hero's place in the world.
	game.player.position = Vector3(-40,0,12)
	game.save_run()
	var stored = Save.load_run()
	check(not stored.is_empty() and stored.place=="world" and is_equal_approx(stored.position[0],-40.0) and is_equal_approx(stored.position[1],12.0),"A save made outdoors keeps the hero's place in the world")
	game.run = stored
	game.load_floor()
	world = game.world
	check(world is Overworld and game.player.position.distance_to(Vector3(-40,0,12))<.01,"Continuing a save made outdoors returns there")

	# The temple's door: walking in begins the ascent on the first floor.
	game.hud.tick(0)
	game.player.position = door+Vector3(-3,0,0)
	game.hud.tick(0)
	check(not Data.temple_open(game.run) and "shut" in game.hud.prompt.text,"Until both dungeons are cleared the HUD says the temple's door is shut")
	game.route = PackedVector3Array([door+Vector3(4,0,0)])
	check(not play(func(): return not game.outdoors(),3.0) and world.entrance(game.player.position)=="temple","Walking at the shut door does not enter the temple")
	game.run.cleared = Data.DUNGEONS.duplicate()
	game.route = PackedVector3Array()
	game.player.position = door+Vector3(-3,0,0)
	game.hud.tick(0)
	check("Walk in" in game.hud.prompt.text,"With the dungeons cleared the HUD says to walk in")
	# A dull amber light comes from the door, the colour of the fires and the
	# desert, in place of a black floor.
	var ember = world.get_node_or_null("TempleDoorGlow")
	var lit_floor = world.get_node_or_null("TempleDoorGlowFloor")
	var door_light = world.get_node_or_null("TempleDoorLight")
	var amber = ember != null and lit_floor != null and door_light != null and world.get_node_or_null("TempleDoorGlowSpill") != null
	if amber:
		var colour: Color = ember.find_children("*","MeshInstance3D",true,false)[0].material_override.albedo_color
		# Orange to yellow: red over green over blue, the green well up, and dull.
		for c in [colour,world.GLOW_COLOUR]:
			amber = amber and c.r>c.g and c.g>c.b*2.0 and c.g>c.r*.45 and c.g<c.r*.8 and c.r<.9
		# Near the torches' own light (Color(1,.60,.28)).
		amber = amber and door_light.light_color.is_equal_approx(Color(1,.60,.28))
		amber = amber and lit_floor.position.x>door.x-3.0 and lit_floor.texture.gradient.colors[0].a==0.0 and lit_floor.texture.gradient.colors[-1].a>.9
	var black = false
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		var m = mesh.material_override
		if m is StandardMaterial3D and m.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and m.albedo_color.get_luminance()<.03 and mesh.global_position.distance_to(door)<12.0: black = true
	check(amber and not black and world.get_node_or_null("TempleDoorDark")==null,"A dull amber light, like the fires', glows from the temple's door, with no black floor")
	check(not world.entering_temple(game.player.position) and world.walk_line(game.player.position,door+Vector3(2,0,0)),"The doorway is open to walk into")
	game.route = PackedVector3Array([door+Vector3(4,0,0)])
	var entered = play(func(): return not game.outdoors(),6.0)
	world = game.world
	check(entered and world is Temple and game.run.floor==0 and game.run.place=="temple","Walking through the temple's door loads its first floor")
	var layout = world.layout
	check(layout.entry.has_area() and game.player.position.distance_to(layout.entry_position())<.01 and world.fits(game.player.position) and not world.leaving_temple(game.player.position),"The hero arrives just inside the door")
	check(game.enemies.size()>0 and game.remaining()>0,"The first floor's statues wait inside")
	var clear_of_door = true
	for enemy in game.enemies: clear_of_door = clear_of_door and not layout.entry.grow(3).has_point(layout.to_cell(enemy.position))
	check(clear_of_door,"No statue stands in the doorway")
	check(world.get_node_or_null("TempleDoor") != null and world.get_node_or_null("TempleDoorDaylight") != null,"The first floor shows the door and the daylight beyond it")
	# What is done inside stays done while the hero steps out and back.
	var slain = game.enemies[0]
	slain.die()
	var slain_id: String = slain.uid
	var passage = layout.to_world(layout.entry.position)+Vector3(layout.entry.size.x-1,0,layout.entry.size.y-1)*.5
	game.target = null
	game.route = PackedVector3Array([passage+Vector3(layout.entry_dir.x,0,layout.entry_dir.y)*.7])
	var left = play(func(): return game.outdoors(),8.0)
	world = game.world
	check(left and world is Overworld and game.run.place=="world" and game.run.floor==0,"Walking back out through the door returns to the desert")
	check(game.player.position.distance_to(door+Overworld.THRESHOLD)<.01 and not world.entering_temple(game.player.position),"The hero steps out in front of the temple, clear of the door")
	check(Save.load_run().place=="world","Leaving the temple is saved")
	game.route = PackedVector3Array([door+Vector3(4,0,0)])
	play(func(): return not game.outdoors(),6.0)
	var still_dead = false
	for enemy in game.enemies:
		if enemy.uid==slain_id: still_dead = enemy.dead
	check(not game.outdoors() and still_dead and slain_id in game.run.dead,"A statue slain before leaving is still slain on returning")

	# Only the first floor has the door, and every first floor has one.
	var doors = true
	var doorless = true
	for sample in 40:
		var run_seed: int = [0,1,42,123,12345,0x7fffffff,0xffffffff][sample] if sample<7 else Layout.floor_seed(sample,6)
		for floor_index in Data.FLOORS:
			var plan = Layout.new()
			plan.generate(run_seed,floor_index)
			if floor_index==0:
				var ok = plan.entry.has_area() and plan.cells.has(plan.to_cell(plan.entry_position()))
				for y in range(plan.entry.position.y,plan.entry.end.y):
					for x in range(plan.entry.position.x,plan.entry.end.x): ok = ok and plan.cells.has(Vector2i(x,y))
				# Beyond the door there is solid wall, never another room.
				for y in range(plan.entry.position.y,plan.entry.end.y):
					for x in range(plan.entry.position.x,plan.entry.end.x):
						var cell = Vector2i(x,y)
						if plan.at_door(cell): ok = ok and not plan.is_open(cell+plan.entry_dir)
				doors = doors and ok
			else: doorless = doorless and not plan.entry.has_area()
	check(doors,"Every first floor has its door, at the end of a passage through solid wall")
	check(doorless,"No other floor has a door to the outside")

	await town_checks()

	# Saves from before the outdoor world were made inside the temple.
	var old = Data.new_run("ranger")
	old.version = 6
	old.erase("place")
	old.floor = 2
	var moved = Save.migrate(old)
	check(Save.valid(old) and moved.version==Data.new_run().version and moved.place=="temple" and moved.floor==1 and Data.temple_open(moved),"Earlier saves continue inside the temple, on the floor their old one became")
	var nowhere = Data.new_run(); nowhere.place = "moon"
	check(not Save.valid(nowhere),"A save in an unknown place is rejected")

	# With a window (-- --render-world), photograph the world for review.
	if "--render-world" in OS.get_cmdline_user_args():
		game.run = Data.new_character("warrior")
		game.load_floor()
		game.set_process(true)
		root.size = Vector2i(1440,900)
		var views = [["world-start",Overworld.START,19.0],["world-desert",Vector3(4,0,-22),36.0],["world-oasis",Vector3(-84,0,36),26.0],["world-gate",Overworld.TOWN_GATE+Vector3(-10,0,2),26.0],["world-town",Vector3(Town.MARKET.get_center().x-8.0,0,Town.MARKET.get_center().y-6.0),30.0],["world-street",Town.ARENA+Vector3(-22,0,-Town.ARENA_RADII.y-9.0),26.0],["world-box",Town.ARENA+Vector3(3,0,-24),17.0],["world-alley",Vector3(-296,0,-58),24.0],["world-palace-road",Vector3(-254,0,-72),36.0],["world-palace",Vector3(-254,0,-97),36.0],["world-lion",Vector3(-262,0,-70),13.0],["world-arena",Town.ARENA,36.0],["world-arena-gate",Town.ARENA+Vector3(Town.ARENA_RADII.x+7.0,0,2),26.0],["world-rim",Vector3(-30,0,56),30.0],["world-temple",Overworld.TEMPLE_DOOR+Vector3(-9,0,0),32.0]]
		for view in views:
			game.player.position = view[1]
			game.route.clear()
			game.world.zoom = view[2]
			for i in 30: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/%s.png" % view[0])
	print("OVERWORLD ",passed," passed; ",failed)
	quit(0 if failed.is_empty() else 1)
