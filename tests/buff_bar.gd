extends SceneTree
## The row of the hero's buffs and debuffs over the hotbar (scripts/hud.gd
## show_effects(), Skills.effects()): an icon for each, its stacks, and a bar
## under it running down with its time. With --render-buffs the row is drawn
## to test-results/buff-bar.png.
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
var passed = 0
var failures: Array = []
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failures.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func shown(hud) -> Array:
	return hud.effect_slots.filter(func(s): return s.frame.visible)
func test():
	var render = "--render-buffs" in OS.get_cmdline_user_args()
	Save.directory = ProjectSettings.globalize_path("res://test-results/buff-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode = true; game.set_process(false)
	game.run = Data.new_run(); game.run.seed = 0
	Data.Skills.learn(game.run,"cleave")
	game.load_floor()
	var hud = game.hud
	var skills = game.skills
	hud.tick(0)
	check(not hud.effect_row.visible and shown(hud).is_empty(),"With nothing on him, no row shows")
	# Under the hotbar: the dash's and the healing spell's recharges.
	var tiles: Array = hud.ready_tiles
	var bar: Rect2 = hud.weapon_slots[0].get_global_rect().merge(hud.weapon_slots[-1].get_global_rect())
	var under: Rect2 = tiles[0].frame.get_global_rect().merge(tiles[1].frame.get_global_rect())
	check(tiles.map(func(t): return t.glyph.id)==["dash","heal"] and under.position.y>=bar.end.y and absf(under.get_center().x-bar.get_center().x)<1.5 and under.end.y<=root.get_visible_rect().size.y,"Dash and heal show side by side, centred under the hotbar")
	check(tiles.all(func(t): return t.count.text=="" and t.shade.size.y==0 and t.frame.get_theme_stylebox("panel")==t.styles.ready),"Both lit and ready at first")
	game.mode = "playing"; game.dash_cooldown = 0; game.dash()
	game.player.hp = 1; game.run.energy = 100; game.heal_cd = 0; game.heal()
	hud.tick(0)
	check(tiles[0].count.text=="3" and tiles[1].count.text=="20" and tiles.all(func(t): return t.frame.get_theme_stylebox("panel")==t.styles.waiting and is_equal_approx(t.shade.size.y,hud.READY_ICON-2)),"Used, each dims and counts down its recharge (%s, %s)" % [tiles[0].count.text,tiles[1].count.text])
	game.dash_cooldown = 1.5; game.heal_cd = 5.0
	hud.tick(0)
	check(tiles[0].count.text=="2" and tiles[1].count.text=="5" and is_equal_approx(tiles[0].shade.size.y,(hud.READY_ICON-2)*.5) and is_equal_approx(tiles[1].shade.size.y,(hud.READY_ICON-2)*.25),"its shade shrinking as it recharges")
	game.dash_cooldown = 0; game.heal_cd = 0; game.dash_time = 0; game.player.busy = 0; game.player.invulnerable = 0; game.player.hp = game.player.max_hp
	hud.tick(0)
	check(tiles.all(func(t): return t.count.text=="" and t.frame.get_theme_stylebox("panel")==t.styles.ready),"and is lit again once ready")
	# A buff with stacks, a timed buff, and a debuff.
	skills.offense_stacks = 3; skills.offense_time = 4.0; skills.lasting.offensive_rhythm = 4.0
	skills.frenzy_bonus = 20; skills.frenzy_time = 10.0; skills.lasting.frenzy = 10.0
	game.slowed = game.CHILL_SECONDS
	hud.tick(0)
	var slots = shown(hud)
	check(hud.effect_row.visible and slots.size()==3,"Each effect on him shows in the row (%d)" % slots.size())
	check(slots.map(func(s): return s.glyph.id)==["frenzy","offensive_rhythm","chilled"],"Each shows its icon, buffs first (%s)" % str(slots.map(func(s): return s.glyph.id)))
	check(slots[1].stacks.text=="3" and slots[0].stacks.text=="" and slots[2].stacks.text=="","Stacks are counted in the corner of one that has them")
	check(slots[2].frame.get_theme_stylebox("panel")==slots[2].styles.debuff and slots[0].frame.get_theme_stylebox("panel")==slots[0].styles.buff,"A debuff is framed in red, a buff in gold")
	check(slots.all(func(s): return s.under.visible and is_equal_approx(s.left.size.x,hud.EFFECT_ICON-2)),"Fresh, each bar under them is full")
	check("Offensive Rhythm ×3" in slots[1].frame.tooltip_text and "s left" in slots[1].frame.tooltip_text,"Hovering one names it, its stacks and its time")
	# Time passes: the bars run down, as the game's own clock runs them.
	for i in 20:
		skills.tick(.1)
		game.slowed = maxf(0,game.slowed-.1)
	hud.tick(0)
	slots = shown(hud)
	var full: float = hud.EFFECT_ICON-2
	check(absf(slots[0].left.size.x/full-.8)<.02 and absf(slots[1].left.size.x/full-.5)<.02 and absf(slots[2].left.size.x/full-.6)<.02,"Two seconds on, each bar shows what is left (%.2f %.2f %.2f)" % [slots[0].left.size.x/full,slots[1].left.size.x/full,slots[2].left.size.x/full])
	# A hit refreshes the stacks' time: its bar is full again.
	skills.offense_time = 4.0
	hud.tick(0)
	check(is_equal_approx(shown(hud)[1].left.size.x,full),"Refreshed, a bar is full again")
	# Hidden lasts as long as he stays in the shadows: no bar under it.
	skills.hidden = true; skills.hide_slow = 30
	hud.tick(0)
	var hide = shown(hud).filter(func(s): return s.glyph.id=="hide_in_shadows")
	check(hide.size()==1 and not hide[0].under.visible,"Hidden shows without a timer")
	skills.hidden = false
	# Laid out over the hotbar, clear of it, the orbs and the prompt.
	for size in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1280,720),Vector2i(1120,700)]:
		root.size = size; await frames(3); hud.tick(0)
		var row = Rect2()
		for s in shown(hud):
			var r: Rect2 = s.frame.get_global_rect().merge(s.under.get_global_rect())
			row = r if not row.has_area() else row.merge(r)
		var bar_top: float = hud.weapon_slots[0].get_global_rect().position.y
		var middle: float = (hud.weapon_slots[0].get_global_rect().position.x+hud.weapon_slots[-1].get_global_rect().end.x)*.5
		check(row.end.y<bar_top and row.end.y>bar_top-20 and absf(row.get_center().x-middle)<2,"The row sits centred just over the hotbar at %s" % size)
		check(not row.intersects(hud.health.get_global_rect()) and not row.intersects(hud.energy.get_global_rect()) and not row.intersects(hud.prompt.get_global_rect()),"Clear of the orbs and the prompt at %s" % size)
		if render and size==Vector2i(1280,800):
			skills.barrier = 40; skills.barrier_time = 6.0; skills.lasting.barrier = 8.0
			hud.tick(0)
			await frames(2); await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/buff-bar.png")
			var crop: Image = root.get_texture().get_image()
			var at: Rect2i = Rect2i(root.get_final_transform()*row.grow(40))
			crop = crop.get_region(at.intersection(Rect2i(Vector2i.ZERO,crop.get_size())))
			crop.resize(crop.get_width()*3,crop.get_height()*3,Image.INTERPOLATE_NEAREST)
			crop.save_png("res://test-results/buff-bar-close.png")
			skills.barrier = 0; skills.barrier_time = 0
	# Run out, they go; and none while he lies dead.
	for i in 120:
		skills.tick(.1)
		game.slowed = maxf(0,game.slowed-.1)
	hud.tick(0)
	check(shown(hud).is_empty() and not hud.effect_row.visible,"Run out, they are gone")
	game.slowed = game.CHILL_SECONDS
	game.player.dead = true
	hud.tick(0)
	check(not hud.effect_row.visible,"None show once he has fallen")
	game.player.dead = false
	print("BUFF_BAR ",passed," passed; ",failures)
	quit(0 if failures.is_empty() else 1)
