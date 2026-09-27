extends SceneTree
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
var game
var passed: Array = []
var failed: Array = []
var origin = Vector3(0,0,5)
func _initialize(): call_deferred("run_tests")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func point_at(point: Vector3):
	# Warp to the pixel actually shown in the rendered window. The camera's
	# unprojection is in logical pixels, just like viewport mouse input.
	var logical: Vector2 = game.world.camera.unproject_position(point)
	Input.warp_mouse(root.get_final_transform()*logical)
	await frames(3)
func button(index: int, down: bool):
	var event = InputEventMouseButton.new()
	event.position = root.get_final_transform()*root.get_mouse_position()
	event.global_position = event.position
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func shift(down: bool):
	var event = InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func reset():
	game.player.position = origin
	game.player.cooldown = 0
	game.player.busy = 0
	game.player.visual.dead = false
	game.left_held = false
	game.right_held = false
	game.target = null
	game.order_pending = false
	game.route.clear()
	game.scheduled.clear()
	game.skills.reset()
	game.run.skill_cooldowns.clear()
	game.run.energy = 100
	game.leap_left = 0
	game.dash_time = 0
	game.player.visual.position = Vector3.ZERO
	for p in game.projectiles: p.node.queue_free()
	game.projectiles.clear()
	game.world.follow(origin,1)
func advance(seconds: float):
	for i in ceili(seconds*60):
		game.player.tick(1.0/60)
		game.player_control(1.0/60)
		game.tick_scheduled(1.0/60)
		game.skills.tick(1.0/60)
		game.tick_projectiles(1.0/60)
		game.tick_effects(1.0/60)
func run_tests():
	Save.directory = ProjectSettings.globalize_path("res://test-results/controls-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.run = Data.new_run()
	game.run.seed = 0
	game.load_floor()
	var room: Rect2i = game.world.layout.rooms[0]
	for candidate in game.world.layout.rooms:
		if mini(candidate.size.x,candidate.size.y)>mini(room.size.x,room.size.y): room=candidate
	origin = game.world.layout.to_world(game.world.layout.center(room))
	for enemy in game.enemies: enemy.dead = true; enemy.visible = false
	await frames(10)
	# Cardinal and diagonal directions in screen space, including screen-left.
	var right = Vector3(19,0,-12).normalized()
	var down = Vector3(12,0,19).normalized()
	var directions = [right,-right,down,-down,(right+down).normalized(),(right-down).normalized(),(-right+down).normalized(),(-right-down).normalized()]
	for size in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1120,700),Vector2i(1280,720)]:
		root.size = size
		await frames(5)
		for d in directions:
			reset()
			var destination: Vector3 = origin+d*2.8
			await point_at(destination)
			var clicked_point: Vector3 = game.world.pointer()
			var pixel_error: Vector2 = root.get_final_transform().basis_xform(game.world.camera.unproject_position(clicked_point)-game.world.camera.unproject_position(destination))
			check(pixel_error.length()<3.0,"Rendered cursor projects onto ground %s / %s (actual %s, expected %s)" % [size,d,game.world.pointer(),destination])
			game.player_control(.016)
			check(game.player.forward().dot(d)>.995,"Idle faces cursor %s / %s" % [size,d])
			button(MOUSE_BUTTON_LEFT,true)
			button(MOUSE_BUTTON_LEFT,false)
			advance(.1)
			check(game.player.forward().dot(d)>.995,"Click movement faces travel %s / %s" % [size,d])
			advance(.8)
			check(game.player.position.distance_to(clicked_point)<.061,"Released click reaches exact floor point %s / %s (actual %s, expected %s)" % [size,d,game.player.position,destination])
	root.size = Vector2i(1280,800)
	await frames(5)
	reset()
	await point_at(origin+right*3)
	button(MOUSE_BUTTON_LEFT,true)
	advance(.15)
	var turn_from: Vector3 = game.player.position
	await point_at(origin-right*3)
	advance(.2)
	check((game.player.position-turn_from).dot(-right)>.8,"Held ground input immediately repaths to screen-left")
	button(MOUSE_BUTTON_LEFT,false)
	advance(1)
	check(game.player.position.distance_to(origin-right*3)<.12,"Release finishes last held destination")
	reset()
	await point_at(origin+down*3)
	button(MOUSE_BUTTON_LEFT,true)
	button(MOUSE_BUTTON_LEFT,false)
	advance(.1)
	var planted: Vector3 = game.player.position
	shift(true)
	advance(.3)
	check(game.player.position.distance_to(planted)<.001 and game.route.is_empty(),"Shift stops an existing route even without a mouse press")
	shift(false)
	# A real obstacle route, including the approach from an off-grid start.
	reset()
	game.player.position = game.world.spawn+Vector3(.12,0,.12)
	var finish: Vector3 = game.world.exit_point+Vector3(.13,0,.13)
	game.route = game.world.path(game.player.position,finish)
	check(game.route.size()>1,"Generated corridors require a detour")
	var safe = true
	for i in 3600:
		game.player_control(1.0/60)
		safe = safe and game.world.fits(game.player.position,.39)
	check(safe and game.player.position.distance_to(finish)<.1,"Mouse route traverses generated rooms and corridors without crossing walls")
	# Exercise input, hit cones, arrows and animated head orientation together.
	var victim = game.enemies[0]
	victim.visible = true
	for weapon in 4:
		game.run = Data.new_run("ranger" if weapon==2 else "warrior")
		game.run.owned[weapon] = true
		game.run.weapon = weapon
		game.player.visual.equip(Data.WEAPONS[weapon])
		for d in directions:
			reset()
			victim.dead = false
			victim.hp = 10000
			victim.position = origin+d*1.5
			await point_at(victim.position+Vector3.UP*victim.config.size)
			check(game.clicked_enemy()==victim,"Rendered statue picking weapon %d / %s" % [weapon,d])
			button(MOUSE_BUTTON_LEFT,true)
			button(MOUSE_BUTTON_LEFT,false)
			check(game.player.forward().dot(d)>.995,"Normal attack aims weapon %d / %s" % [weapon,d])
			game.player.visual.animator.advance(.10)
			await frames(1)
			var sk: Skeleton3D = game.player.visual.skeleton
			var head: Transform3D = sk.global_transform*sk.get_bone_global_pose(sk.find_bone("Head"))
			var facing = Vector3(head.basis.z.x,0,head.basis.z.z).normalized()
			check(facing.dot(d)>.35,"Animated model faces hit direction weapon %d / %s (%s)" % [weapon,d,facing])
			if weapon==0:
				check(game.player.visual.weapon_item.global_basis.y.normalized().dot(d)>.995,"Spear shaft points along thrust %s" % d)
			if weapon==2:
				game.tick_scheduled(preload("res://scripts/combat_animation.gd").profile(weapon,false,0).times[0])
				check(not game.projectiles.is_empty() and (-game.projectiles[0].node.global_basis.y.normalized()).dot(d)>.995,"Arrow mesh points along flight %s" % d)
			advance(1.2)
			check(victim.hp<10000,"Normal attack damages statue weapon %d / %s" % [weapon,d])
			if d == -right:
				game.player.visual.animator.play(game.player.visual.clips[preload("res://scripts/combat_animation.gd").NORMAL[weapon].clip],0)
				game.player.visual.animator.advance(.15)
				await frames(1)
				game.hud.tick(0)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/left-weapon-%d.png" % weapon)
			reset()
			victim.position = origin+d*1.5
			victim.hp = 10000
			await point_at(victim.position+Vector3.UP*victim.config.size)
			button(MOUSE_BUTTON_RIGHT,true)
			button(MOUSE_BUTTON_RIGHT,false)
			check(game.player.forward().dot(d)>.995,"Special aims weapon %d / %s" % [weapon,d])
			advance(1.3)
			check(victim.hp<10000,"Special damages statue weapon %d / %s" % [weapon,d])
		victim.dead = true
	# Shift attacks aim at floor even when no enemy is under the cursor.
	reset()
	game.run.weapon=1
	game.player.visual.equip("sword")
	victim.dead = false
	victim.position = origin-right*1.5
	victim.hp = 10000
	await point_at(origin-right*3)
	shift(true)
	button(MOUSE_BUTTON_LEFT,true)
	advance(2.1)
	button(MOUSE_BUTTON_LEFT,false)
	shift(false)
	check(victim.hp<9980 and game.player.position==origin,"Held Shift attacks repeatedly toward screen-left without moving")
	# A click released out of range keeps pursuing a target that changes course.
	reset()
	victim.position = origin+right*4
	await point_at(victim.position+Vector3.UP*victim.config.size)
	button(MOUSE_BUTTON_LEFT,true)
	button(MOUSE_BUTTON_LEFT,false)
	victim.position = origin-right*2
	victim.hp = 10000
	advance(1.1)
	check(victim.hp<10000,"Released enemy click repaths to a moving target and lands its attack")
	var report = {"passed":passed.size(),"failed":failed,"checks":passed}
	var file = FileAccess.open("res://test-results/controls-regression.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("CONTROLS_REGRESSION ",passed.size()," passed; failures: ",failed)
	quit(0 if failed.is_empty() else 1)
