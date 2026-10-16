extends RefCounted
## Artwork and palette only. Gauges, buttons and game state stay in Hud.
const WIDTH = 600.0
const SOURCE = Vector2(2172,724)
const STYLES = [
	{"id":"classic","name":"Current · Classic","texture":"","accent":Color(.91,.75,.45),"edge":Color(.37,.31,.21),"background":Color(.035,.032,.028,.94),"rim_dark":Color(.13,.09,.055),"rim_light":Color(.69,.53,.29)},
	{"id":"imperial_bronze","name":"Imperial Bronze","texture":"res://assets/ui/hud/imperial_bronze.png","accent":Color(.96,.8,.48),"edge":Color(.49,.36,.18),"background":Color(.035,.025,.014,.58),"rim_dark":Color(.13,.085,.035),"rim_light":Color(.75,.57,.29),"left":Vector2(296.5,341.5),"right":Vector2(1876.5,341.5),"top":66.0,"bottom":658.0,"bar_y":444.0},
	{"id":"sandstone_shrine","name":"Sandstone Shrine","texture":"res://assets/ui/hud/sandstone_shrine.png","accent":Color(1,.88,.65),"edge":Color(.6,.48,.3),"background":Color(.065,.048,.03,.65),"rim_dark":Color(.27,.2,.12),"rim_light":Color(.88,.75,.48),"left":Vector2(296.5,342.5),"right":Vector2(1876,342.5),"top":57.0,"bottom":666.0,"bar_y":445.0},
	{"id":"obsidian_oracle","name":"Obsidian Oracle","texture":"res://assets/ui/hud/obsidian_oracle.png","accent":Color(.67,.9,.9),"edge":Color(.31,.47,.49),"background":Color(.012,.026,.034,.67),"rim_dark":Color(.07,.1,.12),"rim_light":Color(.68,.75,.76),"left":Vector2(294,334.5),"right":Vector2(1878,334.5),"top":31.0,"bottom":681.0,"bar_y":432.0},
	{"id":"crimson_legion","name":"Crimson Legion","texture":"res://assets/ui/hud/crimson_legion.png","accent":Color(.94,.74,.45),"edge":Color(.48,.3,.18),"background":Color(.045,.021,.018,.63),"rim_dark":Color(.12,.075,.05),"rim_light":Color(.65,.48,.25),"left":Vector2(298,339),"right":Vector2(1872.5,339),"top":53.0,"bottom":656.0,"bar_y":442.0}
]

static func index_of(id) -> int:
	if not id is String: return 0
	for i in STYLES.size():
		if STYLES[i].id==id: return i
	return 0
