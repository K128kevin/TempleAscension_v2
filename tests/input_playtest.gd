extends SceneTree
const Save = preload("res://scripts/save.gd")
const Items = preload("res://scripts/items.gd")
var game
var checks: Array = []
var failed: Array = []
func _initialize() -> void:
	call_deferred("playtest")
func check(ok: bool, text: String) -> void:
	if ok: checks.append(text)
	else: failed.append(text); push_error(text)
func frames(count: int) -> void:
	for i in count: await process_frame
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
func click(at: Vector2, button: int, pressed: bool) -> void:
	at = root.get_final_transform() * at
	Input.warp_mouse(at)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func playtest() -> void:
	Save.directory = ProjectSettings.globalize_path("res://test-results/input-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.invincible_test = true
	game.run = preload("res://scripts/data.gd").new_run()
	game.run.seed = 0
	game.load_floor()
	# Keep steering checks on empty ground; enlarged enemy targets can now
	# cover the old destination. Restore the statues for the attack checks.
	for statue in game.enemies: statue.dead=true; statue.visible=false
	var room: Rect2i = game.world.layout.rooms[0]
	for candidate in game.world.layout.rooms:
		if mini(candidate.size.x,candidate.size.y)>mini(room.size.x,room.size.y): room=candidate
	var ground: Vector3 = game.world.layout.to_world(game.world.layout.center(room))
	game.player.position = ground+Vector3(0,0,1)
	game.world.follow(game.player.position,1)
	await frames(30)
	var screen: Vector2 = game.world.camera.unproject_position(ground)
	click(screen,MOUSE_BUTTON_LEFT,true)
	await frames(2)
	click(screen,MOUSE_BUTTON_LEFT,false)
	await frames(100)
	check(game.player.position.distance_to(ground)<1.5,"Ground click routes to destination")
	var right = Vector3(19,0,-12).normalized()
	var held_start: Vector3 = game.player.position
	screen = game.world.camera.unproject_position(held_start+right*2.5)
	click(screen,MOUSE_BUTTON_LEFT,true)
	await frames(18)
	check((game.player.position-held_start).dot(right)>.3,"Held ground movement follows the cursor as the camera moves")
	var turn_start: Vector3 = game.player.position
	screen = game.world.camera.unproject_position(turn_start-right*3)
	Input.warp_mouse(root.get_final_transform()*screen)
	await frames(24)
	click(screen,MOUSE_BUTTON_LEFT,false)
	check((game.player.position-turn_start).dot(-right)>.3,"Moving a held cursor to screen-left reverses the route in live gameplay")
	for statue in game.enemies: statue.dead=false; statue.visible=true
	var enemy = game.enemies[0]
	for offset in [Vector3(0,0,1.4),Vector3(1.4,0,0),Vector3(0,0,-1.4),Vector3(-1.4,0,0)]:
		if game.world.fits(enemy.position+offset): game.player.position = enemy.position+offset; break
	game.world.follow(game.player.position,1)
	await frames(2)
	var old_hp: float = enemy.hp
	screen = game.world.camera.unproject_position(enemy.position+Vector3.UP*enemy.config.size)
	click(screen,MOUSE_BUTTON_LEFT,true)
	await frames(120)
	click(screen,MOUSE_BUTTON_LEFT,false)
	check(enemy.dead or enemy.hp<old_hp,"Held mouse input selects and attacks a statue")
	await key(KEY_ESCAPE,true)
	await key(KEY_ESCAPE,false)
	check(game.mode=="paused","Escape opens pause UI")
	var before_pause: Vector3 = game.player.position
	await frames(20)
	check(game.player.position==before_pause and not game.run.has("seconds"),"Pause freezes gameplay; no elapsed time is tracked")
	game.hud.modal_body.get_child(2).pressed.emit()
	check(game.mode=="playing","Resume button works")
	game.player.invulnerable = 0
	game.run.energy = 10
	game.dash_cooldown = 0
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	check(game.run.energy>=10 and game.dash_time>0 and game.dash_cooldown>0,"Space input dashes, for no energy")
	for other in game.enemies: other.awake=false
	game.player.busy=0; game.combat_age=10
	game.run.bag[0] = Items.make("rangers_bow")
	await key(KEY_I,true); await key(KEY_I,false)
	check(game.mode=="character" and game.hud.panels.inventory_open(),"I opens the inventory and pauses combat")
	# (A right click on the bow in the bag takes it in hand.)
	game.hud.panels.quick_move("bag:0")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(game.run.equipment.main==Items.make("rangers_bow") and game.player.visual.weapon_kind=="bow","The inventory equips a bow from the bag")
	game.save_run()
	var where: Vector3 = game.player.position
	game.continue_run()
	check(game.player.position.distance_to(where)<.01 and game.run.equipment.main==Items.make("rangers_bow"),"Save/continue restores position and equipment")
	await frames(15)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/combat.png")
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var report := {"passed":checks,"failed":failed,"fps":fps,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var file := FileAccess.open("res://test-results/input-playtest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("INPUT_PLAYTEST ",JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
