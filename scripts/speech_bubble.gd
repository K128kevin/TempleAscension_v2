extends Control
## Words said over someone's head (a town guard spoken to: scripts/hud.gd
## speak), as the first Temple Ascension showed them: a dark panel, rounded,
## edged in old gold, its tail pointing down to the speaker; the words in a
## pale typewriter face, typed in a letter every REVEAL seconds; then left to
## be read (HOLD a word, HOLD_LEAST at least) before it goes.
const WIDTH = 304.0
const PAD = Vector2(14,12)
const TAIL = Vector2(9,14)
const RADIUS = 7.0
const FILL = Color(0x14/255.0,0x11/255.0,0x0d/255.0,.94)
const EDGE = Color(0x8b/255.0,0x79/255.0,0x55/255.0,.9)
const INK = Color(0xe6/255.0,0xdc/255.0,0xc3/255.0)
const REVEAL = .018
const HOLD = .22
const HOLD_LEAST = 1.8
const FADE = .3
static var face: SystemFont

var words = ""
var typed = 0
var clock = 0.0
var line: Label

func setup(said: String, size_px: int = 14) -> void:
	words = said
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if face == null:
		face = SystemFont.new()
		face.font_names = PackedStringArray(["Courier New","Courier","Menlo","monospace"])
	line = Label.new()
	line.add_theme_font_override("font",face)
	line.add_theme_font_size_override("font_size",size_px)
	line.add_theme_color_override("font_color",INK)
	line.add_theme_constant_override("line_spacing",3)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = WIDTH-PAD.x*2
	line.position = PAD
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	# Laid out whole first, so the panel stays still as the words type in.
	line.text = words
	line.visible_characters = 0
	size = Vector2(WIDTH,line.get_combined_minimum_size().y+PAD.y*2)

# How long it is shown in all: typed in, then read.
func lasts() -> float:
	return words.length()*REVEAL+maxf(HOLD_LEAST,words.split(" ",false).size()*HOLD)

func advance(dt: float) -> bool:
	clock += dt
	typed = mini(words.length(),int(clock/REVEAL))
	line.visible_characters = typed
	modulate.a = clampf((lasts()-clock)/FADE,0.0,1.0)
	return clock < lasts()

# Its panel's foot-middle, where the tail starts, goes `TAIL.y` above `at`.
func point_at(at: Vector2) -> void:
	position = at-Vector2(size.x*.5,size.y+TAIL.y)

func _draw() -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = FILL
	box.border_color = EDGE
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(RADIUS))
	box.anti_aliasing = true
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	var middle = size.x*.5
	var tail = PackedVector2Array([Vector2(middle-TAIL.x,size.y-1),Vector2(middle,size.y+TAIL.y),Vector2(middle+TAIL.x,size.y-1)])
	draw_colored_polygon(tail,FILL)
	draw_line(tail[0],tail[1],EDGE,1.0,true)
	draw_line(tail[1],tail[2],EDGE,1.0,true)
