extends RefCounted
## The attribute panel (left side of the screen) and the skill tree panel
## (right side), and the + buttons that stay above the orbs while there are
## points to spend: attributes on the left, skills on the right.
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")
const SkillIcon = preload("res://scripts/skill_icon.gd")
# A skill's square in the tree.
const NODE = 44
const SLOT_NAMES = ["RMB","1","2","3","4"]
var hud
var game
var dim = Color(.62,.6,.53)
var green = Color(.45,.92,.5)
var clock = 0.0
var stat_plus: Button
var skill_plus: Button
var stat_note: Label
var skill_note: Label
var stats: PanelContainer
var stat_title: Label
var stat_xp: Label
var stat_xp_bar: ProgressBar
var stat_points: Label
var stat_values: Array = []
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

# A panel's title row with a close button; returns the row.
func header(parent: Node, title: String, closer: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var name_label = text(title,14,hud.gold,row)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(small_button("×",13,func():
		closer.call()
		settle()))
	return row

func stats_open() -> bool: return is_instance_valid(stats)
func skills_open() -> bool: return is_instance_valid(tree)
func any_open() -> bool: return stats_open() or skills_open()

func close_stats() -> void:
	if stats_open(): stats.queue_free()
	stats = null

func close_skills() -> void:
	if skills_open(): tree.queue_free()
	tree = null
	nodes.clear()
	tree_totals.clear()
	unhover()

func close() -> void:
	close_stats()
	close_skills()

# With the last panel closed, play resumes.
func settle() -> void:
	if game.mode=="character" and not any_open() and not is_instance_valid(hud.modal): game.resume_game()

func open_stats() -> void:
	if stats_open(): return
	stats = frame(244)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation",4)
	stats.add_child(body)
	stat_title = header(body,"",close_stats).get_child(0)
	stat_xp = text("",11,dim,body)
	stat_xp_bar = hud.bar(Color(.36,.58,.9),body)
	stat_xp_bar.custom_minimum_size = Vector2(0,4)
	stat_points = text("",12,hud.gold,body)
	stat_values.clear()
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
		text(Data.STAT_HELP[i].replace("; ","\n"),11,dim,names)
		var value = text("",16,hud.gold,row)
		value.custom_minimum_size.x = 26
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_values.append(value)
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
	refresh()

func open_skills() -> void:
	if skills_open(): return
	tree = frame(0)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation",6)
	tree.add_child(body)
	var head = header(body,"SKILLS",close_skills)
	tree_points = text("",12,hud.gold,head)
	head.move_child(tree_points,1)
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
	refresh()

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
	b.pressed.connect(func(): learn(id))
	b.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: assign(id,0))
	b.mouse_entered.connect(func(): hovered = id)
	b.mouse_exited.connect(func():
		if hovered==id: unhover())
	nodes[id] = {"button":b,"icon":icon,"rank":rank,"slot":slot,"state":""}
	return b

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
	stat_note.text = "%d attribute point%s" % [r.points,"" if r.points==1 else "s"]
	skill_note.text = "%d skill point%s" % [r.skill_points,"" if r.skill_points==1 else "s"]
	# The buttons breathe so they are noticed.
	var glow = Color(1,1,1,.8+.2*sin(clock*4.0))
	stat_plus.modulate = glow
	skill_plus.modulate = glow
	refresh()

func refresh() -> void:
	var r: Dictionary = game.run
	if stats_open():
		# Beside the debug panel when it is showing.
		var left = 24.0
		if game.debug.enabled and is_instance_valid(game.debug.panel) and game.debug.panel.visible: left = game.debug.panel.position.x+game.debug.panel.size.x+10
		stats.position = Vector2(left,84)
		var capped: bool = r.level>=Data.MAX_LEVEL
		stat_title.text = "%s · LEVEL %d" % [r.class_id.to_upper(),r.level]
		stat_xp.text = "Maximum level" if capped else "%d / %d XP to level %d" % [r.xp-Data.xp_at_level(r.level),Data.XP_STEPS[r.level-1],r.level+1]
		stat_xp_bar.max_value = 1 if capped else Data.XP_STEPS[r.level-1]
		stat_xp_bar.value = 1 if capped else r.xp-Data.xp_at_level(r.level)
		stat_points.text = "%d attribute point%s to spend" % [r.points,"" if r.points==1 else "s"]
		stat_points.add_theme_color_override("font_color",hud.gold if r.points>0 else dim)
		for i in 5:
			stat_values[i].text = str(r.stats[i])
			stat_buttons[i].disabled = r.points<=0
		stat_summary.text = "Health %d · Energy %d · +%.1f energy/s\nAttack speed +%s%% · Critical strike %s%%" % [Data.max_health(r),Data.max_energy(r),Data.energy_regen(r),game.skills.figure(game.skills.basic_speed(int(r.weapon))),game.skills.figure(Data.crit_chance(r))]
		stat_reset.disabled = not game.safe_checkpoint()
	if skills_open():
		var right: float = hud.root.size.x-24-(200 if game.playground != null else 0)
		tree.position = Vector2(right-tree.get_combined_minimum_size().x,140)
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
	var weapon = int(game.run.weapon)
	var lines = {"title":"%s · Attack" % Data.WEAPONS[weapon].capitalize(),"kind":"LMB · No energy cost"}
	lines.merge(game.skills.crit_numbers(weapon))
	lines.damage = "Damage: "+game.skills.span(100.0,Data.scaling_tag(weapon))
	return lines

func skill_lines(id: String, on_hotbar: bool) -> Dictionary:
	var r: Dictionary = game.run
	var s: Dictionary = Book.all()[id]
	var rank = int(r.skills.get(id,0))
	var active: bool = s.effect!="passive"
	var lines = {"title":"%s · %d/%d" % [s.title,rank,s.max_rank]}
	lines.kind = "Passive" if not active else "Active · %d energy" % game.skills.cost(id)
	if active and s.requirement!="any": lines.kind += " · needs %s" % {"melee":"a melee weapon","shield":"sword and shield","bow":"a bow","staff":"a staff","dagger":"a dagger","bow_dagger":"a bow or dagger"}[s.requirement]
	lines.now = Book.describe(id,maxi(1,rank))
	# What it hits for now, by the hero's attributes and passives.
	lines.merge(game.skills.damage_summary(id,rank))
	lines.next = "Next rank: "+Book.describe(id,rank+1) if rank>0 and rank<s.max_rank else ""
	lines.lock = Book.locked(r,id)
	if lines.lock.is_empty() and rank<s.max_rank and rank>=Book.rank_cap(id,int(r.level)): lines.lock = "Next rank requires level %d." % (s.unlock+rank*3)
	if on_hotbar and lines.lock.is_empty(): lines.lock = game.skills.reason(id)
	lines.hint = ""
	if Book.can_learn(r,id): lines.hint = "Click to learn" if rank==0 else "Click to raise to rank %d" % (rank+1)
	if active and rank>0: lines.hint += ("\n" if not lines.hint.is_empty() else "")+"Right-click or 1–4: assign to RMB or that key"
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
	# A new active skill takes the first empty slot.
	if s.effect!="passive" and not id in game.run.hotbar:
		var empty: int = game.run.hotbar.find("")
		if empty>=0: game.run.hotbar[empty] = id
	game.save_run()
	refresh()

# Puts a learned active skill on RMB (0) or 1 to 4, in combat or out.
func assign(id: String, slot: int) -> void:
	var run: Dictionary = game.run
	if not Book.all().has(id) or int(run.skills.get(id,0))<=0 or Book.all()[id].effect=="passive" or run.hotbar[slot]==id: return
	for j in 3:
		if run.hotbar[j]==id: run.hotbar[j] = ""
	run.hotbar[slot] = id
	game.save_run()
	refresh()
