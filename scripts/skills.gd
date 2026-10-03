extends Node
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
var game
var pending: Array = []
var zones: Array = []
var barrier = 0.0
var barrier_time = 0.0
# Seconds until a skill with a cooldown (Shield Bash) is ready again.
var cooldowns: Dictionary = {}
# Offensive and Defensive Rhythm: the stacks built, and how long they last.
var offense_stacks = 0
var offense_time = 0.0
var defense_stacks = 0
var defense_time = 0.0
# How far (centre to centre) the warrior's blows reach, and how far he leaps.
const MELEE_REACH = 1.9
const CLEAVE_REACH = 2.6
const LEAP_RANGE = 10.0
const LEAP_RADIUS = 3.0
const CURSE_SECONDS = 4.0
const SHADOW_SECONDS = 5.0
# Dash Attack's Cleave is a quick cut out of the dash.
const DASH_CLEAVE_SPEED = 1.6
# The warrior's blows, aimed by facing rather than at a point in sight.
const SWINGS = ["cleave","slam","strike","bash","vampiric","shadow","execute"]

func reset() -> void:
	pending.clear()
	zones.clear()
	cooldowns.clear()
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
	if s.effect=="bash": cooldowns[id] = Book.values(id,level).z
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
		duration = maxf(Data.MELEE_MINIMUM,.84/((1.0+Data.melee_haste(game.run)*.01)*(DASH_CLEAVE_SPEED if free else 1.0)))
		contact = duration*.52
	if s.effect=="leap":
		var gap: float = game.player.position.distance_to(at)
		# He lands beside a unit standing at the target, not on it.
		for enemy in game.targets(game.player):
			if not enemy.dead and not enemy.dormant and enemy.position.distance_to(at)<.6: gap = maxf(0.0,gap-game.player.standoff(enemy))
		game.start_leap(direction.normalized(),gap,contact)
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

# Every hit the hero lands on an enemy: Offensive Rhythm raises it and gains a
# stack, and Cursed Blade leaves its extra damage on the target. `bonus` is
# added after armor (Vampiric Strike's drain).
func strike(enemy, amount: float, type: String = "physical", bonus: float = 0.0) -> void:
	if not is_instance_valid(enemy) or enemy.dead or enemy.dormant: return
	var rhythm: Dictionary = Book.values("offensive_rhythm",rank("offensive_rhythm"))
	amount *= rhythm_boost()
	enemy.hit(amount,type,bonus)
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
			for enemy in arc_targets(origin,direction,v.y,v.z): strike(enemy,attack_damage(v.x))
			shockwave(origin,direction,v.y,v.z)
		"leap":
			for enemy in targets(origin,LEAP_RADIUS): strike(enemy,attack_damage(v.x))
			game.effect(origin,LEAP_RADIUS*2,Color(1,.55,.13,.95),.5)
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

func tick(dt: float) -> void:
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
