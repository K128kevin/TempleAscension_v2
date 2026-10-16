extends CanvasLayer
const Data = preload("res://scripts/data.gd")
const Panels = preload("res://scripts/panels.gd")
const SkillIcon = preload("res://scripts/skill_icon.gd")
const Items = preload("res://scripts/items.gd")
const Art = preload("res://scripts/hud_art.gd")
const Shrine = preload("res://scripts/ui_theme.gd")
const Bindings = preload("res://scripts/combat_bindings.gd")
const Save = preload("res://scripts/save.gd")
var game
# The attribute and skill panels and their + buttons.
var panels
var root: Control
var objective: Label
var health: ColorRect
var energy: ColorRect
var hp_text: Label
var en_text: Label
# Over the energy orb: its name. (The wizard's energy is mana, in a blue orb:
# show_energy_kind.)
var energy_title: Label
var energy_kind = ""
const ENERGY_LIQUID = Color(.04,.38,.11)
const MANA_LIQUID = Color(.05,.2,.82)
var difficulty: Label
var notice: Label
var status: Label
var experience: ProgressBar
var character_info: Label
var direction: Label
# Points toward the nearest remaining statue once five or fewer are left.
var enemy_arrow: Polygon2D
const ARROW_SHOW_AT = 5
const ARROW_RADIUS = 92.0
var prompt: Label
var boss_bar: ProgressBar
var boss_name: Label
# The hero's buffs and debuffs (Skills.effects()), in a row over the hotbar:
# each a small square with its icon, its stacks in the corner, and a bar
# under it running down with the time it has left.
const EFFECT_ICON = 32
# The hotbar and the orbs either side of it are drawn at this scale of their
# laid-out sizes, this far up from the bottom of the screen, the orbs this far
# out from the bar. (No line of controls runs under them: the README lists
# them.)
const BAR_SCALE = .7
const BAR_WIDTH = 356.0
const BAR_BOTTOM = 16.0
const ORB_HEIGHT = 182.0
const ORB_GAP = 10.0
# How far down each orb's box the middle of its globe is (make_orb: under its
# title), and how far up the hotbar sits so its middle is level with it.
const ORB_MIDDLE = 105.0
const ROW_BOTTOM = BAR_BOTTOM+(ORB_HEIGHT-ORB_MIDDLE-28)*BAR_SCALE
const EFFECT_GAP = 6
var effect_row: Control
var effect_slots: Array[Dictionary] = []
# Under the hotbar, the dash's and the healing spell's tiles: each lit when
# ready, and while it recharges dimmed, shaded by what is left and counting
# down its seconds.
const READY_ICON = 26
var ready_tiles: Array[Dictionary] = []
# A small health bar over the head of every enemy in sight, by enemy.
const ENEMY_BAR = Vector2(60,4)
var enemy_bars: Array[ProgressBar] = []
var bar_of: Dictionary = {}
# The name of a townsperson under the cursor (only Anya has one).
var npc_name: Label
# The name of every item lying on the ground in sight, over it: a button,
# which picks the item up (the hero walking to it first if he must).
var item_labels: Array[Button] = []
var item_label_styles: Dictionary = {}
# One amber cast bar over each Oracle while it casts a fireball.
var cast_bars: Array = []
var modal_veil: ColorRect
var modal: PanelContainer
var modal_body: VBoxContainer
var weapon_slots: Array[Button] = []
var weapon_icons: Array[TextureRect] = []
var weapon_names: Array[Label] = []
# The hotbar slot under the cursor, -1 for none; a skill there shows its details.
var hovered_slot = -1
# The three skill slots' icons and recharge countdowns.
var slot_glyphs: Array = []
var slot_cooldowns: Array[Label] = []
var notice_time = 0.0
var gold = Shrine.GOLD
var cream = Shrine.TEXT
var selected_style: StyleBoxFlat
var idle_style: StyleBoxFlat
var art_style = 0
var art_backplate: TextureRect
var orb_holders: Array[Control] = []
var orb_titles: Array[Label] = []
var hotbar_row: Control
var ready_row_control: Control
var hotkeys: Array[Label] = []
var hotbar_accent = Color(.91,.75,.45)

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
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(root)
	root.theme = Shrine.make()
	art_backplate = TextureRect.new()
	art_backplate.name = "HudArtwork"
	art_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_backplate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_backplate.stretch_mode = TextureRect.STRETCH_SCALE
	art_backplate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art_backplate.visible = false
	root.add_child(art_backplate)
	npc_name = label("",14,Color(.93,.86,.7),root)
	npc_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_name.size = Vector2(160,20)
	npc_name.z_index = 1
	npc_name.visible = false
	var left = make_orb(false)
	health = left.orb; hp_text = left.value
	var right = make_orb(true)
	energy = right.orb; en_text = right.value; energy_title = right.title
	objective = label("",20,gold,root)
	anchor(objective,Vector2(1,0),Vector2(-464,22),Vector2(440,28))
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status = label("",17,cream,root)
	anchor(status,Vector2(1,0),Vector2(-464,54),Vector2(440,25))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	difficulty = label("",16,cream,root)
	anchor(difficulty,Vector2(1,0),Vector2(-464,81),Vector2(440,24))
	difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	direction = label("",14,Shrine.MUTED,root)
	anchor(direction,Vector2(1,0),Vector2(-464,108),Vector2(440,24))
	direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	character_info = label("",15,gold,root)
	anchor(character_info,Vector2.ZERO,Vector2(24,24),Vector2(370,24))
	experience = bar(Color(.36,.58,.9),root)
	experience.custom_minimum_size = Vector2(200,5)
	anchor(experience,Vector2.ZERO,Vector2(24,51),Vector2(200,5))
	var row = Control.new()
	hotbar_row = row
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	# Drawn at BAR_SCALE of its laid-out size, centred between the orbs and
	# level with their middles.
	anchor(row,Vector2(.5,1),Vector2(-BAR_WIDTH*BAR_SCALE*.5,-ROW_BOTTOM-56*BAR_SCALE),Vector2(BAR_WIDTH,56))
	row.scale = Vector2.ONE*BAR_SCALE
	idle_style = panel_style(Color(.035,.032,.028,.94),Color(.37,.31,.21))
	selected_style = panel_style(Color(.15,.115,.065,.97),gold)
	selected_style.set_border_width_all(2)
	selected_style.shadow_color = Color(.8,.49,.13,.24)
	selected_style.shadow_size = 5
	for i in 6:
		var slot = Button.new()
		row.add_child(slot)
		slot.position = Vector2(i*60,0)
		slot.size = Vector2(56,56)
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = "Assign skills in the skill panel (K)"
		slot.add_theme_stylebox_override("disabled",idle_style)
		slot.pressed.connect(func():
			if game.mode!="playing": return
			var at: Vector3 = game.target.position if is_instance_valid(game.target) and not game.target.dead else game.player.position+game.player.forward()*4
			if i==0 and Data.casts_left(game.run): game.skills.cast_slot(Data.LEFT_SLOT,at)
			elif i==0: game.attack(false,at)
			else: game.skills.cast_slot(i-1,at))
		slot.mouse_entered.connect(func(): hovered_slot = i)
		slot.mouse_exited.connect(func():
			if hovered_slot==i: hovered_slot = -1)
		weapon_slots.append(slot)
		var icon = TextureRect.new()
		icon.texture = load("res://assets/textures/seal.png")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(11,10); icon.size = Vector2(34,34)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		weapon_icons.append(icon)
		# A skill's glyph and its recharge, one for each tile (the LMB tile's
		# for the wizard's spell there).
		var glyph = SkillIcon.new()
		glyph.position = Vector2(15,13); glyph.size = Vector2(26,26)
		slot.add_child(glyph)
		slot_glyphs.append(glyph)
		var recharge = label("",20,cream,slot)
		recharge.position = Vector2(0,12); recharge.size = Vector2(56,28)
		recharge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_cooldowns.append(recharge)
		var hotkey = label(["LMB","RMB","1","2","3","4"][i],12,gold,slot)
		hotkey.position = Vector2(5,2); hotkey.size = Vector2(46,13)
		hotkey.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hotkeys.append(hotkey)
		var name_label = label("",10,cream,slot)
		name_label.position = Vector2(2,39); name_label.size = Vector2(52,15)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 1
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_names.append(name_label)
	effect_row = Control.new()
	effect_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(effect_row)
	anchor(effect_row,Vector2(.5,1),Vector2(-200,-ROW_BOTTOM-56*BAR_SCALE-6-(EFFECT_ICON+8)),Vector2(400,EFFECT_ICON+8))
	effect_row.visible = false
	var ready_row = Control.new()
	ready_row_control = ready_row
	ready_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ready_row)
	var across = READY_ICON*2+EFFECT_GAP
	anchor(ready_row,Vector2(.5,1),Vector2(-across*.5,-ROW_BOTTOM+6),Vector2(across,READY_ICON))
	for i in 2: ready_tiles.append(ready_tile(ready_row,["dash","heal"][i],["Dash (Space)","Healing spell (Q)"][i],i*(READY_ICON+EFFECT_GAP)))
	prompt = label("",19,gold,root)
	# (Above the orbs, and so above the row of buffs and debuffs.)
	anchor(prompt,Vector2(.5,1),Vector2(-400,-BAR_BOTTOM-ORB_HEIGHT*BAR_SCALE-36),Vector2(800,28))
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
	panels = Panels.new()
	panels.setup(self)
	var chosen = Art.index_of(Save.setting("hud_art_shrine","sandstone_shrine")) if game.debug.enabled else Art.DEFAULT
	set_art_style(chosen,false)

func make_orb(is_energy: bool) -> Dictionary:
	var holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(holder)
	# Close either side of the hotbar, at its scale, their middles level with it.
	var beside = BAR_WIDTH*BAR_SCALE*.5+ORB_GAP
	anchor(holder,Vector2(.5,1),Vector2(beside if is_energy else -beside-180*BAR_SCALE,-BAR_BOTTOM-ORB_HEIGHT*BAR_SCALE),Vector2(180,ORB_HEIGHT))
	holder.scale = Vector2.ONE*BAR_SCALE
	var title = label("ENERGY" if is_energy else "HEALTH",16,gold,holder)
	orb_holders.append(holder)
	orb_titles.append(title)
	title.size = Vector2(180,24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var orb = ColorRect.new()
	orb.position = Vector2(10,25); orb.size = Vector2(160,160)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/orb.gdshader")
	material.set_shader_parameter("liquid",ENERGY_LIQUID if is_energy else Color(.78,.035,.06))
	orb.material = material
	holder.add_child(orb)
	var value = label("",18,cream,holder)
	value.position = Vector2(0,94); value.size = Vector2(180,28)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return {"orb":orb,"value":value,"title":title}

# A live visual swap: retain the same gauge materials, skill buttons, inputs
# and cooldown widgets. Sandstone is the normal default; preview preferences use isolated debug settings.
func fit_shrine_sockets(look: Dictionary) -> void:
	var factor: float = look.width/Art.SOURCE.x
	var top: float = -8-look.bottom*factor
	# Measured centres of the empty recesses in sandstone_shrine_v3.png.
	var centres = [670.5,833.0,998.0,1164.0,1330.5,1495.5]
	for i in weapon_slots.size():
		weapon_slots[i].position.x = ((centres[i]-Art.SOURCE.x*.5)*factor+BAR_WIDTH*BAR_SCALE*.5)/BAR_SCALE-28
	anchor(ready_row_control,Vector2(.5,1),Vector2(-look.width*.5,top),Art.SOURCE*factor)
	for i in 2:
		ready_tiles[i].frame.position = Vector2(954.5 if i==0 else 1208.5,559.5)*factor-Vector2.ONE*READY_ICON*.5

func socket_style(active: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	# The recess and bevel already exist in the artwork. Only feedback is drawn.
	s.bg_color = Color(Shrine.GOLD,.08) if active else Color.TRANSPARENT
	s.border_color = Color(Shrine.GOLD,.55) if active else Color.TRANSPARENT
	s.set_border_width_all(1 if active else 0)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(0)
	return s

func set_art_style(index: int, remember: bool = true) -> bool:
	if index<0 or index>=Art.STYLES.size(): return false
	if index!=Art.DEFAULT and not game.debug.enabled: return false
	art_style = index
	var look: Dictionary = Art.STYLES[index]
	art_backplate.self_modulate = look.get("modulate",Color.WHITE)
	hotbar_accent = look.accent
	art_backplate.visible = index!=0
	var row_middle = -ROW_BOTTOM-28*BAR_SCALE
	if index==0:
		art_backplate.texture = null
		var beside = BAR_WIDTH*BAR_SCALE*.5+ORB_GAP
		for i in 2:
			anchor(orb_holders[i],Vector2(.5,1),Vector2(beside if i==1 else -beside-180*BAR_SCALE,-BAR_BOTTOM-ORB_HEIGHT*BAR_SCALE),Vector2(180,ORB_HEIGHT))
			orb_titles[i].position.y = 0
	else:
		art_backplate.texture = load(look.texture)
		var width: float = look.get("width",Art.WIDTH)
		var factor = width/Art.SOURCE.x
		var top: float = -8.0-look.bottom*factor
		row_middle = top+look.bar_y*factor
		anchor(art_backplate,Vector2(.5,1),Vector2(-width*.5,top),Art.SOURCE*factor)
		for i in 2:
			var at: Vector2 = look.left if i==0 else look.right
			var offset = Vector2((at.x-Art.SOURCE.x*.5)*factor-90*BAR_SCALE,top+at.y*factor-ORB_MIDDLE*BAR_SCALE)
			anchor(orb_holders[i],Vector2(.5,1),offset,Vector2(180,ORB_HEIGHT))
			# Keep titles above the tallest carving, clear of the live orbs.
			orb_titles[i].position.y = (top+look.top*factor-18.0-offset.y)/BAR_SCALE
	anchor(hotbar_row,Vector2(.5,1),Vector2(-BAR_WIDTH*BAR_SCALE*.5,row_middle-28*BAR_SCALE),Vector2(BAR_WIDTH,56))
	# The new frames have a central carved pendant; flank it with the two
	# utility tiles instead of covering the artwork. Classic keeps its gap.
	var ready_gap = EFFECT_GAP+(40 if index!=0 else 0)
	var across = READY_ICON*2+ready_gap
	anchor(ready_row_control,Vector2(.5,1),Vector2(-across*.5,row_middle+28*BAR_SCALE+6),Vector2(across,READY_ICON))
	for i in ready_tiles.size(): ready_tiles[i].frame.position = Vector2(i*(READY_ICON+ready_gap),0)
	# Sandstone has real carved sockets; hit targets contain only live content.
	for i in weapon_slots.size(): weapon_slots[i].position = Vector2(i*60,0)
	if index==Art.DEFAULT: fit_shrine_sockets(look)
	anchor(effect_row,Vector2(.5,1),Vector2(-200,row_middle-28*BAR_SCALE-6-(EFFECT_ICON+8)),Vector2(400,EFFECT_ICON+8))
	var prompt_y = minf(-BAR_BOTTOM-ORB_HEIGHT*BAR_SCALE-36,row_middle-28*BAR_SCALE-6-(EFFECT_ICON+8)-34)
	anchor(prompt,Vector2(.5,1),Vector2(-400,prompt_y),Vector2(800,28))
	for orb in [health,energy]:
		orb.material.set_shader_parameter("rim_start",look.get("rim_start",.83))
		orb.material.set_shader_parameter("rim_dark",Vector3(look.rim_dark.r,look.rim_dark.g,look.rim_dark.b))
		orb.material.set_shader_parameter("rim_light",Vector3(look.rim_light.r,look.rim_light.g,look.rim_light.b))
	for title in orb_titles: title.add_theme_color_override("font_color",hotbar_accent)
	for key in hotkeys: key.add_theme_color_override("font_color",hotbar_accent)
	idle_style = panel_style(look.background,look.edge)
	selected_style = panel_style(Color(.15,.115,.065,.97) if index==0 else look.background.lightened(.10),hotbar_accent)
	selected_style.set_border_width_all(2)
	selected_style.shadow_color = Color(.8,.49,.13,.24) if index==0 else Color(hotbar_accent,.20)
	selected_style.shadow_size = 5
	if index==Art.DEFAULT:
		idle_style = socket_style(false)
		selected_style = socket_style(true)
	for i in weapon_slots.size():
		var slot = weapon_slots[i]
		slot.add_theme_stylebox_override("normal",selected_style if i==1 else idle_style)
		slot.add_theme_stylebox_override("disabled",idle_style)
		for state in ["hover","pressed","focus"]:
			if index==0: slot.remove_theme_stylebox_override(state)
			else: slot.add_theme_stylebox_override(state,selected_style)
	for tile in ready_tiles:
		for state in ["ready","waiting"]:
			var style = socket_style(false) if index==Art.DEFAULT else panel_style(look.background,hotbar_accent if state=="ready" else look.edge)
			style.set_content_margin_all(0)
			tile.styles[state] = style
		for state in ["hover","pressed","focus"]: tile.frame.add_theme_stylebox_override(state,selected_style)
	if remember and game.debug.enabled: Save.keep_setting("hud_art_shrine",look.id)
	return true

# The energy orb as the hero's class has it: the wizard's is mana, blue.
func show_energy_kind() -> void:
	var mana: bool = game.run.get("class_id","")=="wizard"
	var kind: String = "mana" if mana else "energy"
	if kind == energy_kind: return
	energy_kind = kind
	energy_title.text = kind.to_upper()
	energy.material.set_shader_parameter("liquid",MANA_LIQUID if mana else ENERGY_LIQUID)

# What someone says, over his head (scripts/speech_bubble.gd: typed in, then
# left to be read; a town guard spoken to, scripts/game.gd talk_to). A new
# word from him replaces the last.
const SpeechBubble = preload("res://scripts/speech_bubble.gd")
const SPEECH_ABOVE = 2.35
var speeches: Array = []
func speak(speaker: Node3D, words: String) -> void:
	for old in speeches.filter(func(b): return b.speaker == speaker):
		old.panel.queue_free()
		speeches.erase(old)
	var bubble = SpeechBubble.new()
	bubble.setup(words)
	root.add_child(bubble)
	root.move_child(bubble,0)
	speeches.append({"panel":bubble,"speaker":speaker})
	show_speech(0.0)

func show_speech(dt: float) -> void:
	var camera: Camera3D = game.world.camera if is_instance_valid(game.world) else null
	for said in speeches.duplicate():
		if not said.panel.advance(dt) or not is_instance_valid(said.speaker) or camera == null:
			said.panel.queue_free()
			speeches.erase(said)
			continue
		var head: Vector3 = said.speaker.global_position+Vector3.UP*SPEECH_ABOVE
		said.panel.visible = not camera.is_position_behind(head)
		said.panel.point_at(camera.unproject_position(head))

func panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg.lerp(Shrine.INSET,.5)
	s.border_color = border.lerp(Shrine.STONE,.25)
	s.set_border_width_all(1)
	s.set_content_margin_all(16)
	s.border_width_top = 2
	s.border_width_left = 2
	s.set_corner_radius_all(3)
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
	bg.bg_color = Shrine.INSET
	bg.border_color = Shrine.STONE
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	p.add_theme_stylebox_override("background",bg)
	p.add_theme_stylebox_override("fill",fill)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func tick(dt: float) -> void:
	game.debug.refresh()
	show_energy_kind()
	show_enemy_bars()
	show_item_labels()
	show_speech(dt)
	show_effects()
	show_ready()
	for i in range(2,6): hotkeys[i].text = Bindings.caption(i-2)
	show_cast_bars()
	var r: Dictionary = game.run
	var maximum_health = Data.max_health(r)
	var maximum_energy = Data.max_energy(r)
	health.material.set_shader_parameter("fill",clampf(game.player.hp/maximum_health,0,1))
	energy.material.set_shader_parameter("fill",clampf(r.energy/maximum_energy,0,1))
	hp_text.text = "%d / %d" % [maxf(0,game.player.hp),maximum_health]
	en_text.text = "%d / %d" % [r.energy,maximum_energy]
	var outdoors: bool = game.outdoors() and game.playground == null
	objective.text = "PLAYGROUND · Shift+P leaves" if game.playground != null else place_title(r)
	difficulty.text = "%s mode" % Data.DIFFICULTIES[r.difficulty]
	var remaining: int = game.remaining()
	var dungeon: bool = r.place in Data.DUNGEONS
	status.text = "%d %s remain" % [remaining,"bandits" if dungeon else "statues"] if remaining>0 else ("The crown awaits" if Data.summit(r) else ("The bandits are routed" if dungeon and Data.last_floor(r) else ("The way down is open" if dungeon else "The way up is open")))
	direction.text = "Defeat the Crowned Statue" if Data.summit(r) and not outdoors else ""
	# (Behind a gate: whether he has its key yet.)
	if game.gated() and not game.world.gate_open: direction.text = "You carry the gate's key" if game.has_key() else "The way down is barred by a locked gate"
	if outdoors: show_outdoors()
	point_to_nearest_enemy()
	point_to_stairs()
	character_info.text = "%s · Level %d" % [r.class_id.capitalize(),r.level]
	experience.max_value = Data.XP_STEPS[r.level-1] if r.level<Data.MAX_LEVEL else 1
	experience.value = r.xp-Data.xp_at_level(r.level) if r.level<Data.MAX_LEVEL else 1
	# The LMB tile: the normal attack, or the wizard's spell there.
	var casts_left: bool = Data.casts_left(r)
	if not casts_left:
		weapon_slots[0].disabled = game.player.dead
		# (Its details come from the skill panel's tip, as a skill's do.)
		weapon_slots[0].tooltip_text = ""
		weapon_slots[0].add_theme_stylebox_override("normal",idle_style)
		# (The weapon in hand, as its item is pictured.)
		var weapon_icon_path = "res://assets/ui/items/%s.png" % r.equipment.main
		if not ResourceLoader.exists(weapon_icon_path): weapon_icon_path = "res://assets/ui/weapon-%s.png" % Data.WEAPONS[Data.weapon(r)]
		weapon_icons[0].texture = load(weapon_icon_path) if ResourceLoader.exists(weapon_icon_path) else load("res://assets/textures/seal.png")
		weapon_icons[0].modulate = Color.WHITE
		weapon_icons[0].visible = true
		slot_cooldowns[0].text = ""
		slot_glyphs[0].show_skill("",hotbar_accent)
		weapon_names[0].text = "Attack"
	else: weapon_icons[0].texture = load("res://assets/textures/seal.png")
	for i in range(0 if casts_left else 1,6):
		var id: String = r.hotbar[tile_slot(i)]
		var problem: String = game.skills.reason(id)
		weapon_slots[i].disabled = not problem.is_empty()
		# A skill's details come from the skill panel's tip instead.
		weapon_slots[i].tooltip_text = "Assign skills in the skill panel (K)" if id.is_empty() else ""
		weapon_slots[i].add_theme_stylebox_override("normal",selected_style if i==1 else idle_style)
		weapon_icons[i].modulate = Color(.5,.65,1,.25) if r.class_id=="wizard" else Color(1,.8,.4,.2)
		# An empty slot keeps the faint seal; a skill shows its icon, and its
		# seconds left while it recharges.
		weapon_icons[i].visible = id.is_empty()
		var recharge: float = game.skills.cooldowns.get(id,0.0)
		slot_cooldowns[i].text = str(ceili(recharge)) if recharge>0 else ""
		slot_glyphs[i].show_skill(id,Color(.45,.44,.4) if recharge>0 else (hotbar_accent if problem.is_empty() else Color(.6,.58,.5)))
		weapon_names[i].text = "Empty" if id.is_empty() else game.Book.all()[id].title
	panels.tick(dt)
	var hovered_skill: String = r.hotbar[tile_slot(hovered_slot)] if hovered_slot>0 or (hovered_slot==0 and casts_left) else (panels.ATTACK if hovered_slot==0 else "")
	if not hovered_skill.is_empty(): panels.show_tip(hovered_skill,weapon_slots[hovered_slot].get_global_rect())
	elif panels.hovered.is_empty() and is_instance_valid(panels.tip): panels.tip.visible = false
	prompt.text = ""
	if game.mode == "playing":
		if outdoors: prompt.text = outdoor_prompt()
		elif game.crown_available and game.player.position.distance_to(game.crown_position)<3: prompt.text = "E  ·  Claim the emperor's crown"
		elif puzzle_prompt() != "": prompt.text = puzzle_prompt()
		elif game.at_locked_gate(): prompt.text = "E · Unlock the gate" if game.has_key() else "The gate is locked"
		elif game.way_open() and game.has_way_on() and game.player.position.distance_to(game.world.exit_point)<4: prompt.text = "The stairs lead down" if r.place == "basement" else "E · %s" % ("Descend" if r.place in Data.DUNGEONS else "Ascend")
		elif r.place in Data.DUNGEONS and game.world.layout.arrival.has_area() and game.player.position.distance_to(game.world.layout.arrival_position())<3.5: prompt.text = "E · Back up the stair" if r.floor>0 else "E · Up the stair to the arena"
		elif game.world.leaving_soon(game.player.position): prompt.text = {"temple":"The door leads out to the desert","cave":"The cave's mouth leads out to the desert","basement":"The stair leads up into the arena"}[r.place]
		elif game.player.position.distance_to(game.world.spawn)<2: prompt.text = "E · Rest"
	boss_bar.visible = is_instance_valid(game.boss) and not game.boss.dead
	boss_name.visible = boss_bar.visible
	if boss_bar.visible:
		boss_bar.max_value = game.boss.max_hp
		boss_bar.value = game.boss.hp
	notice_time -= dt
	notice.visible = notice_time > 0

# The basement's last level: what its lasers and boulders want of him, when
# he is near them (scripts/basement_puzzle.gd).
func puzzle_prompt() -> String:
	var puzzle = game.world.get("puzzle")
	if puzzle == null: return ""
	var at: Vector3 = game.player.position
	if puzzle.holding(): return "Click where to roll the boulder  ·  E · Let go"
	if puzzle.lit and puzzle.struck(at,at,3.0): return "The beams burn through anything: weigh down both plates to quench them"
	if not puzzle.near_boulder(at).is_empty(): return "E · Take hold of the boulder"
	return ""

# The hotbar slot (Data) a tile of the bar shows: LMB's is the wizard's
# LEFT_SLOT, then RMB and 1 to 4.
func tile_slot(tile: int) -> int:
	return Data.LEFT_SLOT if tile==0 else tile-1

# Outside the temple the corner of the screen says nothing: no place is
# named, and no way pointed out.
func show_outdoors() -> void:
	objective.text = ""
	status.text = ""
	direction.text = ""

# What the hero is standing in front of, outdoors.
func outdoor_prompt() -> String:
	var spot: Dictionary = game.world.place_at(game.player.position)
	if not spot.is_empty() and spot.kind == "temple": return "Walk in to begin the ascent" if Data.temple_open(game.run) else "The door is shut: rout the bandits beneath the arena and in the northern cave"
	if not spot.is_empty() and spot.kind == "cave": return "Walk in to enter the cave"
	if not spot.is_empty() and spot.kind == "basement": return "The stair leads down beneath the arena"
	return ""

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
	background.bg_color = Shrine.INSET
	background.border_color = Shrine.EDGE
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	p.add_theme_stylebox_override("background",background)
	return p

var aim_bar: ProgressBar
# Where the hero is, for the corner of the screen. (No place is named: a
# dungeon's levels are numbered, as the temple's floors are.)
func place_title(r: Dictionary) -> String:
	if r.get("place","temple") in Data.DUNGEONS: return "LEVEL %d" % (r.floor+1)
	return "SUMMIT" if Data.summit(r) else "FLOOR %d" % (r.floor+1)

func show_cast_bars() -> void:
	var casting: Array = game.enemies.filter(func(e): return e.role=="wizard" and not e.dead and e.visible and e.cast_total>0 and e.windup>0)
	while cast_bars.size()<casting.size(): cast_bars.append(cast_bar())
	for i in cast_bars.size():
		var shown: bool = i<casting.size()
		cast_bars[i].visible = shown
		if not shown: continue
		var caster = casting[i]
		# Pushback can add more than the cast has left; the bar then sits empty.
		cast_bars[i].value = clampf(1.0-caster.windup/caster.cast_total,0.0,1.0)
		# (The basement healer's mending fills green.)
		cast_bars[i].modulate = Color(.55,1.6,.6) if caster.healing else Color.WHITE
		# Just above where the hover health bar sits.
		var head: Vector3 = caster.position+Vector3.UP*caster.config.size*2.25
		cast_bars[i].position = game.world.camera.unproject_position(head)-Vector2(cast_bars[i].size.x*.5,24)
	# The hero's own: Power Shot's aim, filling over his head until he looses.
	var aiming: bool = game.skills.aim_total>0 and not game.player.dead
	if aiming and aim_bar == null: aim_bar = cast_bar()
	if aim_bar != null:
		aim_bar.visible = aiming
		if aiming:
			aim_bar.value = clampf(1.0-game.skills.aim_left/game.skills.aim_total,0.0,1.0)
			aim_bar.position = game.world.camera.unproject_position(game.player.position+Vector3.UP*2.25)-Vector2(aim_bar.size.x*.5,24)

# The name of the townsperson under the cursor, over her head.
func show_npc_name(who: Dictionary) -> void:
	npc_name.visible = not who.is_empty()
	if not npc_name.visible: return
	npc_name.text = who.name
	npc_name.position = game.world.camera.unproject_position(who.at)-Vector2(npc_name.size.x*.5,10)

func ready_tile(row: Control, kind: String, tip: String, x: float) -> Dictionary:
	var frame = Button.new()
	frame.focus_mode = Control.FOCUS_NONE
	frame.pressed.connect(func():
		if kind=="heal": game.heal()
		else: game.dash(game.player.position+game.player.forward()*game.DASH_REACH))
	frame.position = Vector2(x,0); frame.size = Vector2(READY_ICON,READY_ICON)
	frame.tooltip_text = tip
	row.add_child(frame)
	var styles = {}
	for look in [["ready",gold],["waiting",Color(.37,.31,.21)]]:
		var style = panel_style(Color(.035,.032,.028,.94),look[1])
		style.set_content_margin_all(0)
		styles[look[0]] = style
	var glyph = SkillIcon.new()
	glyph.position = Vector2(5,1); glyph.size = Vector2(READY_ICON-10,READY_ICON-10)
	frame.add_child(glyph)
	# (The shade over it shrinks away as it recharges.)
	var shade = ColorRect.new()
	shade.color = Color(0,0,0,.55)
	shade.position = Vector2(1,1); shade.size = Vector2(READY_ICON-2,0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)
	var count = label("",13,cream,frame)
	count.size = Vector2(READY_ICON,READY_ICON)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var key = label("",8,gold,frame)
	key.position = Vector2(0,18); key.size = Vector2(READY_ICON,8)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return {"kind":kind,"frame":frame,"glyph":glyph,"shade":shade,"count":count,"key":key,"styles":styles}

func show_ready() -> void:
	for tile in ready_tiles:
		var left: float = game.dash_cooldown if tile.kind=="dash" else game.heal_cd
		var whole: float = game.dash_recharge if tile.kind=="dash" else game.HEAL_COOLDOWN
		var waiting = left>0
		tile.shade.size.y = (READY_ICON-2)*clampf(left/maxf(whole,.01),0.0,1.0)
		tile.count.text = str(ceili(left)) if waiting else ""
		# (The wizard's evade is a teleport.)
		var blinks: bool = tile.kind=="dash" and game.run.get("class_id","")=="wizard"
		tile.glyph.show_skill("teleport" if blinks else tile.kind,Color(.45,.44,.4) if waiting else cream)
		tile.key.text = Bindings.caption(4 if tile.kind=="dash" else 5)
		tile.frame.tooltip_text = "%s (%s)" % [("Teleport" if blinks else "Dash") if tile.kind=="dash" else "Healing spell · 60 "+Data.energy_word(game.run),tile.key.text]
		tile.frame.disabled = waiting or game.player.dead or game.mode!="playing"
		for state in ["normal","disabled"]: tile.frame.add_theme_stylebox_override(state,tile.styles.waiting if waiting else tile.styles.ready)

func effect_slot() -> Dictionary:
	var frame = Panel.new()
	frame.size = Vector2(EFFECT_ICON,EFFECT_ICON)
	# (It stops the mouse only for its own tooltip.)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	effect_row.add_child(frame)
	var styles = {}
	for kind in [["buff",Color(.62,.58,.32)],["debuff",Color(.72,.2,.14)]]:
		var style = panel_style(Color(.035,.032,.028,.94),kind[1])
		style.set_content_margin_all(0)
		styles[kind[0]] = style
	var glyph = SkillIcon.new()
	glyph.position = Vector2(5,5); glyph.size = Vector2(EFFECT_ICON-10,EFFECT_ICON-10)
	frame.add_child(glyph)
	var stacks = label("",12,cream,frame)
	stacks.position = Vector2(0,EFFECT_ICON-17); stacks.size = Vector2(EFFECT_ICON-3,16)
	stacks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var under = ColorRect.new()
	under.color = Color(.05,.03,.015,.94)
	under.position = Vector2(0,EFFECT_ICON+2); under.size = Vector2(EFFECT_ICON,4)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(under)
	var left = ColorRect.new()
	left.position = Vector2(1,1); left.size = Vector2(EFFECT_ICON-2,2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.add_child(left)
	return {"frame":frame,"glyph":glyph,"stacks":stacks,"under":under,"left":left,"styles":styles,"tip":""}

# The row of what is on the hero, centred over the hotbar; none once he has
# fallen, nor on the ending and summary screens.
func show_effects() -> void:
	var active: Array = [] if not is_instance_valid(game.player) or game.player.dead or game.mode in ["dead","ending","summary"] else game.skills.effects()
	while effect_slots.size() < active.size(): effect_slots.append(effect_slot())
	var width = active.size()*EFFECT_ICON+maxi(0,active.size()-1)*EFFECT_GAP
	for i in effect_slots.size():
		var slot: Dictionary = effect_slots[i]
		var frame: Panel = slot.frame
		frame.visible = i < active.size()
		if not frame.visible: continue
		var effect: Dictionary = active[i]
		frame.position = Vector2(roundf(effect_row.size.x*.5-width*.5)+i*(EFFECT_ICON+EFFECT_GAP),0)
		frame.add_theme_stylebox_override("panel",slot.styles.debuff if effect.debuff else slot.styles.buff)
		slot.glyph.show_skill(effect.id,Color(1,.66,.58) if effect.debuff else Color(.93,.91,.82))
		slot.stacks.text = str(effect.stacks) if effect.stacks > 1 else ""
		# The bar under it: what is left of its time, running down.
		var timed: bool = effect.total > 0
		slot.under.visible = timed
		if timed:
			var share = clampf(effect.left/effect.total,0.0,1.0)
			slot.left.size.x = (EFFECT_ICON-2)*share
			slot.left.color = Color(.86,.22,.14) if effect.debuff else Color(.9,.72,.3)
		var tip = "%s%s\n%s" % [effect.name," ×%d" % effect.stacks if effect.stacks > 1 else "",effect.text]
		if timed: tip += "\n%d s left" % ceili(effect.left)
		if tip != slot.tip:
			slot.tip = tip
			frame.tooltip_text = tip
	effect_row.visible = not active.is_empty()

func enemy_bar() -> ProgressBar:
	var p = bar(Color(.88,.055,.04),root)
	p.custom_minimum_size = ENEMY_BAR
	p.size = ENEMY_BAR
	p.z_index = 1
	var background = StyleBoxFlat.new()
	background.bg_color = Shrine.INSET
	background.border_color = Shrine.EDGE
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	p.add_theme_stylebox_override("background",background)
	return p

func item_label() -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",13)
	b.add_theme_constant_override("outline_size",3)
	b.add_theme_color_override("font_outline_color",Color(.025,.02,.015))
	root.add_child(b)
	# (Under the rest of the interface: the orbs and the hotbar cover them.)
	root.move_child(b,0)
	b.pressed.connect(func():
		if b.has_meta("pickup"): game.pick_up(b.get_meta("pickup")))
	return b

# Over each item on the ground the hero can see, its name in its rarity's
# colour; none while the game is paused or over.
func show_item_labels() -> void:
	var camera: Camera3D = game.world.camera
	var shown: Array = []
	if game.mode == "playing" and not game.player.dead:
		for pickup in game.pickups:
			if is_instance_valid(pickup.node) and pickup.node.visible and not camera.is_position_behind(pickup.node.position): shown.append(pickup)
	while item_labels.size() < shown.size(): item_labels.append(item_label())
	for i in item_labels.size():
		var b: Button = item_labels[i]
		b.visible = i < shown.size()
		if not b.visible:
			b.remove_meta("pickup")
			continue
		var pickup: Dictionary = shown[i]
		var inst: Dictionary = pickup.drop.item
		b.set_meta("pickup",pickup)
		if b.text != Items.name_of(inst):
			b.text = Items.name_of(inst)
			var tone: Color = Items.color(inst)
			for look in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(look,tone if look=="font_color" else tone.lightened(.3))
			var key: String = Items.rarity(inst)
			if not item_label_styles.has(key):
				var plain = panel_style(Color(.03,.03,.035,.82),tone.darkened(.35))
				plain.set_content_margin_all(2)
				plain.content_margin_left = 7; plain.content_margin_right = 7
				plain.set_corner_radius_all(3)
				var lit: StyleBoxFlat = plain.duplicate()
				lit.bg_color = Color(.14,.13,.11,.95)
				lit.border_color = tone
				item_label_styles[key] = [plain,lit]
			b.add_theme_stylebox_override("normal",item_label_styles[key][0])
			for look in ["hover","pressed"]: b.add_theme_stylebox_override(look,item_label_styles[key][1])
			b.reset_size()
		b.position = camera.unproject_position(pickup.node.position+Vector3.UP*.45)-Vector2(b.size.x*.5,b.size.y)
	stack_item_labels(shown.size())

# No two names on the ground cover one another: taken from the bottom of the
# screen up (the nearest first; level ones left to right, and items at one
# spot by where they lie, so the order holds still frame to frame), each
# name that would overlap one already placed is lifted to stand just above
# it, again until it is clear.
const ITEM_LABEL_GAP = 2.0
func stack_item_labels(count: int) -> void:
	var order: Array = []
	for i in count: order.append(i)
	var key = func(i: int) -> Array:
		var b: Button = item_labels[i]
		var at: Vector3 = b.get_meta("pickup").node.position
		return [-roundf(b.position.y+b.size.y),roundf(b.position.x),at.x,at.z]
	order.sort_custom(func(a, b):
		var ka: Array = key.call(a)
		var kb: Array = key.call(b)
		for k in ka.size():
			if ka[k] != kb[k]: return ka[k] < kb[k]
		return a < b)
	var placed: Array[Rect2] = []
	for i in order:
		var b: Button = item_labels[i]
		var rect := Rect2(b.position,b.size)
		var moved = true
		while moved:
			moved = false
			for other in placed:
				if rect.grow(ITEM_LABEL_GAP*.5).intersects(other.grow(ITEM_LABEL_GAP*.5)):
					rect.position.y = other.position.y-rect.size.y-ITEM_LABEL_GAP
					moved = true
		b.position = rect.position
		placed.append(rect)

# The last floor's bars, taken down as a new one is entered.
func clear_enemy_bars() -> void:
	for health in enemy_bars: health.visible = false
	bar_of.clear()

# Over every living enemy the hero can see (not one lost in the dark beyond
# his sight, nor one held in reserve), its health; none while the game is
# paused, nor on the death, ending and summary screens.
func show_enemy_bars() -> void:
	var camera: Camera3D = game.world.camera
	var shown: Array = []
	if game.mode == "playing":
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.dead or enemy.dormant or not enemy.visible or not game.world.can_see(enemy.position): continue
			if camera.is_position_behind(enemy.position): continue
			shown.append(enemy)
	while enemy_bars.size() < shown.size(): enemy_bars.append(enemy_bar())
	bar_of.clear()
	for i in enemy_bars.size():
		var health: ProgressBar = enemy_bars[i]
		health.visible = i < shown.size()
		if not health.visible: continue
		var enemy = shown[i]
		bar_of[enemy] = health
		health.max_value = enemy.max_hp
		health.value = clampf(enemy.hp,0,enemy.max_hp)
		var head: Vector3 = enemy.position+Vector3.UP*enemy.config.get("height",enemy.config.size*2.25)
		health.position = camera.unproject_position(head)-Vector2(health.size.x*.5,12)

# Closes the centre dialog and the side panels.
func close_modal() -> void:
	close_dialog()
	panels.close()

func close_dialog() -> void:
	if is_instance_valid(modal_veil):
		root.remove_child(modal_veil)
		modal_veil.queue_free()
	modal_veil = null
	if is_instance_valid(modal):
		root.remove_child(modal)
		modal.queue_free()
	modal = null

func dialog(title: String, subtitle: String) -> void:
	close_modal()
	modal_veil = ColorRect.new()
	modal_veil.color = Color(.035,.025,.012,.64)
	modal_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal_veil)
	modal = PanelContainer.new()
	modal.custom_minimum_size = Vector2(660,560)
	modal.add_theme_stylebox_override("panel",Shrine.panel(20))
	root.add_child(modal)
	anchor(modal,Vector2(.5,.5),Vector2(-330,-280),Vector2(660,560))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation",16)
	scroll.add_child(modal_body)
	var heading = label(title,30,gold,modal_body)
	heading.add_theme_font_override("font",Shrine.heading())
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sub = label(subtitle,18,cream,modal_body)
	sub.custom_minimum_size.x = 600
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func make_enemy_arrow() -> void:
	enemy_arrow = make_arrow(Color(.95,.72,.3,.92))

# An arrow circling the hero on screen, in `colour`, hidden until needed.
func make_arrow(colour: Color) -> Polygon2D:
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(18,0),Vector2(-10,-11),Vector2(-4,0),Vector2(-10,11)])
	arrow.color = colour
	var outline = Line2D.new()
	outline.points = PackedVector2Array([Vector2(18,0),Vector2(-10,-11),Vector2(-4,0),Vector2(-10,11),Vector2(18,0)])
	outline.width = 2.0
	outline.default_color = Color(.12,.07,.02,.9)
	arrow.add_child(outline)
	arrow.visible = false
	root.add_child(arrow)
	return arrow

# Turns `arrow` round the hero to point at `at`, unless that is close by on
# screen already.
func aim_arrow(arrow: Polygon2D, at: Vector3) -> void:
	var camera: Camera3D = game.world.camera
	var from: Vector2 = camera.unproject_position(game.player.position+Vector3.UP)
	var to: Vector2 = camera.unproject_position(at+Vector3.UP)
	if from.distance_to(to) < ARROW_RADIUS*1.2: return
	var heading: Vector2 = (to-from).normalized()
	arrow.position = from+heading*ARROW_RADIUS
	arrow.rotation = heading.angle()
	arrow.visible = true

# Once a floor is cleared (or its way on opened), a jade arrow points the
# hero to the stairway on.
var stair_arrow: Polygon2D
func point_to_stairs() -> void:
	if stair_arrow == null: stair_arrow = make_arrow(Color(.3,1,.85,.92))
	stair_arrow.visible = false
	# (Not in the arena basement: its way down is found, as its key is.)
	if game.playground != null or game.mode!="playing" or game.player.dead or not game.has_way_on() or game.run.place=="basement": return
	if game.remaining()>0 and not game.way_open(): return
	aim_arrow(stair_arrow,game.world.exit_point)

# Circles the hero on screen, pointing at the nearest statue still standing.
func point_to_nearest_enemy() -> void:
	if enemy_arrow == null: make_enemy_arrow()
	var remaining: int = game.remaining()
	enemy_arrow.visible = false
	# Not on the summit, where the only statue left is the Crowned Statue itself.
	# (Nor in the arena basement, whose last bandits are to be found.)
	if game.playground != null or Data.summit(game.run) or game.run.place == "basement" or game.mode!="playing" or game.player.dead or remaining==0 or remaining>ARROW_SHOW_AT: return
	var nearest = null
	var best = INF
	for e in game.enemies:
		if e.dead or e.dormant: continue
		var d: float = e.position.distance_squared_to(game.player.position)
		if d<best: best = d; nearest = e
	if nearest == null: return
	aim_arrow(enemy_arrow,nearest.position)

func button(text: String, callback: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(callback)
	modal_body.add_child(b)
	return b
