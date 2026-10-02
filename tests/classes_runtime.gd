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
		Data.gain_xp(game.run,Data.xp_at_level(Data.MAX_LEVEL))
		# Every active skill of the class at rank one (the trees themselves are
		# covered by the progression test).
		game.run.skills = {}
		for id in Book.all():
			if Book.all()[id].class_id==class_id and Book.all()[id].effect!="passive": game.run.skills[id] = 1
		for id in game.run.skills:
			var s: Dictionary = Book.all()[id]
			game.skills.reset(); game.scheduled.clear()
			game.player.position = origin; game.leap_left = 0
			game.player.busy = 0; game.player.cooldown = 0
			game.run.energy = Data.max_energy(game.run)
			game.run.weapon = 1 if class_id=="warrior" else (2 if class_id=="ranger" else 4)
			game.player.visual.equip(Data.WEAPONS[game.run.weapon])
			# Execute needs a wounded enemy.
			var full: float = 10000.0 if s.effect=="execute" else 100000.0
			victim.hp = full; victim.max_hp = 100000; victim.slow_time=0; victim.mark_time=0; victim.end_stun(); victim.dots.clear()
			var before: float = game.run.energy
			check(game.skills.cast(id,at),"Cast learned skill: "+id)
			check(game.run.energy<before and not game.run.has("skill_cooldowns"),"Skill spends energy: "+id)
			game.player.busy=0
			var repeat_energy: float=game.run.energy
			check(game.skills.cast(id,at)==(repeat_energy>=game.skills.cost(id) and s.effect!="bash"),"Energy cost (and Shield Bash's cooldown) controls repeated casts: "+id)
			game.skills.tick(.6)
			for i in 90: game.tick_projectiles(.016)
			game.skills.tick(1.0)
			if s.tag!="": check(victim.hp<full,"Skill deals damage: "+id)
			elif s.effect=="barrier": check(game.skills.barrier>0,"Barrier supplies absorption")
			elif s.effect=="snare": check(victim.slow_time>0,"Snare slows enemies")
			elif s.effect=="mark": check(victim.mark_time>0,"Marked Prey applies vulnerability")
			elif s.effect=="blink": check(game.player.position.distance_to(origin)>.5 and game.world.fits(game.player.position),"Blink moves without crossing walls")
			if s.effect=="bash": check(victim.stunned and game.skills.cooldowns.shield_bash>0,"Shield Bash stuns and recharges")
		game.skills.reset(); game.leap_left = 0; victim.end_stun(); victim.dots.clear()
		game.player.busy=0; game.player.cooldown=0
		game.player.position=origin
		var owned_id = "cleave" if class_id=="warrior" else ("power_shot" if class_id=="ranger" else "firebolt")
		game.run.hotbar=[owned_id,"",""]
		game.run.weapon = 4 if class_id!="wizard" else 1
		check(game.skills.reason(owned_id).begins_with("Requires"),"Wrong weapon disables skill with explanation: "+class_id)
		game.run.weapon = 1 if class_id=="warrior" else (2 if class_id=="ranger" else 4)
		game.player.visual.equip(Data.WEAPONS[game.run.weapon])
		game.world.zoom=15; game.world.follow(origin,1)
		await snapshot(class_id+"-game")
		game.combat_age=10; victim.awake=false
		Data.respec(game.run)
		check(Save.valid(game.run),"Runtime class state is save-safe: "+class_id)
		game.hud.tick(0)
		check(game.hud.panels.stat_plus.visible and game.hud.panels.skill_plus.visible,"Unspent points show the + buttons: "+class_id)
		game.ProgressionUI.character(game)
		game.hud.tick(0)
		check(game.hud.panels.stats_open() and not game.hud.panels.stat_plus.visible and game.hud.panels.skill_plus.visible,"The attribute panel opens and replaces its + button: "+class_id)
		await snapshot(class_id+"-character")
		game.ProgressionUI.skills(game)
		var roster: int = Book.all().values().filter(func(s): return s.class_id==class_id).size()
		check(game.hud.panels.stats_open() and game.hud.panels.skills_open() and game.hud.panels.nodes.size()==roster,"Both panels can be open, the tree showing the class's whole roster: "+class_id)
		await snapshot(class_id+"-skills")
		check(game.mode=="character" and game.world.process_mode==Node.PROCESS_MODE_DISABLED,"Character and skill panels pause combat")
		game.resume_game()
		check(game.mode=="playing" and not game.hud.panels.any_open(),"Resuming closes the panels: "+class_id)
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
	game.player.hp=20; game.run.energy=60; game.heal_cd=0; game.heal()
	check(not game.run.has("flasks") and game.run.energy==0 and game.player.hp==80 and game.heal_cd==20,"Healing spell instantly restores 60 percent for 60 energy without charges")
	game.run.energy=10; game.dash()
	check(game.run.energy==0 and game.dash_time>0 and game.player.invulnerable>0,"Dash spends ten energy and has no cooldown")
	game.save_run()
	check(not Save.load_run().is_empty(),"New progression survives gameplay save")
	FileAccess.open("res://test-results/classes-runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("CLASSES_RUNTIME ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
