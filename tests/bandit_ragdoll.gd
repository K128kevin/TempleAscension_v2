extends SceneTree
const Visual = preload("res://scripts/visual.gd")
## A slain bandit falls limp on actual physics frames (scripts/ragdoll.gd),
## and bandits bleed when struck. With --render-ragdoll the fall is drawn to
## test-results/bandit-ragdoll-*.png.
const Data = preload("res://scripts/data.gd")
const Temple = preload("res://scripts/temple.gd")
const Actor = preload("res://scripts/actor.gd")
const Fragment = preload("res://scripts/stone_fragment.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")
const STEP = 1.0/60
var game
var origin: Vector3
var passed: Array = []
var failed: Array = []
var serial = 0
var render = false

func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func frames(count: int):
	for i in count:
		await physics_frame
		if game.mode == "playing":
			for enemy in game.enemies: enemy.tick(STEP)
		await process_frame

func victim(at: Vector3, kind: String = "bandit"):
	serial += 1
	var enemy = game.spawn_enemy(kind,"ragdoll:%d" % serial,at)
	enemy.puppet = true
	enemy.awake = true
	return enemy

func blood() -> Array:
	return game.world.get_children().filter(func(n): return n is CPUParticles3D and not n.is_queued_for_deletion())

# The bones as the skeleton last showed them, its modifiers (his fallen
# bodies) applied: between updates they read back as the bare animation.
const WATCHED = ["pelvis","Head","hand_l","thigh_l","thigh_r","calf_l","calf_r","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r"]
var shown: Dictionary = {}
func watch(visual) -> void:
	var s: Skeleton3D = visual.skeleton
	var read = func():
		for bone in WATCHED: shown[[s,bone]] = s.get_bone_global_pose(s.find_bone(bone))
	s.skeleton_updated.connect(read)
	read.call()

func bone_at(visual, bone: String) -> Vector3:
	return visual.skeleton.global_transform*shown[[visual.skeleton,bone]].origin

# How far a knee or elbow is folded, in degrees: negative is bent backward.
func fold(visual, upper: String, lower: String) -> float:
	var s: Skeleton3D = visual.skeleton
	var a: Basis = shown[[s,upper]].basis.orthonormalized()
	var b: Basis = shown[[s,lower]].basis.orthonormalized()
	var rest: Basis = s.get_bone_global_rest(s.find_bone(upper)).basis.orthonormalized().inverse()*s.get_bone_global_rest(s.find_bone(lower)).basis.orthonormalized()
	var turn: Basis = rest.inverse()*(a.inverse()*b)
	var along: Vector3 = turn*Vector3.UP
	return rad_to_deg(atan2(along.z,along.y))

func snapshot(label: String):
	if not render: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/bandit-ragdoll-"+label+".png")

func test():
	render = "--render-ragdoll" in OS.get_cmdline_user_args()
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/bandit-ragdoll-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_run("warrior")
	game.load_floor()
	game.remove_child(game.world)
	game.world.queue_free()
	for list in [game.enemies,game.effects,game.pickups]: list.clear()
	game.world = Temple.new()
	game.add_child(game.world)
	game.world.setup(Temple.Layout.PLAYGROUND,1)
	origin = game.world.spawn
	game.player = Actor.new()
	game.world.add_child(game.player)
	game.player.setup(game,"player","hero",origin)
	game.player.face(origin+Vector3.FORWARD)
	if render:
		game.hud.root.visible = false
		game.world.zoom = 7
		game.world.follow(origin+Vector3.FORWARD*2,1)
	game.world.place("wall",origin+Vector3(0,0,-5),Vector3(7,3.2,.28),preload("res://scripts/assets.gd").material("stone"))

	# A wound that does not kill: he bleeds a little, and stands.
	var hurt = victim(origin+Vector3(2.5,0,-1.8))
	await frames(10)
	hurt.hit(1.0)
	check(not hurt.dead and hurt.visual.ragdoll == null,"A bandit who survives a blow stays on his feet")
	check(blood().size() == 1,"A struck bandit bleeds")
	var light: int = blood()[0].amount
	check(blood()[0].direction.dot((hurt.position-game.player.position).normalized()) > .5,"The blood is thrown away from the blow")
	var statue = victim(origin+Vector3(-2.5,0,-1.8),"centurion")
	statue.hit(1.0)
	check(blood().size() == 1,"Stone does not bleed")
	await frames(11)
	await snapshot("bleeding")
	await frames(49)
	check(blood().is_empty(),"The spatter is gone within the second")

	# Slain in mid-stride, knees and elbows bent.
	var bandit = victim(origin+Vector3.FORWARD*1.8)
	watch(bandit.visual)
	bandit.visual.play("Run")
	bandit.visual.animator.seek(.3,true)
	await frames(2)
	var stood: Vector3 = bone_at(bandit.visual,"Head")
	var hand: Vector3 = bone_at(bandit.visual,"hand_l")
	bandit.hit(100000,"physical",0.0,Fragment.impact(Vector3.FORWARD))
	check(bandit.dead and bandit.visual.dead and bandit.visual.state == "Death","A lethal blow kills him")
	check(bandit.visual.ragdoll != null and not bandit.visual.animator.is_playing(),"He falls limp, not through a clip")
	check(blood().size() == 1 and blood()[0].amount > light,"The killing blow draws more blood")
	var bodies: Array = Ragdoll.bodies(bandit.visual.ragdoll)
	check(bodies.size() == Ragdoll.PARTS.size() and bodies.all(func(b): return b is PhysicalBone3D),"Each part of him is a physical body")
	await frames(2)
	check(bandit.visual.ragdoll.is_simulating_physics(),"His bodies are let go")
	check(bone_at(bandit.visual,"Head").distance_to(stood) < .2 and bone_at(bandit.visual,"hand_l").distance_to(hand) < .25,"He falls from the pose he died in, not his skeleton's rest")
	var sum = Vector3.ZERO
	for b in bodies: sum += b.linear_velocity
	print("RAGDOLL_LAUNCH ",sum/bodies.size())
	check((sum/bodies.size()).dot(Vector3.FORWARD) > .5,"The blow throws him away from the attacker")
	var at: Vector3 = bodies[0].global_position
	bandit.position += Vector3.RIGHT*3
	check(bodies[0].global_position == at,"Moving the corpse's unit cannot drag his body")
	bandit.position -= Vector3.RIGHT*3
	var folds = {"knee":[INF,-INF],"elbow":[INF,-INF]}
	var lowest = INF
	for i in 210:
		await frames(1)
		for side in ["l","r"]:
			for joint in [["knee","thigh_","calf_"],["elbow","upperarm_","lowerarm_"]]:
				var angle = fold(bandit.visual,joint[1]+side,joint[2]+side)
				folds[joint[0]] = [minf(folds[joint[0]][0],angle),maxf(folds[joint[0]][1],angle)]
		for b in bodies: lowest = minf(lowest,b.global_position.y)
		if i == 12: await snapshot("falling")
	print("RAGDOLL_FOLDS ",folds," lowest ",lowest)
	check(folds.knee[0] > -15 and folds.knee[1] < 150,"His knees fold only the way knees do (%d to %d degrees)" % [folds.knee[0],folds.knee[1]])
	check(folds.elbow[0] > -15 and folds.elbow[1] < 155,"His elbows fold only the way elbows do (%d to %d degrees)" % [folds.elbow[0],folds.elbow[1]])
	check(lowest > -.05 and bodies.all(func(b): return b.global_position.y > b.get_child(0).shape.radius-.03),"No part of him sinks through the floor")
	var head: Vector3 = bone_at(bandit.visual,"Head")
	var pelvis: Vector3 = bone_at(bandit.visual,"pelvis")
	print("RAGDOLL_LIES head ",head," pelvis ",pelvis)
	check(head.y < .45 and pelvis.y < .4,"He comes to lie on the ground")
	check((pelvis-bandit.position).dot(Vector3.FORWARD) > .15 and pelvis.distance_to(bandit.position) < 3.3,"He lies a little way off, the way he was struck")
	print("RAGDOLL_REST ",bodies.map(func(b): return snappedf(b.linear_velocity.length(),.01)))
	check(bodies.all(func(b): return b.linear_velocity.length() < .3),"He comes to rest")
	var body_pelvis = bodies.filter(func(b): return b.bone_name == "pelvis")[0]
	check((body_pelvis.global_transform*body_pelvis.body_offset.affine_inverse()).origin.distance_to(pelvis) < .02,"His skeleton lies where his bodies do")
	await snapshot("fallen")
	game.pause_game()
	var lying = bodies.map(func(b): return b.global_transform)
	bodies[3].linear_velocity = Vector3.UP*3
	await frames(20)
	check(bodies.map(func(b): return b.global_transform) == lying,"Pausing holds the body still")
	game.resume_game()

	# Thrown by a blast; then, once the body is gone, its physics are too.
	var thrown = victim(origin+Vector3(-2,0,-3),"bandit_archer")
	thrown.hit(100000,"physical",0.0,Fragment.impact(Vector3.FORWARD,true))
	var flung: Array = Ragdoll.bodies(thrown.visual.ragdoll)
	await frames(20)
	await snapshot("blast")
	var carried = Vector3.ZERO
	for b in flung: carried += (b.global_position-thrown.position)/flung.size()
	print("RAGDOLL_BLAST ",carried)
	check(carried.dot(Vector3.FORWARD) > 1.0 and carried.y > .9,"A blast hurls him off his feet")
	# The wall stands 2 metres behind him.
	var wall: float = origin.z-5.0
	var rebound = false
	var nearest = INF
	for i in 100:
		await frames(1)
		var mean = Vector3.ZERO
		for b in flung:
			mean += b.linear_velocity/flung.size()
			nearest = minf(nearest,b.global_position.z-wall)
		if mean.z > .2: rebound = true
		if i == 12: await snapshot("rebound")
	print("RAGDOLL_WALL nearest ",nearest," rebound ",rebound)
	check(rebound,"Hurled into a wall, he bounces off it")
	check(nearest > 0.0,"No part of him passes through the wall")
	await frames(8*60-310)
	check(not bandit.visible and bandit.visual.ragdoll == null and bodies.all(func(b): return not is_instance_valid(b) or b.is_queued_for_deletion()),"A body that has gone leaves no physics behind")
	await frames(210)
	check(flung.all(func(b): return not is_instance_valid(b)),"Nor does the thrown one")

	# A spell draws no blood; fire or lightning that kills leaves him burnt
	# black, smoking as he falls. Frost, or a blade, does not.
	check(not bandit.visual.scorched,"A blade's kill is not burnt")
	var burnt = victim(origin+Vector3(-1.5,0,-1.2))
	var frozen = victim(origin+Vector3(1.5,0,-1.2))
	await frames(10)
	game.skills.spell_striking = true
	burnt.hit(1.0,"fire")
	check(not burnt.dead and blood().is_empty(),"A spell's hit draws no blood")
	burnt.hit(100000,"lightning",0.0,Fragment.impact(Vector3.FORWARD))
	frozen.hit(100000,"frost",0.0,Fragment.impact(Vector3.FORWARD))
	game.skills.spell_striking = false
	check(burnt.dead and frozen.dead and blood().is_empty(),"Nor does a spell's killing blow")
	check(burnt.visual.scorched and burnt.visual.skin_meshes.all(func(m): return not is_instance_valid(m) or (m.material_overlay is ShaderMaterial and m.material_overlay.shader.resource_path.ends_with("charred.gdshader"))),"Killed by lightning, every part of him is charred")
	check(not frozen.visual.scorched and frozen.visual.skin_meshes.all(func(m): return not is_instance_valid(m) or m.material_overlay == null),"Killed by frost, he is not")
	await frames(40)
	check(is_equal_approx(float(burnt.visual.skin_meshes[0].material_overlay.get_shader_parameter("amount")),1.0),"The char takes him fully within moments")
	check(is_instance_valid(burnt.visual.smoke) and burnt.visual.smoke.emitting and burnt.visual.smoke.get_parent() is BoneAttachment3D,"Smoke rises off the body")
	await snapshot("scorched")
	# A crowd burnt down together: all charred, but only so many smoking.
	var crowd: Array = []
	for i in 14: crowd.append(victim(origin+Vector3(-6+i,0,4)))
	await frames(4)
	game.skills.spell_striking = true
	for one in crowd: one.hit(100000,"fire")
	game.skills.spell_striking = false
	var smokers: int = crowd.filter(func(b): return is_instance_valid(b.visual.smoke)).size()
	check(crowd.all(func(b): return b.visual.scorched) and smokers > 0 and Visual.smoking <= Visual.SMOKE_LIMIT,"Fourteen burnt at once are all charred; no more than %d smoke (%d)" % [Visual.SMOKE_LIMIT,smokers])
	await frames(int((Visual.SMOKE_TIME+Visual.SMOKE_LIFE)*60)+30)
	check(Visual.smoking == 0 and crowd.all(func(b): return not is_instance_valid(b.visual.smoke)),"Their smoke clears, and its emitters with it")

	# Dying of a curse there is no blow: he crumples where he stands.
	var cursed = victim(origin+Vector3(2,0,-3))
	watch(cursed.visual)
	cursed.die()
	await frames(120)
	var fell: Vector3 = bone_at(cursed.visual,"pelvis")
	check(fell.y < .45 and Vector2(fell.x-cursed.position.x,fell.z-cursed.position.z).length() < .9,"With no blow he crumples where he stood")
	cursed.playground_revive()
	check(not cursed.dead and cursed.visual.ragdoll == null,"Revived, he stands whole")
	game.hurt_player(100000,"physical",cursed)
	check(game.player.visual.ragdoll == null,"The hero dies as he always did")
	FileAccess.open("res://test-results/bandit-ragdoll.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("BANDIT_RAGDOLL ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
