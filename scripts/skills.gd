extends Node
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const Shockwave = preload("res://scripts/shockwave.gd")
const Art = preload("res://scripts/assets.gd")
const StoneFragment = preload("res://scripts/stone_fragment.gd")
var game
var pending: Array = []
var zones: Array = []
var barrier = 0.0
var barrier_time = 0.0
# Seconds until a skill with a cooldown (Shield Bash) is ready again.
var cooldowns: Dictionary = {}
# Shield Charge under way: how long he runs on, which way, and who he has hit.
var charge: Dictionary = {}
# Shockwaves under way (scripts/shockwave.gd).
var waves: Array = []
# Offensive and Defensive Rhythm: the stacks built, and how long they last.
# Tests fix the crit roll: -1 rolls, 0 never crits, 1 always does.
var crit_override = -1
var offense_stacks = 0
var offense_time = 0.0
var defense_stacks = 0
var defense_time = 0.0
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
const WARRIOR_CLIPS = {"cleave":["SkillCleave",1.0,.52],"strike":["SkillStrike",1.0,.55],"vampiric":["SkillStab",.9,.52],"shadow":["SkillStab",.9,.52],
	"bash":["SkillBash",.9,.5],"execute":["SkillExecute",1.3,.58],"slam":["SkillSlam",1.1,.52],"shockwave":["SkillShockwave",1.2,.56],
	"cry":["SkillCry",1.0,.3],"charge":["SkillCharge",1.0,.82],"leap":["SkillLeap",1.0,.56]}
# Shield Charge: how fast he goes, and how far the ones in his way are thrown.
const CHARGE_SPEED = 11.0
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

func rank(id: String) -> int:
	return int(game.run.skills.get(id,0))

func reason(id: String) -> String:
	if id.is_empty(): return "No skill assigned. Open K to choose a skill."
	if not Book.all().has(id) or not game.run.skills.has(id): return "Learn this skill first."
	var s: Dictionary = Book.all()[id]
	if s.effect=="passive": return "Passive skills apply automatically."
	if not Book.compatible(id,int(game.run.weapon)): return "Requires %s." % ("sword and shield" if s.requirement=="shield" else s.requirement)
	if cooldowns.get(id,0.0)>0: return "Recharging: %d seconds." % ceili(cooldowns[id])
	if game.run.energy<cost(id): return "Not enough energy."
	return ""

func cost(id: String) -> float:
	var s: Dictionary = Book.all()[id]
	return float(s.cost)*(1.0-Data.passive(game.run,"efficient_casting")*.01 if s.requirement=="staff" else 1.0)

# How close the hero comes to a unit he is ordered to use the skill on.
func reach(id: String) -> float:
	if not Book.all().has(id): return 13.0
	match Book.all()[id].effect:
		"cleave","strike","bash","vampiric","shadow","execute": return MELEE_REACH
		"leap": return LEAP_RANGE
		"slam": return maxf(MELEE_REACH,Book.values(id,maxi(1,rank(id))).z-1.0)
		"charge": return Book.values(id,maxi(1,rank(id))).x-1.0
		"shockwave": return Book.values(id,maxi(1,rank(id))).y-.5
		"cry": return Book.values(id,maxi(1,rank(id))).x-.5
	return 13.0

func cast_slot(slot: int, at: Vector3) -> bool:
	if slot<0 or slot>=3: return false
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
	var direction: Vector3 = at-game.player.position
	direction.y = 0
	if direction.length()<.01: direction = game.player.forward()
	at = game.player.position+direction.normalized()*minf(direction.length(),LEAP_RANGE if s.effect=="leap" else 14.0)
	if not game.world.clear_line(game.player.position,at) and s.effect not in ["blink","retreat"]+SWINGS:
		game.toast("The target is behind a wall.")
		return false
	if s.effect=="execute":
		var limit: float = Book.values(id,level).y
		var victim = single_target(at,direction.normalized())
		if victim == null or victim.hp/victim.max_hp>=limit*.01:
			game.toast("Execute needs an enemy below %d%% health." % limit)
			return false
	if not free: game.run.energy -= cost(id)
	if s.effect in ["bash","shockwave"]: cooldowns[id] = Book.values(id,level).z
	game.order_pending = false
	game.route.clear()
	game.player.face(at)
	# Stepping into a strike, he stops short of the unit it is aimed at (or
	# drives it back as the blow lands).
	game.player.begin_strike(at)
	game.combat_age = 0
	var duration = .7
	var contact = .35
	var clip = "Cast"
	if s.requirement=="bow":
		clip = "BowShot"
		duration = .78*maxf(.65,1.0/(1.0+Data.passive(game.run,"quick_draw")*.01))
		contact = duration*.62
	elif s.requirement in ["melee","shield"]:
		clip = "SwordSlash" if game.run.weapon==1 else ("SpearJab" if game.run.weapon==0 else "AxeChop")
		# Dexterity quickens every melee swing.
		var haste: float = (1.0+Data.melee_haste(game.run)*.01)*(DASH_CLEAVE_SPEED if free else 1.0)
		duration = maxf(Data.MELEE_MINIMUM,.84/haste)
		contact = duration*.52
		# With the sword, each skill has its own swing.
		if game.run.weapon==1 and WARRIOR_CLIPS.has(s.effect) and game.player.visual.clips.has(WARRIOR_CLIPS[s.effect][0]):
			var own: Array = WARRIOR_CLIPS[s.effect]
			clip = own[0]
			duration = maxf(Data.MELEE_MINIMUM,own[1]/haste)
			contact = duration*own[2]
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
	game.player.visual.play(clip,duration)
	game.player.busy = duration
	game.player.cooldown = duration
	pending.append({"time":contact,"id":id,"rank":level,"at":at,"direction":direction.normalized()})
	return true

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

# `percent` of a normal attack's damage.
func attack_damage(percent: float) -> float:
	return Data.damage_tag(game.run,"melee",randf_range(10,15))*percent*.01

# How much Offensive Rhythm's stacks multiply the hero's damage by.
func rhythm_boost() -> float:
	return 1.0+offense_stacks*Data.passive(game.run,"offensive_rhythm")*.01

# Every hit the hero lands on an enemy: it may be a critical hit (rolled for
# each target), Offensive Rhythm raises it and gains a stack, and Cursed Blade
# leaves its extra damage on the target. `bonus` is added after armor
# (Vampiric Strike's drain). `skill` is false for the normal attack, whose
# numbers show white rather than a skill's yellow.
func strike(enemy, amount: float, type: String = "physical", bonus: float = 0.0, death_impact: Vector3 = Vector3.ZERO, skill: bool = true) -> void:
	if not is_instance_valid(enemy) or enemy.dead or enemy.dormant: return
	var rhythm: Dictionary = Book.values("offensive_rhythm",rank("offensive_rhythm"))
	amount *= rhythm_boost()
	var crit: bool = randf()*100.0<Data.crit_chance(game.run) if crit_override<0 else crit_override==1
	if crit: amount *= Data.CRIT_MULTIPLIER
	enemy.hit(amount,type,bonus,death_impact,"crit" if crit else ("skill" if skill else "normal"))
	if rhythm.y>0:
		offense_stacks = mini(int(rhythm.y),offense_stacks+1)
		offense_time = rhythm.z
	var curse: Dictionary = Book.values("cursed_blade",rank("cursed_blade"))
	if curse.y>0 and not enemy.dead: enemy.add_dot("curse",amount*curse.x*.01,CURSE_SECONDS,int(curse.y))

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
	return " · ".join(parts)

func pulse(at: Vector3, radius: float, damage: float, type: String, slow: float = 0) -> void:
	game.effect(at,radius*2,Color(.35,.7,1,.8) if type=="frost" else Color(1,.6,.18,.8),.45)
	for enemy in targets(at,radius):
		strike(enemy,damage,type)
		if slow>0: enemy.slow_time = maxf(enemy.slow_time,slow)

# A blow on the ground: a shockwave of dust and smoke racing out across the
# area it hits (scripts/shockwave.gd), and the screen shaken.
func ground_blow(at: Vector3, reach: float, shake: float, direction: Vector3 = Vector3.ZERO, degrees: float = 360.0) -> void:
	var wave = Shockwave.make(at+Vector3.UP*game.world.lift(at),reach,direction,degrees)
	game.world.add_child(wave)
	waves.append(wave)
	game.shake(shake)

# Ground Slam's shockwave: seals racing out along the arc.
func shockwave(origin: Vector3, direction: Vector3, degrees: float, distance: float) -> void:
	var rays = maxi(3,roundi(degrees/18.0))
	for i in rays:
		var angle = deg_to_rad(degrees)*(float(i)/(rays-1)-.5)
		var wave: Dictionary = game.effect(origin,2.6,Color(1,.62,.2,.85),.4)
		wave.velocity = direction.rotated(Vector3.UP,angle)*distance/.4

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
			game.effect(origin+direction*1.3,CLEAVE_REACH*2,Color(1,.8,.4,.75),.3)
		"slam":
			for enemy in arc_targets(origin,direction,v.y,v.z):
				strike(enemy,attack_damage(v.x),"physical",0.0,StoneFragment.impact(enemy.position-origin,true))
			shockwave(origin,direction,v.y,v.z)
			ground_blow(origin+direction*.9,v.z,SHAKE_SLAM,direction,v.y)
		"leap":
			for enemy in targets(origin,LEAP_RADIUS):
				strike(enemy,attack_damage(v.x),"physical",0.0,StoneFragment.impact(enemy.position-origin,true))
			game.effect(origin,LEAP_RADIUS*2,Color(1,.55,.13,.95),.5)
			ground_blow(origin,LEAP_RADIUS,SHAKE_LEAP)
		"shockwave":
			for enemy in targets(origin,v.y):
				strike(enemy,attack_damage(v.x))
				var away: Vector3 = enemy.position-origin
				away.y = 0
				if away.length()>.05: enemy.shove(away.normalized(),SHOCKWAVE_THROW)
			shockwave(origin,direction,360.0,v.y)
			ground_blow(origin,v.y,SHAKE_SLAM)
		"cry":
			for enemy in targets(origin,v.x): enemy.rally(v.y,v.z)
			game.effect(origin,v.x*2,Color(1,.75,.3,.6),.5)
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
					game.effect(victim.position,2.2,Color(1,.85,.45,.9),.3)
				"bash":
					strike(victim,blow)
					victim.stun(v.y)
					game.effect(victim.position,2.4,Color(.7,.8,1,.9),.35)
				"vampiric":
					strike(victim,blow,"physical",victim.max_hp*v.y*.01)
					var healed: float = Data.max_health(game.run)*v.y*.01
					game.player.hp = minf(Data.max_health(game.run),game.player.hp+healed)
					game.float_text(game.player.position+Vector3.UP*1.8,"+%d" % roundi(healed),Color(.4,1,.55))
					game.effect(victim.position,2.2,Color(.85,.1,.15,.9),.4)
					game.effect(origin,2.2,Color(.3,1,.6,.7),.4)
				"shadow":
					# The lingering damage is raised by Offensive Rhythm as the blow is.
					var lingering: float = attack_damage(v.y)*rhythm_boost()
					strike(victim,blow)
					if not victim.dead:
						victim.add_dot("shadow",lingering,SHADOW_SECONDS,1)
						victim.refresh_dots("curse")
					game.effect(victim.position,2.4,Color(.5,.25,.85,.9),.45)
				"execute":
					# The opening may have closed since the swing began.
					if victim.hp/victim.max_hp>=v.y*.01: return
					strike(victim,blow)
					game.effect(victim.position,2.6,Color(1,.2,.12,.95),.4)
			game.player.landed_on(victim)
		"barrier": barrier = value; barrier_time = s.duration; game.effect(origin,3,Color(.4,.5,1),s.duration)
		"blink":
			game.effect(origin,2,Color(.6,.4,1),.4)
			game.player.position = game.world.move(origin,direction*minf(value,origin.distance_to(at)))
			game.effect(game.player.position,2,Color(.6,.4,1),.4)
		"shot","multishot","retreat","pierce","firebolt","lance":
			var spell: bool = s.tag=="spell"
			var angles = [-.18,0.0,.18] if s.effect=="multishot" else [0.0]
			for angle in angles:
				var aim = direction.rotated(Vector3.UP,angle)
				game.projectile(origin,origin+aim*13,damage,true,"fire" if s.effect=="firebolt" else ("arcane" if spell else "arrow"),s.effect in ["pierce","lance"])
			if s.effect=="retreat": game.player.position = game.world.move(origin,-direction*3)
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
				for i in 6: game.effect(current.lerp(enemy.position,i/5.0),.5,Color(.6,.7,1),.3)
				current = enemy.position
		"mark":
			var victims = targets(origin,float(s.radius))
			victims.sort_custom(func(a,b): return a.position.distance_squared_to(at)<b.position.distance_squared_to(at))
			if not victims.is_empty(): victims[0].mark_time = value
		"snare","trap","rain","blizzard","meteor":
			var duration: float = s.duration
			if s.effect in ["snare","trap"]: duration = 15.0*(1+Data.passive(game.run,"trapcraft")*.01)
			var color = Color(.3,.65,1,.7) if s.effect in ["snare","blizzard"] else Color(1,.6,.2,.7)
			game.effect(at,s.radius*2,color,duration)
			zones.append({"effect":s.effect,"at":at,"radius":float(s.radius),"damage":damage,"value":value,"life":duration,"tick":float(s.duration) if s.effect=="meteor" else (1.0 if s.effect=="trap" else 0.0),"pulses":4 if s.effect=="rain" else (5 if s.effect=="blizzard" else 3)})

# Shield Charge's blow on one unit: damage, thrown aside, the first stunned.
func charge_hit(enemy, direction: Vector3, v: Dictionary) -> void:
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
	game.effect(enemy.position,2.2,Color(.75,.85,1,.9),.3)

# Dash Attack: an enemy the dash passes through takes the rank's damage and is
# pushed back, out of the hero's path.
const DASH_PUSH = .8
func dash_hit(enemy, direction: Vector3, struck: Array) -> void:
	struck.append(enemy)
	strike(enemy,Book.values("dash_attack",rank("dash_attack")).x)
	var aside: Vector3 = enemy.position-game.player.position
	aside.y = 0
	var side: Vector3 = direction.cross(Vector3.UP)
	var push: Vector3 = (side if aside.dot(side)>=0 else -side)*.7+direction*.7
	enemy.shove(push.normalized(),DASH_PUSH)
	game.effect(enemy.position,1.6,Color(.6,.9,1,.7),.25)

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
			if z.effect=="snare":
				if not victims.is_empty():
					for e in victims: e.slow_time = z.value*(1+Data.passive(game.run,"trapcraft")*.01)
					z.life = 0
			elif z.effect=="trap":
				if not victims.is_empty(): pulse(z.at,z.radius,z.damage,"physical"); z.life = 0
			else:
				pulse(z.at,z.radius,z.damage,"frost" if z.effect=="blizzard" else ("fire" if z.effect=="meteor" else "physical"),1.5 if z.effect=="blizzard" else 0)
				z.tick += 1.0
				z.pulses -= 1
				if z.effect=="meteor" or z.pulses<=0: z.life = 0
		if z.life<=0: zones.remove_at(i)
