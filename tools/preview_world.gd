extends SceneTree
## Photographs the game as it is played, for judging its figures in their own
## light: the hero among the townspeople in the street by day and by night,
## at the game's own zoom and close, and in the arena basement among the
## bandits. Prints the frame rate it ran at in each.
##   Godot --path . --resolution 1440x900 --script tools/preview_world.gd --
##     [--class=warrior] [--out=prefix]
## The pictures go to test-results/world-<prefix>-<view>.png.
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Town = preload("res://scripts/world_town.gd")

func _initialize(): call_deferred("capture")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback

func shoot(game, name: String, settle: int = 40) -> void:
	for i in settle: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/world-%s-%s.png" % [arg("out","look"),name])
	# The frame rate over a further second.
	var start = Time.get_ticks_msec()
	var frames = 0
	while Time.get_ticks_msec()-start < 1500:
		await process_frame
		frames += 1
	print("WORLD_VIEW %s fps=%.1f draw_calls=%d" % [name,frames/((Time.get_ticks_msec()-start)/1000.0),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])

func capture():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/preview-world-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.run = Data.new_character(arg("class","warrior"))
	game.run.clock = Daylight.MORNING+300.0
	game.load_floor()
	game.set_process(true)
	game.intro_left = 0.0
	if game.has_method("end_intro"): game.end_intro()
	# In the street on the arena's north side, by the inn.
	var street: Vector3 = Town.ARENA+Vector3(-10,0,-Town.ARENA_RADII.y-7.0)
	game.player.position = street
	game.route.clear()
	game.world.zoom = 19.0
	await shoot(game,"day",90)
	game.world.zoom = 7.0
	await shoot(game,"day-close")
	game.world.zoom = 3.5
	await shoot(game,"day-closest")
	game.run.clock = Daylight.NIGHT+200.0
	game.world.set_time(game.run.clock)
	game.world.zoom = 12.0
	await shoot(game,"night")
	# The arena basement, among its bandits.
	game.run.place = "basement"
	game.run.floor = 0
	game.run.position = [0,9]
	game.run.dead = []
	game.run.drops = []
	game.load_floor()
	game.invincible_test = true
	game.world.zoom = 12.0
	await shoot(game,"basement",60)
	print("WORLD_DONE")
	quit(0)
