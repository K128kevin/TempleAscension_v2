extends Node
## Debug playground (Shift+P in debug mode): an empty, evenly lit plane with a
## hero of each class and one of every statue, including the boss. Any unit can
## be selected and use its abilities. Hits play their reactions but deal no
## damage, and nothing dies, except through the Kill / Revive toggle.
##
## A selected hero is driven by the normal controls (it becomes Game.player, with
## its own run: every class skill learned, energy always full). A selected statue
## walks with left click on the ground, attacks with left click on another unit,
## Shift+left click or right click, and uses its special with 1: the Oracle's
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
	run.level = 30
	var actives: Array = []
	for id in Book.all():
		var s: Dictionary = Book.all()[id]
		if s.class_id != class_id: continue
		run.skills[id] = 1
		if s.effect != "passive" and Book.compatible(id,int(run.weapon)): actives.append(id)
	actives.sort_custom(func(a,b): return Book.all()[a].unlock < Book.all()[b].unlock)
	run.hotbar = [actives[0] if actives.size()>0 else "",actives[1] if actives.size()>1 else "",actives[2] if actives.size()>2 else ""]
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
	selected = unit
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
	# Nothing runs out: energy stays full and cooldowns are short.
	game.run.energy = Data.max_energy(game.run)
	game.heal_cd = 0
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
	var point: Vector3 = game.world.pointer()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Shift+click attacks in place; clicking another unit attacks it;
			# clicking the ground walks there.
			var other = game.enemy_at_screen(game.get_viewport().get_mouse_position(),selected)
			if Input.is_physical_key_pressed(KEY_SHIFT) or event.shift_pressed or other != null:
				if selected.windup <= 0 and selected.busy <= 0 and selected.laser_time <= 0:
					selected.start_attack(other.position if other != null else point)
			else: selected.puppet_goal = point
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if selected.windup <= 0 and selected.busy <= 0 and selected.laser_time <= 0:
				selected.start_attack(point)
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1 and selected.windup <= 0 and selected.busy <= 0 and selected.laser_time <= 0:
			if selected.kind == "wizard": selected.cast_nova()
			elif selected.kind == "boss": selected.start_gaze(point)
			return true
		if event.physical_keycode in [KEY_2,KEY_SPACE,KEY_Q,KEY_E]: return true
	return false

func leave() -> void:
	panel.queue_free()
	game.run = saved_run
