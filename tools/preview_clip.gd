extends SceneTree
## A contact sheet of one of the hero's clips, for judging an animation by eye:
## the clip's poses in a row, seen from the side (top) and from the front
## quarter (bottom), the weapon in the right hand as the game holds it.
##
##   Godot --path . --script tools/preview_clip.gd -- --clip=SkillCleave
##     [--glb=/abs/path/warrior.glb]   the model (default: the game's own)
##     [--weapon=sword --size=.19,1.3,.09 --grip=.22]   the prop, its size, and
##         how far up from its butt the right fist holds it
##     [--item=bronze_hatchet]   or one of the game's items, held as the game
##         holds it (scripts/items.gd)
##     [--offhand=-.2]   marks where the left hand should hold the haft: this
##         many metres along the weapon from the right fist (negative: toward
##         the butt); the worst gap between it and the left palm is printed
##     [--shield=1]      the round shield on the left forearm
##     [--phases=0,.2,.4,.52,.7,1]  or  [--frames=8]
##     [--out=name]      test-results/clip-<name>.png
const Art = preload("res://scripts/assets.gd")
const CELL = Vector2i(320,330)
func _initialize(): call_deferred("capture")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback
func capture():
	var clip = arg("clip","Idle")
	var port = SubViewport.new()
	port.size = CELL
	port.own_world_3d = true
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var scene = Node3D.new()
	port.add_child(scene)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.2,.21,.23)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .75
	scene.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-140,0)
	sun.light_energy = 1.2
	scene.add_child(sun)
	# A ground line to judge the feet and the weapon's point against.
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(12,12)
	ground.mesh = plane
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(.3,.3,.32)
	ground.material_override = floor_mat
	scene.add_child(ground)
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(arg("view","3.6"))
	var rig: Node3D
	var path = arg("glb","")
	if path.is_empty(): rig = load("res://assets/models/character/warrior.glb").instantiate()
	else:
		var document = GLTFDocument.new()
		var state = GLTFState.new()
		var error = document.append_from_file(path,state)
		if error != OK:
			push_error("Could not read %s" % path)
			quit(1)
			return
		rig = document.generate_scene(state)
	scene.add_child(rig)
	for mesh in rig.find_children("*","MeshInstance3D",true,false):
		var n = String(mesh.name)
		if n.begins_with("Ranger") or n.begins_with("Wizard") or "Boots" in n or "Hair" in n: mesh.visible = false
	var animator: AnimationPlayer = rig.find_children("*","AnimationPlayer",true,false)[0]
	var skeleton: Skeleton3D = rig.find_children("*","Skeleton3D",true,false)[0]
	var found = ""
	for name in animator.get_animation_list():
		if name == clip or name.ends_with("/"+clip): found = name
	if found.is_empty():
		push_error("No clip %s. Clips: %s" % [clip,animator.get_animation_list()])
		quit(1)
		return
	var weapon = arg("weapon","sword")
	var hand = BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	skeleton.add_child(hand)
	var grip = float(arg("grip","0.22"))
	var marker: MeshInstance3D
	if weapon != "none":
		var size_text = arg("size",".19,1.3,.09").split(",")
		var item: Node3D
		if arg("item","") != "":
			var look: Dictionary = load("res://scripts/items.gd").ALL[arg("item","")].look
			item = Art.held_model(look)
			grip = look.grip
		else: item = Art.model(weapon,Vector3(float(size_text[0]),float(size_text[1]),float(size_text[2])))
		hand.add_child(item)
		# As the game holds it (scripts/visual.gd equip): the model's +Y along
		# the hand's +Z, its butt `grip` metres behind the fist.
		item.rotation.x = PI/2
		item.position = Vector3(0,.075,-grip)
	var offhand = arg("offhand","")
	if not offhand.is_empty():
		marker = MeshInstance3D.new()
		var ball = SphereMesh.new()
		ball.radius = .035; ball.height = .07
		marker.mesh = ball
		var red = StandardMaterial3D.new()
		red.albedo_color = Color(1,.1,.1)
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		red.no_depth_test = true
		marker.material_override = red
		hand.add_child(marker)
		marker.position = Vector3(0,.075,float(offhand))
	if arg("shield","") != "":
		var fore = BoneAttachment3D.new()
		fore.bone_name = "lowerarm_l"
		skeleton.add_child(fore)
		var shield = Art.model("shield",Vector3(.66,.66,.12),Art.gladiator_shield())
		fore.add_child(shield)
		shield.rotation.y = PI
		shield.position = Vector3(0,.14,-.135)-shield.basis*Vector3(0,.5,0)
	var phases: Array = []
	if arg("phases","") != "":
		for p in arg("phases","").split(","): phases.append(float(p))
	else:
		var count = int(arg("frames","8"))
		for i in count: phases.append(i/float(count-1))
	var length: float = animator.get_animation(found).length
	var sheet = Image.create(CELL.x*phases.size(),CELL.y*2,false,Image.FORMAT_RGBA8)
	var worst = 0.0
	var worst_at = 0.0
	# (The rig faces +Z.)
	var views = [[Vector3(-9,1.0,.3),"side"],[Vector3(5,2.4,8),"front"]]
	for row in 2:
		camera.position = views[row][0]
		camera.look_at(Vector3(0,.95,.3))
		for i in phases.size():
			animator.play(found,0)
			# (Held still at that moment while its picture is taken.)
			animator.speed_scale = 0.0
			animator.seek(length*phases[i],true)
			animator.advance(0)
			skeleton.force_update_all_bone_transforms()
			if marker != null and row == 0:
				var palm: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))*Vector3(0,.075,0)
				var gap = palm.distance_to(marker.global_position)
				if gap > worst: worst = gap; worst_at = phases[i]
			for f in 2: await process_frame
			await RenderingServer.frame_post_draw
			var shot: Image = port.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot,Rect2i(Vector2i.ZERO,CELL),Vector2i(CELL.x*i,CELL.y*row))
	if marker != null:
		# Finer than the pictures: every thirtieth of a second of the clip.
		var steps = int(length*30)
		worst = 0.0
		for f in steps+1:
			animator.seek(length*f/float(steps),true)
			animator.advance(0)
			skeleton.force_update_all_bone_transforms()
			var palm: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))*Vector3(0,.075,0)
			var gap = palm.distance_to(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*marker.position)
			if gap > worst: worst = gap; worst_at = f/float(steps)
		print("OFFHAND_GAP worst %.3f m at %.2f of %s" % [worst,worst_at,clip])
	var out = "res://test-results/clip-%s.png" % arg("out",clip)
	sheet.save_png(out)
	print("CLIP_SHEET ",out," ",length,"s phases ",phases)
	quit(0)
