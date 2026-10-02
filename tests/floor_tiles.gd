extends SceneTree
## The floors' patterns. The terraces are paved in the French Versailles
## pattern of the reference photo (assets/shaders/slate_paving.gdshader): its
## 48 stones must tile the 12 x 11 unit panel exactly, each unit square
## covered by the stone the panel's table names, in the photo's sizes. The
## rooms' marble slabs are bevelled at their edges.

var passed = 0
var failures: Array = []

func _initialize(): call_deferred("test")

func check(ok: bool, message: String):
	if ok: passed += 1
	else:
		failures.append(message)
		push_error(message)

# The numbers inside the shader's `NAME[...] = type[](...)` table.
func table(code: String, name: String) -> Array:
	var start = code.find(name+"[")
	if start < 0: return []
	var open = code.find("(",code.find("=",start))
	var close = code.find(");",open)
	var numbers = []
	var regex = RegEx.new()
	regex.compile("-?[0-9]+(\\.[0-9]+)?")
	for m in regex.search_all(code.substr(open+1,close-open-1).replace("vec4","")): numbers.append(float(m.get_string()))
	return numbers

func test():
	var paving: String = load("res://assets/shaders/slate_paving.gdshader").code
	var layout = table(paving,"LAYOUT")
	var cells = table(paving,"CELLS")
	check(layout.size() == 48*4,"The panel has the photo's 48 stones (%d)" % (layout.size()/4))
	check(cells.size() == 12*11,"The panel is 12 units across and 11 down (%d unit squares)" % cells.size())
	# Every unit square lies in exactly one stone, the one the table names.
	var covered = []
	covered.resize(12*11)
	covered.fill(-1)
	var overlaps = 0
	for k in layout.size()/4:
		var x = int(layout[k*4]); var y = int(layout[k*4+1]); var w = int(layout[k*4+2]); var h = int(layout[k*4+3])
		for j in range(y,y+h):
			for i in range(x,x+w):
				if i >= 12 or j >= 11 or covered[j*12+i] != -1: overlaps += 1
				else: covered[j*12+i] = k
	check(overlaps == 0 and not covered.has(-1),"The stones tile the panel without gaps or overlaps")
	var agrees = true
	for c in cells.size(): if c < covered.size() and int(cells[c]) != covered[c]: agrees = false
	check(agrees,"Each unit square's stone in the table is the stone that covers it")
	# The photo's sizes: 16 small squares, 10 large squares, 8 tall and 6 wide
	# oblongs, 4 large upright and 4 large wide oblongs.
	var sizes = {}
	for k in layout.size()/4:
		var key = "%dx%d" % [int(layout[k*4+2]),int(layout[k*4+3])]
		sizes[key] = sizes.get(key,0)+1
	check(sizes == {"1x1":16,"2x2":10,"1x2":8,"2x1":6,"2x3":4,"3x2":4},"The stones come in the photo's sizes: %s" % str(sizes))
	# The photo's first row, left to right: a 2 x 3 stone, a 1 x 2, a 2 x 1,
	# a 2 x 2, a 1 x 2, a 1 x 1 and a 3 x 2.
	var first_row = []
	for k in layout.size()/4: if int(layout[k*4+1]) == 0: first_row.append([int(layout[k*4]),int(layout[k*4+2]),int(layout[k*4+3])])
	first_row.sort()
	check(first_row == [[0,2,3],[2,1,2],[3,2,1],[5,2,2],[7,1,2],[8,1,1],[9,3,2]],"The panel's top row is laid as in the photo: %s" % str(first_row))
	var marble: String = load("res://assets/shaders/quartz_floor.gdshader").code
	check("bevel_width" in marble and "slope" in marble,"The rooms' marble slabs are bevelled at their edges")
	print("FLOOR_TILES %d passed; %s" % [passed,failures])
	quit(1 if failures.size() > 0 else 0)
