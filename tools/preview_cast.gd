extends SceneTree
## Renders the game's people side by side, for judging their models and
## materials together: the three heroes as they start, bandits, the temple's
## statues, a town guard and townspeople.
##   Godot --path . --resolution 1600x900 --script tools/preview_cast.gd --
##     [--only=warrior,ranger,...]  who stands in the line (all, by default:
##         warrior ranger wizard bandit bandit_woman gladiator centurion
##         guard smith innkeeper ragged)
##     [--light=day|temple]  the desert at mid-morning, or a torchlit hall
##     [--view=front|game]  straight on, or from the game's own camera angle
##     [--size=16] the picture's width in metres  [--height=1.0] its centre
##     [--yaw=0.4] how far each figure is turned  [--out=name]
## The picture goes to test-results/cast-<out>.png.
const Visual = preload("res://scripts/visual.gd")
const Items = preload("res://scripts/items.gd")
const Data = preload("res://scripts/data.gd")
const Bandit = preload("res://scripts/bandit.gd")
const Person = preload("res://scripts/townsperson.gd")
const Guard = preload("res://scripts/town_guard.gd")
const Overworld = preload("res://scripts/overworld.gd")
const Reflections = preload("res://scripts/reflections.gd")
const ALL = ["warrior","ranger","wizard","bandit","bandit_woman","gladiator","centurion","guard","smith","innkeeper","ragged"]

func _initialize(): call_deferred("capture")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback

func bandit_seed(who: String) -> int:
	var seed = 1
	while Bandit.look(seed).who != who: seed += 1
	return seed

func figure(scene: Node3D, who: String) -> Node3D:
	if who in Data.CLASSES:
		var actor = Visual.new()
		scene.add_child(actor)
		actor.setup(false,Color.WHITE,"",1.0,"",who)
		var run = {"class_id":who}
		Items.outfit(run,who)
		actor.wear(run.equipment)
		return actor
	if who.begins_with("bandit"):
		var config: Dictionary = Data.ENEMIES["bandit"]
		var actor = Visual.new()
		scene.add_child(actor)
		actor.bandit_look = Bandit.look(bandit_seed("woman" if who == "bandit_woman" else "man"))
		actor.setup(false,Color.WHITE,config.weapon,config.size,"",config.human)
		return actor
	if who in ["gladiator","centurion","archer","wizard_statue"]:
		var kind = "wizard" if who == "wizard_statue" else who
		var config: Dictionary = Data.ENEMIES[kind]
		var actor = Visual.new()
		scene.add_child(actor)
		actor.setup(true,config.color,config.weapon,1,kind)
		return actor
	if who == "guard":
		var guard = Guard.new()
		scene.add_child(guard)
		guard.setup(.4)
		return guard
	var looks = {
		"smith":{"who":"man","garment":"Sack","cloth":Color(.40,.27,.16),"wear":.35,"hair":"","beard":true,"hair_colour":Color(.05,.04,.035),"skin":"dark","belt":Color(.25,.16,.09),"bulk":.8,"shoes":Color(.3,.2,.12),"size":1.0,"seed":.2},
		"innkeeper":{"who":"woman","garment":"Dress","under":"Blouse","cloth":Color(.36,.24,.15),"under_cloth":Color(.92,.9,.85),"wear":.06,"hair":"Hair_Long","braid":true,"hair_colour":Color(.09,.06,.04),"skin":"light","tone":Color(1.0,.92,.84),"belt":Color(.3,.2,.12),"size":.97,"seed":.4},
		"ragged":{"who":"man","garment":"Tunic","cloth":Color(.50,.40,.28),"wear":.92,"weave":"hessian","hair":"Hair_SimpleParted","beard":true,"hair_colour":Color(.22,.16,.1),"skin":"dark","gaunt":.8,"size":.98,"seed":.7}}
	var person = Person.new()
	scene.add_child(person)
	person.setup(looks[who])
	return person

func capture():
	var scene = Node3D.new()
	root.add_child(scene)
	var light = arg("light","day")
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 1.3
	if light == "temple":
		e.background_color = Color(.02,.02,.025)
		e.ambient_light_color = Color(.35,.40,.50)
		e.ambient_light_energy = .24
	else:
		e.background_color = Color(.80,.66,.46)
		e.ambient_light_color = Color(.70,.78,.96)
		e.ambient_light_energy = .36
	if ResourceLoader.exists("res://scripts/reflections.gd") and arg("reflect","1") == "1":
		Reflections.apply(e,"interior" if light == "temple" else "desert")
	env.environment = e
	scene.add_child(env)
	var who: Array = Array(arg("only",",".join(ALL)).split(",",false))
	var spacing = float(arg("spacing","1.35"))
	if light == "temple":
		# Torches on the wall behind and to either side, as in the halls.
		for i in range(-1,int(ceil(who.size()*.5))+1):
			var torch = OmniLight3D.new()
			torch.light_color = Color(1.0,.62,.32)
			torch.light_energy = 2.2
			torch.omni_range = 7.0
			torch.position = Vector3(i*spacing*2.0-(who.size()-1)*spacing*.5+spacing*.5,2.3,1.8 if i % 2 == 0 else -1.6)
			scene.add_child(torch)
	else:
		var sun = DirectionalLight3D.new()
		sun.light_color = Color(1.0,.95,.88)
		sun.light_energy = .8
		sun.shadow_enabled = true
		scene.add_child(sun)
		sun.look_at_from_position(Vector3(.6,.75,.55).normalized()*100.0,Vector3.ZERO)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new(); plane.size = Vector2(60,30)
	ground.mesh = plane
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(.55,.47,.36) if light != "temple" else Color(.42,.40,.38)
	floor_material.roughness = 1.0
	ground.material_override = floor_material
	scene.add_child(ground)
	var yaw = float(arg("yaw","0.4"))
	for i in who.size():
		var stand = Node3D.new()
		scene.add_child(stand)
		stand.position = Vector3((i-(who.size()-1)*.5)*spacing,0,0)
		stand.rotation.y = yaw
		var body = figure(stand,who[i])
		if body.has_method("advance"):
			for f in 30: body.advance(.016)
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = float(arg("size",str(maxf(who.size()*spacing+.6,2.4))))
	var height = float(arg("height","1.0"))
	if arg("view","front") == "game":
		var line: Vector3 = Overworld.VIEW.normalized()
		camera.look_at_from_position(Vector3(0,height,0)+line*40.0,Vector3(0,height,0))
	else:
		camera.look_at_from_position(Vector3(0,height+.35,9),Vector3(0,height,0))
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cast-%s.png" % arg("out","preview"))
	print("CAST_DONE")
	quit(0)
