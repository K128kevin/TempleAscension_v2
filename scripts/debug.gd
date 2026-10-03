extends Node
## Opt-in playtest controls, matching the original game's DebugMenu.
const Data = preload("res://scripts/data.gd")
var game
var enabled = false
var invulnerable = false
var panel: PanelContainer
var toggle: Button
var buttons: Dictionary = {}
const ACTIONS = [
	[KEY_G,"god","G · Invulnerable"],
	[KEY_F9,"kill","F9 · Kill all enemies"],
	[KEY_F,"refill","F · Refill health / energy"],
	[KEY_H,"axe","H · Grant battle axe"],
	[KEY_J,"bow","J · Grant bow"],
	[KEY_N,"next","N · Next floor"],
	[KEY_B,"boss","B · Boss + level 20"],
	[KEY_L,"first","L · Return to floor 1"],
	[KEY_O,"desert","O · Desert (start)"],
	[KEY_U,"town","U · Town"],
	[KEY_T,"restart","T · Restart floor"],
	[KEY_F8,"reset","F8 · Reset run"],
	[KEY_F10,"ending","F10 · Jump to ending"]]

func configure(args: PackedStringArray) -> void:
	enabled = "--debug-mode" in args

func apply_start(args: PackedStringArray) -> void:
	if not enabled: return
	var destination = -1
	for arg in args:
		if arg.begins_with("--floor="):
			var value = arg.trim_prefix("--floor=")
			if value.is_valid_int() and int(value)>=1 and int(value)<=5:
				destination = int(value)-1
	if "--boss" in args: destination = 5
	if destination>=0: prepare_floor(destination)
	if "--axe" in args: game.run.owned[3] = true
	if "--bow" in args: game.run.owned[2] = true
	if destination>=0 or "--axe" in args or "--bow" in args:
		game.run.health = Data.max_health(game.run)
		game.run.energy = Data.max_energy(game.run)

func setup(owner_game) -> void:
	game = owner_game
	if not enabled: return
	var hud = game.hud
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",hud.panel_style(Color(.035,.04,.045,.96),hud.gold))
	hud.root.add_child(panel)
	hud.anchor(panel,Vector2.ZERO,Vector2(24,96),Vector2(310,0))
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation",4)
	panel.add_child(body)
	hud.label("DEBUG · Separate save",16,hud.gold,body)
	for action in ACTIONS:
		buttons[action[1]] = add_button(body,action[2],func(): execute(action[1]))
	hud.label("Jump to floor · Ctrl + 1–5",14,hud.cream,body)
	var floors = HBoxContainer.new()
	body.add_child(floors)
	for i in 5:
		add_button(floors,str(i+1),func(): execute("floor",i))
	add_button(floors,"Summit",func(): execute("floor",5))
	refresh()

func add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",14)
	for state in ["normal","hover","pressed","disabled"]:
		var style = game.hud.panel_style(Color(.08,.09,.1) if state=="normal" else Color(.18,.18,.17),Color(.35,.32,.25))
		style.set_content_margin_all(5)
		button.add_theme_stylebox_override(state,style)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func refresh() -> void:
	if not enabled or not is_instance_valid(panel): return
	if is_instance_valid(toggle): toggle.text = "DEBUG · God %s · P %s" % ["ON" if invulnerable else "OFF","hide" if panel.visible else "show"]
	buttons.god.text = "G · Invulnerable: %s" % ("ON" if invulnerable else "OFF")
	for action in buttons: buttons[action].disabled = not available(action)
	panel.reset_size()

func available(action: String) -> bool:
	return enabled and (game.mode=="playing" or action in ["panel","reset","restart","first","floor","boss","desert","town"])

func handle_key(event: InputEventKey) -> bool:
	if not enabled or not event.pressed or event.echo: return false
	var key = event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and key>=KEY_1 and key<=KEY_5:
		execute("floor",key-KEY_1)
		return true
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return false
	if key==KEY_P and event.shift_pressed:
		if game.playground != null: game.leave_playground()
		elif game.mode=="playing": game.enter_playground()
		return true
	# In the playground only the panel toggle applies; floor and run shortcuts
	# would tear it down.
	if game.playground != null and key != KEY_P: return false
	if key==KEY_P:
		execute("panel")
		return true
	for action in ACTIONS:
		if key==action[0]:
			execute(action[1])
			return true
	return false

func prepare_floor(index: int) -> void:
	game.run.floor = index
	game.run.place = "temple"
	game.run.dead = []
	game.run.drops = []
	game.run.phase = "playing"
	game.run.completed = false
	game.run.position = [0,9]
	game.run.health = Data.max_health(game.run)
	game.run.energy = Data.max_energy(game.run)

func jump(index: int) -> void:
	if index<0 or index>=Data.FLOORS: return
	prepare_floor(index)
	game.load_floor()
	game.save_run()
	game.toast("[Debug] %s" % ("Summit" if index==5 else "Floor %d" % (index+1)))

func execute(action: String, floor_index: int = 0) -> void:
	if not available(action): return
	match action:
		"panel": panel.visible = not panel.visible
		"god":
			invulnerable = not invulnerable
			game.toast("[Debug] Invulnerable %s" % ("on" if invulnerable else "off"))
		"refill":
			game.player.hp = Data.max_health(game.run)
			game.run.energy = Data.max_energy(game.run)
			game.toast("[Debug] Health and energy refilled")
		"axe", "bow":
			var index = 3 if action=="axe" else 2
			game.run.owned[index] = true
			game.toast("[Debug] %s granted · I: equipment" % Data.WEAPONS[index].capitalize())
		"kill":
			# Normal death handling retains loot, opens stairs and unlocks the crown.
			for enemy in game.enemies: enemy.die()
			game.toast("[Debug] Enemies cleared")
		"next":
			if game.run.floor<5: jump(game.run.floor+1)
			else: execute("kill")
		"boss":
			Data.gain_xp(game.run,maxi(0,Data.xp_at_level(Data.MAX_LEVEL)-int(game.run.xp)))
			prepare_floor(5)
			game.load_floor()
		"first": jump(0)
		"desert", "town":
			# The outdoor world: where a character starts, or inside the town gate.
			game.run.place = "world"
			game.run.completed = false
			game.run.phase = "playing"
			game.run.position = [-52,-15] if action=="desert" else [-186,0]
			game.load_floor()
			game.toast("[Debug] %s" % ("Desert" if action=="desert" else "Town"))
		"floor": jump(floor_index)
		"restart": jump(int(game.run.floor))
		"reset":
			invulnerable = false
			game.run = Data.new_run()
			game.load_floor()
		"ending":
			prepare_floor(5)
			game.load_floor()
			game.ending()
		_: return
	if action!="panel": game.save_run()
	refresh()
