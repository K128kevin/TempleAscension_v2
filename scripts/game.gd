extends Node3D
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const CombatAnimation = preload("res://scripts/combat_animation.gd")
const Art = preload("res://scripts/assets.gd")
const Temple = preload("res://scripts/temple.gd")
const Overworld = preload("res://scripts/overworld.gd")
const Actor = preload("res://scripts/actor.gd")
const Hud = preload("res://scripts/hud.gd")
const ProgressionUI = preload("res://scripts/progression_ui.gd")
const Book = preload("res://scripts/skill_data.gd")
const Save = preload("res://scripts/save.gd")
const RangerFx = preload("res://scripts/ranger_fx.gd")
const StoneFragment = preload("res://scripts/stone_fragment.gd")
var run: Dictionary
var world
var player
var boss
var hud
var enemies: Array = []
var effects: Array = []
var projectiles: Array = []
var fireballs: Array = []
var novas: Array = []
var pickups: Array = []
var scheduled: Array = []
var carriers: Dictionary = {}
var mode = "playing"
var target
var hover_ring: Sprite3D
const ENEMY_CLICK_RADIUS = 64.0
const PLAYER_RUN_SPEED = 5.94 # Player movement speed before the walk-cycle change.
# The hero's pace at a walk (R toggles between walking and running).
const PLAYER_WALK_SPEED = 1.5
var walking = false
var route = PackedVector3Array()
var left_held = false
var right_held = false
# A left hold that began on open ground is a move order: dragging it over a
# statue keeps walking rather than turning into an attack.
var move_hold = false
var hold_timer = 0.0
var pursuit_timer = 0.0
var order_pending = false
var ordered_special = false
# The skill slot a special order casts (RMB is 0; the 1 to 4 keys, 1 to 4).
var ordered_slot = 0
# Dash Attack: the dash under way strikes whoever it passes through, each once.
var dash_attack = false
var dash_struck: Array = []
var dash_speed = 41.0
var leap_left = 0.0
var leap_duration = .26
var leap_direction = Vector3.ZERO
var leap_speed = 0.0
var dash_time = 0.0
var dash_direction = Vector3.ZERO
var heal_cd = 0.0
var regen_recovery_time = 3.0
var slowed = 0.0
# How long frost (an ice shard, a frost nova) slows the hero.
const CHILL_SECONDS = 5.0
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
# The debug playground, while it is open (Shift+P in debug mode).
var playground = null
# Whoever one of the hero's arrows is striking just now: on a statue it rings
# as arrowhead on stone (scripts/actor.gd hit).
var arrow_struck = null
# Set as the hero walks in through the temple's door: the first floor then
# loads with him standing just inside it.
var arriving_by_door = false

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
	# A new character is made in the desert, where it will start.
	if creating_character: run = Data.new_character()
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
	elif not outdoors(): toast("The crown waits above. Defeat every statue to open the ascent.")
	if test_mode:
		var tester = load("res://tests/campaign.gd").new()
		add_child(tester)
		tester.call_deferred("start",self)

# Whether the run is in the world outside the temple (the town, the desert
# and the temple's front) rather than on one of its floors.
func outdoors() -> bool:
	return run.get("place","temple")=="world"

# Loads wherever the run is: the outdoor world, or its floor of the temple.
func load_floor() -> void:
	if test_mode: creating_character = false
	run.erase("seconds") # Discard elapsed time from legacy saves.
	run.erase("skill_cooldowns") # Ignore obsolete skill recharge timers in saved runs.
	run.erase("evade_cooldown")
	var migrating = int(run.version)<2
	if int(run.version)<10: run = Save.migrate(run)
	run.drops = run.drops.filter(func(drop): return drop.value not in [2,3])
	if skills: skills.reset()
	run_generation += 1
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	enemies.clear()
	effects.clear()
	projectiles.clear()
	fireballs.clear()
	novas.clear()
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
	dash_attack = false
	dash_struck.clear()
	leap_left = 0
	heal_cd = run.heal_cooldown
	regen_recovery_time = 3.0
	combat_age = 10
	slowed = 0
	world = Overworld.new() if outdoors() else Temple.new()
	add_child(world)
	if outdoors(): world.setup(int(run.floor),int(run.seed))
	else: world.setup(int(run.floor),int(run.seed),run.place)
	# (The fallen stones' ground, laid with the floor rather than at the first
	# statue's fall, which it held up.)
	if world.has_method("ensure_debris_collision"): world.ensure_debris_collision()
	hover_ring = Art.target_ring()
	hover_ring.layers = UI_LAYER
	world.add_child(hover_ring)
	hud.clear_enemy_bars()
	show_ui(not ui_hidden)
	# The approach's music plays outdoors, as on the first floor.
	sound.track(music_track())
	if world.has_method("set_time"): world.set_time(float(run.get("clock",Daylight.MORNING)))
	player = Actor.new()
	world.add_child(player)
	var at = Vector3(run.position[0],0,run.position[1])
	# Come in from the desert, the hero stands just inside the temple's door.
	if arriving_by_door and not outdoors() and world.layout.entry.has_area(): at = world.layout.entry_position()
	# Come back up a dungeon's stair, he stands at the head of the one he
	# went down by.
	if arriving_from_below and not outdoors(): at = world.exit_point
	arriving_by_door = false
	arriving_from_below = false
	if not world.fits(at): at = world.spawn
	player.setup(self,"player","hero",at)
	player.hp = clampf(run.health,1,Data.max_health(run))
	player.visual.position.y = world.lift(at)
	# Outdoors he faces the temple, in the east.
	player.rotation.y = PI/2 if outdoors() else PI
	# A new character sits by his campfire on the dune, looking down at the
	# town, until he first moves.
	if outdoors() and run.get("resting",false):
		player.rotation.y = PI
		player.visual.rest(true)
	world.update_visibility(player.position,.1)
	world.follow(player.position,1)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(run.seed)+int(run.floor)*193
	# No statue stands outside the temple.
	if outdoors(): pass
	elif not Data.summit(run):
		var types: Array[String] = []
		var counts: Dictionary = Data.area(run).counts
		for kind in counts:
			for i in counts[kind]: types.append(kind)
		var spawn_rng = RandomNumberGenerator.new()
		spawn_rng.seed = Temple.Layout.floor_seed(int(run.seed),int(run.floor)+1+Temple.Layout.KINDS[run.place].salt)
		var spots = world.statue_posts(types.size(),spawn_rng)
		for i in types.size():
			var id = Data.enemy_id(run,i)
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
		# (The staff is found on the fountain court's floor.)
		if run.place=="temple" and run.floor==Temple.Layout.COURT_FLOOR:
			carriers["%d:%d" % [run.floor,carrier_ids[-1]]] = {"kind":"weapon","value":4,"id":"weapon:%d" % run.floor}
	else:
		boss = spawn_enemy("boss","boss",world.boss_point)
		# Four groups of five centurions stand in reserve in the corners; the
		# Crowned Statue summons a group at 80%, 60%, 40% and 20% health.
		for group in 4:
			for i in 5:
				var corner: Vector3 = world.summon_points[group*5+i]
				var centurion = spawn_enemy("centurion","summoned:%d:%d" % [group,i],corner)
				centurion.dormant = true
				centurion.face(world.boss_point)
				if centurion.uid in run.dead or "boss" in run.dead:
					centurion.dead = true
					centurion.visible = false
		toast("The Crowned Statue: ‘Turn back… I cannot stop it…’")
		if "boss" in run.dead:
			boss.dead = true
			boss.visual.crumble(true)
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
	world.exit_seal.visible = remaining()==0 and has_way_on()
	mode = "playing"
	hud.close_modal()
	if run.get("migration_notice",false):
		run.erase("migration_notice")
		toast("Save upgraded: attribute and skill points refunded. Use the + buttons (or C and K) to rebuild your character.")
	elif run.completed: summary_menu()

# The temple's door, from either side: the hero walks through it into the
# first floor, or out of the first floor into the desert. Returns whether he
# went through.
func pass_door() -> bool:
	if player.dead or mode!="playing": return false
	if outdoors():
		var into: String = world.entrance(player.position)
		if into.is_empty():
			sealed_told = false
			return false
		if into=="temple" and not Data.temple_open(run):
			# The temple stays shut until both dungeons are fought through.
			if not sealed_told: toast("The temple's door will not open. The bandits beneath the arena and in the northern cave must be dealt with first.")
			sealed_told = true
			return false
		save_run()
		run.place = into
		run.floor = 0
		arriving_by_door = true
		load_floor()
		save_run()
		return true
	if not world.leaving_temple(player.position): return false
	save_run()
	var from: String = run.place
	run.place = "world"
	run.floor = 0
	var outside: Dictionary = Overworld.OUTSIDE[from]
	run.position = [outside.at.x,outside.at.z]
	load_floor()
	player.rotation.y = outside.facing
	save_run()
	if from=="temple": toast("The town lies west, across the desert.")
	return true

# Whether the floor the hero is on has a way on from it: the temple's stair up
# (not on the summit), a dungeon's stair down (not on its lowest level).
func has_way_on() -> bool:
	if outdoors() or Data.summit(run): return false
	return not (run.place in Data.DUNGEONS and Data.last_floor(run))

# Which of the game's music plays where the hero is.
func music_track() -> int:
	if outdoors(): return 0
	if run.place in Data.DUNGEONS: return 1
	return [1,2,3,5][clampi(int(run.floor),0,3)]

# The statues awake and standing, listed once a frame: each keeps its
# distance from the rest of these as it walks.
var crowd_list: Array = []
var crowd_frame = -1
var crowd_size = -1
func crowd() -> Array:
	var frame = Engine.get_process_frames()
	if frame != crowd_frame or crowd_size != enemies.size():
		crowd_frame = frame
		crowd_size = enemies.size()
		crowd_list = enemies.filter(func(e): return e.awake and not e.dead)
	return crowd_list

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
		# The day goes by, wherever he is.
		if playground == null:
			run["clock"] = Daylight.of_day(float(run.get("clock",Daylight.MORNING))+dt)
			if world.has_method("set_time"): world.set_time(run.clock)
		player.tick(dt)
		# Advance existing jobs before accepting this frame's input: a new
		# attack and its animation both start at time zero on this clock.
		tick_scheduled(dt)
		if not player.dead: skills.tick(dt)
		if playground != null: playground.tick(dt)
		if playground == null or playground.hero_selected(): player_control(dt)
		elif playground.statue_selected(): playground.control(dt)
		# On raised ground (the palace hill) the hero's figure stands at its height.
		if leap_left<=0: player.visual.position.y = world.lift(player.position)
		# Walking through the temple's door changes worlds; this frame ends there.
		if playground == null and pass_door(): return
		world.update_visibility(player.position,dt)
		for enemy in enemies: enemy.tick(dt)
		tick_projectiles(dt)
		tick_fireballs(dt)
		tick_pickups(dt)
		if not player.dead:
			var combat_engaged = false
			for enemy in enemies:
				if enemy.awake and not enemy.dead:
					combat_engaged = true
					break
			if combat_engaged: regen_recovery_time = 0.0
			else: regen_recovery_time += dt
			var health_regen_rate = .01*(4.0 if regen_recovery_time>=3.0 else 1.0)
			player.hp = minf(Data.max_health(run),player.hp+Data.max_health(run)*health_regen_rate*dt)
			run.energy = minf(Data.max_energy(run),run.energy+Data.energy_regen(run)*dt)
		heal_cd = maxf(0,heal_cd-dt)
		slowed = maxf(0,slowed-dt)
		save_timer += dt
		if save_timer>8 and playground == null:
			save_timer = 0
			save_run()
		tick_effects(dt)
	world.occlusion_targets.clear()
	for enemy in enemies:
		if enemy.dead or not enemy.awake or not enemy.visible or enemy.position.distance_squared_to(player.position)>900: continue
		world.occlusion_targets.append({"position":enemy.position,"height":1.8*enemy.config.size})
	world.follow(playground.focus() if playground != null else player.position,dt)
	if shake_left>0:
		# A jolt that rings down: the camera thrown about its place.
		shake_left = maxf(0,shake_left-dt)
		var ring = shake_left/SHAKE_TIME
		var jolt = shake_strength*ring*ring
		world.camera.position += Vector3(sin(combat_age*139.0)*jolt,cos(combat_age*119.0)*jolt*.7,sin(combat_age*101.0)*jolt)
		if shake_left<=0: shake_strength = 0.0
	if is_instance_valid(world.fountain): world.fountain.tick(dt,player.position,mode=="playing")
	hud.tick(dt)
	update_enemy_hover()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: left_held = false
		if event.button_index==MOUSE_BUTTON_RIGHT: right_held = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_Z and event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
			show_ui(ui_hidden)
			get_viewport().set_input_as_handled()
			return
		if debug.handle_key(event):
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode==KEY_ESCAPE:
			# Escape gives up an aimed Power Shot before it pauses the game.
			if mode=="playing" and skills.abandon_aim(): pass
			elif mode=="playing": pause_game()
			elif mode in ["paused","character"] and not creating_character: resume_game()
			get_viewport().set_input_as_handled()
		if event.physical_keycode in [KEY_C,KEY_K,KEY_I] and mode in ["playing","character"] and not creating_character:
			toggle_screen(event.physical_keycode)
			get_viewport().set_input_as_handled()
		# Pointing at a learned skill in the skill panel, 1 to 4 assign it.
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4] and mode=="character" and not hud.panels.hovered.is_empty():
			hud.panels.assign(hud.panels.hovered,event.physical_keycode-KEY_1+1)
			get_viewport().set_input_as_handled()

# Alt+Z hides the whole interface, and shows it again: the HUD and every
# panel, dialog and word on it, and what is drawn into the world for the
# player's eyes alone (damage numbers, a dazed enemy's marks, the target
# ring), which stand on a render layer of their own (UI_LAYER) for the camera
# to leave out. The world itself is untouched.
const UI_LAYER = 1 << 19
var ui_hidden = false
func show_ui(on: bool) -> void:
	ui_hidden = not on
	hud.visible = on
	if is_instance_valid(world) and is_instance_valid(world.camera): world.camera.set_cull_mask_value(20,on)

# C and K open and close the attribute panel (left) and the skill panel (right);
# I, the equipment screen. The game is paused while any of them is open.
func toggle_screen(key: int) -> void:
	if key==KEY_C:
		if hud.panels.stats_open(): hud.panels.close_stats()
		else: ProgressionUI.character(self)
	elif key==KEY_K:
		if hud.panels.skills_open(): hud.panels.close_skills()
		else: ProgressionUI.skills(self)
	elif is_instance_valid(hud.modal): hud.close_dialog()
	else: ProgressionUI.equipment(self)
	if mode=="character" and not hud.panels.any_open() and not is_instance_valid(hud.modal): resume_game()

# Moves the camera in (negative) or out, within its limits; close in, the
# wheel takes finer steps.
const MIN_ZOOM = 3.0
const MAX_ZOOM = 36.0
func zoom_camera(amount: float) -> void:
	world.zoom = clampf(world.zoom+amount,MIN_ZOOM,MAX_ZOOM)

func _unhandled_input(event: InputEvent) -> void:
	if mode!="playing": return
	if playground != null and playground.unhandled(event):
		get_viewport().set_input_as_handled()
		return
	# Trackpads (macOS in particular) scroll with pan gestures rather than wheel
	# clicks, and zoom with a pinch.
	if event is InputEventPanGesture:
		zoom_camera(event.delta.y*.5)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture:
		zoom_camera((1.0-event.factor)*world.zoom)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom_camera(-(1.0 if world.zoom<=12 else 1.5))
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom_camera(1.5)
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
			KEY_R: toggle_walk()
			KEY_X: swap_weapon()
			KEY_1: cast_key(1)
			KEY_2: cast_key(2)
			KEY_3: cast_key(3)
			KEY_4: cast_key(4)
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_walk() -> void:
	walking = not walking
	toast("Walking." if walking else "Running.")

# How fast the hero goes over the ground: walking or running, halved when slowed.
func player_pace() -> float:
	# (Swift Footed quickens the ranger; hidden in the shadows he creeps.)
	var pace = (PLAYER_WALK_SPEED if walking else PLAYER_RUN_SPEED)*(.5 if slowed>0 else 1.0)*(1.0+Data.passive(run,"swift_footed")*.01)
	return pace*(1.0-skills.hide_slow*.01) if skills.hidden else pace

# Everyone an attack can land on. Normally the statues; in the playground every
# unit, heroes included, except the one attacking.
func targets(attacker = null) -> Array:
	if attacker == null: attacker = player
	var list: Array = enemies.duplicate()
	if playground != null: list += playground.heroes
	return list.filter(func(a): return a != attacker and is_instance_valid(a))

# Attacks by a playground statue land on every unit, not only the hero.
func puppet_attack(source) -> bool:
	return playground != null and is_instance_valid(source) and source.puppet

func clicked_enemy():
	if get_viewport().gui_get_hovered_control()!=null: return null
	return enemy_at_screen(get_viewport().get_mouse_position())

func enemy_at_screen(mouse: Vector2, exclude = null):
	var nearest = null
	var best = INF
	for a in targets(exclude if exclude != null else player):
		if a.dead or not a.is_visible_in_tree() or a.dormant: continue
		if world.camera.is_position_behind(a.position): continue
		var tall: float = a.config.get("height",a.config.size*2.1)
		var screen: Vector2 = world.camera.unproject_position(a.position+Vector3.UP*tall*.48)
		var feet: Vector2 = world.camera.unproject_position(a.position)
		var head: Vector2 = world.camera.unproject_position(a.position+Vector3.UP*tall)
		# A generous minimum target grows to cover tall models at close zoom.
		var radius = maxf(ENEMY_CLICK_RADIUS,feet.distance_to(head)*.5+20)
		var distance = screen.distance_to(mouse)
		if distance < radius and distance < best:
			best = distance
			nearest = a
	return nearest

# Where an attack or ability is aimed: the centre of the unit under the cursor
# when it is targeted (its red ring showing), otherwise the ground under the
# cursor. So an arrow loosed while hovering a statue flies at its middle.
# `screen` is a viewport position; by default, the mouse.
func aim_point(screen = null) -> Vector3:
	if screen == null:
		var hovered = clicked_enemy() if mode=="playing" else null
		return hovered.position if is_instance_valid(hovered) else world.pointer()
	var under = enemy_at_screen(screen)
	return under.position if is_instance_valid(under) else world.ground_at(screen)

func update_enemy_hover() -> void:
	var hovered = clicked_enemy() if mode=="playing" and not player.dead else null
	hover_ring.visible = is_instance_valid(hovered)
	if hover_ring.visible:
		hover_ring.position = hovered.position+Vector3.UP*.08
		hover_ring.scale = Vector3.ONE*hovered.config.size
	hud.show_npc_name(world.townsfolk.named_at(world.pointer()) if outdoors() and mode=="playing" and get_viewport().gui_get_hovered_control()==null else {})

# The 1 to 4 keys: a skill used up close is walked to a unit under the cursor,
# as a right click is; anything else is cast where the cursor points.
func cast_key(slot: int) -> void:
	if skills.reach(run.hotbar[slot])<13.0 and is_instance_valid(clicked_enemy()) and not Input.is_physical_key_pressed(KEY_SHIFT): issue_click(true,slot)
	else: skills.cast_slot(slot,aim_point())

func issue_click(special: bool, slot: int = 0, held: bool = false) -> void:
	# (A skill pressed again while Power Shot is aimed or loosed is let go: a
	# double tap fires once.)
	if special and skills.powering: return
	order_pending = false
	hold_timer = .08
	pursuit_timer = .15
	if Input.is_physical_key_pressed(KEY_SHIFT):
		target = null
		route.clear()
		attack(special,aim_point(),slot)
		return
	var clicked = null if held and move_hold and not special else clicked_enemy()
	if not held and not special: move_hold = clicked == null
	if clicked: order_attack(clicked,special,slot)
	elif special:
		target = null
		route.clear()
		attack(true,aim_point(),slot)
	else:
		# Walking off gives up an aimed Power Shot.
		skills.abandon_aim()
		target = null
		route = world.path(player.position,world.pointer())

# An attack (or a skill, `special`) on `clicked`: at once if it is within
# reach, or once he has walked there.
func order_attack(clicked, special: bool, slot: int = 0) -> void:
	if special and skills.powering: return
	target = clicked
	order_pending = true
	ordered_special = special
	ordered_slot = slot
	route.clear()
	if player.position.distance_to(target.position)<=attack_range(special,slot) and world.clear_line(player.position,target.position): attack(special,target.position,slot)
	else: route = world.path(player.position,target.position)

func player_control(dt: float) -> void:
	if player.dead: return
	if leap_left>0:
		# The flight is the last `leap_duration` seconds; before that he gathers.
		var before: float = leap_left
		leap_left = maxf(0,leap_left-dt)
		var step: float = minf(before,leap_duration)-minf(leap_left,leap_duration)
		if step>0:
			player.position = world.move(player.position,leap_direction*leap_speed*step)
			player.visual.position.y = world.lift(player.position)+sin((1.0-minf(leap_left,leap_duration)/leap_duration)*PI)*1.8
		if leap_left<=0: player.visual.position.y = world.lift(player.position)
		return
	if dash_time>0:
		dash_time -= dt
		player.position = world.move(player.position,dash_direction*dash_speed*dt)
		if dash_attack:
			for enemy in skills.targets(player.position,1.0):
				if not enemy in dash_struck: skills.dash_hit(enemy,dash_direction,dash_struck)
		if dash_time<=0: dash_attack = false
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
		if left_held or right_held: attack(right_held,aim_point())
	else:
		if is_instance_valid(target) and (target.dead or (not order_pending and not left_held and not right_held)):
			target = null
			route.clear()
		if right_held and hold_timer <= 0:
			issue_click(true)
		elif left_held and not is_instance_valid(target) and hold_timer <= 0:
			issue_click(false,0,true)
		if is_instance_valid(target):
			var special: bool = ordered_special
			if player.position.distance_to(target.position)<=attack_range(special,ordered_slot) and world.clear_line(player.position,target.position):
				route.clear()
				attack(special,target.position,ordered_slot)
			elif pursuit_timer <= 0:
				# A released click must also pursue a moving statue until its swing.
				pursuit_timer = .15
				route = world.path(player.position,target.position)
	var moved = false
	var pace = player_pace()
	if player.busy <= 0:
		while not route.is_empty() and player.position.distance_to(route[0]) < .06:
			route.remove_at(0)
		if not route.is_empty():
			var offset: Vector3 = route[0]-player.position
			var step: float = minf(offset.length(),pace*dt)
			var before: Vector3 = player.position
			player.position = world.move(before,offset.normalized()*step)
			var displacement: Vector3 = player.position-before
			moved = displacement.length_squared() > .000001
			if moved: player.face(player.position+displacement.normalized())
		elif not is_instance_valid(target):
			var aim: Vector3 = world.pointer()
			# (Sitting by his fire, he keeps looking at it.)
			if player.position.distance_to(aim) > .6 and not player.visual.resting: player.face(aim)
	player.visual.walking = walking
	# Hidden in the shadows, the ranger goes crouched.
	player.visual.sneaking = skills.hidden
	# (Standing after a sword swing, its recovery to the stance plays out.)
	# (He gets up from the campfire the moment he moves or acts.)
	if player.visual.resting and (moved or player.busy>0):
		run.erase("resting")
		player.visual.rest(false)
	player.visual.locomotion(moved,player.busy>0 or (not moved and player.visual.swing_phase() >= 0.0),skills.hidden,1.0,pace)

func attack_range(special: bool, slot: int = 0) -> float:
	if special: return skills.reach(run.hotbar[slot])
	if run.weapon in [2,4]: return 12.5
	return 1.9

# The normal attack's clip and timing. Dexterity quickens a swing and a
# bowshot alike, Quick Strikes a melee swing (down to Data.MELEE_MINIMUM).
func attack_profile() -> Dictionary:
	var weapon: int = run.weapon
	# (Frenzy quickens the ranger's bow and dagger alike.)
	var frenzy: float = (skills.haste()-1.0)*100.0
	if weapon==2: return CombatAnimation.profile(weapon,false,(1.0+Data.attack_haste(run)*.01)*(1.0+frenzy*.01)*100.0-100.0,Data.cooldown(run)*.5,.35)
	if weapon==4: return CombatAnimation.profile(weapon,false,0,Data.cooldown(run)*.5,.35)
	return CombatAnimation.profile(weapon,false,(1.0+Data.melee_attack_speed(run)*.01)*(1.0+frenzy*.01)*100.0-100.0,Data.MELEE_MINIMUM,0.0)

# Which swing of the sword's chain (CombatAnimation.SWORD_CHAIN) was last begun.
# Coming back up a dungeon's stair; and whether the shut temple door has
# been remarked on since he came to it.
var arriving_from_below = false
var sealed_told = false
var sword_swing = 0
# How many swings the chain has run to: each steps with the other foot.
var sword_steps = 0
var dagger_attacks = 0
func attack(special: bool, point: Vector3, slot: int = 0) -> void:
	if player.cooldown>0 or player.busy>0 or player.dead or mode!="playing": return
	if special:
		# A skill that cannot be cast (no energy, recharging) ends the order
		# rather than leaving the hero waiting on it.
		if not skills.cast_slot(slot,point): order_pending = false
		return
	order_pending = false
	# Attacking brings the ranger out of the shadows.
	skills.leave_shadows()
	var animation = attack_profile()
	player.cooldown = animation.duration
	player.busy = animation.duration
	player.face(point)
	player.begin_strike(point)
	var damage = Data.damage(run,randf_range(10,15))
	var weapon: int = run.weapon
	if weapon not in [2,4]: scheduled.append({"time":maxf(.01,animation.times[0]-.12),"type":"swing","sound":"swing-spear" if weapon==0 else "swing-blade"})
	if weapon == 1 and player.visual.clips.has(CombatAnimation.SWORD_OPENER): swing_sword(animation.duration)
	elif weapon == 5 and player.visual.clips.has(CombatAnimation.DAGGER_ATTACKS[1]):
		# The dagger: a stab and a slash by turns.
		dagger_attacks += 1
		player.visual.play(CombatAnimation.DAGGER_ATTACKS[dagger_attacks%2],animation.duration)
	else: player.visual.play(animation.clip,animation.duration)
	if weapon in [2,4]:
		for release_time in animation.times:
			scheduled.append({"time":release_time,"type":"arcane" if weapon==4 else "arrow","at":point,"damage":damage*(2.0/3.0 if special else 1.0),"special":special})
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

# The sword's next swing, its swing taking `seconds`: the swings run on into
# one another while he keeps swinging (the normal attack, and Vampiric and
# Shadow Strike, which are struck with the same swings); broken off, the next
# starts the chain over.
func swing_sword(seconds: float) -> void:
	var phase: float = player.visual.swing_phase()
	var share: float = CombatAnimation.SWORD_SWING_SHARE
	if phase >= 0.0 and phase <= share+CombatAnimation.SWORD_FOLLOW:
		# Each clip carries on a moment into the next swing's motion: the
		# next takes over at that same moment of it, and still ends on time.
		var into: float = maxf(0.0,phase-share)
		sword_swing = (sword_swing+1)%CombatAnimation.SWORD_CHAIN.size()
		sword_steps += 1
		player.visual.play_on(CombatAnimation.SWORD_CHAIN[sword_swing]+CombatAnimation.SWORD_FEET[sword_steps%2],seconds/(share-into),into)
	else:
		sword_swing = 0
		sword_steps = 0
		player.visual.play(CombatAnimation.SWORD_OPENER,seconds/share)

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
				# (The wizard's bolt is silent; only the bow sounds.)
				if job.type=="arrow": sound.play("archer-arrow")
				projectile(player.position,job.at,job.damage,true,job.type,job.type=="arrow" and Data.passive(run,"penetrating_arrows")>0,null,job.special)
			"blast": blast(player.position if job.get("follow_player",false) else job.at,2.88,job.damage,true,true)
			"melee":
				var hit_list: Array = []
				var reach: float = 2.44 if job.special else 1.9
				for enemy in targets(player):
					if enemy.dead or enemy.dormant: continue
					var offset: Vector3 = enemy.position-player.position
					if offset.length()<=reach+(.5 if enemy.kind=="boss" else .25) and job.direction.dot(offset.normalized()) >= (0 if job.special and job.weapon==1 else .707) and world.clear_line(player.position,enemy.position): hit_list.append(enemy)
				hit_list.sort_custom(func(a,b): return player.position.distance_squared_to(a.position)<player.position.distance_squared_to(b.position))
				if not (job.special and job.weapon==1) and hit_list.size()>1: hit_list.resize(1)
				for enemy in hit_list:
					skills.strike(enemy,job.damage,"physical",0.0,Vector3.ZERO,job.special,job.weapon)
					player.landed_on(enemy)
					if job.special and job.weapon==0 and not enemy.dead: enemy.position = world.move(enemy.position,job.direction*6.5)
				if job.special: effect(player.position,4.5,Color(1,.78,.35,.65),.25)

# Carries the hero through the air to land `distance` away after `seconds`
# (the Leap skill); he cannot be hurt on the way.
# A leap of `distance` landing after `seconds`; the flight itself begins
# after `crouch` seconds (the warrior's own leap gathers first).
func start_leap(direction: Vector3, distance: float, seconds: float, crouch: float = 0.0) -> void:
	leap_duration = seconds-crouch
	leap_left = seconds
	leap_direction = direction
	leap_speed = distance/leap_duration
	player.invulnerable = seconds

# The screen shaken: the camera jolted `strength` metres, settling over half a second.
var shake_left = 0.0
var shake_strength = 0.0
const SHAKE_TIME = .7
func shake(strength: float) -> void:
	shake_strength = maxf(shake_strength,strength)
	shake_left = SHAKE_TIME

func dash() -> void:
	if leap_left>0: return
	if mode!="playing" or player.dead: return
	# Dash Attack makes the dash strike, and adds to its cost.
	var attacks: bool = run.skills.has("dash_attack")
	var price: float = 10.0+Book.values("dash_attack",int(run.skills.get("dash_attack",0))).y
	if run.energy<price:
		toast("Evade needs %d energy." % price)
		return
	run.energy -= price
	dash_attack = attacks
	skills.leave_shadows()
	dash_struck.clear()
	scheduled.clear() # Evading cancels an unfinished wind-up or remaining volley.
	sound.play("dash-whoosh")
	skills.pending.clear()
	skills.cancel_aim()
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

func heal() -> void:
	if mode!="playing" or player.dead or heal_cd>0 or player.hp>=Data.max_health(run): return
	if run.energy<60:
		toast("Healing needs 60 energy.")
		return
	sound.play("heal")
	run.energy -= 60
	player.hp = minf(Data.max_health(run),player.hp+Data.max_health(run)*.6)
	heal_cd = 20
	save_run()

# In combat only while an enemy is after him: awake to him and hunting him
# (it stands down once it loses him). His own attacks and skills, at nothing
# or at a statue still asleep, do not count.
func out_of_combat() -> bool:
	for enemy in enemies:
		if enemy.awake and not enemy.dead and not enemy.dormant: return false
	return true

func safe_checkpoint() -> bool:
	return not outdoors() and player.position.distance_to(world.spawn)<3 and out_of_combat()

# The ranger carries his bow and his dagger both: he takes up either at any
# time (X changes between them; a skill made with the other takes it up).
func take_up(index: int) -> void:
	if index<0 or index>=Data.WEAPONS.size() or not run.owned[index] or int(run.weapon)==index: return
	run.weapon = index
	player.visual.equip(Data.WEAPONS[index])

func swap_weapon() -> void:
	if mode!="playing" or player.dead or player.busy>0 or run.class_id!="ranger": return
	var other: int = 5 if int(run.weapon)==2 else 2
	if not run.owned[other]: return
	take_up(other)
	toast("%s in hand." % Data.WEAPONS[other].capitalize())

func equip(index: int) -> void:
	if index<0 or index>=Data.WEAPONS.size() or not run.owned[index]: toast("You do not own that weapon."); return
	if not out_of_combat(): toast("Change equipment out of combat."); return
	if player.busy>0: return
	run.weapon = index
	player.visual.equip(Data.WEAPONS[index])
	save_run()
	toast("%s equipped. Check skill requirements in K." % Data.WEAPONS[index].capitalize())

func awaken(enemy) -> void:
	if enemy.awake or enemy.dead or enemy.dormant: return
	enemy.awake = true
	enemy.visual.play(enemy.visual.idle_action())
	for other in enemies:
		if other.awake or other.dead or other.dormant: continue
		if other.position.distance_to(enemy.position)<6.56 and other.position.distance_to(player.position)<18 and world.clear_line(enemy.position,other.position): awaken(other)

# `source` is the enemy whose attack this is; landing it resets its pushback.
func hurt_player(damage: float, type: String = "physical", source = null) -> void:
	if playground != null:
		# The playground shows the hit, but the hero takes no damage.
		if not player.dead: player.react_to_hit(false)
		if is_instance_valid(source): source.landed_attack()
		return
	if player.dead or player.invulnerable>0 or invincible_test or (debug.enabled and debug.invulnerable): return
	damage = Data.mitigate(damage,10.0,0.0,Data.enemy_level(run),type)
	damage = skills.defend(damage,source)
	# Struck, the ranger is hidden no longer.
	skills.leave_shadows()
	player.hp -= damage
	combat_age = 0
	if is_instance_valid(source): source.landed_attack()
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
	elif damage>0: player.react_to_hit(damage>=player.max_hp*.2)

func retry_floor() -> void:
	run.dead = run.dead.filter(func(id): return not Data.of_place(id,run.place))
	run.drops = []
	run.health = Data.max_health(run)
	run.energy = Data.max_energy(run)
	run.position = [0,9]
	run.phase = "playing"
	load_floor()
	save_run()

func enemy_died(enemy) -> void:
	# The crown's summoned centurions grant no experience.
	if not enemy.uid in run.xp_claimed and not enemy.summoned():
		run.xp_claimed.append(enemy.uid)
		var reward = Data.enemy_xp(run,enemy.kind)
		var levels = Data.gain_xp(run,reward)
		float_text(enemy.position,"+%d XP" % reward,Color(.55,.8,1))
		if levels>0:
			float_text(player.position+Vector3.UP*2.2,"LEVEL %d" % run.level,Color(1,.86,.45))
			toast("Level %d: %d attribute points and %d skill point%s to spend." % [run.level,run.points,run.skill_points,"" if run.skill_points==1 else "s"])
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
	elif remaining()==0 and has_way_on():
		world.exit_seal.visible = true
		toast("The floor is silent. Ascend at the jade stairway." if run.place=="temple" else "The level is silent. The way down is open.")
	elif remaining()==0 and run.place in Data.DUNGEONS and not run.place in run.cleared:
		# The dungeon's last level is cleared: one step nearer the temple.
		run.cleared.append(run.place)
		toast("The bandits are routed. %s" % ("The temple's door will open to you now." if Data.temple_open(run) else "Their fellows %s remain." % ("in the cave in the northern desert" if run.place=="basement" else "beneath the arena")))
	save_run()

func create_pickup(drop: Dictionary) -> void:
	if drop.kind=="gem" or drop.value in [2,3]: return
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
		p.node.visible = world.can_see(p.node.position)
		p.seal.visible = p.node.visible
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

# Metres per second: arrows, and the casters' bolts and ice.
const ARROW_SPEED = 20.6
const BOLT_SPEED = 10.3
# How far the hero's arrows fly (the bow's reach, as Skills.reach): an arrow
# carried on through its targets by Penetrating Arrows stops there all the same.
const ARROW_REACH = 13.0

# `skill`: a skill's shot rather than the normal attack's.
# `extra`: what one of the ranger's arrows carries besides its damage
# (Skills.arrow_hit applies it; scripts/ranger_fx.gd shows it in flight).
func projectile(from: Vector3, at: Vector3, damage: float, friendly: bool, type: String, piercing: bool = false, source = null, skill: bool = true, extra: Dictionary = {}) -> void:
	var direction = (at-from).normalized()
	# Arrows are real arrows: the hero's in their own wood, fletching and
	# steel, a statue's in stone.
	var finish: Material
	if type=="arrow": finish = null if friendly else Art.statue_material()
	else: finish = Art.material("gold" if friendly else "marble",Color(.35,.7,1) if type=="ice" else (Color(.65,.35,1) if type=="arcane" else (Color(1,.3,.05) if type=="fire" else Color(.9,.67,.45))))
	var node = Art.model("arrow" if type=="arrow" else "gem",Art.ARROW_SIZE if type=="arrow" else Vector3(1.5,.5,.6),finish)
	world.add_child(node)
	node.position = from + Vector3.UP
	# The arrow's head is toward its local -Z; turn that into the flight.
	node.rotation = Vector3(0,atan2(direction.x,direction.z)+(PI if type=="arrow" else 0.0),0)
	if not extra.is_empty(): RangerFx.arrow(node,extra.get("kind",""))
	projectiles.append({"node":node,"direction":direction,"damage":damage,"friendly":friendly,"age":0.0,"type":type,"piercing":piercing,"hit":[],"source":source,"skill":skill,"extra":extra})

func tick_projectiles(dt: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary = projectiles[i]
		p.age += dt
		var before: Vector3 = p.node.position
		var after: Vector3 = before+p.direction*(ARROW_SPEED if p.type=="arrow" else BOLT_SPEED)*dt
		p.node.visible = world.can_see(after)
		# Arrows fly twice as fast, over the same range.
		var lifetime: float = 4.0
		if p.type=="arrow": lifetime = ARROW_REACH/ARROW_SPEED if p.friendly else BOLT_SPEED*4.0/ARROW_SPEED
		var remove: bool = p.age>lifetime or not world.clear_line(Vector3(before.x,0,before.z),Vector3(after.x,0,after.z))
		p.node.position = after
		if not remove:
			var friendly: bool = p.friendly or puppet_attack(p.source)
			var candidates: Array = targets(p.source if puppet_attack(p.source) else player) if friendly else [player]
			for a in candidates:
				if a.dead or a.uid in p.hit or a.dormant: continue
				var closest = Geometry3D.get_closest_point_to_segment(a.position+Vector3.UP,before,after)
				if closest.distance_to(a.position+Vector3.UP) < (1.1 if a.kind=="boss" else (.9 if p.type=="ice" else .55)):
					if friendly:
						var kind: String = "physical" if p.type=="arrow" else ("frost" if p.type=="ice" else p.type)
						# The hero's own shots count as his hits.
						var impact = StoneFragment.impact(p.direction)
						if p.friendly and p.type=="arrow":
							arrow_struck = a
							skills.arrow_hit(a,p)
							arrow_struck = null
						elif p.friendly: skills.strike(a,p.damage,kind,0.0,impact,p.skill)
						else: a.hit(p.damage,kind,0.0,impact)
						p.hit.append(a.uid)
					else:
						hurt_player(p.damage,"frost" if p.type=="ice" else "physical",p.source)
						if p.type=="ice" and player.invulnerable<=0: slowed = CHILL_SECONDS
					if not p.piercing:
						remove = true
						break
		if remove:
			p.node.queue_free()
			projectiles.remove_at(i)

func blast(at: Vector3, radius: float, damage: float, friendly: bool, skill: bool = false) -> void:
	area_damage(at,radius,damage,friendly,null,skill)

# The hero's own blasts are his hits (with their chance to crit); a puppet's
# in the playground are not.
func area_damage(at: Vector3, radius: float, damage: float, friendly: bool, source = null, skill: bool = false) -> void:
	if puppet_attack(source): friendly = true
	var candidates: Array = targets(source if puppet_attack(source) else player) if friendly else [player]
	for a in candidates:
		if a.dead or a.position.distance_to(at)>radius or not world.clear_line(at,a.position): continue
		if friendly and not puppet_attack(source): skills.strike(a,damage,"physical",0.0,Vector3.ZERO,skill)
		elif friendly: a.hit(damage)
		else: hurt_player(damage,"physical",source)

# The Oracle's lobbed fireball; it deals area damage when it lands.
func fireball(from: Vector3, at: Vector3, radius: float, damage: float, seconds: float, source = null, friendly: bool = false) -> void:
	var ball = preload("res://scripts/fireball.gd").new()
	world.add_child(ball)
	ball.friendly = friendly
	ball.setup(self,from,at,radius,damage,seconds)
	ball.source = source
	fireballs.append(ball)

func tick_fireballs(dt: float) -> void:
	for list in [fireballs,novas]:
		for i in range(list.size()-1,-1,-1):
			if not list[i].tick(dt):
				list[i].queue_free()
				list.remove_at(i)

# The Oracle's frost nova: frost damage and the ice slow to the hero anywhere
# within the blast, unless evading or behind a wall.
func frost_nova(center: Vector3, radius: float, damage: float, source = null) -> void:
	var nova = preload("res://scripts/frost_nova.gd").new()
	world.add_child(nova)
	nova.setup(self,center,radius)
	novas.append(nova)
	if puppet_attack(source):
		area_damage(center,radius,damage,true,source)
		return
	if player.dead or player.position.distance_to(center)>radius or not world.clear_line(center,player.position): return
	hurt_player(damage,"frost",source)
	if player.invulnerable<=0: slowed = CHILL_SECONDS

func effect(at: Vector3, diameter: float, color: Color, duration: float) -> Dictionary:
	var node = Art.seal(diameter,color)
	world.add_child(node)
	node.position = at + Vector3.UP*.08
	var entry = {"node":node,"life":duration,"total":duration,"float":false}
	effects.append(entry)
	return entry

# `swell`: a critical hit's number, which starts at the usual size and
# quickly grows larger before it fades.
const SWELL_SCALE = 1.5
const SWELL_TIME = .14
func float_text(at: Vector3, text: String, color: Color, swell: bool = false) -> void:
	var l = Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = .009
	# A thin dark border (the default is 12) keeps the numbers legible.
	l.outline_size = 5
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.layers = UI_LAYER
	world.add_child(l)
	l.position = at+Vector3.UP
	if swell:
		l.outline_modulate = Color(.3,.08,0)
		effects.append({"node":l,"life":1.0,"total":1.0,"float":true,"swell":true})
	else: effects.append({"node":l,"life":.85,"total":.85,"float":true})

func tick_effects(dt: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var e: Dictionary = effects[i]
		e.life -= dt
		if e.float: e.node.position.y += dt
		if e.has("velocity"): e.node.position += e.velocity*dt
		e.node.visible = world.can_see(e.node.position)
		e.node.modulate.a = clampf(e.life/e.total,0,1)
		if e.get("swell",false): e.node.scale = Vector3.ONE*lerpf(1.0,SWELL_SCALE,ease(clampf((e.total-e.life)/SWELL_TIME,0,1),.4))
		if e.life<=0:
			e.node.queue_free()
			effects.remove_at(i)

func summon_centurions(group: int) -> void:
	for enemy in enemies:
		if enemy.uid.begins_with("summoned:%d:" % group) and not enemy.dead:
			enemy.dormant = false
			enemy.awake = true
			enemy.visual.play(enemy.visual.idle_action())
	toast("The crown summons five centurions to its defense!")

func place_crown() -> void:
	var crown = Art.model("crown",Vector3(.8,.4,.8),Art.material("gold"))
	world.add_child(crown)
	crown.position = crown_position + Vector3.UP*.4
	effect(crown_position,4,Color(1,.83,.4),10000)

func remaining() -> int:
	var count = 0
	for e in enemies:
		if not e.dead and not e.dormant: count += 1
	return count

func interact() -> void:
	if crown_available and player.position.distance_to(crown_position)<3:
		ending()
	elif remaining()==0 and has_way_on() and player.position.distance_to(world.exit_point)<4:
		next_floor()
	elif run.place in Data.DUNGEONS and run.floor>0 and out_of_combat() and player.position.distance_to(world.layout.arrival_position())<3.5:
		previous_floor()
	elif safe_checkpoint():
		save_run()
		ProgressionUI.character(self)

func allocation_menu() -> void:
	ProgressionUI.character(self)

# Back up a dungeon's stair to the level above, as he left it.
func previous_floor() -> void:
	run.floor = maxi(0,int(run.floor)-1)
	run.drops = []
	arriving_from_below = true
	load_floor()
	save_run()

func next_floor() -> void:
	run.floor = int(run.floor)+1
	# (A dungeon's levels are remembered: he may come back up through them.)
	if run.place=="temple": run.dead = run.dead.filter(func(id): return not Data.of_place(id,"temple"))
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
	hud.dialog("A MOMENT OF STILLNESS", "Progress is saved.\n\nLMB move / attack · Shift + LMB attack in place\nRMB + 1–4 skills · Space evade · Q healing spell\nC attributes · K skills · I equipment · Hold LMB to steer · Wheel or trackpad zoom · E interact · F11 fullscreen")
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

func enter_playground() -> void:
	if playground != null: return
	playground = preload("res://scripts/playground.gd").new()
	add_child(playground)
	playground.enter(self)

func leave_playground() -> void:
	if playground == null: return
	playground.leave()
	playground.queue_free()
	playground = null
	load_floor()

func save_run() -> void:
	# The playground's units and runs are never saved.
	if creating_character or playground != null: return
	run.heal_cooldown = heal_cd
	if not is_instance_valid(player): return
	run.health = maxf(1,player.hp)
	run.position = [player.position.x,player.position.z]
	if mode=="dead":
		run.dead = run.dead.filter(func(id): return not Data.of_place(id,run.place))
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
