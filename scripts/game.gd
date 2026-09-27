extends Node3D
const Data = preload("res://scripts/data.gd")
const CombatAnimation = preload("res://scripts/combat_animation.gd")
const Art = preload("res://scripts/assets.gd")
const Temple = preload("res://scripts/temple.gd")
const Actor = preload("res://scripts/actor.gd")
const Hud = preload("res://scripts/hud.gd")
const ProgressionUI = preload("res://scripts/progression_ui.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
var run: Dictionary
var world
var player
var boss
var hud
var enemies: Array = []
var effects: Array = []
var projectiles: Array = []
var pickups: Array = []
var scheduled: Array = []
var carriers: Dictionary = {}
var mode = "playing"
var target
var route = PackedVector3Array()
var left_held = false
var right_held = false
var hold_timer = 0.0
var pursuit_timer = 0.0
var order_pending = false
var ordered_special = false
var dash_speed = 41.0
var leap_left = 0.0
var leap_duration = .26
var leap_direction = Vector3.ZERO
var leap_speed = 0.0
var dash_cd = 0.0
var dash_time = 0.0
var dash_direction = Vector3.ZERO
var heal_cd = 0.0
var slowed = 0.0
var combat_age = 0.0
var save_timer = 0.0
var crown_available = false
var crown_position = Vector3.ZERO
var run_generation = 0
var test_mode = false
var invincible_test = false
var sound
var debug
var skills
var creating_character = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	test_mode = OS.has_feature("editor") and "--test" in OS.get_cmdline_user_args()
	if test_mode: Save.directory = ProjectSettings.globalize_path("res://test-results/save")
	debug = preload("res://scripts/debug.gd").new()
	add_child(debug)
	debug.configure(OS.get_cmdline_user_args())
	debug.game = self
	if debug.enabled: Save.directory = Save.directory.path_join("debug")
	run = Data.new_run()
	creating_character = not test_mode and not debug.enabled
	if not test_mode:
		var saved = Save.load_run()
		if not saved.is_empty() and not saved.completed:
			run = saved
			creating_character = false
	debug.apply_start(OS.get_cmdline_user_args())
	sound = preload("res://scripts/audio.gd").new()
	add_child(sound)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	debug.setup(self)
	skills = preload("res://scripts/skills.gd").new()
	skills.game = self
	add_child(skills)
	load_floor()
	if creating_character: new_run_menu()
	toast("The crown waits above. Defeat every statue to open the ascent.")
	if test_mode:
		var tester = load("res://tests/campaign.gd").new()
		add_child(tester)
		tester.call_deferred("start",self)

func load_floor() -> void:
	if test_mode: creating_character = false
	run.erase("seconds") # Discard elapsed time from legacy saves.
	var migrating = int(run.version)<2
	if int(run.version)<3: run = Save.migrate(run)
	if skills: skills.reset()
	run_generation += 1
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	enemies.clear()
	effects.clear()
	projectiles.clear()
	pickups.clear()
	scheduled.clear()
	carriers.clear()
	target = null
	order_pending = false
	boss = null
	route.clear()
	left_held = false
	right_held = false
	crown_available = false
	dash_time = 0
	leap_left = 0
	dash_cd = run.evade_cooldown
	heal_cd = run.flask_cooldown
	combat_age = 10
	slowed = 0
	world = Temple.new()
	add_child(world)
	world.setup(int(run.floor),int(run.seed))
	sound.track(int(run.floor))
	player = Actor.new()
	world.add_child(player)
	var at = Vector3(run.position[0],0,run.position[1])
	if not world.fits(at): at = world.spawn
	player.setup(self,"player","hero",at)
	player.hp = clampf(run.health,1,Data.max_health(run))
	player.rotation.y = PI
	world.follow(player.position,1)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(run.seed)+int(run.floor)*193
	if run.floor < 5:
		var types: Array[String] = []
		for kind in Data.COUNTS[run.floor]:
			for i in Data.COUNTS[run.floor][kind]: types.append(kind)
		var spawn_rng = RandomNumberGenerator.new()
		spawn_rng.seed = Temple.Layout.floor_seed(int(run.seed),int(run.floor)+1)
		var spots = world.statue_posts(types.size(),spawn_rng)
		for i in types.size():
			var id = "%d:%d" % [run.floor,i]
			var enemy = spawn_enemy(types[i],id,spots[i].at)
			enemy.rotation.y = spots[i].facing
			if id in run.dead:
				enemy.dead = true
				enemy.hp = 0
				enemy.visible = false
		var carrier_ids: Array[int] = []
		for i in types.size(): carrier_ids.append(i)
		for i in range(carrier_ids.size()-1,0,-1):
			var j = rng.randi_range(0,i)
			var swap = carrier_ids[i]
			carrier_ids[i] = carrier_ids[j]
			carrier_ids[j] = swap
		if run.floor<3:
			carriers["%d:%d" % [run.floor,carrier_ids[-1]]] = {"kind":"weapon","value":[2,3,4][run.floor],"id":"weapon:%d" % run.floor}
	else:
		boss = spawn_enemy("boss","boss",world.boss_point)
		for group in 4:
			for i in 5:
				var corner: Vector3 = world.offering_points[group*5+i]
				spawn_enemy("offering","offering:%d:%d" % [group,i],corner)
		toast("The Crowned Statue: ‘Turn back… I cannot stop it…’")
		if "boss" in run.dead:
			boss.dead = true
			boss.visual.play("Death")
			crown_available = true
			crown_position = boss.position
			place_crown()
	if migrating:
		# Keep collected upgrades, defeated statues and pending loot when moving
		# a pre-generator save onto its new floor. Never strand a drop in void.
		for id in carriers:
			var reward: Dictionary = carriers[id]
			var pending = false
			for drop in run.drops:
				if drop.id==reward.id: pending = true
			if id in run.dead and not pending and not reward.id in run.gems and not (reward.kind=="weapon" and run.owned[reward.value]):
				run.drops.append(reward.duplicate(true))
		for drop in run.drops: drop.position = [world.spawn.x,world.spawn.z]
	for drop in run.drops: create_pickup(drop)
	world.exit_seal.visible = remaining()==0 and run.floor<5
	mode = "playing"
	hud.close_modal()
	if run.get("migration_notice",false):
		run.erase("migration_notice")
		toast("Save upgraded: old bonuses refunded as level-earned points. Open C and K to rebuild your character.")
	elif run.completed: summary_menu()

func spawn_enemy(kind: String, id: String, at: Vector3):
	var a = Actor.new()
	world.add_child(a)
	a.setup(self,kind,id,at)
	enemies.append(a)
	return a

func _process(dt: float) -> void:
	if not is_instance_valid(player): return
	if mode == "playing":
		combat_age += dt
		player.tick(dt)
		player_control(dt)
		for enemy in enemies: enemy.tick(dt)
		tick_scheduled(dt)
		tick_projectiles(dt)
		tick_pickups(dt)
		if not player.dead:
			run.energy = minf(Data.max_energy(run),run.energy+Data.energy_regen(run)*dt)
			skills.tick(dt)
		dash_cd = maxf(0,dash_cd-dt)
		heal_cd = maxf(0,heal_cd-dt)
		slowed = maxf(0,slowed-dt)
		save_timer += dt
		if save_timer>8:
			save_timer = 0
			save_run()
		tick_effects(dt)
	world.follow(player.position,dt)
	if is_instance_valid(world.fountain): world.fountain.tick(dt,player.position,mode=="playing")
	hud.tick(dt)
	var hovered = clicked_enemy() if mode=="playing" else null
	for enemy in enemies:
		if enemy.label:
			enemy.label.visible = not enemy.dead and (enemy==target or enemy==hovered)
			if enemy.label.visible: enemy.label.text = "%s  %d/%d" % [enemy.config.title,enemy.hp,enemy.max_hp]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: left_held = false
		if event.button_index==MOUSE_BUTTON_RIGHT: right_held = false
	if event is InputEventKey and event.pressed and not event.echo:
		if debug.handle_key(event):
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode==KEY_ESCAPE:
			if mode=="playing": pause_game()
			elif mode in ["paused","character"] and not creating_character: resume_game()
			get_viewport().set_input_as_handled()
		if event.physical_keycode in [KEY_C,KEY_K,KEY_I] and mode in ["playing","character"] and not creating_character:
			if mode=="character": resume_game()
			elif event.physical_keycode==KEY_C: ProgressionUI.character(self)
			elif event.physical_keycode==KEY_K: ProgressionUI.skills(self)
			else: ProgressionUI.equipment(self)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if mode!="playing": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: world.zoom = maxf(15,world.zoom-1.5)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: world.zoom = minf(36,world.zoom+1.5)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			left_held = true
			issue_click(false)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			right_held = true
			issue_click(true)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: dash()
			KEY_Q: heal()
			KEY_E: interact()
			KEY_1: skills.cast_slot(1,world.pointer())
			KEY_2: skills.cast_slot(2,world.pointer())
			KEY_3: skills.cast_slot(3,world.pointer())
			KEY_4: skills.cast_slot(4,world.pointer())
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func clicked_enemy():
	var mouse = get_viewport().get_mouse_position()
	var nearest = null
	var best = 38.0
	for a in enemies:
		if a.dead or not a.visible or (a.kind=="offering" and a.dormant_offering): continue
		var screen: Vector2 = world.camera.unproject_position(a.position+Vector3.UP*a.config.size)
		var distance = screen.distance_to(mouse)
		if distance < best:
			best = distance
			nearest = a
	return nearest

func issue_click(special: bool) -> void:
	order_pending = false
	hold_timer = .08
	pursuit_timer = .15
	if Input.is_physical_key_pressed(KEY_SHIFT):
		target = null
		route.clear()
		attack(special,world.pointer())
		return
	var clicked = clicked_enemy()
	if clicked:
		target = clicked
		order_pending = true
		ordered_special = special
		route.clear()
		if player.position.distance_to(target.position)<=attack_range(special) and world.clear_line(player.position,target.position): attack(special,target.position)
		else: route = world.path(player.position,target.position)
	elif special:
		target = null
		route.clear()
		attack(true,world.pointer())
	else:
		target = null
		route = world.path(player.position,world.pointer())

func player_control(dt: float) -> void:
	if player.dead: return
	if leap_left>0:
		var step = minf(dt,leap_left)
		leap_left = maxf(0,leap_left-dt)
		player.position = world.move(player.position,leap_direction*leap_speed*step)
		player.visual.position.y = sin((1.0-leap_left/leap_duration)*PI)*1.8
		if leap_left<=0: player.visual.position.y = 0
		return
	if dash_time>0:
		dash_time -= dt
		player.position = world.move(player.position,dash_direction*dash_speed*dt)
		return
	# The original game's mouse orders are authoritative. Shift plants the hero;
	# a tap keeps its destination, while a held ground order follows the cursor.
	hold_timer -= dt
	pursuit_timer -= dt
	var planted = Input.is_physical_key_pressed(KEY_SHIFT)
	if planted:
		target = null
		order_pending = false
		route.clear()
		if left_held or right_held: attack(right_held,world.pointer())
	else:
		if is_instance_valid(target) and (target.dead or (not order_pending and not left_held and not right_held)):
			target = null
			route.clear()
		if right_held and hold_timer <= 0:
			issue_click(true)
		elif left_held and not is_instance_valid(target) and hold_timer <= 0:
			issue_click(false)
		if is_instance_valid(target):
			var special: bool = ordered_special
			if player.position.distance_to(target.position)<=attack_range(special) and world.clear_line(player.position,target.position):
				route.clear()
				attack(special,target.position)
			elif pursuit_timer <= 0:
				# A released click must also pursue a moving statue until its swing.
				pursuit_timer = .15
				route = world.path(player.position,target.position)
	var moved = false
	if player.busy <= 0:
		while not route.is_empty() and player.position.distance_to(route[0]) < .06:
			route.remove_at(0)
		if not route.is_empty():
			var offset: Vector3 = route[0]-player.position
			var step: float = minf(offset.length(),5.94*(.5 if slowed>0 else 1.0)*dt)
			var before: Vector3 = player.position
			player.position = world.move(before,offset.normalized()*step)
			var displacement: Vector3 = player.position-before
			moved = displacement.length_squared() > .000001
			if moved: player.face(player.position+displacement.normalized())
		elif not is_instance_valid(target):
			var aim: Vector3 = world.pointer()
			if player.position.distance_to(aim) > .6: player.face(aim)
	player.visual.locomotion(moved,player.busy>0)

func attack_range(special: bool) -> float:
	if special: return 13.0
	if run.weapon in [2,4]: return 12.5
	return 1.9

func attack(special: bool, point: Vector3) -> void:
	if player.cooldown>0 or player.dead or mode!="playing": return
	if special:
		skills.cast_slot(0,point)
		return
	order_pending = false
	var animation = CombatAnimation.profile(run.weapon,false,Data.passive(run,"quick_draw") if run.weapon==2 else 0)
	player.cooldown = maxf(Data.cooldown(run),animation.duration)
	player.busy = animation.duration
	player.face(point)
	var damage = Data.damage(run,randf_range(10,15))
	if skills.war_cry>0: damage *= 1.25
	var weapon: int = run.weapon
	if weapon not in [2,4]: scheduled.append({"time":maxf(.01,animation.times[0]-.12),"type":"swing","sound":"swing-spear" if weapon==0 else "swing-blade"})
	player.visual.play(animation.clip,animation.duration)
	combat_age = 0
	if weapon in [2,4]:
		for release_time in animation.times:
			scheduled.append({"time":release_time,"type":"arcane" if weapon==4 else "arrow","at":point,"damage":damage*(2.0/3.0 if special else 1.0)})
	elif weapon==3 and special:
		var offset = point-player.position
		offset.y = 0
		leap_duration = animation.times[0]
		leap_left = leap_duration
		leap_direction = offset.normalized()
		leap_speed = minf(8.1,offset.length())/leap_duration
		player.invulnerable = leap_duration
		scheduled.append({"time":leap_duration,"type":"blast","at":player.position,"damage":damage*1.5,"follow_player":true})
	else:
		scheduled.append({"time":animation.times[0],"type":"melee","at":point,"damage":damage*(2.5 if special and weapon==0 else (1.25 if special else 1.0)),"weapon":weapon,"special":special,"direction":player.forward()})

func tick_scheduled(dt: float) -> void:
	for i in range(scheduled.size()-1,-1,-1):
		var job: Dictionary = scheduled[i]
		job.time -= dt
		if job.time>0: continue
		scheduled.remove_at(i)
		if player.dead: continue
		match job.type:
			"swing": sound.play(job.sound)
			"arrow","arcane":
				sound.play("archer-arrow")
				projectile(player.position,job.at,job.damage,true,job.type)
			"blast": blast(player.position if job.get("follow_player",false) else job.at,2.88,job.damage,true)
			"melee":
				var hit_list: Array = []
				var reach: float = 2.44 if job.special else 1.9
				for enemy in enemies:
					if enemy.dead or (enemy.kind=="offering" and enemy.dormant_offering): continue
					var offset: Vector3 = enemy.position-player.position
					if offset.length()<=reach+(.5 if enemy.kind=="boss" else .25) and job.direction.dot(offset.normalized()) >= (0 if job.special and job.weapon==1 else .707) and world.clear_line(player.position,enemy.position): hit_list.append(enemy)
				hit_list.sort_custom(func(a,b): return player.position.distance_squared_to(a.position)<player.position.distance_squared_to(b.position))
				if not (job.special and job.weapon==1) and hit_list.size()>1: hit_list.resize(1)
				for enemy in hit_list:
					enemy.hit(job.damage)
					if job.special and job.weapon==0 and not enemy.dead: enemy.position = world.move(enemy.position,job.direction*6.5)
				if job.special: effect(player.position,4.5,Color(1,.78,.35,.65),.25)

func dash() -> void:
	if leap_left>0: return
	if dash_cd>0 or mode!="playing" or player.dead: return
	scheduled.clear() # Evading cancels an unfinished wind-up or remaining volley.
	sound.play("dash-whoosh")
	skills.pending.clear()
	dash_cd = 3.0
	dash_time = .16
	var offset = world.pointer()-player.position
	dash_speed = minf(41,offset.length()/.16)
	dash_direction = offset.normalized()
	if dash_direction.length()<.1: dash_direction = player.forward()
	player.face(player.position+dash_direction)
	player.invulnerable = .22
	player.visual.play("Evade",.25)
	player.busy = .2
	route.clear()
	target = null
	effect(player.position,1.8,Color(.6,.9,1,.6),.3)

func heal() -> void:
	if mode!="playing" or player.dead or heal_cd>0 or run.flasks<=0 or player.hp>=Data.max_health(run): return
	sound.play("heal")
	run.flasks -= 1
	heal_cd = 8
	skills.flask_time = 2
	skills.flask_rate = Data.max_health(run)*.2
	effect(player.position,3.5,Color(.3,1,.76,.9),2)
	save_run()

func out_of_combat() -> bool:
	if combat_age<5 or player.busy>0: return false
	for enemy in enemies:
		if enemy.awake and not enemy.dead and enemy.position.distance_to(player.position)<12: return false
	return true

func safe_checkpoint() -> bool:
	return player.position.distance_to(world.spawn)<3 and out_of_combat()

func equip(index: int) -> void:
	if index<0 or index>=5 or not run.owned[index]: toast("You do not own that weapon."); return
	if not out_of_combat(): toast("Change equipment out of combat."); return
	run.weapon = index
	player.visual.equip(Data.WEAPONS[index])
	save_run()
	toast("%s equipped. Check skill requirements in K." % Data.WEAPONS[index].capitalize())

func awaken(enemy) -> void:
	if enemy.awake or enemy.dead or enemy.kind=="offering": return
	enemy.awake = true
	enemy.visual.play("Idle")
	for other in enemies:
		if other.awake or other.dead or other.kind=="offering": continue
		if other.position.distance_to(enemy.position)<6.56 and other.position.distance_to(player.position)<18 and world.clear_line(enemy.position,other.position): awaken(other)

func hurt_player(damage: float, type: String = "physical") -> void:
	if player.dead or player.invulnerable>0 or invincible_test or (debug.enabled and debug.invulnerable): return
	damage = Data.mitigate(damage,10.0,0.0,Data.ENEMY_LEVELS[run.floor],type)
	damage *= 1.0-Data.passive(run,"bulwark")*.01
	if skills.guard>0: damage *= .4
	var absorbed = minf(skills.barrier,damage)
	skills.barrier -= absorbed
	damage -= absorbed
	player.hp -= damage
	combat_age = 0
	float_text(player.position+Vector3.UP*1.8,"−%d" % roundi(damage),Color(1,.35,.25))
	if player.hp<=0:
		player.dead = true
		player.visual.play("Death")
		run.deaths += 1
		mode = "dead"
		left_held = false
		right_held = false
		hud.dialog("STONE CLAIMS ANOTHER", "Retry with your class, XP, learned skills and equipment intact. Previously rewarded enemies grant no additional XP.")
		hud.button("Rise again",retry_floor)
		hud.button("Save and quit",quit_game)

func retry_floor() -> void:
	run.dead = []
	run.drops = []
	run.health = Data.max_health(run)
	run.energy = Data.max_energy(run)
	run.position = [0,9]
	run.phase = "playing"
	run.flasks = 3
	load_floor()
	save_run()

func enemy_died(enemy) -> void:
	if not enemy.uid in run.xp_claimed:
		run.xp_claimed.append(enemy.uid)
		var reward = Data.enemy_xp(run,enemy.kind)
		var levels = Data.gain_xp(run,reward)
		float_text(enemy.position,"+%d XP" % reward,Color(.55,.8,1))
		run.energy = minf(Data.max_energy(run),run.energy+Data.passive(run,"battle_rhythm"))
		if levels>0: toast("Level %d! +%d attribute points and +%d skill points. C: attributes · K: skills" % [run.level,levels*3,levels])
	if not enemy.uid in run.dead: run.dead.append(enemy.uid)
	if carriers.has(enemy.uid):
		var drop: Dictionary = carriers[enemy.uid].duplicate()
		if not drop.id in run.gems and not (drop.kind=="weapon" and run.owned[drop.value]):
			drop.position = [enemy.position.x,enemy.position.z]
			run.drops.append(drop)
			create_pickup(drop)
	if enemy.kind=="boss":
		crown_available = true
		crown_position = enemy.position
		for other in enemies:
			if other!=enemy: other.die(false)
		place_crown()
		toast("The statue falls. The emperor's crown is yours to claim.")
	elif remaining()==0 and run.floor<5:
		world.exit_seal.visible = true
		toast("The floor is silent. Ascend at the jade stairway.")
	save_run()

func create_pickup(drop: Dictionary) -> void:
	if drop.kind=="gem": return
	var color: Color = Data.GEM_COLORS[drop.value] if drop.kind=="gem" else Color(1,.72,.25)
	var id: String = "gem" if drop.kind=="gem" else Data.WEAPONS[drop.value]
	var node = Art.model(id,Vector3(.45,.65,.35) if drop.kind=="gem" else Vector3(.6,1.3,.22),Art.material("marble",color))
	world.add_child(node)
	node.position = Vector3(drop.position[0],.3,drop.position[1])
	var seal = Art.seal(1.7,color)
	world.add_child(seal)
	seal.position = Vector3(drop.position[0],.05,drop.position[1])
	pickups.append({"node":node,"seal":seal,"drop":drop})

func tick_pickups(dt: float) -> void:
	for i in range(pickups.size()-1,-1,-1):
		var p: Dictionary = pickups[i]
		p.node.rotation.y += dt
		if player.position.distance_to(p.node.position)>1.3: continue
		var drop: Dictionary = p.drop
		sound.play("gem-pickup")
		run.owned[drop.value] = true
		toast("%s acquired · I: equipment" % Data.WEAPONS[drop.value].capitalize())
		run.drops.erase(drop)
		p.node.queue_free()
		p.seal.queue_free()
		pickups.remove_at(i)
		save_run()

func projectile(from: Vector3, at: Vector3, damage: float, friendly: bool, type: String, piercing: bool = false) -> void:
	var direction = (at-from).normalized()
	var node = Art.model("arrow" if type=="arrow" else "gem",Vector3(.09,.9,.09) if type=="arrow" else Vector3(1.5,.5,.6),Art.material("gold" if friendly else "marble",Color(.35,.7,1) if type=="ice" else (Color(.65,.35,1) if type=="arcane" else (Color(1,.3,.05) if type=="fire" else Color(.9,.67,.45)))))
	world.add_child(node)
	node.position = from + Vector3.UP
	# The imported arrow tip points down local Y; rotate it into flight.
	node.rotation = Vector3(-PI/2 if type=="arrow" else 0,atan2(direction.x,direction.z),0)
	projectiles.append({"node":node,"direction":direction,"damage":damage,"friendly":friendly,"age":0.0,"type":type,"piercing":piercing,"hit":[]})

func tick_projectiles(dt: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary = projectiles[i]
		p.age += dt
		var before: Vector3 = p.node.position
		var after: Vector3 = before+p.direction*10.3*dt
		var remove: bool = p.age>4 or not world.clear_line(Vector3(before.x,0,before.z),Vector3(after.x,0,after.z))
		p.node.position = after
		if not remove:
			var candidates: Array = enemies if p.friendly else [player]
			for a in candidates:
				if a.dead or a.uid in p.hit or (a.kind=="offering" and a.dormant_offering): continue
				var closest = Geometry3D.get_closest_point_to_segment(a.position+Vector3.UP,before,after)
				if closest.distance_to(a.position+Vector3.UP) < (1.1 if a.kind=="boss" else (.9 if p.type=="ice" else .55)):
					if p.friendly:
						a.hit(p.damage,"physical" if p.type=="arrow" else ("frost" if p.type=="ice" else p.type))
						p.hit.append(a.uid)
					else:
						hurt_player(p.damage,"frost" if p.type=="ice" else "physical")
						if p.type=="ice" and player.invulnerable<=0: slowed = 5
					if not p.piercing:
						remove = true
						break
		if remove:
			p.node.queue_free()
			projectiles.remove_at(i)

func blast(at: Vector3, radius: float, damage: float, friendly: bool) -> void:
	effect(at,radius*2,Color(1,.55,.13,.95),.6)
	var candidates: Array = enemies if friendly else [player]
	for a in candidates:
		if a.dead or a.position.distance_to(at)>radius or not world.clear_line(at,a.position): continue
		if friendly: a.hit(damage)
		else: hurt_player(damage)

func effect(at: Vector3, diameter: float, color: Color, duration: float) -> void:
	var node = Art.seal(diameter,color)
	world.add_child(node)
	node.position = at + Vector3.UP*.08
	effects.append({"node":node,"life":duration,"total":duration,"float":false})

func float_text(at: Vector3, text: String, color: Color) -> void:
	var l = Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = .009
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	world.add_child(l)
	l.position = at+Vector3.UP
	effects.append({"node":l,"life":.85,"total":.85,"float":true})

func tick_effects(dt: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var e: Dictionary = effects[i]
		e.life -= dt
		if e.float: e.node.position.y += dt
		e.node.modulate.a = clampf(e.life/e.total,0,1)
		if e.life<=0:
			e.node.queue_free()
			effects.remove_at(i)

func wake_offerings(group: int) -> void:
	for enemy in enemies:
		if enemy.kind=="offering" and enemy.uid.begins_with("offering:%d:" % group):
			enemy.dormant_offering = false
			enemy.awake = true
			enemy.visual.play("Run")
	toast("The crown summons five offerings. Stop them before they reach it!")

func place_crown() -> void:
	var crown = Art.model("crown",Vector3(.8,.4,.8),Art.material("gold"))
	world.add_child(crown)
	crown.position = crown_position + Vector3.UP*.4
	effect(crown_position,4,Color(1,.83,.4),10000)

func remaining() -> int:
	var count = 0
	for e in enemies:
		if not e.dead and e.kind!="offering": count += 1
	return count

func direction_hint() -> String:
	var nearest = null
	var best = INF
	for e in enemies:
		if e.dead or e.kind=="offering": continue
		var distance: float = e.position.distance_to(player.position)
		if distance < best: best = distance; nearest = e
	if nearest == null: return "The ascent is open"
	var direction: Vector3 = nearest.position-player.position
	var compass = "north" if direction.z<0 else "south"
	if abs(direction.x)>abs(direction.z): compass = "east" if direction.x>0 else "west"
	return "Nearest statue %dm %s" % [best,compass]

func interact() -> void:
	if crown_available and player.position.distance_to(crown_position)<3:
		ending()
	elif remaining()==0 and run.floor<5 and player.position.distance_to(world.exit_point)<4:
		next_floor()
	elif safe_checkpoint():
		run.flasks = 3
		save_run()
		ProgressionUI.character(self)

func allocation_menu() -> void:
	ProgressionUI.character(self)

func next_floor() -> void:
	run.flasks = 3
	run.floor = mini(run.floor+1,5)
	run.dead = []
	run.drops = []
	run.phase = "playing"
	run.position = [0,9]
	run.health = Data.max_health(run)
	run.energy = Data.max_energy(run)
	load_floor()
	save_run()

func ending() -> void:
	mode = "ending"
	sound.track(int(run.floor),true)
	left_held = false
	right_held = false
	player.visual.crown()
	player.visual.petrify()
	for x in [-2,2]:
		var elder = Actor.new()
		world.add_child(elder)
		elder.setup(self,"wizard","elder",player.position+Vector3(x,0,3))
		elder.face(player.position)
		elder.visual.play("Idle")
	run.completed = true
	run.phase = "complete"
	save_run()
	hud.dialog("THE CROWN'S PROMISE", "You place the crown upon your head. Your skin dries and hardens. Grey cracks spread across your hands. You can no longer move.\n\nElder: ‘Interesting. I didn't think this one would make it all the way up here.’\n\nSecond Elder: ‘He will be a formidable foe for the next brave fool we bring in here.’\n\n‘Long shall the elders reign…’")
	hud.button("Continue",summary_menu)

func summary_menu() -> void:
	mode = "summary"
	hud.dialog("TEMPLE ASCENDED", "%s mode · %d deaths\n\nThe crown has a new guardian." % [Data.DIFFICULTIES[run.difficulty],run.deaths])
	hud.button("Begin another ascent",new_run_menu)
	hud.button("Quit",quit_game)

func pause_game() -> void:
	if mode!="playing": return
	mode = "paused"
	world.process_mode = Node.PROCESS_MODE_DISABLED
	left_held = false
	right_held = false
	save_run()
	hud.dialog("A MOMENT OF STILLNESS", "Progress is saved.\n\nLMB move / attack · Shift + LMB attack in place\nRMB + 1–4 skills · Space evade · Q flask\nC attributes · K skills · I equipment · Hold LMB to steer · Wheel zoom · E interact · F11 fullscreen")
	hud.button("Resume",resume_game)
	hud.button("Continue saved ascent",continue_run)
	hud.button("New ascent / Difficulty",new_run_menu)
	hud.button("Sound: %s" % ("off" if sound.muted else "on"),func(): sound.toggle(); mode="playing"; pause_game())
	hud.button("Save and quit",quit_game)

func resume_game() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	mode = "playing"
	hud.close_modal()

func continue_run() -> void:
	var loaded = Save.load_run()
	if loaded.is_empty(): toast("No valid saved ascent found."); return
	run = loaded
	load_floor()

func new_run_menu() -> void:
	mode = "paused"
	world.process_mode = Node.PROCESS_MODE_DISABLED
	hud.dialog("A NEW CHARACTER", "Choose difficulty, then Warrior, Ranger or Wizard. This replaces the current character.")
	for i in 3:
		hud.button(Data.DIFFICULTIES[i],func(): ProgressionUI.creation(self,i))
	if not creating_character: hud.button("Back",resume_game)

func save_run() -> void:
	if creating_character: return
	run.flask_cooldown = heal_cd
	run.evade_cooldown = dash_cd
	if not is_instance_valid(player): return
	run.health = maxf(1,player.hp)
	run.position = [player.position.x,player.position.z]
	if mode=="dead":
		run.dead = []
		run.drops = []
		run.position = [0,9]
		run.health = Data.max_health(run)
		run.energy = Data.max_energy(run)
	if not Save.write(run): toast("Could not save progress. Check disk space and permissions.")

func toast(text: String) -> void:
	if is_instance_valid(hud): hud.toast(text)

func quit_game() -> void:
	save_run()
	get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: quit_game()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT and mode=="playing" and not test_mode: pause_game()
