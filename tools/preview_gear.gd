extends SceneTree
## Renders a hero as he is dressed, for inspection: front and back.
##   Godot --path . --script tools/preview_gear.gd -- --class=warrior
##     [--wear=head=,chest=bronze_cuirass,main=greatsword,off=]  changes to
##         the class's starting equipment (slot=item id; nothing after = empty)
##     [--clip=SwordIdle --phase=.5] [--yaw=0.5] [--size=2.5] [--height=1.0] [--out=name]
## The picture goes to test-results/gear-<out>.png.
const Visual = preload("res://scripts/visual.gd")
const Items = preload("res://scripts/items.gd")
func _initialize(): call_deferred("capture")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback
func capture():
	var scene = Node3D.new()
	root.add_child(scene)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.16,.17,.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .7
	scene.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,150,0)
	sun.light_energy = 1.3
	scene.add_child(sun)
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(arg("size","2.5"))
	var height = float(arg("height","1.0"))
	camera.look_at_from_position(Vector3(0,height,8),Vector3(0,height,0))
	var hero_class = arg("class","warrior")
	var run = {"class_id":hero_class}
	Items.outfit(run,hero_class)
	for change in arg("wear","").split(",",false):
		var pair = change.split("=")
		run.equipment[pair[0]] = pair[1] if pair.size() > 1 else ""
	var yaw = float(arg("yaw","0.5"))
	for i in 2:
		var stand = Node3D.new()
		scene.add_child(stand)
		stand.position = Vector3((i-.5)*1.7,0,0)
		stand.rotation.y = yaw+PI*i
		var actor = Visual.new()
		stand.add_child(actor)
		actor.setup(false,Color.WHITE,"",1.0,"",hero_class)
		actor.wear(run.equipment)
		var clip = arg("clip","")
		for f in 30: actor.advance(.016)
		if clip != "" and actor.clips.has(clip):
			actor.state = clip
			actor.animator.play(actor.clips[clip],0)
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*float(arg("phase","0")),true)
			actor.advance(0.001)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/gear-%s.png" % arg("out","preview"))
	print("GEAR_DONE")
	quit(0)
