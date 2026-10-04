extends Node
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const Shockwave = preload("res://scripts/shockwave.gd")
const WarCry = preload("res://scripts/war_cry.gd")
const Art = preload("res://scripts/assets.gd")
const StoneFragment = preload("res://scripts/stone_fragment.gd")
const RangerFx = preload("res://scripts/ranger_fx.gd")
const Motion = preload("res://scripts/combat_animation.gd")
var game
var pending: Array = []
var zones: Array = []
var barrier = 0.0
var barrier_time = 0.0
# Seconds until a skill with a cooldown (Shield Bash) is ready again.
var cooldowns: Dictionary = {}
# Shield Charge under way: how long he runs on, which way, and who he has hit.
var charge: Dictionary = {}
# Shockwaves and War Cry rings under way (scripts/shockwave.gd, war_cry.gd).
var waves: Array = []
# Offensive and Defensive Rhythm: the stacks built, and how long they last.
# Tests fix the crit roll: -1 rolls, 0 never crits, 1 always does.
var crit_override = -1
var offense_stacks = 0
var offense_time = 0.0
var defense_stacks = 0
var defense_time = 0.0
# The ranger. Hidden in the shadows (no enemy sees him; he moves `hide_slow`
# percent slower); Element of Surprise's damage after he leaves them; Frenzy's
# faster attacks; and the things in the air: Volley's arrows, and effects
# that are drawn for a moment ([node, seconds left]).
var hidden = false
var hide_slow = 0.0
var surprise_bonus = 0.0
var surprise_time = 0.0
var frenzy_bonus = 0.0
var frenzy_time = 0.0
var frenzy_aura: Node3D
var charge_glow: Node3D
# Power Shot being aimed: how long the aim is, and how much of it is left (the
# HUD shows it as a bar over his head).
var aim_total = 0.0
var aim_left = 0.0
# How long each timed effect on the hero lasted when it was last begun or
# refreshed (for the HUD's bars, which run down from it): by effect.
var lasting: Dictionary = {}
var falls: Array = []
var passing: Array = []
# How far the ranger's blade reaches, how far he throws sand, how wide a
# Volley falls and how near its arrows must land to hit, how far lightning
# leaps, and how long the cooldowns the document gives are.
const SAND_REACH = 3.0
# (Twice the ground it once covered: the radius by the root of two.)
const VOLLEY_RADIUS = 4.25
# Between one arrow's fall and the next's.
const VOLLEY_STAGGER = .05/3.0
const VOLLEY_HIT = 1.1
const VOLLEY_FALL = .45
const LIGHTNING_LEAP = 10.0
# How much of the last strike's damage Lightning Shot carries to the next.
const LIGHTNING_FADE = .8
const POISON_SECONDS = 5.0
const FRENZY_COOLDOWN = 30.0
const SAND_COOLDOWN = 45.0
const TRANQ_COOLDOWN = 45.0
# How far round him Triple Slash reaches the others it hits.
const TRIPLE_AROUND = 2.6
# The ranger's blows made at arm's length, aimed by facing as the warrior's.
const RANGER_BLOWS = ["flurry","triple","sand","ambush"]
# Each of the ranger's skills has its own motion (tools/import_ranger.py):
# its clip, how long it plays, and how far through it each blow lands or
# arrow leaves.
const RANGER_CLIPS = {"triple":["SkillTripleSlash",1.0,[.22,.5,.78]],"ambush":["SkillAmbush",.6,[.5]],"hide":["SkillHide",.45,[.9]],
	"volley":["SkillVolley",.9,[.78]],"lightning":["ArcherShot",.7,[.78]],"slowshot":["ArcherShot",.7,[.78]],"tranq":["ArcherShot",.7,[.78]]}
# Power Shot: the ArcherShot's draw, held at full draw while he aims.
const POWER_DRAW = .78
# Power Shot bursts where it strikes: everyone within this many metres of the
# one it hits takes the blow too.
const POWER_BURST = 2.5
const POWER_HOLD = .76
# How far (centre to centre) the warrior's blows reach, and how far he leaps.
const MELEE_REACH = 1.9
const CLEAVE_REACH = 2.6
const LEAP_RANGE = 10.0
const LEAP_RADIUS = 4.5
const CURSE_SECONDS = 4.0
const SHADOW_SECONDS = 5.0
# Dash Attack's Cleave is a quick cut out of the dash.
const DASH_CLEAVE_SPEED = 1.6
# The warrior's blows, aimed by facing rather than at a point in sight.
const SWINGS = ["cleave","slam","strike","bash","vampiric","shadow","execute","cry","charge","shockwave"]
# Each of the warrior's skills has a swing of its own (tools/import_skills.py):
# its clip, how long it plays, and how far through it the blow lands.
const WARRIOR_CLIPS = {"cleave":["SkillCleave",1.0,.52],"strike":["SkillStrike",1.0,.55],
	"bash":["SkillBash",.9,.5],"execute":["SkillExecute",1.3,.58],"slam":["SkillSlam",1.1,.52],"shockwave":["SkillShockwave",1.2,.56],
	"cry":["SkillCry",1.0,.3],"charge":["SkillCharge",1.0,.82],"leap":["SkillLeap",1.0,.56]}
# Vampiric and Shadow Strike are struck with the normal attack's swings, run
# on from (and into) them as they are (Game.swing_sword), the blade glowing
# as they land: blood red and shadowy purple.
const SWORD_CHAIN_SKILLS = {"vampiric":Color(.95,.03,.06),"shadow":Color(.55,.12,1.0)}
# Shield Charge: how fast he goes, and how far the ones in his way are thrown.
const CHARGE_SPEED = 11.0
# Firebolt is the Oracle's fireball: how far it flies, and its blast.
const FIREBALL_REACH = 13.0
const FIREBALL_RADIUS = 2.2
const CHARGE_THROW = 1.6
const SHOCKWAVE_THROW = 2.2
# The screen shakes this hard (metres) as the ground breaks.
const SHAKE_LEAP = .3
const SHAKE_SLAM = .4

func reset() -> void:
	pending.clear()
	zones.clear()
	cooldowns.clear()
	charge.clear()
	for w in waves: w.queue_free()
	waves.clear()
	barrier = 0; barrier_time = 0
	offense_stacks = 0; offense_time = 0; defense_stacks = 0; defense_time = 0
	if hidden and is_instance_valid(game.player): game.player.visual.set_shadowed(false)
	hidden = false; hide_slow = 0
	surprise_bonus = 0; surprise_time = 0; frenzy_bonus = 0; frenzy_time = 0
	lasting.clear()
	for f in falls: f.node.queue_free()
	falls.clear()
	for f in passing:
		if is_instance_valid(f[0]): f[0].queue_free()
	passing.clear()
	if is_instance_valid(frenzy_aura): frenzy_aura.queue_free()
	cancel_aim()

func rank(id: String) -> int:
	return int(game.run.skills.get(id,0))

func reason(id: String) -> String:
	if id.is_empty(): return "No skill assigned. Open K to choose a skill."
	if not Book.all().has(id) or not game.run.skills.has(id): return "Learn this skill first."
	var s: Dictionary = Book.all()[id]
	if s.effect=="passive": return "Passive skills apply automatically."
	# (The ranger carries his bow and his dagger both, and takes up whichever
	# the skill is made with.)
	var needed: int = Book.weapon_for(id,int(game.run.weapon))
	if not Book.compatible(id,int(game.run.weapon)) and (needed<0 or not game.run.owned[needed]): return "Requires %s." % {"shield":"sword and shield","bow_dagger":"bow or dagger"}.get(s.requirement,s.requirement)
	if cooldowns.get(id,0.0)>0: return "Recharging: %d seconds." % ceili(cooldowns[id])
	if game.run.energy<cost(id): return "Not enough energy."
	if s.effect=="hide":
		if hidden: return "Already hidden."
		if not game.out_of_combat(): return "Hide in Shadows needs you out of combat."
	if s.effect=="vanish" and hidden: return "Already hidden."
	if s.effect=="ambush" and not hidden: return "Surprise Attack needs you hidden in shadows."
	return ""

func cost(id: String) -> float:
	var s: Dictionary = Book.all()[id]
	return Book.cost(id,rank(id))*(1.0-Data.passive(game.run,"efficient_casting")*.01 if s.requirement=="staff" else 1.0)

# How close the hero comes to a unit he is ordered to use the skill on.
func reach(id: String) -> float:
	if not Book.all().has(id): return 13.0
	match Book.all()[id].effect:
		"cleave","strike","bash","vampiric","shadow","execute","flurry","triple","ambush": return MELEE_REACH
		# (With the dagger in hand; with the bow it is a shot.)
		"weaken": return MELEE_REACH if int(game.run.weapon)==5 else 13.0
		"sand": return SAND_REACH-.4
		"frenzy","hide","vanish": return 1000.0
		"leap": return LEAP_RANGE
		"slam": return maxf(MELEE_REACH,Book.values(id,maxi(1,rank(id))).z-1.0)
		"charge": return Book.values(id,maxi(1,rank(id))).x-1.0
		"shockwave": return Book.values(id,maxi(1,rank(id))).y-.5
		"cry": return Book.values(id,maxi(1,rank(id))).x-.5
	return 13.0

func cast_slot(slot: int, at: Vector3) -> bool:
	if slot<0 or slot>=game.run.hotbar.size(): return false
	return cast(game.run.hotbar[slot],at)

# `free` casts cost no energy and need not be learned: the Cleave that Dash
# Attack adds to the end of a dash.
func cast(id: String, at: Vector3, free: bool = false) -> bool:
	if game.mode!="playing" or game.player.dead or (game.player.busy>0 and not free): return false
	if free:
		if not Book.all().has(id) or not Book.compatible(id,int(game.run.weapon)): return false
	else:
		var problem = reason(id)
		if not problem.is_empty():
			game.toast(problem)
			return false
	var s: Dictionary = Book.all()[id]
	var level = maxi(1,rank(id))
	# What needs no motion happens at once, and does not interrupt him.
	if s.effect in ["frenzy","vanish"]:
		game.run.energy -= cost(id)
		game.order_pending = false
		if s.effect=="frenzy":
			var f: Dictionary = Book.values(id,level)
			frenzy_bonus = f.x
			frenzy_time = f.y
			lasting.frenzy = f.y
			cooldowns[id] = FRENZY_COOLDOWN
			game.float_text(game.player.position+Vector3.UP*2.3,"Frenzy!",Color(1,.45,.2))
			passing.append([RangerFx.burst(game.world,game.player.position+Vector3.UP,Color(1,.4,.15,.8),1.4,24),1.2])
		else:
			cooldowns[id] = Book.values(id,level).x
			# Gone in a puff of smoke: every wind-up and order of his is dropped.
			pending.clear()
			game.scheduled.clear()
			enter_shadows(true)
		return true
	var needed: int = Book.weapon_for(id,int(game.run.weapon))
	if needed>=0 and not free: game.take_up(needed)
	var direction: Vector3 = at-game.player.position
	direction.y = 0
	if direction.length()<.01: direction = game.player.forward()
	at = game.player.position+direction.normalized()*minf(direction.length(),LEAP_RANGE if s.effect=="leap" else 14.0)
	if not game.world.clear_line(game.player.position,at) and s.effect not in ["blink","retreat","hide"]+SWINGS+RANGER_BLOWS:
		game.toast("The target is behind a wall.")
		return false
	if s.effect=="execute":
		var limit: float = Book.values(id,level).y
		var victim = single_target(at,direction.normalized())
		if victim == null or not executable(victim,limit):
			game.toast("Execute needs an enemy below %d%% health." % limit)
			return false
	if not free: game.run.energy -= cost(id)
	if s.effect in ["bash","shockwave"]: cooldowns[id] = Book.values(id,level).z
	if s.effect=="sand": cooldowns[id] = SAND_COOLDOWN
	if s.effect=="tranq": cooldowns[id] = TRANQ_COOLDOWN
	# Any attack brings him out of the shadows (the ambush, as it lands).
	if s.effect not in ["hide","ambush"]: leave_shadows()
	game.order_pending = false
	game.route.clear()
	game.player.face(at)
	# Stepping into a strike, he stops short of the unit it is aimed at (or
	# drives it back as the blow lands).
	game.player.begin_strike(at)
	var duration = .7
	var contact = .35
	var clip = "Cast"
	# Each blow or arrow of the motion, as shares of its time.
	var contacts: Array = []
	if s.class_id=="ranger":
		# Dexterity and Frenzy quicken his every attack.
		var quick: float = haste()*(1.0+Data.attack_haste(game.run)*.01)
		var v: Dictionary = Book.values(id,level)
		var with_dagger: bool = int(game.run.weapon)==5
		if RANGER_CLIPS.has(s.effect):
			var own: Array = RANGER_CLIPS[s.effect]
			clip = own[0] if game.player.visual.clips.has(own[0]) else "ArcherShot"
			duration = own[1]/(1.0 if s.effect=="hide" else quick)
			contacts = own[2]
		match s.effect:
			"rapid":
				# Shot after shot, each a quick draw of its own.
				clip = "BowShot"
				duration = .26*v.y/quick
				for i in int(v.y): contacts.append((i+.62)/v.y)
			"power":
				# The draw, held while he aims, and the release at the time's end.
				clip = "ArcherShot"
				var aim: float = maxf(POWER_DRAW,v.y)
				duration = aim+.17
				contacts = [aim/duration]
			"flurry":
				clip = "SkillFlurry%d" % int(v.x)
				duration = Motion.flurry_seconds(int(v.x))/quick
				contacts = Motion.flurry_contacts(int(v.x))
			"weaken":
				clip = "DaggerSlash" if with_dagger else "ArcherShot"
				duration = (.5 if with_dagger else .7)/quick
				contacts = [.45 if with_dagger else .78]
			"sand":
				# Thrown with the hand that holds no weapon.
				clip = "SkillSandL" if with_dagger else "SkillSandR"
				duration = .7
				contacts = [.55]
		if not game.player.visual.clips.has(clip): clip = "Cast"
		contact = duration*contacts[0]
	elif s.requirement in ["melee","shield"]:
		clip = "SwordSlash" if game.run.weapon==1 else ("SpearJab" if game.run.weapon==0 else "AxeChop")
		# Dexterity quickens every melee swing.
		var haste: float = (1.0+Data.attack_haste(game.run)*.01)*(DASH_CLEAVE_SPEED if free else 1.0)
		duration = maxf(Data.MELEE_MINIMUM,.84/haste)
		contact = duration*.52
		# With the sword, each skill has its own swing.
		if game.run.weapon==1 and WARRIOR_CLIPS.has(s.effect) and game.player.visual.clips.has(WARRIOR_CLIPS[s.effect][0]):
			var own: Array = WARRIOR_CLIPS[s.effect]
			clip = own[0]
			duration = maxf(Data.MELEE_MINIMUM,own[1]/haste)
			contact = duration*own[2]
		elif game.run.weapon==1 and SWORD_CHAIN_SKILLS.has(s.effect) and game.player.visual.clips.has(Motion.SWORD_OPENER):
			# (The swing's time and its blow's moment are the normal attack's.)
			clip = Motion.SWORD_OPENER
	if s.effect=="leap":
		var gap: float = game.player.position.distance_to(at)
		# He lands beside a unit standing at the target, not on it.
		for enemy in game.targets(game.player):
			if not enemy.dead and not enemy.dormant and enemy.position.distance_to(at)<.6: gap = maxf(0.0,gap-game.player.standoff(enemy))
		# (The flight begins after the crouch and ends on the blow.)
		game.start_leap(direction.normalized(),gap,contact,duration*.2 if clip=="SkillLeap" else 0.0)
	if s.effect=="charge":
		var reach: float = Book.values(id,level).x
		var run_time = minf(reach,direction.length())/CHARGE_SPEED
		charge = {"left":run_time,"direction":direction.normalized(),"hit":[],"id":id,"rank":level,"stunned":false}
		duration = maxf(duration,run_time+.35)
		contact = duration*.95
		game.player.invulnerable = run_time
	if s.effect=="rapid":
		game.player.visual.play(clip,duration/contacts.size())
	elif s.effect=="power":
		game.player.visual.play(clip,POWER_DRAW)
		game.player.visual.hold_at(POWER_HOLD,maxf(0.0,contact-POWER_DRAW*.78))
		if is_instance_valid(charge_glow): charge_glow.queue_free()
		charge_glow = RangerFx.charge(game.player.visual,contact)
		aim_total = contact
		aim_left = contact
	elif clip==Motion.SWORD_OPENER:
		game.swing_sword(duration)
		game.player.visual.tint_blade(SWORD_CHAIN_SKILLS[s.effect],duration)
	else: game.player.visual.play(clip,duration)
	# Cleave and the strikes struck with the normal attack's swings whistle as
	# its swings do, a moment before the blow.
	if s.effect=="cleave" or SWORD_CHAIN_SKILLS.has(s.effect):
		game.scheduled.append({"time":maxf(.01,contact-.12),"type":"swing","sound":"swing-spear" if game.run.weapon==0 else "swing-blade"})
	game.player.busy = duration
	game.player.cooldown = duration
	if contacts.size()>1:
		for i in contacts.size(): pending.append({"time":duration*contacts[i],"id":id,"rank":level,"at":at,"direction":direction.normalized(),"blow":i,"blows":contacts.size(),"span":duration/contacts.size()})
	else: pending.append({"time":contact,"id":id,"rank":level,"at":at,"direction":direction.normalized()})
	return true

# Power Shot let go of before it is loosed (he dashed, or the shot is away).
func cancel_aim() -> void:
	aim_total = 0.0
	aim_left = 0.0
	if is_instance_valid(charge_glow): charge_glow.queue_free()

# What is on the hero now, buffs first, for the HUD's row over the hotbar:
# each its "id" (its icon's), "name", "stacks" (0 for none), the seconds
# "left" of how many in all ("total"; 0 for one that lasts as long as it
# holds), whether it is a "debuff", and a line on what it does ("text").
func effects() -> Array:
	var out: Array = []
	if hidden: out.append(effect("hide_in_shadows","Hidden",0,0.0,"Unseen by enemies; moving %d%% slower." % roundi(hide_slow)))
	if frenzy_time>0: out.append(effect("frenzy","Frenzy",0,frenzy_time,"Attacking %d%% faster." % roundi(frenzy_bonus)))
	if surprise_time>0: out.append(effect("element_of_surprise","Element of Surprise",0,surprise_time,"Dealing %d%% more damage." % roundi(surprise_bonus)))
	if offense_stacks>0: out.append(effect("offensive_rhythm","Offensive Rhythm",offense_stacks,offense_time,"Dealing %d%% more damage." % roundi(offense_stacks*Data.passive(game.run,"offensive_rhythm"))))
	if defense_stacks>0:
		var cut: float = Book.values("defensive_rhythm",rank("defensive_rhythm")).x
		out.append(effect("defensive_rhythm","Defensive Rhythm",defense_stacks,defense_time,"Taking %d%% less damage." % roundi(defense_stacks*cut)))
	if barrier>0 and barrier_time>0: out.append(effect("barrier","Barrier",0,barrier_time,"Absorbing the next %d damage." % ceili(barrier)))
	if game.slowed>0: out.append(effect("chilled","Chilled",0,game.slowed,"Frozen to the bone: moving at half speed.",true,game.CHILL_SECONDS))
	return out

func effect(id: String, title: String, stacks: int, left: float, text: String, debuff: bool = false, total: float = -1.0) -> Dictionary:
	if total<0: total = maxf(lasting.get(id,left),left) if left>0 else 0.0
	return {"id":id,"name":title,"stacks":stacks,"left":left,"total":total,"debuff":debuff,"text":text}

# How much faster the ranger attacks: Frenzy, while it lasts.
func haste() -> float:
	return 1.0+(frenzy_bonus*.01 if frenzy_time>0 else 0.0)

# Into the shadows: no enemy sees him (those after him lose him), and he
# moves slower, as Hide in Shadows' rank has it. `smoke`: Vanish's puff.
func enter_shadows(smoke: bool = false) -> void:
	hidden = true
	hide_slow = Book.values("hide_in_shadows",maxi(1,rank("hide_in_shadows"))).x
	for enemy in game.enemies: enemy.lose_sight()
	game.target = null
	game.route.clear()
	game.player.visual.set_shadowed(true)
	passing.append([RangerFx.burst(game.world,game.player.position+Vector3.UP*.9,Color(.12,.1,.16,.85),2.2 if smoke else 1.3,36 if smoke else 16),1.4])
	game.float_text(game.player.position+Vector3.UP*2.3,"Vanished" if smoke else "Hidden",Color(.7,.68,.85))

# Out of them (he attacked, was struck, or dashed): Element of Surprise
# raises his damage for a while.
func leave_shadows() -> void:
	if not hidden: return
	hidden = false
	game.player.visual.set_shadowed(false)
	var surprise: Dictionary = Book.values("element_of_surprise",rank("element_of_surprise"))
	if surprise.x>0:
		surprise_bonus = surprise.x
		surprise_time = surprise.y
		lasting.element_of_surprise = surprise.y

# One of the hero's arrows, loosed along `direction` for `percent` of a
# normal attack; `extra` is what else it carries (RangerFx.arrow dresses it).
func loose(direction: Vector3, percent: float, extra: Dictionary = {}) -> void:
	game.sound.play("archer-arrow")
	game.projectile(game.player.position,game.player.position+direction*13.0,attack_damage(percent,"ranged"),true,"arrow",Data.passive(game.run,"penetrating_arrows")>0,null,true,extra)

# One of the hero's arrows striking `enemy`: its damage, and whatever it
# carries.
func arrow_hit(enemy, p: Dictionary) -> void:
	var extra: Dictionary = p.get("extra",{})
	var impact = StoneFragment.impact(p.direction)
	match extra.get("kind",""):
		"tranq":
			# No wound: only sleep.
			enemy.sleep(extra.seconds)
			return
		"power":
			# (An arrow driven on through its first by Penetrating Arrows
			# bursts only once.)
			var around: Array = [] if extra.get("burst",false) else targets(enemy.position,POWER_BURST).filter(func(e): return e != enemy)
			extra.burst = true
			strike(enemy,p.damage,"physical",0.0,StoneFragment.impact(p.direction,true),true,2)
			for other in around: strike(other,p.damage,"physical",0.0,StoneFragment.impact(other.position-enemy.position,true),true,2)
			passing.append([RangerFx.burst(game.world,enemy.position+Vector3.UP,Color(1,.9,.6,.8),POWER_BURST,36),.8])
			game.shake(.1)
		"slow":
			strike(enemy,p.damage,"physical",0.0,impact,true,2)
			enemy.slow(extra.percent,extra.seconds)
			if not enemy.dead: game.float_text(enemy.position+Vector3.UP*1.9,"Slowed",Color(.55,.85,1))
		"weaken":
			strike(enemy,p.damage,"physical",0.0,impact,true,2)
			weaken(enemy,extra.percent,extra.cap)
		"lightning":
			strike(enemy,p.damage,"lightning",0.0,impact,true,2)
			# It leaps on from one to the next, never to the same twice, each
			# leap 20% weaker than the one before (LIGHTNING_FADE).
			var struck: Array = [enemy]
			var from = enemy
			for leap in int(extra.leaps):
				var choices = targets(from.position,LIGHTNING_LEAP).filter(func(e): return not e in struck)
				if choices.is_empty(): break
				choices.sort_custom(func(a,b): return a.position.distance_squared_to(from.position)<b.position.distance_squared_to(from.position))
				var next = choices[0]
				passing.append([RangerFx.bolt(game.world,from.position+Vector3.UP*1.1,next.position+Vector3.UP*1.1),.22])
				strike(next,attack_damage(extra.percent,"ranged")*pow(LIGHTNING_FADE,leap+1),"lightning",0.0,Vector3.ZERO,true,2)
				struck.append(next)
				from = next
		_: strike(enemy,p.damage,"physical",0.0,impact,p.skill,2)

func weaken(enemy, percent: float, cap: float) -> void:
	if enemy.dead: return
	enemy.weaken(percent,int(cap))
	game.float_text(enemy.position+Vector3.UP*1.9,"Weakened ×%d" % enemy.weak_stacks,Color(.8,.5,1))

func targets(at: Vector3, radius: float) -> Array:
	return game.targets(game.player).filter(func(e): return not e.dead and not e.dormant and e.position.distance_to(at)<=radius and game.world.clear_line(at,e.position))

# A blow's reach grows a little with its target's bulk.
func bulk(enemy) -> float:
	return .5 if enemy.kind=="boss" else .25

# Everyone standing within `degrees` of arc in front of `origin`, out to `distance`.
func arc_targets(origin: Vector3, direction: Vector3, degrees: float, distance: float) -> Array:
	var limit = cos(deg_to_rad(degrees*.5))
	return game.targets(game.player).filter(func(e):
		if e.dead or e.dormant: return false
		var offset: Vector3 = e.position-origin
		offset.y = 0
		if offset.length()>distance+bulk(e): return false
		if offset.length()>.01 and direction.dot(offset.normalized())<limit-.001: return false
		return game.world.clear_line(origin,e.position))

# The one unit a single-target blow lands on: in reach before the hero, the
# nearest to where the blow is aimed.
func single_target(at: Vector3, direction: Vector3):
	var hits = arc_targets(game.player.position,direction,90.0,MELEE_REACH)
	hits.sort_custom(func(a,b): return a.position.distance_squared_to(at)<b.position.distance_squared_to(at))
	return null if hits.is_empty() else hits[0]

# `percent` of a normal attack's damage (in hand, the dagger's too, by
# Strength; the bow's by Dexterity).
func attack_damage(percent: float, tag: String = "melee") -> float:
	return Data.damage_tag(game.run,tag,randf_range(10,15))*percent*.01

# What a damaging skill hits for at `level` (its current rank, or the first
# while unlearned), from the hero's attributes and passives as they stand:
# {"damage": one hit's range, "crit": a critical strike's chance, "crit_damage":
# what it multiplies a hit by}, or {} for a skill that deals no damage.
# Offensive Rhythm's stacks and Element of Surprise come and go in a fight, so
# are left out.
func damage_summary(id: String, level: int) -> Dictionary:
	var s: Dictionary = Book.all()[id]
	level = maxi(1,level)
	var v: Dictionary = Book.values(id,level)
	# The weapon the skill is made with: the ranger takes up the one it needs.
	var weapon: int = Book.weapon_for(id,int(game.run.weapon))
	if weapon<0: weapon = int(game.run.weapon)
	var tag: String = "melee" if s.class_id=="warrior" else Data.scaling_tag(weapon)
	# The percent of a normal attack one hit deals.
	var percent = -1.0
	match s.effect:
		"cleave","charge","volley","flurry": percent = v.y
		"leap","slam","shockwave","strike","bash","vampiric","shadow","execute","power","lightning","triple": percent = v.x
		"rapid","slowshot","weaken": percent = 100.0
		"passive":
			if id!="dash_attack": return {}
			percent = v.x
		_:
			# (War Cry, Throw Sand and the like; the wizard's Barrier and Blink.)
			if s.has("ranks") or s.tag.is_empty(): return {}
	var result = crit_numbers(weapon)
	# The wizard's spells hit for a set amount.
	if percent<0: result.damage = "Damage: %d" % roundi(Data.damage_tag(game.run,s.tag,15.0*Book.value(id,level)))
	else: result.damage = "Damage: "+span(percent,tag)
	return result

# A critical strike with `weapon`: its chance, and the damage it does, in
# percent of a hit, as tip lines.
func crit_numbers(weapon: int) -> Dictionary:
	var mastery: Dictionary = Data.specialization(game.run,weapon)
	return {"crit":"Critical strike chance: %s%%" % figure(Data.crit_chance(game.run)+mastery.x),"crit_damage":"Critical strike damage: %s%%" % figure(Data.CRIT_MULTIPLIER*(1.0+mastery.y*.01)*100.0)}

# The normal attack's speed bonus with `weapon`, in percent: Dexterity, and
# for a melee weapon Quick Strikes. (The staff's bolt is never quickened.)
func basic_speed(weapon: int) -> float:
	if weapon==4: return 0.0
	return Data.attack_haste(game.run) if weapon==2 else Data.melee_attack_speed(game.run)

# A number as few figures as it needs: 25, 22.5, 22.75.
func figure(amount: float) -> String:
	return Book.figure(amount)

# The least and most `percent` of a normal attack hits for, in words.
func span(percent: float, tag: String) -> String:
	return "%d–%d" % [roundi(Data.damage_tag(game.run,tag,10.0)*percent*.01),roundi(Data.damage_tag(game.run,tag,15.0)*percent*.01)]

# Whether Execute may be used on `victim`: below `limit` percent of its
# health, or anywhere in the debug playground, where any target will do.
func executable(victim, limit: float) -> bool:
	return game.playground != null or victim.hp/victim.max_hp<limit*.01

# How much Offensive Rhythm's stacks multiply the hero's damage by.
func rhythm_boost() -> float:
	return 1.0+offense_stacks*Data.passive(game.run,"offensive_rhythm")*.01

# Every hit the hero lands on an enemy: it may be a critical hit (rolled for
# each target), Offensive Rhythm raises it and gains a stack, and Cursed Blade
# leaves its extra damage on the target. `bonus` is added after armor
# (Vampiric Strike's drain). `skill` is false for the normal attack, whose
# numbers show white rather than a skill's yellow.
# `weapon` is the weapon the hit is made with (the one in hand, unless given:
# an arrow in flight is the bow's whatever he holds by then). The ranger's
# specialization in it adds to the chance of a critical strike and to its
# damage; Weakening Strike's stacks on the target add to that damage again;
# Element of Surprise raises the whole; and Poisons leave their own.
func strike(enemy, amount: float, type: String = "physical", bonus: float = 0.0, death_impact: Vector3 = Vector3.ZERO, skill: bool = true, weapon: int = -1) -> void:
	if not is_instance_valid(enemy) or enemy.dead or enemy.dormant: return
	if weapon<0: weapon = int(game.run.weapon)
	var rhythm: Dictionary = Book.values("offensive_rhythm",rank("offensive_rhythm"))
	amount *= rhythm_boost()
	if surprise_time>0: amount *= 1.0+surprise_bonus*.01
	var mastery: Dictionary = Data.specialization(game.run,weapon)
	var crit: bool = randf()*100.0<Data.crit_chance(game.run)+mastery.x if crit_override<0 else crit_override==1
	if crit: amount *= Data.CRIT_MULTIPLIER*(1.0+mastery.y*.01)*(1.0+enemy.weak_stacks*enemy.weak_bonus*.01)
	var poison: Dictionary = Book.values("poisons",rank("poisons"))
	enemy.hit(amount,type,bonus,death_impact,"crit" if crit else ("skill" if skill else "normal"))
	if rhythm.y>0:
		offense_stacks = mini(int(rhythm.y),offense_stacks+1)
		offense_time = rhythm.z
		lasting.offensive_rhythm = rhythm.z
	var curse: Dictionary = Book.values("cursed_blade",rank("cursed_blade"))
	if curse.y>0 and not enemy.dead: enemy.add_dot("curse",amount*curse.x*.01,CURSE_SECONDS,int(curse.y))
	if poison.y>0 and weapon in [2,5] and not enemy.dead: enemy.add_dot("poison",amount*poison.x*.01,POISON_SECONDS,int(poison.y))

# An attack reaching the hero, after armor: Shield Expertise may block part of
# it (Spiked Shield answering the attacker), Defensive Rhythm lowers it and
# gains a stack, and a barrier absorbs what it can. Returns the damage left.
func defend(damage: float, source) -> float:
	var blocked = false
	var block: Dictionary = Book.values("shield_expertise",rank("shield_expertise"))
	if block.x>0 and int(game.run.weapon)==1 and randf()*100.0<block.x:
		blocked = true
		damage *= 1.0-block.y*.01
	var rhythm: Dictionary = Book.values("defensive_rhythm",rank("defensive_rhythm"))
	damage *= 1.0-defense_stacks*rhythm.x*.01
	if rhythm.y>0:
		defense_stacks = mini(int(rhythm.y),defense_stacks+1)
		defense_time = rhythm.z
		lasting.defensive_rhythm = rhythm.z
	var absorbed = minf(barrier,damage)
	barrier -= absorbed
	damage -= absorbed
	if blocked:
		game.float_text(game.player.position+Vector3.UP*2.4,"Blocked",Color(.72,.84,1))
		var spikes: float = Data.passive(game.run,"spiked_shield")
		if spikes>0 and is_instance_valid(source) and not source.dead: source.hit(attack_damage(spikes))
	return damage

# The effects in play, for the HUD.
func status() -> String:
	var parts: Array = []
	if offense_stacks>0: parts.append("Offensive Rhythm ×%d" % offense_stacks)
	if defense_stacks>0: parts.append("Defensive Rhythm ×%d" % defense_stacks)
	if barrier>0: parts.append("Barrier %d" % ceili(barrier))
	if hidden: parts.append("Hidden in shadows")
	if frenzy_time>0: parts.append("Frenzy %d" % ceili(frenzy_time))
	if surprise_time>0: parts.append("Element of Surprise %d" % ceili(surprise_time))
	return " · ".join(parts)

func pulse(at: Vector3, radius: float, damage: float, type: String, slow: float = 0) -> void:
	for enemy in targets(at,radius):
		strike(enemy,damage,type)
		if slow>0: enemy.slow(60.0,slow)

# A blow on the ground: its shockwave racing out across the area it hits, the
# ground cracked under it (scripts/shockwave.gd; `plasma`: the blade's charge
# driven into the ground with it), the screen shaken and the impact heard.
func ground_blow(at: Vector3, reach: float, shake: float, direction: Vector3 = Vector3.ZERO, degrees: float = 360.0, sound: String = "whirl-impact", plasma: bool = false) -> void:
	var wave = Shockwave.make(at+Vector3.UP*game.world.lift(at),reach,direction,degrees,plasma)
	game.world.add_child(wave)
	waves.append(wave)
	game.shake(shake)
	# The blow meeting the ground: a crash of rock (Thunder Slam and
	# Shockwave), or the original game's Whirl impact as the warrior lands
	# (Leap).
	game.sound.play(sound,-9)

func execute(job: Dictionary) -> void:
	var s: Dictionary = Book.all()[job.id]
	var value = Book.value(job.id,job.rank)
	var v: Dictionary = Book.values(job.id,job.rank)
	var damage = Data.damage_tag(game.run,s.tag,15.0*value) if not s.tag.is_empty() and not s.has("ranks") else 0.0
	var at: Vector3 = job.at
	var origin: Vector3 = game.player.position
	var direction: Vector3 = job.direction
	match s.effect:
		"cleave":
			for enemy in arc_targets(origin,direction,v.x,CLEAVE_REACH):
				strike(enemy,attack_damage(v.y))
				game.player.landed_on(enemy)
		"slam":
			for enemy in arc_targets(origin,direction,v.y,v.z):
				strike(enemy,attack_damage(v.x),"physical",0.0,StoneFragment.impact(enemy.position-origin,true))
			ground_blow(origin+direction*.9,v.z,SHAKE_SLAM,direction,v.y,"rock-impact",true)
		"leap":
			for enemy in targets(origin,LEAP_RADIUS):
				strike(enemy,attack_damage(v.x),"physical",0.0,StoneFragment.impact(enemy.position-origin,true))
			ground_blow(origin,LEAP_RADIUS,SHAKE_LEAP)
		"shockwave":
			for enemy in targets(origin,v.y):
				strike(enemy,attack_damage(v.x))
				var away: Vector3 = enemy.position-origin
				away.y = 0
				if away.length()>.05: enemy.shove(away.normalized(),SHOCKWAVE_THROW)
			ground_blow(origin,v.y,SHAKE_SLAM,Vector3.ZERO,360.0,"rock-impact")
		"cry":
			for enemy in targets(origin,v.x): enemy.rally(v.y,v.z)
			# The red glow on his blade bursts from it as a ring over the ground
			# the cry covers.
			var ring = WarCry.make(origin+Vector3.UP*game.world.lift(origin),v.x)
			game.world.add_child(ring)
			waves.append(ring)
			game.float_text(game.player.position+Vector3.UP*2.3,"War Cry!",Color(1,.8,.4))
		"charge":
			# The blow at the end of the run: whoever is still before him.
			for enemy in arc_targets(origin,direction,100.0,MELEE_REACH):
				if not enemy in charge.get("hit",[]): charge_hit(enemy,direction,v)
			charge.clear()
		"strike","bash","vampiric","shadow","execute":
			var victim = single_target(at,direction)
			if victim == null: return
			var blow: float = attack_damage(v.x)
			match s.effect:
				"strike":
					strike(victim,blow)
				"bash":
					strike(victim,blow)
					victim.stun(v.y)
				"vampiric":
					strike(victim,blow,"physical",victim.max_hp*v.y*.01)
					var healed: float = Data.max_health(game.run)*v.y*.01
					game.player.hp = minf(Data.max_health(game.run),game.player.hp+healed)
					game.float_text(game.player.position+Vector3.UP*1.8,"+%d" % roundi(healed),Color(.4,1,.55))
				"shadow":
					# The lingering damage is raised by Offensive Rhythm as the blow is.
					var lingering: float = attack_damage(v.y)*rhythm_boost()
					strike(victim,blow)
					if not victim.dead:
						victim.add_dot("shadow",lingering,SHADOW_SECONDS,1)
						victim.refresh_dots("curse")
				"execute":
					# The opening may have closed since the swing began.
					if not executable(victim,v.y): return
					strike(victim,blow)
			game.player.landed_on(victim)
		"barrier":
			barrier = value; barrier_time = s.duration
			lasting.barrier = s.duration
		"blink":
			game.player.position = game.world.move(origin,direction*minf(value,origin.distance_to(at)))
		"firebolt":
			# The Oracle's own fireball, from the staff to the target (as far
			# as the spell reaches, and short of any wall), bursting there.
			var reach: float = minf(FIREBALL_REACH,origin.distance_to(at)) if origin.distance_to(at) > .5 else FIREBALL_REACH
			var landing: Vector3 = origin+direction*reach
			while reach > 1.0 and not game.world.clear_line(origin,landing):
				reach -= .5
				landing = origin+direction*reach
			var staff: Vector3 = game.player.visual.staff_tip() if game.player.visual.weapon_kind=="staff" else origin+Vector3.UP*1.5
			game.fireball(staff,landing,FIREBALL_RADIUS,damage,clampf(reach/14.0,.4,.8),null,true)
		"lance":
			game.projectile(origin,origin+direction*13,damage,true,"arcane",true)
		"rapid":
			loose(direction,100.0)
			# The next arrow's draw.
			if job.blow<job.blows-1: game.player.visual.play("BowShot",job.span)
		"power":
			cancel_aim()
			loose(direction,v.x,{"kind":"power"})
		"slowshot": loose(direction,100.0,{"kind":"slow","percent":v.x,"seconds":v.y})
		"tranq": loose(direction,0.0,{"kind":"tranq","seconds":v.x})
		"lightning": loose(direction,v.x,{"kind":"lightning","percent":v.x,"leaps":v.y})
		"weaken":
			if int(game.run.weapon)==5:
				var marked = single_target(at,direction)
				if marked == null: return
				strike(marked,attack_damage(100.0,"melee"))
				weaken(marked,v.x,v.y)
				game.player.landed_on(marked)
			else: loose(direction,100.0,{"kind":"weaken","percent":v.x,"cap":v.y})
		"volley":
			# Up they go from the bow, and down they come over the place aimed
			# at, each where chance puts it.
			game.sound.play("archer-arrow")
			game.effect(at,VOLLEY_RADIUS*2.0,Color(1,.85,.5,.5),VOLLEY_FALL+VOLLEY_STAGGER*v.x+.3)
			for i in int(v.x):
				var spot: Vector3 = at+Vector3.FORWARD.rotated(Vector3.UP,randf()*TAU)*sqrt(randf())*VOLLEY_RADIUS
				passing.append([RangerFx.rising(game.world,origin+Vector3.UP*1.5+direction*.5,direction,i),.3])
				falls.append({"node":RangerFx.falling(game.world),"to":spot,"way":direction,"wait":.25+VOLLEY_STAGGER*i,"left":VOLLEY_FALL,"damage":attack_damage(v.y,"ranged")})
		"flurry":
			var stabbed = single_target(at,direction)
			if stabbed == null: return
			strike(stabbed,attack_damage(v.y,Data.scaling_tag(int(game.run.weapon))))
			game.player.landed_on(stabbed)
		"triple":
			var main = single_target(at,direction)
			if main == null: return
			# Those around him, on every side, nearest him first.
			var beside: Array = arc_targets(origin,direction,360.0,TRIPLE_AROUND).filter(func(e): return e != main)
			beside.sort_custom(func(a,b): return a.position.distance_squared_to(origin)<b.position.distance_squared_to(origin))
			for enemy in [main]+beside.slice(0,int(v.y)): strike(enemy,attack_damage(v.x,Data.scaling_tag(int(game.run.weapon))))
			game.player.landed_on(main)
		"sand":
			passing.append([RangerFx.sand(game.world,origin+Vector3.UP*1.2,direction),1.0])
			var blinded: Array = arc_targets(origin,direction,120.0,SAND_REACH)
			blinded.sort_custom(func(a,b): return a.position.distance_squared_to(at)<b.position.distance_squared_to(at))
			if not blinded.is_empty(): blinded[0].confuse(v.x)
		"ambush":
			var caught = single_target(at,direction)
			leave_shadows()
			if caught == null: return
			caught.ambush(v.x,v.y)
			passing.append([RangerFx.burst(game.world,caught.position+Vector3.UP*1.3,Color(1,.35,.2,.8),1.0,14),.7])
			game.player.landed_on(caught)
		"hide": enter_shadows()
		"nova": pulse(origin,s.radius,damage,"frost",s.duration)
		"chain":
			var current = origin
			var used = []
			for bounce in 4:
				var choices = targets(current,12 if bounce==0 else 5)
				choices = choices.filter(func(e): return not e in used)
				if choices.is_empty(): break
				choices.sort_custom(func(a,b): return a.position.distance_squared_to(at if bounce==0 else current)<b.position.distance_squared_to(at if bounce==0 else current))
				var enemy = choices[0]
				used.append(enemy)
				strike(enemy,damage,"arcane")
				current = enemy.position
		"blizzard","meteor":
			zones.append({"effect":s.effect,"at":at,"radius":float(s.radius),"damage":damage,"value":value,"life":float(s.duration),"tick":float(s.duration) if s.effect=="meteor" else 0.0,"pulses":5 if s.effect=="blizzard" else 3})

# Shield Charge's blow on one unit: damage, thrown aside, the first stunned.
func charge_hit(enemy, direction: Vector3, v: Dictionary) -> void:
	# (The run's own record may be gone by its last blow, if it was cut short.)
	if not charge.has("hit"): charge = {"left":0.0,"hit":[],"stunned":false}
	charge.hit.append(enemy)
	var first_hit: bool = not charge.stunned
	strike(enemy,attack_damage(v.y))
	var aside: Vector3 = enemy.position-game.player.position
	aside.y = 0
	var side: Vector3 = direction.cross(Vector3.UP)
	var throw: Vector3 = (side if aside.dot(side)>=0 else -side)*.7+direction*.7
	enemy.shove(throw.normalized(),CHARGE_THROW)
	if first_hit:
		enemy.stun(v.z)
		charge.stunned = true

# Dash Attack: an enemy the dash passes through takes the rank's share of a
# normal attack's damage and is
# pushed back, out of the hero's path.
const DASH_PUSH = .8
func dash_hit(enemy, direction: Vector3, struck: Array) -> void:
	struck.append(enemy)
	strike(enemy,attack_damage(Book.values("dash_attack",rank("dash_attack")).x))
	var aside: Vector3 = enemy.position-game.player.position
	aside.y = 0
	var side: Vector3 = direction.cross(Vector3.UP)
	var push: Vector3 = (side if aside.dot(side)>=0 else -side)*.7+direction*.7
	enemy.shove(push.normalized(),DASH_PUSH)

func tick(dt: float) -> void:
	for i in range(waves.size()-1,-1,-1):
		if waves[i].tick(dt):
			waves[i].queue_free()
			waves.remove_at(i)
	if not charge.is_empty() and not game.player.dead:
		var step = minf(dt,charge.left)
		charge.left -= dt
		var before: Vector3 = game.player.position
		game.player.position = game.world.move(before,charge.direction*CHARGE_SPEED*step)
		if before.distance_to(game.player.position) < CHARGE_SPEED*step*.3: charge.left = 0.0
		var v: Dictionary = Book.values(charge.id,charge.rank)
		for enemy in arc_targets(game.player.position,charge.direction,120.0,1.3):
			if not enemy in charge.hit: charge_hit(enemy,charge.direction,v)
		if charge.left<=0.0:
			charge.left = 0.0
	barrier_time = maxf(0,barrier_time-dt)
	if barrier_time<=0: barrier = 0
	for id in cooldowns: cooldowns[id] = maxf(0,cooldowns[id]-dt)
	offense_time = maxf(0,offense_time-dt)
	if offense_time<=0: offense_stacks = 0
	defense_time = maxf(0,defense_time-dt)
	if defense_time<=0: defense_stacks = 0
	surprise_time = maxf(0,surprise_time-dt)
	aim_left = maxf(0,aim_left-dt)
	if aim_left<=0 or game.player.dead: aim_total = 0.0
	frenzy_time = maxf(0,frenzy_time-dt)
	# Frenzy shows on him while it lasts.
	if frenzy_time>0 and not is_instance_valid(frenzy_aura): frenzy_aura = RangerFx.aura(game.player.visual)
	elif frenzy_time<=0 and is_instance_valid(frenzy_aura):
		frenzy_aura.queue_free()
		frenzy_aura = null
	for i in range(passing.size()-1,-1,-1):
		passing[i][1] -= dt
		if passing[i][1]<=0:
			if is_instance_valid(passing[i][0]): passing[i][0].queue_free()
			passing.remove_at(i)
	# Volley's arrows coming down: each hits the enemy nearest where it lands.
	for i in range(falls.size()-1,-1,-1):
		var f: Dictionary = falls[i]
		if f.wait>0:
			f.wait -= dt
			f.node.visible = false
			continue
		f.left -= dt
		var u: float = clampf(1.0-f.left/VOLLEY_FALL,0.0,1.0)
		var from: Vector3 = f.to-f.way*2.2+Vector3.UP*9.0
		f.node.visible = game.world.can_see(f.to)
		f.node.position = from.lerp(f.to+Vector3.UP*.25,u)
		f.node.look_at(f.node.position-(f.to-from),Vector3.FORWARD)
		if f.left<=0:
			var under: Array = targets(f.to,VOLLEY_HIT+.25)
			under.sort_custom(func(a,b): return a.position.distance_squared_to(f.to)<b.position.distance_squared_to(f.to))
			if not under.is_empty() and under[0].position.distance_to(f.to)<=VOLLEY_HIT+bulk(under[0]): strike(under[0],f.damage,"physical",0.0,StoneFragment.impact(f.way),true,2)
			passing.append([RangerFx.burst(game.world,f.to+Vector3.UP*.15,Color(.75,.68,.55,.6),.5,6),.6])
			f.node.queue_free()
			falls.remove_at(i)
	for i in range(pending.size()-1,-1,-1):
		pending[i].time -= dt
		if pending[i].time<=0:
			var job: Dictionary = pending[i]; pending.remove_at(i)
			if not game.player.dead: execute(job)
	for i in range(zones.size()-1,-1,-1):
		var z: Dictionary = zones[i]
		z.life -= dt; z.tick -= dt
		if z.tick<=0:
			var victims = targets(z.at,z.radius)
			pulse(z.at,z.radius,z.damage,"frost" if z.effect=="blizzard" else "fire",1.5 if z.effect=="blizzard" else 0)
			z.tick += 1.0
			z.pulses -= 1
			if z.effect=="meteor" or z.pulses<=0: z.life = 0
		if z.life<=0: zones.remove_at(i)
