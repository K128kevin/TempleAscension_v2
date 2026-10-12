extends SceneTree
## Renders the townspeople as the town dresses them, for judging how they
## look: a row of figures, each in the clip and moment asked for, seen from
## the front, the side or the back.
##   Godot --path . --resolution 1600x900 --script tools/preview_folk.gd --
##     [--only=selene,anya,starved_man,starved_woman,man,woman,boy,girl]
##     [--clip=Idle|Walk|...] [--phase=.25] (of the clip's length)
##     [--view=front|side|back|quarter] (or --views=front,side,... one to
##     each figure in turn) [--size=] the picture's width in
##     metres [--height=1.0] its centre [--x=0] [--spacing=1.0] [--out=name]
## The picture goes to test-results/folk-<out>.png.
const Person = preload("res://scripts/townsperson.gd")
const Reflections = preload("res://scripts/reflections.gd")
const LOOKS = {
	"selene":{"who":"woman","garment":"Gown","under":"Blouse","cloth":Color(.30,.34,.30),"under_cloth":Color(.86,.83,.76),"wear":.12,
		"hair":"Hair_Buns","hair_colour":Color(.24,.15,.08),"skin":"light","tone":Color(.98,.9,.82),"belt":Color(.35,.24,.15),"size":.95,"seed":.43,
		"apron":Color(.8,.76,.66)},
	"anya":{"who":"woman","garment":"Dress","under":"Blouse","cloth":Color(.36,.24,.15),"under_cloth":Color(.92,.9,.85),"wear":.06,
		"hair":"Hair_BuzzedFemale","braid":true,"hair_colour":Color(.06,.045,.035),"skin":"light","tone":Color(1.0,.95,.9),"size":.97,"seed":.11},
	"starved_man":{"who":"man","garment":"Sack","cloth":Color(.42,.33,.25),"wear":.95,"weave":"hessian","hair":"Hair_Buzzed","beard":true,
		"hair_colour":Color(.2,.14,.09),"skin":"dark","dirt":.95,"size":.98,"seed":.3,"gaunt":1.0},
	"starved_man2":{"who":"man","garment":"Tunic","cloth":Color(.30,.29,.27),"wear":.88,"weave":"hessian","hair":"","beard":true,
		"hair_colour":Color(.42,.41,.4),"skin":"light","tone":Color(1.0,.93,.86),"dirt":.87,"size":1.0,"seed":.6,"gaunt":1.0},
	"starved_woman":{"who":"woman","garment":"Shift","cloth":Color(.42,.33,.25),"wear":.92,"weave":"hessian","hair":"Hair_Buns",
		"hair_colour":Color(.13,.08,.05),"skin":"dark","dirt":.9,"size":.97,"seed":.5,"gaunt":1.0},
	"starved_woman2":{"who":"woman","garment":"Shift","cloth":Color(.52,.50,.47),"wear":.9,"weave":"hessian","hair":"Hair_Long",
		"hair_colour":Color(.26,.2,.14),"skin":"light","tone":Color(1.0,.93,.86),"dirt":.9,"size":.95,"seed":.8,"gaunt":1.0,"belt":Color(.42,.36,.26)},
	"man":{"who":"man","garment":"Tunic","cloth":Color(.30,.29,.27),"wear":.2,"hair":"Hair_SimpleParted","beard":true,"hair_colour":Color(.13,.08,.05),
		"belt":Color(.3,.2,.12),"skin":"light","tone":Color(1.0,.93,.86),"dirt":.12,"size":1.0,"seed":.2},
	"woman":{"who":"woman","garment":"Gown","cloth":Color(.74,.68,.56),"wear":.15,"hair":"Hair_Long","hair_colour":Color(.2,.14,.09),
		"belt":Color(.3,.2,.12),"skin":"light","tone":Color(1.0,.93,.86),"dirt":.06,"size":.97,"seed":.9},
	"boy":{"who":"man","garment":"Sack","cloth":Color(.60,.52,.40),"wear":.92,"weave":"hessian","hair":"Hair_SimpleParted","hair_colour":Color(.07,.05,.04),
		"skin":"light","dirt":.85,"size":.6,"child":true,"seed":.15},
	"girl":{"who":"woman","garment":"Shift","cloth":Color(.52,.50,.47),"wear":.85,"hair":"Hair_Long","hair_colour":Color(.13,.08,.05),
		"skin":"dark","dirt":.85,"size":.57,"child":true,"seed":.35},
	"zeno":{"who":"man","garment":"Tunic","cloth":Color(.64,.58,.46),"wear":.22,"hair":"Hair_Buzzed","beard":true,"hair_colour":Color(.18,.12,.08),
		"skin":"light","tone":Color(1.0,.9,.8),"belt":Color(.35,.24,.15),"shoes":Color(.3,.21,.13),"size":1.0,"seed":.58,"apron":Color(.8,.76,.66)},
}
const VIEWS = {"front":0.0,"quarter":.6,"side":PI*.5,"back":PI}

func _initialize(): call_deferred("capture")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback

func capture():
	var scene = Node3D.new()
	root.add_child(scene)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.80,.66,.46)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.70,.78,.96)
	e.ambient_light_energy = .45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 1.3
	Reflections.apply(e,"desert")
	env.environment = e
	scene.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0,.95,.88)
	sun.light_energy = .9
	sun.shadow_enabled = true
	scene.add_child(sun)
	sun.look_at_from_position(Vector3(.5,.8,.7).normalized()*100.0,Vector3.ZERO)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new(); plane.size = Vector2(60,30)
	ground.mesh = plane
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(.55,.47,.36)
	floor_material.roughness = 1.0
	ground.material_override = floor_material
	scene.add_child(ground)
	var who: Array = Array(arg("only","selene,anya,starved_man,starved_woman,man,woman,boy,girl").split(",",false))
	var spacing = float(arg("spacing","1.0"))
	var clip = arg("clip","Idle")
	var phase = float(arg("phase","0.25"))
	var view = arg("view","front")
	var yaw: float = VIEWS[view] if VIEWS.has(view) else float(view)
	for i in who.size():
		var stand = Node3D.new()
		scene.add_child(stand)
		stand.position = Vector3((i-(who.size()-1)*.5)*spacing,0,0)
		stand.rotation.y = yaw
		var views: Array = Array(arg("views","").split(",",false))
		if not views.is_empty(): stand.rotation.y = VIEWS[views[i % views.size()]]
		var person = Person.new()
		stand.add_child(person)
		person.setup(LOOKS[who[i]])
		# (--hide=Gown,... leaves those parts out, to see what is under them.)
		for part in arg("hide","").split(",",false):
			for mesh in person.skeleton.find_children(part,"MeshInstance3D",true,false): mesh.visible = false
		person.animator.play(clip,0.0)
		person.animator.seek(person.animator.get_animation(clip).length*phase,true)
		person.animator.pause()
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = float(arg("size",str(maxf(who.size()*spacing+.4,1.6))))
	var height = float(arg("height","1.0"))
	var x = float(arg("x","0"))
	camera.look_at_from_position(Vector3(x,height+float(arg("lift",".3")),9),Vector3(x,height,0))
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/folk-%s.png" % arg("out","preview"))
	print("FOLK_DONE")
	quit(0)
