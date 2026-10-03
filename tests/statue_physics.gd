extends SceneTree
## Exercise actual physics frames as well as the killing attack's damage path.
const Data = preload("res://scripts/data.gd")
const Temple = preload("res://scripts/temple.gd")
const Actor = preload("res://scripts/actor.gd")
const Fragment = preload("res://scripts/stone_fragment.gd")
const Art = preload("res://scripts/assets.gd")
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

func victim(at: Vector3, kind: String = "centurion"):
	serial += 1
	var enemy = game.spawn_enemy(kind,"physics:%d" % serial,at)
	enemy.puppet = true
	enemy.awake = true
	enemy.hp = .01
	return enemy

# The chips that have broken loose: the rest wait in the statue until the
# break reaches them.
func velocity(chips: Array) -> Vector3:
	var loose = chips.filter(func(chip): return not chip.held)
	var sum = Vector3.ZERO
	for chip in loose: sum += chip.linear_velocity
	return sum/maxi(1,loose.size())

func center(chips: Array) -> Vector3:
	var sum = Vector3.ZERO
	for chip in chips: sum += chip.global_position
	return sum/chips.size()

func positions(chips: Array) -> Array:
	return chips.map(func(chip): return chip.global_transform)

# Every visible rock must belong to a rigid body; a separate decorative pile
# would leave a visible mesh outside those bodies after the statue vanishes.
func physical_rocks_only(visual) -> bool:
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree(): continue
		var parent = mesh.get_parent()
		while parent != visual and not parent is RigidBody3D: parent = parent.get_parent()
		if not parent is RigidBody3D: return false
	return true

func snapshot(label: String):
	if not render: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/statue-physics-"+label+".png")

func clear():
	for enemy in game.enemies: enemy.queue_free()
	game.enemies.clear()
	game.skills.reset()
	game.player.busy = 0
	game.player.cooldown = 0
	game.player.position = origin
	game.run.energy = 100

func test():
	render = "--render-debris" in OS.get_cmdline_user_args()
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/statue-physics-save")
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
	# Leave floor around the whole burst, including stones deflected sideways
	# by the wall. Landing checks should not send them off the test plane.
	origin = game.world.spawn
	game.player = Actor.new()
	game.world.add_child(game.player)
	game.player.setup(game,"player","hero",origin)
	game.player.face(origin+Vector3.FORWARD)
	if render:
		game.hud.root.visible = false
		game.world.zoom = 11
		game.world.follow(origin,1)
	# A real temple wall, turned north/south by Temple.place().
	game.world.place("wall",origin+Vector3(4,0,0),Vector3(.28,3.2,7),Art.material("stone"))
	check(game.world.debris_collision == null,"Collision geometry is deferred until a statue dies")
	var enemy = victim(origin+Vector3.FORWARD*1.8)
	enemy.rotation.y = 1.7
	game.attack(false,enemy.position)
	game.tick_scheduled(1.0)
	var chips: Array = enemy.visual.chips.duplicate()
	check(enemy.dead and chips.size() == 36 and chips.all(func(c): return c is RigidBody3D),"A lethal normal attack creates thirty-six physical stone fragments")
	await frames(2)
	var normal_velocity = velocity(chips)
	print("NORMAL_LAUNCH ",normal_velocity)
	check(normal_velocity.dot(Vector3.FORWARD) > .6 and normal_velocity.dot(Vector3.FORWARD) < 2.4,"A normal attack gives a small push away from the attacker in world space")
	# The top ring breaks loose first; the statue gives way down to its feet.
	var top_ring: Array = chips.slice(30)
	var start = center(top_ring)
	var transforms = positions(chips)
	enemy.position += Vector3.RIGHT*3
	enemy.rotation.y += PI/2
	check(positions(chips) == transforms,"Corpse movement and facing cannot drag or rotate airborne fragments")
	await frames(24)
	check((center(top_ring)-start).dot(Vector3.FORWARD) > .2 and velocity(top_ring).y < -.5,"Gravity pulls fragments down while their hit momentum carries them backward")
	check(chips[-1].global_basis != transforms[-1].basis,"Fragments tumble during flight")
	await snapshot("normal")
	game.pause_game()
	transforms = positions(chips)
	var age: float = chips[0].age
	await frames(30)
	check(positions(chips) == transforms and chips[0].age == age,"Pausing freezes both the rocks and their cleanup timer")
	game.resume_game()
	# Plus the half second the statue takes to break apart, and the moment
	# the last of its rocks then need to fall asleep.
	await frames(270)
	check(chips.all(func(c): return c.global_position.y > 0 and c.global_position.y < .75),"All normal fragments settle on the paving or one another without sinking through it")
	check(not enemy.visual.rig.visible and physical_rocks_only(enemy.visual),"Every visible remnant is a physics body, with no static rubble pile")
	check(chips.all(func(c): return c.linear_velocity.length() < .15),"Friction settles the fragments instead of letting them slide forever")
	check(chips.any(func(c): return c.sleeping),"Settled fragments go to sleep")
	clear()
	await frames(2)
	check(chips.all(func(c): return not is_instance_valid(c)),"Removing a corpse also removes all its physics bodies")

	# These skills use the same real damage path as their timed contact jobs.
	var blast_chips: Array = []
	var blast_starts: Array[Vector3] = []
	var wall_contacts = [0]
	for skill in ["ground_slam","leap"]:
		clear()
		await frames(2)
		var targets: Array = []
		var ways: Array = [Vector3.FORWARD.rotated(Vector3.UP,-.35),Vector3.FORWARD.rotated(Vector3.UP,.35)] if skill == "ground_slam" else [Vector3.RIGHT,Vector3.LEFT]
		for way in ways: targets.append(victim(origin+way*2))
		var survivor = victim(origin+Vector3.FORWARD*2.5)
		survivor.hp = 100000
		game.skills.execute({"id":skill,"rank":1,"at":origin,"direction":Vector3.FORWARD})
		await frames(2)
		for i in targets.size():
			var pieces: Array = targets[i].visual.chips
			var motion = velocity(pieces)
			print("BLAST_LAUNCH ",skill," ",i," ",motion)
			check(targets[i].dead and motion.dot(ways[i]) > normal_velocity.length()*2.5 and motion.y > 2.5,"%s blasts fragments strongly outward and upward, target %d" % [skill,i])
			blast_starts.append(center(pieces))
		check(not survivor.dead and survivor.visual.chips.is_empty(),"%s creates debris only on lethal hits" % skill)
		if skill == "leap":
			blast_chips = targets[0].visual.chips.duplicate()
			for chip in blast_chips:
				chip.contact_monitor = true
				chip.max_contacts_reported = 4
				chip.body_entered.connect(func(body):
					if body == game.world.debris_collision: wall_contacts[0] += 1)
		await frames(30)
		await snapshot(skill)
		for i in targets.size():
			check((center(targets[i].visual.chips)-blast_starts[-2+i]).dot(ways[i]) > (1.3 if skill == "leap" and i == 0 else 2.0),"%s sends fragments visibly farther than a basic hit, target %d" % [skill,i])
	# Leap's right-hand target throws its rocks into the real wall at x=4.
	check(wall_contacts[0] > 0 and blast_chips.all(func(c): return c.global_position.x < origin.x+4),"Blasted rocks collide with the temple wall rather than passing through it")
	await frames(180)
	check(blast_chips.all(func(c): return c.global_position.y > 0 and c.global_position.y < .75),"The larger blast still settles onto the floor")
	await frames(300)
	check(blast_chips.all(func(c): return not is_instance_valid(c)),"Fragments expire after eight seconds of active physics")
	clear()
	await frames(2)

	# A shot keeps its flight direction even if the hero moves after firing.
	var archer_target = victim(origin+Vector3.FORWARD*1.8)
	game.projectile(origin,archer_target.position,10000,true,"arrow")
	game.player.position = origin+Vector3.RIGHT*5
	game.tick_projectiles(.1)
	await frames(2)
	check(archer_target.dead and velocity(archer_target.visual.chips).dot(Vector3.FORWARD) > .8,"A projectile pushes fragments along its flight, independent of the shooter's new position")
	clear()
	await frames(2)
	var restored = victim(origin,"boss")
	restored.dead = true
	restored.visual.crumble(true)
	check(restored.visual.chips.is_empty() and not restored.visual.rig.visible and physical_rocks_only(restored.visual),"A restored dead boss stays gone without a static pile or a replayed blast")
	var revived = victim(origin+Vector3.RIGHT*2,"lion")
	revived.playground_kill()
	var old_chips: Array = revived.visual.chips.duplicate()
	revived.playground_revive()
	await frames(2)
	check(not revived.dead and revived.visual.chips.is_empty() and old_chips.all(func(c): return not is_instance_valid(c)),"Playground revival cleans up the old fragments")
	check(game.player.visual.crumbling < 0,"The living hero never acquires stone fragments")
	# A single falling rock visibly rebounds, then loses its energy to friction.
	var dropped = Fragment.make(game.world,origin+Vector3(7,2,-6),.3,Vector3(1,-1,0),Vector3(3,2,1))
	var fell = false
	var bounced = false
	for i in 100:
		await frames(1)
		if dropped.linear_velocity.y < -2: fell = true
		if fell and dropped.linear_velocity.y > .2: bounced = true
	check(bounced,"Stone rebounds after hitting the floor")
	dropped.queue_free()
	FileAccess.open("res://test-results/statue-physics.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("STATUE_PHYSICS ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
