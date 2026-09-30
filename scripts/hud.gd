extends CanvasLayer
const Data = preload("res://scripts/data.gd")
var game
var root: Control
var objective: Label
var health: ColorRect
var energy: ColorRect
var hp_text: Label
var en_text: Label
var difficulty: Label
var notice: Label
var abilities: Label
var status: Label
var experience: ProgressBar
var character_info: Label
var direction: Label
# Points toward the nearest remaining statue once five or fewer are left.
var enemy_arrow: Polygon2D
const ARROW_SHOW_AT = 5
const ARROW_RADIUS = 92.0
var recovery: Label
var prompt: Label
var boss_bar: ProgressBar
var boss_name: Label
var hover_health: ProgressBar
# One amber cast bar over each Oracle while it casts a fireball.
var cast_bars: Array = []
var modal: PanelContainer
var modal_body: VBoxContainer
var weapon_slots: Array[Button] = []
var weapon_icons: Array[TextureRect] = []
var weapon_names: Array[Label] = []
var notice_time = 0.0
var gold = Color(.91,.75,.45)
var cream = Color(.93,.91,.82)
var selected_style: StyleBoxFlat
var idle_style: StyleBoxFlat

func anchor(control: Control, point: Vector2, offset: Vector2, dimensions: Vector2) -> void:
	control.anchor_left = point.x
	control.anchor_right = point.x
	control.anchor_top = point.y
	control.anchor_bottom = point.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x+dimensions.x
	control.offset_bottom = offset.y+dimensions.y

func setup(owner_game) -> void:
	game = owner_game
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color","Label",cream)
	theme.set_color("font_outline_color","Label",Color(.025,.02,.015))
	theme.set_constant("outline_size","Label",4)
	theme.set_color("font_color","Button",cream)
	for state in ["normal","hover","pressed","focus"]:
		theme.set_stylebox(state,"Button",panel_style(Color(.12,.13,.14,.96) if state=="normal" else Color(.24,.23,.20),gold))
	root.theme = theme
	hover_health = bar(Color(.88,.055,.04),root)
	hover_health.custom_minimum_size = Vector2(72,5)
	hover_health.size = Vector2(72,5)
	hover_health.z_index = 1
	hover_health.visible = false
	var hover_background = StyleBoxFlat.new()
	hover_background.bg_color = Color(.045,.015,.015,.96)
	hover_background.border_color = Color(.18,.08,.07)
	hover_background.set_border_width_all(1)
	hover_background.set_corner_radius_all(2)
	hover_health.add_theme_stylebox_override("background",hover_background)
	var left = make_orb(false)
	health = left.orb; hp_text = left.value
	var right = make_orb(true)
	energy = right.orb; en_text = right.value
	recovery = label("",13,cream,root)
	anchor(recovery,Vector2(0,1),Vector2(20,-26),Vector2(180,22))
	recovery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var energy_caption = label("RMB + 1 / 2 · Skills",13,cream,root)
	anchor(energy_caption,Vector2(1,1),Vector2(-208,-26),Vector2(188,22))
	energy_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective = label("",20,gold,root)
	anchor(objective,Vector2(1,0),Vector2(-464,22),Vector2(440,28))
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status = label("",17,cream,root)
	anchor(status,Vector2(1,0),Vector2(-464,54),Vector2(440,25))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	difficulty = label("",16,cream,root)
	anchor(difficulty,Vector2(1,0),Vector2(-464,81),Vector2(440,24))
	difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	direction = label("",14,Color(.7,.68,.59),root)
	anchor(direction,Vector2(1,0),Vector2(-464,108),Vector2(440,24))
	direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	character_info = label("",15,gold,root)
	anchor(character_info,Vector2.ZERO,Vector2(24,24),Vector2(370,24))
	experience = bar(Color(.36,.58,.9),root)
	anchor(experience,Vector2.ZERO,Vector2(24,51),Vector2(300,8))
	for i in 3:
		var b = Button.new()
		b.text = ["C · Character","K · Skills","I · Equipment"][i]
		root.add_child(b)
		anchor(b,Vector2.ZERO,Vector2(24+i*80,66),Vector2(76,20))
		b.add_theme_font_size_override("font_size",9)
		b.focus_mode = Control.FOCUS_NONE
		# The HUD's button style has generous padding; keep these compact.
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style = b.get_theme_stylebox(state)
			if style == null: continue
			style = style.duplicate()
			style.content_margin_left = 6; style.content_margin_right = 6
			style.content_margin_top = 2; style.content_margin_bottom = 2
			b.add_theme_stylebox_override(state,style)
		b.pressed.connect(func():
			if game.mode!="playing": return
			if i==0: game.ProgressionUI.character(game)
			elif i==1: game.ProgressionUI.skills(game)
			else: game.ProgressionUI.equipment(game))
	var row = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	anchor(row,Vector2(.5,1),Vector2(-118,-124),Vector2(236,56))
	idle_style = panel_style(Color(.035,.032,.028,.94),Color(.37,.31,.21))
	selected_style = panel_style(Color(.15,.115,.065,.97),gold)
	selected_style.set_border_width_all(2)
	selected_style.shadow_color = Color(.8,.49,.13,.24)
	selected_style.shadow_size = 5
	for i in 4:
		var slot = Button.new()
		row.add_child(slot)
		slot.position = Vector2(i*60,0)
		slot.size = Vector2(56,56)
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = "Assign skills in K"
		slot.add_theme_stylebox_override("disabled",idle_style)
		slot.pressed.connect(func():
			if game.mode!="playing": return
			var at: Vector3 = game.target.position if is_instance_valid(game.target) and not game.target.dead else game.player.position+game.player.forward()*4
			if i==0: game.attack(false,at)
			else: game.skills.cast_slot(i-1,at))
		weapon_slots.append(slot)
		var icon = TextureRect.new()
		icon.texture = load("res://assets/textures/seal.png")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(11,10); icon.size = Vector2(34,34)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		weapon_icons.append(icon)
		var hotkey = label(["LMB","RMB","1","2"][i],12,gold,slot)
		hotkey.position = Vector2(5,2)
		var name_label = label("",10,cream,slot)
		name_label.position = Vector2(2,39); name_label.size = Vector2(52,15)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 1
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_names.append(name_label)
	abilities = label("",16,gold,root)
	anchor(abilities,Vector2(.5,1),Vector2(-330,-61),Vector2(660,23))
	abilities.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls = label("LMB Move / Attack · RMB + 1 / 2 Skills · SPACE Evade · Q Flask",13,Color(.7,.68,.60),root)
	anchor(controls,Vector2(.5,1),Vector2(-350,-30),Vector2(700,22))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = label("",19,gold,root)
	anchor(prompt,Vector2(.5,1),Vector2(-400,-177),Vector2(800,28))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = label("",21,cream,root)
	anchor(notice,Vector2(.5,1),Vector2(-390,-290),Vector2(780,65))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_name = label("THE CROWNED STATUE",18,gold,root)
	anchor(boss_name,Vector2(.5,0),Vector2(-200,22),Vector2(400,27))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = bar(Color(.71,.36,.18),root)
	anchor(boss_bar,Vector2(.5,0),Vector2(-200,55),Vector2(400,10))
	boss_bar.visible = false; boss_name.visible = false

func make_orb(is_energy: bool) -> Dictionary:
	var holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(holder)
	anchor(holder,Vector2(1 if is_energy else 0,1),Vector2(-204 if is_energy else 24,-214),Vector2(180,182))
	var title = label("ENERGY" if is_energy else "HEALTH",16,gold,holder)
	title.size = Vector2(180,24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var orb = ColorRect.new()
	orb.position = Vector2(10,25); orb.size = Vector2(160,160)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/orb.gdshader")
	material.set_shader_parameter("liquid",Color(.04,.38,.11) if is_energy else Color(.78,.035,.06))
	orb.material = material
	holder.add_child(orb)
	var value = label("",18,cream,holder)
	value.position = Vector2(0,94); value.size = Vector2(180,28)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return {"orb":orb,"value":value}

func panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(16)
	s.corner_radius_top_left = 4
	s.corner_radius_bottom_right = 4
	return s

func label(value: String, font_size: int, color: Color, parent: Node) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func bar(color: Color, parent: Node) -> ProgressBar:
	var p = ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(300,9)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(.12,.16,.17)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	p.add_theme_stylebox_override("background",bg)
	p.add_theme_stylebox_override("fill",fill)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func tick(dt: float) -> void:
	game.debug.refresh()
	show_cast_bars()
	var r: Dictionary = game.run
	var maximum_health = Data.max_health(r)
	var maximum_energy = Data.max_energy(r)
	health.material.set_shader_parameter("fill",clampf(game.player.hp/maximum_health,0,1))
	energy.material.set_shader_parameter("fill",clampf(r.energy/maximum_energy,0,1))
	hp_text.text = "%d / %d" % [maxf(0,game.player.hp),maximum_health]
	en_text.text = "%d / %d" % [r.energy,maximum_energy]
	objective.text = "%s · %s" % ["SUMMIT" if r.floor==5 else "FLOOR %d" % (r.floor+1),Data.FLOORS[r.floor].to_upper()]
	difficulty.text = "%s mode" % Data.DIFFICULTIES[r.difficulty]
	var remaining: int = game.remaining()
	status.text = "%d statues remain" % remaining if remaining>0 else ("The crown awaits" if r.floor==5 else "The way up is open")
	direction.text = "" if r.floor<5 else "Intercept the crown's offerings"
	point_to_nearest_enemy()
	character_info.text = "%s · Lv %d · %d XP · %d attribute / %d skill points" % [r.class_id.capitalize(),r.level,r.xp,r.points,r.skill_points]
	experience.max_value = Data.XP_STEPS[r.level-1] if r.level<30 else 1
	experience.value = r.xp-Data.xp_at_level(r.level) if r.level<30 else 1
	weapon_slots[0].disabled = game.player.dead
	weapon_slots[0].tooltip_text = "LMB · %s basic attack · no energy cost" % Data.WEAPONS[r.weapon].capitalize()
	weapon_slots[0].add_theme_stylebox_override("normal",idle_style)
	var weapon_icon_path = "res://assets/ui/weapon-%s.png" % Data.WEAPONS[r.weapon]
	weapon_icons[0].texture = load(weapon_icon_path) if ResourceLoader.exists(weapon_icon_path) else load("res://assets/textures/seal.png")
	weapon_icons[0].modulate = Color.WHITE
	weapon_names[0].text = "Attack"
	for i in range(1,4):
		var id: String = r.hotbar[i-1]
		var problem: String = game.skills.reason(id)
		weapon_slots[i].disabled = not problem.is_empty()
		weapon_slots[i].tooltip_text = problem if not problem.is_empty() else "%s · %.0f energy" % [game.Book.all()[id].title,game.skills.cost(id)]
		weapon_slots[i].add_theme_stylebox_override("normal",selected_style if i==1 else idle_style)
		weapon_icons[i].modulate = Color(.5,.65,1,.25) if r.class_id=="wizard" else Color(1,.8,.4,.2)
		weapon_names[i].text = "Empty" if id.is_empty() else game.Book.all()[id].title
	abilities.text = "%s · K: learn / assign skills · I: equipment" % Data.WEAPONS[r.weapon].capitalize()
	recovery.text = "Q · Heal 60%% · 60 energy%s" % [" · %ds" % ceili(game.heal_cd) if game.heal_cd>0 else ""]
	prompt.text = ""
	if game.mode == "playing":
		if game.crown_available and game.player.position.distance_to(game.crown_position)<3: prompt.text = "E  ·  Claim the emperor's crown"
		elif remaining==0 and r.floor<5: prompt.text = "The stairway is open. %s" % ("Press E to ascend" if game.player.position.distance_to(game.world.exit_point)<4 else "Follow the jade seal to the stairs")
		elif game.player.position.distance_to(game.world.spawn)<2: prompt.text = "E · Rest · C attributes · K skills"
	boss_bar.visible = is_instance_valid(game.boss) and not game.boss.dead
	boss_name.visible = boss_bar.visible
	if boss_bar.visible:
		boss_bar.max_value = game.boss.max_hp
		boss_bar.value = game.boss.hp
	notice_time -= dt
	notice.visible = notice_time > 0

func toast(value: String) -> void:
	notice.text = value
	notice_time = 5

func cast_bar() -> ProgressBar:
	var p = bar(Color(1,.64,.18),root)
	p.custom_minimum_size = Vector2(64,6)
	p.size = Vector2(64,6)
	p.max_value = 1.0
	p.step = 0.0
	p.z_index = 1
	var background = StyleBoxFlat.new()
	background.bg_color = Color(.05,.03,.015,.94)
	background.border_color = Color(.34,.2,.08)
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	p.add_theme_stylebox_override("background",background)
	return p

func show_cast_bars() -> void:
	var casting: Array = game.enemies.filter(func(e): return e.kind=="wizard" and not e.dead and e.visible and e.cast_total>0 and e.windup>0)
	while cast_bars.size()<casting.size(): cast_bars.append(cast_bar())
	for i in cast_bars.size():
		var shown: bool = i<casting.size()
		cast_bars[i].visible = shown
		if not shown: continue
		var caster = casting[i]
		# Pushback can add more than the cast has left; the bar then sits empty.
		cast_bars[i].value = clampf(1.0-caster.windup/caster.cast_total,0.0,1.0)
		# Just above where the hover health bar sits.
		var head: Vector3 = caster.position+Vector3.UP*caster.config.size*2.25
		cast_bars[i].position = game.world.camera.unproject_position(head)-Vector2(cast_bars[i].size.x*.5,24)

func show_enemy_hover(enemy) -> void:
	hover_health.visible = is_instance_valid(enemy) and not enemy.dead
	if not hover_health.visible: return
	hover_health.max_value = enemy.max_hp
	hover_health.value = clampf(enemy.hp,0,enemy.max_hp)
	var head: Vector3 = enemy.position+Vector3.UP*enemy.config.size*2.25
	var screen: Vector2 = game.world.camera.unproject_position(head)
	hover_health.position = screen-Vector2(hover_health.size.x*.5,12)

func close_modal() -> void:
	if is_instance_valid(modal):
		root.remove_child(modal)
		modal.queue_free()
	modal = null

func dialog(title: String, subtitle: String) -> void:
	close_modal()
	modal = PanelContainer.new()
	modal.custom_minimum_size = Vector2(660,560)
	modal.add_theme_stylebox_override("panel",panel_style(Color(.035,.06,.07,.98),gold))
	root.add_child(modal)
	anchor(modal,Vector2(.5,.5),Vector2(-330,-280),Vector2(660,560))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation",16)
	scroll.add_child(modal_body)
	label(title,30,gold,modal_body)
	var sub = label(subtitle,18,cream,modal_body)
	sub.custom_minimum_size.x = 620
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func make_enemy_arrow() -> void:
	enemy_arrow = Polygon2D.new()
	enemy_arrow.polygon = PackedVector2Array([Vector2(18,0),Vector2(-10,-11),Vector2(-4,0),Vector2(-10,11)])
	enemy_arrow.color = Color(.95,.72,.3,.92)
	var outline = Line2D.new()
	outline.points = PackedVector2Array([Vector2(18,0),Vector2(-10,-11),Vector2(-4,0),Vector2(-10,11),Vector2(18,0)])
	outline.width = 2.0
	outline.default_color = Color(.12,.07,.02,.9)
	enemy_arrow.add_child(outline)
	enemy_arrow.visible = false
	root.add_child(enemy_arrow)

# Circles the hero on screen, pointing at the nearest statue still standing.
func point_to_nearest_enemy() -> void:
	if enemy_arrow == null: make_enemy_arrow()
	var remaining: int = game.remaining()
	enemy_arrow.visible = false
	# Not on the summit, where the only statue left is the Crowned Statue itself.
	if game.run.floor==5 or game.mode!="playing" or game.player.dead or remaining==0 or remaining>ARROW_SHOW_AT: return
	var nearest = null
	var best = INF
	for e in game.enemies:
		if e.dead or e.kind=="offering": continue
		var d: float = e.position.distance_squared_to(game.player.position)
		if d<best: best = d; nearest = e
	if nearest == null: return
	var camera: Camera3D = game.world.camera
	var from: Vector2 = camera.unproject_position(game.player.position+Vector3.UP)
	var to: Vector2 = camera.unproject_position(nearest.position+Vector3.UP)
	if from.distance_to(to) < ARROW_RADIUS*1.2: return
	var heading: Vector2 = (to-from).normalized()
	enemy_arrow.position = from+heading*ARROW_RADIUS
	enemy_arrow.rotation = heading.angle()
	enemy_arrow.visible = true

func button(text: String, callback: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(callback)
	modal_body.add_child(b)
	return b
