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
	check(game.run.skills.is_empty() and game.run.skill_points==1,"A new warrior has one skill point to spend")
	# The first point spent on Cleave, which takes RMB.
	Data.Skills.learn(game.run,"cleave"); game.run.hotbar[0]="cleave"
	game.load_floor()
	var hud = game.hud
	check(not game.run.has("seconds"),"New runs have no elapsed-time field")
	for size in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1280,720),Vector2i(1120,700)]:
		root.size=size; await frames(5); hud.tick(0)
		var area: Rect2 = root.get_visible_rect()
		var left: Rect2 = hud.health.get_global_rect()
		var right: Rect2 = hud.energy.get_global_rect()
		# Either side of the hotbar, close to it, at the foot of the screen.
		var bar: Rect2 = hud.weapon_slots[0].get_global_rect().merge(hud.weapon_slots[-1].get_global_rect())
		check(left.end.x<bar.position.x and bar.position.x-left.end.x<30 and left.position.y>area.size.y*.65,"Health sits just left of the hotbar at "+str(size))
		check(right.position.x>bar.end.x and right.position.x-bar.end.x<30 and right.position.y>area.size.y*.65,"Energy sits just right of the hotbar at "+str(size))
		check(area.encloses(left) and area.encloses(right),"Orbs fit the viewport at "+str(size))
		check(absf(bar.get_center().y-left.get_center().y)<1.5 and absf(bar.get_center().y-right.get_center().y)<1.5,"The hotbar's middle is level with the middle of both orbs at %s (%.1f, %.1f)" % [size,bar.get_center().y,left.get_center().y])
		var first: Rect2 = hud.weapon_slots[0].get_global_rect()
		var last: Rect2 = hud.weapon_slots[-1].get_global_rect()
		check(absf((first.position.x+last.end.x)*.5-area.size.x*.5)<2 and left.end.x<first.position.x and last.end.x<right.position.x,"Six compact ability panels (LMB, RMB, 1–4) centered without overlap at "+str(size))
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
	check(not hud.weapon_slots[0].disabled and hud.weapon_slots[2].disabled and hud.weapon_slots[3].disabled,"Basic attack remains available and unassigned skill slots are disabled")
	check(game.hud.root.get_children().filter(func(n): return n is Button and n.visible).is_empty() and not hud.panels.stat_plus.visible and not hud.panels.skill_plus.visible,"No character, skills or equipment buttons at top left, and no + buttons without points")
	Data.gain_xp(game.run,Data.xp_at_level(8))
	hud.tick(0)
	var stat_plus: Rect2 = hud.panels.stat_plus.get_global_rect()
	var skill_plus: Rect2 = hud.panels.skill_plus.get_global_rect()
	check(hud.panels.stat_plus.visible and hud.panels.skill_plus.visible and stat_plus.end.x<200 and skill_plus.position.x>root.get_visible_rect().size.x-200 and stat_plus.end.y<=hud.health.get_global_rect().position.y and stat_plus.size.x<=30,"Leveling shows a small + above each orb: attributes left, skills right")
	await capture("hud-plus-buttons")
	await click(hud.panels.stat_plus)
	check(game.mode=="character" and hud.panels.stats_open() and hud.panels.stats.get_global_rect().end.x<root.get_visible_rect().size.x*.4,"The left + opens the attribute panel on the left")
	hud.tick(0); await frames(2)
	await click(hud.panels.stat_buttons[3])
	check(game.run.stats[3]==6 and game.run.points==34 and Data.max_health(game.run)==110,"A + in the panel spends an attribute point")
	await click(hud.panels.skill_plus)
	hud.tick(0); await frames(2)
	check(hud.panels.skills_open() and hud.panels.tree.get_global_rect().position.x>root.get_visible_rect().size.x*.6 and hud.panels.tree.size.x<440,"The right + opens the compact skill tree on the right")
	await click(hud.panels.nodes.powerful_strike.button)
	check(game.run.skills.get("powerful_strike",0)==1 and game.run.hotbar[1]=="powerful_strike","Clicking a skill learns it and fills the next slot")
	hud.tick(0); await frames(2)
	check(hud.panels.tip.visible and "Powerful Strike" in hud.panels.tip_lines.title.text,"Hovering a skill shows its details")
	await capture("hud-panels")
	game.run.points=0; game.run.stats[0]+=34; hud.tick(0)
	check(not hud.panels.stat_plus.visible and hud.panels.skill_plus.visible==false,"A + stays only while its points are unspent (or its panel is closed)")
	game.resume_game(); hud.tick(0)
	check(not hud.panels.stat_plus.visible and hud.panels.skill_plus.visible,"The skill + persists until the skill points are spent")
	var ids = ["cleave","powerful_strike","shield_bash"]
	for id in ids:
		if not game.run.skills.has(id): Data.Skills.learn(game.run,id)
	game.run.hotbar = ids+["",""]
	check(hud.weapon_slots.size()==6 and hud.weapon_icons[0].size==Vector2(34,34) and hud.weapon_slots[0].size==Vector2(56,56),"Exactly six significantly smaller ability icons")
	game.player.busy=0; game.player.cooldown=0
	await click(hud.weapon_slots[0])
	check(game.player.busy>0 and not game.left_held and game.route.is_empty(),"LMB icon performs the basic attack and consumes movement input")
	game.scheduled.clear()
	for i in 3:
		game.player.busy=0; game.player.cooldown=0
		game.skills.pending.clear()
		game.run.energy=Data.max_energy(game.run); hud.tick(0)
		var before_energy: float=game.run.energy
		await click(hud.weapon_slots[i+1]); hud.tick(0)
		check(game.run.energy<before_energy and not game.run.has("skill_cooldowns"),"Clicking hotbar spends energy: "+ids[i])
		check(not game.left_held and game.route.is_empty(),"Skill panel consumes movement input: "+ids[i])
	game.skills.pending.clear()
	game.creating_character=true
	game.new_run_menu()
	game.hud.modal_body.get_child(2).pressed.emit()
	check(game.mode=="character" and "CLASS" in game.hud.modal_body.get_child(0).text,"Difficulty selection opens class creation")
	await capture("class-creation")
	game.hud.modal_body.get_child(4).pressed.emit()
	check(game.run.class_id=="wizard" and game.run.weapon==4 and game.run.skills.is_empty() and game.run.skill_points==1 and not game.creating_character,"Wizard creation grants the staff and one skill point")
	check(not Save.load_run().is_empty(),"New class creation writes a valid character save")
	# A new character wakes in the desert: the corner tells the way, not a floor.
	game.run.difficulty=2; hud.tick(0)
	check(hud.objective.text=="" and "Hard" in hud.difficulty.text and "Temple" in hud.direction.text,"Outdoors the corner shows the difficulty and the way to the temple")
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
