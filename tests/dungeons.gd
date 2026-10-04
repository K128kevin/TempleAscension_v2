extends SceneTree
## The two dungeons fought through before the temple: the basement under the
## arena and the bandits' cave. Their layouts, their bandits, the stairs down
## and back up, and the temple's door staying shut until both are cleared.
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
const Layout = preload("res://scripts/layout.gd")
const Temple = preload("res://scripts/temple.gd")
const Overworld = preload("res://scripts/overworld.gd")
const Town = preload("res://scripts/world_town.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var game
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func reachable(layout) -> Dictionary:
	var seen = {layout.start:true}
	var queue: Array[Vector2i] = [layout.start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for d in Layout.DIRS:
			var next: Vector2i = p+d
			if layout.cells.has(next) and not seen.has(next):
				seen[next] = true; queue.append(next)
	return seen
func play(done: Callable, seconds: float) -> bool:
	var left = seconds
	while left>0:
		if done.call(): return true
		game._process(.05)
		left -= .05
	return done.call()
func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/dungeons-save")
	# The layouts: two levels each, gone down into.
	var signatures: Dictionary = {}
	for place in Data.DUNGEONS:
		check(Data.AREAS[place].size()==2 and Layout.KINDS[place].minutes.size()==2,"Two levels: "+place)
		for sample in 12:
			var run_seed: int = [0,1,42,123,12345,0x7fffffff][sample] if sample<6 else Layout.floor_seed(sample,6)
			for level in 2:
				var layout = Layout.new()
				layout.generate(run_seed,level,place)
				var label = "%s level %d / seed %d" % [place,level+1,run_seed]
				check(reachable(layout).size()==layout.cells.size() and layout.rooms.size()>=5,"Every tile of several rooms is connected: "+label)
				check(layout.descending and layout.corridor==Layout.KINDS[place].corridor and layout.court.size==Vector2i.ZERO and layout.terrace.is_empty(),"A dungeon's own hallways, with no court or terrace: "+label)
				check(layout.entry.has_area()==(level==0) and layout.arrival.has_area()==(level==1),"The way in is a door on the first level and a stair on the second: "+label)
				check(layout.stairs.has_area()==(level==0) and layout.last==(level==1),"Only the first level has a stair further down: "+label)
				if level==1: check(layout.cells.has(layout.arrival_foot) and not layout.arrival.has_point(layout.arrival_foot),"The stair back up is reached from the floor at its foot: "+label)
				var copy = Layout.new(); copy.generate(run_seed,level,place)
				check(copy.cells==layout.cells and copy.start==layout.start,"Deterministic: "+label)
				var signature = hash(layout.cells)
				check(not signatures.has(signature),"Unlike any other level: "+label)
				signatures[signature] = true
			var temple_plan = Layout.new(); temple_plan.generate(run_seed,0)
			check(not signatures.has(hash(temple_plan.cells)),"Unlike the temple's floor of the same seed: %s / %d" % [place,run_seed])
	# The bandits.
	for kind in ["bandit","bandit_archer"]:
		var config: Dictionary = Data.ENEMIES[kind]
		check(config.has("human") and config.as in ["gladiator","archer"] and Data.enemy_xp(Data.new_run(),kind)>0,"A bandit is a man who fights as a guardian does: "+kind)
	for place in Data.DUNGEONS:
		for area in Data.AREAS[place]:
			check(area.counts.keys()==["bandit","bandit_archer"] and area.counts.bandit>area.counts.bandit_archer,"The dungeons hold bandits with swords and with bows: "+place)
	check(Data.AREAS.temple[0].counts.keys()==["gladiator","archer"],"The temple's first floor holds only gladiators and archers")
	check(Data.AREAS.temple[1].counts.has("lion") and Data.AREAS.temple[1].counts.has("wizard") and not Data.AREAS.temple[1].counts.has("centurion"),"Its second adds lions and Oracles")
	check(Data.AREAS.temple[2].counts.has("centurion") and Data.AREAS.temple.size()==Data.FLOORS and Data.AREAS.temple[3].counts.is_empty(),"Its third adds centurions, under the summit")
	var rising = true
	var before = 0
	for place in ["basement","cave","temple"]:
		for area in Data.AREAS[place]:
			rising = rising and area.level>before
			before = area.level
	check(rising,"Every floor of the campaign is stronger than the one before")

	# The campaign: from the camp, down under the arena.
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior"); game.run.seed = 4242
	game.load_floor()
	var world = game.world
	check(world is Overworld and not Data.temple_open(game.run) and game.run.cleared.is_empty(),"A new character has cleared nothing: the temple is shut")
	for target in [["the basement stair",Overworld.BASEMENT_STAIR,"basement"],["the cave's mouth",Overworld.CAVE+Vector3(0,0,2),"cave"]]:
		var route = world.path(Overworld.START,target[1])
		check(not route.is_empty() and route[-1].distance_to(target[1])<1.0 and world.entrance(target[1])==target[2],"From the camp there is a way to "+target[0])
	for place in Overworld.OUTSIDE:
		var spot: Dictionary = Overworld.OUTSIDE[place]
		check(world.fits(spot.at) and world.entrance(spot.at)=="","Coming out of the %s he stands clear of its entrance" % place)
	check(world.CAVE.z<-60.0 and world.CAVE.x>Overworld.CARAVAN.x and world.CAVE.x<Overworld.TEMPLE_DOOR.x-30.0,"The cave is in the desert's northern rocks, before the temple")
	# Under the stands.
	check(Town.under_stands(Overworld.BASEMENT_STAIR) and not Town.under_stands(Town.ARENA) and not Town.under_stands(Town.ARENA+Vector3(Town.ARENA_RADII.x+3.0,0,0)),"The stair stands under the arena's stands, between its outer wall and the sand")
	check(not world.stand_seats.is_empty() and world.stand_seats.all(func(n): return n.visible) and world.stand_fittings.all(func(n): return not n.visible),"From outside the seats are seen, and what is under them is not")
	world.follow(Overworld.OUTSIDE.basement.at,1)
	check(world.stand_seats.all(func(n): return not n.visible) and not world.stand_fittings.is_empty() and world.stand_fittings.all(func(n): return n.visible),"Under the stands the seats overhead are lifted away")
	var lifted = func(n): return n.find_children("*","GeometryInstance3D",true,false).all(func(m): return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	check(not world.stand_front.is_empty() and world.stand_front.all(lifted),"Under the stands he is indoors: the outer wall on the camera's side is lifted away, its shadow kept")
	check(world.stand_front.any(func(n): return n.position.z>Town.ARENA.z+Town.ARENA_RADII.y-3.0) and not world.stand_front.any(func(n): return n.position.z<Town.ARENA.z-Town.ARENA_RADII.y*.5 and n.position.x>Town.ARENA.x),"It is the southern side that is lifted, not the far north-east")
	var east_gate = Town.ARENA+Vector3(Town.ARENA_RADII.x+2.0,0,0)
	var inside = world.path(east_gate,Overworld.BASEMENT_STAIR)
	var under = false
	for point in inside: under = under or Town.under_stands(point)
	check(not inside.is_empty() and under and inside.size()<90,"A doorway in the gateway lets into the space under the stands")
	world.follow(Overworld.START,1)
	check(world.stand_front.all(func(n): return not lifted.call(n)) and world.stand_seats.all(func(n): return n.visible),"Out from under the stands the arena's walls stand whole again")
	game.player.position = Overworld.BASEMENT_STAIR+Vector3(1.0,0,1.0)
	game.hud.tick(0)
	check("beneath the arena" in game.hud.prompt.text,"At the stair the HUD says where it leads")
	game.player.position = Overworld.BASEMENT_STAIR
	check(game.pass_door() and game.run.place=="basement" and game.run.floor==0 and game.world is Temple,"Walking onto the stair goes down to the basement's first level")
	world = game.world
	var expected = 0
	for count in Data.AREAS.basement[0].counts.values(): expected += count
	check(game.enemies.size()==expected and game.remaining()==expected and game.enemies.all(func(e): return e.human and e.kind.begins_with("bandit") and e.uid.begins_with("basement:0:")),"Its bandits wait there")
	check(game.enemies.all(func(e): return not e.visual.is_stone and e.role in ["gladiator","archer"]),"They are men, not statues")
	check(game.player.position.distance_to(world.layout.entry_position())<.01 and not world.leaving_temple(game.player.position),"He arrives just inside the way in")
	game.hud.tick(0)
	check("bandits remain" in game.hud.status.text and game.hud.objective.text=="LEVEL 1","The HUD counts bandits, on a numbered level with no place name")
	check(not game.has_way_on() or not world.exit_seal.visible,"The way down is shut while bandits remain")
	# A bandit fights, and falls.
	var bandit = game.enemies.filter(func(e): return e.kind=="bandit")[0]
	game.player.position = bandit.position+Vector3(0,0,1.4)
	var hp: float = game.player.hp
	for i in 120:
		bandit.tick(1.0/60); game.tick_scheduled(1.0/60)
	check(bandit.awake and game.player.hp<hp,"A bandit swordsman attacks the hero")
	var xp: int = game.run.xp
	bandit.hit(10000)
	check(bandit.dead and bandit.visual.state=="Death" and game.run.xp>xp and bandit.uid in game.run.dead,"He falls, and is worth experience")
	game.player.hp = game.player.max_hp
	for enemy in game.enemies:
		if not enemy.dead: enemy.hit(100000)
	check(game.remaining()==0 and world.exit_seal.visible and game.has_way_on() and game.run.cleared.is_empty(),"With the level cleared the way down opens")
	game.player.position = world.exit_point
	game.hud.tick(0)
	check("descend" in game.hud.prompt.text,"The HUD says to descend")
	game.interact()
	world = game.world
	check(game.run.place=="basement" and game.run.floor==1 and world.layout.last and not game.has_way_on(),"The stair goes down to the second, last level")
	check(game.enemies.all(func(e): return e.uid.begins_with("basement:1:")) and game.remaining()>expected,"More bandits wait below")
	# Back up, and down again: what was done stays done.
	game.player.position = world.layout.arrival_position()
	check(world.fits(game.player.position),"The foot of the stair back up can be stood at")
	game.interact()
	world = game.world
	check(game.run.floor==0 and game.remaining()==0 and game.player.position.distance_to(world.exit_point)<.01,"The stair leads back up to the cleared level, at the head of the stair")
	game.interact()
	world = game.world
	check(game.run.floor==1 and game.remaining()>0,"And down again")
	for enemy in game.enemies:
		if not enemy.dead: enemy.hit(100000)
	check(game.remaining()==0 and game.run.cleared==["basement"] and not Data.temple_open(game.run) and not world.exit_seal.visible,"Clearing the last level clears the dungeon; the temple stays shut for the cave")
	check(Save.valid(game.run),"The run is valid to save")
	# Out again.
	game.player.position = world.layout.arrival_position()
	game.interact()
	world = game.world
	game.target = null
	var layout = world.layout
	var passage = layout.to_world(layout.entry.position)+Vector3(layout.entry.size.x-1,0,layout.entry.size.y-1)*.5
	game.player.position = layout.entry_position()
	game.route = PackedVector3Array([passage+Vector3(layout.entry_dir.x,0,layout.entry_dir.y)*.7])
	var left = play(func(): return game.outdoors(),8.0)
	check(left and game.run.place=="world" and game.player.position.distance_to(Overworld.OUTSIDE.basement.at)<.01,"Walking out comes up under the stands, by the stair")
	# The cave.
	game.player.position = Overworld.CAVE+Vector3(0,0,2)
	check(game.pass_door() and game.run.place=="cave" and game.run.floor==0 and game.world.layout.kind=="cave","Walking into the cave's mouth enters its first level")
	check(game.enemies.all(func(e): return e.uid.begins_with("cave:0:") and not e.dead) and "basement:0:0" in game.run.dead,"Its bandits are its own; the basement's dead are remembered")
	var archer = game.enemies.filter(func(e): return e.kind=="bandit_archer")[0]
	check(archer.visual.weapon_kind=="bow" and archer.config.range>8.0,"Some of the bandits shoot arrows")
	for level in 2:
		for enemy in game.enemies:
			if not enemy.dead: enemy.hit(100000)
		if level==0:
			game.player.position = game.world.exit_point
			game.interact()
	check(game.run.floor==1 and game.run.cleared.size()==2 and Data.temple_open(game.run),"With both dungeons cleared the temple's door opens")
	check(game.run.level>=5,"The dungeons' bandits have raised him several levels (to %d)" % game.run.level)
	# Dying in a dungeon gives its bandits back, and no other place's.
	game.hurt_player(100000)
	game.retry_floor()
	check(not game.run.dead.any(func(id): return Data.of_place(id,"cave")) and "basement:0:0" in game.run.dead and game.run.cleared.size()==2,"A retry restores that dungeon's bandits only")
	# The temple, three floors and the summit.
	game.run.place = "temple"; game.run.floor = 0; game.run.position = [0,9]
	game.load_floor()
	check(game.enemies.all(func(e): return e.kind in ["gladiator","archer"] and not e.human and e.visual.is_stone),"The temple's first floor holds stone gladiators and archers")
	game.run.floor = 1; game.load_floor()
	check(game.world.layout.court.has_area() and is_instance_valid(game.world.fountain) and game.enemies.any(func(e): return e.kind=="lion") and game.enemies.any(func(e): return e.kind=="wizard") and not game.enemies.any(func(e): return e.kind=="centurion"),"The second floor has the fountain court, lions and Oracles")
	game.run.floor = 2; game.load_floor()
	var terraces: Array = game.world.layout.terrace
	var size: int = game.world.layout.size
	var sides = terraces.size()==3 and terraces.any(func(s): return s.position.x<0 and s.size.y>size) and terraces.any(func(s): return s.position.x>=size and s.size.y>size) and terraces.any(func(s): return s.position.y<0 and s.size.x>size)
	check(sides and game.world.layout.terrace_doors.size()==6 and game.enemies.any(func(e): return e.kind=="centurion"),"The third floor has the terrace round three sides, and centurions")
	game.run.floor = 3; game.load_floor()
	check(game.world.layout.summit and is_instance_valid(game.boss) and Data.summit(game.run),"Above it is the summit and the Crowned Statue")
	FileAccess.open("res://test-results/dungeons.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("DUNGEONS ",passed.size()," passed; ",failed)
	quit(1 if not failed.is_empty() else 0)
