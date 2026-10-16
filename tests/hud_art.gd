extends SceneTree
## Live HUD artwork switching: layouts, fills, cooldowns, inputs and settings.
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/hud_art.gd")
var passed: Array[String] = []
var failed: Array[String] = []

func _initialize() -> void: call_deferred("test")
func check(ok: bool, message: String) -> void:
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func frames(count: int = 2) -> void:
	for i in count: await process_frame
func press(game, shift: bool = false) -> void:
	var key = InputEventKey.new()
	key.physical_keycode = KEY_F4; key.pressed = true; key.shift_pressed = shift
	game._input(key)

func click(control: Control) -> void:
	var at = control.get_global_rect().get_center()
	var move = InputEventMouseMotion.new()
	move.position = at; move.global_position = at
	root.push_input(move,true)
	await frames()
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = at; event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		root.push_input(event,true)
		await frames()

func test() -> void:
	var debug_mode = "--debug-mode" in OS.get_cmdline_user_args()
	var base = ProjectSettings.globalize_path("res://test-results/hud-art-save-"+("debug" if debug_mode else "normal"))
	Save.directory = base
	Save.write(Data.new_run("warrior"))
	Save.keep_setting("hud_art","obsidian_oracle")
	var regular = FileAccess.get_file_as_bytes(base.path_join("run.json"))
	var regular_settings = FileAccess.get_file_as_bytes(base.path_join("settings.cfg"))
	if debug_mode:
		Save.directory = base.path_join("debug")
		Save.write(Data.new_run("warrior"))
		Save.keep_setting("hud_art_shrine","invalid-old-style")
		Save.directory = base
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true; game.set_process(false); game.sound.muted = true
	var hud = game.hud
	check(hud.art_style==Art.DEFAULT and hud.art_backplate.visible,"Sandstone Shrine is the production default, including with an invalid debug setting")
	check(Art.STYLES.size()==5 and Art.index_of("not-a-style")==Art.DEFAULT,"Exactly five named choices include the current UI and a safe fallback")
	if not debug_mode:
		check(not is_instance_valid(game.debug.hud_art_selector),"Normal mode has no debug artwork chooser")
		press(game); press(game,true)
		check(hud.art_style==Art.DEFAULT and not hud.set_art_style(1),"F4 and alternate styles are gated outside debug mode")
		check(FileAccess.get_file_as_bytes(base.path_join("settings.cfg"))==regular_settings,"Normal launch preserves its settings")
	else:
		var selector: OptionButton = game.debug.hud_art_selector
		check(selector.item_count==5 and game.debug.panel.is_ancestor_of(selector),"The debug panel contains all five named artwork choices")
		var original_health = hud.health.get_instance_id()
		var original_energy = hud.energy.get_instance_id()
		var buttons: Array = hud.weapon_slots.map(func(slot): return slot.get_instance_id())
		Data.Skills.learn(game.run,"cleave"); game.run.hotbar[0]="cleave"
		game.skills.cooldowns["cleave"] = 3.25
		var bar_assignment: Array = game.run.hotbar.duplicate()
		for index in Art.STYLES.size():
			selector.item_selected.emit(index)
			check(hud.art_style==index and selector.selected==index and Save.setting("hud_art_shrine","")==Art.STYLES[index].id,"Dropdown selects and remembers "+Art.STYLES[index].name)
			check(hud.health.get_instance_id()==original_health and hud.energy.get_instance_id()==original_energy and hud.weapon_slots.map(func(slot): return slot.get_instance_id())==buttons,"Changing artwork retains the live gauges and buttons: "+Art.STYLES[index].name)
			check(game.run.hotbar==bar_assignment and game.skills.cooldowns.cleave==3.25,"Artwork changes preserve skill assignments and cooldowns")
			check(is_equal_approx(hud.health.material.get_shader_parameter("rim_start"),.92 if index==Art.DEFAULT else .83) and hud.energy.material.get_shader_parameter("rim_start")==hud.health.material.get_shader_parameter("rim_start"),"Thin gauge bezels apply to Sandstone and reset for the other previews")
			if index>0:
				var picture: Image = hud.art_backplate.texture.get_image()
				check(hud.art_backplate.visible and picture.get_size()==Vector2i(Art.SOURCE) and picture.has_mipmaps() and picture.detect_alpha()!=Image.ALPHA_NONE,"Artwork imports with genuine transparency and mipmaps: "+Art.STYLES[index].name)
				check(picture.get_pixelv(Vector2i(Art.STYLES[index].left)).a<.05 and picture.get_pixelv(Vector2i(Art.STYLES[index].right)).a<.05,"Both live orb openings are transparent")
			else: check(not hud.art_backplate.visible,"Current UI hides all added artwork")
			for size in [Vector2i(1120,700),Vector2i(1280,720),Vector2i(1440,900)]:
				root.size = size; await frames(); game.debug.refresh(); await frames()
				var area: Rect2 = root.get_visible_rect()
				var left: Rect2 = hud.health.get_global_rect()
				var right: Rect2 = hud.energy.get_global_rect()
				var skills: Rect2 = hud.weapon_slots[0].get_global_rect().merge(hud.weapon_slots[-1].get_global_rect())
				check(area.encloses(left) and area.encloses(right) and area.encloses(skills) and area.encloses(hud.ready_tiles[0].frame.get_global_rect()) and area.encloses(hud.ready_tiles[1].frame.get_global_rect()),"Gauges, six skills and utility tiles fit %s in %s" % [size,Art.STYLES[index].name])
				check(absf(skills.get_center().x-area.size.x*.5)<1 and skills.position.y>area.size.y*.7 and left.end.x<skills.position.x and skills.end.x<right.position.x,"The HUD stays bottom-centred with separate circular gauges")
				check(left.size.is_equal_approx(Vector2.ONE*160*hud.BAR_SCALE) and right.size==left.size,"Existing circular gauges keep their original size")
				check(area.encloses(selector.get_global_rect()) and game.debug.panel.get_global_rect().end.y<=area.end.y,"Debug artwork chooser and scrolling panel stay on screen")
				for ratio in [0.0,.5,1.0]:
					game.player.hp = Data.max_health(game.run)*ratio; game.run.energy = Data.max_energy(game.run)*ratio
					hud.tick(0)
					check(is_equal_approx(hud.health.material.get_shader_parameter("fill"),ratio) and is_equal_approx(hud.energy.material.get_shader_parameter("fill"),ratio),"Both live circles show %d%% with %s" % [ratio*100,Art.STYLES[index].name])
			game.run.class_id = "wizard"; hud.tick(0)
			check(hud.energy_title.text=="MANA" and hud.energy.material.get_shader_parameter("liquid")==hud.MANA_LIQUID,"The wizard retains blue mana in "+Art.STYLES[index].name)
			game.run.class_id = "warrior"; hud.tick(0)
			check(hud.energy_title.text=="ENERGY" and hud.energy.material.get_shader_parameter("liquid")==hud.ENERGY_LIQUID and hud.slot_cooldowns[1].text=="4","Energy and cooldown numbers remain live")
			game.skills.cooldowns.clear(); game.player.busy=0; game.player.cooldown=0
			game.run.energy = Data.max_energy(game.run); hud.tick(0)
			var energy_before: float = game.run.energy
			await click(hud.weapon_slots[1])
			check(game.run.energy<energy_before and not game.left_held and game.route.is_empty(),"Mouse clicks reach the live skill button without moving the hero: "+Art.STYLES[index].name)
			game.skills.pending.clear(); game.scheduled.clear()
			game.skills.cooldowns["cleave"] = 3.25
			if "--render-hud-art" in OS.get_cmdline_user_args():
				game.debug.panel.hide(); hud.notice.hide(); await frames()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/hud-art-"+Art.STYLES[index].id+".png")
				game.debug.panel.show()
		hud.set_art_style(0); press(game,true)
		check(hud.art_style==4,"Shift+F4 wraps backward from Current to Crimson Legion")
		press(game)
		check(hud.art_style==0,"F4 wraps forward to the current UI")
		game.debug.panel.hide(); press(game)
		check(hud.art_style==1,"F4 works while the debug panel is hidden")
		game.mode="paused"; press(game)
		check(hud.art_style==2,"Artwork switching works while paused")
		game.mode="playing"; hud.set_art_style(4)
		game.skills.cooldowns.clear(); game.player.hp=Data.max_health(game.run); game.run.energy=Data.max_energy(game.run)
		game.player.busy=0; hud.tick(0)
		var before: float = game.run.energy
		hud.weapon_slots[1].pressed.emit()
		check(game.run.energy<before,"A live skill button still casts with alternate artwork")
		check(not hud.set_art_style(-1) and not hud.set_art_style(5) and hud.art_style==4,"Invalid style indices preserve the current choice")
		check(FileAccess.get_file_as_bytes(base.path_join("run.json"))==regular and FileAccess.get_file_as_bytes(base.path_join("settings.cfg"))==regular_settings,"Debug artwork never modifies the regular run or settings")
		game.queue_free(); await frames()
		game = load("res://scenes/main.tscn").instantiate(); Save.directory=base
		root.add_child(game); game.test_mode=true; game.set_process(false)
		check(game.hud.art_style==4 and game.debug.hud_art_selector.selected==4,"The chosen debug artwork survives a new launch")
		game.hud.set_art_style(0)
	FileAccess.open("res://test-results/hud-art-"+("debug" if debug_mode else "normal")+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("HUD_ART ","debug" if debug_mode else "normal"," ",passed.size()," passed; ",failed)
	game.queue_free(); await frames()
	quit(0 if failed.is_empty() else 1)
