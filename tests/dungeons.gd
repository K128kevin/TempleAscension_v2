extends SceneTree
## The two dungeons fought through before the temple: the basement under the
## arena and the bandits' cave. Their layouts, their bandits, the stairs down
## and back up, and the temple's door staying shut until both are cleared.
const Save = preload("res://scripts/save.gd")
const Items = preload("res://scripts/items.gd")
const Game = preload("res://scripts/game.gd")
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
# Plays the game on until the boulder he holds has no moves left and lies
# still (or `seconds` pass).
func roll_on(puzzle, seconds: float = 30.0) -> void:
	var left = seconds
	while left > 0 and (not puzzle.moves.is_empty() or puzzle.held.t < 1.0 or not game.route.is_empty()):
		game._process(.05)
		left -= .05

# The basement's last level: its boulders, plates and lasers, and the three
# in the room beyond them.
func puzzle_and_elites() -> void:
	var world = game.world
	var layout = world.layout
	var puzzle = world.puzzle
	# (Saved as a run in play is.)
	var creating: bool = game.creating_character
	game.creating_character = false
	check(puzzle != null and puzzle.boulders.size()==2 and puzzle.plates.size()==2 and puzzle.beams.size()==3 and puzzle.lit,"Below: two boulders, two plates, and the lasers lit")
	for beam in puzzle.beams:
		check(Vector2(beam.end.x-beam.from.x,beam.end.z-beam.from.z).length()>=layout.quiet[0].size.x-1.0,"A beam spans the hallway, wall to wall")
	# The wings' gates: shut, each opened by its wing's key, which the last
	# of its bandits drops.
	check(world.wing_gates.size()==2 and world.wing_gates.all(func(g): return not g.open) and not world.fits(world.wing_gate_point(0)),"The wings' gates stand locked")
	var west: Array = game.wing_bandits(0)
	check(west.size() >= 4 and game.wing_bandits(1).size() >= 4,"Bandits hold both wings (%d west, %d east)" % [west.size(),game.wing_bandits(1).size()])
	for k in west.size()-1: west[k].hit(100000)
	check(not game.wing_key_lying(0) and not Items.carries(game.run,"west_gate_key"),"No key falls while any of the wing's bandits stands")
	west[-1].hit(100000)
	var key_drop = game.pickups.filter(func(p): return p.drop.item.get("base","") == "west_gate_key")
	check(key_drop.size()==1 and Items.name_of(key_drop[0].drop.item)=="West Gate Key" and key_drop[0].node.position.distance_to(west[-1].position) < 1.5,"The last of them drops the West Gate Key")
	game.take_pickup(key_drop[0])
	game.player.position = world.wing_gate_point(0)+Vector3(world.layout.wings[0].dir.x,0,world.layout.wings[0].dir.y)*-1.5
	game.hud.tick(0)
	check("Unlock" in game.hud.prompt.text,"At its gate with the key, the HUD offers to unlock it")
	game.interact()
	check(world.wing_gates[0].open and world.fits(world.wing_gate_point(0)) and not Items.carries(game.run,"west_gate_key") and "basement:1:west:open" in game.run.keys,"E opens it (the key left in the lock), and it stays open")
	check(not world.wing_gates[1].open,"The east gate is still shut")
	# Through it the boulder is pushed a short way to the plate before it.
	for e in game.enemies: e.dormant = true
	var stone0: Dictionary = puzzle.boulders[0]
	game.player.position = puzzle.stand_point(stone0.cell,Vector2i.RIGHT,false)
	game.interact()
	puzzle.roll_to(puzzle.centre(layout.buttons[0]))
	var pushes: int = puzzle.moves.size()
	roll_on(puzzle,30.0)
	check(stone0.cell == layout.buttons[0] and pushes <= 16 and puzzle.plates[0].down,"Through the open gate it is rolled onto the plate before it in %d moves" % pushes)
	game.interact()
	for e in game.enemies: e.dormant = false
	# The east gate shut, its boulder cannot be got out.
	var stone1: Dictionary = puzzle.boulders[1]
	game.player.position = puzzle.stand_point(stone1.cell,Vector2i.LEFT,false)
	game.interact()
	puzzle.roll_to(puzzle.centre(layout.buttons[1]))
	check(puzzle.moves.is_empty() or stone1.cell+puzzle.moves.reduce(func(a,m): return a+m.m,Vector2i.ZERO) != layout.buttons[1],"Behind its locked gate the other boulder cannot be rolled out")
	puzzle.moves.clear()
	game.interact()
	# (Back where the rest of these checks expect it.)
	stone0.cell = layout.boulders[0]; stone0.to = puzzle.centre(stone0.cell); stone0.from = stone0.to; stone0.node.position = stone0.to; puzzle.settle(stone0.node)
	puzzle.nav_mark(layout.buttons[0]); puzzle.nav_mark(stone0.cell)
	# Held (E beside it), a boulder is rolled where he clicks: he goes round
	# to push it from the side it must be pushed from.
	# (The bandits stood aside: a boulder is not rolled into a man.)
	var places: Array = game.enemies.map(func(e): return e.position)
	for e in game.enemies:
		e.dormant = true
		e.position += Vector3(500,0,500)
	var b: Dictionary = puzzle.boulders[0]
	var room: Rect2i = layout.rooms.filter(func(r): return r.encloses(Rect2i(layout.boulders[0],Vector2i(2,2))))[0]
	game.player.position = puzzle.stand_point(b.cell,Vector2i.DOWN,false)
	game.hud.tick(0)
	check("Take hold" in game.hud.prompt.text,"Beside a boulder the HUD offers to take hold of it")
	game.interact()
	check(puzzle.holding(),"E takes hold of it")
	roll_on(puzzle,3.0)
	check(puzzle.gripping() and game.hud.prompt.text != "" and not is_instance_valid(game.player.visual.weapon_item) or not game.player.visual.weapon_item.visible,"Set against it, his hands on it, his weapon put away")
	var goal: Vector2i = b.cell+Vector2i(2,-2)
	game.issue_click(false)
	puzzle.roll_to(puzzle.centre(goal))
	check(puzzle.moves.size()==4 and puzzle.moves.all(func(m): return not m.pull),"A click plans it there, pushing it four tiles")
	game.sound.heard.clear()
	roll_on(puzzle)
	check("boulder-roll-short" in game.sound.heard and "boulder-roll-medium" in game.sound.heard and not puzzle.grinding_now,"It grinds as it goes, with Boulders' sounds, and falls quiet when it stops")
	check(b.cell == goal and b.t >= 1.0 and not world.fits(b.to),"He goes round it as he must and rolls it there")
	# Wedged in a corner, it is pulled out before it is pushed on.
	b.cell = room.position; b.to = puzzle.centre(b.cell); b.from = b.to; b.node.position = b.to; puzzle.settle(b.node)
	puzzle.nav_mark(goal); puzzle.nav_mark(b.cell)
	game.player.position = puzzle.stand_point(b.cell,Vector2i.DOWN,true)
	var out: Vector2i = b.cell+Vector2i(4,3)
	puzzle.roll_to(puzzle.centre(out))
	check(puzzle.moves.any(func(m): return m.pull) and not puzzle.moves.is_empty(),"Out of a corner, it is pulled clear first: %s" % [puzzle.moves])
	roll_on(puzzle,60.0)
	check(b.cell == out,"And rolled out of the corner to where he wanted it: %s vs %s, left %s, notice %s, hero %s" % [b.cell,out,puzzle.moves,game.hud.notice.text,game.player.position])
	game.interact()
	check(not puzzle.holding() and game.player.visual.weapon_item.visible,"E again lets it go, his weapon in hand again")
	for i in game.enemies.size():
		game.enemies[i].dormant = false
		game.enemies[i].position = places[i]
	# The plates: the hero on one, a boulder on the other.
	game.player.position = puzzle.centre(layout.buttons[0])
	puzzle.tick(.05)
	check(puzzle.plates[0].down and not puzzle.plates[1].down and puzzle.lit,"Standing on one plate presses it; the lasers stay lit")
	for i in 2:
		var stone: Dictionary = puzzle.boulders[i]
		stone.cell = layout.buttons[1-i]+Vector2i(i,0)
		stone.to = puzzle.centre(stone.cell); stone.from = stone.to; stone.t = 1.0
	game.player.position = world.layout.arrival_position()
	puzzle.tick(.05)
	check(puzzle.plates.all(func(p): return p.down) and not puzzle.lit,"With a boulder on each plate (a tile off, at most) the lasers go dark")
	# (Across the middle of the hallway.)
	var south: Vector3 = layout.to_world(layout.lasers[1].cell+layout.lasers[1].dir*2)
	game.player.position = south+Vector3(0,0,-2)
	puzzle.tick(.05)
	game.player.position = south+Vector3(0,0,2)
	puzzle.tick(.05)
	check(not game.player.dead,"Dark, they are walked through")
	game.save_run()
	check(game.run.boulders == puzzle.kept() and game.kept_boulders()==[puzzle.boulders[0].cell,puzzle.boulders[1].cell],"Where the boulders lie is saved")
	var stone: Dictionary = puzzle.boulders[0]
	stone.cell = layout.boulders[0]; stone.to = puzzle.centre(stone.cell); stone.from = stone.to
	game.player.position = world.layout.arrival_position()
	puzzle.tick(.05)
	check(puzzle.lit and not puzzle.barred(south+Vector3(0,0,-1.2),south+Vector3(0,0,-.8)) and puzzle.barred(south+Vector3(0,0,-.8),south+Vector3(0,0,.8)),"A boulder rolled off, they light again; no bandit walks through them")
	# Lit, they kill whoever walks into them, however well armored.
	game.player.position = south+Vector3(0,0,-2)
	puzzle.tick(.05)
	game.player.invulnerable = 1.0
	game.player.position = south+Vector3(0,0,2)
	puzzle.tick(.05)
	check(game.player.dead and game.mode=="dead","Walking through a lit laser kills him outright, even evading")
	game.player.invulnerable = 0.0
	# (Up again, as if it had not happened: a retry would stand the first
	# level's bandits up again too.)
	game.player.dead = false; game.player.hp = game.player.max_hp; game.mode = "playing"; game.hud.close_modal()
	game.player.position = layout.arrival_position()
	var rolled: Array = puzzle.kept()
	game.save_run()
	game.load_floor()
	world = game.world
	layout = world.layout
	puzzle = world.puzzle
	check(not game.player.dead and puzzle.kept() == rolled,"Come back, the boulders lie where they were rolled")
	# The level's own bandits are hardier than those above, and in studded
	# leather and yellow bandanas; the guards stand down the hallway.
	var bandit_here = game.enemies.filter(func(e): return e.kind=="bandit")[0]
	check(is_equal_approx(bandit_here.max_hp,Data.ENEMIES.bandit.hp*Data.HEALTH_SCALE[game.run.difficulty]*1.25) and is_equal_approx(Data.might(game.run,"bandit","damage"),1.4),"Its bandits have a quarter more health and deal 40% more damage")
	var above = game.run.duplicate(); above.floor = 0
	check(Data.enemy_xp(game.run,"bandit") > Data.enemy_xp(above,"bandit")*1.3*1.3,"And are worth 30% more experience on top of their level's")
	check(bandit_here.visual.bandit_look.get("studded",false) and bandit_here.visual.bandit_look.headwrap and bandit_here.visual.bandit_look.brow.g > bandit_here.visual.bandit_look.brow.b*3.0,"They wear studded leather and yellow bandanas")
	var south_hall: Rect2i = layout.halls[-1]
	var guards: Array = game.enemies.filter(func(e): return south_hall.has_point(layout.to_cell(e.position)) and not layout.quiet[0].has_point(layout.to_cell(e.position)))
	check(guards.size()>=Data.AREAS.basement[1].guards.size(),"Bandits stand guard down the hallway to the last room")
	# The three beyond.
	var elites: Array = game.enemies.filter(func(e): return e.kind in ["bandit_champion","bandit_marksman","bandit_healer"])
	check(elites.size()==3 and elites.all(func(e): return layout.elite_room.has_point(layout.to_cell(e.position)) and e.human),"Three bandits hold the last room")
	check(game.enemies.all(func(e): return e in elites or not layout.elite_room.has_point(layout.to_cell(e.position)) and not layout.quiet[0].has_point(layout.to_cell(e.position))),"No other bandit stands there or in the hallway of the lasers")
	var champion = elites.filter(func(e): return e.kind=="bandit_champion")[0]
	var marksman = elites.filter(func(e): return e.kind=="bandit_marksman")[0]
	var healer = elites.filter(func(e): return e.kind=="bandit_healer")[0]
	check(is_instance_valid(champion.visual.shield_item) and champion.armor()>=80.0 and champion.role=="gladiator","The champion bears a shield and heavy armor")
	check(not champion.visual.bandit_look.get("studded",false) and is_equal_approx(champion.max_hp,367.5*Data.HEALTH_SCALE[game.run.difficulty]) and Data.ENEMIES.bandit_marksman.damage==72.0 and Data.ENEMIES.bandit_healer.heals==.6,"The three are hardier and hit twice as hard, and the healer mends twice as much")
	check(healer.role=="wizard" and healer.visual.weapon_kind=="staff" and marksman.role=="archer" and marksman.config.damage>Data.ENEMIES.bandit_archer.damage*2,"A healer with a staff, a marksman whose arrows hit hard")
	# The healer mends his fellows, unless he is hurt as he casts.
	for e in elites: game.awaken(e)
	game.player.position = layout.to_world(layout.elite_room.position+Vector2i(1,1))
	champion.hp = champion.max_hp*.4
	var casting = false
	for i in 20:
		healer.tick(.05)
		if healer.healing: casting = true; break
	check(casting and healer.heal_target == champion and is_equal_approx(healer.cast_total,healer.HEAL_CAST),"The healer begins a two-second mending of the hurt champion")
	var hurt: float = champion.hp
	healer.hit(1)
	check(not healer.healing and healer.windup<=0 and is_equal_approx(champion.hp,hurt),"Struck, his mending is broken off")
	healer.heal_cooldown = 0.0; healer.busy = 0.0; healer.hit_stun = 0.0
	var mended = false
	for i in 80:
		healer.tick(.05)
		if champion.hp > hurt+1.0: mended = true; break
	check(mended and absf(champion.hp-hurt-champion.max_hp*healer.config.heals) < 1.0,"Left be, he mends him by a share of his health")
	# The marksman's stunning arrow.
	game.player.hp = game.player.max_hp
	game.player.position = marksman.position+Vector3(0,0,-6)
	marksman.stun_shot_left = 0.0; marksman.cooldown = 0.0; marksman.busy = 0.0
	var stunned = false
	for i in 120:
		marksman.tick(.05)
		game.tick_projectiles(.05)
		if game.stun_left > 0: stunned = true; break
	check(stunned and game.stun_left > 1.5 and game.hobbled > 3.5 and game.player.hp < game.player.max_hp,"Now and then his arrow stuns the hero for two seconds and hobbles him for four")
	var at: Vector3 = game.player.position
	game.route = PackedVector3Array([at+Vector3(3,0,0)])
	game.player_control(.1)
	check(game.player.position == at and game.player_pace() < Game.PLAYER_RUN_SPEED*.6,"Stunned, he cannot move; hobbled, he goes at half pace")
	game.stun_left = 0.0; game.hobbled = 0.0
	game.player.hp = game.player.max_hp
	game.player.position = layout.arrival_position()
	for i in elites.size():
		elites[i].lose_sight()
		elites[i].position = layout.to_world(layout.elite_posts[i])
		elites[i].hp = elites[i].max_hp
	game.creating_character = creating

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
				# (The cave's way in is its mouth; the basement is entered down a stair.)
				if place == "basement": check(not layout.entry.has_area() and layout.arrival.has_area(),"The way in is a stair, on both levels: "+label)
				else: check(layout.entry.has_area()==(level==0) and layout.arrival.has_area()==(level==1),"The way in is a door on the first level and a stair on the second: "+label)
				check(layout.stairs.has_area()==(level==0) and layout.last==(level==1),"Only the first level has a stair further down: "+label)
				if level==1: check(layout.cells.has(layout.arrival_foot) and not layout.arrival.has_point(layout.arrival_foot),"The stair back up is reached from the floor at its foot: "+label)
				if place=="basement" and level==0:
					# As big as the arena and its shape: a hallway round the middle,
					# rooms off both its sides, and at its far side from the way in a
					# gate into a hallway in to the middle, rooms off that too, and
					# the vault of the stair down.
					var middle: Vector2i = layout.center(layout.vault)-Vector2i(0,Layout.CENTER_SOUTH)
					check(layout.cells.keys().all(func(c): return Layout.oval_measure(c-middle,Layout.OVAL)<=1.0) and layout.cells.size()>=2000,"Within the arena's oval, and filling it (%d tiles): %s" % [layout.cells.size(),label])
					var ring: Array = layout.halls.slice(0,layout.halls.size()-1)
					check(ring.size()>=8 and ring.all(func(h): return mini(h.size.x,h.size.y)==Layout.MAIN_HALL) and layout.halls.any(func(h): return h.has_point(middle+Vector2i(0,Layout.RING.y))) and layout.halls.any(func(h): return h.has_point(middle+Vector2i(Layout.RING.x,0))) and layout.halls.any(func(h): return h.has_point(middle-Vector2i(Layout.RING.x,0))),"A great hallway rings the middle: "+label)
					var off: Array = layout.rooms.slice(1,layout.rooms.size()-1)
					var sealed_rooms: Array = off.filter(func(r): return layout.behind_gate(layout.center(r)))
					check(off.size()-sealed_rooms.size()>=8 and sealed_rooms.size()>=1 and off.all(func(r): return not layout.halls.any(func(h): return h.intersects(r))),"Rooms off it (%d), and off the hallway in (%d): %s" % [off.size()-sealed_rooms.size(),sealed_rooms.size(),label])
					var outer: int = off.filter(func(r): return Layout.oval_measure(layout.center(r)-middle,Layout.RING)>1.0).size()
					check(outer>=3 and off.size()-sealed_rooms.size()-outer>=3,"On both sides of it: "+label)
					check(layout.start.y>middle.y+Layout.RING.y and layout.gate.get_area()==Layout.GATE_WIDTH and layout.gate.position.y<middle.y-Layout.RING.y/2 and layout.gate_dir==Vector2i.DOWN and layout.halls[-1].has_point(layout.gate.position+layout.gate_dir) and layout.vault.encloses(layout.stairs) and layout.behind_gate(layout.exit_cell),"Its way in is to the south; to the north a gate opens on the way in to the vault of the stair: "+label)
					check(Layout.oval_measure(layout.center(layout.vault)-middle,Vector2(8,8))<=1.0,"The stair down is in the middle: "+label)
				elif place=="basement":
					# The last level: the room he comes down into, its two plates; the
					# arms north-west and north-east to the boulders; south, the lasers,
					# and the elites' room beyond them.
					var room: Rect2i = layout.rooms[0]
					check(room.has_point(layout.start) and room.encloses(layout.arrival) and layout.buttons.size()==2 and layout.buttons.all(func(b): return room.encloses(Rect2i(b,Vector2i(2,2))) and not layout.arrival.grow(1).intersects(Rect2i(b,Vector2i(2,2)))),"Two pressure plates in the room he comes down into: "+label)
					check(layout.boulders.size()==2 and layout.boulders.all(func(b): return [b,b+Vector2i.RIGHT,b+Vector2i.DOWN,b+Vector2i.ONE].all(func(c): return layout.cells.has(c))) and layout.boulders.any(func(b): return b.x<room.position.x) and layout.boulders.any(func(b): return b.x>=room.end.x),"A boulder in each wing's last room, west and east: "+label)
					# The wings: out from the room's north and round, three times as
					# long as they were, back to their last rooms beside the room, a
					# locked gate (wide enough for a boulder) between.
					check(layout.wings.size()==2 and layout.wings.map(func(w): return w.name)==["west","east"],"Two wings, west and east: "+label)
					for wing in layout.wings:
						var g: Rect2i = wing.gate
						var hall_length = 0
						for r in wing.rects.slice(0,5): hall_length += maxi(r.size.x,r.size.y)-Layout.DEPTHS_HALL
						check(g.size.y==Layout.WING_GATE and g.size.x==1 and Layout.WING_GATE>=4 and room.grow(1).has_point(g.position) and wing.room.has_point(layout.boulders[0 if wing.name=="west" else 1]+Vector2i.ONE) and wing.rects.any(func(r): return r.has_point(g.position-wing.dir)) and layout.cells.has(g.position),"%s: its last room holds the boulder, beside the room of the plates, a gate %d wide between: %s" % [wing.name,g.size.y,label])
						check(hall_length >= 125 and wing.rects[0].position.y < room.position.y,"%s: out from the room's north side and round, %d tiles of hallway: %s" % [wing.name,hall_length,label])
					check(layout.lasers.size()==3 and layout.lasers.all(func(l): return layout.quiet[0].has_point(l.cell) and l.cell.y>room.end.y and not layout.cells.has(l.cell-l.dir)) and layout.elite_room.position.y>layout.lasers[-1].cell.y+8,"Lasers across the hallway south, the last room well beyond them: "+label)
					check(layout.elite_posts.size()==3 and layout.elite_posts.all(func(c): return layout.elite_room.has_point(c) and layout.cells.has(c)),"Three posts in the last room: "+label)
					var south: Rect2i = layout.halls[-1]
					check(south.size.y==Layout.LASER_HALL and Layout.LASER_HALL==54 and layout.quiet[0].size.y==Layout.QUIET_HALL,"The hallway to it is three times as long as it was, its first stretch quiet: "+label)
					var off_south: Array = layout.rooms.filter(func(r): return layout.wing_of(layout.center(r)) < 0 and r.position.y>=south.position.y+Layout.QUIET_HALL and r.end.y<=south.end.y+2 and (r.end.x<south.position.x or r.position.x>=south.end.x))
					check(off_south.size()==Layout.HALL_ROOMS and off_south.any(func(r): return r.end.x<south.position.x) and off_south.any(func(r): return r.position.x>=south.end.x),"Two rooms off it, one each side, beyond the lasers: "+label)
					check(layout.guard_posts.size()>=Data.AREAS.basement[1].guards.size() and layout.guard_posts.all(func(c): return south.has_point(c) and not layout.quiet[0].has_point(c) and layout.cells.has(c)),"Guards' posts down it: "+label)
					check(layout.rooms.size()>=6 and not layout.gate.has_area() and not layout.vault.has_area(),"Rooms off the arms, and no gate: "+label)
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
	check(Data.AREAS.temple[0].counts.keys()==["gladiator","archer","lion"],"The temple's first floor holds gladiators, archers and lions")
	check(not Data.AREAS.temple[2].counts.has("gladiator") and Data.AREAS.temple[2].counts.centurion==75,"On the third floor centurions stand in the gladiators' place")
	check(Data.ENEMIES.lion.damage==13.5,"A lion's swipe does 13.5 damage (doubled, then raised by half again)")
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
	var flight = world.find_child("BasementFlight",false,false)
	check(flight != null and flight.position.y < -2.0 and flight.position.distance_to(Overworld.BASEMENT_STAIR+Vector3.DOWN*Town.STAIR_DEPTH) < .01 and world.ground_material.get_shader_parameter("hole_center") == Vector2(Overworld.BASEMENT_STAIR.x,Overworld.BASEMENT_STAIR.z),"The stair down is a flight of steps sunk in an opening in the ground")
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
	var rats: Array = world.get_children().filter(func(n): return n.get_script() == preload("res://scripts/rats.gd"))
	check(rats.size()==1 and rats[0].rats.size()==roundi(world.layout.cells.size()/Game.RAT_ROOM),"Rats scurry about the basement")
	check(game.player.position.distance_to(world.layout.arrival_position())<.01 and not world.leaving_temple(game.player.position),"He arrives at the foot of the stair down from the arena")
	game.hud.tick(0)
	check("bandits remain" in game.hud.status.text and game.hud.objective.text=="LEVEL 1","The HUD counts bandits, on a numbered level with no place name")
	check(not game.has_way_on() or not (game.way_open() and game.has_way_on()),"The way down is shut while bandits remain")
	# A bandit fights, and falls.
	var bandit = game.enemies.filter(func(e): return e.kind=="bandit")[0]
	# (On whichever side of him there is floor.)
	for side in [Vector3(0,0,1.4),Vector3(0,0,-1.4),Vector3(1.4,0,0),Vector3(-1.4,0,0)]:
		game.player.position = bandit.position+side
		if world.fits(game.player.position) and world.clear_line(bandit.position,game.player.position): break
	var hp: float = game.player.hp
	for i in 120:
		bandit.tick(1.0/60); game.tick_scheduled(1.0/60)
	check(bandit.awake and game.player.hp<hp,"A bandit swordsman attacks the hero")
	var xp: int = game.run.xp
	bandit.hit(10000)
	check(bandit.dead and bandit.visual.state=="Death" and game.run.xp>xp and bandit.uid in game.run.dead,"He falls, and is worth experience")
	game.player.hp = game.player.max_hp
	# The way down is behind a locked gate at the hallway's end; one bandit,
	# in a room off its far half, carries the key.
	var layout0 = world.layout
	check(game.gated() and not world.gate_open and not world.fits(world.gate_point()) and not game.has_key(),"A locked gate bars the way to the stair")
	check(layout0.vault.encloses(layout0.stairs) and layout0.vault.has_point(layout0.exit_cell),"The stair down is in the vault behind it")
	var holder = game.key_holder
	check(holder != null and not layout0.behind_gate(layout0.to_cell(holder.position)) and is_instance_valid(holder.visual.belt_key),"One bandit this side of the gate wears the key at his belt")
	game.player.position = world.gate_point()-Vector3(layout0.gate_dir.x,0,layout0.gate_dir.y)*1.5
	game.hud.tick(0)
	check("locked" in game.hud.prompt.text,"At the gate the HUD says it is locked")
	game.interact()
	check(not world.gate_open,"Without the key it stays shut")
	# Its bearer slain too soon (before two thirds of those this side of the
	# gate are dead), the key does not fall: another of them has it.
	var first_holder = game.key_holder
	first_holder.hit(100000)
	check(game.key_pickup().is_empty() and game.key_holder != first_holder and not game.key_holder.dead and is_instance_valid(game.key_holder.visual.belt_key) and not is_instance_valid(first_holder.visual.belt_key),"Slain too soon, its bearer drops no key; another bandit wears it")
	var side: Array = game.key_side()
	for enemy in side:
		if game.key_free(): break
		if not enemy.dead and enemy != game.key_holder: enemy.hit(100000)
	check(game.key_pickup().is_empty() and side.filter(func(e): return e.dead).size() >= ceili(side.size()*2.0/3.0),"Two thirds of them dead, the key has still to be won from its bearer")
	holder = game.key_holder
	holder.hit(100000)
	check(not game.key_pickup().is_empty(),"Its bearer slain then, the key falls")
	for enemy in game.enemies:
		if not enemy.dead: enemy.hit(100000)
	check(game.remaining()==0 and not (game.way_open() and game.has_way_on()) and game.run.cleared.is_empty() and not game.way_open(),"With the level cleared the gate is still locked")
	var lying: Dictionary = game.key_pickup()
	check(not lying.is_empty() and lying.drop in game.run.drops and not is_instance_valid(holder.visual.belt_key),"The key fell where its bearer died, an item on the floor")
	game.hud.tick(0)
	check(not game.hud.stair_arrow.visible,"No arrow points the way in the basement")
	game.player.position = lying.node.position
	game.pick_up(lying)
	check(game.has_key() and game.key_pickup().is_empty() and Items.carries(game.run,Game.GATE_KEY),"Picked up, it goes in the bag")
	var key_place: int = game.run.bag.find(Items.make(Game.GATE_KEY))
	check(Items.describe(Game.GATE_KEY).kind=="Key" and Items.slot_for(game.run,Items.make(Game.GATE_KEY))=="" and key_place>=0 and not Items.move(game.run,"bag:%d" % key_place,"main").is_empty(),"It is carried, not worn or held")
	# Killed, he rises again with the key still in his bag.
	game.hurt_player(100000)
	game.retry_floor()
	world = game.world
	check(game.has_key() and game.remaining()==0 and game.enemies.all(func(e): return e.dead) and game.key_pickup().is_empty(),"Dying, he keeps the key, and the basement's slain stay dead")
	for enemy in game.enemies:
		if not enemy.dead: enemy.hit(100000)
	game.player.hp = game.player.max_hp
	check(game.key_pickup().is_empty() and game.run.bag.count(Items.make(Game.GATE_KEY))==1,"No second key falls")
	game.player.position = world.gate_point()-Vector3(layout0.gate_dir.x,0,layout0.gate_dir.y)*1.5
	game.hud.tick(0)
	check("Unlock" in game.hud.prompt.text,"With it, the HUD offers to unlock the gate")
	game.interact()
	check(world.gate_open and world.fits(world.gate_point()) and (game.way_open() and game.has_way_on()) and game.way_open() and "basement:0:open" in game.run.keys and not Game.GATE_KEY in game.run.bag,"The key opens the gate (and stays in its lock), and the way down")
	check(not world.path(world.gate_point()-Vector3(layout0.gate_dir.x,0,layout0.gate_dir.y)*2.0,world.exit_point).is_empty(),"Through the open gate the stair can be walked to")
	# The way down is taken with E, not by walking onto it.
	game.player.position = world.exit_point
	check(not game.pass_door() and game.run.floor==0,"Walking onto the stairs does not take them")
	game.player.position = world.exit_point+(world.gate_point()-world.exit_point).normalized()*1.5
	game.hud.tick(0)
	check("E · Descend" in game.hud.prompt.text,"Near them the HUD offers E to go down")
	game.interact()
	world = game.world
	check(game.run.place=="basement" and game.run.floor==1 and world.layout.last and not game.has_way_on(),"The stair goes down to the second, last level")
	var below = 3+Data.AREAS.basement[1].guards.size()
	for count in Data.AREAS.basement[1].counts.values(): below += count
	check(game.enemies.all(func(e): return e.uid.begins_with("basement:1:")) and game.remaining()==below,"More bandits wait below")
	puzzle_and_elites()
	world = game.world
	# Back up, and down again: what was done stays done.
	game.player.position = world.layout.arrival_position()
	check(world.fits(game.player.position),"The foot of the stair back up can be stood at")
	game.interact()
	world = game.world
	check(game.run.floor==0 and game.remaining()==0 and game.player.position.distance_to(world.exit_point)<.01,"The stair leads back up to the cleared level, at the head of the stair")
	check(not game.pass_door() and game.run.floor==0,"Come up, he is not sent straight back down")
	game.interact()
	world = game.world
	check(game.run.floor==1,"E takes him down again")
	check(game.run.floor==1 and game.remaining()>0,"And down again")
	# Killed in the basement, a bandit never stands again, even when he dies.
	var slain = game.enemies.filter(func(e): return not e.dead)[0]
	var slain_id: String = slain.uid
	slain.hit(100000)
	var left: int = game.remaining()
	game.hurt_player(100000)
	game.retry_floor()
	check(game.remaining()==left and game.enemies.filter(func(e): return e.uid==slain_id)[0].dead and slain_id in game.run.dead,"The basement's slain stay dead when he dies and rises again")
	# No arrow points the way to the last of them here, and the level's
	# clearing goes unremarked.
	var standing: Array = game.enemies.filter(func(e): return not e.dead)
	for enemy in standing.slice(0,standing.size()-3): enemy.hit(100000)
	game.hud.tick(0)
	check(game.remaining()==3 and not game.hud.enemy_arrow.visible,"No arrow points to the basement's last bandits")
	game.hud.notice.text = ""
	for enemy in game.enemies:
		if not enemy.dead: enemy.hit(100000)
	check(not "routed" in game.hud.notice.text and not "silent" in game.hud.notice.text,"Nothing is said of the basement's being cleared")
	check(game.remaining()==0 and game.run.cleared==["basement"] and not Data.temple_open(game.run) and not (game.way_open() and game.has_way_on()),"Clearing the last level clears the dungeon; the temple stays shut for the cave")
	check(Save.valid(game.run),"The run is valid to save")
	# A save from before the basement was laid out anew: its bandits stand again.
	var older: Dictionary = game.run.duplicate(true)
	older.version = 14; older.erase("keys")
	var sixteen: Dictionary = game.run.duplicate(true)
	sixteen.version = 16; sixteen.keys = ["basement:0:open"]; sixteen.bag = Items.empty_bag(); sixteen.boulders = [[1,1],[2,2]]
	var seventeen: Dictionary = Save.migrate(sixteen)
	check(Save.valid(sixteen) and seventeen.version==Data.new_run().version and seventeen.keys.is_empty() and Items.carries(seventeen,Game.GATE_KEY) and not seventeen.has("boulders") and not seventeen.dead.any(func(id): return id.begins_with("basement:")) and seventeen.position==[0,9],"A save from before the oval basement: its gate shut again with the key given back, its bandits standing again")
	var renewed: Dictionary = Save.migrate(older)
	check(Save.valid(older) and renewed.keys.is_empty() and not renewed.dead.any(func(id): return id.begins_with("basement:")) and renewed.cleared==["basement"],"An earlier save's basement is peopled again, still counted cleared")
	# Out again.
	game.player.position = world.layout.arrival_position()
	game.interact()
	world = game.world
	game.target = null
	check(game.run.floor==0 and game.player.position.distance_to(world.exit_point)<.01,"Up from the second level, back on the first, at the head of its stair down")
	game.player.position = world.layout.arrival_position()
	game.hud.tick(0)
	check("arena" in game.hud.prompt.text,"At the first level's stair the HUD says it climbs to the arena")
	game.interact()
	check(game.outdoors() and game.run.place=="world" and game.player.position.distance_to(Overworld.OUTSIDE.basement.at)<.01,"Up the stair, he comes out under the stands, by its head")
	# The cave.
	game.player.position = Overworld.CAVE+Vector3(0,0,2)
	check(game.pass_door() and game.run.place=="cave" and game.run.floor==0 and game.world.layout.kind=="cave","Walking into the cave's mouth enters its first level")
	check(not game.world.get_children().any(func(n): return n.get_script() == preload("res://scripts/rats.gd")),"The cave has no rats")
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
	check(game.enemies.all(func(e): return e.kind in ["gladiator","archer","lion"] and not e.human and e.visual.is_stone) and game.enemies.any(func(e): return e.kind=="lion"),"The temple's first floor holds stone gladiators, archers and lions")
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
