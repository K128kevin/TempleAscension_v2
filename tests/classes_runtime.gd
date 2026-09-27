extends SceneTree
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
var game
var passed: Array = []
var failed: Array = []
var render = false
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func snapshot(name: String):
	if not render: return
	game.hud.tick(0)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/class-"+name+".png")
func test():
	render = "--render-classes" in OS.get_cmdline_user_args()
	Save.directory = ProjectSettings.globalize_path("res://test-results/class-runtime-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	for class_id in Data.CLASSES:
		game.run = Data.new_run(class_id)
		game.load_floor()
		check(game.mode=="playing" and game.run.weapon=={"warrior":1,"ranger":2,"wizard":4}[class_id],"Playable starting class and equipment: "+class_id)
		var victim = game.enemies[0]
		var origin: Vector3 = game.world.spawn
		var at: Vector3 = game.world.move(origin,Vector3(0,0,-1.4))
		for e in game.enemies: e.dead = true; e.visible = false
		victim.dead = false; victim.visible = true; victim.position = at
		victim.hp = 100000; victim.max_hp = 100000
		game.player.position = origin
		game.attack(false,at)
		game.tick_scheduled(1.0)
		for i in 30: game.tick_projectiles(.016)
		check(victim.hp<100000 and game.run.energy==100,"Free basic attack deals damage: "+class_id)
		Data.gain_xp(game.run,Data.xp_at_level(30))
		game.run.skills = {}; game.run.skill_points = 30
		for id in Book.all():
			if Book.all()[id].class_id==class_id: check(Book.learn(game.run,id),"Learn class roster: "+id)
		for id in game.run.skills:
			var s: Dictionary = Book.all()[id]
			if s.effect=="passive": continue
			game.skills.reset(); game.scheduled.clear()
			game.run.skill_cooldowns.clear()
			game.player.position = origin
			game.player.busy = 0; game.player.cooldown = 0
			game.run.energy = Data.max_energy(game.run)
			game.run.weapon = 1 if class_id=="warrior" else (2 if class_id=="ranger" else 4)
			game.player.visual.equip(Data.WEAPONS[game.run.weapon])
			victim.hp = 100000; victim.slow_time=0; victim.mark_time=0; victim.stagger_time=0
			var before: float = game.run.energy
			check(game.skills.cast(id,at),"Cast learned skill: "+id)
			check(game.run.energy<before and game.run.skill_cooldowns[id]>0,"Cost and cooldown apply once: "+id)
			game.player.busy=0
			check(not game.skills.cast(id,at),"Cooldown prevents duplicate cast: "+id)
			game.skills.tick(.6)
			for i in 90: game.tick_projectiles(.016)
			game.skills.tick(1.0)
			if s.tag!="": check(victim.hp<100000,"Skill deals damage: "+id)
			elif s.effect=="guard": check(game.skills.guard>0,"Guard supplies defense")
			elif s.effect=="barrier": check(game.skills.barrier>0,"Barrier supplies absorption")
			elif s.effect=="snare": check(victim.slow_time>0,"Snare slows enemies")
			elif s.effect=="mark": check(victim.mark_time>0,"Marked Prey applies vulnerability")
			elif s.effect=="blink": check(game.player.position.distance_to(origin)>.5 and game.world.fits(game.player.position),"Blink moves without crossing walls")
			elif s.effect=="war_cry": check(game.skills.war_cry>0,"War Cry supplies damage buff")
		game.skills.reset(); game.run.skill_cooldowns.clear()
		game.player.busy=0; game.player.cooldown=0
		game.player.position=origin
		var owned_id = "cleave" if class_id=="warrior" else ("power_shot" if class_id=="ranger" else "firebolt")
		game.run.hotbar=[owned_id,"","","",""]
		game.run.weapon = 4 if class_id!="wizard" else 1
		check(game.skills.reason(owned_id).begins_with("Requires"),"Wrong weapon disables skill with explanation: "+class_id)
		game.run.weapon = 1 if class_id=="warrior" else (2 if class_id=="ranger" else 4)
		game.player.visual.equip(Data.WEAPONS[game.run.weapon])
		game.world.zoom=15; game.world.follow(origin,1)
		await snapshot(class_id+"-game")
		game.combat_age=10; victim.awake=false
		game.ProgressionUI.character(game)
		await snapshot(class_id+"-character")
		game.ProgressionUI.skills(game)
		await snapshot(class_id+"-skills")
		check(game.mode=="character" and game.world.process_mode==Node.PROCESS_MODE_DISABLED,"Character and skill screens pause combat")
		game.resume_game()
		check(Save.valid(game.run),"Runtime class state is save-safe: "+class_id)
	game.run = Data.new_run("wizard"); game.load_floor()
	var enemy=game.enemies[0]
	var initial_xp = game.run.xp
	enemy.die()
	check(game.run.xp>initial_xp,"Killing an enemy grants XP")
	var earned=game.run.xp
	game.enemy_died(enemy)
	check(game.run.xp==earned,"Duplicate death callback cannot grant XP twice")
	game.retry_floor()
	game.enemies[0].die()
	check(game.run.xp==earned,"Retry cannot farm the same rewarded enemy")
	var points=game.run.points
	game.next_floor()
	check(game.run.points==points and game.run.xp==earned,"Floor travel grants no points or XP")
	game.player.hp=20; game.run.energy=0; game.heal_cd=0; game.heal()
	check(game.run.flasks==2 and game.run.energy==0 and game.player.hp==20,"Flask spends a charge and heals over time without energy")
	game.skills.tick(2)
	check(is_equal_approx(game.player.hp,60),"Flask restores 40 percent over two seconds")
	game.dash_cd=0; game.dash()
	check(game.run.energy==0 and game.dash_cd==3 and game.player.invulnerable>0,"Universal evade is free with a three-second recharge")
	game.save_run()
	check(not Save.load_run().is_empty(),"New progression survives gameplay save")
	FileAccess.open("res://test-results/classes-runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("CLASSES_RUNTIME ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
