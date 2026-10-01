extends SceneTree
## Debug playground: opens with Shift+P in debug mode, holds every hero class and
## statue, lets any be driven, takes no damage, and kills/revives on demand.
const Data = preload("res://scripts/data.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var game

func _initialize(): call_deferred("test")

func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func key(code: int, shift: bool = false):
	var e = InputEventKey.new(); e.pressed = true; e.physical_keycode = code; e.keycode = code; e.shift_pressed = shift
	if not game.debug.handle_key(e): game._unhandled_input(e)
	await process_frame

func step(seconds: float):
	var t = 0.0
	while t < seconds:
		game._process(1.0/60); t += 1.0/60

func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/playground-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true; game.set_process(false)
	game.run = Data.new_run("warrior"); game.run.floor = 1
	game.load_floor(); await process_frame
	var floor_before: int = game.run.floor
	await key(KEY_P,true)
	var pg = game.playground
	check(pg != null,"Shift+P opens the playground in debug mode")
	check(pg.heroes.size()==3 and game.enemies.size()==pg.KINDS.size(),"Three heroes and one of every statue, including the boss")
	check(game.boss != null and game.boss.kind=="boss","The Crowned Statue is present")
	check(game.world.level==game.world.Layout.PLAYGROUND and not game.world.camera.get_node("LineOfSightFog").visible,"An open, evenly lit plane without fog")
	var target = game.enemies[0]
	target.position = game.player.position+Vector3(0,0,-1.4)
	game.player.face(target.position)
	var hp: float = target.hp
	game.attack(false,target.position)
	step(1.0)
	check(target.hp==hp and not target.dead,"Hero attacks hit statues but deal no damage")
	check(target.visual.state.trim_prefix("Shield") in ["Hit","HitHead","HitStagger","HitKnockdown"] or target.hit_reactions>0,"The struck statue reacts to the hit")
	var skill_id: String = game.run.hotbar[0]
	check(not skill_id.is_empty() and game.skills.cast(skill_id,target.position),"The hero can use a class ability")
	step(1.0)
	check(target.hp==hp,"Abilities deal no damage either")
	# Drive a statue: select it, attack the hero, and see the hero take nothing.
	var gladiator = game.enemies.filter(func(e): return e.kind=="gladiator")[0]
	pg.select(gladiator)
	gladiator.position = game.player.position+Vector3(0,0,1.2)
	var hero_hp: float = game.player.hp
	gladiator.start_attack(game.player.position)
	step(1.5)
	check(game.player.hp==hero_hp and not game.player.dead and game.player.hit_reactions>0,"A driven statue's attack lands on the hero without damage")
	gladiator.puppet_goal = gladiator.position+Vector3(3,0,0)
	var start: Vector3 = gladiator.position
	step(1.0)
	check(gladiator.position.distance_to(start)>1.0,"A selected statue walks where it is sent")
	# Kill and revive.
	await key(KEY_X)
	check(gladiator.dead and gladiator.visual.state=="Crumble","X kills the selected unit and plays its death")
	await key(KEY_X)
	check(not gladiator.dead and not gladiator.visual.dead and gladiator.visual.state!="Crumble","X again revives it")
	pg.select(pg.heroes[2])
	check(game.player==pg.heroes[2] and game.run.class_id=="wizard","Selecting a hero hands it the controls")
	pg.toggle_death()
	check(game.player.dead and game.player.visual.state=="Death","A hero can be killed too")
	pg.toggle_death()
	check(not game.player.dead,"And revived")
	# Every hero class lands its basic attack, on a statue and on another hero.
	for hero in pg.heroes:
		pg.select(hero)
		for victim in [game.enemies.filter(func(e): return e.kind=="centurion")[0], pg.heroes[(pg.heroes.find(hero)+1)%3]]:
			var home: Vector3 = victim.position
			victim.position = hero.position+Vector3(0,0,-1.5); victim.stagger_time = 0; victim.busy = 0; victim.windup = 0
			var before: int = victim.hit_reactions
			hero.face(victim.position); hero.cooldown = 0; hero.busy = 0
			game.attack(false,victim.position)
			step(1.2)
			check(victim.hit_reactions>before,"%s's basic attack hits the %s" % [pg.unit_name(hero),pg.unit_name(victim)])
			victim.position = home
	# Every attacking statue lands its attack on another unit, hero or statue.
	for enemy in game.enemies:
		pg.select(enemy)
		for victim in [pg.heroes[0], game.enemies.filter(func(e): return e != enemy and e.kind=="lion")[0] if enemy.kind!="lion" else game.enemies[0]]:
			var home: Vector3 = victim.position
			victim.position = enemy.position+Vector3(0,0,1.4); victim.stagger_time = 0; victim.busy = 0; victim.windup = 0
			enemy.busy = 0; enemy.windup = 0; enemy.cooldown = 0
			var before: int = victim.hit_reactions
			enemy.start_attack(victim.position)
			step(3.0)
			check(victim.hit_reactions>before,"The %s's attack hits the %s" % [pg.unit_name(enemy),pg.unit_name(victim)])
			victim.position = home
	# Each hero class wears its own kit.
	for hero in pg.heroes:
		var cls: String = hero.uid.trim_prefix("hero:")
		var shown = {}
		for mesh in hero.visual.skin_meshes: shown[String(mesh.name)] = mesh.visible
		var kit = {"warrior":["HeroHelmet","HeroArmor","SuperHero_Male"],"ranger":["RangerCloak","RangerBody"],"wizard":["WizardRobe","WizardCape","WizardHood","WizardBody"]}[cls]
		var hidden = ["HeroHelmet","RangerCloak","RangerBody","WizardRobe","WizardCape","WizardHood","WizardBody","HeroArmor","SuperHero_Male"].filter(func(n): return not n in kit)
		check(kit.all(func(n): return shown.get(n,false)) and hidden.all(func(n): return not shown.get(n,true)),"The %s wears its own kit" % cls)
	# The ranger's cloak swings on a spring simulation that collides with his legs.
	var cloak_sim = pg.heroes[1].visual.cloak
	check(cloak_sim != null and cloak_sim.setting_count == 13 and cloak_sim.get_collision_count(0) == 2,"The ranger's cloak has physics chains and hip colliders")
	# Its cloth is kept outside his legs by the cloak shader, given the legs as
	# capsules every frame.
	var cloth: ShaderMaterial = pg.heroes[1].visual.cloak_mesh.material_override
	pg.heroes[1].visual.cloak_capsules()
	check(cloth.shader.resource_path.ends_with("cloak.gdshader") and cloth.get_shader_parameter("capsule_count") == 6 and (cloth.get_shader_parameter("capsule_a") as PackedVector3Array).size() == 6,"The ranger's cloak folds over his legs (cloth shader with leg capsules)")
	check(pg.heroes[0].visual.cloak == null,"The warrior wears no simulated cloth")
	# The wizard's cape, the Oracle's and the Crowned Statue's swing the same
	# way, from the shoulders, as heavier cloth.
	for unit in [pg.heroes[2]]+game.enemies.filter(func(e): return e.kind in ["wizard","boss"]):
		var sim = unit.visual.cloak
		var cape_mesh = unit.visual.cloak_mesh
		check(sim != null and sim.setting_count == 13 and cape_mesh != null and unit.visual.cloth_feel == unit.visual.CLOTH_HEAVY,"The %s's cape swings and folds over the legs" % pg.unit_name(unit))
	var helm = pg.heroes[0].visual.skin_meshes.filter(func(m): return m.name == "HeroHelmet")[0]
	check(helm.material_override.albedo_color.r > helm.material_override.albedo_color.b*2,"The warrior's helm is bronze")
	# Statue stone is laid out from the rest pose, so it stays fixed to the body
	# as it animates; only the gladiator's scale armor is marked for scales.
	for enemy in game.enemies:
		for mesh in enemy.visual.skin_meshes:
			if mesh.skin == null: continue
			var arrays = mesh.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_CUSTOM0] != null and arrays[Mesh.ARRAY_CUSTOM0].size() == arrays[Mesh.ARRAY_VERTEX].size()*4 and mesh.material_override.get_shader_parameter("rest_pose"),"The %s's stone follows its rest pose" % pg.unit_name(enemy))
			var colors = arrays[Mesh.ARRAY_COLOR]
			var scaled = colors != null and Array(colors).any(func(c): return c.r < .5)
			check(scaled == (enemy.kind == "gladiator"),"Only the gladiator's armor carries scales (%s)" % pg.unit_name(enemy))
	# Arrows are real arrows (long along their flight, slim across it) and fly
	# twice as fast as the casters' bolts.
	var from: Vector3 = game.world.spawn
	game.projectile(from,from+Vector3(10,0,0),0,true,"arrow")
	var arrow = game.projectiles[-1]
	var launched: Vector3 = arrow.node.position
	game.tick_projectiles(.1)
	var model: Node3D = arrow.node
	var along: float = (model.global_basis*Vector3(0,0,1)).length()
	var across: float = maxf((model.global_basis*Vector3(1,0,0)).length(),(model.global_basis*Vector3(0,1,0)).length())
	check(is_equal_approx((arrow.node.position-launched).length(),2.06) and game.ARROW_SPEED == 2*game.BOLT_SPEED,"Arrows fly at twice the bolts' speed")
	check(along > .6 and across < .06 and (model.global_basis*Vector3(0,0,-1)).normalized().dot(Vector3(1,0,0)) > .99,"An arrow is long and slim, its head leading")
	game.tick_projectiles(5.0)
	var zoom_in = InputEventMouseButton.new(); zoom_in.pressed = true; zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in 30: game._unhandled_input(zoom_in)
	check(game.world.zoom<=3.01,"The playground zooms in much closer")
	var pan = InputEventPanGesture.new(); pan.delta = Vector2(0,4)
	game._unhandled_input(pan)
	check(game.world.zoom>4.9,"A trackpad scroll zooms out")
	pan.delta = Vector2(0,-40)
	game._unhandled_input(pan)
	check(game.world.zoom<=3.01,"A trackpad scroll zooms in, down to the playground limit")
	var pinch = InputEventMagnifyGesture.new(); pinch.factor = .5
	game._unhandled_input(pinch)
	check(game.world.zoom>4.4,"Pinching in zooms out")
	pinch.factor = 1.5
	for i in 10: game._unhandled_input(pinch)
	check(game.world.zoom<=3.01,"Pinching out zooms in")
	await key(KEY_P,true)
	check(game.playground==null and game.run.floor==floor_before and game.world.level==floor_before,"Shift+P leaves, restoring the run")
	FileAccess.open("res://test-results/playground.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("PLAYGROUND ",passed.size()," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
