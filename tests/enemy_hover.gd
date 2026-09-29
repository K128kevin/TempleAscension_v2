extends SceneTree
const Data = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var game
var passed = 0
var failures: Array = []
var render = false
func _initialize(): call_deferred("verify")
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failures.append(message); push_error(message)
func frames(n: int):
	for i in n: await process_frame
func body(enemy) -> Vector2:
	return game.world.camera.unproject_position(enemy.position+Vector3.UP*enemy.config.size)
func mouse(at: Vector2):
	var pixel: Vector2=root.get_final_transform()*at
	Input.warp_mouse(pixel)
	var motion=InputEventMouseMotion.new(); motion.position=pixel; motion.global_position=pixel
	Input.parse_input_event(motion); Input.flush_buffered_events()
	await frames(3)
	game.update_enemy_hover()
func snapshot(name: String):
	game.hud.tick(0)
	await frames(2); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hover-"+name+".png")
func verify():
	render = "--render-hover" in OS.get_cmdline_user_args()
	Save.directory = ProjectSettings.globalize_path("res://test-results/enemy-hover-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode=true; game.set_process(false)
	game.run=Data.new_run(); game.run.seed=0; game.load_floor(); game.sound.muted=true
	for enemy in game.enemies: enemy.dead=true; enemy.visible=false
	var room: Rect2i=game.world.layout.rooms[0]
	for candidate in game.world.layout.rooms:
		if mini(candidate.size.x,candidate.size.y)>mini(room.size.x,room.size.y): room=candidate
	var at: Vector3=game.world.layout.to_world(game.world.layout.center(room))
	var enemy=game.enemies[0]
	enemy.dead=false; enemy.visible=true; enemy.position=at
	game.player.position=at+Vector3(0,0,1.4)
	game.world.follow(at,1)
	var bar=game.hud.hover_health
	for size in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1280,720),Vector2i(1120,700)]:
		root.size=size; await frames(3)
		for zoom in [15.0,36.0]:
			game.world.zoom=zoom; game.world.follow(at,1)
			var center=body(enemy)
			check(game.enemy_at_screen(center+Vector2(55,0))==enemy,"Expanded area accepts an offset the old 38px radius rejected: %s / %.0f" % [size,zoom])
			check(game.enemy_at_screen(center+Vector2(100,0))==null,"Outside the target area stays a ground click: %s / %.0f" % [size,zoom])
			if not render: continue
			await mouse(center+Vector2(55,0))
			check(game.clicked_enemy()==enemy,"Rendered pointer selects the enlarged region: %s / %.0f" % [size,zoom])
			check(game.hover_ring.visible and bar.visible,"Hover shows the ring and health bar together")
			check(game.hover_ring.position.distance_to(enemy.position+Vector3.UP*.08)<.001,"Red ring rests under the enemy's feet")
			for ratio in [1.0,.5,.1]:
				enemy.hp=enemy.max_hp*ratio; game.update_enemy_hover()
				check(absf(bar.value/bar.max_value-ratio)<.001,"Hover bar tracks the enemy's current health")
			var head: Vector2=game.world.camera.unproject_position(enemy.position+Vector3.UP*enemy.config.size*2.25)
			check(bar.size==Vector2(72,5) and absf(bar.get_global_rect().get_center().x-head.x)<1 and bar.get_global_rect().end.y<head.y,"Small bar follows the head in logical viewport coordinates")
			check(bar.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Health bar does not intercept attacks")
			if size==Vector2i(1280,800) and zoom==15:
				enemy.hp=enemy.max_hp*.5; game.update_enemy_hover()
				await snapshot("gladiator-half-health")
			await mouse(center+Vector2(100,0))
			check(not game.hover_ring.visible and not bar.visible,"Moving outside the click area hides both indicators")
	# Overlapping areas select the nearest body center consistently.
	var other=game.enemies[1]; other.dead=false; other.visible=true
	other.position=at+Vector3(1.5,0,0)
	check(game.enemy_at_screen(body(other))==other,"Nearest enemy wins when enlarged areas overlap")
	other.dead=true; other.visible=false
	enemy.dead=true; check(game.enemy_at_screen(body(enemy))==null,"Dead enemies cannot be hovered or selected")
	enemy.dead=false; enemy.visible=false
	check(game.enemy_at_screen(body(enemy))==null,"Hidden enemies cannot be hovered or selected")
	enemy.visible=true
	var offering=game.spawn_enemy("offering","hover:offering",at+Vector3(4,0,0))
	check(game.enemy_at_screen(body(offering))!=offering,"Dormant offerings cannot be hovered or selected")
	offering.dead=true; offering.visible=false
	var boss=game.spawn_enemy("boss","hover:boss",at+Vector3(4,0,0))
	game.world.zoom=15; game.world.follow(boss.position,1)
	check(game.enemy_at_screen(game.world.camera.unproject_position(boss.position))==boss,"Close-zoom large enemy can be selected at its feet")
	check(game.enemy_at_screen(game.world.camera.unproject_position(boss.position+Vector3.UP*4.2))==boss,"Close-zoom large enemy can be selected at its head")
	if render:
		boss.hp=boss.max_hp*.5
		await mouse(body(boss)); await snapshot("boss-half-health")
		check(game.hover_ring.scale==Vector3.ONE*boss.config.size,"Ring scales to the large enemy")
		boss.visible=false; boss.dead=true
		game.world.follow(at,1); game.world.zoom=15; game.world.follow(at,1)
		await mouse(body(enemy)+Vector2(55,0))
		game.player.position=at+Vector3(0,0,1.4); game.player.cooldown=0; game.player.busy=0
		var pixel: Vector2=root.get_final_transform()*root.get_mouse_position()
		for pressed in [true,false]:
			var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT
			event.position=pixel; event.global_position=pixel; event.pressed=pressed
			Input.parse_input_event(event); Input.flush_buffered_events(); await frames(1)
		check(game.target==enemy and game.player.busy>0,"Actual left click in the enlarged area starts an attack")
		game.mode="paused"; game.update_enemy_hover()
		check(not game.hover_ring.visible and not bar.visible,"Pause hides the hover indicators")
		game.mode="playing"; await mouse(body(enemy))
		enemy.dead=true; game.update_enemy_hover()
		check(not game.hover_ring.visible and not bar.visible,"Enemy death immediately clears hover feedback")
		enemy.dead=false
		# Put a projected target behind the Pause button to verify UI priority.
		var pause: Button
		for node in game.hud.root.get_children():
			if node is Button and node.text=="ESC · Pause": pause=node
		var button_center: Vector2=pause.get_global_rect().get_center()
		enemy.position=game.world.camera.project_position(button_center,10)-Vector3.UP*enemy.config.size
		await mouse(button_center)
		check(game.enemy_at_screen(button_center)==enemy and game.clicked_enemy()==null,"HUD buttons take priority over enemies behind them")
		check(not game.hover_ring.visible and not bar.visible,"Hovering UI does not highlight an enemy behind it")
	game.load_floor()
	check(not game.hover_ring.visible and not bar.visible,"Changing floors clears old hover feedback")
	print("ENEMY_HOVER ",passed," passed; ",failures)
	game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
