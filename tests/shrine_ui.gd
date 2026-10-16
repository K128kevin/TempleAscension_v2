extends SceneTree
## Production theme, asset alignment, dynamic assignments/remaps and real clicks.
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
const Shrine = preload("res://scripts/ui_theme.gd")
const Bindings = preload("res://scripts/combat_bindings.gd")
var passed: Array[String] = []
var failed: Array[String] = []

class DrawProbe:
	extends "res://scripts/shrine_style.gd"
	var calls = 0
	func _draw(item: RID, area: Rect2) -> void:
		calls += 1
		super._draw(item,area)

func _initialize() -> void: call_deferred("test")
func check(ok: bool, message: String) -> void:
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func frames(count: int = 3) -> void:
	for i in count: await process_frame
func click(control: Control) -> void:
	var at = control.get_global_rect().get_center()
	var move = InputEventMouseMotion.new()
	move.position = at; move.global_position = at
	root.push_input(move,true); await frames()
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = at; event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		root.push_input(event,true); await frames()
func carved(control: Control, style: String = "panel") -> bool:
	var s = control.get_theme_stylebox(style)
	return s.get_script()==Shrine.Frame and s.texture==Shrine.PANEL

func luminance(color: Color) -> float:
	var linear = color.srgb_to_linear()
	return linear.r*.2126+linear.g*.7152+linear.b*.0722

func contrast(ink: Color, background: Color) -> float:
	var a = luminance(ink); var b = luminance(background)
	return (maxf(a,b)+.05)/(minf(a,b)+.05)

func carved_band_width(picture: Image, centre: Vector2) -> float:
	# Sample a clear diagonal, away from the bar and the small palmettes.
	var direction = Vector2(-1,-1).normalized()
	var first = -1
	for radius in range(120,360):
		var solid = picture.get_pixelv(Vector2i(centre+direction*radius)).a>.5
		if solid and first<0: first=radius
		elif not solid and first>=0: return radius-first
	return INF

func readable_tabs(panels) -> bool:
	for button in panels.tab_buttons.values():
		var font: Font = button.get_theme_font("font")
		var size: int = button.get_theme_font_size("font_size")
		var style: StyleBox = button.get_theme_stylebox("normal")
		if size<16 or font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+style.get_margin(SIDE_LEFT)+style.get_margin(SIDE_RIGHT)>button.size.x+.5: return false
		for state in [["normal","font_color"],["hover","font_hover_color"],["pressed","font_pressed_color"]]:
			var background: StyleBoxFlat = button.get_theme_stylebox(state[0])
			if contrast(button.get_theme_color(state[1]),background.bg_color)<7: return false
	return true

func check_frames() -> void:
	var large = Shrine.panel()
	var small = Shrine.make().get_stylebox("panel","TooltipPanel")
	check(small.texture_margin_top<large.texture_margin_top and large.texture_margin_top<28,"Popup borders are thinner, with an even smaller frame for tooltips")
	var canvas = RenderingServer.canvas_item_create()
	var probe = DrawProbe.new()
	probe.texture = Shrine.PANEL
	probe.draw(canvas,Rect2(0,0,660,560))
	check(probe.calls==1,"Godot invokes the custom tiled-frame renderer rather than the built-in stretched style")
	for style in [large,small,Shrine.button()]:
		for size in [Vector2(26,26),Vector2(250,180),Vector2(660,560),Vector2(2000,1100)]:
			var area = Rect2(Vector2(13,17),size)
			var segments: Array = style.patches(area)
			var valid = true
			var covered = 0.0
			for segment in segments:
				var source_size: Vector2 = Vector2(segment.source.size.y,segment.source.size.x) if segment.transpose else segment.source.size
				var scale: Vector2 = segment.destination.size/source_size
				valid = valid and absf(scale.x-scale.y)<.0001 and area.grow(.001).encloses(segment.destination)
				covered += segment.destination.get_area()
			var corners: Array = segments.filter(func(p): return p.source.size.is_equal_approx(Vector2.ONE*Shrine.PANEL.get_width()*style.SOURCE_BORDER_RATIO))
			valid = valid and corners.size()==4 and corners.all(func(p): return p.destination.size.is_equal_approx(corners[0].destination.size))
			check(valid and absf(covered-area.get_area())<1,"Frame tiles cover %s with equal corners and no change to any tile's aspect ratio" % size)
			# Exercise the actual canvas submission, even with a headless renderer.
			style.draw(canvas,area)
	RenderingServer.free_rid(canvas)
func capture(name: String) -> void:
	if "--render-shrine" not in OS.get_cmdline_user_args(): return
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/shrine-"+name+".png")

func test() -> void:
	Save.directory = ProjectSettings.globalize_path("res://test-results/shrine-ui-save")
	Save.write(Data.new_run("warrior"))
	Save.keep_setting("hud_art","crimson_legion") # Old preview preference must not override the selected theme.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode=true; game.set_process(false); game.sound.muted=true
	var hud = game.hud
	var panels = hud.panels
	check(hud.art_style==hud.Art.DEFAULT and hud.art_backplate.visible,"Sandstone Shrine is active in normal mode, superseding old preview settings")
	check(Shrine.PANEL.get_width()==1254 and Shrine.PANEL.get_image().has_mipmaps(),"Shared nine-patch retains the full-resolution source with mipmaps")
	check_frames()
	check(hud.root.theme.get_stylebox("panel","PanelContainer").get_script()==Shrine.Frame and carved(panels.stat_plus,"normal"),"Shared windows and compact buttons use the sandstone artwork")
	var picture: Image = hud.art_backplate.texture.get_image()
	var old_frame: Image = load("res://assets/ui/hud/sandstone_shrine_v2.png").get_image()
	var look: Dictionary = hud.Art.STYLES[hud.Art.DEFAULT]
	check(carved_band_width(picture,look.left)<carved_band_width(old_frame,Vector2(295,342.5))*.65 and carved_band_width(picture,look.right)<carved_band_width(old_frame,Vector2(1876,342))*.65,"Both carved orb surrounds are substantially thinner in the actual artwork")
	for dimensions in [Vector2i(1120,700),Vector2i(1280,720),Vector2i(1440,900)]:
		root.size=dimensions; await frames(); hud.tick(0)
		var art: Rect2 = hud.art_backplate.get_global_rect()
		var sockets: Array = hud.weapon_slots.duplicate()
		for tile in hud.ready_tiles: sockets.append(tile.frame)
		var aligned = true
		for b in sockets:
			var source: Vector2 = (b.get_global_rect().get_center()-art.position)/art.size*Vector2(picture.get_size())
			# Sample each actual artwork recess around the live icon, rather than
			# comparing against the same layout constants used by the implementation.
			for offset in [Vector2.ZERO,Vector2(-20,-20),Vector2(20,20)]:
				var pixel: Color = picture.get_pixelv(Vector2i(source+offset))
				aligned = aligned and pixel.a>.95 and maxf(pixel.r,maxf(pixel.g,pixel.b))<.4
			var style = b.get_theme_stylebox("normal")
			aligned = aligned and style is StyleBoxFlat and style.bg_color.a<.15
		check(aligned,"All eight live controls fit empty recesses without opaque button overlays at "+str(dimensions))
		for class_id in Data.CLASSES:
			panels.close(); await frames()
			game.run=Data.new_run(class_id)
			for tab in panels.TABS:
				panels.open(tab); await frames(); hud.tick(0); await frames()
				check(root.get_visible_rect().encloses(panels.window.get_global_rect()) and carved(panels.window),"%s %s window fits and uses carved stone at %s" % [class_id,tab,dimensions])
				check(readable_tabs(panels),"%s tabs use larger text, strong contrast in every state and no clipping at %s" % [tab,dimensions])
			panels.close(); await frames()
	game.run=Data.new_run("warrior"); game.mode="playing"; game.end_intro()
	Data.Skills.learn(game.run,"cleave"); game.run.hotbar[0]="cleave"
	hud.tick(0)
	var same_button: int = hud.weapon_slots[1].get_instance_id()
	check(hud.weapon_names[1].text=="Cleave" and hud.slot_glyphs[1].id=="cleave","A learned skill populates a carved socket dynamically")
	game.run.hotbar[0]=""; hud.tick(0)
	check(hud.weapon_names[1].text=="Empty" and hud.slot_glyphs[1].id=="" and hud.weapon_slots[1].disabled,"Removing a binding clears and disables the same socket")
	game.run.hotbar[0]="cleave"; hud.tick(0)
	check(hud.weapon_slots[1].get_instance_id()==same_button,"Reassigning skills retains the live button")
	game.player.hp=1; game.run.energy=100; game.heal_cd=0; hud.tick(0)
	await click(hud.ready_tiles[1].frame); hud.tick(0)
	check(game.player.hp>1 and game.run.energy==40 and game.heal_cd==game.HEAL_COOLDOWN and not game.left_held and game.route.is_empty(),"Clicking the carved heal socket heals and consumes input")
	check(hud.ready_tiles[1].frame.disabled and hud.ready_tiles[1].count.text=="20","A recharging utility socket disables clicks and shows live time")
	game.dash_cooldown=0; game.player.busy=0; hud.tick(0)
	await click(hud.ready_tiles[0].frame); hud.tick(0)
	check(game.dash_cooldown>0 and not game.left_held and game.route.is_empty(),"Clicking the carved dash socket evades without issuing a movement order")
	# Remap a real action: captions, tree assignment and casting must agree.
	var shifted = InputEventKey.new(); shifted.physical_keycode=KEY_1; shifted.pressed=true; shifted.shift_pressed=true
	check(Bindings.matches(shifted,0),"Holding Shift still permits the original keyboard skill actions")
	var original: Array[InputEvent] = InputMap.action_get_events(Bindings.ACTIONS[0])
	InputMap.action_erase_events(Bindings.ACTIONS[0])
	var remap = InputEventKey.new(); remap.physical_keycode=KEY_7; remap.pressed=true
	InputMap.action_add_event(Bindings.ACTIONS[0],remap)
	hud.tick(0); panels.open_skills(); panels.hovered="cleave"; game._input(remap); hud.tick(0)
	check(hud.hotkeys[2].text=="7" and game.run.hotbar[1]=="cleave" and panels.nodes.cleave.slot.text=="7" and "7" in panels.tree_hint.text,"InputMap remaps update the HUD, skill tree labels and assignment input together")
	panels.close(); game.player.busy=0; game.player.cooldown=0; game.run.energy=100; game.skills.cooldowns.clear(); game.skills.pending.clear(); game.scheduled.clear()
	game._unhandled_input(remap)
	check(game.run.energy<100,"The remapped key casts the skill shown in its socket")
	InputMap.action_erase_events(Bindings.ACTIONS[0])
	for event in original: InputMap.action_add_event(Bindings.ACTIONS[0],event)
	game.skills.pending.clear(); game.scheduled.clear(); game.dash_cooldown=0; game.heal_cd=0
	for menu in ["pause","difficulty","class","summary","dialogue"]:
		game.mode="playing"
		match menu:
			"pause": game.pause_game()
			"difficulty": game.new_run_menu()
			"class": game.ProgressionUI.creation(game,0)
			"summary": game.summary_menu()
			"dialogue": hud.dialog("DESERT VOICES","A reusable dialogue frame, shared with every menu.")
		await frames()
		var buttons = hud.modal_body.get_children().filter(func(n): return n is Button)
		check(carved(hud.modal) and buttons.all(func(b): return carved(b,"normal")) and root.get_visible_rect().encloses(hud.modal.get_global_rect()),menu.capitalize()+" uses the shared sandstone panel and live buttons within the viewport")
		await capture(menu)
	hud.close_modal(); game.mode="playing"; hud.tick(0)
	panels.open_skills(); panels.show_tip("cleave"); await frames()
	check(carved(panels.tip),"Skill details use the same carved frame")
	panels.close(); await frames(); panels.open_inventory(); panels.hovered_item="head"; hud.tick(0); await frames()
	check(carved(panels.item_tip),"Item details use the same carved frame while preserving rarity colours")
	await capture("inventory")
	check(hud.root.theme.get_stylebox("panel","TooltipPanel").get_script()==Shrine.Frame and hud.root.theme.get_stylebox("panel","PopupMenu").get_script()==Shrine.Frame,"Native tooltips and popup menus share sandstone chrome")
	check(hud.root.theme.get_stylebox("grabber","VScrollBar").border_color==Shrine.STONE,"Scrollbars share the shrine palette")
	FileAccess.open("res://test-results/shrine-ui.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("SHRINE_UI ",passed.size()," passed; ",failed)
	game.queue_free(); await frames(); quit(0 if failed.is_empty() else 1)
