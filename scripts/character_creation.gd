extends Control
## Making a new character (from the main menu: Game.new_run_menu): the three
## classes side by side, each shown as he will start, in his starting gear,
## standing at his ease (a figure in a small lit stage of its own, a
## SubViewport); one chosen by clicking it; a name to be given him (his own:
## Save.name_problem); the difficulty; and Begin, or Back to the main menu.
const Data = preload("res://scripts/data.gd")
const Items = preload("res://scripts/items.gd")
const Visual = preload("res://scripts/visual.gd")
const Shrine = preload("res://scripts/ui_theme.gd")
const Save = preload("res://scripts/save.gd")
const SUMMARIES = {"warrior":"Sword and shield, heavy armor.\nCleaves, bashes and leaps into the fray.","ranger":"Bow and dagger, leather.\nShoots from afar, strikes from the shadows.","wizard":"Staff and robes.\nIce, fire and lightning."}
const STAGE = Vector2i(300,400)
var game
var chosen = "warrior"
var difficulty = 0
var cards: Dictionary = {}
var figures: Array = []
var name_field: LineEdit
var problem: Label
var difficulty_buttons: Array = []

func setup(owner_game) -> void:
	game = owner_game
	name = "CharacterCreation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Shrine.make()
	var veil = ColorRect.new()
	veil.color = Color(.035,.025,.012,.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var middle = CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(middle)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",Shrine.panel(22))
	middle.add_child(panel)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	panel.add_child(body)
	var heading = text("CREATE A CHARACTER",30,Shrine.GOLD,body)
	heading.add_theme_font_override("font",Shrine.heading())
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",18)
	body.add_child(row)
	for class_id in Data.CLASSES: row.add_child(card(class_id))
	# The name.
	var naming = HBoxContainer.new()
	naming.alignment = BoxContainer.ALIGNMENT_CENTER
	naming.add_theme_constant_override("separation",12)
	body.add_child(naming)
	text("Name",20,Shrine.TEXT,naming)
	name_field = LineEdit.new()
	name_field.custom_minimum_size = Vector2(340,40)
	name_field.max_length = Save.NAME_LENGTH
	name_field.placeholder_text = "Your character's name"
	name_field.add_theme_font_size_override("font_size",20)
	name_field.text_changed.connect(func(_t): problem.text = "")
	name_field.text_submitted.connect(func(_t): begin())
	naming.add_child(name_field)
	problem = text("",17,Color(1,.55,.4),body)
	problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The difficulty, and the way on or back.
	var choices = HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation",12)
	body.add_child(choices)
	text("Difficulty",20,Shrine.TEXT,choices)
	for i in Data.DIFFICULTIES.size():
		var b = Button.new()
		b.text = Data.DIFFICULTIES[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130,40)
		b.pressed.connect(func(): pick_difficulty(i))
		choices.add_child(b)
		difficulty_buttons.append(b)
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 60
	choices.add_child(spacer)
	var back = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(130,44)
	back.pressed.connect(func(): game.main_menu())
	choices.add_child(back)
	var go = Button.new()
	go.name = "Begin"
	go.text = "Begin"
	go.custom_minimum_size = Vector2(170,44)
	go.pressed.connect(begin)
	choices.add_child(go)
	pick(chosen)
	pick_difficulty(0)
	name_field.call_deferred("grab_focus")

func text(value: String, size: int, colour: Color, parent: Node) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",colour)
	parent.add_child(l)
	return l

# One class's card: his figure on its stage, his name and what he does.
func card(class_id: String) -> Control:
	var frame = PanelContainer.new()
	frame.name = class_id.capitalize()
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: pick(class_id))
	var inner = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation",6)
	frame.add_child(inner)
	var holder = SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(STAGE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(holder)
	var stage = SubViewport.new()
	stage.size = STAGE
	stage.own_world_3d = true
	stage.msaa_3d = Viewport.MSAA_4X
	holder.add_child(stage)
	build_stage(stage,class_id)
	var title = text(class_id.capitalize(),24,Shrine.GOLD,inner)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",Shrine.heading())
	var about = text(SUMMARIES[class_id],15,Shrine.TEXT,inner)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.custom_minimum_size.x = STAGE.x
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cards[class_id] = frame
	return frame

# The stage: a dim, warm room's light on him, a key light from the upper
# left, and the camera at his height, a little below his eyes.
func build_stage(stage: SubViewport, class_id: String) -> void:
	var world = Node3D.new()
	stage.add_child(world)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.07,.055,.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.75,.66,.56)
	e.ambient_light_energy = .55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,-40,0)
	key.light_energy = 1.3
	key.light_color = Color(1,.9,.78)
	world.add_child(key)
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20,150,0)
	rim.light_energy = .6
	rim.light_color = Color(.7,.78,1)
	world.add_child(rim)
	var floor = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = .9; disc.bottom_radius = .9; disc.height = .04
	floor.mesh = disc
	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color(.22,.18,.14)
	stone.roughness = .95
	floor.material_override = stone
	floor.position = Vector3.DOWN*.02
	world.add_child(floor)
	var figure = Visual.new()
	world.add_child(figure)
	figure.setup(false,Color.WHITE,"",1.0,"",class_id)
	var kit = {"class_id":class_id}
	Items.outfit(kit,class_id)
	figure.wear(kit.equipment)
	figure.rotation.y = .35
	figure.play(figure.idle_action())
	figures.append(figure)
	var camera = Camera3D.new()
	camera.fov = 30
	# (Aimed by its transform: the stage is not in the tree yet.)
	var eye = Vector3(0,1.0,4.6)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0,.92,0)-eye),eye)
	world.add_child(camera)

func _process(dt: float) -> void:
	for figure in figures:
		if is_instance_valid(figure): figure.advance(dt)

func pick(class_id: String) -> void:
	chosen = class_id
	for id in cards:
		var frame: PanelContainer = cards[id]
		var look: StyleBoxFlat = Shrine.inset(Shrine.GOLD if id == chosen else Shrine.EDGE,id == chosen)
		look.set_border_width_all(3 if id == chosen else 1)
		look.set_content_margin_all(8)
		frame.add_theme_stylebox_override("panel",look)
		frame.modulate = Color.WHITE if id == chosen else Color(.78,.76,.72)

func pick_difficulty(i: int) -> void:
	difficulty = i
	for k in difficulty_buttons.size(): difficulty_buttons[k].button_pressed = k == i

func begin() -> void:
	var wanted: String = name_field.text.strip_edges()
	var wrong: String = Save.name_problem(wanted)
	if not wrong.is_empty():
		problem.text = wrong
		return
	game.begin_character(chosen,wanted,difficulty)
