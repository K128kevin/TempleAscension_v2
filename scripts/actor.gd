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
var dormant_offering = true
var dead = false
var cooldown = 0.0
var busy = 0.0
var windup = 0.0
var attack_recovery = .25
var attack_point = Vector3.ZERO
var warning: Sprite3D
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
var stagger_time = 0.0
var stagger_meter = 0.0
var hit_reactions = 0
# The Oracle's fireball takes two seconds to cast, shown by a cast bar; the
# ground warning lasts through the cast and the fireball's flight.
const FIRE_CAST = 2.0
const FIRE_RECOVERY = .6
var fireball_flight = 0.0
var cast_total = 0.0
var cast_ring: Dictionary = {}
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
		visual.setup(false,Color.WHITE,Data.WEAPONS[game.run.weapon])
	else:
		config = Data.ENEMIES[kind]
		max_hp = config.hp * Data.HEALTH_SCALE[game.run.difficulty]
		hp = max_hp
		visual.setup(true,config.color,config.weapon,config.size,kind)
		if kind == "boss": visual.crown()
		visual.animator.pause()
	warning = Art.seal(3.4,Color(1,.2,.08,.75))
	warning.position.y = .06
	warning.visible = false
	add_child(warning)

func tick(dt: float) -> void:
	if kind!="player" and not dead:
		visible = game.world.can_see(position)
		visual.animator.active = visible
	visual.advance(dt)
	slow_time = maxf(0,slow_time-dt)
	mark_time = maxf(0,mark_time-dt)
	stagger_time = maxf(0,stagger_time-dt)
	invulnerable = maxf(0,invulnerable-dt)
	busy = maxf(0,busy-dt)
	cooldown = maxf(0,cooldown-dt)
	nova_cooldown = maxf(0,nova_cooldown-dt)
	if dead:
		death_age += dt
		if death_age > 8 and kind != "player": visible = false
		return
	if kind == "player" or stagger_time>0: return
	var player = game.player
	var distance: float = position.distance_to(player.position)
	if kind == "offering":
		if dormant_offering: return
		if not is_instance_valid(game.boss) or game.boss.dead: die(false); return
		if position.distance_to(game.boss.position) < 1.8:
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
				game.wake_offerings(i)
		laser_cooldown -= dt
		if laser_time > 0:
			laser_time -= dt
			laser_angle = rotate_toward(laser_angle,atan2(player.position.x-position.x,player.position.z-position.z),deg_to_rad(30)*dt)
			face(position + Vector3(sin(laser_angle),0,cos(laser_angle)))
			laser_model.rotation.y = laser_angle
			laser_tick -= dt
			if laser_tick <= 0:
				laser_tick = .1
				var forward = Vector3(sin(laser_angle),0,cos(laser_angle))
				var offset: Vector3 = player.position-position
				if offset.dot(forward)>0 and offset.cross(forward).length()<.65 and game.world.clear_line(position,player.position): game.hurt_player(10*.6*Data.DAMAGE_SCALE[game.run.difficulty])
			if laser_time <= 0:
				laser_model.queue_free()
				busy = 0
			return
		if laser_cooldown <= 0 and windup <= 0:
			laser_cooldown = 16
			windup = 1.0
			cast_count = -1
			attack_point = player.position
			warning.visible = true
			visual.play("Cast",windup/.5)
			game.toast("THE CROWN'S GAZE — keep moving around the statue")
	if windup > 0:
		windup -= dt
		warning.modulate.a = .5 + .35 * sin(Time.get_ticks_msec()*.025)
		if windup <= 0:
			warning.visible = false
			release_attack()
		return
	if busy > 0: return
	if kind == "wizard" and nova_cooldown <= 0 and distance <= NOVA_RADIUS and game.world.clear_line(position,player.position):
		cast_nova()
		return
	var reach: float = config.range
	if distance <= reach and game.world.clear_line(position,player.position) and cooldown <= 0:
		face(player.position)
		attack_point = player.position
		windup = 1.5 if kind == "wizard" else (.65 if kind == "boss" else .42)
		if kind == "wizard":
			# Every ranged cast is the fireball; frost comes only as the nova.
			fireball_flight = clampf(distance/14.0,.4,.8)
			windup = FIRE_CAST
			cast_total = windup
			cast_ring = game.effect(attack_point,4.4,Color(1,.25,.12),FIRE_CAST+fireball_flight)
		cooldown = config.interval + windup
		warning.visible = true
		var clip = "Cast" if kind in ["wizard","archer"] else "Attack"
		var duration = windup+.25
		var weapon_index = Data.WEAPONS.find(config.weapon)
		var signature = {"centurion":Motion.SHIELD_STAB}.get(kind,{})
		if not signature.is_empty() and visual.clips.has(signature.clip):
			clip = signature.clip
			duration = windup/signature.contacts[0]
		elif weapon_index>=0 and visual.clips.has(Motion.NORMAL[weapon_index].clip):
			clip = Motion.NORMAL[weapon_index].clip
			duration = windup/Motion.NORMAL[weapon_index].contacts[0]
		attack_recovery = maxf(.25,duration-windup)
		# The long cast plays its wind-up slowly; the follow-through is brief.
		if kind == "wizard": attack_recovery = FIRE_RECOVERY
		visual.play(clip,duration)
	elif distance > reach * .85:
		walk_to(player.position,dt)
	elif kind == "wizard" and distance < 5:
		var direction: Vector3 = (position-player.position).normalized()
		var before = position
		position = game.world.move(position,direction*config.speed*(.4 if slow_time>0 else 1.0)*dt)
		face(player.position)
		visual.locomotion(position.distance_to(before)>.005,false)
	else: visual.locomotion(false,false)

func release_attack() -> void:
	if kind == "boss" and cast_count == -1:
		cast_count = 0
		laser_time = 5
		laser_angle = atan2(attack_point.x-position.x,attack_point.z-position.z)
		laser_model = Node3D.new()
		add_child(laser_model)
		var beam = Art.model("arrow",Vector3(.25,.25,28),Art.material("gold"))
		laser_model.add_child(beam)
		beam.position = Vector3(0,1.0,14)
		return
	busy = attack_recovery
	var damage: float = config.damage * .6 * Data.DAMAGE_SCALE[game.run.difficulty]
	if kind == "archer": game.projectile(position,attack_point,damage,false,"arrow")
	elif kind == "wizard":
		cast_total = 0
		var hand: Vector3 = visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_r")).origin
		game.fireball(hand+forward()*.25,attack_point,2.2,damage,fireball_flight)
		cast_ring = {}
	elif position.distance_to(game.player.position) <= config.range + .6 and game.world.clear_line(position,game.player.position):
		var d: Vector3 = (game.player.position-position).normalized()
		if forward().dot(d) > .2: game.hurt_player(damage)

# Instant: the blast goes off at once, the Oracle snapping into the release of
# its casting pose and recovering briefly.
func cast_nova() -> void:
	face(game.player.position)
	nova_cooldown = NOVA_COOLDOWN
	game.frost_nova(position,NOVA_RADIUS,7.5*.6*Data.DAMAGE_SCALE[game.run.difficulty])
	var contact: float = Motion.NORMAL[Data.WEAPONS.find("staff")].contacts[0]
	var duration = NOVA_RECOVERY/(1.0-contact)
	visual.play("Cast",duration)
	visual.advance(duration*contact)
	busy = NOVA_RECOVERY

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
		if difference.length_squared() < .85 and difference.length_squared() > .001: separation += difference.normalized()*.6
	direction = (direction + separation).normalized()
	var before = position
	position = game.world.move(position,direction*config.speed*(.4 if slow_time>0 else 1.0)*dt)
	if position.distance_to(before) > .005: face(position+direction)
	visual.locomotion(position.distance_to(before)>.005,false,kind=="lion")

func face(at: Vector3) -> void:
	var d = at-position
	if d.length_squared() > .001:
		rotation.y = atan2(d.x,d.z)
		visual.align_weapon()

func forward() -> Vector3:
	return Vector3(sin(rotation.y),0,cos(rotation.y))

func stagger(seconds: float) -> void:
	if kind=="boss":
		stagger_meter += 1
		if stagger_meter<3: return
		stagger_meter = 0
		seconds = minf(seconds,.6)
	stagger_time = maxf(stagger_time,seconds)
	windup = 0
	warning.visible = false
	# A cancelled cast clears its ground warning.
	if not cast_ring.is_empty(): cast_ring.life = minf(cast_ring.life,.15)
	cast_ring = {}
	cast_total = 0
	# Long staggers knock the statue down and let it rise as the stagger ends.
	if not dead and laser_time<=0: visual.react("HitKnockdown" if seconds>=1.2 else "HitStagger",seconds if seconds>=1.2 else .6)

# Light hits alternate chest and head flinches; heavy hits stagger. Wind-ups,
# attack recoveries, the boss's gaze and running reactions are not interrupted.
func react_to_hit(heavy: bool = false) -> void:
	if dead or windup>0 or busy>0 or laser_time>0: return
	if visual.reaction_time>0 and not (heavy and visual.state in ["Hit","HitHead"]): return
	hit_reactions += 1
	if heavy: visual.react("HitStagger",.6)
	else: visual.react("HitHead" if hit_reactions%2==0 else "Hit",.34)

func hit(damage: float, type: String = "physical") -> void:
	if dead or (kind == "offering" and dormant_offering): return
	damage = Data.mitigate(damage,35.0 if kind=="boss" else (20.0 if kind=="centurion" else 0.0),0.0,int(game.run.level),type)
	if mark_time>0: damage *= 1.2+Data.passive(game.run,"predator")*.01
	hp -= damage
	game.sound.play("weapon-impact",-15)
	game.float_text(position+Vector3.UP*1.6,str(roundi(damage)),Color(1,.83,.46))
	if hp <= 0: die()
	else:
		if not awake: game.awaken(self)
		react_to_hit()
		cooldown += .25
		if windup > 0:
			windup += .1
			visual.animation_delay += .1
			# Keep the fire warning up until the delayed fireball lands.
			if not cast_ring.is_empty(): cast_ring.life += .1; cast_ring.total += .1

func die(reward: bool = true) -> void:
	if dead: return
	dead = true
	hp = 0
	warning.visible = false
	if windup>0 and not cast_ring.is_empty(): cast_ring.life = minf(cast_ring.life,.15)
	cast_total = 0
	if is_instance_valid(laser_model): laser_model.queue_free()
	visual.play("Death")
	if reward: game.enemy_died(self)
