extends SceneTree
## What is heard of an enemy's attack (scripts/actor.gd release_attack,
## scripts/game.gd hurt_player): an archer's shot (statue or bandit) as the
## hero's bow; a blow landing on the hero as the first Temple Ascension's
## were: a sword's hit, or a lion's cry.
const Data = preload("res://scripts/data.gd")
const Game = preload("res://scripts/game.gd")
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)
func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/enemy-sounds-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.run = Data.new_run("warrior")
	game.load_floor()
	game.mode = "playing"
	for e in game.enemies: e.dead = true
	var hero: Vector3 = game.player.position
	for kind in ["archer","bandit_archer"]:
		var archer = game.spawn_enemy(kind,"sound:"+kind,game.world.move(hero,Vector3(0,0,-5)))
		archer.awake = true
		game.sound.heard.clear()
		archer.start_attack(hero)
		for t in 120:
			archer.tick(1.0/60)
			if "archer-arrow" in game.sound.heard: break
		check("archer-arrow" in game.sound.heard,"A %s's shot is heard as a bow's" % kind)
		archer.dead = true; archer.visible = false
	for kind in ["bandit","gladiator","lion"]:
		var foe = game.spawn_enemy(kind,"sound:"+kind,game.world.move(hero,Vector3(0,0,-1.0)))
		foe.awake = true
		foe.face(hero)
		game.player.hp = game.player.max_hp; game.player.invulnerable = 0.0
		game.sound.heard.clear()
		foe.start_attack(hero)
		for t in 180:
			foe.tick(1.0/60)
			if game.player.hp < game.player.max_hp: break
		var wanted: Array = Game.LION_CRIES if kind == "lion" else ["sword-hit"]
		check(game.player.hp < game.player.max_hp and wanted.any(func(id): return id in game.sound.heard),"A %s's blow landing on the hero is heard (%s)" % [kind,game.sound.heard])
		foe.dead = true; foe.visible = false
	print("ENEMY_SOUNDS ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
