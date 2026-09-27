extends SceneTree
const Data=preload("res://scripts/data.gd")
const Motion=preload("res://scripts/combat_animation.gd")
var passed: Array=[]
var failed: Array=[]
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func test():
	preload("res://scripts/save.gd").directory=ProjectSettings.globalize_path("res://test-results/combat-timing-save")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode=true; game.set_process(false)
	game.run=Data.new_run(); game.load_floor()
	for enemy in game.enemies: enemy.dead=true
	var victim=game.enemies[0]
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
		game.skills.pending.clear(); game.run.skill_cooldowns.clear(); game.player.busy=0
		game.skills.cast_slot(0,victim.position)
		game.dash_cd=0; game.dash()
		check(game.skills.pending.is_empty() and game.scheduled.is_empty(),"Evade cancels unfinished skill and basic attack jobs")
		victim.dead=true
	FileAccess.open("res://test-results/combat-timing.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("COMBAT_TIMING ",passed.size()," passed; ",failed)
	game.queue_free(); await process_frame; await process_frame
	quit(0 if failed.is_empty() else 1)
