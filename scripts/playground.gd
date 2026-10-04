extends Node
## Debug playground (Shift+P in debug mode): an empty, evenly lit plane with a
## hero of each class and one of every statue, including the boss. Any unit can
## be selected and use its abilities. Hits play their reactions but deal no
## damage, and nothing dies, except through the Kill / Revive toggle.
##
## A selected hero is driven by the normal controls (it becomes Game.player, with
## its own run: every class skill learned, energy always full). A selected statue
## is driven the same way: it turns to the cursor as it moves, walks where the
## ground is clicked (following the cursor while the button is held), pursues
## and attacks a clicked unit, attacks in place with Shift or the right button
## (again and again while held), and uses its special with 1: the Oracle's
## frost nova or the Crowned Statue's gaze. Every attack can land on any other
## unit, hero or statue.
const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/assets.gd")
const Temple = preload("res://scripts/temple.gd")
const Actor = preload("res://scripts/actor.gd")
const Book = preload("res://scripts/skill_data.gd")
const CLASSES = ["warrior","ranger","wizard"]
const KINDS = ["gladiator","archer","lion","wizard","centurion","boss"]

var game
var saved_run: Dictionary
var heroes: Array = []
var hero_runs: Dictionary = {}
var units: Array = []
var selected
var ring: Sprite3D
var panel: PanelContainer
var title: Label
var buttons: Dictionary = {}
var kill_button: Button
# A selected statue's orders, as the hero's (Game.player_control): the unit it
# pursues to attack, and the clocks that pace a held button's fresh orders and
# a pursuit's repathing.
var statue_target = null
var statue_order_pending = false
var statue_hold = 0.0
# A left hold begun on open ground walks on over units rather than attacking.
var statue_move_hold = false
var statue_pursuit = 0.0

func enter(owner_game) -> void:
	game = owner_game
	saved_run = game.run.duplicate(true)
	name = "Playground"
	build_world()
	build_panel()
	select(heroes[0])
	game.toast("Playground · Tab or the panel selects a unit · X kills / revives · Shift+P leaves")

func build_world() -> void:
	if game.skills: game.skills.reset()
	if is_instance_valid(game.world):
		game.remove_child(game.world)
		game.world.queue_free()
	for list in [game.enemies,game.effects,game.projectiles,game.fireballs,game.novas,game.pickups,game.scheduled]: list.clear()
	game.carriers.clear()
	game.target = null
	game.boss = null
	game.route.clear()
	game.world = Temple.new()
	game.add_child(game.world)
	game.world.setup(Temple.Layout.PLAYGROUND,1)
	game.hover_ring = Art.target_ring()
	game.world.add_child(game.hover_ring)
	ring = Art.target_ring()
	var green = GradientTexture2D.new()
	green.width = 128; green.height = 128
	green.fill = GradientTexture2D.FILL_RADIAL
	green.fill_from = Vector2(.5,.5); green.fill_to = Vector2(1,.5)
	green.gradient = Gradient.new()
	green.gradient.offsets = PackedFloat32Array([0,.87,.92,.97,1])
	green.gradient.colors = PackedColorArray([Color(.3,1,.5,0),Color(.3,1,.5,0),Color(.3,1,.5,.95),Color(.3,1,.5,.95),Color(.3,1,.5,0)])
	ring.texture = green
	game.world.add_child(ring)
	var center: Vector3 = game.world.spawn
	for i in CLASSES.size():
		var class_id: String = CLASSES[i]
		var run = hero_run(class_id)
		hero_runs[class_id] = run
		game.run = run
		var hero = Actor.new()
		game.world.add_child(hero)
		hero.setup(game,"player","hero:"+class_id,center+Vector3((i-1)*2.5,0,3))
		hero.rotation.y = PI
		# Enough of a statue's profile to be targeted, hovered and hit.
		hero.config = {"title":class_id.capitalize(),"size":1.0,"range":1.9,"interval":.5,"damage":0.0,"weapon":Data.WEAPONS[int(run.weapon)]}
		heroes.append(hero)
		units.append(hero)
	for i in KINDS.size():
		var kind: String = KINDS[i]
		var at = center+Vector3((i-(KINDS.size()-1)/2.0)*3.2,0,-5 if kind!="boss" else -9)
		var enemy = game.spawn_enemy(kind,"playground:"+kind,at)
		enemy.puppet = true
		enemy.awake = true
		enemy.visual.play(enemy.visual.idle_action())
		if kind == "boss":
			enemy.visual.crown()
			game.boss = enemy
		units.append(enemy)
	game.player = heroes[0]
	game.mode = "playing"
	game.hud.close_modal()

# A hero of this class with every class skill learned and the first three
# active ones on the hotbar.
func hero_run(class_id: String) -> Dictionary:
	var run = Data.new_run(class_id)
	run.level = Data.MAX_LEVEL
	var actives: Array = []
	for id in Book.all():
		var s: Dictionary = Book.all()[id]
		if s.class_id != class_id: continue
		run.skills[id] = 1
		if s.effect != "passive" and Book.compatible(id,int(run.weapon)): actives.append(id)
	actives.sort_custom(func(a,b): return Book.all()[a].points+Book.all()[a].unlock < Book.all()[b].points+Book.all()[b].unlock)
	run.hotbar = []
	for i in 5: run.hotbar.append(actives[i] if actives.size()>i else "")
	return run

func build_panel() -> void:
	var hud = game.hud
	panel = PanelContainer.new()
	var frame = hud.panel_style(Color(.035,.04,.045,.94),hud.gold)
	frame.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel",frame)
	hud.root.add_child(panel)
	hud.anchor(panel,Vector2(1,0),Vector2(-214,130),Vector2(190,0))
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation",3)
	panel.add_child(body)
	title = hud.label("PLAYGROUND",15,hud.gold,body)
	for unit in units:
		var b = compact(Button.new(),unit_name(unit))
		b.pressed.connect(func(): select(unit))
		body.add_child(b)
		buttons[unit] = b
	kill_button = compact(Button.new(),"")
	kill_button.pressed.connect(toggle_death)
	body.add_child(kill_button)
	var leave = compact(Button.new(),"Leave (Shift+P)")
	leave.pressed.connect(func(): game.leave_playground())
	body.add_child(leave)
	var help = hud.label("Click a unit or Shift+click to attack. Statue: click ground to move, RMB attack, 1 special.",11,Color(.75,.72,.62),body)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 170

# A small button: the HUD's button style with tight padding.
func compact(b: Button, text: String) -> Button:
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",11)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style = b.get_theme_stylebox(state)
		if style == null: continue
		style = style.duplicate()
		style.content_margin_top = 3; style.content_margin_bottom = 3
		style.content_margin_left = 6; style.content_margin_right = 6
		b.add_theme_stylebox_override(state,style)
	return b

func unit_name(unit) -> String:
	if unit.kind == "player": return unit.uid.trim_prefix("hero:").capitalize()
	return Data.ENEMIES[unit.kind].title

func select(unit) -> void:
	if is_instance_valid(selected) and selected.kind != "player": selected.puppet_goal = null
	selected = unit
	statue_target = null
	statue_order_pending = false
	if unit.kind == "player":
		game.player = unit
		game.run = hero_runs[unit.uid.trim_prefix("hero:")]
		game.skills.reset()
		game.route.clear()
		game.target = null
		game.order_pending = false
	for u in buttons: buttons[u].modulate = Color(1,.85,.4) if u == unit else Color.WHITE
	refresh()

func refresh() -> void:
	kill_button.text = ("Revive " if selected.dead else "Kill ")+unit_name(selected)+" (X)"

func hero_selected() -> bool:
	return selected != null and selected.kind == "player"

func focus() -> Vector3:
	return selected.position if selected != null else game.world.spawn

func toggle_death() -> void:
	if selected.dead:
		var weapon = Data.WEAPONS[int(hero_runs[selected.uid.trim_prefix("hero:")].weapon)] if selected.kind=="player" else ""
		selected.playground_revive(weapon)
		if selected.kind != "player": selected.visual.play(selected.visual.idle_action())
	else:
		selected.playground_kill()
	refresh()

func tick(dt: float) -> void:
	# Nothing runs out: energy stays full and nothing recharges.
	game.run.energy = Data.max_energy(game.run)
	game.heal_cd = 0
	game.skills.cooldowns.clear()
	for hero in heroes:
		hero.hp = hero.max_hp
		if hero != game.player: hero.tick(dt)
	for enemy in game.enemies: enemy.hp = enemy.max_hp
	if is_instance_valid(selected) and not selected.dead:
		ring.visible = true
		ring.position = selected.position+Vector3.UP*.05
		var size: float = selected.config.size if selected.kind != "player" else 1.0
		ring.scale = Vector3.ONE*size
	else: ring.visible = false

# Input for a selected statue. Returns true when the event was used.
func unhandled(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			select(units[(units.find(selected)+1)%units.size()])
			return true
		if event.physical_keycode == KEY_X:
			toggle_death()
			return true
	if hero_selected() or selected == null or selected.dead: return false
	if event is InputEventMouseButton and event.pressed:
		# The buttons are held and released through the game's own state, as
		# for the hero; the order is given at once and renewed while held.
		if event.button_index == MOUSE_BUTTON_LEFT:
			game.left_held = true
			statue_click(false)
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			game.right_held = true
			statue_click(true)
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1 and statue_ready():
			if selected.kind == "wizard": selected.cast_nova()
			elif selected.kind == "boss": selected.start_gaze(statue_aim())
			return true
		if event.physical_keycode in [KEY_2,KEY_SPACE,KEY_Q,KEY_E]: return true
	return false

func statue_selected() -> bool:
	return is_instance_valid(selected) and selected.kind != "player" and not selected.dead

func statue_ready() -> bool:
	return selected.windup <= 0 and selected.busy <= 0 and selected.laser_time <= 0

# Where a statue's attack is aimed: the centre of a unit under the cursor, as
# for the hero, or the ground there.
func statue_aim() -> Vector3:
	var other = game.enemy_at_screen(game.get_viewport().get_mouse_position(),selected)
	return other.position if other != null else game.world.pointer()

func statue_attack(at: Vector3) -> void:
	if not statue_ready(): return
	statue_order_pending = false
	selected.puppet_goal = null
	selected.start_attack(at)

# A click (or a held button's renewed order), as Game.issue_click: Shift or
# the right button attacks in place; a unit under the cursor is pursued and
# attacked; the ground is walked to.
func statue_click(special: bool, held: bool = false) -> void:
	statue_order_pending = false
	statue_hold = .08
	statue_pursuit = .15
	var other = null if held and statue_move_hold and not special else game.enemy_at_screen(game.get_viewport().get_mouse_position(),selected)
	if not held and not special: statue_move_hold = other == null
	if Input.is_physical_key_pressed(KEY_SHIFT) or special:
		statue_target = null
		statue_attack(other.position if other != null else game.world.pointer())
	elif other != null:
		statue_target = other
		statue_order_pending = true
		selected.puppet_goal = other.position
	else:
		statue_target = null
		selected.puppet_goal = game.world.pointer()

# Each frame for a selected statue, as Game.player_control for the hero.
func control(dt: float) -> void:
	statue_hold -= dt
	statue_pursuit -= dt
	var held: bool = game.left_held or game.right_held
	if Input.is_physical_key_pressed(KEY_SHIFT):
		statue_target = null
		statue_order_pending = false
		selected.puppet_goal = null
		if held: statue_attack(statue_aim())
	else:
		if is_instance_valid(statue_target) and (statue_target.dead or (not statue_order_pending and not held)):
			statue_target = null
			selected.puppet_goal = null
		if game.right_held and statue_hold <= 0: statue_click(true)
		elif game.left_held and not is_instance_valid(statue_target) and statue_hold <= 0: statue_click(false,true)
		if is_instance_valid(statue_target):
			var reach: float = selected.config.range+statue_target.config.size*.3 if statue_target.kind != "player" else selected.config.range
			if selected.position.distance_to(statue_target.position) <= reach and game.world.clear_line(selected.position,statue_target.position):
				selected.puppet_goal = null
				statue_attack(statue_target.position)
			elif statue_pursuit <= 0:
				statue_pursuit = .15
				selected.puppet_goal = statue_target.position
	# Standing, it turns to face the cursor.
	if selected.puppet_goal == null and statue_ready() and not is_instance_valid(statue_target):
		var aim: Vector3 = game.world.pointer()
		if selected.position.distance_to(aim) > .6: selected.face(aim)

func leave() -> void:
	panel.queue_free()
	game.run = saved_run
