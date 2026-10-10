extends RefCounted
## The character window, on the right side of the screen: one panel with a
## tab each for the hero's attributes, his skill trees and his inventory
## (what he wears and holds, round a figure of him, over the ten places of
## his bag); and the + buttons that stay above the orbs while there are
## points to spend, which open it at the attributes or the skills.
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const SkillIcon = preload("res://scripts/skill_icon.gd")
const Items = preload("res://scripts/items.gd")
const Visual = preload("res://scripts/visual.gd")
const Art = preload("res://scripts/assets.gd")
# A skill's square in the tree.
const NODE = 44
const SLOT_NAMES = ["RMB","1","2","3","4","LMB"]
var hud
var game
var dim = Color(.62,.6,.53)
var green = Color(.45,.92,.5)
var clock = 0.0
var stat_plus: Button
var skill_plus: Button
var stat_note: Label
var skill_note: Label
# The window, the tab it shows ("stats", "skills" or "bag"; "" while shut),
# and each tab's button and body. `stats`, `tree` and `bag` are the window
# while it shows that tab (null otherwise).
const TABS = ["stats","skills","bag"]
const TAB_TITLES = {"stats":"Attributes · C","skills":"Skills · K","bag":"Inventory · I"}
var window: PanelContainer
var tab = ""
var tab_buttons: Dictionary = {}
var bodies: Dictionary = {}
var stats: PanelContainer
var bag: PanelContainer
# An equipment slot's or a bag place's square in the inventory, by place
# ("head", "main", "bag:3": Items.at): {"frame","icon","name","place"}.
const SLOT = 54
var slots: Dictionary = {}
var slot_styles: Dictionary = {}
# The figure of the hero in the inventory: its viewport, the turntable it
# stands on, and the figure itself (dressed as he is).
var figure_port: SubViewport
var figure_stand: Node3D
var figure: Node3D
var figure_class = ""
var bag_summary: Label
# Behind the window while the inventory shows: an item dragged out onto it is
# dropped on the ground.
var drop_zone: Control
# The item the cursor is on (its place), and its tip.
var hovered_item = ""
var item_tip: PanelContainer
var item_tip_lines: Dictionary = {}
var stat_title: Label
var stat_xp: Label
var stat_xp_bar: ProgressBar
var stat_points: Label
var stat_values: Array = []
var stat_splits: Array = []
var stat_buttons: Array = []
var stat_summary: Label
var stat_reset: Button
var tree: PanelContainer
var tree_points: Label
var tree_totals: Dictionary = {}
# Skill id to its square: {"button","icon","rank","slot","state"}.
var nodes: Dictionary = {}
var styles: Dictionary = {}
var tip: PanelContainer
var tip_lines: Dictionary = {}
# The skill the cursor is on in the tree.
var hovered = ""

func setup(owner_hud) -> void:
	hud = owner_hud
	game = hud.game
	stat_plus = plus_button(false,func(): game.ProgressionUI.character(game))
	skill_plus = plus_button(true,func(): game.ProgressionUI.skills(game))
	stat_note = text("",12,hud.gold,hud.root)
	hud.anchor(stat_note,Vector2(0,1),Vector2(60,-247),Vector2(200,20))
	skill_note = text("",12,hud.gold,hud.root)
	hud.anchor(skill_note,Vector2(1,1),Vector2(-260,-247),Vector2(200,20))
	skill_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for state in ["locked","open","learned","maxed"]:
		var border: Color = {"locked":Color(.2,.2,.19),"open":Color(.5,.46,.36),"learned":hud.gold,"maxed":hud.gold}[state]
		for hover in [false,true]:
			var s = StyleBoxFlat.new()
			s.bg_color = Color(.16,.13,.07) if state=="maxed" else (Color(.09,.09,.085) if state!="locked" else Color(.05,.05,.05))
			if hover: s.bg_color = s.bg_color.lightened(.08)
			s.border_color = border
			s.set_border_width_all(2 if state in ["learned","maxed"] else 1)
			s.set_corner_radius_all(3)
			styles[state+("-hover" if hover else "")] = s

# Small readable text: the HUD's label with a thinner outline.
func text(value: String, font_size: int, color: Color, parent: Node) -> Label:
	var l = hud.label(value,font_size,color,parent)
	l.add_theme_constant_override("outline_size",2)
	return l

# The HUD's button, kept compact.
func small_button(value: String, font_size: int, callback: Callable) -> Button:
	var b = Button.new()
	b.text = value
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_color_override("font_disabled_color",Color(.4,.39,.36))
	for state in ["normal","hover","pressed","disabled"]:
		var style = hud.panel_style(Color(.2,.19,.16) if state in ["hover","pressed"] else Color(.09,.095,.1,.96),Color(.28,.27,.25) if state=="disabled" else Color(.5,.44,.3))
		style.set_content_margin_all(3)
		style.content_margin_left = 7; style.content_margin_right = 7
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(callback)
	return b

func plus_button(right: bool, callback: Callable) -> Button:
	var b = small_button("+",20,func():
		if game.mode in ["playing","character"] and not game.creating_character: callback.call())
	b.add_theme_color_override("font_color",hud.gold)
	for state in ["normal","hover","pressed"]:
		var style = hud.panel_style(Color(.3,.24,.12) if state!="normal" else Color(.13,.105,.06,.96),hud.gold)
		style.set_content_margin_all(0)
		style.set_corner_radius_all(4)
		b.add_theme_stylebox_override(state,style)
	hud.root.add_child(b)
	hud.anchor(b,Vector2(1 if right else 0,1),Vector2(-54 if right else 24,-252),Vector2(30,30))
	b.visible = false
	return b

func frame(width: float) -> PanelContainer:
	var p = PanelContainer.new()
	var style = hud.panel_style(Color(.03,.035,.04,.95),Color(.47,.4,.27))
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel",style)
	p.custom_minimum_size.x = width
	hud.root.add_child(p)
	return p

func stats_open() -> bool: return is_instance_valid(window) and tab=="stats"
func skills_open() -> bool: return is_instance_valid(window) and tab=="skills"
func inventory_open() -> bool: return is_instance_valid(window) and tab=="bag"
func any_open() -> bool: return is_instance_valid(window)

func close_stats() -> void:
	if stats_open(): close()
func close_skills() -> void:
	if skills_open(): close()
func close_inventory() -> void:
	if inventory_open(): close()

func close() -> void:
	if is_instance_valid(window): window.queue_free()
	if is_instance_valid(drop_zone): drop_zone.queue_free()
	window = null
	drop_zone = null
	stats = null
	tree = null
	bag = null
	tab = ""
	figure = null
	figure_port = null
	nodes.clear()
	slots.clear()
	tree_totals.clear()
	bodies.clear()
	tab_buttons.clear()
	unhover()
	unhover_item()

# With the window closed, play resumes.
func settle() -> void:
	if game.mode=="character" and not any_open() and not is_instance_valid(hud.modal): game.resume_game()

func open_stats() -> void: open("stats")
func open_skills() -> void: open("skills")
func open_inventory() -> void: open("bag")

# Opens the window at a tab, or turns it to that tab if it is open.
func open(wanted: String) -> void:
	if not is_instance_valid(window): build()
	tab = wanted
	for t in TABS:
		bodies[t].visible = t==tab
		for look in ["normal","hover","pressed"]: tab_buttons[t].add_theme_stylebox_override(look,tab_styles["on" if t==tab else ("off" if look=="normal" else "over")])
		tab_buttons[t].add_theme_color_override("font_color",hud.gold if t==tab else dim)
	stats = window if tab=="stats" else null
	tree = window if tab=="skills" else null
	bag = window if tab=="bag" else null
	if tab=="bag" and not is_instance_valid(drop_zone): make_drop_zone()
	elif tab!="bag" and is_instance_valid(drop_zone):
		drop_zone.queue_free()
		drop_zone = null
	if tab!="skills": unhover()
	if tab!="bag": unhover_item()
	window.reset_size()
	refresh()

var tab_styles: Dictionary = {}
func build() -> void:
	window = frame(0)
	var all = VBoxContainer.new()
	all.add_theme_constant_override("separation",8)
	window.add_child(all)
	if tab_styles.is_empty():
		for look in [["on",Color(.16,.13,.07),hud.gold],["off",Color(.06,.062,.066),Color(.3,.27,.2)],["over",Color(.12,.11,.09),Color(.5,.44,.3)]]:
			var style = hud.panel_style(look[1],look[2])
			style.set_content_margin_all(4)
			style.content_margin_left = 10; style.content_margin_right = 10
			tab_styles[look[0]] = style
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	all.add_child(row)
	for t in TABS:
		var b = Button.new()
		b.text = TAB_TITLES[t]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size",13)
		b.pressed.connect(func(): open(t))
		row.add_child(b)
		tab_buttons[t] = b
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size.x = 12
	row.add_child(gap)
	row.add_child(small_button("×",13,func():
		close()
		settle()))
	for t in TABS:
		var body = VBoxContainer.new()
		all.add_child(body)
		bodies[t] = body
	build_stats(bodies.stats)
	build_skills(bodies.skills)
	build_bag(bodies.bag)

func build_stats(body: VBoxContainer) -> void:
	body.add_theme_constant_override("separation",4)
	body.custom_minimum_size.x = 250
	stat_title = text("",14,hud.gold,body)
	stat_xp = text("",11,dim,body)
	stat_xp_bar = hud.bar(Color(.36,.58,.9),body)
	stat_xp_bar.custom_minimum_size = Vector2(0,4)
	stat_points = text("",12,hud.gold,body)
	stat_values.clear()
	stat_splits.clear()
	stat_buttons.clear()
	for i in 5:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		body.add_child(row)
		var names = VBoxContainer.new()
		names.add_theme_constant_override("separation",-2)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(names)
		text(Data.STATS[i],14,hud.cream,names)
		text(Data.stat_help(game.run,i).replace("; ","\n"),11,dim,names)
		# The attribute in all, and beneath it, where items add to it, how
		# much is his own (what he has spent points on) and how much theirs.
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation",-3)
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(column)
		var value = text("",16,hud.gold,column)
		value.custom_minimum_size.x = 26
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_values.append(value)
		var split = text("",10,Items.RARITY_COLORS.uncommon,column)
		split.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_splits.append(split)
		var plus = small_button("+",15,func(): add_stat(i))
		plus.custom_minimum_size = Vector2(26,26)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.tooltip_text = "Shift-click spends 5"
		row.add_child(plus)
		stat_buttons.append(plus)
	stat_summary = text("",11,hud.cream,body)
	stat_reset = small_button("Reset attributes and skills",11,respec)
	stat_reset.tooltip_text = "Free at a floor's entrance, out of combat"
	body.add_child(stat_reset)
	text("Shift-click + spends 5 · C closes",10,dim,body)

func build_skills(body: VBoxContainer) -> void:
	body.add_theme_constant_override("separation",6)
	tree_points = text("",12,hud.gold,body)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation",10)
	body.add_child(columns)
	var class_skills: Array = Book.all().values().filter(func(s): return s.class_id==game.run.class_id)
	# One row for each requirement, shared by the three trees.
	var gates: Array = []
	for s in class_skills:
		if not gate(s) in gates: gates.append(gate(s))
	gates.sort()
	var class_trees: Array = Book.trees(game.run.class_id)
	for t in class_trees:
		if t != class_trees[0]:
			var rule = ColorRect.new()
			rule.color = Color(.3,.27,.2)
			rule.custom_minimum_size.x = 1
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			columns.add_child(rule)
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation",6)
		columns.add_child(column)
		var heading = VBoxContainer.new()
		heading.add_theme_constant_override("separation",-3)
		column.add_child(heading)
		text(Book.TREE_TITLES[t],12,hud.cream,heading).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tree_totals[t] = text("",10,dim,heading)
		tree_totals[t].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for g in gates:
			var row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation",6)
			row.custom_minimum_size.y = NODE
			column.add_child(row)
			for s in class_skills:
				if s.tree==t and gate(s)==g: row.add_child(square(s.id))
	text("Click: learn · Right-click or 1–4: assign to that slot",10,dim,body).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# --- The inventory ---------------------------------------------------------------

# The figure of the hero stands in the middle, his head, chest and legs to
# its left and his hands and feet to its right, as he wears them; under it
# his two hands' weapons; and below, his bag.
func build_bag(body: VBoxContainer) -> void:
	body.add_theme_constant_override("separation",8)
	if slot_styles.is_empty():
		for look in [["empty",Color(.3,.27,.2)],["common",Color(.5,.46,.36)],["uncommon",Items.RARITY_COLORS.uncommon.darkened(.25)],["rare",Items.RARITY_COLORS.rare.darkened(.15)],["unique",Items.RARITY_COLORS.unique.darkened(.15)],["no",Color(.75,.22,.16)],["yes",Color(.5,.85,.5)]]:
			var style = hud.panel_style(Color(.055,.055,.06,.98),look[1])
			style.set_content_margin_all(0)
			style.set_corner_radius_all(3)
			if look[0] in ["no","yes"]: style.set_border_width_all(2)
			slot_styles[look[0]] = style
	var top = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation",8)
	body.add_child(top)
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation",8)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(left)
	for place in ["head","chest","legs"]: left.add_child(slot(place))
	var middle = VBoxContainer.new()
	middle.add_theme_constant_override("separation",6)
	top.add_child(middle)
	middle.add_child(make_figure())
	var hands = HBoxContainer.new()
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	hands.add_theme_constant_override("separation",10)
	middle.add_child(hands)
	for place in ["main","off"]: hands.add_child(slot(place))
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation",8)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(right)
	for place in ["hands","feet"]: right.add_child(slot(place))
	bag_summary = text("",11,hud.cream,body)
	bag_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid = GridContainer.new()
	grid.columns = Items.BAG_COLUMNS
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)
	for i in Items.BAG_SIZE: grid.add_child(slot("bag:%d" % i))
	text("Drag to equip, unequip or rearrange · Right-click: equip / take off\nDrag an item out of the window to drop it · X: other weapon",10,dim,body).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# One square: an equipment slot (its name shown while it is empty) or a
# place in the bag. It is dragged from and dropped on.
func slot(place: String) -> Control:
	var square_frame = Panel.new()
	square_frame.custom_minimum_size = Vector2(SLOT,SLOT)
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(3,3); icon.size = Vector2(SLOT-6,SLOT-6)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square_frame.add_child(icon)
	var name_label = text("",9,Color(.42,.41,.38),square_frame)
	name_label.position = Vector2(1,0); name_label.size = Vector2(SLOT-2,SLOT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	square_frame.set_drag_forwarding(func(_at): return drag_from(place),func(_at,data): return can_drop(place,data),func(_at,data): drop_on(place,data))
	square_frame.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and (event.button_index==MOUSE_BUTTON_RIGHT or (event.button_index==MOUSE_BUTTON_LEFT and event.double_click)): quick_move(place))
	square_frame.mouse_entered.connect(func(): hovered_item = place)
	square_frame.mouse_exited.connect(func():
		if hovered_item==place: unhover_item())
	slots[place] = {"frame":square_frame,"icon":icon,"name":name_label,"place":place,"shown":"?"}
	return square_frame

# An item's picture (tools/render_item_icons.gd makes them from its model).
# An item's picture: its base's (tools/render_item_icons.gd).
func item_icon(thing) -> Texture2D:
	var base: String = thing.get("base","") if thing is Dictionary else str(thing)
	var path = "res://assets/ui/items/%s.png" % base
	return load(path) if ResourceLoader.exists(path) else null

# The hero as he is dressed and armed, standing on a turntable (drag across
# him to turn him round).
func make_figure() -> Control:
	var holder = SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(190,268)
	holder.stretch = true
	figure_port = SubViewport.new()
	figure_port.own_world_3d = true
	figure_port.transparent_bg = true
	figure_port.msaa_3d = Viewport.MSAA_4X
	figure_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(figure_port)
	var scene = Node3D.new()
	figure_port.add_child(scene)
	var surroundings = WorldEnvironment.new()
	surroundings.environment = Environment.new()
	surroundings.environment.background_mode = Environment.BG_CLEAR_COLOR
	surroundings.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	surroundings.environment.ambient_light_color = Color(.9,.88,.84)
	surroundings.environment.ambient_light_energy = .55
	scene.add_child(surroundings)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,150,0)
	key.light_energy = 1.25
	scene.add_child(key)
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20,-40,0)
	rim.light_color = Color(.6,.7,1)
	rim.light_energy = .5
	scene.add_child(rim)
	var camera = Camera3D.new()
	camera.fov = 30
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(0,1.05,4.6),Vector3(0,.95,0))
	figure_stand = Node3D.new()
	figure_stand.rotation.y = .35
	scene.add_child(figure_stand)
	figure = Visual.new()
	figure_stand.add_child(figure)
	figure_class = game.run.class_id
	figure.setup(false,Color.WHITE,"",1.0,"",figure_class)
	figure.wear(game.run.equipment)
	holder.gui_input.connect(func(event):
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and is_instance_valid(figure_stand): figure_stand.rotation.y += event.relative.x*.012)
	holder.tooltip_text = "Drag to turn"
	return holder

func make_drop_zone() -> void:
	drop_zone = Control.new()
	drop_zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.root.add_child(drop_zone)
	hud.root.move_child(drop_zone,0)
	drop_zone.set_drag_forwarding(func(_at): return null,func(_at,data): return data is Dictionary and data.has("item_from"),func(_at,data):
		game.discard_item(data.item_from)
		refresh())

# What is dragged from a square: its item (nothing from an empty one).
func drag_from(place: String):
	var inst: Dictionary = Items.at(game.run,place)
	if inst.is_empty(): return null
	var shown = TextureRect.new()
	shown.texture = item_icon(inst)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shown.size = Vector2(SLOT,SLOT)
	shown.position = -shown.size*.5
	var carried = Control.new()
	carried.add_child(shown)
	if shown.texture == null: text(Items.name_of(inst),11,Items.color(inst),carried)
	slots[place].frame.set_drag_preview(carried)
	unhover_item()
	return {"item_from":place}

# Whether what is dragged may be put down on this square (tried on a copy).
func can_drop(place: String, data) -> bool:
	if not (data is Dictionary and data.has("item_from")): return false
	var trial = {"class_id":game.run.class_id,"equipment":game.run.equipment.duplicate(),"bag":game.run.bag.duplicate()}
	return Items.move(trial,data.item_from,place).is_empty()

func drop_on(place: String, data) -> void:
	var problem: String = game.move_item(data.item_from,place)
	if not problem.is_empty(): game.toast(problem)
	refresh()

# A right click (or a double click): an item in the bag is put on, one worn
# or held goes into the bag.
func quick_move(place: String) -> void:
	var inst: Dictionary = Items.at(game.run,place)
	if inst.is_empty(): return
	var to = ""
	if Items.in_bag(place):
		to = Items.slot_for(game.run,inst)
		# (Nothing to put it on: a key is only carried.)
		if to.is_empty(): return
	else:
		var room: int = Items.free_bag_slot(game.run)
		if room < 0:
			game.toast("No room in the bag.")
			return
		to = "bag:%d" % room
	var problem: String = game.move_item(place,to)
	if not problem.is_empty(): game.toast(problem)
	unhover_item()
	refresh()

func unhover_item() -> void:
	hovered_item = ""
	if is_instance_valid(item_tip): item_tip.visible = false

# The hovered item's details, beside the window.
func show_item_tip(place: String) -> void:
	var inst: Dictionary = Items.at(game.run,place)
	if inst.is_empty() or not slots.has(place):
		if is_instance_valid(item_tip): item_tip.visible = false
		return
	if not is_instance_valid(item_tip):
		item_tip = frame(250)
		item_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var body = VBoxContainer.new()
		body.add_theme_constant_override("separation",3)
		item_tip.add_child(body)
		for line in [["title",15,hud.gold],["kind",11,dim],["stats",12,hud.cream],["effect",12,Items.RARITY_COLORS.unique],["note",12,Color(1,.5,.4)],["hint",11,green]]:
			var l = text("",line[1],line[2],body)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 230
			item_tip_lines[line[0]] = l
	var about: Dictionary = Items.describe(inst,game.run.class_id)
	var lines = {"title":about.title,"kind":about.kind,"stats":"\n".join(about.stats),"effect":about.effect,"note":about.note}
	lines.hint = "Right-click: %s" % ("put on" if Items.in_bag(place) else "take off") if about.note.is_empty() else ""
	for key in item_tip_lines:
		item_tip_lines[key].text = lines[key]
		item_tip_lines[key].visible = not lines[key].is_empty()
	item_tip_lines.title.add_theme_color_override("font_color",Items.RARITY_COLORS[about.rarity])
	item_tip.visible = true
	item_tip.move_to_front()
	item_tip.reset_size()
	var height: float = item_tip.get_combined_minimum_size().y
	var at: Rect2 = slots[place].frame.get_global_rect()
	item_tip.position = Vector2(window.position.x-258,clampf(at.position.y,8,hud.root.size.y-height-8))

func refresh_bag() -> void:
	var r: Dictionary = game.run
	for place in slots:
		var s: Dictionary = slots[place]
		var inst: Dictionary = Items.at(r,place)
		if s.shown is Dictionary and s.shown == inst: continue
		s.shown = inst
		s.icon.texture = item_icon(inst) if not inst.is_empty() else null
		# An empty equipment slot says what goes there; an item with no picture, its name.
		s.name.text = (Items.SLOT_TITLES[place] if not Items.in_bag(place) else "") if inst.is_empty() else (Items.name_of(inst) if s.icon.texture == null else "")
		s.name.add_theme_color_override("font_color",Color(.42,.41,.38) if inst.is_empty() else Items.color(inst))
		s.frame.add_theme_stylebox_override("panel",slot_styles["empty" if inst.is_empty() else Items.rarity(inst)])
	if is_instance_valid(figure):
		if figure.worn != r.equipment: figure.wear(r.equipment)
	var span: Array = Data.span(r,Data.scaling_tag(Data.weapon(r)))
	var tag: String = Data.scaling_tag(Data.weapon(r))
	bag_summary.text = "Armor %s · %s%% less damage taken\n%s: %d–%d" % [Items.figure(Data.armor_points(r)),Items.figure(Data.armor(r)),"Spell damage" if tag=="spell" else "Attack damage",roundi(Data.damage_tag(r,tag,span[0])),roundi(Data.damage_tag(r,tag,span[1]))]

# Skills that open together share a row: by points in the tree, then by level.
func gate(s: Dictionary) -> int:
	return int(s.points)*100+int(s.unlock)

func square(id: String) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(NODE,NODE)
	b.focus_mode = Control.FOCUS_NONE
	var icon = SkillIcon.new()
	b.add_child(icon)
	icon.position = Vector2(9,5)
	icon.size = Vector2(NODE-18,NODE-18)
	var rank = text("",10,dim,b)
	rank.position = Vector2(0,NODE-16)
	rank.size = Vector2(NODE-4,14)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slot = text("",9,hud.cream,b)
	slot.position = Vector2(4,1)
	# A left click learns or raises a skill. The wizard's binds a learned
	# spell to LMB instead, as a right click binds one to RMB, when there is
	# no raising it (or always, with Shift held).
	b.pressed.connect(func():
		if left_binds(id): assign(id,Data.LEFT_SLOT)
		else: learn(id))
	b.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: assign(id,0))
	b.mouse_entered.connect(func(): hovered = id)
	b.mouse_exited.connect(func():
		if hovered==id: unhover())
	nodes[id] = {"button":b,"icon":icon,"rank":rank,"slot":slot,"state":""}
	return b

func left_binds(id: String) -> bool:
	if not Data.casts_left(game.run) or int(game.run.skills.get(id,0))<=0 or Book.all()[id].effect=="passive": return false
	return Input.is_physical_key_pressed(KEY_SHIFT) or not Book.can_learn(game.run,id)

func unhover() -> void:
	hovered = ""
	if is_instance_valid(tip): tip.visible = false

func tick(dt: float) -> void:
	clock += dt
	var r: Dictionary = game.run
	var shown: bool = game.mode in ["playing","character"] and not game.creating_character and game.playground == null
	stat_plus.visible = shown and r.points>0 and not stats_open()
	skill_plus.visible = shown and r.skill_points>0 and not skills_open()
	stat_note.visible = stat_plus.visible
	skill_note.visible = skill_plus.visible
	# The figure in the inventory breathes.
	if inventory_open() and is_instance_valid(figure): figure.advance(dt)
	stat_note.text = "%d attribute point%s" % [r.points,"" if r.points==1 else "s"]
	skill_note.text = "%d skill point%s" % [r.skill_points,"" if r.skill_points==1 else "s"]
	# The buttons breathe so they are noticed.
	var glow = Color(1,1,1,.8+.2*sin(clock*4.0))
	stat_plus.modulate = glow
	skill_plus.modulate = glow
	refresh()

func refresh() -> void:
	var r: Dictionary = game.run
	if any_open():
		# On the right of the screen (beside the playground's panel, there).
		var right: float = hud.root.size.x-24-(200 if game.playground != null else 0)
		window.position = Vector2(right-window.get_combined_minimum_size().x,84)
		for t in TABS:
			var spend: int = r.points if t=="stats" else (r.skill_points if t=="skills" else 0)
			tab_buttons[t].text = TAB_TITLES[t]+(" •" if spend>0 else "")
	if inventory_open():
		refresh_bag()
		if not hovered_item.is_empty(): show_item_tip(hovered_item)
	if stats_open():
		var capped: bool = r.level>=Data.MAX_LEVEL
		stat_title.text = "%s · LEVEL %d" % [r.class_id.to_upper(),r.level]
		stat_xp.text = "Maximum level" if capped else "%d / %d XP to level %d" % [r.xp-Data.xp_at_level(r.level),Data.XP_STEPS[r.level-1],r.level+1]
		stat_xp_bar.max_value = 1 if capped else Data.XP_STEPS[r.level-1]
		stat_xp_bar.value = 1 if capped else r.xp-Data.xp_at_level(r.level)
		stat_points.text = "%d attribute point%s to spend" % [r.points,"" if r.points==1 else "s"]
		stat_points.add_theme_color_override("font_color",hud.gold if r.points>0 else dim)
		for i in 5:
			var gear: int = Data.stat(r,i)-int(r.stats[i])
			stat_values[i].text = str(Data.stat(r,i))
			stat_splits[i].text = "%d base · %+d items" % [r.stats[i],gear] if gear != 0 else ""
			stat_splits[i].visible = gear != 0
			stat_buttons[i].disabled = r.points<=0
		stat_summary.text = Data.in_his_words(r,"Health %d · Energy %d · +%.1f energy/s\nArmor %s (%s%% less damage) · Critical strike %s%%\nAttack speed +%s%%%s") % [Data.max_health(r),Data.max_energy(r),Data.energy_regen(r),Items.figure(Data.armor_points(r)),Items.figure(Data.armor(r)),game.skills.figure(Data.crit_chance(r)),game.skills.figure(game.skills.basic_speed(Data.weapon(r)))," · %s attacks/s" % game.skills.figure(game.skills.attacks_a_second(Data.weapon(r))) if Data.weapon(r)!=4 else ""]
		stat_reset.disabled = not game.safe_checkpoint()
	if skills_open():
		tree_points.text = "%d point%s to spend" % [r.skill_points,"" if r.skill_points==1 else "s"]
		tree_points.add_theme_color_override("font_color",hud.gold if r.skill_points>0 else dim)
		for t in tree_totals:
			var spent: int = Book.tree_points(r.skills,t)
			tree_totals[t].text = "%d point%s" % [spent,"" if spent==1 else "s"]
		for id in nodes:
			var n: Dictionary = nodes[id]
			var s: Dictionary = Book.all()[id]
			var rank = int(r.skills.get(id,0))
			var state = "maxed" if rank>=s.max_rank else ("learned" if rank>0 else ("open" if Book.locked(r,id).is_empty() else "locked"))
			n.icon.show_skill(id,{"locked":Color(.36,.36,.35),"open":hud.cream,"learned":hud.gold,"maxed":Color(1,.86,.5)}[state])
			n.rank.text = "%d/%d" % [rank,s.max_rank]
			n.rank.add_theme_color_override("font_color",green if Book.can_learn(r,id) else (hud.gold if rank>0 else Color(.42,.41,.38)))
			var slot: int = r.hotbar.find(id)
			n.slot.text = SLOT_NAMES[slot] if slot>=0 else ""
			if n.state != state:
				n.state = state
				for look in ["normal","hover","pressed"]: n.button.add_theme_stylebox_override(look,styles[state+("" if look=="normal" else "-hover")])
		if not hovered.is_empty() and nodes.has(hovered): show_tip(hovered)

# The hovered skill's details: beside the tree, or above a hotbar slot when
# `slot` (that slot's rect) is given. ATTACK is the normal attack's slot.
const ATTACK = "attack"
func show_tip(id: String, slot: Rect2 = Rect2()) -> void:
	var on_hotbar: bool = slot.has_area()
	if not is_instance_valid(tip):
		tip = frame(270)
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var body = VBoxContainer.new()
		body.add_theme_constant_override("separation",3)
		tip.add_child(body)
		for line in [["title",15,hud.gold],["kind",11,dim],["now",12,hud.cream],["damage",12,Color(1,.78,.45)],["crit",12,Color(1,.78,.45)],["crit_damage",12,Color(1,.78,.45)],["next",12,dim],["lock",12,Color(1,.5,.4)],["hint",11,green]]:
			var l = text("",line[1],line[2],body)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 250
			tip_lines[line[0]] = l
	var lines: Dictionary
	if id==ATTACK: lines = attack_lines()
	else: lines = skill_lines(id,on_hotbar)
	for key in tip_lines:
		tip_lines[key].text = lines.get(key,"")
		tip_lines[key].visible = not lines.get(key,"").is_empty()
	place_tip(id,slot)

# The normal attack's tip: what the weapon in hand hits for.
func attack_lines() -> Dictionary:
	var weapon = Data.weapon(game.run)
	var lines = {"title":"%s · Attack" % (Items.main(game.run).name if not Items.main(game.run).is_empty() else "Bare hands"),"kind":Data.in_his_words(game.run,"LMB · No energy cost · %s attacks/s" % game.skills.figure(game.skills.attacks_a_second(weapon)))}
	lines.merge(game.skills.crit_numbers(weapon))
	lines.damage = "Damage: "+game.skills.span(100.0,Data.scaling_tag(weapon))
	return lines

func skill_lines(id: String, on_hotbar: bool) -> Dictionary:
	var r: Dictionary = game.run
	var s: Dictionary = Book.all()[id]
	var rank = int(r.skills.get(id,0))
	var active: bool = s.effect!="passive"
	var lines = {"title":"%s · %d/%d" % [s.title,rank,s.max_rank]}
	lines.kind = "Passive" if not active else "Active · %d %s" % [game.skills.cost(id),Data.energy_word(r)]
	if active and s.requirement!="any": lines.kind += " · needs %s" % {"melee":"a melee weapon","shield":"a shield","bow":"a bow","dagger":"a dagger","bow_dagger":"a bow or dagger"}[s.requirement]
	lines.now = Data.in_his_words(r,Book.describe(id,maxi(1,rank)))
	# What it hits for now, by the hero's attributes and passives.
	lines.merge(game.skills.damage_summary(id,rank))
	lines.next = "Next rank: "+Data.in_his_words(r,Book.describe(id,rank+1)) if rank>0 and rank<s.max_rank else ""
	lines.lock = Book.locked(r,id)
	if lines.lock.is_empty() and rank<s.max_rank and rank>=Book.rank_cap(id,int(r.level)): lines.lock = "Next rank requires level %d." % (s.unlock+rank*3)
	if on_hotbar and lines.lock.is_empty(): lines.lock = game.skills.reason(id)
	lines.hint = ""
	if Book.can_learn(r,id): lines.hint = "Click to learn" if rank==0 else "Click to raise to rank %d" % (rank+1)
	if active and rank>0 and Data.casts_left(r):
		lines.hint += ("\n" if not lines.hint.is_empty() else "")+("Shift-click, right-click or 1–4: assign to LMB, RMB or that key" if Book.can_learn(r,id) else "Click, right-click or 1–4: assign to LMB, RMB or that key")
	elif active and rank>0: lines.hint += ("\n" if not lines.hint.is_empty() else "")+"Right-click or 1–4: assign to RMB or that key"
	if on_hotbar: lines.hint = ""
	return lines

func place_tip(id: String, slot: Rect2) -> void:
	var on_hotbar: bool = slot.has_area()
	tip.visible = true
	tip.move_to_front()
	tip.reset_size()
	var height: float = tip.get_combined_minimum_size().y
	if on_hotbar:
		var width: float = tip.get_combined_minimum_size().x
		tip.position = Vector2(clampf(slot.get_center().x-width*.5,8,hud.root.size.x-width-8),maxf(8,slot.position.y-height-8))
		return
	var at: Rect2 = nodes[id].button.get_global_rect()
	tip.position = Vector2(tree.position.x-278,clampf(at.position.y,8,hud.root.size.y-height-8))

# Shift-click spends five at once.
func add_stat(index: int) -> void:
	var amount: int = mini(int(game.run.points),5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)
	if amount<=0: return
	game.run.stats[index] += amount
	game.run.points -= amount
	game.player.max_hp = Data.max_health(game.run)
	game.save_run()
	refresh()

func respec() -> void:
	if not game.safe_checkpoint(): return
	Data.respec(game.run)
	game.player.max_hp = Data.max_health(game.run)
	game.player.hp = minf(game.player.hp,game.player.max_hp)
	game.skills.reset()
	game.save_run()
	refresh()

func learn(id: String) -> void:
	if not Book.learn(game.run,id): return
	var s: Dictionary = Book.all()[id]
	# A new active skill takes the first empty slot (the wizard's LMB first:
	# it is his attack).
	if s.effect!="passive" and not id in game.run.hotbar:
		var order: Array = [Data.LEFT_SLOT,0,1,2,3,4] if Data.casts_left(game.run) else [0,1,2,3,4]
		for slot in order:
			if game.run.hotbar[slot]=="":
				game.run.hotbar[slot] = id
				break
	game.save_run()
	refresh()

# Puts a learned active skill on RMB (0), 1 to 4, or (the wizard's) LMB, in
# combat or out.
func assign(id: String, slot: int) -> void:
	var run: Dictionary = game.run
	if slot==Data.LEFT_SLOT and not Data.casts_left(run): return
	if not Book.all().has(id) or int(run.skills.get(id,0))<=0 or Book.all()[id].effect=="passive" or run.hotbar[slot]==id: return
	for j in run.hotbar.size():
		if run.hotbar[j]==id: run.hotbar[j] = ""
	run.hotbar[slot] = id
	game.save_run()
	refresh()
