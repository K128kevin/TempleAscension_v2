extends RefCounted
## Shared Sandstone Shrine materials. Semantic health, rarity and status colours
## are supplied by callers; all chrome uses this same stone and gold vocabulary.
const STONE = Color(.76,.63,.43)
const GOLD = Color(.96,.8,.49)
const TEXT = Color("f6f1e7")
const MUTED = Color("d4c9b3")
const DISABLED_TEXT = Color("aaa18f")
const TAB_TEXT = Color("fff8e9")
const TAB_SIZE = 16
const INSET = Color(.065,.052,.037,.97)
const EDGE = Color(.48,.37,.22)
const PANEL = preload("res://assets/ui/shrine_panel.png")
const Frame = preload("res://scripts/shrine_style.gd")

static var title_face: SystemFont

static func heading() -> Font:
	if title_face == null:
		title_face = SystemFont.new()
		title_face.font_names = PackedStringArray(["Palatino Linotype","Palatino","Georgia","Times New Roman","serif"])
	return title_face

static func panel(padding: float = 20.0, border: float = 16.0) -> StyleBox:
	var s = Frame.new()
	s.texture = PANEL
	# Full-resolution source with equal, repeating borders at this display width.
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		s.set_texture_margin(side,border)
		s.set_content_margin(side,padding)
	return s

static func button(state: String = "normal", padding: float = 6.0) -> StyleBox:
	var s = panel(padding)
	# Narrower trim leaves a dark text area even on short buttons.
	s.set_texture_margin_all(8)
	s.content_margin_left = maxf(10,padding)
	s.content_margin_right = maxf(10,padding)
	s.modulate_color = {"normal":Color(.85,.8,.7),"hover":Color(1.13,1.06,.91),"pressed":Color(.69,.6,.44),"focus":Color(1.1,.97,.7),"disabled":Color(.43,.4,.34,.8)}.get(state,Color.WHITE)
	return s

static func tab(active: bool, hovered: bool = false) -> StyleBoxFlat:
	var s = inset(GOLD if active else EDGE)
	s.bg_color = Color("30271b") if active else (Color("292217") if hovered else Color("191610"))
	s.border_width_top = 3 if active else 1
	s.set_content_margin_all(7)
	s.content_margin_left = 10; s.content_margin_right = 10
	return s

static func inset(tone: Color = EDGE, active: bool = false) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = INSET.lightened(.055) if active else INSET
	s.border_color = tone
	s.border_width_left = 2; s.border_width_top = 2
	s.border_width_right = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(3)
	s.set_content_margin_all(4)
	return s

static func make() -> Theme:
	var t = Theme.new()
	t.default_font_size = 18
	for type in ["Label","Button","OptionButton","CheckButton","CheckBox","LineEdit","RichTextLabel","PopupMenu","TooltipLabel"]:
		t.set_color("font_color",type,TEXT)
		t.set_color("font_hover_color",type,Color(1,.96,.85))
		t.set_color("font_pressed_color",type,GOLD)
		t.set_color("font_disabled_color",type,DISABLED_TEXT)
		t.set_color("font_hover_pressed_color",type,TEXT)
		t.set_color("font_focus_color",type,TEXT)
		t.set_color("font_outline_color",type,Color(.025,.018,.011))
		t.set_constant("outline_size",type,2)
	for type in ["Button","OptionButton","CheckButton","CheckBox"]:
		for state in ["normal","hover","pressed","disabled"]: t.set_stylebox(state,type,button(state))
		var focus = inset(GOLD)
		focus.bg_color = Color.TRANSPARENT
		focus.set_border_width_all(2)
		t.set_stylebox("focus",type,focus)
	t.set_stylebox("panel","PanelContainer",panel())
	t.set_stylebox("panel","Panel",inset())
	t.set_stylebox("panel","PopupMenu",panel(14,10))
	t.set_stylebox("hover","PopupMenu",inset(GOLD,true))
	t.set_stylebox("separator","PopupMenu",inset(EDGE))
	t.set_font_size("font_size","PopupMenu",14)
	t.set_stylebox("panel","TooltipPanel",panel(14,10))
	t.set_color("font_color","TooltipLabel",TEXT)
	t.set_font_size("font_size","TooltipLabel",13)
	for state in ["normal","focus","read_only"]: t.set_stylebox(state,"LineEdit",inset(GOLD if state=="focus" else EDGE))
	for type in ["HScrollBar","VScrollBar"]:
		t.set_stylebox("scroll",type,inset())
		for state in ["grabber","grabber_highlight","grabber_pressed"]:
			var s = inset(GOLD if state!="grabber" else STONE)
			s.bg_color = EDGE.lightened(.1 if state!="grabber" else 0)
			t.set_stylebox(state,type,s)
	var track = inset(STONE)
	track.set_content_margin_all(1)
	t.set_stylebox("background","ProgressBar",track)
	var fill = StyleBoxFlat.new()
	fill.bg_color = GOLD
	t.set_stylebox("fill","ProgressBar",fill)
	return t
