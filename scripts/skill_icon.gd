extends Control
## A skill's icon, drawn as line art in the HUD's colors (no textures). Each
## glyph is a list of strokes in a unit square, y down: "l" a line through
## points, "p" a closed outline, "c" a circle, "d" a filled dot, and "a" an arc
## (centre, radius, from and to in degrees, clockwise from the right). Skills
## without a glyph of their own show their initials.
const SHIELD = ["p",.2,.16,.8,.16,.8,.5,.5,.88,.2,.5]
const GLYPHS = {
	"cleave":[["a",.5,.82,.56,205,335],["a",.5,.82,.34,215,325],["d",.5,.82,.055]],
	"leap":[["a",.42,.72,.3,180,360],["l",.6,.6,.72,.74,.84,.6],["l",.5,.9,.94,.9],["d",.12,.76,.05]],
	"ground_slam":[["l",.5,.1,.5,.5],["l",.34,.36,.5,.52,.66,.36],["l",.08,.72,.28,.64,.4,.78,.5,.62,.6,.78,.72,.64,.92,.72],["l",.3,.9,.7,.9]],
	"powerful_strike":[["l",.24,.76,.8,.2],["l",.26,.56,.44,.74],["d",.19,.81,.045],["l",.86,.36,.95,.4],["l",.64,.14,.6,.05],["l",.88,.12,.95,.05]],
	"shield_bash":[["p",.1,.18,.6,.18,.6,.5,.35,.84,.1,.5],["l",.7,.3,.92,.22],["l",.72,.5,.95,.5],["l",.7,.7,.92,.78]],
	"vampiric_strike":[["a",.5,.6,.24,-20,200],["l",.726,.518,.5,.12,.274,.518],["l",.5,.5,.5,.7],["l",.4,.6,.6,.6]],
	"shadow_strike":[["a",.46,.5,.36,50,310],["a",.72,.5,.2775,96,264],["d",.82,.26,.035],["d",.9,.44,.025]],
	"execute":[["c",.5,.42,.27],["d",.4,.42,.06],["d",.6,.42,.06],["l",.38,.66,.38,.84,.62,.84,.62,.66],["l",.5,.7,.5,.84]],
	"dash_attack":[["l",.06,.32,.4,.32],["l",.02,.5,.44,.5],["l",.06,.68,.4,.68],["a",.5,.5,.4,-65,65]],
	"shield_expertise":[SHIELD,["l",.36,.44,.47,.58,.66,.32]],
	"endurance":[["p",.6,.08,.28,.54,.48,.54,.4,.92,.74,.42,.54,.42]],
	"quick_strikes":[["l",.14,.8,.42,.2],["l",.38,.8,.66,.2],["l",.62,.8,.9,.2]],
	"cursed_blade":[["l",.5,.08,.5,.64],["l",.32,.64,.68,.64],["l",.5,.64,.5,.84],["d",.5,.88,.045],["d",.28,.3,.04],["d",.72,.42,.04],["d",.3,.5,.03]],
	"offensive_rhythm":[["l",.28,.4,.5,.18,.72,.4],["l",.28,.62,.5,.4,.72,.62],["l",.28,.84,.5,.62,.72,.84]],
	"defensive_rhythm":[SHIELD,["l",.34,.34,.66,.34],["l",.36,.5,.64,.5]],
	"spiked_shield":[["c",.5,.5,.22],["d",.5,.5,.05],["l",.78,.5,.94,.5],["l",.22,.5,.06,.5],["l",.5,.78,.5,.94],["l",.5,.22,.5,.06],["l",.7,.7,.81,.81],["l",.3,.3,.19,.19],["l",.7,.3,.81,.19],["l",.3,.7,.19,.81]]}
var id = ""
var tint = Color(.93,.91,.82)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_skill(skill_id: String, color: Color) -> void:
	if skill_id==id and color==tint: return
	id = skill_id
	tint = color
	queue_redraw()

func points(stroke: Array, origin: Vector2, side: float) -> PackedVector2Array:
	var list = PackedVector2Array()
	for i in range(1,stroke.size(),2): list.append(origin+Vector2(stroke[i],stroke[i+1])*side)
	return list

func _draw() -> void:
	if id.is_empty(): return
	var side = minf(size.x,size.y)
	var origin = (size-Vector2(side,side))*.5
	var width = maxf(1.5,side*.07)
	if not GLYPHS.has(id):
		var initials = ""
		for word in id.split("_"): initials += word.left(1).to_upper()
		var font = ThemeDB.fallback_font
		var font_size = int(side*.5)
		draw_string(font,origin+Vector2(0,side*.5+font_size*.36),initials.left(2),HORIZONTAL_ALIGNMENT_CENTER,side,font_size,tint)
		return
	for stroke in GLYPHS[id]:
		match stroke[0]:
			"l": draw_polyline(points(stroke,origin,side),tint,width,true)
			"p":
				var outline = points(stroke,origin,side)
				outline.append(outline[0])
				draw_polyline(outline,tint,width,true)
			"c": draw_arc(origin+Vector2(stroke[1],stroke[2])*side,stroke[3]*side,0,TAU,32,tint,width,true)
			"d": draw_circle(origin+Vector2(stroke[1],stroke[2])*side,stroke[3]*side,tint)
			"a": draw_arc(origin+Vector2(stroke[1],stroke[2])*side,stroke[3]*side,deg_to_rad(stroke[4]),deg_to_rad(stroke[5]),24,tint,width,true)
