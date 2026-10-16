extends RefCounted
## The mountains that close the outdoor world (scripts/overworld.gd) in on
## the north, behind the desert the track crosses, and on the east, round the
## temple and down to the river in the south. Their foot stands a few metres
## back from the open ground's edge (Overworld.mountain_depth), where a few
## of the rim's rocks lie at it; from there they rise gently out of the sand,
## steepening as they climb in ridges to peaks some sixty metres up.
##
## They are a height field, built in square tiles of two-metre cells (the
## tiles nowhere near them are left out), drawn by the photographed cliff
## (assets/shaders/mountain_rock.gdshader).
const TILE = 64.0
const STEP = 2.0
# How far the field reaches: well past the map, under the horizon's crests.
const REACH = Rect2(-920,-560,1440,1180)
# How tall the range grows, and over what depth into it it gets there.
const PEAK = 60.0
const CLIMB = 110.0
const CLIFF = 2.5

# The tiles, baked by tools/bake_mountains.gd from `generate` (they take
# seconds to build); tests/overworld.gd checks they still match it.
const BAKED = "res://assets/models/mountains.scn"

static func build(world) -> void:
	var range: Node3D = load(BAKED).instantiate() if ResourceLoader.exists(BAKED) else generate(world)
	range.name = "Mountains"
	var material = rock()
	for tile in range.get_children(): tile.material_override = material
	world.add_child(range)

static func rock() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/mountain_rock.gdshader")
	material.set_shader_parameter("cliff_map",load("res://assets/textures/scan_namaqualand_cliff_02_diff.jpg"))
	material.set_shader_parameter("cliff_normal",load("res://assets/textures/scan_namaqualand_cliff_02_nor_gl.jpg"))
	material.set_shader_parameter("boulder_map",load("res://assets/textures/scan_namaqualand_boulder_05_diff.jpg"))
	material.set_shader_parameter("detail_map",load("res://assets/textures/rock_detail.jpg"))
	material.set_shader_parameter("sand_map",load("res://assets/textures/sand_fine.jpg"))
	return material

static func noises() -> Array:
	var ridges = FastNoiseLite.new()
	ridges.seed = 71
	ridges.frequency = 1.0/210.0
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 3
	var crags = FastNoiseLite.new()
	crags.seed = 72
	crags.frequency = 1.0/30.0
	crags.fractal_octaves = 2
	# Broad, rounded swells, for the summits.
	var swells = FastNoiseLite.new()
	swells.seed = 73
	swells.frequency = 1.0/150.0
	swells.fractal_octaves = 3
	return [ridges,crags,swells]

# Every tile of the range, as a node of MeshInstance3Ds.
static func generate(world) -> Node3D:
	var noise = noises()
	var range = Node3D.new()
	var cells = int(TILE/STEP)
	var tz = REACH.position.y
	while tz < REACH.end.y:
		var tx = REACH.position.x
		while tx < REACH.end.x:
			# Heights over the tile and a cell round it (for the normals).
			var heights = PackedFloat32Array()
			heights.resize((cells+3)*(cells+3))
			var any = false
			for j in cells+3:
				for i in cells+3:
					var h = height(world,noise,tx+(i-1)*STEP,tz+(j-1)*STEP)
					heights[j*(cells+3)+i] = h
					if h > 0.0: any = true
			if any:
				var node = tile(heights,cells,tx,tz)
				range.add_child(node)
				node.owner = range
			tx += TILE
		tz += TILE
	return range

# The mountains' height at a point: below the ground short of their foot.
static func height(world, noise: Array, x: float, z: float) -> float:
	var ridges: FastNoiseLite = noise[0]
	var crags: FastNoiseLite = noise[1]
	var depth: float = world.mountain_depth(x,z)
	# The field sinks away at its edges, behind the crests.
	var edge = minf(minf(x-REACH.position.x,REACH.end.x-x),minf(z-REACH.position.y,REACH.end.y-z))
	var fade = smoothstep(0.0,120.0,edge)
	if depth <= 0.0: return -2.0+depth*.2
	# Long ridges and broad swells, their crests weathered round, with
	# valleys between them.
	var ridge = clampf(ridges.get_noise_2d(x,z)*.5+.5,0.0,1.0)
	var swell = clampf((noise[2] as FastNoiseLite).get_noise_2d(x,z)*.5+.5,0.0,1.0)
	var shape = smoothstep(0.0,1.0,ridge*.35+swell*.65)
	var rise = PEAK*(1.0-exp(-depth/CLIMB))*(.35+1.05*shape)
	var cliff = CLIFF*smoothstep(0.0,5.0,depth)*(.75+.5*(crags.get_noise_2d(x*.4,z*.4)*.5+.5))
	var rough = crags.get_noise_2d(x,z)*2.2*smoothstep(0.0,10.0,depth)
	# They rise out of the desert gently, steepening as they climb.
	var ease = smoothstep(0.0,40.0,depth)
	return (cliff+rise*(.15+.85*ease)+rough*ease)*fade-20.0*(1.0-fade)

static func tile(heights: PackedFloat32Array, cells: int, tx: float, tz: float) -> MeshInstance3D:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wide = cells+3
	for j in cells+1:
		for i in cells+1:
			var at = (j+1)*wide+i+1
			var normal = Vector3(heights[at-1]-heights[at+1],2.0*STEP,heights[at-wide]-heights[at+wide]).normalized()
			tool.set_normal(normal)
			tool.set_uv(Vector2(tx+i*STEP,tz+j*STEP))
			tool.add_vertex(Vector3(tx+i*STEP,heights[at],tz+j*STEP))
	var row = cells+1
	for j in cells:
		for i in cells:
			var a = j*row+i
			# (Split along whichever diagonal follows the slope better.)
			var h00 = heights[(j+1)*wide+i+1]; var h11 = heights[(j+2)*wide+i+2]
			var h10 = heights[(j+1)*wide+i+2]; var h01 = heights[(j+2)*wide+i+1]
			if absf(h00-h11) < absf(h10-h01):
				for corner in [a,a+1,a+row+1,a,a+row+1,a+row]: tool.add_index(corner)
			else:
				for corner in [a,a+1,a+row,a+1,a+row+1,a+row]: tool.add_index(corner)
	tool.generate_tangents()
	var node = MeshInstance3D.new()
	node.mesh = tool.commit()
	node.name = "Tile%d_%d" % [tx,tz]
	return node
