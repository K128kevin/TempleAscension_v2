extends SceneTree
const Data=preload("res://scripts/data.gd")
const Motion=preload("res://scripts/combat_animation.gd")
const Book=preload("res://scripts/skill_data.gd")
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
func held_attacks(game, victim, class_id: String, weapon: int, dt: float):
	game.run=Data.new_run(class_id); game.run.weapon=weapon
	if class_id=="ranger": game.run.skills.quick_draw=3
	game.player.visual.equip(Data.WEAPONS[weapon])
	game.player.cooldown=0; game.player.busy=0; game.scheduled.clear()
	game.skills.reset()
	game.left_held=true; game.right_held=false; game.target=victim
	game.order_pending=true; game.ordered_special=false; game.route.clear()
	victim.dead=false; victim.hp=1000000
	victim.position=game.world.move(game.world.spawn,Vector3(0,0,-1.4))
	game.player.position=game.world.spawn
	var starts=0; var contacts=0; var clock=0.0; var last_start=-100.0
	var profile=Motion.profile(weapon,false,Data.passive(game.run,"quick_draw") if weapon==2 else 0,Data.cooldown(game.run))
	var context="%s %s at %d FPS" % [class_id,Data.WEAPONS[weapon],roundi(1/dt)]
	while starts<4 or not game.scheduled.is_empty():
		game.player.tick(dt)
		var old_hp: float=victim.hp; var old_projectiles: int=game.projectiles.size()
		game.tick_scheduled(dt)
		if victim.hp<old_hp or game.projectiles.size()>old_projectiles:
			contacts+=1
			check(absf(phase(game.player.visual)-profile.contacts[0])<=dt/profile.duration+.001,"One visible contact for each held attack: "+context)
		var ready: bool=game.player.cooldown<=0
		game.player_control(dt)
		if ready and game.player.cooldown>0:
			starts+=1
			check(is_zero_approx(phase(game.player.visual)),"Held click restarts each swing: "+context)
			check(clock-last_start>=profile.duration-.001,"Held click waits for full recovery: "+context)
			check(absf(game.player.busy-profile.duration)<.001 and absf(game.player.cooldown-profile.duration)<.001,"Visual and attack locks use one duration: "+context)
			last_start=clock
		if starts>=4: game.left_held=false; game.order_pending=false; game.target=null
		clock+=dt
		if clock>10: check(false,"Held attack test timed out: "+context); break
	check(starts==4 and contacts==4,"Four held attacks produce four animated contacts: "+context)
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
		var clip: String=Motion.NORMAL[game.run.weapon].clip
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
	for weapon in 5:
		var profile=Motion.profile(weapon,false,0)
		game.run.weapon=weapon; game.run.energy=100
		game.player.visual.equip(Data.WEAPONS[weapon])
		game.player.position=game.world.spawn; game.player.cooldown=0; game.player.busy=0
		game.target=null; game.route.clear(); game.scheduled.clear()
		for p in game.projectiles: p.node.queue_free()
		game.projectiles.clear()
		victim.dead=false; victim.hp=10000; victim.position=game.world.spawn+Vector3(0,0,1.4)
		game.attack(false,victim.position)
		check(game.player.visual.state==profile.clip,"Basic uses dedicated animation: "+profile.clip)
		var count=game.scheduled.size()
		game.attack(false,victim.position)
		check(game.scheduled.size()==count and game.run.energy==100,"Repeated input cannot restart basic attack; basics cost no energy")
		game.tick_scheduled(.2)
		check(victim.hp==10000 and game.projectiles.is_empty(),"Damage waits for contact: "+profile.clip)
		game.tick_scheduled(profile.times[0]-.2+.001)
		if weapon in [2,4]: check(game.projectiles.size()==1,"Ranged basic releases at contact")
		else: check(victim.hp<10000,"Melee basic lands at contact")
		check(Motion.profile(weapon,false,100).duration>=profile.duration*.65-.001,"Speed bonus respects animation readability floor")
		victim.dead=true
	# Fast and slow playback of every weapon clip, including multi-release bow.
	for weapon in 5:
		game.player.visual.equip(Data.WEAPONS[weapon])
		for special in [false,true]:
			var profile=Motion.profile(weapon,special,0)
			for duration in [.25,1.75]:
				playback(game.player.visual,profile.clip,duration,profile.contacts,"%s %.2fs" % [profile.clip,duration])
	for class_id in Data.CLASSES:
		for weapon in 5:
			for dt in [1.0/15,1.0/60]: held_attacks(game,victim,class_id,weapon,dt)
	# All active class skills share the same restart and duration contract.
	for id in Book.all():
		var skill: Dictionary=Book.all()[id]
		if skill.effect=="passive": continue
		game.run=Data.new_run(skill.class_id); game.run.skills[id]=1
		game.player.busy=0; game.player.cooldown=0; game.skills.reset()
		game.player.position=game.world.spawn
		game.player.visual.equip(Data.WEAPONS[game.run.weapon])
		check(game.skills.cast(id,victim.position),"Skill enters timed playback: "+id)
		var duration: float=game.player.busy
		var contact: float=game.skills.pending[0].time/duration
		playback(game.player.visual,game.player.visual.state,duration,[contact],id)
		game.player.busy=duration; game.player.cooldown=0
		var jobs=game.scheduled.size()
		game.attack(false,victim.position)
		check(game.scheduled.size()==jobs,"Basic cannot interrupt a skill recovery: "+id)
	# Actual AI attacks use the same timed clip on each enemy rig.
	game.run=Data.new_run(); game.invincible_test=true
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
				var duration: float=enemy.visual.animator.current_animation_length/enemy.visual.animator.get_playing_speed()
				check(absf(duration-enemy.windup-enemy.attack_recovery)<.001,"AI contact and recovery fit the clip: "+kind)
			clock+=1.0/60
			if clock>15: check(false,"AI attack test timed out: "+kind); break
		# Taking a hit delays both the telegraph and the animation equally.
		enemy.cooldown=0; enemy.busy=0; enemy.windup=0
		enemy.tick(.01); enemy.tick(.1)
		var before_phase: float=phase(enemy.visual); var before_windup: float=enemy.windup
		enemy.hit(0); enemy.tick(.1)
		check(absf(phase(enemy.visual)-before_phase)<.001 and absf(enemy.windup-before_windup)<.001,"Enemy hit delay keeps pose and contact synchronized: "+kind)
		enemy.dead=true
	game.player.visual.play("SwordSwing",1.0)
	game.player.visual.animator.active=false; game.player.visual.advance(.4)
	game.player.visual.animator.active=true; game.player.visual.advance(.2)
	check(absf(phase(game.player.visual)-.6)<.001,"Returning from culling restores the combat pose without slowing its clock")
	game.player.position=game.world.spawn
	for class_id in Data.CLASSES:
		game.run=Data.new_run(class_id)
		game.skills.reset(); game.player.cooldown=0; game.player.busy=0
		game.player.visual.equip(Data.WEAPONS[game.run.weapon])
		for p in game.projectiles: p.node.queue_free()
		game.projectiles.clear()
		victim.dead=false; victim.hp=10000
		game.attack(true,victim.position)
		check(game.skills.pending.size()==1,"RMB queues assigned class starter: "+class_id)
		game.skills.tick(.1)
		check(victim.hp==10000 and game.projectiles.is_empty(),"Class skill respects windup: "+class_id)
		game.skills.tick(.5)
		check(victim.hp<10000 or not game.projectiles.is_empty(),"Class skill executes after windup: "+class_id)
		game.skills.pending.clear(); game.player.busy=0
		game.skills.cast_slot(0,victim.position)
		game.run.energy=10; game.dash()
		check(is_equal_approx(game.run.energy,0.0),"Evade costs 10 energy")
		check(game.skills.pending.is_empty() and game.scheduled.is_empty(),"Evade cancels unfinished skill and basic attack jobs")
		victim.dead=true
	if "--live-attacks" in OS.get_cmdline_user_args(): await live_attacks(game)
	FileAccess.open("res://test-results/combat-timing.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("COMBAT_TIMING ",passed.size()," passed; ",failed)
	game.queue_free(); await process_frame; await process_frame
	quit(0 if failed.is_empty() else 1)
