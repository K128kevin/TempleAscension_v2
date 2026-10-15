extends SceneTree
## Photographs the outdoor world's edges as played: the river by the town and
## round the desert's south, the mountains north of the track, round the
## temple and down to the river, and the opening view from the dune.
##   Godot --path . --resolution 1440x900 --script tools/preview_terrain.gd --
##     [--only=name,name] [--zoom=19]
## The pictures go to test-results/terrain-<view>.png.
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const VIEWS = {
	"quay":Vector3(-366,0,-20),"quay-south":Vector3(-364,0,96),"south-street":Vector3(-290,0,88),
	"bend":Vector3(-350,0,250),"river-south":Vector3(-200,0,262),"river-mouth":Vector3(-70,0,262),
	"slope":Vector3(-10,0,180),"north":Vector3(-40,0,-48),"temple":Vector3(55,0,0),"temple-south":Vector3(70,0,60),
	"cave":Vector3(20,0,-62),"gorge":Vector3(-355,0,-74),"town-gate":Vector3(-176,0,96),"se-foot":Vector3(18,0,150),"e-foot":Vector3(70,0,52),"n-foot":Vector3(-60,0,-50),"se-corner":Vector3(-172,0,112),"ne-corner":Vector3(-172,0,-70),"palace-sw":Vector3(-306,0,-72),"palace-nw":Vector3(-306,0,-150),"palace-ne":Vector3(-202,0,-150),"palace-se":Vector3(-202,0,-72),"wall-south":Vector3(-300,0,104),"wall-south2":Vector3(-200,0,104),"nw-river":Vector3(-372,0,-60)}

func _initialize(): call_deferred("capture")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback

func shoot(name: String, settle: int = 30) -> void:
	for i in settle: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/terrain-%s.png" % name)
	print("TERRAIN_VIEW ",name," ",Time.get_ticks_msec())

func capture():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/preview-terrain-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.run = Data.new_character("warrior")
	game.run.clock = Daylight.MORNING+500.0
	var only = arg("only","")
	if only == "" or "opening" in only:
		game.load_floor()
		game.start_intro()
		await shoot("opening",60)
	print("TERRAIN_LOAD ",Time.get_ticks_msec())
	game.load_floor()
	print("TERRAIN_LOADED ",Time.get_ticks_msec())
	game.set_process(true)
	game.intro_left = 0.0
	if game.has_method("end_intro"): game.end_intro()
	for name in VIEWS:
		if only != "" and not name in only.split(","): continue
		game.player.position = VIEWS[name]
		game.route.clear()
		game.world.zoom = float(arg("zoom","19"))
		await shoot(name,45)
	print("TERRAIN_DONE")
	quit(0)
