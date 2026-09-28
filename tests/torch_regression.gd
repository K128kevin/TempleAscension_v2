extends SceneTree
const TorchFlame = preload("res://scripts/torch_flame.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var game
var fires: Array = []
var rendered = false

func _initialize(): call_deferred("test")

func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func capture(filename: String):
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+filename+".png")

func test():
	rendered = "--render-torches" in OS.get_cmdline_user_args()
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/torch-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.run = preload("res://scripts/data.gd").new_run()
	game.run.floor = 3
	game.load_floor()
	var world = game.world
	for child in world.get_children():
		if child is TorchFlame:
			fires.append(child)
			child.set_process(false)
	check(fires.size()==world.shadow_torches.size() and fires.size()>2,"Every torch has an animated flame and its original local light")
	var first = fires[0]
	var second = fires[1]
	var different = false
	var min_energy = INF
	var max_energy = 0.0
	var previous = first.light.light_energy
	var max_step = 0.0
	var start_time: float = first.flame_material.get_shader_parameter("flame_time")
	for i in 600:
		first.advance(1.0/60.0)
		second.advance(1.0/60.0)
		var energy: float = first.light.light_energy
		min_energy = minf(min_energy,energy)
		max_energy = maxf(max_energy,energy)
		max_step = maxf(max_step,absf(energy-previous))
		previous = energy
		if absf(energy-second.light.light_energy)>.02: different = true
	var base: float = first.base_energy
	check(min_energy>=base*.9 and max_energy<=base*1.1 and max_energy-min_energy>base*.05,"Flicker varies visibly while remaining within ten percent of the torch's brightness")
	check(max_step<.04,"Light changes smoothly without frame-to-frame flashes")
	check(different,"Neighboring torches flicker independently")
	check(is_equal_approx(first.flame_material.get_shader_parameter("flame_time"),start_time+10.0),"Flame animation advances with elapsed time at the same rate as the light")
	check(first.light.omni_range==9.0 and first.light.shadow_caster_mask==2,"Flicker preserves the existing light reach and shadow mask")
	if rendered:
		fires.sort_custom(func(a,b): return a.position.distance_squared_to(world.spawn)<b.position.distance_squared_to(world.spawn))
		var target = fires[0]
		game.player.position = target.position+Vector3(1,-2.08,1)
		world.zoom = 6
		world.follow(target.position-Vector3.UP*.5,1)
		for frame in 3:
			for fire in fires: fire.advance(.23)
			await capture("torch-flame-%d" % frame)
		world.zoom = 19
		world.follow(game.player.position,1)
		await capture("torch-room")
		var strip: Rect2i = world.layout.terrace[0]
		game.player.position = world.layout.to_world(world.layout.center(strip))
		world.follow(game.player.position,1)
		await capture("torch-terrace")
	FileAccess.open("res://test-results/torch-regression.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("TORCH_REGRESSION: ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
