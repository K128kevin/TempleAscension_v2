extends SceneTree
## The warrior's three skill trees in play: every skill's listed numbers, on an
## open plane with passive stand-in enemies.
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
const Temple = preload("res://scripts/temple.gd")
const Actor = preload("res://scripts/actor.gd")
const Art = preload("res://scripts/assets.gd")
const STEP = 1.0/60
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

# An open, wall-less plane with the real damage rules (the debug playground's
# floor without the playground itself).
func open_plane():
	game.run = Data.new_run("warrior")
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

# A stand-in enemy that only acts when told: `ahead` metres in front of the
# hero, turned `degrees` off his facing.
func dummy(ahead: float, degrees: float = 0.0, hp: float = 100000.0):
	spawned += 1
	var e = game.spawn_enemy("gladiator","dummy:%d" % spawned,origin+forward.rotated(Vector3.UP,deg_to_rad(degrees))*ahead)
	e.puppet = true; e.awake = true
	e.max_hp = hp; e.hp = hp
	return e

func clear():
	for e in game.enemies: e.dead = true; e.visible = false; e.queue_free()
	game.enemies.clear()

# A warrior with these ranks, ready to act.
func hero(ranks: Dictionary, weapon: int = 1):
	game.run = Data.new_run("warrior")
	game.run.skills = ranks
	game.run.weapon = weapon; game.run.owned[weapon] = true
	game.player.visual.equip(Data.WEAPONS[weapon])
	ready()

func ready():
	game.player.position = origin
	game.player.face(origin+forward)
	game.player.busy = 0; game.player.cooldown = 0; game.player.invulnerable = 0; game.player.dead = false
	game.player.hp = Data.max_health(game.run); game.player.max_hp = game.player.hp
	game.scheduled.clear(); game.skills.reset()
	game.run.energy = Data.max_energy(game.run)
	game.leap_left = 0; game.dash_time = 0; game.dash_attack = false; game.combat_age = 10
	# Damage checks are exact; critical hits are tested on their own.
	game.skills.crit_override = 0
	game.player.visual.position = Vector3.ZERO

# Skills and enemies run on; the hero stays where he stands.
func wait(seconds: float):
	for i in ceili(seconds/STEP):
		game.skills.tick(STEP)
		for e in game.enemies: e.tick(STEP)

# The whole hero runs: movement, leaps, dashes, swings.
func play(seconds: float):
	for i in ceili(seconds/STEP):
		game.player.tick(STEP)
		game.tick_scheduled(STEP)
		game.skills.tick(STEP)
		game.player_control(STEP)
		for e in game.enemies: e.tick(STEP)

func lost(e) -> float: return e.max_hp-e.hp

func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/warrior-skills-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	open_plane()
	check(game.world.clear_line(origin,origin+forward*21.5) and game.world.fits(origin+forward*21.5),"The test plane has room for the longest Ground Slam")

	# Cleave: every enemy in the arc, for the listed damage and energy.
	hero({"cleave":1})
	var front = dummy(2.0); var side = dummy(2.0,60); var wide = dummy(2.0,80); var behind = dummy(2.0,180); var far = dummy(3.6)
	check(game.skills.cast("cleave",origin+forward*2) and game.run.energy==75,"Cleave costs 25 energy")
	wait(.3)
	check(lost(front)==0,"Cleave waits for the swing to land")
	wait(.3)
	check(lost(front)>=12.5 and lost(front)<=18.75,"Cleave rank 1 deals 125%% of a normal attack (%.1f)" % lost(front))
	check(lost(side)>0 and lost(wide)==0 and lost(behind)==0 and lost(far)==0,"Cleave rank 1 sweeps a 140° arc within reach")
	hero({"cleave":5})
	game.skills.cast("cleave",origin+forward*2); wait(.6)
	check(lost(wide)>=16.5 and lost(wide)<=24.75 and lost(behind)==0,"Cleave rank 5 sweeps 180° for 165%")
	check(game.attack_range(true,0)==game.skills.MELEE_REACH,"An ordered Cleave is walked into melee reach")
	clear()

	# Ground Slam: an arc out to its listed distance.
	hero({"cleave":5,"ground_slam":1})
	var near = dummy(9.0); var beyond = dummy(11.5); var off = dummy(9.0,45)
	check(game.skills.cast("ground_slam",origin+forward*5) and game.run.energy==60,"Ground Slam costs 40 energy")
	wait(.6)
	check(lost(near)>=10 and lost(near)<=15 and lost(beyond)==0 and lost(off)==0,"Ground Slam rank 1: 100% damage in a 70° arc out to 10 metres")
	check(game.effects.any(func(e): return e.has("velocity")),"The slam sends a shockwave out along the arc")
	hero({"cleave":5,"ground_slam":5})
	var distant = dummy(20.5)
	game.skills.cast("ground_slam",origin+forward*5); wait(.6)
	check(lost(distant)>=25 and lost(distant)<=37.5 and lost(off)>0,"Ground Slam rank 5: 250% damage in a 120° arc out to 21 metres")
	check(game.skills.waves.size()>=1 and game.shake_left>0 and game.player.visual.state=="SkillSlam","The slam sends out a shockwave of dust, shakes the screen, and has its own swing")
	var wave = game.skills.waves[0]
	var puffs = wave.get_children().filter(func(c): return c is CPUParticles3D)
	check(puffs.size()==2 and puffs.all(func(p): return p.emitting and absf(p.spread-60.0)<.01 and p.initial_velocity_max>=20.0),"Dust and smoke burst out fast across the slam's arc")
	wait(3.0)
	check(game.skills.waves.is_empty(),"The shockwave passes within a couple of seconds")
	clear()

	# War Cry: every enemy near takes more damage for a while.
	hero({"war_cry":1})
	var cowed = dummy(4.0); var afar = dummy(8.0)
	check(game.skills.cast("war_cry",origin+forward) and game.run.energy==70,"War Cry costs 30 energy, with no points needed")
	wait(.5)
	check(cowed.rally_time>5.0 and afar.rally_time==0.0,"War Cry rank 1 cows enemies within 6 metres for 6 seconds")
	game.skills.strike(cowed,10); game.skills.strike(afar,10)
	check(absf(lost(cowed)-lost(afar)*1.2)<.01,"They take 20% more damage")
	wait(6.5)
	check(cowed.rally_time==0.0,"and the effect ends")
	hero({"war_cry":5})
	game.skills.cast("war_cry",origin+forward); wait(.5)
	check(afar.rally_time>9.0 and afar.rally_bonus==100.0,"War Cry rank 5 reaches 10 metres, doubling the damage taken, for 10 seconds")
	clear()

	# Shield Charge: a run behind the shield through everyone in the way.
	hero({"cleave":5,"ground_slam":5,"shield_charge":1},3)
	check(not game.skills.cast("shield_charge",origin+forward*6),"Shield Charge needs the sword and shield")
	hero({"cleave":5,"ground_slam":5,"shield_charge":1})
	var first = dummy(3.0); var second = dummy(6.0); var aside = dummy(5.0,40)
	check(game.skills.cast("shield_charge",origin+forward*7.5) and game.run.energy==65,"Shield Charge costs 35 energy")
	play(1.2)
	check(lost(first)>=10 and lost(first)<=15 and lost(second)>=10 and lost(second)<=15 and lost(aside)==0,"Rank 1: everyone in the path takes 100%")
	check(first.stun_memory>0,"The first one hit was stunned")
	check(game.player.position.distance_to(origin)>4.0,"He ran on through them (%.1f m)" % game.player.position.distance_to(origin))
	check(first.position.distance_to(origin+forward*3.0)>.8 or second.position.distance_to(origin+forward*6.0)>.8,"and they were thrown aside")
	clear()

	# Shockwave: a ring that throws everyone back, on a cooldown.
	hero({"cleave":5,"ground_slam":5,"shockwave":1})
	var inside = dummy(3.0); var ring_edge = dummy(5.0)
	check(game.skills.cast("shockwave",origin+forward) and game.run.energy==60,"Shockwave costs 40 energy")
	wait(.8)
	check(lost(inside)>=18 and lost(inside)<=27 and lost(ring_edge)==0,"Shockwave rank 1: 180% within 4 metres")
	check(game.skills.cooldowns.get("shockwave",0.0)>8.0 and not game.skills.cast("shockwave",origin+forward),"and a 10-second cooldown")
	check(game.skills.waves.size()>=1 and game.player.visual.state=="SkillShockwave","It sends out a shockwave")
	play(.6)
	check(inside.position.distance_to(origin)>3.6,"and throws them back (%.1f m)" % inside.position.distance_to(origin))
	clear()

	# Leap: through the air to the target, striking everything around the landing.
	hero({"cleave":5,"leap":1})
	var landing = dummy(8.0,0); var beside = dummy(8.0,14); var start = dummy(1.5,180)
	var reached = dummy(10.7,0); var past = dummy(11.7,0)
	check(game.skills.cast("leap",origin+forward*6.5) and game.run.energy==60,"Leap costs 40 energy")
	check(game.leap_left>0 and game.player.invulnerable>0,"He is in the air, out of harm's way")
	# (The warrior gathers himself for a fifth of the swing, then flies.)
	play(.4)
	check(game.player.visual.position.y>.5 and lost(landing)==0,"The leap arcs through the air before it lands")
	play(.5)
	check(game.player.position.distance_to(origin+forward*6.5)<.6 and game.player.visual.position.y==0,"He lands at the target (%.2f m off)" % game.player.position.distance_to(origin+forward*6.5))
	check(game.skills.waves.size()>=1 and game.shake_left>0 and game.player.visual.state=="SkillLeap","The landing sends out a shockwave all round and shakes the screen")
	check(lost(landing)>=10 and lost(landing)<=15 and lost(beside)>0 and lost(start)==0,"Leap rank 1 deals 100% to everyone around the landing")
	check(game.skills.LEAP_RADIUS==4.5 and lost(reached)>0 and lost(past)==0,"Its blast reaches 4.5 metres from the landing")
	hero({"cleave":5,"leap":5})
	game.skills.cast("leap",origin+forward*20)
	play(1.0)
	check(absf(game.player.position.distance_to(origin)-game.skills.LEAP_RANGE)<.6,"A leap carries at most its range")
	check(game.attack_range(true,1)==13.0 and game.skills.reach("leap")==game.skills.LEAP_RANGE,"An ordered Leap is made from its range")
	clear()

	# Powerful Strike: one enemy.
	hero({"powerful_strike":1})
	var aimed = dummy(1.6,-18); var other = dummy(1.6,18)
	check(game.skills.cast("powerful_strike",aimed.position) and game.run.energy==75,"Powerful Strike costs 25 energy")
	wait(.6)
	check(lost(aimed)>=20 and lost(aimed)<=30 and lost(other)==0,"Powerful Strike rank 1 deals 200% to the one enemy it is aimed at")
	hero({"powerful_strike":5})
	game.skills.cast("powerful_strike",other.position); wait(.6)
	check(lost(other)>=30 and lost(other)<=45,"Powerful Strike rank 5 deals 300%")
	clear()

	# Shield Bash: damage, a stun that damage breaks, a cooldown, and less
	# stun on a target bashed again within 30 seconds.
	hero({"shield_bash":1})
	var bashed = dummy(1.6)
	check(game.skills.cast("shield_bash",bashed.position) and game.run.energy==65,"Shield Bash costs 35 energy")
	wait(.5)
	check(lost(bashed)>=2.5 and lost(bashed)<=3.75,"Shield Bash rank 1 deals 25%")
	check(bashed.stunned and absf(bashed.stagger_time-5.0)<.1 and is_instance_valid(bashed.stun_mark),"It stuns for 5 seconds")
	check(absf(game.skills.cooldowns.shield_bash-31.5)<.1 and game.skills.reason("shield_bash").begins_with("Recharging"),"It recharges for 32 seconds")
	game.player.busy = 0
	check(not game.skills.cast("shield_bash",bashed.position) and game.run.energy==65,"It cannot be cast while recharging")
	wait(31.6)
	check(not bashed.stunned and game.skills.reason("shield_bash").is_empty(),"The stun runs out, and the bash is ready after its cooldown")
	game.player.busy = 0; game.run.energy = 100; bashed.stun_memory = 20.0
	game.skills.cast("shield_bash",bashed.position); wait(.5)
	check(absf(bashed.stagger_time-2.5)<.1,"A second bash within 30 seconds stuns for half as long")
	game.skills.cooldowns.clear(); game.player.busy = 0; game.run.energy = 100
	game.skills.cast("shield_bash",bashed.position); wait(.5)
	check(absf(bashed.stagger_time-1.25)<.1,"A third, half as long again")
	bashed.hit(1)
	check(not bashed.stunned and bashed.stagger_time==0,"Damage to the target breaks the stun")
	bashed.stun_memory = 0; game.skills.cooldowns.clear(); game.player.busy = 0; game.run.energy = 100
	game.skills.cast("shield_bash",bashed.position); wait(.5)
	check(absf(bashed.stagger_time-5.0)<.1,"After 30 seconds the stun is whole again")
	hero({"shield_bash":5})
	bashed.end_stun(); bashed.stun_memory = 0
	game.skills.cast("shield_bash",bashed.position); wait(.5)
	check(absf(bashed.stagger_time-10.0)<.1 and absf(game.skills.cooldowns.shield_bash-19.5)<.1,"Shield Bash rank 5: a 10-second stun on a 20-second cooldown")
	hero({"shield_bash":1},0)
	check(game.skills.reason("shield_bash")=="Requires sword and shield.","Shield Bash needs the shield")
	clear()
	# A stunned enemy does nothing until the stun ends.
	hero({"shield_bash":1})
	var brute = game.spawn_enemy("gladiator","brute",origin+forward*1.6)
	brute.awake = true; brute.max_hp = 100000; brute.hp = 100000
	game.invincible_test = true
	game.skills.cast("shield_bash",brute.position); wait(.5)
	var stood: Vector3 = brute.position
	var acted = false
	for i in 240:
		brute.tick(STEP)
		acted = acted or brute.windup>0 or brute.busy>0
	check(brute.stunned and not acted and brute.position.distance_to(stood)<.01,"A stunned enemy neither moves nor attacks")
	for i in 120:
		brute.tick(STEP)
		acted = acted or brute.windup>0 or brute.busy>0
	check(not brute.stunned and acted,"It attacks again once the stun ends")
	game.invincible_test = false
	clear()

	# Vampiric Strike: damage, a share of the target's whole health, and healing.
	hero({"vampiric_strike":1})
	var drained = dummy(1.6,0,1000.0)
	game.player.hp = 50
	check(game.skills.cast("vampiric_strike",drained.position) and game.run.energy==75,"Vampiric Strike costs 25 energy")
	wait(.6)
	check(lost(drained)>=38 and lost(drained)<=42,"Vampiric Strike rank 1 deals 80%% plus 3%% of the target's total health (%.1f)" % lost(drained))
	check(is_equal_approx(game.player.hp,53.0),"and heals 3% of the hero's own")
	hero({"vampiric_strike":5})
	drained.hp = 1000; game.player.hp = 50
	game.skills.cast("vampiric_strike",drained.position); wait(.6)
	check(lost(drained)>=132.5 and lost(drained)<=138.75 and is_equal_approx(game.player.hp,62.0),"Vampiric Strike rank 5: 125% plus 12%, healing 12%")
	clear()

	# Shadow Strike: a blow, then its listed damage over five seconds.
	hero({"shadow_strike":1})
	var shadowed = dummy(1.6)
	check(game.skills.cast("shadow_strike",shadowed.position) and game.run.energy==75,"Shadow Strike costs 25 energy")
	wait(.5)
	var blow: float = lost(shadowed)
	check(blow>=2.5 and blow<=4.5 and shadowed.dots.size()==1 and shadowed.dots[0].kind=="shadow","Shadow Strike rank 1 deals 25% and leaves its shadow")
	wait(5.2)
	check(lost(shadowed)-blow>=9.0 and lost(shadowed)-blow<=15.01 and shadowed.dots.is_empty(),"then 100%% more over 5 seconds (%.1f)" % (lost(shadowed)-blow))
	# It refreshes Cursed Blade's stacks on the target.
	hero({"shadow_strike":1,"cursed_blade":3})
	for i in 3: game.skills.strike(shadowed,10)
	wait(3.0)
	check(shadowed.dots.filter(func(d): return d.kind=="curse").all(func(d): return d.left<1.1),"Cursed Blade's stacks are running down")
	game.skills.cast("shadow_strike",shadowed.position); wait(.5)
	var curses: Array = shadowed.dots.filter(func(d): return d.kind=="curse")
	check(curses.size()==3 and curses.all(func(d): return d.left>3.9),"Shadow Strike starts them over")
	game.player.busy = 0; game.run.energy = 100
	game.skills.cast("shadow_strike",shadowed.position); wait(.5)
	check(shadowed.dots.filter(func(d): return d.kind=="shadow").size()==1,"A second Shadow Strike replaces the first's shadow")
	clear()

	# Execute: only on a wounded enemy.
	hero({"execute":1})
	var doomed = dummy(1.6,0,1000.0)
	doomed.hp = 500
	check(not game.skills.cast("execute",doomed.position) and game.run.energy==100 and game.player.busy==0,"Execute refuses an enemy above 20% health, at no cost")
	doomed.hp = 190
	check(game.skills.cast("execute",doomed.position) and game.run.energy==55,"Execute costs 45 energy, on an enemy below 20% health")
	wait(.8)
	check(190-doomed.hp>=20 and 190-doomed.hp<=30,"Execute rank 1 deals 200%")
	check(game.player.visual.state=="SkillExecute","with its own swing")
	hero({"execute":5})
	doomed.hp = 390
	check(game.skills.cast("execute",doomed.position),"Execute rank 5 opens below 40% health")
	wait(.8)
	check(390-doomed.hp>=45 and 390-doomed.hp<=67.5,"and deals 450%")
	clear()

	# Dash Attack: the dash strikes and pushes back whoever it passes through,
	# for extra energy.
	hero({"cleave":1})
	game.dash()
	check(game.run.energy==90 and not game.dash_attack,"Without Dash Attack a dash costs 10 energy")
	var dealt_by_rank: Array = []
	for r in [1,5]:
		hero({"dash_attack":r})
		var met = dummy(3.0)
		var spared = dummy(3.0,90.0)
		var cost: float = 25.0 if r==1 else 15.0
		game.run.energy = cost-1; game.dash()
		check(game.run.energy==cost-1 and game.dash_time<=0,"Dash Attack rank %d raises the dash to %d energy" % [r,cost])
		game.run.energy = 100; game.dash()
		game.dash_direction = forward; game.dash_speed = 41.0; game.player.face(origin+forward)
		check(game.run.energy==100-cost and game.dash_attack,"and the dash will strike")
		var before: Vector3 = met.position
		play(.5)
		dealt_by_rank.append(lost(met))
		check(lost(met)>0 and lost(spared)==0,"Rank %d's dash hits the enemy it passes through (%.1f), not one off its path" % [r,lost(met)])
		check(met.position.distance_to(before)>.4,"and pushes it back (%.2fm)" % met.position.distance_to(before))
		check(game.dash_struck.size()==1 and not game.dash_attack,"each enemy once, and the striking ends with the dash")
		clear()
	check(dealt_by_rank[1]>dealt_by_rank[0]*3.5,"Rank 5 hits for 50 to rank 1's 10")
	check(Book.values("dash_attack",1)==({"x":10.0,"y":15.0,"z":0.0}) and Book.values("dash_attack",3)==({"x":20.0,"y":11.0,"z":0.0}),"Dash Attack's damage and extra cost run 10/15/20/30/50 and 15/13/11/8/5")

	# Critical hits: 20%, and 0.2% more a point of Dexterity, for double damage,
	# rolled for every struck_dummy hit.
	hero({})
	check(is_equal_approx(Data.crit_chance(game.run),20.0),"A new hero crits 20% of the time")
	game.run.stats[1] += 10
	check(is_equal_approx(Data.crit_chance(game.run),22.0),"Each point of Dexterity adds 0.2%")
	game.run.stats[1] -= 10
	var struck_dummy = dummy(2.0)
	game.effects.clear()
	game.skills.strike(struck_dummy,10.0,"physical",0.0,Vector3.ZERO,false)
	var plain = lost(struck_dummy)
	check(game.effects[-1].node.modulate.r==1.0 and game.effects[-1].node.modulate.b==1.0,"A normal attack's number is white")
	game.skills.strike(struck_dummy,10.0)
	check(is_equal_approx(lost(struck_dummy),plain*2) and game.effects[-1].node.modulate.b<.5 and game.effects[-1].node.modulate.g>.8,"A skill's number is yellow")
	game.skills.crit_override = 1
	game.skills.strike(struck_dummy,10.0,"physical",0.0,Vector3.ZERO,false)
	var crit_number = game.effects[-1]
	check(is_equal_approx(lost(struck_dummy),plain*4),"A critical hit deals double damage")
	check(crit_number.node.modulate.g<.6 and crit_number.node.modulate.r==1.0 and crit_number.get("swell",false),"and shows its number in orange")
	game.tick_effects(.05)
	var early: float = crit_number.node.scale.x
	game.tick_effects(.2)
	check(early>1.0 and early<game.SWELL_SCALE and is_equal_approx(crit_number.node.scale.x,game.SWELL_SCALE),"growing quickly from the usual size to a larger one (%.2f, then %.2f)" % [early,crit_number.node.scale.x])
	game.skills.strike(struck_dummy,10.0)
	check(game.effects[-1].node.modulate.g<.6,"A skill's critical hit is orange too")
	game.skills.crit_override = -1
	seed(7)
	var crits = 0
	for i in 2000:
		game.skills.strike(struck_dummy,1.0)
		if game.effects[-1].get("swell",false): crits += 1
	check(crits>340 and crits<460,"Left to chance, about one hit in five crits (%d of 2000)" % crits)
	game.skills.crit_override = 0
	clear()
	# Cursed Blade's damage over time shows in purple.
	hero({"cursed_blade":1})
	var blighted = dummy(2.0)
	game.skills.strike(blighted,40.0)
	game.effects.clear()
	wait(1.0)
	check(not game.effects.is_empty() and game.effects.all(func(e): return e.node.modulate.b==1.0 and e.node.modulate.r<.8),"Cursed Blade's damage numbers are purple")
	clear()

	# Offensive Rhythm: every hit raises the next.
	hero({"offensive_rhythm":5})
	var struck = dummy(1.6)
	var dealt: Array = []
	for i in 12:
		var before: float = struck.hp
		game.skills.strike(struck,100)
		dealt.append(roundi(before-struck.hp))
	check(dealt.slice(0,4)==[100,130,160,190] and dealt[10]==400 and dealt[11]==400 and game.skills.offense_stacks==10,"Offensive Rhythm rank 5: +30% a stack, up to 10 stacks")
	wait(11.5)
	check(game.skills.offense_stacks==10,"The stacks last their 12 seconds")
	wait(.6)
	check(game.skills.offense_stacks==0 and game.skills.status()=="","and then lapse")
	hero({"offensive_rhythm":1})
	for i in 8: game.skills.strike(struck,100)
	var before_hit: float = struck.hp
	game.skills.strike(struck,100)
	check(is_equal_approx(before_hit-struck.hp,125.0),"Offensive Rhythm rank 1: +5% a stack, up to 5")
	clear()

	# Cursed Blade: extra damage over four seconds, in stacks.
	hero({"cursed_blade":1})
	var cursed = dummy(1.6)
	game.skills.strike(cursed,100)
	check(is_equal_approx(lost(cursed),100.0) and cursed.dots.size()==1,"The hit lands and leaves a curse")
	game.skills.strike(cursed,100)
	check(cursed.dots.size()==1,"Cursed Blade rank 1 holds one stack")
	wait(4.1)
	check(absf(lost(cursed)-210.0)<.05 and cursed.dots.is_empty(),"Cursed Blade rank 1: 10%% extra damage over 4 seconds (%.2f)" % (lost(cursed)-200.0))
	hero({"cursed_blade":5})
	cursed.hp = cursed.max_hp
	for i in 10: game.skills.strike(cursed,100)
	check(cursed.dots.size()==8,"Cursed Blade rank 5 stacks 8 times")
	wait(4.1)
	check(absf(lost(cursed)-(1000.0+8*65.0))<.05,"each stack 65% of its hit")
	var weak = dummy(1.6,30,105.0)
	game.skills.strike(weak,100)
	check(not weak.dead,"A cursed enemy survives the hit")
	wait(4.1)
	check(weak.dead,"and falls to the curse")
	var dazed = dummy(1.6,-30)
	game.skills.strike(dazed,100); dazed.stun(5.0)
	wait(.1)
	check(not dazed.stunned,"The curse's damage breaks a stun")
	clear()

	# Shield Expertise, Spiked Shield and Defensive Rhythm.
	hero({})
	var attacker = dummy(1.6)
	game.player.hp = 100; game.hurt_player(10,"physical",attacker)
	var normal: float = 100-game.player.hp
	hero({"shield_expertise":5,"spiked_shield":5})
	seed(20261002)
	var blocks = 0; var spiked = 0
	for i in 400:
		game.player.hp = 100; game.player.invulnerable = 0
		var attacker_hp: float = attacker.hp
		game.hurt_player(10,"physical",attacker)
		var taken: float = 100-game.player.hp
		if is_equal_approx(taken,normal*.2):
			blocks += 1
			var answer: float = attacker_hp-attacker.hp
			if answer>=8.0 and answer<=12.0: spiked += 1
		else: check(is_equal_approx(taken,normal) and attacker.hp==attacker_hp,"An unblocked hit lands whole and unanswered")
	check(blocks>=160 and blocks<=240,"Shield Expertise rank 5 blocks half of all attacks (%d of 400), which then deal 80%% less" % blocks)
	check(spiked==blocks,"Spiked Shield rank 5 answers every block with 80% of a normal attack")
	hero({"shield_expertise":5},0)
	var unshielded = 0
	for i in 60:
		game.player.hp = 100; game.player.invulnerable = 0
		game.hurt_player(10,"physical",attacker)
		if not is_equal_approx(100-game.player.hp,normal): unshielded += 1
	check(unshielded==0,"There is no blocking without the shield")
	hero({"defensive_rhythm":5})
	var hits: Array = []
	for i in 8:
		game.player.hp = 100; game.player.invulnerable = 0
		game.hurt_player(10,"physical",attacker)
		hits.append((100-game.player.hp)/normal)
	check(is_equal_approx(hits[0],1.0) and is_equal_approx(hits[1],.88) and is_equal_approx(hits[6],.28) and is_equal_approx(hits[7],.28) and game.skills.defense_stacks==6,"Defensive Rhythm rank 5: 12% less damage a stack, up to 6 stacks")
	wait(12.1)
	check(game.skills.defense_stacks==0,"Its stacks lapse after their 12 seconds")
	clear()

	# Attack speed: Dexterity for every melee swing, Quick Strikes for normal attacks.
	hero({})
	check(is_equal_approx(game.attack_profile().duration,.84),"A sword swing takes .84 seconds")
	game.run.stats[1] = 25
	check(is_equal_approx(game.attack_profile().duration,.84/1.2),"Twenty points of Dexterity make it 20% faster")
	game.run.skills = {"cleave":1,"quick_strikes":1}
	check(is_equal_approx(game.attack_profile().duration,.84/1.4),"Quick Strikes rank 1 adds 20% more")
	var target = dummy(1.6)
	game.attack(false,target.position)
	check(is_equal_approx(game.player.busy,.84/1.4) and is_equal_approx(game.scheduled[-1].time,.84/1.4*.52),"The quicker swing lands and recovers sooner")
	ready()
	game.skills.cast("cleave",target.position)
	check(is_equal_approx(game.player.busy,1.0/1.2),"Skills quicken with Dexterity, not with Quick Strikes")
	game.run.skills = {"quick_strikes":5}; game.run.stats[1] = 5
	check(is_equal_approx(game.attack_profile().duration,.84/2.7),"Quick Strikes rank 5: 170% faster")
	game.run.stats[1] = 300
	check(is_equal_approx(game.attack_profile().duration,Data.MELEE_MINIMUM),"No swing is quicker than a fifth of a second")
	game.run.weapon = 2; game.run.stats[1] = 25; game.run.skills = {"quick_strikes":5}
	check(is_equal_approx(game.attack_profile().duration,.78),"Neither speeds a bow")
	clear()

	# The sword's normal attack: three swings that follow one another while he
	# keeps swinging, starting over when he breaks off.
	hero({})
	target = dummy(1.6)
	var swings: Array = []
	var landed: Array = []
	for i in 5:
		game.attack(false,target.position)
		swings.append(game.player.visual.state)
		landed.append(is_equal_approx(game.player.busy,.84) and is_equal_approx(game.scheduled[-1].time,.84*.52))
		while game.player.busy > 0: play(STEP)
	check(swings == ["SwordOpen","SwordCut2L","SwordThrustR","SwordCut1L","SwordCut2R"],"Swinging on, the sword cuts down one way, then the other, then thrusts, and round again, stepping with each foot in turn: %s" % [swings])
	check(not false in landed,"Every swing of the three takes the sword's time and lands at the same moment of it")
	play(.3)
	check(game.player.visual.state == "SwordCut2R" and game.player.visual.swing_phase() > .85,"Standing after a swing, he recovers to his stance")
	game.attack(false,target.position)
	check(game.player.visual.state == "SwordOpen","Broken off, the swings start over from the first")
	while game.player.busy > 0: play(STEP)
	game.player.visual.locomotion(true,false)
	game.attack(false,target.position)
	check(game.player.visual.state == "SwordOpen","Moving between swings starts them over too")
	# The cuts leave a wake of air behind the blade; the thrust leaves none.
	var wake = game.player.visual.sword_trail
	play(.84*.4)
	check(wake.samples.is_empty() and wake.mesh.get_surface_count() == 0,"Winding up, the blade leaves no wake")
	play(.84*.15)
	check(wake.samples.size() >= 3 and wake.mesh.get_surface_count() == 1,"Cutting, the blade trails a wake of air (%d places)" % wake.samples.size())
	check(wake.samples[-1][2].distance_to(game.player.visual.weapon_item.global_transform*Vector3(0,1.02,0)) < .02,"The wake follows the blade's point")
	while game.player.busy > 0: play(STEP)
	check(wake.samples.is_empty(),"The wake is gone by the swing's end")
	game.attack(false,target.position); play(.84*.5)
	game.attack(false,target.position)
	while game.player.busy > 0: play(STEP)
	game.attack(false,target.position)
	var thrust_wake = 0
	while game.player.busy > 0:
		play(STEP)
		thrust_wake = maxi(thrust_wake,wake.samples.size())
	check(game.player.visual.state == "SwordThrustR" and thrust_wake == 0,"The thrust leaves no wake")
	clear()

	# The panels: attributes on the left, the skill tree on the right.
	hero({"cleave":1})
	Data.gain_xp(game.run,Data.xp_at_level(6))
	game.mode = "playing"
	game.hud.tick(0)
	var panels = game.hud.panels
	check(game.run.points==25 and game.run.skill_points==5 and panels.stat_plus.visible and panels.skill_plus.visible,"Five levels: 25 attribute points, 5 skill points, and both + buttons")
	panels.stat_plus.pressed.emit()
	check(game.mode=="character" and panels.stats_open() and not panels.skills_open(),"The left + opens the attribute panel")
	panels.add_stat(0); panels.add_stat(3)
	check(game.run.stats==[6,5,5,6,5] and game.run.points==23 and game.player.max_hp==110,"Its + buttons spend points on any attribute")
	panels.skill_plus.pressed.emit()
	check(panels.skills_open() and panels.stats_open() and panels.nodes.size()==19,"The right + opens the tree beside it: nineteen warrior skills")
	game.hud.tick(0)
	check(panels.nodes.leap.state=="locked" and panels.nodes.cleave.state=="learned" and panels.nodes.powerful_strike.state=="open","Skills behind a requirement show as locked")
	panels.nodes.leap.button.pressed.emit()
	check(not game.run.skills.has("leap") and game.run.skill_points==5,"A locked skill cannot be learned")
	panels.nodes.powerful_strike.button.pressed.emit()
	check(game.run.skills.powerful_strike==1 and game.run.hotbar==["cleave","powerful_strike",""],"Clicking learns a skill; a new active skill takes the first empty slot")
	for i in 4: panels.nodes.cleave.button.pressed.emit()
	game.hud.tick(0)
	check(game.run.skills.cleave==5 and game.run.skill_points==0 and panels.nodes.cleave.state=="maxed" and panels.nodes.leap.state=="open","Five points in the tree open its next row")
	check(not panels.skill_plus.visible and not panels.stat_plus.visible,"The + buttons are gone while their panels are open")
	panels.hovered = "powerful_strike"
	panels.assign("powerful_strike",2)
	check(game.run.hotbar==["cleave","","powerful_strike"],"A learned skill can be moved to another slot")
	panels.assign("endurance",1)
	check(game.run.hotbar==["cleave","","powerful_strike"],"Unlearned and passive skills cannot be assigned")
	game.combat_age = 0
	panels.assign("powerful_strike",0)
	check(game.run.hotbar==["cleave","","powerful_strike"],"Slots are not swapped in combat")
	game.combat_age = 10
	game.resume_game(); game.hud.tick(0)
	check(game.mode=="playing" and not panels.any_open() and panels.stat_plus.visible and not panels.skill_plus.visible,"Closed, the attribute + stays until its points are spent; the skill + is gone with its points")
	check(Save.valid(game.run),"The character is save-valid throughout")
	FileAccess.open("res://test-results/warrior-skills.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("WARRIOR_SKILLS ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
