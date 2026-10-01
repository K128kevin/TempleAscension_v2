extends Node3D
const Art = preload("res://scripts/assets.gd")
const Layout = preload("res://scripts/layout.gd")
var layout = Layout.new()
var boss_point = Vector3.ZERO
var summon_points: Array[Vector3] = []
var nav = AStarGrid2D.new()
var spawn = Vector3(0,0,9)
var exit_point = Vector3.ZERO
var camera: Camera3D
var zoom = 19.0
var exit_seal: Sprite3D
var bounds = Rect2()
var level = 0
var occluders: Array = []
var occlusion_tick = 0.0
var floor_nodes: Array = []
var shadow_torches: Array[OmniLight3D] = []
var torch_lights: Array[Vector3] = []
# The wall each torch spot is mounted on, as a direction from the torch.
var torch_walls: Dictionary = {}
# Room-center tiles no wall torch reaches; the ambient light keeps them readable.
var ambient_only: Dictionary = {}
var fountain
var desert_backdrop: Sprite3D
var terrace_moonlight: DirectionalLight3D
var boss_moonlight: SpotLight3D
const TERRACE_LIGHT_LAYER = 8
const VISION_RANGE = 16.0
const WALL_HEIGHT = 3.2
const TORCH_ENERGY = 2.4
const TORCH_RANGE = 9.0
const TORCH_DECAY = 1.6
const TORCH_HEIGHT = 2.22
# Estimated floor light, with Godot's omni falloff and floor incidence, that
# still reads clearly in the dark temple: one torch at about three metres.
const LIT_LEVEL = .12
# Floor cells occupied by solid props (stairs, standing braziers). They are
# visible and let sight pass, but are not walkable.
var solid_floor: Dictionary = {}
const VISIBILITY_GRID_ORIGIN = Vector2i(-5,-5)
var visibility_image: Image
var visibility_texture: ImageTexture
var visibility_grid_size = Vector2i.ZERO
var visibility_floor_batches: Array[Dictionary] = []
var visibility_nodes: Array[Node3D] = []
# Cells whose line of sight reveals each node; nodes absent here use their own cell.
var visibility_cells: Dictionary = {}
# Stonework below floor level (the terrace masonry and the summit's storeys):
# outdoor scenery, shown with the desert rather than by line of sight.
var outdoor_scenery: Array[Node3D] = []
# Awake enemies near the hero, as {position, height}, set by Game each frame:
# walls that would hide them fade just as for the hero.
var occlusion_targets: Array = []
# Opacity of a wall faded to show whoever stands behind it.
const FADED_ALPHA = .45
# Only walls this close to someone can hide them from the camera.
const OCCLUSION_REACH = 7.0
var visibility_timer = 0.0
var visibility_player_position = Vector3(INF,INF,INF)
var fog_material: ShaderMaterial

func setup(floor_index: int, run_seed: int = 1) -> void:
	level = floor_index
	layout.generate(run_seed,floor_index)
	spawn = layout.to_world(layout.start)
	exit_point = layout.exit_position()
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.35,.40,.50)
	# Enough fill that the middle of a large room, beyond the wall torches, stays readable.
	e.ambient_light_energy = .24
	if floor_index==Layout.PLAYGROUND:
		# The playground is evenly lit so models and animations read clearly.
		e.background_color = Color(.16,.18,.22)
		e.ambient_light_color = Color(.85,.85,.9)
		e.ambient_light_energy = .42
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = false
	env.environment = e
	add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.far = 200
	add_child(camera)
	setup_visibility_fog()
	if floor_index==Layout.PLAYGROUND:
		camera.get_node("LineOfSightFog").visible = false
		var sun = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55,-35,0)
		sun.light_energy = .8
		sun.shadow_enabled = true
		add_child(sun)
	var stone = Art.material("stone", [Color(.91,.87,.77),Color(.74,.80,.77),Color(.73,.70,.66),Color(.70,.76,.82),Color(.75,.69,.61),Color(.94,.87,.70)][floor_index])
	# Pale quartz paving keeps the dark stone statues readable against the floor.
	# The playground's floor is a mid grey, so every model reads against it.
	var paving = Art.quartz_material(Color(.46,.47,.5) if floor_index==Layout.PLAYGROUND else Color(.70,.70,.72))
	var court_paving = Art.quartz_material(Color(.74,.64,.64))
	var lower = Vector2i(10000,10000)
	var upper = Vector2i(-10000,-10000)
	var edges: Dictionary = {}
	var torch_candidates: Array[Vector3] = []
	# The ascent stair's footprint is paved and walled like the room around it,
	# although it is solid for movement.
	var surface: Array = layout.cells.keys()
	for y in range(layout.stairs.position.y,layout.stairs.end.y):
		for x in range(layout.stairs.position.x,layout.stairs.end.x): surface.append(Vector2i(x,y))
	# The arrival stairwell is unpaved, but the room's walls still run round it,
	# rising above the flight's deep end.
	for y in range(layout.arrival.position.y,layout.arrival.end.y):
		for x in range(layout.arrival.position.x,layout.arrival.end.x): surface.append(Vector2i(x,y))
	for cell in surface:
		var at = layout.to_world(cell)
		lower = lower.min(Vector2i(at.x,at.z))
		upper = upper.max(Vector2i(at.x,at.z))
		if not layout.arrival.has_point(cell):
			place("floor",at+Vector3.DOWN*.16,Vector3(1,.16,1),court_paving if layout.court.has_point(cell) else paving)
		# The playground is an open plane, without walls.
		if level==Layout.PLAYGROUND: continue
		for direction in Layout.DIRS:
			if layout.is_open(cell+direction): continue
			# The court's solid centerpiece is the fountain, not a wall.
			if layout.court_obstacle.has_point(cell+direction): continue
			var horizontal_edge: bool = direction.y!=0
			var line: float = (at.z+direction.y*.5) if horizontal_edge else (at.x+direction.x*.5)
			var low = floor_index==5 or (layout.on_terrace(cell) and not Rect2i(0,0,layout.size,layout.size).has_point(cell+direction))
			var key = "%s:%s:%s:%s" % [horizontal_edge,line,direction,low]
			if not edges.has(key): edges[key] = {"horizontal":horizontal_edge,"line":line,"direction":direction,"low":low,"along":[]}
			edges[key].along.append(int(at.x if horizontal_edge else at.z))
			# Small wall torches sit inside the boundary, with no floor obstruction.
			if not layout.stairs.has_point(cell) and not layout.arrival.has_point(cell) and not layout.arrival.has_point(cell+direction):
				var spot = at+Vector3(direction.x,0,direction.y)*.28
				torch_candidates.append(spot)
				torch_walls[spot] = Vector3(direction.x,0,direction.y)
	bounds = Rect2(Vector2(lower)-Vector2(.5,.5),Vector2(upper-lower)+Vector2.ONE)
	for edge in edges.values():
		edge.along.sort()
		var index = 0
		while index<edge.along.size():
			var first: int = edge.along[index]
			var last = first
			index += 1
			while index<edge.along.size() and edge.along[index]==last+1 and last-first<3:
				last = edge.along[index]
				index += 1
			var mid = (first+last)*.5
			var pos = Vector3(mid,0,edge.line+edge.direction.y*.14) if edge.horizontal else Vector3(edge.line+edge.direction.x*.14,0,mid)
			var height = 1.0 if edge.low else WALL_HEIGHT
			# Extend each end to the adjacent wall's centerline. The authored
			# molding is wider than its stone core, so a tiny cap overlap leaves
			# open seams at right-angle corners.
			var dimensions = Vector3(last-first+1.28,height,.28) if edge.horizontal else Vector3(.28,height,last-first+1.28)
			var wall = place("wall",pos,dimensions,stone)
			# Walls stand in solid cells that are never seen themselves. Reveal each
			# one from the floor it faces, never from the far side of the wall.
			var faces: Array[Vector2i] = []
			for along in range(first,last+1):
				var floor_at = Vector3(along,0,edge.line-edge.direction.y*.5) if edge.horizontal else Vector3(edge.line-edge.direction.x*.5,0,along)
				faces.append(layout.to_cell(floor_at))
			visibility_cells[wall] = faces
	# The generated rooms determine every landmark and decoration placement.
	for i in layout.rooms.size():
		var room: Rect2i = layout.rooms[i]
		var corner = layout.to_world(room.position)
		# Imported columns occupy solid wall corners, never a corridor tile.
		if not layout.cells.has(room.position+Vector2i(-1,-1)):
			place("column",corner+Vector3(-.65,0,-.65),Vector3(.7,3.8,.7),stone)
		if i%3==1 and not layout.cells.has(room.position+Vector2i(0,-1)):
			place("banner",corner+Vector3(0,1,-.55),Vector3(.7,1.7,.1))
		if level==2 and i%2==1 and not layout.cells.has(room.position+Vector2i(-1,0)):
			var shelf = place("bookcase",corner+Vector3(-.65,0,0),Vector3(.9,2.4,.25),stone)
			shelf.rotation.y = PI/2
	if layout.court.has_area():
		fountain = preload("res://scripts/fountain.gd").new()
		add_child(fountain)
		fountain.setup(layout)
	if floor_index in [3,4,5]: setup_desert(stone)
	# The stairwell up from the floor below; the ascent is in the furthest room.
	if layout.arrival.has_area(): build_arrival(stone)
	if layout.stairs.has_area():
		# The imported flight climbs toward its local -Z from a base at its origin.
		# Scaled to wall height, its top step meets the top of the wall it climbs into.
		var rect: Rect2i = layout.stairs
		var middle = layout.to_world(rect.position)+Vector3(rect.size.x-1,0,rect.size.y-1)*.5
		var flight = place("stairs",middle,Vector3(Layout.STAIR_WIDTH,WALL_HEIGHT,Layout.STAIR_DEPTH),stone)
		flight.rotation.y = atan2(-layout.stairs_dir.x,-layout.stairs_dir.y)
		var reveal: Array[Vector2i] = [layout.exit_cell]
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x): reveal.append(Vector2i(x,y))
		visibility_cells[flight] = reveal
		for cell in reveal.slice(1): solid_floor[cell] = true
	exit_seal = Art.seal(3,Color(.3,1,.85,.85))
	exit_seal.position = exit_point+Vector3.UP*.05
	add_child(exit_seal)
	exit_seal.visible = false
	if floor_index==2: setup_court_torches()
	if level!=Layout.PLAYGROUND: light_floor(torch_candidates)
	if floor_index==5:
		boss_point = layout.to_world(Vector2i(14,10))
		setup_boss_moonlight()
		setup_summit_understructure(facade_stone(stone))
		for corner in [Vector2i(2,2),Vector2i(25,2),Vector2i(2,17),Vector2i(25,17)]:
			var dx = 1 if corner.x<14 else -1
			var dz = 1 if corner.y<10 else -1
			for offset in [Vector2i.ZERO,Vector2i(dx*2,0),Vector2i(dx*4,0),Vector2i(0,dz*2),Vector2i(0,dz*4)]:
				summon_points.append(layout.to_world(corner+offset))
	nav.region = Rect2i(lower,upper-lower+Vector2i.ONE)
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for x in range(lower.x,upper.x+1):
		for z in range(lower.y,upper.y+1):
			if not fits(Vector3(x,0,z),.4): nav.set_point_solid(Vector2i(x,z))
	setup_walkable_mask()
	batch_floors()
	follow(spawn,1)

func setup_desert(stone: Material) -> void:
	# The image lies far beyond/below the gallery. A dark imported foundation under
	# the building keeps the desert out of interior gaps between generated rooms.
	if level<5:
		var dark = StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.albedo_color = Color(.007,.009,.013)
		var center = layout.to_world(Vector2i.ZERO)+Vector3((layout.size-1)*.5,0,(layout.size-1)*.5)
		var foundation = Art.model("floor",Vector3(layout.size,.4,layout.size),dark)
		foundation.position = center+Vector3.DOWN*.6
		add_child(foundation)
	# Deep masonry along the exposed edges makes the elevation above the dunes
	# legible instead of leaving the terrace as a paper-thin floating platform.
	var masonry = Art.material("stone",Color(.22,.27,.34))
	for strip in layout.terrace:
		var corner: Vector3 = layout.to_world(strip.position)-Vector3(.5,0,.5)
		place_scenery("wall",corner+Vector3(strip.size.x*.5,-7,strip.size.y*.5),Vector3(strip.size.x,6.84,strip.size.y),masonry)
	if level<5: setup_terrace_facades(facade_stone(stone))
	desert_backdrop = Sprite3D.new()
	desert_backdrop.name = "MoonlitDesertBelowTerrace"
	desert_backdrop.texture = preload("res://assets/textures/desert_moonlit_ruins_v2.png")
	desert_backdrop.position = Vector3(0,0,-140)
	desert_backdrop.modulate = Color(.60,.64,.72)
	desert_backdrop.visible = false
	desert_backdrop.shaded = false
	desert_backdrop.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	desert_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A distant camera-facing matte retains the image's dune detail, instead
	# of magnifying a tiny portion of it across a giant horizontal plane.
	camera.add_child(desert_backdrop)
	terrace_moonlight = DirectionalLight3D.new()
	terrace_moonlight.name = "DimTerraceMoonlight"
	terrace_moonlight.rotation_degrees = Vector3(-55,-30,0)
	terrace_moonlight.light_color = Color(.50,.61,.80)
	terrace_moonlight.light_energy = .18
	terrace_moonlight.light_cull_mask = TERRACE_LIGHT_LAYER
	terrace_moonlight.shadow_enabled = false
	terrace_moonlight.visible = false
	add_child(terrace_moonlight)

# Which cells are the temple's floor (walkable, or the fountain and stairs that
# stand on it). Outdoors, the fog leaves everything at floor height elsewhere
# alone: the tops of the storeys below the terraces and the summit are scenery.
func setup_walkable_mask() -> void:
	var image = Image.create(visibility_grid_size.x,visibility_grid_size.y,false,Image.FORMAT_R8)
	image.fill(Color.BLACK)
	var interior: Array = layout.cells.keys()+solid_floor.keys()
	if level==2:
		for y in range(layout.court_obstacle.position.y,layout.court_obstacle.end.y):
			for x in range(layout.court_obstacle.position.x,layout.court_obstacle.end.x): interior.append(Vector2i(x,y))
	for cell in interior:
		var pixel: Vector2i = cell-VISIBILITY_GRID_ORIGIN
		if pixel.x>=0 and pixel.y>=0 and pixel.x<visibility_grid_size.x and pixel.y<visibility_grid_size.y:
			image.set_pixel(pixel.x,pixel.y,Color.WHITE)
	fog_material.set_shader_parameter("walkable_mask",ImageTexture.create_from_image(image))

func setup_visibility_fog() -> void:
	visibility_grid_size = Vector2i(layout.size+10,layout.size+10)
	visibility_image = Image.create(visibility_grid_size.x,visibility_grid_size.y,false,Image.FORMAT_R8)
	visibility_image.fill(Color.BLACK)
	visibility_texture = ImageTexture.create_from_image(visibility_image)
	fog_material = ShaderMaterial.new()
	fog_material.shader = preload("res://assets/shaders/fog_of_war.gdshader")
	fog_material.set_shader_parameter("visibility_mask",visibility_texture)
	# Drawn last over the whole view; the shader reads scene depth so raised
	# surfaces such as walls are fogged by their own cell, not the floor behind.
	fog_material.render_priority = Material.RENDER_PRIORITY_MAX
	var quad = QuadMesh.new()
	quad.size = Vector2(2,2)
	var fog = MeshInstance3D.new()
	fog.name = "LineOfSightFog"
	fog.mesh = quad
	fog.material_override = fog_material
	fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog.custom_aabb = AABB(Vector3(-1e4,-1e4,-1e4),Vector3(2e4,2e4,2e4))
	fog.position.z = -1
	camera.add_child(fog)
	var world_origin = Vector2(VISIBILITY_GRID_ORIGIN.x-layout.start.x,VISIBILITY_GRID_ORIGIN.y-layout.start.y+9)
	fog_material.set_shader_parameter("map_world_origin",world_origin)
	fog_material.set_shader_parameter("map_dimensions",Vector2(visibility_grid_size))

func setup_boss_moonlight() -> void:
	boss_moonlight = SpotLight3D.new()
	boss_moonlight.name = "DimBossRoomMoonlight"
	boss_moonlight.position = boss_point+Vector3.UP*9
	boss_moonlight.rotation_degrees.x = -90
	boss_moonlight.light_color = Color(.50,.61,.80)
	boss_moonlight.light_energy = 1.7
	boss_moonlight.spot_range = 24
	boss_moonlight.spot_angle = 68
	boss_moonlight.spot_attenuation = 1.0
	boss_moonlight.light_cull_mask = 3
	boss_moonlight.shadow_enabled = false
	add_child(boss_moonlight)

func setup_court_torches() -> void:
	var first: Vector3 = layout.to_world(layout.court.position)
	var last: Vector3 = layout.to_world(layout.court.end-Vector2i.ONE)
	var center = (first+last)*.5
	for offset in [-8.0,8.0]:
		torch(Vector3(center.x+offset,0,first.z-.28),true,Vector3.FORWARD)
		torch(Vector3(center.x+offset,0,last.z+.28),true,Vector3.BACK)
	for offset in [-4.5,4.5]:
		torch(Vector3(first.x-.28,0,center.z+offset),true,Vector3.LEFT)
		torch(Vector3(last.x+.28,0,center.z+offset),true,Vector3.RIGHT)

# The summit crowns a stepped building. On its camera-facing south and east
# sides, one storey below the boss floor, the stone roof of floor 5 wraps
# around it; a storey lower again, floor 4's quartz-paved terrace wraps around
# that, and the rest of the building drops away to the desert.
const SUMMIT_ROOF_WIDTH = 7.0
const SUMMIT_TERRACE_WIDTH = 7.0
func setup_summit_understructure(stone: Material) -> void:
	var room: Rect2i = layout.rooms[0]
	var near: Vector3 = layout.to_world(room.position)-Vector3(.5,0,.5)
	var far: Vector3 = layout.to_world(room.end-Vector2i.ONE)+Vector3(.5,0,.5)
	# Summit storey: the boss floor's own south and east walls.
	summit_tier(near,far,0.0,1,stone)
	var roof_far = far+Vector3(SUMMIT_ROOF_WIDTH,0,SUMMIT_ROOF_WIDTH)
	tier_roof(near,far,roof_far,-8.0,stone)
	summit_tier(near,roof_far,-8.0,1,stone)
	var terrace_far = roof_far+Vector3(SUMMIT_TERRACE_WIDTH,0,SUMMIT_TERRACE_WIDTH)
	tier_roof(near,roof_far,terrace_far,-16.0,Art.quartz_material())
	summit_tier(near,terrace_far,-16.0,3,stone)

# One step of the building: storeys along the south and east edges of the
# rectangle from `near` to `far` (world edges), starting at height `top`.
func summit_tier(near: Vector3, far: Vector3, top: float, storeys: int, stone: Material) -> void:
	facade(far.z-.5,Vector2i(0,1),Vector2(near.x,far.x),stone,top,storeys)
	facade(far.x-.5,Vector2i(1,0),Vector2(near.z,far.z),stone,top,storeys)

# The L-shaped roof between an upper tier (ending at `inner`) and the tier
# below (ending at `outer`), at height `top`, with a low parapet on its edge.
func tier_roof(near: Vector3, inner: Vector3, outer: Vector3, top: float, surface: Material) -> void:
	var south = Rect2(Vector2(near.x,inner.z),Vector2(outer.x-near.x,outer.z-inner.z))
	var east = Rect2(Vector2(inner.x,near.z),Vector2(outer.x-inner.x,inner.z-near.z))
	for strip in [south,east]:
		var middle: Vector2 = strip.get_center()
		place_scenery("floor",Vector3(middle.x,top-.3,middle.y),Vector3(strip.size.x,.3,strip.size.y),surface)
	var parapet = Art.material("stone",Color(.72,.68,.6))
	place_scenery("wall",Vector3((near.x+outer.x)*.5,top,outer.z-.14),Vector3(outer.x-near.x,1.0,.28),parapet)
	place_scenery("wall",Vector3(outer.x-.14,top,(near.z+outer.z)*.5),Vector3(.28,1.0,outer.z-near.z),parapet)

# Storeys of the building below a terrace edge, like the summit's: a wall per
# storey, a projecting stone course and columns, so the gallery reads as the
# roof of a tall building. `line` is the edge's world coordinate, `outward` the
# direction the face looks, `span` its extent along the other axis.
const FACADE_STOREYS = 3
func facade(line: float, outward: Vector2i, span: Vector2, stone: Material, top: float = 0.0, storeys: int = FACADE_STOREYS) -> void:
	var along_x = outward.y!=0
	var length = span.y-span.x
	var middle = (span.x+span.y)*.5
	for story in storeys:
		var base = top-8.0*(story+1)
		var face = line+(outward.y if along_x else outward.x)*.5
		var at = Vector3(middle,base,face) if along_x else Vector3(face,base,middle)
		var out = Vector3(outward.x,0,outward.y)
		place_scenery("wall",at,Vector3(length,8,1.0) if along_x else Vector3(1.0,8,length),stone)
		place_scenery("wall",at+Vector3(0,-.55,0)+out*.3,Vector3(length+.3,.55,1.6) if along_x else Vector3(1.6,.55,length+.3),stone)
		var count = maxi(1,roundi(length/5.0))
		for i in count+1:
			var d = span.x+length*i/float(count)
			var column = Vector3(d,base,face) if along_x else Vector3(face,base,d)
			place_scenery("column",column+out*.5,Vector3(.95,8,.95),stone)

# The building with its terraces fills one rectangle on the terrace floors.
# Its camera-facing south and east sides get the facade along their full
# length, so the whole structure, not just the terrace ends, stands on storeys.
func setup_terrace_facades(stone: Material) -> void:
	var footprint = Rect2i(0,0,layout.size,layout.size)
	for strip in layout.terrace: footprint = footprint.merge(strip)
	var first: Vector3 = layout.to_world(footprint.position)
	var last: Vector3 = layout.to_world(footprint.end-Vector2i.ONE)
	# Floor 5 stands a storey higher above the desert than floor 4.
	var storeys = FACADE_STOREYS+(1 if level==4 else 0)
	facade(last.z,Vector2i(0,1),Vector2(first.x-.5,last.x+.5),stone,0.0,storeys)
	facade(last.x,Vector2i(1,0),Vector2(first.z-.5,last.z+.5),stone,0.0,storeys)

# Stone for the building's exterior storeys, projected at world scale so the
# texture keeps its size on long, tall walls instead of stretching with them.
func facade_stone(stone: StandardMaterial3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = stone.duplicate()
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*.25
	return m

# A flight descending a full storey into an opening in the floor, its top step
# level with the floor at the room side, lined with stone walls down to the
# floor below. Its cells are solid; sight passes over them.
func build_arrival(stone: Material) -> void:
	var rect: Rect2i = layout.arrival
	var dir: Vector2i = layout.arrival_dir
	var middle = layout.to_world(rect.position)+Vector3(rect.size.x-1,0,rect.size.y-1)*.5
	var flight = place("stairs",middle+Vector3.DOWN*WALL_HEIGHT,Vector3(Layout.STAIR_WIDTH,WALL_HEIGHT,Layout.STAIR_DEPTH),stone)
	# The imported flight climbs toward its local -Z; this one climbs away from the wall.
	flight.rotation.y = atan2(dir.x,dir.y)
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x): cells.append(Vector2i(x,y))
	for cell in cells: solid_floor[cell] = true
	visibility_cells[flight] = cells
	var lining = Art.material("stone",Color(.42,.4,.37))
	var near: Vector3 = layout.to_world(rect.position)-Vector3(.5,0,.5)
	var far: Vector3 = layout.to_world(rect.end-Vector2i.ONE)+Vector3(.5,0,.5)
	var size = far-near
	var walls = [
		[Vector3((near.x+far.x)*.5,-WALL_HEIGHT,near.z-.14),Vector3(size.x,WALL_HEIGHT,.28),Vector2i.UP],
		[Vector3((near.x+far.x)*.5,-WALL_HEIGHT,far.z+.14),Vector3(size.x,WALL_HEIGHT,.28),Vector2i.DOWN],
		[Vector3(near.x-.14,-WALL_HEIGHT,(near.z+far.z)*.5),Vector3(.28,WALL_HEIGHT,size.z),Vector2i.LEFT],
		[Vector3(far.x+.14,-WALL_HEIGHT,(near.z+far.z)*.5),Vector3(.28,WALL_HEIGHT,size.z),Vector2i.RIGHT]]
	for w in walls:
		# No wall across the top step, where the flight meets the room floor.
		if w[2] == -dir: continue
		# Plain solid blocks (the paving slab mesh), flush with the flight's
		# sides; the decorated wall mesh showed its moulding at the pit's rim.
		# Stop just below the floor so the block's carved top stays hidden.
		var block = Art.model("floor",w[1]-Vector3(0,.17,0),lining)
		add_child(block)
		block.position = w[0]
		visibility_nodes.append(block)
		visibility_cells[block] = cells
	# Torchlight from the room above: a dim, shadowless glow down the stairwell,
	# so its deep end and lining read as stone rather than a black hole.
	var glow = OmniLight3D.new()
	glow.light_color = Color(1,.72,.45)
	glow.light_energy = 1.1
	glow.omni_range = 5.0
	glow.omni_attenuation = 1.2
	glow.shadow_enabled = false
	glow.position = middle+Vector3.DOWN*1.2-Vector3(dir.x,0,dir.y)*.6
	add_child(glow)
	visibility_nodes.append(glow)
	visibility_cells[glow] = cells
	# A flat quartz coping round the opening covers the paving's chipped edges.
	var copings = [
		[Vector3((near.x+far.x)*.5,-.19,near.z),Vector3(size.x+.5,.2,.5)],
		[Vector3((near.x+far.x)*.5,-.19,far.z),Vector3(size.x+.5,.2,.5)],
		[Vector3(near.x,-.19,(near.z+far.z)*.5),Vector3(.5,.2,size.z+.5)],
		[Vector3(far.x,-.19,(near.z+far.z)*.5),Vector3(.5,.2,size.z+.5)]]
	for c in copings:
		var lip = Art.model("floor",c[1],Art.quartz_material())
		add_child(lip)
		lip.position = c[0]+Vector3.UP*.01
		visibility_nodes.append(lip)
		visibility_cells[lip] = cells

func place_scenery(id: String, pos: Vector3, size: Vector3, mat: Material) -> Node3D:
	var n = place(id,pos,size,mat)
	# Outdoor stone catches the terrace moonlight.
	for mesh in n.find_children("*","MeshInstance3D",true,false): mesh.layers |= TERRACE_LIGHT_LAYER
	visibility_nodes.erase(n)
	visibility_cells.erase(n)
	# Roof slabs reuse the paving mesh but are scenery, not batched floor tiles.
	floor_nodes.erase(n)
	outdoor_scenery.append(n)
	n.visible = false
	return n

func terrace_surface(at: Vector3) -> bool:
	# Include parapets offset just outside a gallery tile. Interior paving
	# stays on its normal layer and receives only the existing room lighting.
	for offset in [Vector3.ZERO,Vector3(.3,0,0),Vector3(-.3,0,0),Vector3(0,0,.3),Vector3(0,0,-.3)]:
		if layout.on_terrace(layout.to_cell(at+offset)): return true
	return false

func statue_posts(count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for cell in layout.cells:
		if layout.court.has_area() and layout.court.has_point(cell): continue
		var at = layout.to_world(cell)
		if at.distance_to(spawn)<9 or at.distance_to(exit_point)<2.5 or not fits(at,.45): continue
		var backs: Array[Vector2i] = []
		for direction in Layout.DIRS:
			if not layout.cells.has(cell+direction): backs.append(direction)
		if backs.is_empty(): continue
		var back = backs[rng.randi_range(0,backs.size()-1)]
		candidates.append({"at":at,"facing":atan2(-back.x,-back.y)})
	for i in range(candidates.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var swap = candidates[i]; candidates[i] = candidates[j]; candidates[j] = swap
	var posts: Array[Dictionary] = []
	for candidate in candidates:
		var crowded = false
		for other in posts:
			if other.at.distance_squared_to(candidate.at)<3.24: crowded=true; break
		if not crowded: posts.append(candidate)
		if posts.size()==count: return posts
	# Small/pathological layouts may use unoccupied interior floor positions.
	for cell in layout.cells:
		if layout.court.has_area() and layout.court.has_point(cell): continue
		var at = layout.to_world(cell)
		if at.distance_to(spawn)<9 or at.distance_to(exit_point)<2.5 or not fits(at,.45): continue
		var crowded = false
		for other in posts:
			if other.at.distance_squared_to(at)<3.24: crowded=true; break
		if not crowded: posts.append({"at":at,"facing":0.0})
		if posts.size()==count: return posts
	assert(false,"Generated floor has insufficient statue positions")
	return posts

# Floor light a torch at `at` gives a point on the floor, matching the omni
# light's falloff and the floor's angle to it.
func torch_light(at: Vector3, point: Vector3) -> float:
	var d = (at+Vector3.UP*TORCH_HEIGHT).distance_to(point)
	if d>=TORCH_RANGE: return 0.0
	var window = maxf(1.0-pow(d/TORCH_RANGE,4.0),0.0)
	return TORCH_ENERGY*window*window*pow(d,-TORCH_DECAY)*TORCH_HEIGHT/d

func add_light(levels: Dictionary, at: Vector3) -> void:
	var center = layout.to_cell(at)
	var reach = ceili(TORCH_RANGE)
	for x in range(center.x-reach,center.x+reach+1):
		for y in range(center.y-reach,center.y+reach+1):
			var cell = Vector2i(x,y)
			if levels.has(cell): levels[cell] += torch_light(at,layout.to_world(cell))

# Evenly spaced wall torches first, then another wall torch wherever a floor
# tile is still too dark and a wall is close. Torches are only ever on walls;
# the few room-center tiles beyond their reach rely on the ambient light.
func light_floor(candidates: Array[Vector3]) -> void:
	var levels: Dictionary = {}
	for cell in layout.cells:
		# The court on floor 3 keeps its authored torches around the pool.
		if level==2 and layout.court.grow(1).has_point(cell): continue
		levels[cell] = 0.0
	var placed: Array[Vector3] = []
	for at in torch_lights: placed.append(at)
	for at in placed: add_light(levels,at)
	for at in candidates:
		if level==2 and layout.court.grow(1).has_point(layout.to_cell(at)): continue
		if nearest_torch(placed,at)<5.5: continue
		torch(at,true,torch_walls[at])
		placed.append(at)
		add_light(levels,at)
	var given_up: Dictionary = {}
	while true:
		var darkest = Vector2i.ZERO
		var lowest = LIT_LEVEL
		for cell in levels:
			if levels[cell]<lowest and not given_up.has(cell):
				lowest = levels[cell]
				darkest = cell
		if lowest>=LIT_LEVEL: break
		var target = layout.to_world(darkest)
		var choice = Vector3.INF
		var best = 3.0
		for at in candidates:
			var d = at.distance_to(target)
			if d<best and nearest_torch(placed,at)>=3.0: best = d; choice = at
		if choice==Vector3.INF:
			given_up[darkest] = true
			continue
		torch(choice,true,torch_walls[choice])
		placed.append(choice)
		add_light(levels,choice)
	ambient_only = given_up

func nearest_torch(placed: Array[Vector3], at: Vector3) -> float:
	var nearest = INF
	for other in placed: nearest = minf(nearest,other.distance_to(at))
	return nearest

func torch(at: Vector3, cast_shadows: bool, wall: Vector3) -> void:
	torch_walls[at] = wall
	var fixture = place("brazier",at,Vector3(.6,1.6,.6),Art.material("gold"))
	# The fixture's back plate is on its local -Z side; turn it flat to the wall.
	fixture.rotation.y = atan2(-wall.x,-wall.z)
	var flame = place("torch_lit",at+Vector3.UP,Vector3(.5,1.0,.5))
	for mesh in flame.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.mesh.get_surface_count():
			var source = mesh.get_active_material(surface)
			var material = ShaderMaterial.new()
			material.shader = preload("res://assets/shaders/torch.gdshader")
			if source is StandardMaterial3D: material.set_shader_parameter("atlas",source.albedo_texture)
			mesh.set_surface_override_material(surface,material)
	var light = OmniLight3D.new()
	light.position = at+Vector3.UP*TORCH_HEIGHT
	light.light_color = Color(1,.60,.28)
	torch_lights.append(at)
	light.light_energy = TORCH_ENERGY
	light.omni_range = TORCH_RANGE
	light.omni_attenuation = TORCH_DECAY
	light.shadow_enabled = false
	if cast_shadows: shadow_torches.append(light)
	light.shadow_bias = .06
	light.shadow_caster_mask = 2
	light.distance_fade_enabled = true
	light.distance_fade_begin = 32
	light.distance_fade_shadow = 26
	light.distance_fade_length = 8
	add_child(light)
	visibility_nodes.append(light)
	var fire = preload("res://scripts/torch_flame.gd").new()
	# The flame rises from the torch's wick.
	fire.position = at+Vector3.UP*1.96
	# Stable spatial phases keep neighboring torches from pulsing in unison.
	fire.setup(light,fposmod(at.x*12.9898+at.z*78.233,100.0))
	add_child(fire)
	visibility_nodes.append(fire)

func place(id: String, pos: Vector3, size: Vector3, mat: Material = null) -> Node3D:
	# The wall's continuous face runs along local X. Rotate north–south
	# runs; stretching its recessed end profile along Z creates large holes.
	var turn_wall = id=="wall" and size.z>size.x
	var dimensions = Vector3(size.z,size.y,size.x) if turn_wall else size
	var n = Art.model(id,dimensions,mat)
	if turn_wall: n.rotation.y = PI/2
	add_child(n)
	n.position = pos
	if id!="floor": visibility_nodes.append(n)
	if id in ["column","arch","banner","bookcase"] and pos.y>-1:
		# Corner architecture sits in solid cells; any seen neighbour reveals it.
		var low = layout.to_cell(pos-size*.5)
		var high = layout.to_cell(pos+size*.5)
		var around: Array[Vector2i] = []
		for x in range(low.x-1,high.x+2):
			for y in range(low.y-1,high.y+2): around.append(Vector2i(x,y))
		visibility_cells[n] = around
	# Torches cast architecture shadows without re-rendering the animated crowd.
	var layers = 2 | TERRACE_LIGHT_LAYER if terrace_surface(pos) else 2
	for mesh in n.find_children("*","MeshInstance3D",true,false): mesh.layers = layers
	if id=="floor": floor_nodes.append(n)
	if (id in ["wall","arch","column","bookcase"] or (id=="stairs" and size.y>=WALL_HEIGHT)) and mat:
		var faded = mat.duplicate()
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		faded.albedo_color.a = FADED_ALPHA
		occluders.append({"root":n,"meshes":n.find_children("*","MeshInstance3D",true,false),"normal":mat,"faded":faded,"hidden":false})
	return n

func batch_floors() -> void:
	# GPU instancing reuses the imported paving mesh; no geometry is generated.
	var groups: Dictionary = {}
	for tile in floor_nodes:
		for mesh in tile.find_children("*","MeshInstance3D",true,false):
			# Small batches keep the compatibility renderer's per-object light
			# limit from choosing one set of torches for the entire temple floor.
			var chunk = 4
			var key = "%d:%d:%d:%d:%d:%d" % [mesh.mesh.get_instance_id(),mesh.material_override.get_instance_id(),mesh.layers,chunk,floori(tile.position.x/chunk),floori(tile.position.z/chunk)]
			if not groups.has(key): groups[key] = {"mesh":mesh.mesh,"material":mesh.material_override,"layers":mesh.layers,"transforms":[],"cells":[]}
			groups[key].transforms.append(mesh.global_transform)
			groups[key].cells.append(layout.to_cell(tile.position))
	for group in groups.values():
		var instances = MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = group.mesh
		instances.instance_count = group.transforms.size()
		for i in group.transforms.size(): instances.set_instance_transform(i,group.transforms[i])
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = instances
		batch.material_override = group.material
		batch.layers = group.layers
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		visibility_floor_batches.append({"node":batch,"cells":group.cells})
	for tile in floor_nodes:
		remove_child(tile)
		tile.queue_free()
	floor_nodes.clear()

func fits(p: Vector3, radius: float = .4) -> bool:
	# Tile occupancy is shared by rendering, collision and navigation. The
	# empty space between rooms is solid black void, never walkable terrain.
	var lo = layout.to_cell(p-Vector3(radius,0,radius))
	var hi = layout.to_cell(p+Vector3(radius,0,radius))
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			if not layout.cells.has(Vector2i(x,y)): return false
	return true

func move(from: Vector3, step: Vector3, radius: float = .4) -> Vector3:
	# Substeps keep even fast dashes from tunnelling through walls.
	var p = from
	var count = maxi(1,ceili(step.length()/.22))
	var s = step / count
	for i in count:
		if fits(p+s,radius): p += s
		else:
			if fits(p+Vector3(s.x,0,0),radius): p.x += s.x
			if fits(p+Vector3(0,0,s.z),radius): p.z += s.z
	return p

func clear_line(a: Vector3, b: Vector3) -> bool:
	# The level 3 fountain occupies blocked navigation tiles, but does not hide
	# the rest of the court. Keep the obstacle solid for movement while letting
	# visibility rays pass through its footprint.
	var steps = maxi(1,ceili(a.distance_to(b)/.2))
	for i in range(steps+1):
		if not fits_for_visibility(a.lerp(b,float(i)/steps),.04): return false
	return true

func fits_for_visibility(p: Vector3, radius: float) -> bool:
	var lo = layout.to_cell(p-Vector3(radius,0,radius))
	var hi = layout.to_cell(p+Vector3(radius,0,radius))
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			var cell = Vector2i(x,y)
			if layout.cells.has(cell): continue
			if level==2 and layout.court_obstacle.has_point(cell): continue
			if solid_floor.has(cell): continue
			return false
	return true

func floor_line(a: Vector3, b: Vector3, radius: float) -> bool:
	var steps = maxi(1,ceili(a.distance_to(b)/.2))
	for i in range(steps+1):
		if not fits(a.lerp(b,float(i)/steps),radius): return false
	return true

func walk_line(a: Vector3, b: Vector3) -> bool:
	return floor_line(a,b,.41)

func navigation_cell(at: Vector3, require_connection: bool) -> Vector2i:
	var center = Vector2i(clampi(roundi(at.x),nav.region.position.x,nav.region.end.x-1),clampi(roundi(at.z),nav.region.position.y,nav.region.end.y-1))
	var best = Vector2i(-1000,-1000)
	var distance = INF
	for radius in range(5):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var cell = center+Vector2i(x,z)
				if not nav.is_in_boundsv(cell) or nav.is_point_solid(cell): continue
				var point = Vector3(cell.x,0,cell.y)
				if require_connection and not walk_line(at,point): continue
				var d = at.distance_squared_to(point)
				if d < distance:
					best = cell
					distance = d
		if best.x != -1000: break
	return best

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var destination = Vector3(clampf(to.x,bounds.position.x+.41,bounds.end.x-.41),0,clampf(to.z,bounds.position.y+.41,bounds.end.y-.41))
	if walk_line(from,destination): return PackedVector3Array([destination])
	var start = navigation_cell(from,true)
	var end = navigation_cell(destination,false)
	var result = PackedVector3Array()
	if start.x == -1000 or end.x == -1000: return result
	var points = PackedVector3Array()
	for p in nav.get_point_path(start,end): points.append(Vector3(p.x,0,p.y))
	if points.is_empty(): return result
	if walk_line(points[-1],destination): points.append(destination)
	# Keep the exact floor point and skip only waypoints reachable without
	# clipping a wall. Repeated held orders therefore cannot pull us backwards
	# to the rounded start cell or zigzag between neighboring grid cells.
	var anchor = from
	while not points.is_empty():
		var next = 0
		for i in range(points.size()-1,-1,-1):
			if walk_line(anchor,points[i]):
				next = i
				break
		anchor = points[next]
		result.append(anchor)
		for i in range(next+1): points.remove_at(0)
	return result

func pointer() -> Vector3:
	# Camera projection and viewport input both use logical viewport pixels.
	# Applying the window stretch transform here scales the pointer twice.
	return ground_at(get_viewport().get_mouse_position())

func ground_at(viewport_position: Vector2) -> Vector3:
	var origin = camera.project_ray_origin(viewport_position)
	var ray = camera.project_ray_normal(viewport_position)
	var hit = Plane(Vector3.UP,0).intersects_ray(origin,ray)
	return hit if hit != null else spawn

func follow(pos: Vector3, delta: float) -> void:
	var desired = pos + Vector3(12,21,19)
	camera.position = camera.position.lerp(desired,minf(1,delta*8))
	camera.look_at(camera.position-Vector3(12,21,19))
	camera.size = lerpf(camera.size,zoom,minf(1,delta*8))
	var viewport_size = get_viewport().get_visible_rect().size
	if is_instance_valid(desert_backdrop):
		var outdoors = layout.on_terrace(layout.to_cell(pos))
		desert_backdrop.visible = outdoors or level==5
		fog_material.set_shader_parameter("outdoors",desert_backdrop.visible)
		for n in outdoor_scenery: n.visible = desert_backdrop.visible
		# The summit's lower roofs and terrace are always in view, in moonlight.
		terrace_moonlight.visible = outdoors or level==5
		var width = camera.size*viewport_size.x/viewport_size.y
		var texture_size = desert_backdrop.texture.get_size()
		desert_backdrop.pixel_size = maxf(width/texture_size.x,camera.size/texture_size.y)*1.08
		# Keep the distant horizon at the top and nearby ground below. Overscan covers
		# the small parallax movement at every supported aspect ratio and zoom.
		var image_height = texture_size.y*desert_backdrop.pixel_size
		desert_backdrop.position.x = -sin(pos.x*.012)*width*.025
		desert_backdrop.position.y = (camera.size-image_height)*.5+camera.size*(.02-sin(pos.z*.012)*.01)
	occlusion_tick -= delta
	if occlusion_tick <= 0:
		occlusion_tick = .1
		# Restrict expensive animated shadows to the two torches nearest play.
		# Every torch still contributes its local pool of light.
		shadow_torches.sort_custom(func(a,b): return a.position.distance_squared_to(pos)<b.position.distance_squared_to(pos))
		for i in shadow_torches.size():
			shadow_torches[i].shadow_enabled = i<2 and shadow_torches[i].position.distance_squared_to(pos)<100

		var targets: Array = [{"position":pos,"height":1.8}]+occlusion_targets
		for group in occluders:
			if group.root.position.distance_squared_to(pos)>900 and not group.hidden: continue
			var blocked = false
			for target in targets:
				if Vector2(group.root.position.x-target.position.x,group.root.position.z-target.position.z).length()>OCCLUSION_REACH: continue
				for mesh in group.meshes:
					var box: AABB = mesh.global_transform * mesh.get_aabb()
					# Fade anything hiding someone's feet, body or head.
					for share in [.08,.55,1.0]:
						if box.intersects_segment(camera.position,target.position+Vector3.UP*target.height*share): blocked = true; break
					if blocked: break
				if blocked: break
			if blocked != group.hidden:
				group.hidden = blocked
				for mesh in group.meshes: mesh.material_override = group.faded if blocked else group.normal

func update_visibility(pos: Vector3, delta: float) -> void:
	visibility_timer -= delta
	if visibility_timer>0 and pos.distance_squared_to(visibility_player_position)<.09: return
	visibility_timer = .10
	visibility_player_position = pos
	visibility_image.fill(Color.BLACK)
	for cell in layout.cells: mark_visibility_cell(cell,pos)
	# Fountain cells are intentionally removed from layout.cells so they remain
	# blocked for movement, but their surface should still receive the clear LOS mask.
	if level==2:
		for y in range(layout.court_obstacle.position.y,layout.court_obstacle.end.y):
			for x in range(layout.court_obstacle.position.x,layout.court_obstacle.end.x):
				mark_visibility_cell(Vector2i(x,y),pos)
	for cell in solid_floor: mark_visibility_cell(cell,pos)
	visibility_texture.update(visibility_image)
	for batch in visibility_floor_batches:
		var seen = false
		for cell in batch.cells:
			if cell_is_visible(cell): seen = true; break
		batch.node.visible = seen
	for node in visibility_nodes:
		if not is_instance_valid(node): continue
		if visibility_cells.has(node):
			var seen = false
			for cell in visibility_cells[node]:
				if cell_is_visible(cell): seen = true; break
			node.visible = seen
		else: node.visible = can_see(node.position)

func mark_visibility_cell(cell: Vector2i, pos: Vector3) -> void:
	var at = layout.to_world(cell)
	if at.distance_squared_to(pos)>VISION_RANGE*VISION_RANGE or not clear_line(pos,at): return
	var pixel = cell-VISIBILITY_GRID_ORIGIN
	if pixel.x>=0 and pixel.y>=0 and pixel.x<visibility_grid_size.x and pixel.y<visibility_grid_size.y:
		visibility_image.set_pixel(pixel.x,pixel.y,Color.WHITE)

func cell_is_visible(cell: Vector2i) -> bool:
	if level==Layout.PLAYGROUND: return true
	var pixel = cell-VISIBILITY_GRID_ORIGIN
	return pixel.x>=0 and pixel.y>=0 and pixel.x<visibility_grid_size.x and pixel.y<visibility_grid_size.y and visibility_image.get_pixel(pixel.x,pixel.y).r>.5

func can_see(at: Vector3) -> bool:
	return cell_is_visible(layout.to_cell(at))
