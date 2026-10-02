extends SceneTree
const Visual = preload("res://scripts/visual.gd")
const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/assets.gd")
const Motion = preload("res://scripts/combat_animation.gd")
var passed = 0
var failures: Array = []
var actors: Array = []
var render = false
func _initialize(): call_deferred("verify")
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failures.append(message); push_error(message)
func paw_bone(lion, name: String) -> int:
	return lion.skeleton.find_bone(name)
func frames(n: int):
	for i in n: await process_frame
func snapshot(name: String):
	if not render: return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/enemies-"+name+".png")
# The statue stone, or a statue's own copy of it (statues with a cape carry
# their legs' positions for the cape's cloth).
func is_stone(material, skinned: bool) -> bool:
	var stone = Art.statue_material(skinned)
	return material == stone or (material is ShaderMaterial and material.shader == stone.shader and material.get_shader_parameter("rest_pose") == skinned)

func verify():
	render = "--render-enemies" in OS.get_cmdline_user_args()
	var scene = Node3D.new(); root.add_child(scene)
	var environment = WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.035,.04,.05)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.8,.8,.8)
	environment.environment.ambient_light_energy=.35
	scene.add_child(environment)
	var light = DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-25,0); light.light_energy=.8; scene.add_child(light)
	var camera = Camera3D.new(); scene.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect=Camera3D.KEEP_WIDTH; camera.size=8.4
	camera.position=Vector3(0,2.8,9); camera.look_at(Vector3(0,1,0))
	for index in 4:
		var kind = ["gladiator","centurion","archer","wizard"][index]
		var config: Dictionary = Data.ENEMIES[kind]
		var actor = Visual.new(); scene.add_child(actor)
		actor.position.x=index*2.1-3.15
		actor.setup(true,config.color,config.weapon,1,kind)
		actors.append(actor)
		var mesh = actor.skin_meshes[0]
		check(mesh.name=="Stone"+kind.capitalize(),"Correct imported outfit: "+kind)
		# Animated bodies use the stone laid out from their rest pose.
		check(is_stone(mesh.material_override,true),"Body and outfit share gray cracked stone: "+kind)
		# Carved in the likeness of its class's hero: the body's own relief and
		# that hero's kit, cut into the stone.
		var kit = Visual.STATUE_KITS[kind]
		var carving = mesh.material_override.get_shader_parameter("kit_height")
		check(mesh.material_override.get_shader_parameter("body_detail") == 1.0 and carving != null and carving.resource_path.ends_with("hero_kit_%s_height.png" % kit),"Statue carved with the %s's kit: %s" % [kit,kind])
		check(actor.skin_meshes.size()==1 and mesh.skin.get_bind_count()>50,"Outfit remains one skinned surface: "+kind)
		for clip in ["Run","Death","SwordSwing","SpearStab","BowShot","Cast","Hit","HitHead","HitStagger","HitKnockdown"]:
			check(actor.clips.has(clip),"Outfit retains animation "+clip+": "+kind)
		for gear in actor.find_children("*","MeshInstance3D",true,false):
			check(is_stone(gear.material_override,gear.skin != null),"Worn/held item uses statue stone: "+kind+"/"+gear.name)
		var label = Label3D.new(); label.text=kind.capitalize(); label.position=Vector3(actor.position.x,-.2,0); label.font_size=40; label.pixel_size=.007; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; scene.add_child(label)
	await snapshot("idle")
	for actor in actors:
		var before: Transform3D = actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("hand_r"))
		actor.state="Run"; actor.animator.play(actor.clips.Run,0); actor.animator.seek(.15,true); actor.animator.advance(0); actor.animator.pause(); actor.skeleton.force_update_all_bone_transforms(); actor.align_weapon()
		check(not before.is_equal_approx(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("hand_r"))),"Imported run animation changes the bone pose")
	await snapshot("run")
	for i in 4:
		var actor = actors[i]; actor.state=["SwordSwing","SpearStab","BowShot","Cast"][i]; actor.animator.play(actor.clips[actor.state],0); actor.animator.seek(actor.animator.current_animation_length*.45,true); actor.animator.advance(0); actor.animator.pause(); actor.skeleton.force_update_all_bone_transforms(); actor.align_weapon()
	await snapshot("attack")
	for actor in actors:
		actor.state=actor.idle_action(); actor.animator.play(actor.clips[actor.state],0); actor.animator.seek(0,true); actor.animator.advance(0); actor.animator.pause(); actor.rotation.y=PI; actor.skeleton.force_update_all_bone_transforms(); actor.align_weapon()
	await snapshot("back")
	# The Crowned Statue wears close-fitted plate, bareheaded under its crown.
	var boss = Visual.new(); scene.add_child(boss)
	boss.setup(true,Data.ENEMIES.boss.color,Data.ENEMIES.boss.weapon,2.0,"boss"); boss.crown()
	check(boss.skin_meshes.size()==1 and boss.skin_meshes[0].name=="StoneBoss" and boss.skin_meshes[0].skin.get_bind_count()>50,"The boss wears its plate as one skinned surface")
	check(boss.weapon_kind=="sword" and boss.shield_item==null,"The boss wields a great sword and no shield")
	boss.queue_free()
	# The lion is a lion: its own four-legged figure, with its carved face.
	var lion = Visual.new(); scene.add_child(lion)
	lion.setup(true,Data.ENEMIES.lion.color,Data.ENEMIES.lion.weapon,Data.ENEMIES.lion.size,"lion")
	check(lion.quadruped and lion.skeleton.find_bone("forepaw_r")>=0 and lion.skeleton.find_bone("hand_r")<0,"The lion stands on four legs, on a skeleton of its own")
	check(lion.skin_meshes[0].material_override.shader==Art.statue_material().shader and lion.skin_meshes[0].material_override.get_shader_parameter("body_normal").resource_path.ends_with("lion_normal.png"),"It is carved in the statues' stone, its sculpted detail in relief")
	var lion_clips = ["Idle","Run","Attack","Hit","HitHead","HitStagger"]
	check(lion_clips.all(func(c): return lion.clips.has(c)),"It has its own stance, trot, swipe and flinches")
	# A trot: the diagonal pairs of paws step in turn.
	var trot: Animation = lion.animator.get_animation(lion.clips.Run)
	var pairs_alternate = true
	for half in 2:
		lion.animator.play(lion.clips.Run)
		lion.animator.seek(trot.length*(.2+.5*half),true)
		lion.skeleton.force_update_all_bone_transforms()
		var up = {}
		for paw in ["foretoes_l","hindtoes_r","foretoes_r","hindtoes_l"]: up[paw] = lion.skeleton.get_bone_global_pose(paw_bone(lion,paw)).origin.y-lion.skeleton.get_bone_global_rest(paw_bone(lion,paw)).origin.y
		var down = ["foretoes_l","hindtoes_r"] if half==0 else ["foretoes_r","hindtoes_l"]
		var raised = ["foretoes_r","hindtoes_l"] if half==0 else ["foretoes_l","hindtoes_r"]
		if not (down.all(func(paw): return up[paw]<.03) and raised.all(func(paw): return up[paw]>.08)): pairs_alternate = false
	check(pairs_alternate,"It trots: each fore paw steps with the opposite hind paw, the two pairs in turn")
	check(lion.planter != null and lion.planter.feet.size()==4 and lion.planter.feet.all(func(f): return f.thigh>=0 and f.calf>=0 and f.foot>=0),"Its four paws are planted on the ground, to step when it is pushed")
	check(Motion.LION_SWIPE.clip=="Attack" and lion.animator.get_animation(lion.clips.Attack).length>.8,"Its swipe is a full blow: rearing, then raking a forepaw across")
	var lion_box = AABB()
	for mesh in lion.skin_meshes: lion_box = lion_box.merge(mesh.get_aabb()) if lion_box.has_volume() else mesh.get_aabb()
	check(lion_box.size.y>1.2 and lion_box.size.y<1.6 and lion_box.size.z>2.6 and lion_box.size.z<3.3,"It is the size of a living lion (%.2f m tall, %.2f m nose to tail)" % [lion_box.size.y,lion_box.size.z])
	lion.queue_free()
	print("ENEMY_VISUALS ",passed," passed; ",failures)
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
