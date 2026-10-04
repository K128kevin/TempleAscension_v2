extends SceneTree
func _initialize(): call_deferred("capture")
func frames(n: int):
	for i in n: await process_frame
func screenshot(name: String):
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func capture():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/map-preview-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.run = preload("res://scripts/data.gd").new_run()
	game.run.seed = 0
	for level in 4:
		game.run.floor = level
		game.run.dead = []; game.run.drops = []; game.run.position = [0,9]
		game.load_floor()
		for enemy in game.enemies: enemy.visual.animator.pause()
		game.hud.tick(0)
		await screenshot("generated-entrance-%d" % [level+1])
		var largest: Rect2i = game.world.layout.rooms[0]
		for room in game.world.layout.rooms:
			if room.get_area()>largest.get_area(): largest=room
		game.player.position = game.world.layout.to_world(game.world.layout.center(largest))
		if not game.world.fits(game.player.position):
			var tile: Vector2i = game.world.navigation_cell(game.player.position,false)
			game.player.position = Vector3(tile.x,0,tile.y)
		game.world.follow(game.player.position,1)
		await screenshot("generated-room-%d" % [level+1])
		var center: Vector2 = game.world.bounds.get_center()
		var camera: Camera3D = game.world.camera
		camera.position = Vector3(center.x,110,center.y+.01)
		camera.look_at(Vector3(center.x,0,center.y),Vector3(0,0,-1))
		camera.size = maxf(game.world.bounds.size.y+5,(game.world.bounds.size.x+5)/1.6)
		for light in game.world.shadow_torches: light.distance_fade_enabled = false
		game.hud.visible = false
		await screenshot("generated-map-%d" % [level+1])
		game.hud.visible = true
		print("MAP_PREVIEW ",level+1," rooms=",game.world.layout.rooms.size()," torches=",game.world.shadow_torches.size()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("GENERATED_MAP_PREVIEWS_READY")
	quit()
