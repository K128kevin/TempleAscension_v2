extends Node3D
const Art = preload("res://scripts/assets.gd")
const Layout = preload("res://scripts/layout.gd")
const StoneFragment = preload("res://scripts/stone_fragment.gd")
const Kit = preload("res://scripts/world_art.gd")
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
# Built on the first death. Paving is batched away after setup, so retain its
# bounds; solid props retain their final transforms, including turned stairs.
var debris_floors: Array[AABB] = []
var debris_props: Array[Node3D] = []
var debris_collision: StaticBody3D
var shadow_torches: Array[OmniLight3D] = []
var torch_lights: Array[Vector3] = []
# The wall each torch spot is mounted on, as a direction from the torch.
var torch_walls: Dictionary = {}
# The fire bowls standing on low parapets.
var braziers: Array[Node3D] = []
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
# The low parapets' height, and the braziers that stand on them: the fire
# bowl's size, and how far from the torch spot (inside the wall) to the
# wall's centre line.
const LOW_WALL_HEIGHT = 1.0
const BRAZIER_SIZE = Vector3(.5,.42,.48)
const BRAZIER_INSET = .36
# The brazier's light hangs above its fire, over the rim: lit from inside,
# the bowl's bronze glared.
const BRAZIER_FIRE_LIFT = .3
# Its flame is broader than a torch's.
const BRAZIER_FLAME_SCALE = 1.25
static var coal_finish: ShaderMaterial
static func coal_material() -> ShaderMaterial:
	if coal_finish == null:
		coal_finish = ShaderMaterial.new()
		coal_finish.shader = preload("res://assets/shaders/embers.gdshader")
	return coal_finish
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
var visibility_rest = 0.0
# The sight being worked out (its next row, or -1), a band of rows a frame.
const VISIBILITY_ROWS = 9
var visibility_row = -1
var visibility_next: Image
var visibility_player_position = Vector3(INF,INF,INF)
var fog_material: ShaderMaterial

# `place`: the temple, or one of the dungeons built as its floors are, in
# their own stone: "basement" (under the town's arena: dressed masonry and
# slate) and "cave" (the bandits': walls of living rock over packed earth).
func setup(floor_index: int, run_seed: int = 1, place: String = "temple") -> void:
	level = floor_index
	layout.generate(run_seed,floor_index,place)
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
	var tints: Array = {"temple":[Color(.91,.87,.77),Color(.73,.70,.66),Color(.75,.69,.61),Color(.94,.87,.70)],"basement":[Color(.62,.58,.52),Color(.55,.52,.48)],"cave":[Color(.52,.44,.36),Color(.46,.39,.33)]}[layout.kind]
	var stone = Art.material("stone",tints[maxi(floor_index,0)])
	# Pale quartz paving keeps the dark stone statues readable against the floor.
	# The playground's floor is a mid grey, so every model reads against it.
	var paving: Material = Art.quartz_material(Color(.46,.47,.5) if floor_index==Layout.PLAYGROUND else Color(.70,.70,.72))
	# A dungeon's floor: bare dirt under the arena, packed earth in the cave.
	if layout.kind == "basement": paving = dirt_material()
	elif layout.kind == "cave": paving = earth_material()
	var court_paving = Art.quartz_material(Color(.74,.64,.64))
	var lower = Vector2i(10000,10000)
	var upper = Vector2i(-10000,-10000)
	var edges: Dictionary = {}
	var torch_candidates: Array[Vector3] = []
	# A flight's footprint is paved and walled like the room around it,
	# although it is solid for movement.
	var surface: Array = layout.cells.keys()
	for y in range(layout.stairs.position.y,layout.stairs.end.y):
		for x in range(layout.stairs.position.x,layout.stairs.end.x): surface.append(Vector2i(x,y))
	# A stairwell down is unpaved, but the room's walls still run round it,
	# rising above the flight's deep end.
	for y in range(layout.arrival.position.y,layout.arrival.end.y):
		for x in range(layout.arrival.position.x,layout.arrival.end.x): surface.append(Vector2i(x,y))
	# (A stairwell going down is left open: in the temple the one he arrives
	# by, in a dungeon the one on down.)
	var well: Rect2i = layout.stairs if layout.descending else layout.arrival
	for cell in surface:
		var at = layout.to_world(cell)
		lower = lower.min(Vector2i(at.x,at.z))
		upper = upper.max(Vector2i(at.x,at.z))
		if not well.has_point(cell):
			# The open-air terraces are paved in grey slate, not the halls' quartz.
			var tiles = court_paving if layout.court.has_point(cell) else (Art.slate_material() if layout.on_terrace(cell) else paving)
			var tile = place("floor",at+Vector3.DOWN*.16,Vector3(1,.16,1),tiles)
			# (A dungeon's floor is bare ground, not the paving's cut tiles.)
			if layout.kind in ["cave","basement"]:
				for mesh in tile.find_children("*","MeshInstance3D",true,false):
					var box: AABB = mesh.mesh.get_aabb()
					mesh.position += mesh.basis*box.get_center()
					mesh.mesh = bare_ground(box.size)
		# The playground is an open plane, without walls.
		if level==Layout.PLAYGROUND: continue
		for direction in Layout.DIRS:
			if layout.is_open(cell+direction): continue
			# The court's solid centerpiece is the fountain, not a wall.
			if layout.court_obstacle.has_point(cell+direction): continue
			# The temple's door stands at the end of the first floor's passage.
			if layout.at_door(cell) and direction==layout.entry_dir: continue
			var horizontal_edge: bool = direction.y!=0
			var line: float = (at.z+direction.y*.5) if horizontal_edge else (at.x+direction.x*.5)
			var low = low_wall(cell,direction)
			var key = "%s:%s:%s:%s" % [horizontal_edge,line,direction,low]
			if not edges.has(key): edges[key] = {"horizontal":horizontal_edge,"line":line,"direction":direction,"low":low,"along":[]}
			edges[key].along.append(int(at.x if horizontal_edge else at.z))
			# Small wall torches sit inside the boundary, with no floor obstruction.
			if not layout.stairs.has_point(cell) and not layout.arrival.has_point(cell) and not layout.arrival.has_point(cell+direction):
				# (A cave's torches stand clear of its rough rock.)
				var spot = at+Vector3(direction.x,0,direction.y)*(-.1 if layout.kind == "cave" else .28)
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
			# Low parapets are built of short pieces, about a cell long, so the
			# wall model's carved stones keep their shape: one squashed to a
			# third of its height and stretched over four cells flattens them
			# into long slabs. Full walls span up to four cells.
			var pieces: Array = [[first,last]]
			if edge.low:
				pieces = []
				for along in range(first,last+1): pieces.append([along,along])
			for piece in pieces:
				# Ends at the run's corners extend to the adjacent wall's
				# centerline: the authored molding is wider than its stone core,
				# so a tiny cap overlap leaves open seams at right-angle corners.
				var start: float = piece[0]-.5-(.14 if piece[0]==first else 0.0)
				var finish: float = piece[1]+.5+(.14 if piece[1]==last else 0.0)
				var mid = (start+finish)*.5
				var pos = Vector3(mid,0,edge.line+edge.direction.y*.14) if edge.horizontal else Vector3(edge.line+edge.direction.x*.14,0,mid)
				var height = LOW_WALL_HEIGHT if edge.low else WALL_HEIGHT
				var dimensions = Vector3(finish-start,height,.28) if edge.horizontal else Vector3(.28,height,finish-start)
				var wall: Node3D = rock_wall(pos+Vector3(edge.direction.x,0,edge.direction.y)*.5,dimensions) if layout.kind == "cave" else place("wall",pos,dimensions,Art.world_stone(stone) if edge.low else stone)
				# (A full wall stops what falls as a box running deep into the
				# solid ground behind it: see ensure_debris_collision.)
				if layout.kind != "cave" and not edge.low:
					debris_props.erase(wall)
					var back = Vector3(edge.direction.x,0,edge.direction.y)
					var box = AABB(pos-Vector3(dimensions.x,0,dimensions.z)*.5,dimensions)
					debris_walls.append(box.merge(AABB(box.position+back*WALL_DEPTH,box.size)))
				# Walls stand in solid cells that are never seen themselves. Reveal
				# each piece from the floor it faces, never from the far side.
				var faces: Array[Vector2i] = []
				for along in range(piece[0],piece[1]+1):
					var floor_at = Vector3(along,0,edge.line-edge.direction.y*.5) if edge.horizontal else Vector3(edge.line-edge.direction.x*.5,0,along)
					faces.append(layout.to_cell(floor_at))
				visibility_cells[wall] = faces
				# (The basement's walls are dirtied and damaged, once they all stand.)
				if layout.kind == "basement" and not edge.low:
					var face = Vector3(mid,0,edge.line) if edge.horizontal else Vector3(edge.line,0,mid)
					wall_pieces.append({"node":wall,"face":face,"back":edge.direction,"length":finish-start,"horizontal":edge.horizontal,"cells":faces})
	# The generated rooms determine every landmark and decoration placement.
	for i in layout.rooms.size():
		var room: Rect2i = layout.rooms[i]
		var corner = layout.to_world(room.position)
		# Imported columns occupy solid wall corners, never a corridor tile.
		if layout.kind != "cave" and not layout.cells.has(room.position+Vector2i(-1,-1)):
			place("column",corner+Vector3(-.65,0,-.65),Vector3(.7,3.8,.7),stone)
		if layout.court.has_area() and i%2==1 and not layout.cells.has(room.position+Vector2i(-1,0)):
			var shelf = place("bookcase",corner+Vector3(-.65,0,0),Vector3(.9,2.4,.25),stone)
			shelf.rotation.y = PI/2
	if layout.court.has_area():
		fountain = preload("res://scripts/fountain.gd").new()
		add_child(fountain)
		fountain.setup(layout)
	if not layout.terrace.is_empty() or layout.summit: setup_desert(stone)
	# In the temple the hero climbs: a stairwell up from the floor below where
	# he arrives, and the flight up in the furthest room. In a dungeon he goes
	# down: the flight he came down by where he arrives, and a stairwell on
	# down in the furthest room.
	if layout.arrival.has_area():
		if layout.descending: build_flight(layout.arrival,layout.arrival_dir,layout.arrival_foot,stone)
		else: build_well(layout.arrival,layout.arrival_dir,stone)
	if layout.entry.has_area(): build_entry(stone)
	if layout.stairs.has_area():
		if layout.descending: build_well(layout.stairs,layout.stairs_dir,stone)
		else: build_flight(layout.stairs,layout.stairs_dir,layout.exit_cell,stone)
	if layout.descending: furnish_dungeon(run_seed)
	if layout.kind == "basement":
		furnish_basement(run_seed)
		var dirtied = RandomNumberGenerator.new()
		dirtied.seed = Layout.floor_seed(run_seed,level+13+Layout.KINDS[layout.kind].salt)
		grime_walls(dirtied)
	if layout.gate.has_area(): setup_gate(stone)
	exit_seal = Art.seal(3,Color(.3,1,.85,.85))
	exit_seal.position = exit_point+Vector3.UP*.05
	add_child(exit_seal)
	exit_seal.visible = false
	if layout.court.has_area(): setup_court_torches()
	# (No torch is hung over a statue standing against its wall, nor in a
	# webbed corner.)
	if not unlit_cells.is_empty():
		var clear: Array[Vector3] = []
		for spot in torch_candidates:
			if not unlit_cells.has(layout.to_cell(spot)): clear.append(spot)
		torch_candidates = clear
	if level!=Layout.PLAYGROUND: light_floor(torch_candidates)
	if layout.summit:
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
	if not layout.summit:
		var dark = StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.albedo_color = Color(.007,.009,.013)
		# It stops round a stairwell, which goes down a full storey through
		# the floor: laid across it, the foundation filled the well with black
		# just under its rim, hiding the flight.
		var low: Vector3 = layout.to_world(Vector2i.ZERO)-Vector3(.5,0,.5)
		var high: Vector3 = layout.to_world(Vector2i(layout.size-1,layout.size-1))+Vector3(.5,0,.5)
		var slabs = [Rect2(low.x,low.z,high.x-low.x,high.z-low.z)]
		for well in [layout.arrival if not layout.descending else Rect2i(),layout.stairs if layout.descending else Rect2i()]:
			if not well.has_area(): continue
			var near: Vector3 = layout.to_world(well.position)-Vector3(.5,0,.5)
			var far: Vector3 = layout.to_world(well.end-Vector2i.ONE)+Vector3(.5,0,.5)
			# (Out to the outside of the well's lining.)
			var hole = Rect2(near.x-.28,near.z-.28,far.x-near.x+.56,far.z-near.z+.56)
			var cut = []
			for slab in slabs: cut += around(slab,hole)
			slabs = cut
		for slab in slabs:
			var foundation = Art.model("floor",Vector3(slab.size.x,.4,slab.size.y),dark)
			foundation.position = Vector3(slab.get_center().x,-.6,slab.get_center().y)
			add_child(foundation)
	# Deep masonry along the exposed edges makes the elevation above the dunes
	# legible instead of leaving the terrace as a paper-thin floating platform.
	var masonry = Art.material("stone",Color(.22,.27,.34))
	for strip in layout.terrace:
		var corner: Vector3 = layout.to_world(strip.position)-Vector3(.5,0,.5)
		place_scenery("wall",corner+Vector3(strip.size.x*.5,-7,strip.size.y*.5),Vector3(strip.size.x,6.84,strip.size.y),masonry)
	if not layout.summit: setup_terrace_facades(facade_stone(stone))
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

# What is left of `slab` with `hole` cut out of it: up to four rectangles round
# the hole (x across, y along the floor's z).
static func around(slab: Rect2, hole: Rect2) -> Array:
	if not slab.intersects(hole): return [slab]
	var cut = hole.intersection(slab)
	var pieces = [
		Rect2(slab.position.x,slab.position.y,cut.position.x-slab.position.x,slab.size.y),
		Rect2(cut.end.x,slab.position.y,slab.end.x-cut.end.x,slab.size.y),
		Rect2(cut.position.x,slab.position.y,cut.size.x,cut.position.y-slab.position.y),
		Rect2(cut.position.x,cut.end.y,cut.size.x,slab.end.y-cut.end.y)]
	return pieces.filter(func(r): return r.size.x>.01 and r.size.y>.01)

# Which cells are the temple's floor (walkable, or the fountain and stairs that
# stand on it). Outdoors, the fog leaves everything at floor height elsewhere
# alone: the tops of the storeys below the terraces and the summit are scenery.
func setup_walkable_mask() -> void:
	var image = Image.create(visibility_grid_size.x,visibility_grid_size.y,false,Image.FORMAT_R8)
	image.fill(Color.BLACK)
	var interior: Array = layout.cells.keys()+solid_floor.keys()
	if layout.court.has_area():
		for y in range(layout.court_obstacle.position.y,layout.court_obstacle.end.y):
			for x in range(layout.court_obstacle.position.x,layout.court_obstacle.end.x): interior.append(Vector2i(x,y))
	for cell in interior:
		var pixel: Vector2i = cell-VISIBILITY_GRID_ORIGIN
		if pixel.x>=0 and pixel.y>=0 and pixel.x<visibility_grid_size.x and pixel.y<visibility_grid_size.y:
			image.set_pixel(pixel.x,pixel.y,Color.WHITE)
	fog_material.set_shader_parameter("walkable_mask",ImageTexture.create_from_image(image))
	var bowls = PackedVector4Array()
	for bowl in braziers.slice(0,64): bowls.append(Vector4(bowl.position.x,bowl.position.y,bowl.position.z,BRAZIER_SIZE.x*.7))
	fog_material.set_shader_parameter("braziers",bowls)
	fog_material.set_shader_parameter("brazier_count",bowls.size())

func setup_visibility_fog() -> void:
	visibility_grid_size = Vector2i(layout.size+10,layout.size+10)
	visibility_image = Image.create(visibility_grid_size.x,visibility_grid_size.y,false,Image.FORMAT_R8)
	visibility_next = Image.create(visibility_grid_size.x,visibility_grid_size.y,false,Image.FORMAT_R8)
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
	tier_roof(near,roof_far,terrace_far,-16.0,Art.slate_material())
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
	var parapet = Art.world_stone(Art.material("stone",Color(.72,.68,.6)))
	parapet_run(Vector3(near.x,top,outer.z-.14),Vector3(outer.x,top,outer.z-.14),parapet)
	parapet_run(Vector3(outer.x-.14,top,near.z),Vector3(outer.x-.14,top,outer.z),parapet)

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
	# (The terraces are the temple's third floor, high above the desert.)
	var storeys = FACADE_STOREYS+1
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
func build_well(rect: Rect2i, dir: Vector2i, stone: Material) -> void:
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

# A flight climbing a full storey into the wall behind it, its foot on the
# room's floor (`foot`, the tile before it). Its cells are solid; sight
# passes over them.
func build_flight(rect: Rect2i, dir: Vector2i, foot: Vector2i, stone: Material) -> void:
	# The imported flight climbs toward its local -Z from a base at its origin.
	# Scaled to wall height, its top step meets the top of the wall it climbs into.
	var middle = layout.to_world(rect.position)+Vector3(rect.size.x-1,0,rect.size.y-1)*.5
	var flight = place("stairs",middle,Vector3(Layout.STAIR_WIDTH,WALL_HEIGHT,Layout.STAIR_DEPTH),stone)
	flight.rotation.y = atan2(-dir.x,-dir.y)
	var reveal: Array[Vector2i] = [foot]
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x): reveal.append(Vector2i(x,y))
	visibility_cells[flight] = reveal
	for cell in reveal.slice(1): solid_floor[cell] = true

# A plain slab the size of a paving tile, shared by every tile of a floor.
var ground_slab: BoxMesh
func bare_ground(size: Vector3) -> BoxMesh:
	if ground_slab == null:
		ground_slab = BoxMesh.new()
		ground_slab.size = size
	return ground_slab

# The arena basement's floor: old dirt, trodden hard, blotched damp and
# dusty, stained and gritty (assets/shaders/basement_dirt.gdshader).
func dirt_material() -> ShaderMaterial:
	var dirt = ShaderMaterial.new()
	dirt.shader = load("res://assets/shaders/basement_dirt.gdshader")
	dirt.set_shader_parameter("ground",load("res://assets/textures/sand_gravel.jpg"))
	dirt.set_shader_parameter("ground_normal",load("res://assets/textures/sand_gravel_normal.jpg"))
	dirt.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	return dirt

# A cave's floor: packed earth and grit.
func earth_material() -> StandardMaterial3D:
	var earth = StandardMaterial3D.new()
	earth.albedo_color = Color(.66,.64,.62)
	earth.albedo_texture = load("res://assets/textures/sand_gravel.jpg")
	earth.normal_enabled = true
	earth.normal_texture = load("res://assets/textures/sand_gravel_normal.jpg")
	earth.roughness = .95
	earth.uv1_world_triplanar = true
	earth.uv1_triplanar = true
	earth.uv1_scale = Vector3.ONE*.55
	return earth

# A cave's wall: living rock, a boulder to every two metres of it, each its
# own shape and lean, in place of the temple's dressed stone.
const CAVE_ROCKS = ["boulder_a","boulder_b","boulder_c","boulder_d"]
func rock_wall(pos: Vector3, dimensions: Vector3) -> Node3D:
	var along_x: bool = dimensions.x >= dimensions.z
	var length: float = dimensions.x if along_x else dimensions.z
	var run = Node3D.new()
	add_child(run)
	run.position = pos
	visibility_nodes.append(run)
	var count = maxi(1,roundi(length/1.6))
	for i in count:
		var seed = pos.x*12.9898+pos.z*78.233+i*37.7
		var chance = func(k: float) -> float: return fposmod(sin(seed*k)*43758.5453,1.0)
		var offset = (float(i)+.5)/count*length-length*.5
		var id: String = CAVE_ROCKS[int(chance.call(1.0)*4.0)%4]
		var rock = Art.model(id,Vector3(length/count*1.45,WALL_HEIGHT*(.95+.5*chance.call(2.0)),1.5+.5*chance.call(3.0)),Kit.rock(id,Color(.74,.70,.66),0.0))
		run.add_child(rock)
		rock.position = (Vector3(offset,-.4,0) if along_x else Vector3(0,-.4,offset))
		rock.rotation.y = (0.0 if along_x else PI/2)+(chance.call(4.0)-.5)*.5+(PI if chance.call(5.0) > .5 else 0.0)
	return run

# What a dungeon's rooms hold: the bandits' stores stacked in corners (crates,
# barrels, sacks), solid to walk round and low enough to see over. The same
# for the same seed.
func furnish_dungeon(run_seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = Layout.floor_seed(run_seed,level+7+Layout.KINDS[layout.kind].salt)
	var keep_clear: Array[Vector2i] = [layout.start,layout.exit_cell]
	if layout.arrival.has_area(): keep_clear.append(layout.arrival_foot)
	for room in layout.rooms:
		for corner in [Vector2i(room.position.x,room.position.y),Vector2i(room.end.x-1,room.position.y),Vector2i(room.position.x,room.end.y-1),Vector2i(room.end.x-1,room.end.y-1)]:
			if rng.randf() > .55: continue
			var inward = Vector2i(1 if corner.x==room.position.x else -1,1 if corner.y==room.position.y else -1)
			# A true corner: wall on both of its outer sides, floor all about it.
			if layout.is_open(corner-Vector2i(inward.x,0)) or layout.is_open(corner-Vector2i(0,inward.y)): continue
			var pile: Array[Vector2i] = [corner]
			if rng.randf() < .6: pile.append(corner+Vector2i(inward.x,0))
			if rng.randf() < .4: pile.append(corner+Vector2i(0,inward.y))
			var free = true
			for cell in pile:
				if not layout.cells.has(cell) or layout.stairs.grow(2).has_point(cell) or layout.arrival.grow(2).has_point(cell) or layout.entry.grow(3).has_point(cell) or layout.gate.grow(3).has_point(cell): free = false
				for spot in keep_clear:
					if (cell-spot).length() < 4.0: free = false
			if not free: continue
			for cell in pile:
				var id: String = ["crate","barrel","bag","crate"][rng.randi_range(0,3)]
				var height: float = {"crate":rng.randf_range(.7,.95),"barrel":.95,"bag":.7}[id]
				var thing = Art.model(id,Kit.sized(id,height))
				Kit.dress(thing)
				add_child(thing)
				thing.position = layout.to_world(cell)+Vector3(rng.randf_range(-.1,.1),0,rng.randf_range(-.1,.1))
				thing.rotation.y = rng.randf_range(0,TAU)
				visibility_nodes.append(thing)
				# Solid to movement, open to sight, like a standing brazier.
				layout.cells.erase(cell)
				solid_floor[cell] = true

# The arena basement's leavings (scripts/basement_props.gd): broken statues
# of gladiators stand against the walls of its rooms and hallway (STATUE_ROOM
# of the rooms, one to every STATUE_HALL metres of hallway, on its far side);
# the dead lie where they fell, slumped against a wall or sprawled on the
# floor, or only their bones are left (SKELETONS a room, as a share); pots
# stand against the walls in ones, twos and threes, some smashed or knocked
# over (POTS); and spiders have webbed the corners of the rooms (WEBBED) and
# of the hallway (HALL_WEBBED), its far wall every HALL_WEB_EVERY metres or
# so, a room's far wall now and then (ROOM_WALL_WEBBED), and the gap
# between a statue and the wall behind it (STATUE_WEBBED). Statues
# and standing pots are solid; bones, shards and webs are not.
const STATUE_ROOM = .45
const STATUE_HALL = 11.0
const SKELETONS = .5
const POTS = .6
const WEBBED = .45
const HALL_WEBBED = .75
const HALL_WEB_EVERY = 6.0
const ROOM_WALL_WEBBED = .4
const WEB_HEIGHT = 2.7
var unlit_cells: Dictionary = {}
func furnish_basement(run_seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = Layout.floor_seed(run_seed,level+11+Layout.KINDS[layout.kind].salt)
	var keep_clear: Array[Vector2i] = [layout.start,layout.exit_cell]
	if layout.arrival.has_area(): keep_clear.append(layout.arrival_foot)
	# A cell with wall at its back toward `back` (and beside it, so it is
	# not at a doorway's edge), clear of the ways in and out.
	var by_wall = func(cell: Vector2i, back: Vector2i) -> bool:
		if not layout.cells.has(cell) or layout.is_open(cell+back): return false
		var side = Vector2i(absi(back.y),absi(back.x))
		if layout.is_open(cell+back+side) or layout.is_open(cell+back-side): return false
		if layout.stairs.grow(2).has_point(cell) or layout.arrival.grow(2).has_point(cell) or layout.entry.grow(3).has_point(cell) or layout.gate.grow(3).has_point(cell): return false
		for spot in keep_clear:
			if (cell-spot).length() < 4.0: return false
		return true
	var facing = func(back: Vector2i) -> float: return atan2(-back.x,-back.y)
	var show = func(thing: Node3D, cell: Vector2i, solid: bool) -> void:
		add_child(thing)
		visibility_nodes.append(thing)
		visibility_cells[thing] = [cell]
		if solid:
			layout.cells.erase(cell)
			solid_floor[cell] = true
	# The places along a room's walls: [cell, back] for each.
	var wall_spots = func(room: Rect2i) -> Array:
		var spots: Array = []
		# (Only along the walls the camera faces: the near ones would hide
		# whatever stood against them.)
		for x in range(room.position.x+1,room.end.x-1): spots.append([Vector2i(x,room.position.y),Vector2i.UP])
		for y in range(room.position.y+1,room.end.y-1): spots.append([Vector2i(room.position.x,y),Vector2i.LEFT])
		for i in range(spots.size()-1,0,-1):
			var j = rng.randi_range(0,i)
			var swap = spots[i]; spots[i] = spots[j]; spots[j] = swap
		return spots.filter(func(spot): return by_wall.call(spot[0],spot[1]))
	for i in layout.rooms.size():
		var room: Rect2i = layout.rooms[i]
		if room == layout.vault: continue
		var spots: Array = wall_spots.call(room)
		var taken: Array[Vector2i] = []
		var free = func(cell: Vector2i) -> bool:
			for other in taken:
				if (other-cell).length() < 2.5: return false
			return layout.cells.has(cell)
		if i > 0 and rng.randf() < STATUE_ROOM:
			for spot in spots:
				if not free.call(spot[0]): continue
				var statue = BasementProps.damaged_statue(rng)
				statue.position = layout.to_world(spot[0])
				statue.rotation.y = facing.call(spot[1])
				show.call(statue,spot[0],true)
				unlit_cells[spot[0]] = true
				statue_web(rng,spot[0],spot[1],show)
				taken.append(spot[0])
				break
		if rng.randf() < SKELETONS:
			var slumped: bool = rng.randf() < .5
			if slumped:
				for spot in spots:
					if not free.call(spot[0]): continue
					var body = BasementProps.skeleton(rng,true)
					body.position = layout.to_world(spot[0])+Vector3(spot[1].x,0,spot[1].y)*.35
					body.rotation.y = facing.call(spot[1])
					show.call(body,spot[0],false)
					taken.append(spot[0])
					break
			else:
				var cell = Vector2i(rng.randi_range(room.position.x+2,room.end.x-3),rng.randi_range(room.position.y+2,room.end.y-3))
				if free.call(cell):
					var body = BasementProps.skeleton(rng,false) if rng.randf() < .6 else BasementProps.bones(rng)
					body.position = layout.to_world(cell)
					body.rotation.y = rng.randf_range(0,TAU)
					show.call(body,cell,false)
					taken.append(cell)
		if rng.randf() < POTS:
			for spot in spots:
				if not free.call(spot[0]): continue
				var side = Vector2i(absi(spot[1].y),absi(spot[1].x))
				for k in rng.randi_range(1,3):
					var cell: Vector2i = spot[0]+side*k
					if not by_wall.call(cell,spot[1]) or not layout.cells.has(cell): break
					pot(rng,cell,spot[1],show)
				taken.append(spot[0])
				break
	# Webs in the corners that are true corners, in the rooms and along the
	# hallway (more often there, HALL_WEBBED).
	for room in layout.rooms+layout.halls:
		if room == layout.vault: continue
		var chance: float = HALL_WEBBED if room in layout.halls else WEBBED
		# (Not the nearest corner, between the two walls nearest the camera.)
		for corner in [room.position,Vector2i(room.end.x-1,room.position.y),Vector2i(room.position.x,room.end.y-1)]:
			if rng.randf() > chance: continue
			var inward = Vector2i(1 if corner.x==room.position.x else -1,1 if corner.y==room.position.y else -1)
			if layout.is_open(corner-Vector2i(inward.x,0)) or layout.is_open(corner-Vector2i(0,inward.y)): continue
			var web = BasementProps.web(rng.randf_range(1.0,1.6))
			web.position = layout.to_world(corner)-Vector3(inward.x,0,inward.y)*.5+Vector3.UP*WEB_HEIGHT
			web.rotation.y = {Vector2i(1,1):0.0,Vector2i(-1,1):-PI/2,Vector2i(1,-1):PI/2,Vector2i(-1,-1):PI}[inward]
			show.call(web,corner,false)
			unlit_cells[corner] = true
	# Along the hallway's walls: statues, now and then, and the odd body;
	# and webs hung on them every few metres (HALL_WEB_EVERY).
	for hall in layout.halls:
		var along_x: bool = hall.size.x >= hall.size.y
		var length: int = hall.size.x if along_x else hall.size.y
		for back in [Vector2i.UP if along_x else Vector2i.LEFT]:
			var at: float = rng.randf_range(3.0,STATUE_HALL)
			while at < length-3:
				var step = int(at)
				var cell: Vector2i
				if along_x: cell = Vector2i(hall.position.x+step,hall.position.y if back==Vector2i.UP else hall.end.y-1)
				else: cell = Vector2i(hall.position.x if back==Vector2i.LEFT else hall.end.x-1,hall.position.y+step)
				if by_wall.call(cell,back):
					var statue: bool = rng.randf() < .7
					var thing: Node3D = BasementProps.damaged_statue(rng) if statue else BasementProps.skeleton(rng,true)
					thing.position = layout.to_world(cell)+(Vector3.ZERO if statue else Vector3(back.x,0,back.y)*.35)
					thing.rotation.y = facing.call(back)
					show.call(thing,cell,statue)
					if statue:
						unlit_cells[cell] = true
						statue_web(rng,cell,back,show)
				at += rng.randf_range(STATUE_HALL*.7,STATUE_HALL*1.3)
			at = rng.randf_range(1.0,HALL_WEB_EVERY)
			while at < length-1:
				var step = int(at)
				var cell: Vector2i = Vector2i(hall.position.x+step,hall.position.y) if along_x else Vector2i(hall.position.x,hall.position.y+step)
				var side = Vector2i(absi(back.y),absi(back.x))
				if layout.cells.has(cell) and not layout.is_open(cell+back) and not layout.is_open(cell+back+side) and not layout.is_open(cell+back-side):
					wall_web(rng,cell,back,show)
				at += rng.randf_range(HALL_WEB_EVERY*.6,HALL_WEB_EVERY*1.4)
	# And one now and then on a room's far wall.
	for i in range(1,layout.rooms.size()):
		if layout.rooms[i] == layout.vault or rng.randf() > ROOM_WALL_WEBBED: continue
		var room: Rect2i = layout.rooms[i]
		var back: Vector2i = Vector2i.UP if rng.randf() < .5 else Vector2i.LEFT
		var cell: Vector2i = Vector2i(rng.randi_range(room.position.x+1,room.end.x-2),room.position.y) if back == Vector2i.UP else Vector2i(room.position.x,rng.randi_range(room.position.y+1,room.end.y-2))
		var side = Vector2i(absi(back.y),absi(back.x))
		if not layout.is_open(cell+back) and not layout.is_open(cell+back+side) and not layout.is_open(cell+back-side): wall_web(rng,cell,back,show)

# The basement's walls, dirtied (assets/shaders/wall_grime.gdshader): damp
# risen from the floor, streaks run down from the top, grime. On the walls the
# camera sees, a stretch now and then (DAMAGED, of each metre) is broken: the
# dressed face fallen away in a spot or two, cracks about them, and below,
# where they fell, rubble and chips of stone on the floor.
const DAMAGED = .07
var wall_pieces: Array = []
func grime_walls(rng: RandomNumberGenerator) -> void:
	var shared = ShaderMaterial.new()
	shared.shader = load("res://assets/shaders/wall_grime.gdshader")
	var groups: Dictionary = {}
	for group in occluders: groups[group.root] = group
	for piece in wall_pieces:
		var grime: ShaderMaterial = shared
		var back: Vector2i = piece.back
		if back in [Vector2i.UP,Vector2i.LEFT] and rng.randf() < DAMAGED*piece.length:
			grime = shared.duplicate()
			var spots = PackedVector4Array()
			for k in rng.randi_range(1,2):
				var along: float = rng.randf_range(-.5,.5)*(piece.length-1.0)
				var at: Vector3 = piece.face+(Vector3(along,0,0) if piece.horizontal else Vector3(0,0,along))
				var low: bool = rng.randf() < .55
				spots.append(Vector4(at.x,rng.randf_range(.25,.9) if low else rng.randf_range(1.0,2.6),at.z,rng.randf_range(.22,.5)))
				rubble(rng,at,back)
			grime.set_shader_parameter("spots",spots)
			grime.set_shader_parameter("spot_count",spots.size())
		for mesh in piece.node.find_children("*","MeshInstance3D",true,false): mesh.material_overlay = grime
		if groups.has(piece.node): groups[piece.node].grime = grime

# What fell from a broken wall, at the foot of its face at `at` (the wall's
# back toward `back`): a low heap of rubble and a few smaller pieces.
func rubble(rng: RandomNumberGenerator, at: Vector3, back: Vector2i) -> void:
	var out = Vector3(-back.x,0,-back.y)
	var cell: Vector2i = layout.to_cell(at+out*.5)
	if not layout.cells.has(cell): return
	var heap = Node3D.new()
	heap.position = at+out*rng.randf_range(.2,.35)
	var pile = Kit.prop("rubble",rng.randf_range(.18,.3))
	pile.rotation.y = rng.randf_range(0,TAU)
	heap.add_child(pile)
	for k in rng.randi_range(2,4):
		var chip = Kit.prop("rubble",rng.randf_range(.05,.09))
		chip.position = out*rng.randf_range(.2,.7)+Vector3(out.z,0,out.x)*rng.randf_range(-.6,.6)
		chip.rotation = Vector3(rng.randf_range(0,TAU),rng.randf_range(0,TAU),rng.randf_range(0,TAU))*.3
		heap.add_child(chip)
	add_child(heap)
	visibility_nodes.append(heap)
	visibility_cells[heap] = [cell]

# A web draped on the wall at `cell`'s back (toward `back`), high up.
func wall_web(rng: RandomNumberGenerator, cell: Vector2i, back: Vector2i, show: Callable) -> void:
	var web = BasementProps.wall_web(rng.randf_range(.9,1.7))
	web.position = layout.to_world(cell)+Vector3(back.x,0,back.y)*.5+Vector3.UP*rng.randf_range(2.5,3.0)
	web.rotation.y = atan2(-back.x,-back.y)
	show.call(web,cell,false)

# A web strung from the wall behind a statue (at `cell`, its back toward
# `back`) to its shoulders, now and then (STATUE_WEBBED).
const STATUE_WEBBED = .55
func statue_web(rng: RandomNumberGenerator, cell: Vector2i, back: Vector2i, show: Callable) -> void:
	if rng.randf() > STATUE_WEBBED: return
	var web = BasementProps.bridge_web(.36,rng.randf_range(.7,1.1),rng.randf_range(2.45,2.75),rng.randf_range(.55,.85))
	web.position = layout.to_world(cell)+Vector3(back.x,0,back.y)*.5
	web.rotation.y = atan2(-back.x,-back.y)
	show.call(web,cell,false)

# A pot against the wall at `cell` (its back toward `back`): an urn, a vase
# or a plain pot, standing, knocked over, or smashed to a heap of shards.
const POT_KINDS = ["pot","urn","vase","pot"]
func pot(rng: RandomNumberGenerator, cell: Vector2i, back: Vector2i, show: Callable) -> void:
	var roll: float = rng.randf()
	var id: String = "urn_broken" if roll < .35 else POT_KINDS[rng.randi_range(0,POT_KINDS.size()-1)]
	var height: float = {"pot":rng.randf_range(.45,.6),"urn":rng.randf_range(.7,.9),"vase":rng.randf_range(.55,.75),"urn_broken":rng.randf_range(.3,.42)}[id]
	var thing = Kit.prop(id,height)
	var holder = Node3D.new()
	holder.add_child(thing)
	holder.position = layout.to_world(cell)+Vector3(back.x,0,back.y)*rng.randf_range(.1,.25)+Vector3(rng.randf_range(-.12,.12),0,rng.randf_range(-.12,.12))
	holder.rotation.y = rng.randf_range(0,TAU)
	var standing = id != "urn_broken"
	# (Knocked over: lying on its side.)
	if standing and roll > .82:
		thing.rotation.z = PI/2
		thing.position.y = height*.3
		standing = false
	show.call(holder,cell,standing)

# The rooms off the far half of the basement's hallway (not the vault), where
# the gate's key is kept.
func key_rooms() -> Array:
	var far: Array = []
	for i in range(1,layout.rooms.size()):
		if layout.rooms[i] != layout.vault and layout.reach[i] > layout.hall_length*.5: far.append(layout.rooms[i])
	return far

# The basement's gate (scripts/basement_props.gd), GATE_HEIGHT tall under a
# lintel up to the walls' top: barred to movement while it is locked, though
# seen through, between its bars. `open_gate` swings it open over GATE_SWING
# seconds (at once, `instantly`, where it was opened before).
const BasementProps = preload("res://scripts/basement_props.gd")
const GATE_HEIGHT = 2.7
const GATE_SWING = 1.6
var gate_node: Node3D
var gate_open = false
func setup_gate(stone: Material) -> void:
	var g: Rect2i = layout.gate
	gate_node = BasementProps.gate(g.size.x*g.size.y,GATE_HEIGHT,WALL_HEIGHT,stone)
	add_child(gate_node)
	gate_node.position = gate_point()
	gate_node.rotation.y = atan2(layout.gate_dir.x,layout.gate_dir.y)
	visibility_nodes.append(gate_node)
	var faces: Array[Vector2i] = []
	for y in range(g.position.y-1,g.end.y+1):
		for x in range(g.position.x-1,g.end.x+1): faces.append(Vector2i(x,y))
	visibility_cells[gate_node] = faces
	bar_gate(true)

# The middle of the gate, on the floor.
func gate_point() -> Vector3:
	var g: Rect2i = layout.gate
	return layout.to_world(g.position)+Vector3(g.size.x-1,0,g.size.y-1)*.5

func bar_gate(barred: bool) -> void:
	var g: Rect2i = layout.gate
	for y in range(g.position.y,g.end.y):
		for x in range(g.position.x,g.end.x):
			var cell = Vector2i(x,y)
			if barred:
				layout.cells.erase(cell)
				solid_floor[cell] = true
			else:
				layout.cells[cell] = true
				solid_floor.erase(cell)
	# (Before the floor's navigation is built, it will be built from these.)
	if nav.region.has_area():
		for y in range(g.position.y-1,g.end.y+1):
			for x in range(g.position.x-1,g.end.x+1):
				var at: Vector3 = layout.to_world(Vector2i(x,y))
				var point = Vector2i(roundi(at.x),roundi(at.z))
				if nav.is_in_boundsv(point): nav.set_point_solid(point,not fits(at,.4))

func open_gate(instantly: bool = false) -> void:
	if gate_node == null or gate_open: return
	gate_open = true
	bar_gate(false)
	if instantly:
		BasementProps.open_gate(gate_node,1.0)
		return
	var swing = create_tween()
	swing.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing.tween_method(func(t): BasementProps.open_gate(gate_node,t),0.0,1.0,GATE_SWING)

# The light beyond a door to the world outside follows the time of day there
# (scripts/daylight.gd).
func set_time(clock: float) -> void:
	var beyond = get_node_or_null("TempleDoorDaylight")
	if beyond == null: return
	var sky: Dictionary = preload("res://scripts/daylight.gd").sky(clock)
	var lit: Color = sky.sky.lerp(Color(.86,.70,.48),.5)*(1.0-sky.night*.55)
	for mesh in beyond.find_children("*","MeshInstance3D",true,false): mesh.material_override.albedo_color = Color(lit.r,lit.g,lit.b)
	var spill = get_node_or_null("TempleDoorSunlight")
	if spill != null:
		spill.light_color = sky.light.lerp(sky.ambient,.4)
		spill.light_energy = lerpf(1.0,.3,sky.night)

# The temple's door, from inside: an open portal at the end of the first
# floor's passage, with the desert's daylight beyond it.
func build_entry(stone: Material) -> void:
	var rect: Rect2i = layout.entry
	var out = Vector3(layout.entry_dir.x,0,layout.entry_dir.y)
	var middle = layout.to_world(rect.position)+Vector3(rect.size.x-1,0,rect.size.y-1)*.5
	var threshold = middle+out*(Layout.ENTRY_DEPTH*.5+.14)
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x): cells.append(Vector2i(x,y))
	var portal = place("arch",threshold,Vector3(Layout.ENTRY_WIDTH+.28,WALL_HEIGHT,.5),stone)
	portal.name = "TempleDoor"
	if layout.entry_dir.x!=0: portal.rotation.y = PI/2
	visibility_cells[portal] = cells
	# Sunlit sand fills the opening: a bright, unshaded slab just outside.
	var daylight = StandardMaterial3D.new()
	daylight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	daylight.albedo_color = Color(.86,.70,.48)
	var across = Vector3(absf(out.z),0,absf(out.x))
	var beyond = Art.model("floor",Vector3(.3,.3,.3)+across*(Layout.ENTRY_WIDTH-.2)+Vector3.UP*(WALL_HEIGHT-.5),daylight)
	beyond.name = "TempleDoorDaylight"
	add_child(beyond)
	beyond.position = threshold+out*.5
	visibility_nodes.append(beyond)
	visibility_cells[beyond] = cells
	var spill = OmniLight3D.new()
	spill.name = "TempleDoorSunlight"
	spill.light_color = Color(1.0,.90,.72)
	spill.light_energy = 1.0
	spill.omni_range = 6.5
	spill.omni_attenuation = 1.2
	spill.shadow_enabled = false
	spill.position = threshold-out*.9+Vector3.UP*1.7
	add_child(spill)
	visibility_nodes.append(spill)
	visibility_cells[spill] = cells

# A temple floor is level. (Outdoors the ground can rise: Overworld.lift.)
func lift(_at: Vector3) -> float:
	return 0.0

# Walking through the first floor's door leaves for the desert.
func leaving_temple(at: Vector3) -> bool:
	return layout.at_door(layout.to_cell(at))

# Whether the hero is in, or at the mouth of, the door's passage.
func leaving_soon(at: Vector3) -> bool:
	return layout.entry.has_area() and layout.entry.grow(2).has_point(layout.to_cell(at))

# A low scenery parapet from `a` to `b` (along X or Z), in pieces about a
# metre and a quarter long, so its carved stones keep their shape.
func parapet_run(a: Vector3, b: Vector3, mat: Material) -> void:
	var length = a.distance_to(b)
	var count = maxi(1,roundi(length/1.28))
	var along_x = absf(b.x-a.x)>absf(b.z-a.z)
	for i in count:
		var mid = a.lerp(b,(i+.5)/count)
		var piece = length/count+.02
		place_scenery("wall",mid,Vector3(piece,LOW_WALL_HEIGHT,.28) if along_x else Vector3(.28,LOW_WALL_HEIGHT,piece),mat)

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

# Enemies stand in loose clumps of CLUMPS enemies (least and most; smaller
# on the arena basement's levels: BASEMENT_CLUMPS), each clump grown over
# open floor within CLUMP_REACH of where it was begun (CLUMP_STEPS walking
# steps, so never through a wall), its members POST_GAP or more apart, taken
# from that ground with CLUMP_SCATTER of shuffle so they straggle rather than
# huddle, and the clumps CLUMP_APART from each other where the floor allows.
# The posts come back shuffled, so the kinds a floor holds are mixed through
# its clumps.
const CLUMPS = Vector2i(3,8)
const BASEMENT_CLUMPS = [Vector2i(2,3),Vector2i(2,5)]
const CLUMP_REACH = 7.0
const CLUMP_STEPS = 11
const CLUMP_SCATTER = 3.0
const CLUMP_APART = 12.0
const POST_GAP = 3.0

# Where an enemy may stand: not in the fountain court or the doorway, clear
# of the hero's arrival and the way on.
func post_allowed(cell: Vector2i) -> bool:
	if layout.court.has_area() and layout.court.has_point(cell): return false
	if layout.entry.has_area() and layout.entry.grow(4).has_point(cell): return false
	# (Nor behind the basement's gate, nor in its mouth.)
	if layout.vault.has_point(cell) or (layout.gate.has_area() and layout.gate.grow(3).has_point(cell)): return false
	var at = layout.to_world(cell)
	return at.distance_to(spawn)>=9 and at.distance_to(exit_point)>=2.5 and fits(at,.45)

# How many stand in each clump, each its own size within this floor's span.
func clump_span() -> Vector2i:
	if layout.kind == "basement": return BASEMENT_CLUMPS[clampi(layout.level_index,0,BASEMENT_CLUMPS.size()-1)]
	return CLUMPS

func clump_sizes(count: int, rng: RandomNumberGenerator) -> Array[int]:
	return knot_sizes(count,clump_span(),rng)

# Sizes from `span.x` to `span.y` at random, adding up to `count` (none left
# smaller than the least, where that can be helped).
func knot_sizes(count: int, span: Vector2i, rng: RandomNumberGenerator) -> Array[int]:
	var sizes: Array[int] = []
	var left: int = count
	while left > 0:
		# What is left over must still make a clump of the least size.
		var size: int = left if left <= span.y else rng.randi_range(span.x,mini(span.y,left-span.x))
		sizes.append(size)
		left -= size
	return sizes

# The open cells a clump begun at `seed_cell` may take, nearest first (a
# little shuffled), reached by walking.
func clump_ground(seed_cell: Vector2i, allowed: Dictionary, rng: RandomNumberGenerator) -> Array:
	var origin: Vector3 = layout.to_world(seed_cell)
	var steps = {seed_cell:0}
	var queue: Array[Vector2i] = [seed_cell]
	var ground: Array = []
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if allowed.has(cell): ground.append([layout.to_world(cell).distance_to(origin)+rng.randf()*CLUMP_SCATTER,cell])
		if steps[cell]>=CLUMP_STEPS: continue
		for direction in Layout.DIRS:
			var next: Vector2i = cell+direction
			if steps.has(next) or not layout.cells.has(next) or layout.to_world(next).distance_to(origin)>CLUMP_REACH: continue
			steps[next] = steps[cell]+1
			queue.append(next)
	ground.sort_custom(func(a,b): return a[0]<b[0])
	return ground.map(func(entry): return entry[1])

func spaced(at: Vector3, posts: Array, gap: float) -> bool:
	for other in posts:
		if other.distance_squared_to(at)<gap*gap: return false
	return true

# Which way a post faces: away from the wall at its back, if it stands at one;
# out from its clump's middle, if not (a ring keeping watch all round).
func post_facing(cell: Vector2i, middle: Vector3, rng: RandomNumberGenerator) -> float:
	var backs: Array[Vector2i] = []
	for direction in Layout.DIRS:
		if not layout.cells.has(cell+direction): backs.append(direction)
	if not backs.is_empty():
		var back = backs[rng.randi_range(0,backs.size()-1)]
		return atan2(-back.x,-back.y)
	var out: Vector3 = layout.to_world(cell)-middle
	if out.length()<.5: out = Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))
	return atan2(out.x,out.z)

func statue_posts(count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var allowed: Dictionary = {}
	var seeds: Array[Vector2i] = []
	for cell in layout.cells:
		if post_allowed(cell):
			allowed[cell] = true
			seeds.append(cell)
	for i in range(seeds.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var swap = seeds[i]; seeds[i] = seeds[j]; seeds[j] = swap
	# Behind a gate: its key is carried by one of a clump begun first, in a
	# room off the far half of the hallway.
	var key_room = Rect2i()
	if layout.gate.has_area():
		var far: Array = key_rooms()
		if not far.is_empty():
			key_room = far[rng.randi_range(0,far.size()-1)]
			var inside: Array[Vector2i] = []
			var outside: Array[Vector2i] = []
			for cell in seeds: (inside if key_room.has_point(cell) else outside).append(cell)
			seeds = inside+outside
	var sizes: Array[int] = clump_sizes(count,rng)
	var placed: Array = []
	var posts: Array[Dictionary] = []
	# Clumps are begun well apart; where a floor is too small for that, closer.
	var apart = CLUMP_APART
	while not sizes.is_empty() and apart>=0.0:
		for seed_cell in seeds:
			if sizes.is_empty(): break
			var origin: Vector3 = layout.to_world(seed_cell)
			if not spaced(origin,placed,maxf(apart,POST_GAP)): continue
			var clump: Array = []
			for cell in clump_ground(seed_cell,allowed,rng):
				var at: Vector3 = layout.to_world(cell)
				if spaced(at,placed,maxf(apart*.5,POST_GAP)) and spaced(at,clump.map(func(c): return layout.to_world(c)),POST_GAP): clump.append(cell)
				if clump.size()==sizes[0]: break
			if clump.size()<sizes[0]: continue
			sizes.remove_at(0)
			var middle = Vector3.ZERO
			for cell in clump: middle += layout.to_world(cell)/clump.size()
			for cell in clump:
				var at: Vector3 = layout.to_world(cell)
				placed.append(at)
				posts.append({"at":at,"facing":post_facing(cell,middle,rng)})
		apart -= 3.0
	assert(sizes.is_empty(),"Generated floor has no room for its enemies' clumps")
	if layout.gate.has_area() and not posts.is_empty():
		var holders: Array = posts.filter(func(p): return key_room.has_point(layout.to_cell(p.at)))
		if holders.is_empty(): holders = posts.filter(func(p): return key_rooms().any(func(r): return r.has_point(layout.to_cell(p.at))))
		if holders.is_empty():
			holders = posts.duplicate()
			holders.sort_custom(func(a,b): return a.at.distance_squared_to(spawn)>b.at.distance_squared_to(spawn))
			holders.resize(1)
		holders[rng.randi_range(0,holders.size()-1)]["key"] = true
	for i in range(posts.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var swap = posts[i]; posts[i] = posts[j]; posts[j] = swap
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
		# A fountain court keeps its authored torches around the pool.
		if layout.court.has_area() and layout.court.grow(1).has_point(cell): continue
		levels[cell] = 0.0
	var placed: Array[Vector3] = []
	for at in torch_lights: placed.append(at)
	for at in placed: add_light(levels,at)
	for at in candidates:
		if layout.court.has_area() and layout.court.grow(1).has_point(layout.to_cell(at)): continue
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

# Whether the wall on `direction`'s side of `cell` is a low parapet: every wall
# of the summit, and a terrace's outer edge.
func low_wall(cell: Vector2i, direction: Vector2i) -> bool:
	return layout.summit or (layout.on_terrace(cell) and not Rect2i(0,0,layout.size,layout.size).has_point(cell+direction))

func torch(at: Vector3, cast_shadows: bool, wall: Vector3) -> void:
	torch_walls[at] = wall
	var cell = layout.to_cell(at)
	# On a low parapet the light is a brazier standing on the wall's top: a
	# bronze fire bowl on three legs, burning with the torches' own flame.
	var brazier = level!=Layout.PLAYGROUND and low_wall(cell,Vector2i(roundi(wall.x),roundi(wall.z)))
	var flame_at: Vector3
	if brazier:
		var bowl_at = at+wall*BRAZIER_INSET+Vector3.UP*LOW_WALL_HEIGHT
		var bowl = place("fire_bowl",bowl_at,BRAZIER_SIZE,Art.bronze())
		braziers.append(bowl)
		# The bowl casts no shadow, so its own fire never shades it.
		for mesh in bowl.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# It is heaped nearly to the rim with burning coals, so the polished
		# bronze inside (which glared white, or mirrored the dark sky) is
		# never seen, and the flame rises from them.
		var coals = MeshInstance3D.new()
		coals.mesh = SphereMesh.new()
		coals.mesh.radial_segments = 32
		coals.mesh.rings = 16
		coals.material_override = coal_material()
		coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coals.scale = Vector3(BRAZIER_SIZE.x*.88,.16,BRAZIER_SIZE.z*.88)
		coals.position = Vector3.UP*BRAZIER_SIZE.y*.8
		bowl.add_child(coals)
		coals.scale /= bowl.scale
		coals.position /= bowl.scale
		coals.layers = bowl.find_children("*","MeshInstance3D",true,false)[0].layers
		# It stands on the wall; it is seen from the floor in front of it.
		visibility_cells[bowl] = [cell]
		flame_at = bowl_at+Vector3.UP*BRAZIER_SIZE.y*.9
	else:
		var fixture = place("brazier",at,Vector3(.6,1.6,.6),Art.material("gold"))
		# The fixture's back plate is on its local -Z side; turn it flat to the wall.
		fixture.rotation.y = atan2(-wall.x,-wall.z)
		# Sitting right under its own flame, the holder would throw its outline
		# across the wall beside it (most plainly into a corner): it casts no
		# shadow.
		for mesh in fixture.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var flame = place("torch_lit",at+Vector3.UP,Vector3(.5,1.0,.5))
		for mesh in flame.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in mesh.mesh.get_surface_count():
				var source = mesh.get_active_material(surface)
				var material = ShaderMaterial.new()
				material.shader = preload("res://assets/shaders/torch.gdshader")
				if source is StandardMaterial3D: material.set_shader_parameter("atlas",source.albedo_texture)
				mesh.set_surface_override_material(surface,material)
		# The flame rises from the torch's wick.
		flame_at = at+Vector3.UP*1.96
	var light = OmniLight3D.new()
	# A torch's light hangs just above its wick; a brazier's above its fire.
	light.position = flame_at+Vector3.UP*(BRAZIER_FIRE_LIFT if brazier else TORCH_HEIGHT-1.96)
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
	fire.position = flame_at
	if brazier: fire.scale = Vector3.ONE*BRAZIER_FLAME_SCALE
	# Stable spatial phases keep neighboring torches from pulsing in unison.
	fire.setup(light,fposmod(at.x*12.9898+at.z*78.233,100.0))
	add_child(fire)
	visibility_nodes.append(fire)
	if brazier:
		visibility_cells[light] = [cell]
		visibility_cells[fire] = [cell]

func place(id: String, pos: Vector3, size: Vector3, mat: Material = null) -> Node3D:
	# The wall's continuous face runs along local X. Rotate north–south
	# runs; stretching its recessed end profile along Z creates large holes.
	var turn_wall = id=="wall" and size.z>size.x
	var dimensions = Vector3(size.z,size.y,size.x) if turn_wall else size
	var n = Art.model(id,dimensions,mat)
	if turn_wall: n.rotation.y = PI/2
	add_child(n)
	n.position = pos
	if id == "floor": debris_floors.append(AABB(pos-Vector3(size.x*.5,0,size.z*.5),size))
	elif id in ["wall","column","stairs","bookcase"]: debris_props.append(n)
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

func ensure_debris_collision() -> void:
	if is_instance_valid(debris_collision): return
	StoneFragment.prepare()
	debris_collision = StaticBody3D.new()
	debris_collision.name = "DebrisCollision"
	debris_collision.collision_layer = StoneFragment.WORLD_LAYER
	debris_collision.collision_mask = StoneFragment.DEBRIS_LAYER
	add_child(debris_collision)
	# Merge adjacent paving in each row into slabs, leaving stairwell openings
	# and gaps between rooms intact. This also removes seams under small chips.
	var rows: Dictionary = {}
	for box in debris_floors:
		var key = Vector4(box.position.y,box.position.z,box.size.y,box.size.z)
		if not rows.has(key): rows[key] = []
		rows[key].append(box)
	for row in rows.values():
		row.sort_custom(func(a,b): return a.position.x < b.position.x)
		var slab: AABB = row[0]
		for box in row.slice(1):
			if box.position.x <= slab.end.x+.001: slab = slab.merge(box)
			else:
				debris_slab(slab)
				slab = box
		debris_slab(slab)
	for wall in debris_walls:
		var shape = BoxShape3D.new()
		shape.size = wall.size
		var collision = CollisionShape3D.new()
		collision.shape = shape
		collision.position = wall.get_center()
		debris_collision.add_child(collision)
	# Each prop's hull is its model's outermost points (worked out once a
	# model), not its every vertex.
	var outlines: Dictionary = {}
	for prop in debris_props:
		for mesh in prop.find_children("*","MeshInstance3D",true,false):
			if not outlines.has(mesh.mesh): outlines[mesh.mesh] = StoneFragment.outline(mesh.mesh.get_faces())
			var points = PackedVector3Array()
			var local: Transform3D = global_transform.affine_inverse()*mesh.global_transform
			for point in outlines[mesh.mesh]: points.append(local*point)
			var hull = ConvexPolygonShape3D.new()
			hull.points = points
			hull.margin = .005
			var collision = CollisionShape3D.new()
			collision.shape = hull
			debris_collision.add_child(collision)

# A full wall, solid WALL_DEPTH back from its face into the ground behind it,
# for the same reason: a fast limb sunk into a thin one is pushed out behind
# it, and held there by the wall while the body is carried on.
const WALL_DEPTH = .6
var debris_walls: Array[AABB] = []

# A slab of floor, solid FLOOR_DEPTH below its paving: a fast limb sunk into
# a thin one is pushed out through its underside, and the body's joints tear
# it apart; sunk into this, it is always pushed back up.
const FLOOR_DEPTH = 1.5
func debris_slab(bounds: AABB) -> void:
	bounds = AABB(bounds.position-Vector3(0,FLOOR_DEPTH,0),bounds.size+Vector3(0,FLOOR_DEPTH,0))
	var shape = BoxShape3D.new()
	shape.size = bounds.size
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position = bounds.get_center()
	debris_collision.add_child(collision)

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

# Every cell sight passes over (floor, the stairwells' solid floor, the
# fountain's footprint), as a grid of bytes laid as the visibility image is:
# looked up far faster than the cells' dictionaries, by every line of sight.
var sight_grid = PackedByteArray()
var sight_grid_cells = -1
func ensure_sight_grid() -> void:
	if sight_grid_cells == layout.cells.size()+solid_floor.size(): return
	sight_grid_cells = layout.cells.size()+solid_floor.size()
	var w: int = visibility_grid_size.x
	sight_grid.resize(w*visibility_grid_size.y)
	sight_grid.fill(0)
	var open: Array = layout.cells.keys()+solid_floor.keys()
	if layout.court.has_area():
		for y in range(layout.court_obstacle.position.y,layout.court_obstacle.end.y):
			for x in range(layout.court_obstacle.position.x,layout.court_obstacle.end.x): open.append(Vector2i(x,y))
	for cell in open:
		var pixel: Vector2i = cell-VISIBILITY_GRID_ORIGIN
		if pixel.x>=0 and pixel.y>=0 and pixel.x<w and pixel.y<visibility_grid_size.y: sight_grid[pixel.y*w+pixel.x] = 1

func clear_line(a: Vector3, b: Vector3) -> bool:
	# A fountain (floors 2 and 3) occupies blocked navigation tiles, but does not hide
	# the rest of the court. Keep the obstacle solid for movement while letting
	# visibility rays pass through its footprint.
	var steps = maxi(1,ceili(a.distance_to(b)/.2))
	if visibility_grid_size.x <= 0:
		for i in range(steps+1):
			if not fits_for_visibility(a.lerp(b,float(i)/steps),.04): return false
		return true
	# (As fits_for_visibility at each step, on the grid of bytes.)
	ensure_sight_grid()
	var w: int = visibility_grid_size.x
	var h: int = visibility_grid_size.y
	var kx: float = layout.start.x-VISIBILITY_GRID_ORIGIN.x+.5
	var ky: float = layout.start.y-9-VISIBILITY_GRID_ORIGIN.y+.5
	var px: float = a.x+kx
	var py: float = a.z+ky
	var dx: float = (b.x-a.x)/steps
	var dy: float = (b.z-a.z)/steps
	for i in range(steps+1):
		var x0: int = floori(px-.04)
		var x1: int = floori(px+.04)
		var y0: int = floori(py-.04)
		var y1: int = floori(py+.04)
		if x0<0 or y0<0 or x1>=w or y1>=h: return false
		if sight_grid[y0*w+x0]==0: return false
		if x1!=x0 or y1!=y0:
			if sight_grid[y0*w+x1]==0 or sight_grid[y1*w+x0]==0 or sight_grid[y1*w+x1]==0: return false
		px += dx
		py += dy
	return true

func fits_for_visibility(p: Vector3, radius: float) -> bool:
	var lo = layout.to_cell(p-Vector3(radius,0,radius))
	var hi = layout.to_cell(p+Vector3(radius,0,radius))
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			var cell = Vector2i(x,y)
			if layout.cells.has(cell): continue
			if layout.court.has_area() and layout.court_obstacle.has_point(cell): continue
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
	# (Pressed into a wall's corner, none may be walked to in a straight
	# line: the nearest open one will do, rather than no way at all.)
	if start.x == -1000: start = navigation_cell(from,false)
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
		desert_backdrop.visible = outdoors or layout.summit
		fog_material.set_shader_parameter("outdoors",desert_backdrop.visible)
		for n in outdoor_scenery: n.visible = desert_backdrop.visible
		# The summit's lower roofs and terrace are always in view, in moonlight.
		terrace_moonlight.visible = outdoors or layout.summit
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
		var nearest = null
		var second = null
		var nearest_d = 100.0
		var second_d = 100.0
		for torch in shadow_torches:
			var d: float = torch.position.distance_squared_to(pos)
			if d < nearest_d:
				second = nearest; second_d = nearest_d
				nearest = torch; nearest_d = d
			elif d < second_d:
				second = torch; second_d = d
		for torch in shadow_torches:
			var lit: bool = torch == nearest or torch == second
			if torch.shadow_enabled != lit: torch.shadow_enabled = lit

		var targets: Array = [{"position":pos,"height":1.8}]+occlusion_targets
		for group in occluders:
			if group.root.position.distance_squared_to(pos)>900 and not group.hidden: continue
			var blocked = false
			for target in targets:
				if Vector2(group.root.position.x-target.position.x,group.root.position.z-target.position.z).length()>OCCLUSION_REACH: continue
				# (The temple's stone stays where it stands: each mesh's box is
				# worked out once.)
				if not group.has("boxes"):
					group.boxes = []
					for mesh in group.meshes: group.boxes.append(mesh.global_transform * mesh.get_aabb())
				for box in group.boxes:
					# Fade anything hiding someone's feet, body or head.
					for share in [.08,.55,1.0]:
						if box.intersects_segment(camera.position,target.position+Vector3.UP*target.height*share): blocked = true; break
					if blocked: break
				if blocked: break
			if blocked != group.hidden:
				group.hidden = blocked
				for mesh in group.meshes:
					mesh.material_override = group.faded if blocked else group.normal
					# (A faded wall shows none of its grime.)
					if group.has("grime"): mesh.material_overlay = null if blocked else group.grime

func update_visibility(pos: Vector3, delta: float) -> void:
	visibility_timer -= delta
	visibility_rest -= delta
	if visibility_row < 0:
		var moved = pos.distance_squared_to(visibility_player_position)
		if visibility_timer>0 and moved<.09: return
		# Standing where he was, he sees what he saw: nothing to work out again
		# (but for a look round now and then, should the temple itself change).
		visibility_timer = .10
		if moved<.0004 and visibility_rest>0: return
		visibility_rest = 1.0
		visibility_player_position = pos
		visibility_next.fill(Color.BLACK)
		visibility_row = 0
	# Only the cells within sight's reach of him are looked at: floor, the
	# stairwells' solid floor and the fountain's footprint (which stays blocked
	# for movement, but whose surface still receives the clear LOS mask). The
	# work is spread over a few frames, a band of rows in each (all at once
	# when asked for at once: `delta` of a tenth of a second or more), and
	# what he sees changes when the last is done.
	ensure_sight_grid()
	var from = visibility_player_position
	var w: int = visibility_grid_size.x
	var centre: Vector2i = layout.to_cell(from)-VISIBILITY_GRID_ORIGIN
	var reach = ceili(VISION_RANGE)+1
	var first = maxi(0,centre.y-reach)
	var last = mini(visibility_grid_size.y,centre.y+reach+1)
	var rows = last-first if delta>=.1 else VISIBILITY_ROWS
	var y = first+visibility_row
	while y < last and rows > 0:
		for x in range(maxi(0,centre.x-reach),mini(w,centre.x+reach+1)):
			if sight_grid[y*w+x]==0: continue
			var at = layout.to_world(Vector2i(x,y)+VISIBILITY_GRID_ORIGIN)
			if at.distance_squared_to(from)>VISION_RANGE*VISION_RANGE or not clear_line(from,at): continue
			visibility_next.set_pixel(x,y,Color.WHITE)
		y += 1
		rows -= 1
	if y < last:
		visibility_row = y-first
		return
	visibility_row = -1
	visibility_image.copy_from(visibility_next)
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

func cell_is_visible(cell: Vector2i) -> bool:
	if level==Layout.PLAYGROUND: return true
	var pixel = cell-VISIBILITY_GRID_ORIGIN
	return pixel.x>=0 and pixel.y>=0 and pixel.x<visibility_grid_size.x and pixel.y<visibility_grid_size.y and visibility_image.get_pixel(pixel.x,pixel.y).r>.5

func can_see(at: Vector3) -> bool:
	return cell_is_visible(layout.to_cell(at))
