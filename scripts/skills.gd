extends Node
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
var game
var pending: Array = []
var zones: Array = []
var guard = 0.0
var war_cry = 0.0
var barrier = 0.0
var barrier_time = 0.0
var flask_time = 0.0
var flask_rate = 0.0

func reset() -> void:
	pending.clear()
	zones.clear()
	guard = 0; war_cry = 0; barrier = 0; barrier_time = 0; flask_time = 0

func reason(id: String) -> String:
	if id.is_empty(): return "No skill assigned. Open K to choose a skill."
	if not Book.all().has(id) or not game.run.skills.has(id): return "Learn this skill first."
	var s: Dictionary = Book.all()[id]
	if s.effect=="passive": return "Passive skills apply automatically."
	if not Book.compatible(id,int(game.run.weapon)): return "Requires %s." % ("sword and shield" if s.requirement=="shield" else s.requirement)
	if float(game.run.skill_cooldowns.get(id,0))>0: return "Recharging: %.1fs" % game.run.skill_cooldowns[id]
	if game.run.energy<cost(id): return "Not enough energy."
	return ""

func cost(id: String) -> float:
	var s: Dictionary = Book.all()[id]
	return float(s.cost)*(1.0-Data.passive(game.run,"efficient_casting")*.01 if s.requirement=="staff" else 1.0)

func cast_slot(slot: int, at: Vector3) -> bool:
	if slot<0 or slot>=5: return false
	return cast(game.run.hotbar[slot],at)

func cast(id: String, at: Vector3) -> bool:
	if game.mode!="playing" or game.player.dead or game.player.busy>0: return false
	var problem = reason(id)
	if not problem.is_empty():
		game.toast(problem)
		return false
	var s: Dictionary = Book.all()[id]
	var rank = int(game.run.skills[id])
	var direction: Vector3 = at-game.player.position
	direction.y = 0
	if direction.length()<.01: direction = game.player.forward()
	at = game.player.position+direction.normalized()*minf(direction.length(),14.0)
	if not game.world.clear_line(game.player.position,at) and s.effect not in ["blink","lunge","retreat"]:
		game.toast("The target is behind a wall.")
		return false
	game.run.energy -= cost(id)
	game.run.skill_cooldowns[id] = float(s.cooldown)
	game.order_pending = false
	game.route.clear()
	game.player.face(at)
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
		duration = .84; contact = duration*.52
	game.player.visual.play(clip,duration)
	game.player.busy = duration
	game.player.cooldown = duration
	pending.append({"time":contact,"id":id,"rank":rank,"at":at,"direction":direction.normalized()})
	return true

func targets(at: Vector3, radius: float) -> Array:
	return game.enemies.filter(func(e): return not e.dead and not (e.kind=="offering" and e.dormant_offering) and e.position.distance_to(at)<=radius and game.world.clear_line(at,e.position))

func hit(enemy, amount: float, type: String = "physical") -> void:
	if war_cry>0: amount *= 1.25
	enemy.hit(amount,type)

func pulse(at: Vector3, radius: float, damage: float, type: String, slow: float = 0) -> void:
	game.effect(at,radius*2,Color(.35,.7,1,.8) if type=="frost" else Color(1,.6,.18,.8),.45)
	for enemy in targets(at,radius):
		hit(enemy,damage,type)
		if slow>0: enemy.slow_time = maxf(enemy.slow_time,slow)

func execute(job: Dictionary) -> void:
	var s: Dictionary = Book.all()[job.id]
	var value = Book.value(job.id,job.rank)
	var damage = Data.damage_tag(game.run,s.tag,15.0*value) if not s.tag.is_empty() else 0.0
	var at: Vector3 = job.at
	var origin: Vector3 = game.player.position
	var direction: Vector3 = job.direction
	var victims = targets(origin,float(s.radius))
	victims.sort_custom(func(a,b): return a.position.distance_squared_to(at)<b.position.distance_squared_to(at))
	match s.effect:
		"guard": guard = value; game.effect(origin,2.8,Color(.9,.8,.4),value)
		"war_cry": war_cry = value; game.effect(origin,4,Color(1,.45,.15),value)
		"barrier": barrier = value; barrier_time = s.duration; game.effect(origin,3,Color(.4,.5,1),s.duration)
		"blink":
			game.effect(origin,2,Color(.6,.4,1),.4)
			game.player.position = game.world.move(origin,direction*minf(value,origin.distance_to(at)))
			game.effect(game.player.position,2,Color(.6,.4,1),.4)
		"lunge":
			game.player.position = game.world.move(origin,direction*minf(5,origin.distance_to(at)))
			pulse(game.player.position,2,damage,"physical")
		"cone","bash","execution","line":
			var hits = 0
			for enemy in victims:
				var offset: Vector3 = enemy.position-origin
				var forward: float = offset.dot(direction)
				if forward<0 or (s.effect=="line" and offset.cross(direction).length()>1.2): continue
				hit(enemy,damage*(2.0 if s.effect=="execution" and enemy.hp/enemy.max_hp<.35 else 1.0))
				if s.effect=="bash": enemy.stagger(float(s.duration))
				hits += 1
				if s.effect in ["bash","execution"]: break
			game.effect(origin+direction*1.5,4,Color(1,.8,.4),.4)
		"shot","multishot","retreat","pierce","firebolt","lance":
			var spell: bool = s.tag=="spell"
			var angles = [-.18,0.0,.18] if s.effect=="multishot" else [0.0]
			for angle in angles:
				var aim = direction.rotated(Vector3.UP,angle)
				game.projectile(origin,origin+aim*13,damage*(1.25 if war_cry>0 else 1.0),true,"fire" if s.effect=="firebolt" else ("arcane" if spell else "arrow"),s.effect in ["pierce","lance"])
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
				hit(enemy,damage,"arcane")
				for i in 6: game.effect(current.lerp(enemy.position,i/5.0),.5,Color(.6,.7,1),.3)
				current = enemy.position
		"mark":
			if not victims.is_empty():
				victims[0].mark_time = value
				game.effect(victims[0].position,2,Color(1,.2,.25),value)
		"snare","trap","rain","blizzard","whirlwind","meteor":
			var duration: float = s.duration
			if s.effect in ["snare","trap"]: duration = 15.0*(1+Data.passive(game.run,"trapcraft")*.01)
			var center = origin if s.effect=="whirlwind" else at
			var color = Color(.3,.65,1,.7) if s.effect in ["snare","blizzard"] else Color(1,.6,.2,.7)
			game.effect(center,s.radius*2,color,duration)
			zones.append({"effect":s.effect,"at":center,"radius":float(s.radius),"damage":damage,"value":value,"life":duration,"tick":float(s.duration) if s.effect=="meteor" else (1.0 if s.effect=="trap" else 0.0),"pulses":4 if s.effect=="rain" else (5 if s.effect=="blizzard" else 3)})

func tick(dt: float) -> void:
	guard = maxf(0,guard-dt); war_cry = maxf(0,war_cry-dt); barrier_time = maxf(0,barrier_time-dt)
	if barrier_time<=0: barrier = 0
	if flask_time>0:
		game.player.hp = minf(Data.max_health(game.run),game.player.hp+flask_rate*minf(dt,flask_time))
		flask_time = maxf(0,flask_time-dt)
	for id in game.run.skill_cooldowns: game.run.skill_cooldowns[id] = maxf(0,float(game.run.skill_cooldowns[id])-dt)
	for i in range(pending.size()-1,-1,-1):
		pending[i].time -= dt
		if pending[i].time<=0:
			var job: Dictionary = pending[i]; pending.remove_at(i)
			if not game.player.dead: execute(job)
	for i in range(zones.size()-1,-1,-1):
		var z: Dictionary = zones[i]
		z.life -= dt; z.tick -= dt
		if z.effect=="whirlwind": z.at = game.player.position
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
