extends SceneTree
const Oracle = preload("res://scripts/actor.gd")
const Data=preload("res://scripts/data.gd")
const Motion=preload("res://scripts/combat_animation.gd")
const Book=preload("res://scripts/skill_data.gd")
const Items=preload("res://scripts/items.gd")
var passed: Array=[]
var failed: Array=[]
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func phase(visual) -> float:
	return visual.animator.current_animation_position/visual.animator.current_animation_length
func playback(visual, clip: String, duration: float, contacts: Array, context: String):
	# Leave the previous clip playing just before its end. This reproduced the
	# held-click bug: play(same_clip) used to resume its recovery instead.
	for repeat in 2:
		visual.play(clip,duration)
		check(is_zero_approx(phase(visual)),"New attack starts at wind-up: %s / %d" % [context,repeat])
		var previous = 0.0
		for contact in contacts:
			visual.animator.advance((contact-previous)*duration)
			check(absf(phase(visual)-contact)<.001,"Animation reaches contact on gameplay clock: %s / %d / %.2f" % [context,repeat,contact])
			previous = contact
		visual.animator.advance((.99-previous)*duration)
		check(visual.animator.is_playing() and absf(phase(visual)-.99)<.001,"Full recovery fits attack duration: %s / %d" % [context,repeat])
# `kind`: the plain weapon of that kind in hand ("unarmed": none).
func held_attacks(game, victim, class_id: String, kind: String, dt: float):
	game.run=Data.new_run(class_id); game.arm(kind)
	# (The sword's chain of swings: any one-handed sword, mace or axe.)
	var weapon: int=1 if Data.family(game.run)=="one" else Data.weapon(game.run)
	game.player.cooldown=0; game.player.busy=0; game.scheduled.clear()
	game.player.visual.play(game.player.visual.idle_action())
	game.skills.reset()
	game.left_held=true; game.right_held=false; game.target=victim
	game.order_pending=true; game.ordered_special=false; game.route.clear()
	# (Held where it stands but for the blows' own shoves, which it gives way
	# to as an enemy does: the hero steps in after it.)
	victim.dead=false; victim.hp=1000000; victim.stagger_time=1000000
	victim.position=game.world.move(game.world.spawn,Vector3(0,0,-1.4))
	game.player.position=game.world.spawn
	var starts=0; var contacts=0; var clock=0.0; var last_start=-100.0
	var profile=game.attack_profile()
	var context="%s %s at %d FPS" % [class_id,kind,roundi(1/dt)]
	while starts<4 or not game.scheduled.is_empty():
		game.player.tick(dt)
		victim.tick(dt)
		var old_hp: float=victim.hp; var old_projectiles: int=game.projectiles.size()
		game.tick_scheduled(dt)
		if victim.hp<old_hp or game.projectiles.size()>old_projectiles:
			contacts+=1
			# (A sword swing is the first share of its clip; the rest is its recovery.)
			var swing_share: float=Motion.SWORD_SWING_SHARE if weapon==1 else 1.0
			# (A swing that follows on a frame late takes over that far in, and makes it up.)
			check(absf(phase(game.player.visual)/swing_share-profile.contacts[0])<=dt/profile.duration*(1.5 if weapon==1 else 1.0)+.001,"One visible contact for each held attack: "+context)
		var ready: bool=game.player.cooldown<=0
		game.player_control(dt)
		if ready and game.player.cooldown>0:
			starts+=1
			# (The sword's next swing takes over from the last where that has run on to.)
			check(is_zero_approx(phase(game.player.visual)) or (weapon==1 and starts>1 and phase(game.player.visual)<=dt/profile.duration*Motion.SWORD_SWING_SHARE+.001),"Held click restarts each swing: "+context)
			check(clock-last_start>=profile.duration-.001,"Held click waits for full recovery: "+context)
			check(absf(game.player.busy-profile.duration)<.001 and absf(game.player.cooldown-profile.duration)<.001,"Visual and attack locks use one duration: "+context)
			last_start=clock
		if starts>=4: game.left_held=false; game.order_pending=false; game.target=null
		clock+=dt
		if clock>10: check(false,"Held attack test timed out: "+context); break
	check(starts==4 and contacts==4,"Four held attacks produce four animated contacts: %s (%d starts, %d contacts, foe %.2f m off)" % [context,starts,contacts,game.player.position.distance_to(victim.position)])
	# (The axe's chain is two cuts, the sword's three: after four swings each is somewhere else in it.)
	var axe_held: bool = Items.kind(game.run)=="axe"
	if weapon==1: check(game.player.visual.state==("SwordCut2L" if axe_held else "SwordCut1L") and game.sword_swing==(1 if axe_held else 0),"Held, the sword's swings follow one another round the chain: "+context)
	victim.dead=true
func live_attacks(game):
	# Exercise the normal frame callbacks as well as deterministic playback.
	for class_id in Data.CLASSES:
		game.run=Data.new_run(class_id); game.load_floor()
		for enemy in game.enemies: enemy.dead=true; enemy.visible=false
		var victim=game.enemies[0]
		victim.dead=false; victim.visible=true; victim.hp=1000000; victim.stagger_time=1000000
		victim.position=game.world.move(game.world.spawn,Vector3(0,0,-1.4))
		game.player.position=game.world.spawn
		game.invincible_test=true; game.save_timer=-1000000
		var completed=[0]
		var clip: String=Motion.NORMAL[Data.weapon(game.run)].clip
		game.player.visual.animator.animation_finished.connect(func(name):
			if name==game.player.visual.clips[clip]: completed[0]+=1)
		for i in 5: await process_frame
		game.left_held=true; game.target=victim; game.order_pending=true; game.ordered_special=false
		game.set_process(true)
		var starts=0; var previous_cooldown=0.0; var began=Time.get_ticks_msec()
		while completed[0]<4 and Time.get_ticks_msec()-began<15000:
			await process_frame
			if game.player.cooldown>previous_cooldown+.001:
				starts+=1
				check(completed[0]==starts-1,"Live held attack finishes the previous swing: "+class_id)
				if starts>=4: game.left_held=false; game.order_pending=false; game.target=null
			previous_cooldown=game.player.cooldown
		game.set_process(false)
		check(starts==4 and completed[0]==4,"Live held input produces four complete swings: "+class_id)
		print("LIVE_ATTACKS ",class_id," ",starts," starts / ",completed[0]," finished")
func test():
	preload("res://scripts/save.gd").directory=ProjectSettings.globalize_path("res://test-results/combat-timing-save")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode=true; game.set_process(false)
	game.sound.muted=true
	game.run=Data.new_run(); game.load_floor()
	for enemy in game.enemies: enemy.dead=true
	var victim=game.enemies[0]
	game.player.visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Every kind of weapon a hero may hold (its plain item), and bare hands.
	for kind in ["spear","sword","bow","axe","staff","dagger","mace","unarmed"]:
		game.arm(kind); game.run.energy=100
		var swung: String=Data.family(game.run)
		var profile=game.attack_profile()
		game.player.position=game.world.spawn; game.player.cooldown=0; game.player.busy=0
		game.target=null; game.route.clear(); game.scheduled.clear()
		for p in game.projectiles: p.node.queue_free()
		game.projectiles.clear()
		victim.dead=false; victim.hp=10000; victim.position=game.world.spawn+Vector3(0,0,1.4)
		game.attack(false,victim.position)
		# (The sword's first swing of its chain: Motion.SWORD_CHAIN.)
		check(game.player.visual.state in profile.clips and game.player.visual.clips.has(game.player.visual.state),"Basic uses its family's own animation: %s (%s)" % [kind,game.player.visual.state])
		var count=game.scheduled.size()
		game.attack(false,victim.position)
		check(game.scheduled.size()==count and game.run.energy==100,"Repeated input cannot restart basic attack; basics cost no energy")
		game.tick_scheduled(.2)
		check(victim.hp==10000 and game.projectiles.is_empty(),"Damage waits for contact: "+kind)
		game.tick_scheduled(profile.times[0]-.2+.001)
		if swung in ["bow","staff"]: check(game.projectiles.size()==1,"Ranged basic releases at contact: "+kind)
		else: check(victim.hp<10000,"Melee basic lands at contact: "+kind)
		# (The weapon's own time, but a staff's bolt keeps its family's.)
		var own: float = -1.0 if swung=="staff" else Data.attack_seconds(game.run,Data.scaling_tag(Data.weapon(game.run)))
		check(Motion.timed(swung,100,0.0,.65,own).duration>=profile.duration*.65-.001,"Speed bonus respects animation readability floor: "+kind)
		victim.dead=true
	# Fast and slow playback of every weapon clip, including multi-release bow.
	for weapon in 5:
		game.player.visual.equip(Data.WEAPONS[weapon])
		for special in [false,true]:
			var profile=Motion.profile(weapon,special,0)
			for duration in [.25,1.75]:
				playback(game.player.visual,profile.clip,duration,profile.contacts,"%s %.2fs" % [profile.clip,duration])
	# And every family's own clips, as the heroes swing them.
	for swung in Motion.FAMILIES:
		for clip in Motion.FAMILIES[swung].clips+([Motion.FAMILIES[swung].off] if Motion.FAMILIES[swung].has("off") else []):
			check(game.player.visual.clips.has(clip),"The hero has the %s family's clip %s" % [swung,clip])
			for duration in [.25,1.75]: playback(game.player.visual,clip,duration,Motion.FAMILIES[swung].contacts if not clip.begins_with("Sword") and clip!="OffCut" else [Motion.FAMILIES[swung].contacts[0]*Motion.SWORD_SWING_SHARE],"%s %.2fs" % [clip,duration])
	# (The wizard has no normal attack: his left click casts a spell.)
	for class_id in Data.CLASSES.filter(func(c): return not Data.casts_left(Data.new_run(c))):
		# (Only the kinds a weapon is made of: no spear yet.)
		for kind in Items.WIELDS[class_id].filter(func(k): return k!="shield" and Items.PLAIN.has(k))+["unarmed"]:
			for dt in [1.0/15,1.0/60]: held_attacks(game,victim,class_id,kind,dt)
	# All active class skills share the same restart and duration contract.
	for id in Book.all():
		var skill: Dictionary=Book.all()[id]
		if skill.effect=="passive": continue
		# (Those of the ranger's that take no time, need him hidden or out of
		# combat, or replay or hold their clip are timed in tests/ranger_skills.gd.)
		# (And the wizard's channelled spells, which are held rather than timed: tests/wizard_skills.gd.)
		if skill.effect in ["frenzy","vanish","hide","ambush","rapid","power","freezefloor","frostblast"]: continue
		game.run=Data.new_run(skill.class_id); game.run.skills[id]=1
		game.player.busy=0; game.player.cooldown=0; game.skills.reset(); game.leap_left=0
		game.player.position=game.world.spawn
		# Execute needs a wounded enemy in reach; the wizard's pointed spells, an enemy before him.
		victim.dead=skill.effect!="execute" and not skill.effect in ["prison","rod","shock","bolt"]; victim.hp=victim.max_hp*.1
		victim.position=game.world.spawn+Vector3(0,0,1.4)
		game.refit()
		check(game.skills.cast(id,victim.position),"Skill enters timed playback: "+id)
		var duration: float=game.player.busy
		var contact: float=game.skills.pending[0].time/duration
		playback(game.player.visual,game.player.visual.state,duration,[contact],id)
		game.player.busy=duration; game.player.cooldown=0
		var jobs=game.scheduled.size()
		game.attack(false,victim.position)
		check(game.scheduled.size()==jobs,"Basic cannot interrupt a skill recovery: "+id)
	victim.dead=true; game.leap_left=0; game.skills.reset()
	# Actual AI attacks use the same timed clip on each enemy rig.
	game.run=Data.new_run(); game.invincible_test=true
	# The Oracle's frost nova: cast when the hero comes close, blasting frost
	# all around it with the old ice bolt's damage and slow, every 15 seconds.
	game.invincible_test=false; game.player.invulnerable=0; game.slowed=0
	var frost_oracle=game.spawn_enemy("wizard","frost:oracle",game.world.spawn)
	frost_oracle.awake=true; frost_oracle.cooldown=1000000
	game.player.position=game.world.move(game.world.spawn,Vector3(0,0,-3.0))
	game.player.hp=game.player.max_hp
	var nova_hp: float=game.player.hp
	for step in 60: frost_oracle.tick(1.0/60); game.tick_fireballs(1.0/60)
	check(game.novas.size()==1 and game.player.hp<nova_hp and game.slowed>=4.0,"Frost nova hits and slows the hero within twice a sword's reach")
	check(game.projectiles.filter(func(p): return p.type=="ice").is_empty(),"The Oracle no longer fires ice bolts")
	check(frost_oracle.nova_cooldown>14.0,"Frost nova starts its 15-second cooldown")
	game.player.hp=game.player.max_hp; nova_hp=game.player.hp
	for step in 120: frost_oracle.tick(1.0/60); game.tick_fireballs(1.0/60)
	check(game.novas.size()<=1 and game.player.hp==nova_hp,"Frost nova waits for its cooldown")
	frost_oracle.nova_cooldown=0; frost_oracle.busy=0; frost_oracle.windup=0
	game.player.position=game.world.move(game.world.spawn,Vector3(0,0,-5.0))
	var before_novas: int=game.novas.size()
	for step in 60: frost_oracle.tick(1.0/60)
	check(frost_oracle.nova_cooldown==0 and game.novas.size()==before_novas,"Frost nova is only cast at close range")
	for step in 300: game.tick_fireballs(1.0/60)
	check(game.novas.is_empty(),"Frost nova effect cleans itself up")
	frost_oracle.dead=true; frost_oracle.visible=false
	game.slowed=0; game.player.hp=game.player.max_hp
	# The Oracle's fire spell: a lobbed fireball that damages only on impact,
	# 2-second cast, then the flight.
	game.invincible_test=false; game.player.invulnerable=0
	var oracle=game.spawn_enemy("wizard","fire:oracle",game.world.spawn)
	# Only the fireball here: the nova would fire if the hero stood close.
	oracle.awake=true; oracle.cast_count=0; oracle.nova_cooldown=1000
	game.player.position=game.world.move(game.world.spawn,Vector3(0,0,-7))
	game.player.hp=game.player.max_hp
	var before_hp: float=game.player.hp
	var fire_clock=0.0; var launched=-1.0; var landed=-1.0
	var bar_seen=false; var bar_progress=0.0
	var straight=true
	oracle.visible=true
	while fire_clock<4.0 and landed<0:
		oracle.tick(1.0/60); game.tick_fireballs(1.0/60); fire_clock+=1.0/60
		oracle.visible=true
		if launched<0:
			game.hud.show_cast_bars()
			var shown: Array=game.hud.cast_bars.filter(func(b): return b.visible)
			if not shown.is_empty(): bar_seen=true; bar_progress=maxf(bar_progress,shown[0].value)
		if launched<0 and not game.fireballs.is_empty():
			launched=fire_clock; check(game.player.hp==before_hp,"Fireball launch deals no damage")
			check(game.fireballs[0].origin.distance_to(oracle.visual.staff_tip())<.35 and oracle.visual.state=="OracleCast","The fireball leaves the crown of the Oracle's staff")
		if launched<0 and absf(fire_clock-1.2)<.01:
			oracle.visual.skeleton.force_update_all_bone_transforms(); oracle.visual.align_weapon()
			check(oracle.visual.oracle_flame.visible,"A flame forms in the staff's crown during the cast")
		if launched<0: check(game.effects.all(func(e): return not (e.node is Sprite3D)),"No red target ring on the ground during the cast")
		if launched>=0 and landed<0 and not game.fireballs.is_empty() and not game.fireballs[0].exploded:
			var ball=game.fireballs[0]
			straight=straight and Geometry3D.get_closest_point_to_segment(ball.position,ball.origin,ball.target).distance_to(ball.position)<.01
		if launched>=0 and game.player.hp<before_hp: landed=fire_clock
	check(launched>0 and landed>launched+.3,"Fireball flies before it explodes")
	check(straight,"The fireball flies in a straight line from the staff to its target")
	check(absf(landed-Oracle.FIRE_CAST-oracle.fireball_flight)<.05,"Fireball lands after its 2-second cast and flight (%.2fs)" % landed)
	check(bar_seen and bar_progress>.9,"A cast bar over the Oracle fills during the fireball cast")
	game.hud.show_cast_bars()
	check(game.hud.cast_bars.all(func(b): return not b.visible),"The cast bar clears once the fireball is released")
	check(game.fireballs.size()==1 and game.fireballs[0].exploded,"Explosion effect lingers after impact")
	for step in 300: game.tick_fireballs(1.0/60)
	check(game.fireballs.is_empty(),"Explosion cleans itself up")
	oracle.dead=true; oracle.visible=false
	game.player.hp=game.player.max_hp; game.invincible_test=true
	# Hit pushback: 50%, 30%, 15%, then 0% of the unit's normal time between
	# attacks, rooting it for that time; landing an attack resets it to 50%.
	var pushed=game.spawn_enemy("gladiator","pushback",game.world.spawn)
	pushed.awake=true
	game.player.position=game.world.move(game.world.spawn,Vector3(0,0,-6))
	var cycle: float=pushed.attack_cycle()
	for share in [.5,.3,.15,0.0]:
		pushed.cooldown=0; pushed.windup=0; pushed.busy=0; pushed.hit_stun=0
		pushed.hit(0)
		check(absf(pushed.cooldown-share*cycle)<.001 and absf(pushed.hit_stun-share*cycle)<.001,"Hit pushback of %d%% delays the next attack and roots the enemy" % roundi(share*100))
	pushed.cooldown=0; pushed.hit_stun=0; pushed.pushback_step=0
	pushed.hit(0)
	var rooted_at: Vector3=pushed.position
	for step in 20: pushed.tick(1.0/60)
	check(pushed.position.distance_to(rooted_at)<.001,"A pushed-back enemy cannot move")
	for step in 60: pushed.tick(1.0/60)
	check(pushed.position.distance_to(rooted_at)>.05 or pushed.windup>0 or pushed.busy>0,"It moves or attacks again once the pushback ends")
	game.invincible_test=false; game.player.invulnerable=0; game.player.hp=game.player.max_hp
	pushed.pushback_step=3
	game.hurt_player(1,"physical",pushed)
	check(pushed.pushback_step==0,"Landing an attack resets the pushback to 50%")
	pushed.pushback_step=3; game.player.invulnerable=1
	game.hurt_player(1,"physical",pushed)
	check(pushed.pushback_step==3,"An attack that deals no damage does not reset it")
	game.player.invulnerable=0; game.player.hp=game.player.max_hp; game.invincible_test=true
	pushed.dead=true; pushed.visible=false
	# The crown's gaze: a lightning beam from the boss's eyes, sweeping toward the
	# hero at a steady 30 degrees a second.
	var crowned=game.spawn_enemy("boss","gaze",game.world.spawn)
	crowned.awake=true; crowned.visible=true; crowned.laser_cooldown=1000
	game.player.position=game.world.spawn+Vector3(4,0,3)
	crowned.attack_point=game.world.spawn+Vector3(-4,0,3); crowned.cast_count=-1
	crowned.release_attack()
	check(crowned.laser_model!=null and crowned.laser_model.get_script().resource_path.ends_with("boss_laser.gd"),"The gaze is a beam, not a stretched arrow")
	var eyes: Array=crowned.laser_model.eyes()
	var head: Vector3=(crowned.visual.skeleton.global_transform*crowned.visual.skeleton.get_bone_global_pose(crowned.visual.skeleton.find_bone("Head"))).origin
	check(eyes[0].distance_to(head)<.4*crowned.visual.rig.scale.x and eyes[0].y>head.y,"The beam leaves the boss's eyes")
	var before_angle: float=crowned.laser_angle
	crowned.tick(.5)
	check(absf(absf(angle_difference(before_angle,crowned.laser_angle))-deg_to_rad(15))<.01,"The beam sweeps toward the hero at a steady 30 degrees a second")
	crowned.die(false)
	check(not is_instance_valid(crowned.laser_model) or crowned.laser_model.is_queued_for_deletion(),"The beam ends with the boss")
	game.enemies.erase(crowned); crowned.queue_free()
	game.player.hp=game.player.max_hp; game.slowed=0
	# Slain statues crumble into physical fragments with the original sound.
	var fallen=game.spawn_enemy("centurion","crumble",game.world.spawn)
	fallen.awake=true; fallen.visible=true
	fallen.die(false)
	check(fallen.visual.state=="Crumble" and fallen.visual.chips.size()==fallen.visual.CHIPS and fallen.visual.chips.all(func(c): return c is RigidBody3D),"A slain statue crumbles, throwing physical stone chips")
	for step in 90: fallen.tick(1.0/60)
	check(not fallen.visual.rig.visible and fallen.visual.chips.all(func(c): return c.visible),"The body is gone, leaving individual stone fragments")
	check(ResourceLoader.exists("res://assets/audio/stone-crumble.wav") and load("res://assets/audio/stone-crumble.wav") is AudioStreamWAV,"The original crumble sound is available")
	check(game.player.visual.crumbling<0,"The hero is not stone and never crumbles")
	fallen.visible=false
	# Only wizards back away from a nearby hero; archers hold their ground.
	for kind in ["archer","wizard"]:
		var ranged=game.spawn_enemy(kind,"retreat:"+kind,game.world.spawn)
		ranged.awake=true; ranged.cooldown=1000000; ranged.nova_cooldown=1000000
		game.player.position=game.world.move(game.world.spawn,Vector3(0,0,-3))
		var start: Vector3=ranged.position
		for step in 30: ranged.tick(1.0/30)
		var gap: float=ranged.position.distance_to(game.player.position)-start.distance_to(game.player.position)
		check(gap>.5 if kind=="wizard" else ranged.position.distance_to(start)<.01,"Close range: %s %s" % [kind,"retreats" if kind=="wizard" else "holds position"])
		ranged.dead=true; ranged.visible=false
	# A ranged statue that loses sight of the hero (in its reach, round a
	# corner) goes after him until it sees him again, and does not stand.
	for kind in ["archer","wizard"]:
		var hunter=game.spawn_enemy(kind,"hunt:"+kind,game.world.spawn)
		hunter.awake=true; hunter.cooldown=0; hunter.nova_cooldown=1000000
		# (Wherever the floor has one: the hero stands at a room's middle.)
		var hero: Vector3=game.world.spawn
		var hidden=Vector3.INF
		for room in game.world.layout.rooms:
			hero=game.world.layout.to_world(game.world.layout.center(room))
			if not game.world.fits(hero,.45): continue
			for cell in game.world.layout.cells:
				var at: Vector3=game.world.layout.to_world(cell)
				var gap: float=at.distance_to(hero)
				if gap>4.0 and gap<hunter.config.range-1.0 and game.world.fits(at,.45) and not game.world.clear_line(at,hero) and game.world.path(at,hero).size()>0:
					hidden=at; break
			if hidden!=Vector3.INF: break
		game.player.position=hero
		check(hidden!=Vector3.INF,"There is a spot in reach of the hero but out of his sight: "+kind)
		hunter.position=hidden
		var saw=false
		for step in 1500:
			hunter.tick(1.0/60)
			if game.world.clear_line(hunter.position,hero): saw=true; break
		check(saw and hunter.position.distance_to(hidden)>.05,"Out of sight in its reach, %s goes after the hero until it sees him" % kind)
		hunter.dead=true; hunter.visible=false
	for kind in ["gladiator","centurion","archer","wizard","lion","boss"]:
		var enemy=game.spawn_enemy(kind,"timing:"+kind,game.world.spawn)
		enemy.awake=true; enemy.laser_cooldown=1000000
		enemy.visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		game.player.position=game.world.move(game.world.spawn,Vector3(0,0,-1.4))
		var starts=0; var clock=0.0
		while starts<3:
			enemy.position=game.world.spawn
			var old_cooldown: float=enemy.cooldown
			enemy.tick(1.0/60)
			if enemy.cooldown>old_cooldown:
				starts+=1
				check(is_zero_approx(phase(enemy.visual)),"AI attack starts at wind-up: "+kind)
				check(enemy.find_children("*","Sprite3D",true,false).all(func(n): return not n.visible or n.texture==null or not n.texture.resource_path.ends_with("seal.png")),"No red seal under an attacking enemy: "+kind)
				if kind=="archer": check(enemy.visual.state=="ArcherShot" and absf(enemy.attack_cycle()-2.42)<.001,"Archers notch, draw and shoot, at the same time between shots")
				var duration: float=enemy.visual.animator.current_animation_length/enemy.visual.animator.get_playing_speed()
				# The Oracle's long cast keeps a brief follow-through rather than the
				# whole stretched clip; everyone else plays the clip to its end.
				if kind=="wizard": check(enemy.windup==Oracle.FIRE_CAST and enemy.attack_recovery==Oracle.FIRE_RECOVERY and duration>enemy.windup,"Oracle casts its fireball for two seconds")
				else: check(absf(duration-enemy.windup-enemy.attack_recovery)<.001,"AI contact and recovery fit the clip: "+kind)
			clock+=1.0/60
			if clock>15: check(false,"AI attack test timed out: "+kind); break
		# A hit mid-wind-up breaks the attack off: the enemy flinches, is rooted
		# for half its normal time between attacks, then starts a fresh swing.
		enemy.cooldown=0; enemy.busy=0; enemy.windup=0; enemy.pushback_step=0; enemy.hit_stun=0
		enemy.tick(.01); enemy.tick(.1)
		check(enemy.windup>0,"Enemy is mid-wind-up: "+kind)
		var push: float=.5*enemy.attack_cycle()
		if kind=="wizard":
			# An Oracle's cast is pushed back, not cancelled.
			var before_cast: float=enemy.windup; var before_phase: float=phase(enemy.visual)
			enemy.hit(0); enemy.tick(.1)
			check(absf(enemy.windup-(before_cast+push-.1))<.001 and enemy.visual.state=="OracleCast" and absf(phase(enemy.visual)-before_phase)<.001,"A hit pushes the Oracle's cast back without cancelling it")
			enemy.dead=true
			continue
		enemy.hit(0)
		check(enemy.windup==0 and enemy.visual.state.trim_prefix("Shield").trim_prefix("Scutum") in ["Hit","HitHead"] and absf(enemy.cooldown-push)<.001 and absf(enemy.hit_stun-push)<.001,"Hit mid-wind-up interrupts the swing with a flinch: "+kind)
		var restarted=false
		for step in int((push+.2)*60):
			enemy.tick(1.0/60)
			if enemy.windup>0 and not restarted:
				restarted=true
				check(is_zero_approx(phase(enemy.visual)) or phase(enemy.visual)<.05,"The swing starts again from the beginning after the delay: "+kind)
		check(restarted,"The enemy attacks again after the delay: "+kind)
		enemy.windup=0; enemy.busy=0
		enemy.hit(0)
		check(enemy.visual.state.trim_prefix("Shield").trim_prefix("Scutum") in ["Hit","HitHead"] and enemy.visual.reaction_time>0,"Idle enemy flinches when hit: "+kind)
		enemy.stun(4.0)
		var held: Vector3=enemy.position
		for step in 30: enemy.tick(1.0/60)
		check(enemy.stunned and absf(enemy.stagger_time-3.5)<.001 and enemy.windup<=0 and enemy.position.distance_to(held)<.001 and is_instance_valid(enemy.stun_mark),"A stunned enemy stands dazed under its mark: "+kind)
		enemy.hit(1)
		check(not enemy.stunned and enemy.stagger_time==0 and not is_instance_valid(enemy.stun_mark),"Damage breaks the stun: "+kind)
		enemy.dead=true
	game.player.visual.play("SwordSwing",1.0)
	game.player.visual.animator.active=false; game.player.visual.advance(.4)
	game.player.visual.animator.active=true; game.player.visual.advance(.2)
	check(absf(phase(game.player.visual)-.6)<.001,"Returning from culling restores the combat pose without slowing its clock")
	game.player.position=game.world.spawn
	for class_id in Data.CLASSES:
		game.run=Data.new_run(class_id)
		# The class's first skill, learned with the point it starts with and
		# put on RMB.
		var first: String = {"warrior":"cleave","ranger":"power_shot","wizard":"fireball"}[class_id]
		Data.Skills.learn(game.run,first); game.run.hotbar[0]=first
		game.skills.reset(); game.player.cooldown=0; game.player.busy=0
		game.refit()
		for p in game.projectiles: p.node.queue_free()
		game.projectiles.clear()
		for f in game.fireballs: f.queue_free()
		game.fireballs.clear()
		victim.dead=false; victim.hp=10000
		game.attack(true,victim.position)
		check(game.skills.pending.size()==1,"RMB queues assigned class starter: "+class_id)
		game.skills.tick(.1)
		check(victim.hp==10000 and game.projectiles.is_empty() and game.fireballs.is_empty(),"Class skill respects windup: "+class_id)
		# (The ranger's Power Shot is aimed for three seconds at its first rank.)
		game.skills.tick(3.0 if class_id=="ranger" else .5)
		# (The wizard's Fireball flies as the Oracle's does.)
		check(victim.hp<10000 or not game.projectiles.is_empty() or not game.fireballs.is_empty(),"Class skill executes after windup: "+class_id)
		game.skills.pending.clear(); game.player.busy=0
		game.skills.cast_slot(0,victim.position)
		game.run.energy=10; game.dash_cooldown=0; game.dash()
		check(is_equal_approx(game.run.energy,10.0) and game.dash_cooldown>0,"Evade costs no energy, and recharges")
		check(game.skills.pending.is_empty() and game.scheduled.is_empty(),"Evade cancels unfinished skill and basic attack jobs")
		victim.dead=true
	if "--live-attacks" in OS.get_cmdline_user_args(): await live_attacks(game)
	FileAccess.open("res://test-results/combat-timing.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("COMBAT_TIMING ",passed.size()," passed; ",failed)
	game.queue_free(); await process_frame; await process_frame
	quit(0 if failed.is_empty() else 1)
