extends SceneTree
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
var passed: Array[String] = []
var failed: Array[String] = []
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func click(control: Control):
	var at: Vector2 = root.get_final_transform()*control.get_global_rect().get_center()
	Input.warp_mouse(at)
	await frames(2)
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position=at; event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
		await frames(1)
func capture(name: String):
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/hud-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode=true; game.set_process(false)
	game.run = Data.new_run(); game.run.seed=0
	game.load_floor()
	var hud = game.hud
	check(not game.run.has("seconds"),"New runs have no elapsed-time field")
	for size in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1280,720),Vector2i(1120,700)]:
		root.size=size; await frames(5); hud.tick(0)
		var area: Rect2 = root.get_visible_rect()
		var left: Rect2 = hud.health.get_global_rect()
		var right: Rect2 = hud.energy.get_global_rect()
		check(left.position.x<area.size.x*.15 and left.position.y>area.size.y*.65,"Health anchored bottom-left at "+str(size))
		check(right.end.x>area.size.x*.85 and right.position.y>area.size.y*.65,"Energy anchored bottom-right at "+str(size))
		check(area.encloses(left) and area.encloses(right),"Orbs fit the viewport at "+str(size))
		var first: Rect2 = hud.weapon_slots[0].get_global_rect()
		var last: Rect2 = hud.weapon_slots[4].get_global_rect()
		check(absf((first.position.x+last.end.x)*.5-area.size.x*.5)<2 and left.end.x<first.position.x and last.end.x<right.position.x,"Five skill panels centered without overlap at "+str(size))
		check(hud.objective.get_global_rect().end.x>area.size.x*.9 and hud.objective.position.y<100,"Floor information anchored top-right at "+str(size))
		for ratio in [0.0,.5,1.0]:
			game.player.hp = Data.max_health(game.run)*ratio
			game.run.energy = Data.max_energy(game.run)*ratio
			hud.tick(0)
			check(is_equal_approx(hud.health.material.get_shader_parameter("fill"),ratio) and is_equal_approx(hud.energy.material.get_shader_parameter("fill"),ratio),"Orb levels show %d percent at %s" % [ratio*100,size])
		if size==Vector2i(1280,800):
			game.player.hp=50; game.run.energy=25; hud.tick(0)
			await capture("hud-partial")
		else: await capture("hud-%dx%d" % [size.x,size.y])
	game.player.hp=100; game.run.energy=100; hud.tick(0)
	check(hud.weapon_slots[1].disabled and hud.weapon_slots[4].disabled,"Unassigned skill slots are disabled")
	Data.gain_xp(game.run,Data.xp_at_level(8))
	var ids = ["cleave","guard","shield_bash","lunge","whirlwind"]
	for id in ids:
		if not game.run.skills.has(id): Data.Skills.learn(game.run,id)
	game.run.hotbar = ids
	for i in 5:
		game.player.busy=0; game.player.cooldown=0
		game.run.skill_cooldowns.clear(); game.skills.pending.clear()
		game.run.energy=Data.max_energy(game.run); hud.tick(0)
		await click(hud.weapon_slots[i]); hud.tick(0)
		check(game.run.skill_cooldowns.has(ids[i]),"Clicking hotbar casts "+ids[i])
		check(not game.left_held and game.route.is_empty(),"Skill panel consumes movement input: "+ids[i])
	game.skills.pending.clear()
	game.creating_character=true
	game.new_run_menu()
	game.hud.modal_body.get_child(2).pressed.emit()
	check(game.mode=="character" and "CLASS" in game.hud.modal_body.get_child(0).text,"Difficulty selection opens class creation")
	await capture("class-creation")
	game.hud.modal_body.get_child(4).pressed.emit()
	check(game.run.class_id=="wizard" and game.run.weapon==4 and game.run.skills.firebolt==1 and not game.creating_character,"Wizard creation grants staff and starter Firebolt")
	check(not Save.load_run().is_empty(),"New class creation writes a valid character save")
	game.run.difficulty=2; game.run.floor=4; hud.tick(0)
	check("FLOOR 5" in hud.objective.text and "Hard" in hud.difficulty.text and "statues" in hud.status.text,"Floor, difficulty and remaining statues update")
	await capture("hud-unlocked")
	game._process(.1)
	check(not game.run.has("seconds"),"Gameplay does not accumulate elapsed run time")
	var legacy = Data.new_run(); legacy.seconds=4321.0
	DirAccess.make_dir_recursive_absolute(Save.directory)
	var file = FileAccess.open(Save.directory.path_join("run.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	var loaded = Save.load_run()
	check(not loaded.is_empty() and not loaded.has("seconds"),"Legacy save loads without its elapsed-time field")
	Save.write(loaded)
	for name in ["run.json","run.backup.json"]:
		var saved = JSON.parse_string(FileAccess.get_file_as_string(Save.directory.path_join(name)))
		check(not saved.has("seconds"),"Elapsed time absent from "+name)
	game.summary_menu()
	check(not "time" in hud.modal_body.get_child(1).text.to_lower(),"Completion summary has no timing or best-time record")
	check(not FileAccess.file_exists(Save.directory.path_join("records.json")),"Completing a run creates no time record")
	await capture("hud-completion")
	FileAccess.open("res://test-results/hud-regression.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("HUD_REGRESSION ",passed.size()," passed; ",failed)
	quit(0 if failed.is_empty() else 1)
