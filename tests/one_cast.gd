extends SceneTree
## One press of a skill, one cast (scripts/game.gd attack): a skill ordered
## on an enemy (a key or the right button with the cursor on it) is cast once,
## and the order ends with it, never casting again once the hero is free.
const Data = preload("res://scripts/data.gd")
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)
func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/one-cast-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_run("wizard")
	game.run.level = 20
	game.load_floor()
	game.mode = "playing"
	for e in game.enemies: e.dead = true
	for id in ["ice_spikes"]:
		game.run.skills[id] = 1
		game.run.hotbar[1] = id
		var foe = game.spawn_enemy("gladiator","cast:"+id,game.world.move(game.player.position,Vector3(0,0,-3)))
		foe.awake = true
		foe.hp = 1000000.0; foe.max_hp = 1000000.0
		game.run.energy = Data.max_energy(game.run)
		game.player.busy = 0.0; game.player.cooldown = 0.0
		game.skills.cooldowns.clear()
		var casts = 0
		var last: float = game.run.energy
		game.order_attack(foe,true,1)
		for t in 480:
			game.player.tick(1.0/60)
			game.skills.tick(1.0/60)
			game.player_control(1.0/60)
			game.tick_scheduled(1.0/60)
			if game.run.energy < last-20.0: casts += 1
			last = game.run.energy
		check(casts == 1 and not game.order_pending,"%s ordered once is cast once (%d casts)" % [id,casts])
		foe.dead = true; foe.visible = false
	# The right button held down: its skill is cast once, not again and again.
	game.run.skills["ice_spikes"] = 1
	game.run.hotbar[0] = "ice_spikes"
	game.run.energy = Data.max_energy(game.run)
	game.player.busy = 0.0; game.player.cooldown = 0.0
	game.skills.cooldowns.clear()
	var held_casts = 0
	var was: float = game.run.energy
	game.aim_fixed = game.world.move(game.player.position,Vector3(0,0,-4))
	game.right_held = true
	game.right_press_cast = false
	game.issue_click(true)
	for t in 300:
		game.player.tick(1.0/60)
		game.skills.tick(1.0/60)
		game.player_control(1.0/60)
		game.tick_scheduled(1.0/60)
		if game.run.energy < was-20.0: held_casts += 1
		was = game.run.energy
	game.right_held = false
	game.aim_fixed = Vector3.INF
	check(held_casts == 1,"The right button held five seconds casts its skill once (%d casts)" % held_casts)
	print("ONE_CAST ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
