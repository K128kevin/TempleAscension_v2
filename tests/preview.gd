extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/preview-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.run = preload("res://scripts/data.gd").new_run()
	game.load_floor()
	game.mode = "preview"
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/entrance.png")
	game.player.position = Vector3(-7,0,-5)
	game.world.follow(game.player.position,1)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hall.png")
	game.world.zoom = 12
	game.player.position = Vector3(0,0,8)
	game.world.follow(game.player.position,1)
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/character.png")
	game.run.floor = 4
	game.run.position = [0,-26]
	game.run.dead = []
	game.run.drops = []
	game.load_floor()
	game.invincible_test = true
	for i in 140: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/floor-five.png")
	print("FLOOR_FIVE_METRICS ",JSON.stringify({"fps":Performance.get_monitor(Performance.TIME_FPS),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	game.run.floor = 5
	game.run.position = [0,-28]
	game.run.dead = []
	game.run.drops = []
	game.load_floor()
	game.mode = "preview"
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/summit.png")
	print("PREVIEW_READY")
	quit()
