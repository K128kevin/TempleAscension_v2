extends SceneTree
## The ranger's three skill trees in play: every skill's listed numbers, on an
## open plane with passive stand-in enemies.
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
const Temple = preload("res://scripts/temple.gd")
const Actor = preload("res://scripts/actor.gd")
const Art = preload("res://scripts/assets.gd")
const Motion = preload("res://scripts/combat_animation.gd")
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

func open_plane():
	game.run = Data.new_run("ranger")
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
	for p in game.projectiles: p.node.queue_free()
	game.projectiles.clear()
	for e in game.enemies: e.dead = true; e.visible = false; e.queue_free()
	game.enemies.clear()

# A ranger with these ranks, the bow (2) or the dagger (5) in hand, ready to act.
func hero(ranks: Dictionary, weapon: int = 2):
	game.run = Data.new_run("ranger")
	game.run.skills = ranks
	# As the hero who spent his first point on Power Shot, which waits on RMB.
	game.run.skill_points = 0
	if ranks.has("power_shot"): game.run.hotbar[0] = "power_shot"
	game.run.weapon = weapon
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

# The whole hero runs: movement, swings, arrows in flight.
func play(seconds: float):
	for i in ceili(seconds/STEP):
		game.player.tick(STEP)
		game.tick_scheduled(STEP)
		game.skills.tick(STEP)
		game.player_control(STEP)
		game.tick_projectiles(STEP)
		for e in game.enemies: e.tick(STEP)

func lost(e) -> float: return e.max_hp-e.hp
# `hits` blows of `percent` of a normal attack (10 to 15 a blow, at 5 Dexterity).
func within(e, hits: float, percent: float) -> bool:
	return lost(e) >= 10.0*hits*percent*.01-.01 and lost(e) <= 15.0*hits*percent*.01+.01

func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/ranger-skills-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	open_plane()
	var at: Vector3 = origin+forward*6.0

	# The roster and the trees.
	var mine: Array = Book.all().values().filter(func(s): return s.class_id=="ranger")
	check(mine.size()==20 and Book.trees("ranger")==["attack","utility","passive"],"The ranger has twenty skills in Attacks, Utility and Passive")
	check(mine.filter(func(s): return s.tree=="attack").size()==7 and mine.filter(func(s): return s.tree=="utility").size()==7 and mine.filter(func(s): return s.tree=="passive").size()==6,"Seven attacks, seven utility skills, six passives")
	var fresh = Data.new_run("ranger")
	check(fresh.owned[2] and fresh.owned[5] and fresh.weapon==2 and fresh.skills.is_empty() and fresh.skill_points==1 and Save.valid(fresh),"A new ranger carries a bow and a dagger, and has a skill point to spend")
	check(not Book.locked(fresh,"volley").is_empty() and not Book.locked(fresh,"frenzy").is_empty() and Book.locked(fresh,"flurry").is_empty(),"Skills open by the points spent in their own tree")
	for clip in ["DaggerStab","DaggerSlash","SkillFlurry2","SkillFlurry3","SkillFlurry4","SkillTripleSlash","SkillAmbush","SkillSandR","SkillSandL","SkillHide","SneakIdle","SkillVolley"]:
		check(game.player.visual.clips.has(clip),"The ranger's clip is there: "+clip)

	# The dagger: the normal attack, a stab and a slash by turns, by Dexterity.
	hero({},5)
	var foe = dummy(1.6)
	check(game.player.visual.weapon_kind=="dagger" and game.attack_range(false)==1.9,"With the dagger he fights at arm's length")
	game.attack(false,foe.position)
	var first: String = game.player.visual.state
	check(is_equal_approx(game.player.busy,.5),"A dagger attack takes half a second")
	while game.player.busy>0: play(STEP)
	game.attack(false,foe.position)
	check([first,game.player.visual.state]==["DaggerSlash","DaggerStab"] or [first,game.player.visual.state]==["DaggerStab","DaggerSlash"],"The dagger stabs and slashes by turns")
	while game.player.busy>0: play(STEP)
	check(within(foe,2,100),"Each dagger attack lands for a normal attack's damage (%.1f)" % lost(foe))
	game.run.stats[1] = 30
	foe.hp = foe.max_hp
	game.attack(false,foe.position)
	while game.player.busy>0: play(STEP)
	check(lost(foe)>=10-.01 and lost(foe)<=15+.01,"Dexterity does not raise the dagger's damage")
	game.run.stats[1] = 5; game.run.stats[0] = 30
	foe.hp = foe.max_hp
	game.attack(false,foe.position)
	while game.player.busy>0: play(STEP)
	check(lost(foe)>=10*1.5-.01 and lost(foe)<=15*1.5+.01,"Strength raises the dagger's damage as every melee weapon's")
	clear()

	# Rapid Fire.
	hero({"rapid_fire":1})
	foe = dummy(6)
	check(game.skills.cast("rapid_fire",at) and is_equal_approx(game.run.energy,65.0),"Rapid Fire rank 1 costs 35 energy")
	play(1.5)
	check(within(foe,2,100),"and fires two arrows in a row (%.1f)" % lost(foe))
	hero({"rapid_fire":5}); foe.hp = foe.max_hp
	check(game.skills.cast("rapid_fire",at) and is_equal_approx(game.run.energy,80.0),"Rank 5 costs 20")
	check(game.player.busy<1.2,"its four arrows loosed quickly (%.2fs)" % game.player.busy)
	play(1.8)
	check(within(foe,4,100),"and fires four (%.1f)" % lost(foe))
	clear()

	# Power Shot: the aim, then the shot.
	hero({"power_shot":1})
	foe = dummy(6)
	check(game.skills.cast("power_shot",at) and is_equal_approx(game.run.energy,70.0),"Power Shot costs 30 energy")
	play(1.5)
	game.hud.show_cast_bars()
	check(game.hud.aim_bar != null and game.hud.aim_bar.visible and absf(game.hud.aim_bar.value-.5)<.03,"A bar over his head shows the aim, half full halfway through")
	play(1.3)
	check(lost(foe)==0 and game.player.busy>0 and game.player.visual.state=="ArcherShot","Rank 1 aims for three seconds, the bow held drawn")
	play(.6)
	check(within(foe,1,200),"then deals 200%% (%.1f)" % lost(foe))
	game.hud.show_cast_bars()
	check(not game.hud.aim_bar.visible,"and the bar is gone with the shot")
	game.player.busy = 0; game.run.energy = 100; foe.hp = foe.max_hp
	game.skills.cast("power_shot",at); play(.5)
	game.dash(); play(3.5)
	game.hud.show_cast_bars()
	check(lost(foe)==0 and game.skills.aim_total==0 and not game.hud.aim_bar.visible,"Dashing lets the aim go: no shot, and no bar")
	ready()
	hero({"power_shot":5}); foe.hp = foe.max_hp
	game.skills.cast("power_shot",at)
	play(.9)
	check(lost(foe)==0,"Rank 5 aims for one second")
	play(.5)
	check(within(foe,1,400),"and deals 400%% (%.1f)" % lost(foe))
	clear()

	# Flurry: he takes up the dagger for it.
	hero({"flurry":1})
	foe = dummy(1.6)
	check(game.skills.reason("flurry").is_empty() and game.skills.cast("flurry",foe.position) and game.run.weapon==5 and game.player.visual.weapon_kind=="dagger","Cast with the bow in hand, Flurry takes up the dagger")
	check(game.player.visual.state=="SkillFlurry2" and is_equal_approx(game.run.energy,75.0),"Flurry costs 25 energy and has its own motion")
	play(1.2)
	check(within(foe,2,100),"Rank 1 stabs twice for 100%% (%.1f)" % lost(foe))
	hero({"flurry":5},5); foe.hp = foe.max_hp
	game.skills.cast("flurry",foe.position)
	check(game.player.visual.state=="SkillFlurry4","Rank 5's four stabs have their own motion")
	play(1.5)
	check(within(foe,4,275),"Rank 5 stabs four times for 275%% (%.1f)" % lost(foe))
	game.run.owned[5] = false; game.run.weapon = 2
	check(game.skills.reason("flurry")=="Requires dagger.","Without a dagger, Flurry cannot be used")
	clear()

	# Volley.
	hero({"volley":5})
	var crowd: Array = []
	for spot in [Vector3(0,0,0),Vector3(1.5,0,0),Vector3(-1.5,0,.5),Vector3(0,0,1.6),Vector3(.8,0,-1.5)]:
		var e = dummy(6)
		e.position = at+spot
		crowd.append(e)
	var far = dummy(6)
	far.position = at+Vector3(7,0,0)
	check(game.skills.cast("volley",at) and is_equal_approx(game.run.energy,60.0) and game.player.visual.state=="SkillVolley","Volley costs 40 energy and is loosed high")
	play(.75)
	check(game.skills.falls.size()==30,"Rank 5 sends thirty arrows up")
	play(1.6)
	var struck: float = 0.0
	for e in crowd: struck += lost(e)
	check(game.skills.falls.is_empty() and struck>=10*1.5-.01 and struck<=30*15*1.5+.01 and lost(far)==0,"They come down within the area aimed at, each for 150%% on whoever it lands by (%.1f in all)" % struck)
	clear()

	# Lightning Shot.
	hero({"lightning_shot":5})
	var line: Array = []
	for i in 7:
		var e = dummy(6)
		e.position = at+Vector3((i%2)*3.0-1.5 if i>0 else 0.0,0,-2.2*i)
		line.append(e)
	var outside = dummy(6)
	outside.position = at+Vector3(-11,0,0)
	check(game.skills.cast("lightning_shot",at) and is_equal_approx(game.run.energy,65.0),"Lightning Shot costs 35 energy")
	play(1.2)
	var leapt = line.filter(func(e): return lost(e)>0).size()
	check(leapt==6 and within(line[0],1,250) and within(line[1],1,200) and within(line[5],1,250*pow(.8,5)) and lost(line[6])==0 and lost(outside)==0,"Rank 5 strikes for 250%% and leaps to five more, each within 10 meters of the last and 20%% weaker than the strike before (%d struck)" % leapt)
	hero({"lightning_shot":1})
	for e in line: e.hp = e.max_hp
	game.skills.cast("lightning_shot",at)
	play(1.2)
	check(line.filter(func(e): return lost(e)>0).size()==2 and within(line[1],1,80),"Rank 1 leaps once, for 80%")
	clear()

	# Frenzy.
	hero({"frenzy":1})
	var normal: float = game.attack_profile().duration
	check(game.skills.cast("frenzy",at) and game.run.energy==Data.max_energy(game.run) and game.player.busy==0,"Frenzy costs nothing and takes no time")
	check(is_equal_approx(game.attack_profile().duration,normal/1.1),"Rank 1: attacks 10% faster")
	check(game.skills.reason("frenzy").begins_with("Recharging: 30"),"It recharges for 30 seconds")
	play(5.5)
	check(game.skills.frenzy_time>0 and is_instance_valid(game.skills.frenzy_aura),"It lasts six seconds, and shows on him")
	play(.7)
	check(is_equal_approx(game.attack_profile().duration,normal) and not is_instance_valid(game.skills.frenzy_aura),"then ends")
	hero({"frenzy":5},5)
	normal = game.attack_profile().duration
	game.skills.cast("frenzy",at)
	check(is_equal_approx(game.attack_profile().duration,normal/1.35) and is_equal_approx(game.skills.frenzy_time,15.0),"Rank 5: 35% faster for 15 seconds, with the dagger as with the bow")
	clear()

	# Triple Slash.
	hero({"triple_slash":1},5)
	foe = dummy(1.6)
	var at_back = dummy(1.2,180)
	var beside: Array = [at_back,dummy(1.9,35),dummy(2.2,65),dummy(3.4,-35)]
	check(game.skills.cast("triple_slash",foe.position) and is_equal_approx(game.run.energy,75.0) and game.player.visual.state=="SkillTripleSlash","Triple Slash costs 25 energy and has its own motion")
	play(1.3)
	var others = beside.filter(func(e): return lost(e)>0)
	check(within(foe,3,130) and others.size()==2 and within(others[0],3,130),"Rank 1 cuts the target three times for 130%% and the two nearest around him (%.1f, %d others)" % [lost(foe),others.size()])
	check(lost(at_back)>0 and lost(beside[3])==0,"Those it reaches are around him, behind him too, not beside the target")
	clear()

	# Slow Shot.
	hero({"slow_shot":1})
	foe = dummy(6)
	check(game.skills.cast("slow_shot",at) and is_equal_approx(game.run.energy,80.0),"Slow Shot costs 20 energy")
	play(1.0)
	check(within(foe,1,100) and is_equal_approx(foe.slow_factor,.7) and foe.slow_time>1.8 and foe.slow_time<=3.0,"Rank 1 slows its target by 30% for 3 seconds")
	hero({"slow_shot":5})
	game.skills.cast("slow_shot",at)
	play(1.0)
	check(is_equal_approx(foe.slow_factor,.25) and foe.slow_time>4.8,"Rank 5 by 75% for 6")
	clear()

	# Weakening Strike: with either weapon; critical strikes on the target deal more.
	hero({"weakening_strike":1})
	foe = dummy(6)
	check(game.skills.cast("weakening_strike",at) and is_equal_approx(game.run.energy,85.0) and game.run.weapon==2,"Weakening Strike costs 15 energy, and with the bow is a shot")
	play(1.0)
	check(within(foe,1,100) and foe.weak_stacks==1 and is_equal_approx(foe.weak_bonus,10.0),"It hits and leaves one stack")
	game.player.busy = 0; game.skills.cast("weakening_strike",at); play(1.0)
	game.player.busy = 0; game.skills.cast("weakening_strike",at); play(1.0)
	check(foe.weak_stacks==2,"Rank 1 stacks twice at most")
	foe.hp = foe.max_hp
	game.skills.crit_override = 1
	game.skills.strike(foe,10.0)
	check(is_equal_approx(lost(foe),10.0*Data.CRIT_MULTIPLIER*1.2),"Two stacks of 10%: a critical strike on it deals a fifth more")
	game.skills.crit_override = 0
	for i in 400: foe.tick(STEP)
	check(foe.weak_stacks==0,"The stacks last six seconds")
	clear()
	hero({"weakening_strike":5},5)
	foe = dummy(1.6)
	check(game.skills.cast("weakening_strike",foe.position) and game.run.weapon==5 and game.player.visual.state=="DaggerSlash","With the dagger in hand it is a cut")
	play(.8)
	check(within(foe,1,100) and foe.weak_stacks==1 and is_equal_approx(foe.weak_bonus,15.0) and Book.values("weakening_strike",5).y==5,"which hits and weakens as the shot does (rank 5: 15% a stack, five stacks)")
	clear()

	# Hide in Shadows.
	hero({"hide_in_shadows":1})
	var pace: float = game.player_pace()
	foe = dummy(6)
	check(game.skills.reason("hide_in_shadows")=="Hide in Shadows needs you out of combat.","Hide in Shadows cannot be cast in combat")
	foe.awake = false
	check(game.skills.cast("hide_in_shadows",at) and is_equal_approx(game.run.energy,80.0),"Out of combat it costs 20 energy")
	play(.6)
	check(game.skills.hidden and game.player.visual.shadowed and is_equal_approx(game.player_pace(),pace*.5),"Hidden, he is drawn in shadow and moves 50% slower at rank 1")
	check(game.player.visual.state=="SneakIdle","and waits crouched")
	foe.puppet = false
	foe.position = origin+forward*4.0
	play(1.0)
	check(not foe.awake,"An enemy he passes does not see him")
	game.attack(false,foe.position)
	check(not game.skills.hidden and not game.player.visual.shadowed,"Attacking ends it")
	clear()
	hero({"hide_in_shadows":5,"element_of_surprise":1})
	check(game.skills.cast("hide_in_shadows",at),"Hidden again")
	play(.6)
	check(is_equal_approx(game.player_pace(),pace*.85),"Rank 5 slows him by only 15%")
	game.hurt_player(1.0)
	check(not game.skills.hidden,"Being struck ends it")
	check(is_equal_approx(game.skills.surprise_bonus,40.0) and is_equal_approx(game.skills.surprise_time,4.0),"Element of Surprise rank 1: 40% more damage for 4 seconds after")
	foe = dummy(1.6)
	game.skills.strike(foe,10.0)
	check(is_equal_approx(lost(foe),14.0),"which every hit of his deals")
	game.skills.tick(4.1)
	foe.hp = foe.max_hp
	game.skills.strike(foe,10.0)
	check(is_equal_approx(lost(foe),10.0),"until it runs out")
	game.player.busy = 0; game.combat_age = 10; foe.awake = false
	game.skills.cast("hide_in_shadows",at); play(.6)
	game.run.energy = 100
	game.dash()
	check(not game.skills.hidden,"Dashing ends it")
	clear()

	# Throw Sand.
	hero({"throw_sand":1})
	foe = dummy(2.4)
	foe.puppet = false
	var beyond = dummy(4.5)
	check(game.skills.cast("throw_sand",foe.position) and is_equal_approx(game.run.energy,60.0) and game.player.visual.state=="SkillSandR","Throw Sand costs 40 energy, thrown with the free right hand when he holds the bow")
	play(.6)
	check(foe.daze=="confuse" and foe.stagger_time>2.0 and beyond.daze=="","An enemy within 3 meters is blinded for 3 seconds; one beyond is not")
	var from: Vector3 = foe.position
	var hurt: float = game.player.hp
	play(1.5)
	check(foe.position.distance_to(from)>.2 and game.player.hp==hurt and foe.windup<=0,"Blinded, it wanders and does not attack")
	foe.hit(1.0)
	check(foe.daze=="" and not foe.stunned,"Damage ends it")
	check(game.skills.reason("throw_sand").begins_with("Recharging: 4"),"It recharges for 45 seconds")
	hero({"throw_sand":5},5)
	# (It has wandered: put back in reach.)
	foe.position = origin+forward*2.4
	game.skills.cast("throw_sand",foe.position)
	check(game.player.visual.state=="SkillSandL","With the dagger in his right hand he throws with the left")
	play(.6)
	check(foe.daze=="confuse" and foe.stagger_time>11.0,"Rank 5 blinds for 12 seconds")
	clear()

	# Tranquilizer.
	hero({"tranquilizer":1})
	foe = dummy(6)
	check(game.skills.cast("tranquilizer",at) and is_equal_approx(game.run.energy,60.0),"Tranquilizer costs 40 energy")
	play(1.0)
	check(foe.daze=="sleep" and lost(foe)==0 and foe.stagger_time>2.0 and foe.stagger_time<=3.0,"Its arrow does no harm, and puts the target to sleep for 3 seconds")
	foe.hit(1.0)
	check(foe.daze=="","Damage wakes it")
	check(game.skills.reason("tranquilizer").begins_with("Recharging: 4"),"It recharges for 45 seconds")
	clear()

	# Vanish.
	hero({"vanish":1})
	foe = dummy(5)
	foe.puppet = false
	game.combat_age = 0
	check(game.skills.cast("vanish",at) and is_equal_approx(game.run.energy,60.0) and game.skills.hidden,"Vanish costs 40 energy and hides him at once, in combat")
	check(not foe.awake and game.player.busy==0,"Every enemy loses him")
	play(1.0)
	check(not foe.awake and foe.windup<=0,"and does not find him again while he is hidden")
	game.skills.leave_shadows()
	check(game.skills.reason("vanish").begins_with("Recharging: 5") or game.skills.reason("vanish").begins_with("Recharging: 60"),"It recharges for 60 seconds")
	play(.5)
	check(foe.awake,"Seen again, he is fought again")
	clear()

	# Surprise Attack.
	hero({"surprise_attack":1,"vanish":1})
	foe = dummy(1.6)
	check(game.skills.reason("surprise_attack")=="Surprise Attack needs you hidden in shadows.","Surprise Attack needs him hidden")
	game.skills.cast("vanish",at)
	check(game.skills.cast("surprise_attack",foe.position) and is_equal_approx(game.run.energy,10.0) and game.player.visual.state=="SkillAmbush","Hidden, it costs 50 energy and has its own motion")
	play(.7)
	check(foe.daze=="ambush" and foe.stagger_time>2.0 and not game.skills.hidden,"Rank 1 stuns for 3 seconds, and brings him out of the shadows")
	foe.hit(10.0)
	check(is_equal_approx(lost(foe),12.0) and foe.daze=="ambush","The stunned enemy takes 20% more damage, and the stun holds")
	for i in 200: foe.tick(STEP)
	foe.hp = foe.max_hp
	foe.hit(10.0)
	check(foe.daze=="" and is_equal_approx(lost(foe),10.0),"until its time is up")
	clear()

	# The passives.
	hero({"swift_footed":5})
	check(is_equal_approx(game.player_pace(),pace*1.4),"Swift Footed rank 5: 40% faster")
	hero({"bow_specialization":5,"dagger_specialization":1})
	check(is_equal_approx(Data.specialization(game.run,2).x,30.0) and is_equal_approx(Data.specialization(game.run,5).x,4.0) and Data.specialization(game.run,1).x==0,"The specializations add to the chance of a critical strike with their own weapon")
	foe = dummy(1.6)
	game.skills.crit_override = 1
	game.skills.strike(foe,10.0,"physical",0.0,Vector3.ZERO,true,2)
	check(is_equal_approx(lost(foe),10.0*Data.CRIT_MULTIPLIER*2.5),"Bow Specialization rank 5: the bow's critical strikes deal 150% extra")
	foe.hp = foe.max_hp
	game.skills.strike(foe,10.0,"physical",0.0,Vector3.ZERO,true,5)
	check(is_equal_approx(lost(foe),10.0*Data.CRIT_MULTIPLIER*1.25),"Dagger Specialization rank 1: the dagger's, 25%")
	clear()
	hero({"poisons":1})
	foe = dummy(1.6)
	game.skills.strike(foe,100.0,"physical",0.0,Vector3.ZERO,true,2)
	game.skills.strike(foe,100.0,"physical",0.0,Vector3.ZERO,true,5)
	check(foe.dots.filter(func(d): return d.kind=="poison").size()==1,"Poisons rank 1: one stack at most, from arrow or dagger")
	for i in 330: foe.tick(STEP)
	check(absf(lost(foe)-210.0)<.6 and foe.dots.is_empty(),"10%% of the hit, over 5 seconds (%.1f)" % lost(foe))
	hero({"poisons":5})
	for i in 10: game.skills.strike(foe,100.0)
	check(foe.dots.filter(func(d): return d.kind=="poison").size()==8,"Rank 5 stacks eight times")
	clear()
	hero({"penetrating_arrows":1})
	foe = dummy(5)
	var behind = dummy(8)
	game.attack(false,at)
	play(1.6)
	check(within(foe,1,100) and within(behind,1,100),"Penetrating Arrows: the arrow carries on through its target to the one behind")
	clear()
	hero({"penetrating_arrows":1})
	foe = dummy(5)
	var past_reach = dummy(game.ARROW_REACH+2.0)
	game.attack(false,at)
	play(2.5)
	check(within(foe,1,100) and lost(past_reach)==0,"Penetrating Arrows do not carry an arrow past the bow's reach")
	clear()
	hero({})
	foe = dummy(5)
	behind = dummy(8)
	game.attack(false,at)
	play(1.6)
	check(within(foe,1,100) and lost(behind)==0,"Without it, an arrow stops in the first it strikes")
	clear()

	# X changes between bow and dagger, in combat too.
	hero({})
	game.resume_game()
	game.combat_age = 0
	game.swap_weapon()
	check(game.run.weapon==5 and game.player.visual.weapon_kind=="dagger","X takes up the dagger")
	game.swap_weapon()
	check(game.run.weapon==2 and game.player.visual.weapon_kind=="bow","and the bow again")

	# A save from before these skills: the ranger's points are refunded, the dagger his.
	var old = Data.new_run("ranger")
	old.version = 7
	old.owned = [false,false,true,false,false]
	old.skills = {"power_shot":1}; old.skill_points = 0
	old.level = 1
	var migrated = Save.migrate(old)
	check(Save.valid(old) and migrated.version==9 and migrated.owned.size()==6 and migrated.owned[5] and migrated.skills.is_empty() and migrated.skill_points==1,"An older ranger's save is carried over: skill points refunded, a dagger at his belt")
	game.run.skills = {"power_shot":1}; game.run.skill_points = 0
	check(Save.valid(game.run),"The character is save-valid throughout")
	FileAccess.open("res://test-results/ranger-skills.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("RANGER_SKILLS ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
