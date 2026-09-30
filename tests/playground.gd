extends SceneTree
## Debug playground: opens with Shift+P in debug mode, holds every hero class and
## statue, lets any be driven, takes no damage, and kills/revives on demand.
const Data = preload("res://scripts/data.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var game

func _initialize(): call_deferred("test")

func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func key(code: int, shift: bool = false):
	var e = InputEventKey.new(); e.pressed = true; e.physical_keycode = code; e.keycode = code; e.shift_pressed = shift
	if not game.debug.handle_key(e): game._unhandled_input(e)
	await process_frame

func step(seconds: float):
	var t = 0.0
	while t < seconds:
		game._process(1.0/60); t += 1.0/60

func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/playground-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true; game.set_process(false)
	game.run = Data.new_run("warrior"); game.run.floor = 1
	game.load_floor(); await process_frame
	var floor_before: int = game.run.floor
	await key(KEY_P,true)
	var pg = game.playground
	check(pg != null,"Shift+P opens the playground in debug mode")
	check(pg.heroes.size()==3 and game.enemies.size()==pg.KINDS.size(),"Three heroes and one of every statue, including the boss")
	check(game.boss != null and game.boss.kind=="boss","The Crowned Statue is present")
	check(game.world.level==game.world.Layout.PLAYGROUND and not game.world.camera.get_node("LineOfSightFog").visible,"An open, evenly lit plane without fog")
	var target = game.enemies[0]
	target.position = game.player.position+Vector3(0,0,-1.4)
	game.player.face(target.position)
	var hp: float = target.hp
	game.attack(false,target.position)
	step(1.0)
	check(target.hp==hp and not target.dead,"Hero attacks hit statues but deal no damage")
	check(target.visual.state.trim_prefix("Shield") in ["Hit","HitHead","HitStagger","HitKnockdown"] or target.hit_reactions>0,"The struck statue reacts to the hit")
	var skill_id: String = game.run.hotbar[0]
	check(not skill_id.is_empty() and game.skills.cast(skill_id,target.position),"The hero can use a class ability")
	step(1.0)
	check(target.hp==hp,"Abilities deal no damage either")
	# Drive a statue: select it, attack the hero, and see the hero take nothing.
	var gladiator = game.enemies.filter(func(e): return e.kind=="gladiator")[0]
	pg.select(gladiator)
	gladiator.position = game.player.position+Vector3(0,0,1.2)
	var hero_hp: float = game.player.hp
	gladiator.start_attack(game.player.position)
	step(1.5)
	check(game.player.hp==hero_hp and not game.player.dead and game.player.hit_reactions>0,"A driven statue's attack lands on the hero without damage")
	gladiator.puppet_goal = gladiator.position+Vector3(3,0,0)
	var start: Vector3 = gladiator.position
	step(1.0)
	check(gladiator.position.distance_to(start)>1.0,"A selected statue walks where it is sent")
	# Kill and revive.
	await key(KEY_X)
	check(gladiator.dead and gladiator.visual.state=="Crumble","X kills the selected unit and plays its death")
	await key(KEY_X)
	check(not gladiator.dead and not gladiator.visual.dead and gladiator.visual.state!="Crumble","X again revives it")
	pg.select(pg.heroes[2])
	check(game.player==pg.heroes[2] and game.run.class_id=="wizard","Selecting a hero hands it the controls")
	pg.toggle_death()
	check(game.player.dead and game.player.visual.state=="Death","A hero can be killed too")
	pg.toggle_death()
	check(not game.player.dead,"And revived")
	await key(KEY_P,true)
	check(game.playground==null and game.run.floor==floor_before and game.world.level==floor_before,"Shift+P leaves, restoring the run")
	FileAccess.open("res://test-results/playground.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("PLAYGROUND ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
