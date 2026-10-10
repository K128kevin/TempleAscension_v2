extends RefCounted
## Debug item browser (F5 in debug mode, scripts/debug.gd): every base item
## in the game in one scrolling list, filtered by its rarity, each put into
## the hero's bag with a click, whether or not his class can use it; a common
## item's row has buttons beside it that put in a random uncommon or rare
## one made of it (scripts/items.gd enchant). Hovering a row shows what the
## item does, as its tip in the inventory does.
const Items = preload("res://scripts/items.gd")
# The filters, in order: everything, the gear a class starts with (which
# never drops), the common items (which drop, and the magic items are made
# of), and the uniques.
const FILTERS = ["all","starting","common","unique"]
const FILTER_TITLES = {"all":"All","starting":"Starting","common":"Common","unique":"Unique"}
const ICON = 40
var game
var hud
var window: PanelContainer
var list: VBoxContainer
var count: Label
var filter_buttons: Dictionary = {}
var filter = "all"
# The class the rows were marked for (what it cannot use is dimmed).
var marked_for = ""
var rng = RandomNumberGenerator.new()

func setup(owner_game) -> void:
	game = owner_game
	hud = game.hud

func is_open() -> bool:
	return is_instance_valid(window) and window.visible

func toggle() -> void:
	if is_open(): window.visible = false
	else: open()

func open() -> void:
	if not is_instance_valid(window): build()
	window.visible = true
	window.move_to_front()
	show_filter(filter)

# Its filter: which base items are listed ("all": everything but the key).
static func shows(id: String, which: String) -> bool:
	var rarity: String = Items.BASES[id].get("rarity","")
	if rarity.is_empty(): return false
	if which == "all": return true
	return rarity == which

# The base items under a filter, the starting gear first, then the common
# items, then the uniques.
static func listed(which: String) -> Array:
	var order = ["starting","common","unique"]
	var ids: Array = Items.BASES.keys().filter(func(id): return shows(id,which))
	var place = {}
	for i in ids.size(): place[ids[i]] = i
	ids.sort_custom(func(a,b):
		var ra = order.find(Items.BASES[a].get("rarity",""))
		var rb = order.find(Items.BASES[b].get("rarity",""))
		return ra < rb if ra != rb else place[a] < place[b])
	return ids

func build() -> void:
	window = PanelContainer.new()
	window.add_theme_stylebox_override("panel",hud.panel_style(Color(.035,.04,.045,.96),hud.gold))
	hud.root.add_child(window)
	hud.anchor(window,Vector2.ZERO,Vector2(346,96),Vector2(400,0))
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation",6)
	window.add_child(body)
	var top = HBoxContainer.new()
	body.add_child(top)
	var title = hud.label("DEBUG · Item browser · F5",16,hud.gold,top)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.debug.add_button(top,"×",func(): window.visible = false).size_flags_horizontal = Control.SIZE_SHRINK_END
	var filters = HBoxContainer.new()
	filters.add_theme_constant_override("separation",4)
	body.add_child(filters)
	for which in FILTERS:
		var b: Button = game.debug.add_button(filters,FILTER_TITLES[which],func(): show_filter(which))
		b.toggle_mode = true
		if which in Items.RARITY_COLORS:
			for look in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]: b.add_theme_color_override(look,Items.RARITY_COLORS[which])
		filter_buttons[which] = b
	count = hud.label("",12,hud.cream,body)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380,440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation",3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

func show_filter(which: String) -> void:
	filter = which
	for f in filter_buttons: filter_buttons[f].set_pressed_no_signal(f == which)
	for old in list.get_children():
		list.remove_child(old)
		old.queue_free()
	marked_for = game.run.class_id
	for id in listed(which): list.add_child(row(id))
	refresh()

# One base item: its picture, its name in its rarity's colour, and what it
# is. A click puts it in the bag; a common item's U and R buttons put in an
# uncommon or a rare one made of it.
func row(id: String) -> Button:
	var item: Dictionary = Items.BASES[id]
	var about: Dictionary = Items.describe(id,game.run.class_id)
	var b = Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0,ICON+8)
	for state in ["normal","hover","pressed"]:
		var style = hud.panel_style(Color(.07,.075,.08) if state == "normal" else Color(.16,.15,.13),Items.color(id).darkened(.45))
		style.set_content_margin_all(4)
		b.add_theme_stylebox_override(state,style)
	var tip: Array = [about.kind]+about.stats
	if not about.effect.is_empty(): tip.append(about.effect)
	if not about.note.is_empty(): tip.append(about.note)
	b.tooltip_text = "\n".join(tip)
	b.pressed.connect(func(): add(Items.make(id)))
	var icon = TextureRect.new()
	icon.texture = hud.panels.item_icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4,4); icon.size = Vector2(ICON,ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var name_label = hud.label(item.name,14,Items.color(id),b)
	name_label.position = Vector2(ICON+12,4)
	var rarity: String = item.get("rarity","starting")
	var kind_label = hud.label("%s · %s%s" % [rarity.capitalize(),about.kind,"" if about.note.is_empty() else " · can't use"],11,Color(.62,.6,.53),b)
	kind_label.position = Vector2(ICON+12,24)
	if rarity == "common":
		var x = 300.0
		for roll in [["U","uncommon"],["R","rare"]]:
			var magic = Button.new()
			magic.text = roll[0]
			magic.name = roll[1]
			magic.focus_mode = Control.FOCUS_NONE
			magic.custom_minimum_size = Vector2(26,26)
			magic.position = Vector2(x,ICON*.5-9)
			magic.tooltip_text = "Add a random %s %s" % [roll[1],item.name]
			for look in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]: magic.add_theme_color_override(look,Items.RARITY_COLORS[roll[1]])
			magic.pressed.connect(func(): add(Items.enchant(id,roll[1],rng)))
			b.add_child(magic)
			x += 30.0
	if not about.note.is_empty(): b.modulate = Color(1,1,1,.6)
	return b

func add(inst: Dictionary) -> void:
	if Items.stow(game.run,inst):
		game.toast("[Debug] %s added to the bag" % Items.name_of(inst))
		game.save_run()
		if game.hud.panels.any_open(): game.hud.panels.refresh()
	else: game.toast("[Debug] The bag is full")
	refresh()

# How many items are listed and how much room the bag has (the bag may
# change under it, and the class with a reset run).
func refresh() -> void:
	if not is_open(): return
	if marked_for != game.run.class_id:
		show_filter(filter)
		return
	var room: int = Items.free_places(game.run)
	count.text = "%d item%s · click one to add it to the bag · %d free place%s" % [list.get_child_count(),"" if list.get_child_count() == 1 else "s",room,"" if room == 1 else "s"]
	window.reset_size()
