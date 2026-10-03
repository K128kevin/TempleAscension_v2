extends Node3D
const Data = preload("res://scripts/data.gd")
const Motion = preload("res://scripts/combat_animation.gd")
const Visual = preload("res://scripts/visual.gd")
const Art = preload("res://scripts/assets.gd")
var game
var visual
var kind = "player"
var uid = ""
var hp = 100.0
var max_hp = 100.0
var config: Dictionary = {}
var awake = false
# A summit centurion held in reserve until the Crowned Statue summons it.
var dormant = false
var dead = false
var cooldown = 0.0
var busy = 0.0
var windup = 0.0
var attack_recovery = .25
var attack_point = Vector3.ZERO
var route = PackedVector3Array()
var repath = 0.0
var death_age = 0.0
var cast_count = 0
var laser_cooldown = 7.0
var laser_time = 0.0
var laser_angle = 0.0
var laser_tick = 0.0
var laser_model: Node3D
var thresholds = 0
var invulnerable = 0.0
var slow_time = 0.0
var mark_time = 0.0
# Rooted and unable to act (Shield Bash's stun).
var stagger_time = 0.0
# A stun ends at the first damage. Stunned again within STUN_MEMORY seconds of
# the last one, a unit is stunned for half as long each time.
const STUN_MEMORY = 30.0
var stunned = false
var stun_memory = 0.0
var stun_count = 0
var stun_mark: Sprite3D
# Damage over time: Cursed Blade's stacks and Shadow Strike's lingering damage.
# Each is {"kind", "rate" (damage a second), "left", "seconds"}.
var dots: Array = []
var dot_shown = 0.0
var dot_clock = 0.0
var hit_reactions = 0
# Driven by the debug playground instead of the AI.
var puppet = false
var puppet_goal = null
# Hit pushback: each hit delays the next attack by a share of the unit's normal
# time between attacks, rooting it for that time; a wind-up or cast in progress
# is pushed back by the same amount. The share steps down with repeated hits
# and resets once the enemy lands an attack.
const PUSHBACK = [.5,.3,.15]
# The archer notches and draws before releasing; its interval is shortened to
# match, keeping the same time between shots.
const ARCHER_DRAW = 1.2
var pushback_step = 0
var hit_stun = 0.0
# The Oracle's fireball takes two seconds to cast, shown by a cast bar.
const FIRE_CAST = 2.0
const FIRE_RECOVERY = .6
var fireball_flight = 0.0
var cast_total = 0.0
# The Oracle's frost nova: an instant blast of ice all around it when the hero
# comes within twice a sword's reach, at most once every 15 seconds.
const NOVA_RADIUS = 3.8
const NOVA_RECOVERY = .5
const NOVA_COOLDOWN = 15.0
var nova_cooldown = 0.0

func setup(owner_game, type: String, id: String, at: Vector3) -> void:
	game = owner_game
	kind = type
	uid = id
	position = at
	visual = Visual.new()
	add_child(visual)
	if kind == "player":
		max_hp = Data.max_health(game.run)
		hp = max_hp
		visual.setup(false,Color.WHITE,Data.WEAPONS[game.run.weapon],1.0,"",game.run.class_id)
	else:
		config = Data.ENEMIES[kind]
		max_hp = config.hp * Data.HEALTH_SCALE[game.run.difficulty]
		hp = max_hp
		visual.setup(true,config.color,config.weapon,config.size,kind)
		if kind == "boss": visual.crown()
		visual.animator.pause()

func tick(dt: float) -> void:
	if kind!="player" and not dead:
		visible = game.world.can_see(position)
		visual.animator.active = visible
	visual.advance(dt)
	# Stepping into an attack carries the unit forward (Visual.ROOT_ADVANCE).
	# (Not in the air: a leap carries the hero itself.)
	var travel: float = visual.take_travel()
	if travel > 0.0 and not dead and not (kind == "player" and game.leap_left > 0): step_forward(travel)
	# (Cut short, the clip's step can't make up the rest: follow in.)
	if catch_up > 0.0 and visual.travel_to_come() <= 0.0:
		follow(catch_up)
		catch_up = 0.0
	# Shoved back by a blow, or following one in.
	if shove_left > 0.0:
		var step = minf(shove_left,shove_speed*dt)
		shove_left -= step
		if not dead: position = game.world.move(position,shove_dir*step)
	if follow_left > 0.0:
		var step = minf(follow_left,follow_speed*dt)
		follow_left -= step
		if not dead: position = game.world.move(position,follow_dir*step)
	# The feet step with the body as it is carried over the ground.
	visual.carried = shove_left > 0.0 or follow_left > 0.0
	visual.shoved = shove_left > 0.0
	visual.owed = shove_dir*shove_left+follow_dir*follow_left
	if held_travel > 0.0 and not strike_landed: visual.owed += forward()*held_travel
	visual.owed += forward()*catch_up
	slow_time = maxf(0,slow_time-dt)
	mark_time = maxf(0,mark_time-dt)
	stagger_time = maxf(0,stagger_time-dt)
	stun_memory = maxf(0,stun_memory-dt)
	if stunned and stagger_time<=0: end_stun()
	if is_instance_valid(stun_mark): stun_mark.rotation.y += dt*4.0
	hit_stun = maxf(0,hit_stun-dt)
	invulnerable = maxf(0,invulnerable-dt)
	busy = maxf(0,busy-dt)
	cooldown = maxf(0,cooldown-dt)
	nova_cooldown = maxf(0,nova_cooldown-dt)
	if dead:
		death_age += dt
		if death_age > 8 and kind != "player": visible = false
		return
	if kind == "player": return
	tick_dots(dt)
	if dead: return
	if stagger_time>0:
		# Stunned, it stands dazed once its flinch is over.
		visual.locomotion(false,false)
		return
	# Rooted by a hit: no moving, while the pushed-back attack timer runs.
	if hit_stun>0 and windup<=0 and laser_time<=0:
		visual.locomotion(false,false)
		return
	if puppet:
		puppet_tick(dt)
		return
	var player = game.player
	var distance: float = position.distance_to(player.position)
	if dormant: return
	if summoned():
		# The crown's summons never attack: they run to it and each one that
		# reaches it heals it by 5%. They fall with it.
		if not is_instance_valid(game.boss) or game.boss.dead:
			die(false)
		elif position.distance_to(game.boss.position) < 1.8+game.boss.config.size*.4:
			game.boss.hp = minf(game.boss.max_hp,game.boss.hp+game.boss.max_hp*.05)
			game.float_text(position,"+5%",Color(.7,.4,1))
			die(false)
		else: walk_to(game.boss.position,dt)
		return
	if not awake:
		if distance < 10 and game.world.clear_line(position,player.position): game.awaken(self)
		else: return
	if kind == "boss":
		for i in range(thresholds,4):
			if hp/max_hp <= .8 - i*.2:
				thresholds = i+1
				game.summon_centurions(i)
		laser_cooldown -= dt
		if laser_time > 0:
			gaze_tick(dt)
			return
		if laser_cooldown <= 0 and windup <= 0:
			laser_cooldown = 16
			start_gaze(player.position)
			game.toast("THE CROWN'S GAZE — keep moving around the statue")
	if windup > 0:
		windup -= dt
		if windup <= 0:
			release_attack()
		return
	if busy > 0: return
	if kind == "wizard" and nova_cooldown <= 0 and distance <= NOVA_RADIUS and game.world.clear_line(position,player.position):
		cast_nova()
		return
	var reach: float = config.range
	if distance <= reach and game.world.clear_line(position,player.position) and cooldown <= 0:
		start_attack(player.position)
	elif distance > reach * .85:
		walk_to(player.position,dt)
	elif kind == "wizard" and distance < 5:
		var direction: Vector3 = (position-player.position).normalized()
		var before = position
		var pace = config.speed*(.4 if slow_time>0 else 1.0)
		position = game.world.move(position,direction*pace*dt)
		face(player.position)
		# Backing away while facing the hero: the stride runs backward.
		visual.locomotion(position.distance_to(before)>.005,false,false,1.0,-pace)
	else: visual.locomotion(false,false)

# Begin this statue's attack at `point`: face it, wind up and play the clip.
func start_attack(point: Vector3) -> void:
	face(point)
	attack_point = point
	begin_strike(point)
	windup = 1.5 if kind == "wizard" else (.65 if kind == "boss" else (ARCHER_DRAW if kind == "archer" else .42))
	if kind == "wizard":
		# Every ranged cast is the fireball; frost comes only as the nova.
		fireball_flight = clampf(position.distance_to(point)/14.0,.4,.8)
		windup = FIRE_CAST
		cast_total = windup
	cooldown = config.interval + windup
	var clip = "Cast" if kind in ["wizard","archer"] else "Attack"
	var duration = windup+.25
	var weapon_index = Data.WEAPONS.find(config.weapon)
	var signature = {"centurion":Motion.SHIELD_STAB,"archer":Motion.ARCHER_SHOT,"wizard":Motion.ORACLE_CAST,"lion":Motion.LION_SWIPE}.get(kind,{})
	if not signature.is_empty() and visual.clips.has(signature.clip):
		clip = signature.clip
		duration = windup/signature.contacts[0]
	elif weapon_index>=0 and visual.clips.has(Motion.NORMAL[weapon_index].clip):
		clip = Motion.NORMAL[weapon_index].clip
		duration = windup/Motion.NORMAL[weapon_index].contacts[0]
		# A shield bearer swings with his shield held in its guard.
		if is_instance_valid(visual.shield_item) and visual.clips.has("Scutum"+clip): clip = "Scutum"+clip
	attack_recovery = maxf(.25,duration-windup)
	# The long cast plays its wind-up slowly; the follow-through is brief.
	if kind == "wizard": attack_recovery = FIRE_RECOVERY
	visual.play(clip,duration)

# The Crowned Statue's gaze: a one-second wind-up, then the beam.
func start_gaze(point: Vector3) -> void:
	windup = 1.0
	cast_count = -1
	attack_point = point
	visual.play("Cast",windup/.5)

# The beam sweeps toward the hero, ticking damage while it crosses them.
func gaze_tick(dt: float) -> void:
	var player = game.player
	laser_time -= dt
	laser_angle = rotate_toward(laser_angle,atan2(player.position.x-position.x,player.position.z-position.z),deg_to_rad(30)*dt)
	face(position + Vector3(sin(laser_angle),0,cos(laser_angle)))
	laser_model.tick(dt,laser_angle)
	laser_tick -= dt
	if laser_tick <= 0:
		laser_tick = .1
		var forward = Vector3(sin(laser_angle),0,cos(laser_angle))
		var offset: Vector3 = player.position-position
		if game.puppet_attack(self):
			for other in game.targets(self):
				var along: Vector3 = other.position-position
				if not other.dead and along.dot(forward)>0 and along.cross(forward).length()<.65 and game.world.clear_line(position,other.position): other.hit(0)
		elif offset.dot(forward)>0 and offset.cross(forward).length()<.65 and game.world.clear_line(position,player.position): game.hurt_player(10*.6*Data.DAMAGE_SCALE[game.run.difficulty],"physical",self)
	if laser_time <= 0:
		laser_model.queue_free()
		busy = 0

# Playground control: the statue acts only when told to.
func puppet_tick(dt: float) -> void:
	if laser_time > 0:
		gaze_tick(dt)
		return
	if windup > 0:
		windup -= dt
		if windup <= 0: release_attack()
		return
	if busy > 0: return
	if puppet_goal != null and position.distance_to(puppet_goal) > .3:
		walk_to(puppet_goal,dt)
	else:
		puppet_goal = null
		visual.locomotion(false,false)

# Playground: fall as if slain (statues crumble), with no rewards.
func playground_kill() -> void:
	if dead: return
	dead = true
	windup = 0; busy = 0; cast_total = 0; laser_time = 0
	if is_instance_valid(laser_model): laser_model.queue_free()
	if kind == "player": visual.play("Death")
	else:
		visual.crumble()
		game.sound.play("stone-crumble",-8)

# Playground: stand back up, whole, with a freshly built model.
func playground_revive(weapon: String = "") -> void:
	dead = false
	death_age = 0
	hp = max_hp
	visible = true
	end_stun(); dots.clear(); hit_stun = 0; pushback_step = 0
	visual.queue_free()
	visual = Visual.new()
	add_child(visual)
	if kind == "player": visual.setup(false,Color.WHITE,weapon,1.0,"",game.run.class_id)
	else:
		visual.setup(true,config.color,config.weapon,config.size,kind)
		if kind == "boss": visual.crown()

func release_attack() -> void:
	if kind == "boss" and cast_count == -1:
		cast_count = 0
		laser_time = 5
		laser_angle = atan2(attack_point.x-position.x,attack_point.z-position.z)
		# A red lightning beam from the boss's eyes, as in the original game.
		laser_model = preload("res://scripts/boss_laser.gd").new()
		add_child(laser_model)
		laser_model.setup(game,self)
		laser_model.tick(0.0,laser_angle)
		return
	busy = attack_recovery
	var damage: float = config.damage * .6 * Data.DAMAGE_SCALE[game.run.difficulty]
	if kind == "archer": game.projectile(position,attack_point,damage,false,"arrow",false,self)
	elif kind == "wizard":
		cast_total = 0
		# The fireball leaves the crown of the staff, where the flame formed.
		visual.align_weapon()
		game.fireball(visual.staff_tip(),attack_point,2.2,damage,fireball_flight,self)
	elif game.puppet_attack(self):
		# A playground statue's swing lands on whoever stands in front of it.
		for other in game.targets(self):
			if other.dead or position.distance_to(other.position) > strike_reach(other) or not game.world.clear_line(position,other.position): continue
			if forward().dot((other.position-position).normalized()) > .2:
				other.hit(damage)
				landed_on(other)
	elif position.distance_to(game.player.position) <= strike_reach(game.player) and game.world.clear_line(position,game.player.position):
		var d: Vector3 = (game.player.position-position).normalized()
		if forward().dot(d) > .2: game.hurt_player(damage,"physical",self)

# How far (centre to centre) this statue's blow reaches `other` as it lands:
# a little beyond where it attacks from, or as far as its weapon's point
# reaches ("strike"), and further into a bulkier statue.
func strike_reach(other) -> float:
	if not config.has("strike"): return config.range+.6
	var bulk = maxf(0.0,other.config.size-1.0)*.3 if other.kind != "player" else 0.0
	return config.strike+bulk

# Instant: the blast goes off at once, the Oracle snapping into the release of
# its casting pose and recovering briefly.
func cast_nova() -> void:
	face(game.player.position)
	nova_cooldown = NOVA_COOLDOWN
	game.frost_nova(position,NOVA_RADIUS,7.5*.6*Data.DAMAGE_SCALE[game.run.difficulty],self)
	# Straight to the staff swing: the nova needs no flame.
	var clip = "OracleCast" if visual.clips.has("OracleCast") else "Cast"
	var contact: float = Motion.ORACLE_CAST.contacts[0] if clip=="OracleCast" else Motion.NORMAL[Data.WEAPONS.find("staff")].contacts[0]
	var duration = NOVA_RECOVERY/(1.0-contact)
	# Into the swing's release, crossfading rather than jumping there.
	visual.play_from(clip,duration,contact)
	busy = NOVA_RECOVERY

# One of the centurions the Crowned Statue summons on the summit.
func summoned() -> bool:
	return uid.begins_with("summoned:")

func walk_to(destination: Vector3, dt: float) -> void:
	repath -= dt
	var direct: bool = game.world.clear_line(position,destination)
	if repath <= 0 and not direct:
		repath = .6 + float(uid.hash()%7)*.035
		route = game.world.path(position,destination)
	var next = destination
	if not direct:
		if route.is_empty(): visual.locomotion(false,false); return
		next = route[0]
		if position.distance_to(next) < .3:
			route.remove_at(0)
			return
	var direction = (next-position).normalized()
	var separation = Vector3.ZERO
	for other in game.enemies:
		if other == self or other.dead or not other.awake: continue
		var difference: Vector3 = position-other.position
		# (A lion is two metres long: it keeps a body's length from the others.)
		var room = 2.6 if kind == "lion" or other.kind == "lion" else .85
		if difference.length_squared() < room and difference.length_squared() > .001: separation += difference.normalized()*.6
	direction = (direction + separation).normalized()
	var before = position
	var pace = config.speed*(.4 if slow_time>0 else 1.0)
	position = game.world.move(position,direction*pace*dt)
	if position.distance_to(before) > .005: face(position+direction)
	visual.locomotion(position.distance_to(before)>.005,false,kind=="lion",1.0,pace)

# Where the unit's current attack is aimed, and the unit it is aimed at.
# Stepping in, it stops short of that unit; the step it is denied is held
# until its blow lands on the unit, which is then driven back as far as the
# attacker's whole step would have taken it past (the held step and what is
# left of the clip's), in one shove, the attacker stepping in after it as far
# as the unit gives (a unit backed against a wall cannot give ground, and the
# attacker stays where it is). The held step is made up through the rest of
# the clip's own step in (its footwork stepping the longer way), or, if the
# clip has no more step to take, by following the unit in.
var root_goal = null
var root_target = null
var held_travel = 0.0
var strike_landed = false
# After the blow has landed: how much further the attacker may follow in, and
# the held step still to make up through the clip's own (at this much per
# metre of it).
var follow_budget = 0.0
var catch_up = 0.0
var catch_rate = 0.0
# A shove back: its direction, how far is left to go, and how fast (it moves
# at a steady pace, stepping with it: scripts/foot_planter.gd).
var shove_dir = Vector3.ZERO
var shove_left = 0.0
var shove_speed = 0.0
# Following a shoved unit in.
var follow_dir = Vector3.ZERO
var follow_left = 0.0
var follow_speed = 0.0
# How fast a blow drives a unit back (metres a second).
const SHOVE_SPEED = 1.5

# Begins an attack stepping in at `point` (Visual.ROOT_ADVANCE).
func begin_strike(point: Vector3) -> void:
	root_goal = point
	held_travel = 0.0
	strike_landed = false
	follow_budget = 0.0
	catch_up = 0.0
	root_target = null
	var nearest = 1.3
	for other in game.targets(self) if game.puppet_attack(self) or kind == "player" else [game.player]:
		if not is_instance_valid(other) or other.dead or other == self: continue
		var d = Vector2(other.position.x-point.x,other.position.z-point.z).length()
		if d < nearest:
			nearest = d
			root_target = other

# How close this unit steps to `other` (its reach, plus a big unit's bulk).
func standoff(other) -> float:
	# (Far enough that a lunging body, its shield and its blade stop short of
	# the other's.)
	var mine = 1.05 if kind == "player" else 1.0*config.size
	if other == null or other.kind == "player": return mine
	return mine+maxf(0.0,(other.config.size-1.0)*.5)

func step_forward(distance: float) -> void:
	if strike_landed and catch_up > 0.0:
		var extra = minf(catch_up,distance*catch_rate)
		catch_up -= extra
		distance += extra
	var target = root_target if is_instance_valid(root_target) and not root_target.dead else null
	var goal = target.position if target != null else root_goal
	if goal != null:
		var gap = Vector2(goal.x-position.x,goal.z-position.z).length()
		var allowed = maxf(0.0,gap-standoff(target))
		if distance > allowed and target != null:
			var denied = distance-allowed
			# Once the blow has landed, the step follows the driven unit in,
			# as far as it gives.
			if strike_landed: follow(denied)
			else: held_travel += denied
		distance = minf(distance,allowed)
		if strike_landed: follow_budget = maxf(0.0,follow_budget-distance)
	if distance > 0.0: position = game.world.move(position,forward()*distance)

# The blow lands on `victim`: if it is the unit this attack stepped in on and
# the step was held short of it, it is driven back that far and the attacker
# follows it in.
func landed_on(victim) -> void:
	if victim != root_target or not is_instance_valid(victim) or strike_landed: return
	strike_landed = true
	if held_travel <= 0.0 or victim.dead: return
	var to_come: float = visual.travel_to_come()
	follow_budget = victim.shove(forward(),held_travel+to_come)
	if to_come > .05:
		catch_up = held_travel
		catch_rate = held_travel/to_come
	else: follow(held_travel)
	held_travel = 0.0

# Steps in after the driven unit by up to `distance`, at its pace, as far as
# it gives.
func follow(distance: float) -> void:
	var add = minf(distance,follow_budget)
	if add <= 0.0: return
	follow_budget -= add
	follow_dir = forward()
	follow_left += add
	follow_speed = SHOVE_SPEED

# Drives this unit along `direction` by up to `distance` more, at
# SHOVE_SPEED, as far as the walls allow (counting the drive still under way);
# returns how far that adds.
func shove(direction: Vector3, distance: float) -> float:
	var start: Vector3 = position+shove_dir*shove_left
	var free: Vector3 = game.world.move(start,direction*distance)
	var room = Vector2(free.x-start.x,free.z-start.z).length()
	if room < .005: return 0.0
	shove_dir = direction
	shove_left += room
	shove_speed = SHOVE_SPEED
	return room

func face(at: Vector3) -> void:
	var d = at-position
	if d.length_squared() > .001:
		rotation.y = atan2(d.x,d.z)
		# The body turns there itself, smoothly (Visual.turn_toward_facing).
		visual.keep_facing()
		visual.align_weapon()

func forward() -> Vector3:
	return Vector3(sin(rotation.y),0,cos(rotation.y))

# Shield Bash: stunned for `seconds` (less when stunned again soon after), its
# attack broken off, until the time runs out or it takes damage. The crown's
# gaze, once it burns, cannot be stopped.
func stun(seconds: float) -> void:
	if dead or dormant or laser_time>0: return
	stun_count = stun_count+1 if stun_memory>0 else 0
	stun_memory = STUN_MEMORY
	seconds *= pow(.5,stun_count)
	stunned = true
	stagger_time = seconds
	if kind == "boss" and cast_count == -1:
		# An interrupted gaze is tried again afterward, not lost to its cooldown.
		cast_count = 0
		laser_cooldown = seconds
	windup = 0
	cast_total = 0
	busy = 0
	visual.react("HitStagger",.6)
	if not is_instance_valid(stun_mark):
		# A gold halo turning over its head.
		stun_mark = Art.seal(.8*config.get("size",1.0),Color(1,.88,.35,.95))
		stun_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stun_mark)
		stun_mark.position = Vector3.UP*config.get("size",1.0)*2.2
	game.float_text(position+Vector3.UP*1.9,"Stunned",Color(1,.88,.35))

func end_stun() -> void:
	stunned = false
	stagger_time = 0
	if is_instance_valid(stun_mark): stun_mark.queue_free()
	stun_mark = null

# Adds `total` damage over `seconds`. At most `cap` of a kind run at once: the
# oldest gives way.
func add_dot(dot_kind: String, total: float, seconds: float, cap: int) -> void:
	if dead or dormant or total<=0 or seconds<=0: return
	var same: Array = dots.filter(func(d): return d.kind==dot_kind)
	if same.size()>=cap: dots.erase(same[0])
	dots.append({"kind":dot_kind,"rate":total/seconds,"left":seconds,"seconds":seconds})

# Starts every running effect of a kind over from its full time.
func refresh_dots(dot_kind: String) -> void:
	for d in dots:
		if d.kind==dot_kind: d.left = d.seconds

func tick_dots(dt: float) -> void:
	if dots.is_empty(): return
	var total = 0.0
	for i in range(dots.size()-1,-1,-1):
		var d: Dictionary = dots[i]
		var step = minf(dt,d.left)
		total += d.rate*step
		d.left -= dt
		if d.left<=0: dots.remove_at(i)
	if dead or game.playground != null:
		dots.clear()
		return
	var dealt: float = Data.mitigate(total,armor(),0.0,int(game.run.level),"physical")
	hp -= dealt
	if dealt>0: end_stun()
	# Shown as one number every half second rather than one a frame.
	dot_shown += dealt
	dot_clock += dt
	if dot_clock>=.5 or hp<=0 or dots.is_empty():
		if dot_shown>=.5: game.float_text(position+Vector3.UP*1.2,str(roundi(dot_shown)),Color(.72,.45,1))
		dot_shown = 0.0
		dot_clock = 0.0
	if hp<=0: die()

func armor() -> float:
	return 35.0 if kind=="boss" else (20.0 if kind=="centurion" else 0.0)

# Light hits alternate chest and head flinches; heavy hits stagger. Wind-ups,
# attack recoveries, the boss's gaze and running reactions are not interrupted.
func react_to_hit(heavy: bool = false) -> void:
	if dead or windup>0 or busy>0 or laser_time>0: return
	if visual.reaction_time>0 and not (heavy and visual.state.trim_prefix("Shield").trim_prefix("Scutum") in ["Hit","HitHead"]): return
	hit_reactions += 1
	if heavy: visual.react("HitStagger",.6)
	else: visual.react("HitHead" if hit_reactions%2==0 else "Hit",.34)

# `bonus` is damage added after armor.
func hit(damage: float, type: String = "physical", bonus: float = 0.0) -> void:
	if dead or dormant: return
	if game.playground != null:
		# The playground shows every hit, but nothing takes damage.
		game.sound.play("weapon-impact",-15)
		react_to_hit()
		if kind != "player": push_back()
		return
	damage = Data.mitigate(damage,armor(),0.0,int(game.run.level),type)+bonus
	if mark_time>0: damage *= 1.2+Data.passive(game.run,"predator")*.01
	hp -= damage
	if damage>0: end_stun()
	game.sound.play("weapon-impact",-15)
	game.float_text(position+Vector3.UP*1.6,str(roundi(damage)),Color(1,.83,.46))
	if hp <= 0: die()
	else:
		if not awake: game.awaken(self)
		react_to_hit()
		push_back()

func push_back() -> void:
	if pushback_step >= PUSHBACK.size(): return
	var delay: float = PUSHBACK[pushback_step]*attack_cycle()
	pushback_step += 1
	if windup > 0 and kind == "wizard" and cast_total > 0:
		# An Oracle's cast is not cancelled but pushed back: the cast bar loses
		# ground and the casting pose holds.
		windup += delay
		visual.animation_delay += delay
	elif windup > 0:
		# Caught winding up: the attack is broken off. The enemy
		# flinches, stays rooted for the delay, then starts a fresh attack.
		windup = 0
		cast_total = 0
		busy = 0
		if kind == "boss" and cast_count == -1:
			# The crown's gaze is retried after the delay, not lost to its cooldown.
			cast_count = 0
			laser_cooldown = delay
		cooldown = delay
		hit_stun = delay
		hit_reactions += 1
		visual.react("HitHead" if hit_reactions%2==0 else "Hit",minf(delay,.4))
	else:
		cooldown += delay
		hit_stun = maxf(hit_stun,delay)

# The unit's normal time between attacks: its interval plus its wind-up.
func attack_cycle() -> float:
	var typical = FIRE_CAST if kind == "wizard" else (.65 if kind == "boss" else (ARCHER_DRAW if kind == "archer" else .42))
	return config.interval + typical

# An attack of this enemy damaged the hero: its pushback starts over.
func landed_attack() -> void:
	pushback_step = 0
	# (A statue's blow landing on the hero.)
	landed_on(game.player)

func die(reward: bool = true) -> void:
	if dead or game.playground != null: return
	dead = true
	hp = 0
	cast_total = 0
	dots.clear()
	end_stun()
	if is_instance_valid(laser_model): laser_model.queue_free()
	# Statues crumble into a rubble pile, with the original game's crumble sound.
	visual.crumble()
	game.sound.play("stone-crumble",-8)
	if reward: game.enemy_died(self)
