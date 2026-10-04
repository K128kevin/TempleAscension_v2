extends SceneTree
## Alt+Z hides the whole interface and shows it again (scripts/game.gd
## show_ui). With --render-ui the HUD at its narrowest and the hidden view are
## drawn to test-results/hide-ui-*.png.
const Data = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var game
var passed = 0
var failures: Array = []
func _initialize(): call_deferred("verify")
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failures.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func snapshot(name: String):
	if not "--render-ui" in OS.get_cmdline_user_args(): return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hide-ui-"+name+".png")
func alt_z():
	var key = InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.keycode = KEY_Z
	key.alt_pressed = true
	key.pressed = true
	game._input(key)

func verify():
	Save.directory = ProjectSettings.globalize_path("res://test-results/hide-ui-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode = true
	game.run = Data.new_run(); game.run.seed = 0; game.load_floor(); game.sound.muted = true
	game.mode = "playing"
	root.size = Vector2i(1120,700)
	var enemy = game.enemies[0]
	game.float_text(game.player.position,"12",Color.WHITE)
	enemy.sleep(5.0)
	var number: Label3D = game.world.get_children().filter(func(n): return n is Label3D)[-1]
	check(number.layers == game.UI_LAYER and game.hover_ring.layers == game.UI_LAYER and is_instance_valid(enemy.stun_mark) and enemy.stun_mark.layers == game.UI_LAYER,"Damage numbers, a dazed enemy's marks and the target ring are drawn on the interface's layer")
	check(game.hud.visible and game.world.camera.get_cull_mask_value(20),"At first the interface is shown")
	await snapshot("shown")
	alt_z()
	check(game.ui_hidden and not game.hud.visible and not game.world.camera.get_cull_mask_value(20),"Alt+Z hides the HUD and every word and mark over the world")
	check(game.world.camera.get_cull_mask_value(1),"The world itself is still drawn")
	await snapshot("hidden")
	game.load_floor()
	check(game.ui_hidden and not game.hud.visible and not game.world.camera.get_cull_mask_value(20),"It stays hidden on a new floor")
	alt_z()
	check(not game.ui_hidden and game.hud.visible and game.world.camera.get_cull_mask_value(20),"Alt+Z again shows it all again")
	# Z alone is not the toggle.
	var plain = InputEventKey.new()
	plain.physical_keycode = KEY_Z; plain.keycode = KEY_Z; plain.pressed = true
	game._input(plain)
	check(not game.ui_hidden,"Z without Alt does nothing to it")
	print("HIDE_UI ",passed," passed; ",failures)
	quit(0 if failures.is_empty() else 1)
