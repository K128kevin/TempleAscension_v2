extends SceneTree
## Renders a hero as he is dressed, for inspection: front and back.
##   Godot --path . --script tools/preview_gear.gd -- --class=warrior
##     [--wear=head=,chest=steel_breastplate,main=greatsword,off=]  changes to
##         the class's starting equipment (slot=base item id, or
##         prefix:base:suffix for a magic one; nothing after = empty)
##     [--clip=SwordIdle --phase=.5] [--yaw=0.5] [--size=2.5] [--height=1.0] [--out=name]
##     [--play=2]  plays the clip that many seconds (and on to --phase) first,
##         so what swings with him (the warrior's kilt) has swung
##     [--spread=1.7]  how far apart the two figures stand (closer, to look close up)
##     [--tilt=0]  how many degrees the camera looks down from
##     [--pan=0.0]  the camera moved this far to the right (to frame one figure)
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
	preload("res://scripts/reflections.gd").apply(env.environment,"studio")
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
	# (`--tilt`: degrees the camera looks down from, as the game's does.)
	var tilt = deg_to_rad(float(arg("tilt","0")))
	var pan = float(arg("pan","0.0"))
	camera.look_at_from_position(Vector3(pan,height+8.0*sin(tilt),8.0*cos(tilt)),Vector3(pan,height,0))
	var hero_class = arg("class","warrior")
	var run = {"class_id":hero_class}
	Items.outfit(run,hero_class)
	for change in arg("wear","").split(",",false):
		var pair = change.split("=")
		# (A base item's id, or one with its prefix and suffix: "swift:steel_longsword:zeus".)
		if pair.size() < 2 or pair[1].is_empty():
			run.equipment[pair[0]] = {}
			continue
		var parts = pair[1].split(":")
		run.equipment[pair[0]] = Items.make(parts[1],parts[0],parts[2]) if parts.size() == 3 else Items.make(parts[0])
	var yaw = float(arg("yaw","0.5"))
	for i in 2:
		var stand = Node3D.new()
		scene.add_child(stand)
		stand.position = Vector3((i-.5)*float(arg("spread","1.7")),0,0)
		stand.rotation.y = yaw+PI*i
		var actor = Visual.new()
		stand.add_child(actor)
		actor.setup(false,Color.WHITE,"",1.0,"",hero_class)
		actor.wear(run.equipment)
		var clip = arg("clip","")
		for f in 30: actor.advance(.016)
		if clip != "" and actor.clips.has(clip) and float(arg("play","0")) > 0.0:
			# Played through for that long (and on to the phase), on the
			# unit's clock, so what swings (the kilt, a cloak) has swung.
			actor.state = clip
			actor.animator.play(actor.clips[clip],0)
			var length: float = actor.animator.get_animation(actor.clips[clip]).length
			for f in int((float(arg("play","0"))+length*float(arg("phase","0")))*60.0): actor.advance(1.0/60.0)
		elif clip != "" and actor.clips.has(clip):
			actor.state = clip
			actor.animator.play(actor.clips[clip],0)
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*float(arg("phase","0")),true)
			actor.advance(0.001)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/gear-%s.png" % arg("out","preview"))
	print("GEAR_DONE")
	quit(0)
