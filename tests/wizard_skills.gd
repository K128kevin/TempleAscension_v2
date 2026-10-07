extends SceneTree
## The wizard's three trees in play: every spell's listed numbers, its ice,
## fire and lightning, on an open plane with passive stand-in enemies.
const Data = preload("res://scripts/data.gd")
const Items = preload("res://scripts/items.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
const Temple = preload("res://scripts/temple.gd")
const Actor = preload("res://scripts/actor.gd")
const Art = preload("res://scripts/assets.gd")
const ShieldBubble = preload("res://scripts/shield_bubble.gd")
const WizardFx = preload("res://scripts/wizard_fx.gd")
const STEP = 1.0/60
# The starting staff adds 5% to every spell.
const STAFF = 1.05
var game
var origin: Vector3
var forward = Vector3(0,0,-1)
var passed: Array = []
var failed: Array = []
var spawned = 0
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func open_plane():
	game.run = Data.new_run("wizard")
	game.load_floor()
	game.remove_child(game.world); game.world.queue_free()
	for list in [game.enemies,game.effects,game.projectiles,game.fireballs,game.novas,game.pickups,game.scheduled]: list.clear()
	game.world = Temple.new()
	game.add_child(game.world)
	game.world.setup(Temple.Layout.PLAYGROUND,1)
	game.hover_ring = Art.target_ring()
	game.world.add_child(game.hover_ring)
	game.player = Actor.new()
	game.world.add_child(game.player)
	origin = game.world.spawn+Vector3(0,0,10)
	game.player.setup(game,"player","hero",origin)

func dummy(ahead: float, degrees: float = 0.0, hp: float = 100000.0):
	spawned += 1
	var e = game.spawn_enemy("gladiator","dummy:%d" % spawned,origin+forward.rotated(Vector3.UP,deg_to_rad(degrees))*ahead)
	e.puppet = true; e.awake = true
	e.max_hp = hp; e.hp = hp
	return e

func clear():
	for e in game.enemies: e.dead = true; e.visible = false; e.queue_free()
	game.enemies.clear()

func hero(ranks: Dictionary):
	game.run = Data.new_run("wizard")
	game.run.skills = ranks
	game.run.skill_points = 0
	game.refit()
	ready()

func ready():
	game.player.position = origin
	game.player.face(origin+forward)
	game.player.busy = 0; game.player.cooldown = 0; game.player.invulnerable = 0; game.player.dead = false
	game.player.hp = Data.max_health(game.run); game.player.max_hp = game.player.hp
	game.scheduled.clear(); game.skills.reset()
	game.run.energy = Data.max_energy(game.run)
	game.leap_left = 0; game.dash_time = 0; game.dash_cooldown = 0; game.combat_age = 10
	game.skills.crit_override = 0
	game.skills.block_override = 0
	game.player.visual.position = Vector3.ZERO

func play(seconds: float):
	for i in ceili(seconds/STEP):
		game.player.tick(STEP)
		game.tick_scheduled(STEP)
		game.skills.tick(STEP)
		game.player_control(STEP)
		game.tick_projectiles(STEP)
		game.tick_fireballs(STEP)
		for e in game.enemies: e.tick(STEP)

func lost(e) -> float: return e.max_hp-e.hp
# `hits` of `percent` of the spell baseline (10 to 15 at 5 Intelligence, by the staff).
func within(e, hits: float, percent: float, factor: float = 1.0) -> bool:
	return lost(e) >= 10.0*STAFF*hits*percent*.01*factor-.01 and lost(e) <= 15.0*STAFF*hits*percent*.01*factor+.01

func cast(id: String, at: Vector3) -> bool:
	var ok: bool = game.skills.cast(id,at)
	return ok

func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/wizard-skills-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	open_plane()
	var at: Vector3 = origin+forward*6.0

	# The roster and the trees.
	var mine: Array = Book.all().values().filter(func(s): return s.class_id=="wizard")
	check(mine.size()==19 and Book.trees("wizard")==["ice","fire","lightning"],"The wizard has nineteen spells in Ice, Fire and Lightning")
	check(mine.filter(func(s): return s.tree=="ice").size()==7 and mine.filter(func(s): return s.tree=="fire").size()==6 and mine.filter(func(s): return s.tree=="lightning").size()==6,"Seven of ice, six of fire, six of lightning")
	var fresh = Data.new_run("wizard")
	check(Book.locked(fresh,"ice_bolt").is_empty() and Book.locked(fresh,"fireball").is_empty() and Book.locked(fresh,"lightning_bolt").is_empty() and not Book.locked(fresh,"ice_spikes").is_empty() and not Book.locked(fresh,"ice_storm").is_empty(),"Spells open by the points spent in their own tree")
	for clip in ["CastBolt","CastPoint","CastGround","CastSelf","CastChannel"]:
		check(game.player.visual.clips.has(clip),"The wizard's casting clip is there: "+clip)

	# --- Ice.
	hero({"ice_bolt":1})
	var foe = dummy(6)
	check(cast("ice_bolt",foe.position) and game.player.visual.state=="CastBolt" and is_equal_approx(game.run.energy,90.0),"Ice Bolt is hurled for 10 energy")
	play(2.0)
	check(within(foe,1,100) and foe.chilled() and foe.slow_time>0 and is_equal_approx(foe.slow_factor,.6),"Rank 1 hits for 100%% and chills: slowed 40%% for 3 seconds (%.1f)" % lost(foe))
	check(game.skills.patches.size()==1 and game.skills.on_ice(foe.position),"and ices the floor under it")
	hero({"ice_bolt":5}); foe.hp = foe.max_hp
	var frozen = 0
	for i in 40:
		ready(); foe.hp = foe.max_hp; foe.end_stun()
		cast("ice_bolt",foe.position); play(1.5)
		if foe.stunned and foe.daze=="freeze": frozen += 1
	check(within(foe,1,180) and frozen>=2 and frozen<=18,"Rank 5: 180%%, and one bolt in five freezes (%d of 40)" % frozen)
	foe.end_stun()
	hero({"ice_bolt":1,"improved_chill":5}); foe.hp = foe.max_hp
	cast("ice_bolt",foe.position); play(1.5)
	check(is_equal_approx(foe.slow_factor,.2) and foe.chill_time>6.4 and foe.chill_time<=8.0,"Improved Chill rank 5: the chill slows 80%% for 8 seconds (%.1f left)" % foe.chill_time)
	clear()

	# Freeze Floor: held, laying ice along the ray, slowing whoever walks on it.
	hero({"freeze_floor":1})
	game.skills.channel_hold_override = 1
	check(cast("freeze_floor",at) and game.skills.channeling() and game.player.visual.state=="CastChannel" and is_equal_approx(game.run.energy,100.0),"Freeze Floor is a channel: nothing paid until it is held")
	play(1.0)
	check(absf(game.run.energy-90.0)<.5 and game.skills.channeling() and game.skills.patches.size()>=1,"Held a second it costs 10 energy and ices the floor where the ray falls")
	# (With the game's own frames running, his energy coming back as it does,
	# the channel is still paid in full: none comes back while it is held.)
	var before_frames: float = game.run.energy
	for i in 30: game._process(STEP)
	check(game.skills.channeling() and absf((before_frames-game.run.energy)-10.0*30*STEP)<.3,"In play, held, it drains 10 energy a second; none comes back while it is held (%.2f in half a second)" % (before_frames-game.run.energy))
	var walker = dummy(6)
	play(.5)
	check(walker.slow_time>0 and is_equal_approx(walker.slow_factor,.6),"An enemy on the ice is slowed 40%")
	game.skills.channel_hold_override = 0
	play(.1)
	check(not game.skills.channeling() and game.player.busy<=0,"Let go, the channel ends and he is free")
	var left: float = game.skills.patches.map(func(p): return p.left).max()
	check(left>9.5 and left<=12.0 and game.skills.patches[-1].radius==1.25,"The ice lasts 12 seconds and spreads 2.5 metres across where the ray falls")
	hero({"freeze_floor":5}); game.skills.channel_hold_override = 1
	cast("freeze_floor",at); play(.5)
	check(is_equal_approx(walker.slow_factor,.2),"Rank 5 slows 80%")
	game.skills.channel_hold_override = -1
	game.run.energy = 3.0
	play(.5)
	check(not game.skills.channeling(),"Out of energy, the channel breaks")
	var sheets: Array = game.skills.patches.map(func(p): return p.node)
	play(12.5)
	check(game.skills.patches.is_empty() and sheets.all(func(n): return not is_instance_valid(n) or n.is_queued_for_deletion()),"The ice melts away after 12 seconds, its sheets with it")
	game.skills.lay_ice(origin+forward*6,1.25,12.0,40.0)
	game.skills.lay_ice(origin+forward*6.5,1.25,12.0,40.0)
	check(game.skills.patches.size()==1,"Ice laid within half its width of a patch freezes that one afresh")
	for i in 60: game.skills.lay_ice(origin+Vector3(i*3,0,0),.9,6.0,0.0)
	play(1.1)
	check(game.skills.patches.size()<=game.skills.MAX_PATCHES,"No more than %d patches of ice lie at once (%d)" % [game.skills.MAX_PATCHES,game.skills.patches.size()])
	clear()

	# Ice Spikes: everyone within 2 metres of the aim.
	hero({"ice_spikes":1})
	var ring = [dummy(6),dummy(7.5),dummy(6,14),dummy(9.5)]
	check(cast("ice_spikes",at) and game.player.visual.state=="CastGround" and is_equal_approx(game.run.energy,65.0),"Ice Spikes costs 35, raised with both hands")
	play(1.5)
	check(within(ring[0],1,100) and within(ring[1],1,100) and within(ring[2],1,100) and lost(ring[3])==0,"Rank 1: 100%% across 4 metres, not beyond (%.1f, %.1f, %.1f, %.1f)" % [lost(ring[0]),lost(ring[1]),lost(ring[2]),lost(ring[3])])
	check(ring[0].chilled() and game.skills.on_ice(ring[1].position),"They are chilled, and the ground iced")
	hero({"ice_spikes":5}); for e in ring: e.hp = e.max_hp
	cast("ice_spikes",at); play(1.5)
	check(within(ring[0],1,180),"Rank 5: 180%")
	clear()

	# Ice Prison: held fast, taking more.
	hero({"ice_prison":1})
	foe = dummy(6)
	check(cast("ice_prison",foe.position) and game.player.visual.state=="CastPoint" and is_equal_approx(game.run.energy,55.0),"Ice Prison costs 45, pointed")
	play(.6)
	check(foe.stunned and foe.daze=="prison" and foe.stagger_time>1.5 and foe.stagger_time<=2.0 and is_instance_valid(foe.stun_mark),"Rank 1 freezes it for 2 seconds in a block of ice")
	foe.hit(100.0)
	check(foe.stunned and absf(lost(foe)-120.0)<.5,"Damage does not break the prison, and it takes 20% more")
	play(2.0)
	check(not foe.stunned,"The ice melts in time")
	hero({"ice_prison":5}); foe.hp = foe.max_hp
	cast("ice_prison",foe.position); play(.6)
	check(foe.stagger_time>5.5 and foe.stagger_time<=6.0 and is_equal_approx(foe.daze_bonus,60.0),"Rank 5: 6 seconds, 60% more damage")
	foe.end_stun()
	clear()

	# Frost Blast: held, its damage a second within 3 metres of the stream.
	hero({"frost_blast":1}); game.skills.channel_hold_override = 1
	var line = [dummy(4),dummy(8,-15),dummy(9,45)]
	check(cast("frost_blast",at) and game.skills.channeling() and is_equal_approx(game.run.energy,100.0),"Frost Blast is a channel")
	play(1.0)
	check(absf(game.run.energy-80.0)<.5,"and costs 20 energy a second")
	check(within(line[0],1,70,1.0) or (lost(line[0])>=10*STAFF*.7*.75-.01 and lost(line[0])<=15*STAFF*.7+.01),"Rank 1: about 70%% a second to the enemy in the stream (%.1f)" % lost(line[0]))
	check(lost(line[1])>0 and lost(line[2])==0,"to one within 3 metres of it, and not to one off to the side")
	check(line[0].chilled(),"Frost chills")
	game.skills.channel_hold_override = 0; play(.1)
	game.skills.channel_hold_override = -1
	clear()

	# Ice Storm: frost about him, frost doubled, nothing else cast.
	hero({"ice_storm":1,"ice_bolt":1,"fireball":1})
	var near = dummy(3)
	var far = dummy(6,30)
	check(cast("ice_storm",at) and game.player.visual.state=="CastSelf" and is_equal_approx(game.run.energy,60.0),"Ice Storm costs 40, cast on himself")
	play(.6)
	check(game.skills.storm_time>0 and game.skills.storm_time<=6.0 and game.skills.cooldowns.ice_storm>58.0,"Rank 1 lasts 6 seconds, on a 60-second cooldown")
	play(1.0)
	check(lost(near)>0 and lost(far)==0 and near.chilled(),"Frost tears at everyone within 4 metres each second (%.1f)" % lost(near))
	check(game.skills.reason("fireball")=="Only frost spells while the Ice Storm rages." and game.skills.reason("ice_bolt").is_empty(),"Only frost spells can be cast while it lasts")
	game.player.busy = 0; var before: float = lost(far)
	cast("ice_bolt",far.position); play(1.5)
	check(lost(far)-before>=10*STAFF*2.0-.01 and lost(far)-before<=15*STAFF*2.0+.01,"Frost spells deal double damage in the storm (%.1f)" % (lost(far)-before))
	play(5.0)
	check(game.skills.storm_time==0 and game.skills.reason("fireball").is_empty(),"It passes, and his fire is his again")
	clear()

	# --- Fire.
	hero({"fireball":1})
	foe = dummy(6)
	check(cast("fireball",foe.position) and game.player.visual.state=="CastBolt" and is_equal_approx(game.run.energy,90.0),"Fireball costs 10")
	play(2.0)
	check(within(foe,1,120),"Rank 1 burns for 120%% (%.1f)" % lost(foe))
	hero({"fireball":5}); foe.hp = foe.max_hp
	cast("fireball",foe.position); play(2.0)
	check(within(foe,1,280),"Rank 5: 280%")
	hero({"fireball":1,"frostburn":1,"ice_bolt":1}); foe.hp = foe.max_hp
	cast("ice_bolt",foe.position); play(1.5)
	var chilled_at: float = lost(foe)
	game.player.busy = 0
	cast("fireball",foe.position); play(2.0)
	check(lost(foe)-chilled_at>=10*STAFF*1.2*1.5-.01 and lost(foe)-chilled_at<=15*STAFF*1.2*1.5+.01,"Frostburn rank 1: fire deals 50%% more to the chilled (%.1f)" % (lost(foe)-chilled_at))
	# On ice laid on the floor, unchilled, it counts as chilled.
	hero({"fireball":1,"frostburn":1}); foe.hp = foe.max_hp; foe.chill_time = 0.0
	check(not foe.chilled(),"Off the ice and unchilled, an enemy is not chilled")
	cast("fireball",foe.position); play(2.0)
	check(within(foe,1,120),"so Frostburn adds nothing (%.1f)" % lost(foe))
	hero({"fireball":1,"frostburn":1}); foe.hp = foe.max_hp; foe.chill_time = 0.0
	game.skills.lay_ice(foe.position,game.skills.FLOOR_RADIUS,10.0,0.0)
	check(foe.chilled() and foe.chill_time==0.0,"Standing on the wizard's ice, it is chilled")
	cast("fireball",foe.position); play(2.0)
	check(within(foe,1,120,1.5),"and Frostburn's 50%% more is dealt it (%.1f)" % lost(foe))
	game.skills.lay_ice(game.player.position,game.skills.FLOOR_RADIUS,10.0,0.0)
	check(game.skills.on_ice(game.player.position) and not game.player.chilled(),"(The wizard on his own ice is not)")
	hero({"fireball":1,"pyromaniac":1}); foe.hp = foe.max_hp
	cast("fireball",foe.position); play(2.0)
	check(within(foe,1,240) and game.skills.burn_left>0 and game.player.hp<game.player.max_hp,"Pyromaniac doubles fire, and burns him (%.1f dealt, %.1f burnt)" % [lost(foe),game.player.max_hp-game.player.hp])
	play(3.0)
	check(absf((game.player.max_hp-game.player.hp)-lost(foe)*.1)<.5,"for a tenth of what it dealt, over 3 seconds")
	clear()
	# Bolts strike the first enemy in their way, as arrows do.
	hero({"ice_bolt":1,"fireball":1})
	var first = dummy(4)
	var behind = dummy(8)
	cast("ice_bolt",behind.position); play(1.5)
	check(lost(first)>0 and lost(behind)==0,"An ice bolt strikes the first enemy in its way (%.1f, %.1f)" % [lost(first),lost(behind)])
	first.hp = first.max_hp; first.end_stun(); ready()
	cast("fireball",behind.position); play(2.0)
	check(lost(first)>0 and lost(behind)==0,"A fireball bursts on the first enemy in its way (%.1f, %.1f)" % [lost(first),lost(behind)])
	clear()

	# Blast Wave: 5 metres all round.
	hero({"blast_wave":1})
	var round_him = [dummy(3),dummy(4.5,120),dummy(4.8,-100),dummy(6.5)]
	check(cast("blast_wave",at) and game.player.visual.state=="CastSelf" and is_equal_approx(game.run.energy,55.0),"Blast Wave costs 45")
	play(1.2)
	check(within(round_him[0],1,125) and within(round_him[1],1,125) and within(round_him[2],1,125) and lost(round_him[3])==0,"Rank 1: 125%% to everyone within 5 metres, on every side (%.1f, %.1f, %.1f, %.1f)" % [lost(round_him[0]),lost(round_him[1]),lost(round_him[2]),lost(round_him[3])])
	clear()

	# Fire Tornado: 8 seconds of fire where he aims, wandering about it.
	hero({"fire_tornado":1})
	foe = dummy(6)
	var aside = dummy(13)
	check(cast("fire_tornado",at) and game.player.visual.state=="CastGround" and is_equal_approx(game.run.energy,35.0),"Fire Tornado costs 65")
	play(.6)
	check(game.skills.zones.size()==1,"It stands where he aimed")
	# Its fire lands every 0.2 seconds, each time a fifth of its damage a second.
	var burns: Array = []
	var was: float = foe.hp
	for i in 60:
		play(1.0/60)
		if foe.hp<was: burns.append(was-foe.hp); was = foe.hp
	check(burns.size()==5 and burns.all(func(d): return absf(d-burns[0])<burns[0]*.6) and burns[0]>=10*STAFF*.5*.2-.01 and burns[0]<=15*STAFF*.5*.2+.01,"It burns every 0.2 seconds, a fifth of its damage a second each time (%d burns in a second: %s)" % [burns.size(),burns])
	var strayed: float = 0.0
	for i in 34:
		play(.25)
		if not game.skills.zones.is_empty(): strayed = maxf(strayed,game.skills.zones[0].at.distance_to(game.skills.zones[0].origin))
	check(strayed>.5 and strayed<=game.skills.TORNADO_WANDER+.5,"It wanders, but no further than %.0f metres from where it was cast (%.1f)" % [game.skills.TORNADO_WANDER,strayed])
	check(lost(foe)>0 and lost(foe)<=15*STAFF*.5*8+.01 and lost(aside)==0 and game.skills.zones.is_empty(),"Rank 1: 50%% a second for 8 seconds to what it touches (%.1f)" % lost(foe))
	check(range(1,6).all(func(r): return Book.values("fire_tornado",r).y==r),"Its chance to make an enemy a Lightning Rod is 1, 2, 3, 4 and 5%% by rank")
	# Each burn rolls for each enemy it burns: with five burns a second for
	# eight seconds, at rank 5 most of a crowd in it are made rods (once a
	# second for one enemy, few could be).
	clear()
	hero({"fire_tornado":5,"lightning_rod":1})
	var crowd: Array = []
	for i in 6:
		var e = dummy(6)
		e.position = at+Vector3(cos(i*TAU/6),0,sin(i*TAU/6))*.3
		crowd.append(e)
	seed(20261006)
	cast("fire_tornado",at)
	var strikes = 0
	for i in 52:
		play(.16)
		for e in crowd:
			if game.skills.zones.size()==1: e.position = game.skills.zones[0].at+(e.position-game.skills.zones[0].at).limit_length(.3)
		strikes = maxi(strikes,game.skills.waves.filter(func(w): return w is WizardFx.SkyStrike).size())
	var rodded: int = crowd.filter(func(e): return e.rod_time>0).size()
	check(rodded>=4,"Rank 5: each burn has its own 5%% chance for each enemy it burns (%d of 6 made rods)" % rodded)
	check(strikes>=2,"and each one made a rod is struck by lightning from the sky (%d strikes at once)" % strikes)
	clear()

	# Every other damage over time lands the same way: a fifth of its damage
	# a second every 0.2 seconds.
	hero({})
	var cursed = dummy(4)
	cursed.add_dot("curse",100.0,5.0,1)
	var steps: Array = []
	was = cursed.hp
	for i in 60:
		cursed.tick(1.0/60)
		if cursed.hp<was: steps.append(snappedf(was-cursed.hp,.01)); was = cursed.hp
	check(steps.size()==5 and steps.all(func(d): return is_equal_approx(d,steps[0])),"Curses, poisons and shadows land every 0.2 seconds, a fifth of their damage a second each time (%s)" % [steps])
	for i in 300: cursed.tick(1.0/60)
	check(is_equal_approx(cursed.max_hp-cursed.hp,steps[0]*25) and cursed.dots.is_empty(),"and all of it lands by the time it ends (%.2f)" % (cursed.max_hp-cursed.hp))
	clear()

	# Blazing Speed.
	hero({"blazing_speed":1,"fireball":1})
	var pace: float = game.player_pace()
	check(cast("blazing_speed",at) and is_equal_approx(game.run.energy,50.0),"Blazing Speed costs 50")
	play(.6)
	check(game.skills.blazing_time>0 and is_equal_approx(game.player_pace(),pace*1.75) and game.skills.cost("fireball")==0.0 and game.skills.cooldowns.blazing_speed>58.0,"For 6 seconds he runs 75% faster and fire costs nothing; 60-second cooldown")
	foe = dummy(6)
	game.player.busy = 0
	check(cast("fireball",foe.position) and is_equal_approx(game.run.energy,50.0),"Fireball is free")
	play(1.0)
	play(6.0)
	check(game.skills.blazing_time==0 and is_equal_approx(game.player_pace(),pace),"It passes")
	clear()

	# --- Lightning.
	hero({"lightning_bolt":1})
	foe = dummy(6)
	check(cast("lightning_bolt",foe.position) and game.player.visual.state=="CastBolt" and is_equal_approx(game.run.energy,90.0),"Lightning Bolt costs 10")
	play(.6)
	check(within(foe,1,100),"Rank 1 strikes at once for 100%% (%.1f)" % lost(foe))
	hero({"lightning_bolt":5}); foe.hp = foe.max_hp
	cast("lightning_bolt",foe.position); play(.6)
	check(within(foe,1,220),"Rank 5: 220%")
	hero({"lightning_bolt":1,"ignition":5})
	var beside = dummy(7.2)
	var lit = 0
	var bursts = 0
	var popped = 0
	for i in 30:
		ready(); foe.hp = foe.max_hp; beside.hp = beside.max_hp
		game.sound.heard.clear()
		cast("lightning_bolt",foe.position); play(.6)
		if lost(beside)>0:
			lit += 1
			if game.skills.waves.any(func(w): return w is WizardFx.Ignition): bursts += 1
			if "ignition-burst" in game.sound.heard: popped += 1
	check(lit>=3 and lit<=20 and (lost(beside)==0 or within(beside,1,200)),"Ignition rank 5: a bolt in three sets off 200%% of fire within 2 metres (%d of 30)" % lit)
	check(bursts==lit and popped==lit,"Each time it goes off with an explosion, and is heard bursting (%d, %d of %d)" % [bursts,popped,lit])
	clear()

	# Lightning Shield.
	hero({"lightning_shield":1})
	foe = dummy(2)
	check(cast("lightning_shield",at) and game.player.visual.state=="CastSelf" and is_equal_approx(game.run.energy,50.0),"Lightning Shield costs 50")
	play(.6)
	check(game.skills.barrier==50.0 and game.skills.shield_time>59.0 and game.skills.cooldowns.lightning_shield>58.0,"Rank 1 absorbs 50 for 60 seconds, on a 60-second cooldown")
	var bubble = game.skills.shield_node
	check(bubble is ShieldBubble and bubble.get_parent()==game.player.visual and bubble.crackles.is_empty(),"It is a bubble about him, quiet until struck")
	game.hurt_player(30.0,"physical",foe)
	var through: float = 30.0*(1.0-Data.armor(game.run)*.01)
	check(game.player.hp==game.player.max_hp and is_equal_approx(game.skills.barrier,50.0-through) and within(foe,1,20),"A blow is absorbed (what armor let through), and its striker shocked for 20%% (%.1f)" % lost(foe))
	var toward: Vector3 = game.player.visual.global_transform.basis.inverse()*(foe.position-game.player.position)
	check(bubble.crackles.size()==1 and bubble.crackles[0].from.dot(Vector3(toward.x,0,toward.z).normalized())>.7,"Absorbing it, the bubble crackles with electricity where the blow came from")
	play(.6)
	check(bubble.crackles.is_empty(),"and the crackle dies away")
	game.hurt_player(30.0,"physical",foe)
	check(game.player.hp<game.player.max_hp and game.skills.barrier==0.0,"Spent, the rest gets through")
	play(.1)
	check(game.skills.shield_node == null and is_instance_valid(bubble) and bubble.ending and bubble in game.skills.waves,"Spent, the bubble gives out, its last crackle seen")
	play(1.0)
	check(not is_instance_valid(bubble) or bubble.is_queued_for_deletion(),"and is gone")
	check(range(1,6).map(func(r): return Book.values("lightning_shield",r).z)==[60.0,55.0,50.0,40.0,30.0],"Its cooldown is 60, 55, 50, 40 and 30 seconds by rank")
	hero({"lightning_shield":5})
	cast("lightning_shield",at); play(.6)
	check(is_equal_approx(game.skills.cooldowns.lightning_shield,30.0-.6+STEP) or absf(game.skills.cooldowns.lightning_shield-29.4)<.05,"Rank 5 recharges in 30 seconds (%.1f)" % game.skills.cooldowns.lightning_shield)
	var first_bubble = game.skills.shield_node
	game.hurt_player(30.0,"physical",foe)
	play(30.0)
	game.player.busy = 0; game.player.cooldown = 0; game.run.energy = Data.max_energy(game.run)
	check(cast("lightning_shield",at),"Recharged, it is cast again while the shield is still up")
	play(.6)
	var shields: int = game.player.visual.get_children().filter(func(c): return c is ShieldBubble and not c.ending and not c.is_queued_for_deletion()).size()
	check(is_equal_approx(game.skills.barrier,150.0) and game.skills.shield_time>59.0 and shields==1 and not is_instance_valid(first_bubble) or (is_instance_valid(first_bubble) and first_bubble.is_queued_for_deletion()),"It replaces the shield he had (absorbing 150 again, not more; one bubble) (%.0f, %d)" % [game.skills.barrier,shields])
	clear()

	# Lightning Rod.
	hero({"lightning_rod":1})
	var rod = dummy(5)
	var chain = [dummy(7),dummy(9),dummy(11),dummy(13),dummy(15)]
	check(cast("lightning_rod",rod.position) and game.player.visual.state=="CastPoint" and is_equal_approx(game.run.energy,70.0),"Lightning Rod costs 30, pointed")
	play(.6)
	check(rod.rod_time>9.0 and is_instance_valid(rod.rod_mark),"The enemy is a rod for 10 seconds")
	check(game.skills.waves.any(func(w): return w is WizardFx.SkyStrike and Vector2(w.position.x,w.position.z).distance_to(Vector2(rod.position.x,rod.position.z))<.01),"A great bolt of lightning strikes it out of the sky")
	check(rod.rod_mark is WizardFx.StaticArcs and not rod.rod_mark.arcs.is_empty() and rod.rod_mark.arcs.any(func(a): return a.a is Array),"and static arcs crawl over its body while it lasts (%d)" % rod.rod_mark.arcs.size())
	rod.hit(10.0)
	check(within(chain[0],1,100) and within(chain[1],1,70) and within(chain[2],1,49) and within(chain[3],1,34.3) and lost(chain[4])==0,"Hurt, it jolts the nearest for 100%%, then three more each 30%% weaker (%.1f, %.1f, %.1f, %.1f, %.1f)" % [lost(chain[0]),lost(chain[1]),lost(chain[2]),lost(chain[3]),lost(chain[4])])
	var jolted: float = lost(chain[0])
	rod.hit(10.0)
	check(lost(chain[0])==jolted,"but not twice within half a second")
	play(.6); rod.hit(10.0)
	check(lost(chain[0])>jolted,"and again after it")
	clear()

	# System Shock.
	hero({"system_shock":1})
	foe = dummy(6)
	check(cast("system_shock",foe.position) and game.player.visual.state=="CastPoint" and is_equal_approx(game.run.energy,55.0),"System Shock costs 45")
	play(.6)
	check(foe.stunned and foe.stagger_time>4.5 and foe.stagger_time<=5.0 and game.skills.cooldowns.system_shock>44.0,"Rank 1 stuns for 5 seconds, on a 45-second cooldown")
	foe.hit(5.0)
	check(not foe.stunned,"Damage breaks it")
	clear()

	# Conductive Ice.
	hero({"lightning_bolt":1,"conductive_ice":1,"freeze_floor":1})
	var a = dummy(5); var b = dummy(6.4); var c = dummy(9)
	game.skills.lay_ice(a.position,.9,10,0); game.skills.lay_ice(a.position.lerp(b.position,.5),.9,10,0); game.skills.lay_ice(b.position,.9,10,0)
	cast("lightning_bolt",a.position); play(.6)
	check(within(a,1,100) and within(b,1,100) and lost(c)==0,"Lightning on an enemy standing on ice leaps to another on the same ice, not to one on bare floor (%.1f, %.1f, %.1f)" % [lost(a),lost(b),lost(c)])
	clear()

	# Only a wizard's spells have an element; his bare-handed casting and tips.
	hero({"fireball":1})
	game.run.equipment.main = ""; game.refit()
	foe = dummy(6)
	check(cast("fireball",foe.position),"Spells are cast with nothing in hand")
	check("Damage:" in game.skills.damage_summary("fireball",1).damage and " a second" in game.skills.damage_summary("fire_tornado",1).damage and game.skills.damage_summary("ice_prison",1).is_empty(),"Tips show a spell's damage, a second for what lasts, and none for what deals none")
	check(Book.element("fireball")=="fire" and Book.element("ice_bolt")=="ice" and Book.element("system_shock")=="lightning" and Book.element("cleave")=="","Each spell has its element")
	# An older wizard's save: his points come back.
	var old = Data.new_run("wizard"); old.version = 11; old.skills = {}; old.skill_points = 1
	var migrated = Save.migrate(old)
	check(Save.valid(old) and migrated.version==Data.new_run().version and migrated.skills.is_empty() and migrated.skill_points==1 and migrated.get("migration_notice",false),"A wizard's older save has its skill points refunded")
	game.run.skills = {"fireball":1}; game.run.skill_points = 0; game.run.equipment.main = "silver_staff"
	check(Save.valid(game.run),"The character is save-valid throughout")
	# LMB is bound from the skill panel as the other slots are.
	hero({})
	game.run.skills = {}; game.run.skill_points = 2; game.run.hotbar = ["","","","","",""]
	game.mode = "playing"; game.hud.tick(0)
	var panels = game.hud.panels
	panels.skill_plus.pressed.emit()
	panels.nodes.ice_bolt.button.pressed.emit()
	check(game.run.skills.ice_bolt==1 and game.run.hotbar[Data.LEFT_SLOT]=="ice_bolt","The wizard's first spell goes on LMB")
	panels.nodes.fireball.button.pressed.emit()
	check(game.run.skills.fireball==1 and game.run.hotbar[0]=="fireball" and game.run.skill_points==0,"his next on RMB")
	panels.nodes.fireball.button.pressed.emit()
	check(game.run.hotbar[Data.LEFT_SLOT]=="fireball" and game.run.hotbar[0]=="" and game.run.skills.fireball==1,"With no point to raise it, clicking a learned spell binds it to LMB")
	panels.assign("ice_bolt",2)
	check(game.run.hotbar[2]=="ice_bolt","and 1 to 4 bind as before")
	game.resume_game()

	# Running, he carries his staff in his fist as the swordsman carries his
	# sword, swinging with his stride; standing, it is his walking stick again.
	var look = game.player.visual
	var staff_line = func() -> Array:
		look.skeleton.force_update_all_bone_transforms()
		look.align_weapon()
		var foot: Vector3 = look.weapon_item.global_transform*Vector3.ZERO
		var top: Vector3 = look.weapon_item.global_transform*Vector3(0,1,0)
		var fist: Vector3 = look.bow_hold("r")[0]
		var along: Vector3 = (top-foot).normalized()
		return [along,(fist-foot-along*(fist-foot).dot(along)).length()]
	var swing: Array = []
	var gripped = true
	for i in 70:
		look.locomotion(true,false,false,1.0,4.75); look.advance(1.0/60)
		if i>=10:
			var held_line: Array = staff_line.call()
			swing.append(held_line[0])
			gripped = gripped and held_line[1]<.03
	var widest = 0.0
	for d in swing: widest = maxf(widest,rad_to_deg(swing[0].angle_to(d)))
	check(look.state=="WizardRun" and gripped and widest>20.0,"Running, the staff stays in his fist and swings with his stride (%.0f degrees)" % widest)
	for i in 40: look.locomotion(false,false); look.advance(1.0/60)
	var rest: Array = staff_line.call()
	check(rest[0].dot(Vector3.UP)>.98 and rest[1]<.03,"Standing, it is upright in his hand again")
	# --- His evade is a teleport.
	clear()
	hero({})
	var start: Vector3 = game.player.position
	game.player.busy = 1.0
	game.dash(start+forward*20.0)
	check(game.player.position.distance_to(start+forward*game.TELEPORT_REACH)<.01 and game.dash_time==0.0 and game.player.busy==0.0,"Space teleports him at once, as far as 8.5 metres toward the cursor, and he is free at once")
	check(is_equal_approx(game.dash_cooldown,3.0) and game.skills.waves.filter(func(w): return w is WizardFx.Blink).size()==2 and "teleport" in game.sound.heard,"on the dash's 3-second recharge, with a flash where he goes and where he comes, and its sound")
	var there: Vector3 = game.player.position
	game.dash(there-forward*5.0)
	check(game.player.position==there,"It cannot be used again while it recharges")
	for i in 190: game._process(STEP)
	game.player.position = there
	game.dash(there-forward*4.0)
	check(game.player.position.distance_to(there-forward*4.0)<.01,"Recharged, he teleports exactly where he points, within reach")
	game.player.position = there
	game.dash_cooldown = 0
	game.dash(there+forward*.2)
	check(absf(game.player.position.distance_to(there)-game.DASH_MIN)<.01,"Never shorter than the dash's least")
	game.player.position = origin
	game.dash_cooldown = 0
	game.dash(origin+Vector3(0,0,-400))
	var path_clear: bool = game.world.clear_line(origin,game.player.position) and game.world.fits(game.player.position)
	check(path_clear and game.player.position.distance_to(origin)<=game.TELEPORT_REACH+.01,"Never through a wall: he lands on open floor in plain sight")
	hero({})
	game.run.class_id = "warrior"
	game.dash(game.player.position+forward*5.0)
	check(game.dash_time>0,"(The other classes dash, as before)")
	game.dash_time = 0; game.player.busy = 0; game.player.invulnerable = 0

	# --- Sounds: spells are heard by their own, never as a weapon's blow.
	var heard: Array = game.sound.heard
	var blows = func(): return heard.any(func(id): return id in ["weapon-impact","arrow-stone-impact","sword-hit-flesh"] or id.begins_with("arrow-flesh"))
	clear()
	hero({"fireball":1})
	foe = dummy(6)
	heard.clear()
	cast("fireball",foe.position)
	play(.6)
	var cast_at: int = heard.find("fireball-cast")
	check(cast_at>=0 and not "fireball-burst" in heard,"Fireball is heard as it leaves his staff, before it lands (%s)" % [heard])
	play(1.4)
	check(lost(foe)>0 and heard.find("fireball-burst")>cast_at and not blows.call(),"and bursts as it strikes, with no weapon's blow heard (%s)" % [heard])
	for spell in [["ice_bolt","frost-bolt"],["ice_spikes","ice-spikes"],["ice_prison","ice-prison"],["blast_wave","fire-blast"],["lightning_bolt","lightning-zap"]]:
		hero({spell[0]:1}); foe.hp = foe.max_hp; foe.end_stun(); foe.dead = false
		heard.clear()
		cast(spell[0],foe.position); play(1.5)
		check(spell[1] in heard and not blows.call(),"%s is heard as %s, not as a weapon's blow (%s)" % [spell[0],spell[1],heard])
	hero({"ice_bolt":1}); foe.hp = foe.max_hp; foe.end_stun()
	heard.clear()
	cast("ice_bolt",foe.position); play(1.5)
	check("ice-impact" in heard,"An ice bolt shatters as it strikes")
	heard.clear()
	game.skills.strike(foe,1.0)
	check("weapon-impact" in heard,"A weapon's blow on a statue is still heard")
	hero({"lightning_rod":1}); foe.hp = foe.max_hp
	heard.clear()
	cast("lightning_rod",foe.position); play(1.0)
	check("thunder-strike" in heard and not "lightning-zap" in heard,"Lightning Rod's bolt from the sky is heard as thunder")
	heard.clear()
	game.skills.spell_hit(foe,10.0,"frost")
	check(not blows.call() and not game.skills.spell_striking,"A spell striking a Lightning Rod (its jolt a spell within a spell) is no weapon's blow either")
	hero({"fire_tornado":1})
	heard.clear()
	cast("fire_tornado",at); play(1.0)
	var funnel: Dictionary = game.skills.zones[0]
	game.player.position = funnel.at
	var close_by: float = game.skills.tornado_gain(funnel)
	game.player.position = funnel.at+Vector3(7,0,0)
	var middling: float = game.skills.tornado_gain(funnel)
	game.player.position = funnel.at+Vector3(25,0,0)
	var distant: float = game.skills.tornado_gain(funnel)
	check("fire-tornado" in heard and close_by>.95 and absf(middling-.5)<.02 and distant<.08,"Fire Tornado roars as it burns, louder the nearer he is (%.2f beside it, %.2f at 7 m, %.2f at 25 m)" % [close_by,middling,distant])
	funnel.life = .4
	check(game.skills.tornado_gain(funnel)<distant*.6,"and dies away as it burns out")
	for spell in [["ice_storm","ice-storm"],["freeze_floor","frost-stream"]]:
		hero({spell[0]:1})
		heard.clear()
		cast(spell[0],at); play(1.2)
		check(spell[1] in heard,"%s is heard for as long as it lasts" % spell[0])
	FileAccess.open("res://test-results/wizard-skills.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("WIZARD_SKILLS ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
