extends Node3D
const Art = preload("res://scripts/assets.gd")
const Layout = preload("res://scripts/layout.gd")
var layout = Layout.new()
var boss_point = Vector3.ZERO
var offering_points: Array[Vector3] = []
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
var fountain
var desert_backdrop: Sprite3D
var terrace_moonlight: DirectionalLight3D
var boss_moonlight: SpotLight3D
const TERRACE_LIGHT_LAYER = 8
const VISION_RANGE = 16.0
const VISIBILITY_GRID_ORIGIN = Vector2i(-5,-5)
var visibility_image: Image
var visibility_texture: ImageTexture
var visibility_grid_size = Vector2i.ZERO
var visibility_floor_batches: Array[Dictionary] = []
var visibility_nodes: Array[Node3D] = []
var visibility_timer = 0.0
var visibility_player_position = Vector3(INF,INF,INF)
var fog_material: ShaderMaterial

func setup(floor_index: int, run_seed: int = 1) -> void:
	level = floor_index
	layout.generate(run_seed,floor_index)
	spawn = layout.to_world(layout.start)
	exit_point = layout.to_world(layout.exit_cell)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.35,.40,.50)
	e.ambient_light_energy = .08
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
	var stone = Art.material("stone", [Color(.91,.87,.77),Color(.74,.80,.77),Color(.73,.70,.66),Color(.70,.76,.82),Color(.75,.69,.61),Color(.94,.87,.70)][floor_index])
	var paving = Art.material("marble", Color(.37,.40,.39))
	var court_paving = Art.material("marble",Color(.57,.64,.60))
	var lower = Vector2i(10000,10000)
	var upper = Vector2i(-10000,-10000)
	var edges: Dictionary = {}
	var torch_candidates: Array[Vector3] = []
	for cell in layout.cells:
		var at = layout.to_world(cell)
		lower = lower.min(Vector2i(at.x,at.z))
		upper = upper.max(Vector2i(at.x,at.z))
		place("floor",at+Vector3.DOWN*.16,Vector3(1,.16,1),court_paving if layout.court.has_point(cell) else paving)
		for direction in Layout.DIRS:
			if layout.cells.has(cell+direction): continue
			# The court's solid centerpiece is the fountain, not a wall.
			if layout.court_obstacle.has_point(cell+direction): continue
			var horizontal_edge: bool = direction.y!=0
			var line: float = (at.z+direction.y*.5) if horizontal_edge else (at.x+direction.x*.5)
			var low = floor_index==5 or (layout.on_terrace(cell) and not Rect2i(0,0,layout.size,layout.size).has_point(cell+direction))
			var key = "%s:%s:%s:%s" % [horizontal_edge,line,direction,low]
			if not edges.has(key): edges[key] = {"horizontal":horizontal_edge,"line":line,"direction":direction,"low":low,"along":[]}
			edges[key].along.append(int(at.x if horizontal_edge else at.z))
			# Small wall torches sit inside the boundary, with no floor obstruction.
			torch_candidates.append(at+Vector3(direction.x,0,direction.y)*.28)
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
			var height = 1.0 if edge.low else 3.2
			# Extend each end to the adjacent wall's centerline. The authored
			# molding is wider than its stone core, so a tiny cap overlap leaves
			# open seams at right-angle corners.
			var dimensions = Vector3(last-first+1.28,height,.28) if edge.horizontal else Vector3(.28,height,last-first+1.28)
			place("wall",pos,dimensions,stone)
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
	if floor_index in [3,4,5]: setup_desert()
	# A downward stair marks arrival; ascent is in the furthest generated room.
	var arrival = place("stairs",spawn+Vector3(0,-.25,1.1),Vector3(1.5,.3,1.5),stone)
	arrival.rotation.y = PI
	place("stairs",exit_point,Vector3(2,1.3,2),stone)
	exit_seal = Art.seal(3,Color(.3,1,.85,.85))
	exit_seal.position = exit_point+Vector3.UP*.05
	add_child(exit_seal)
	exit_seal.visible = false
	var torch_positions: Array[Vector3] = []
	# Deterministic placement covers room walls, junctions and galleries.
	for at in torch_candidates:
		if floor_index==2 and layout.court.grow(1).has_point(layout.to_cell(at)): continue
		var crowded = false
		for other in torch_positions:
			if at.distance_squared_to(other)<30.25: crowded=true; break
		if crowded: continue
		torch_positions.append(at)
		torch(at,true)
	if floor_index==2: setup_court_torches()
	if floor_index==5:
		boss_point = layout.to_world(Vector2i(14,10))
		setup_boss_moonlight()
		setup_summit_understructure(stone)
		for corner in [Vector2i(2,2),Vector2i(25,2),Vector2i(2,17),Vector2i(25,17)]:
			var dx = 1 if corner.x<14 else -1
			var dz = 1 if corner.y<10 else -1
			for offset in [Vector2i.ZERO,Vector2i(dx*2,0),Vector2i(dx*4,0),Vector2i(0,dz*2),Vector2i(0,dz*4)]:
				offering_points.append(layout.to_world(corner+offset))
	nav.region = Rect2i(lower,upper-lower+Vector2i.ONE)
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for x in range(lower.x,upper.x+1):
		for z in range(lower.y,upper.y+1):
			if not fits(Vector3(x,0,z),.4): nav.set_point_solid(Vector2i(x,z))
	batch_floors()
	follow(spawn,1)

func setup_desert() -> void:
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
		place("wall",corner+Vector3(strip.size.x*.5,-7,strip.size.y*.5),Vector3(strip.size.x,6.84,strip.size.y),masonry)
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

func setup_visibility_fog() -> void:
	visibility_grid_size = Vector2i(layout.size+10,layout.size+10)
	visibility_image = Image.create(visibility_grid_size.x,visibility_grid_size.y,false,Image.FORMAT_R8)
	visibility_image.fill(Color.BLACK)
	visibility_texture = ImageTexture.create_from_image(visibility_image)
	fog_material = ShaderMaterial.new()
	fog_material.shader = preload("res://assets/shaders/fog_of_war.gdshader")
	fog_material.set_shader_parameter("visibility_mask",visibility_texture)
	var layer = CanvasLayer.new()
	layer.name = "LineOfSightFog"
	layer.layer = 0
	add_child(layer)
	var fog = ColorRect.new()
	fog.name = "FogOverlay"
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.material = fog_material
	layer.add_child(fog)
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
		torch(Vector3(center.x+offset,0,first.z-.28),true)
		torch(Vector3(center.x+offset,0,last.z+.28),true)
	for offset in [-4.5,4.5]:
		torch(Vector3(first.x-.28,0,center.z+offset),true)
		torch(Vector3(last.x+.28,0,center.z+offset),true)

func setup_summit_understructure(stone: Material) -> void:
	# A continuous stone body wraps beneath the southern front and full east
	# edge, keeping the desert out of view around the southeast corner.
	for story in 4:
		var story_base = -8.0*(story+1)
		place("wall",Vector3(-.5,story_base,10.65),Vector3(26,8,1.0),stone)
		place("wall",Vector3(-13.5,story_base,25.5),Vector3(1.0,8,30),stone)
		place("wall",Vector3(12.5,story_base,1.5),Vector3(1.0,8,18),stone)
		place("wall",Vector3(12.5,story_base,25.5),Vector3(1.0,8,30),stone)
		# Projecting stone courses articulate each storey and join the corner returns.
		place("wall",Vector3(-.5,story_base-.55,10.95),Vector3(26,.55,1.6),stone)
		place("wall",Vector3(-13.5,story_base-.55,25.5),Vector3(1.6,.55,30),stone)
		place("wall",Vector3(12.5,story_base-.55,1.5),Vector3(1.6,.55,18),stone)
		place("wall",Vector3(12.5,story_base-.55,25.5),Vector3(1.6,.55,30),stone)
		for x in [-12,-7,-2,3,8,12]:
			place("column",Vector3(x,story_base,11.15),Vector3(.95,8,.95),stone)
		for z in [17,28,39]:
			place("column",Vector3(-13.5,story_base,z),Vector3(.95,8,.95),stone)
		for z in [-5,0,5,10,17,28,39]:
			place("column",Vector3(12.5,story_base,z),Vector3(.95,8,.95),stone)

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

func torch(at: Vector3, cast_shadows: bool) -> void:
	place("brazier",at,Vector3(.6,1.6,.6),Art.material("gold"))
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
	light.position = at+Vector3.UP*2.05
	light.light_color = Color(1,.60,.28)
	light.light_energy = 2.8
	light.omni_range = 9.0
	light.omni_attenuation = 1.6
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
	fire.position = at+Vector3.UP*2.08
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
	# Torches cast architecture shadows without re-rendering the animated crowd.
	var layers = 2 | TERRACE_LIGHT_LAYER if terrace_surface(pos) else 2
	for mesh in n.find_children("*","MeshInstance3D",true,false): mesh.layers = layers
	if id=="floor": floor_nodes.append(n)
	if id in ["wall","arch","column","bookcase"] and mat:
		var faded = mat.duplicate()
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		faded.albedo_color.a = .16
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
	return floor_line(a,b,.04)

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
	fog_material.set_shader_parameter("camera_position",camera.global_position)
	fog_material.set_shader_parameter("camera_right",camera.global_basis.x)
	fog_material.set_shader_parameter("camera_up",camera.global_basis.y)
	fog_material.set_shader_parameter("camera_forward",-camera.global_basis.z)
	fog_material.set_shader_parameter("camera_size",camera.size)
	fog_material.set_shader_parameter("viewport_aspect",viewport_size.x/maxf(1.0,viewport_size.y))
	if is_instance_valid(desert_backdrop):
		var outdoors = layout.on_terrace(layout.to_cell(pos))
		desert_backdrop.visible = outdoors or level==5
		terrace_moonlight.visible = outdoors
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

		for group in occluders:
			if group.root.position.distance_squared_to(pos)>900 and not group.hidden: continue
			var blocked = false
			for mesh in group.meshes:
				var box: AABB = mesh.global_transform * mesh.get_aabb()
				if box.intersects_segment(camera.position,pos+Vector3.UP): blocked = true; break
			if blocked != group.hidden:
				group.hidden = blocked
				for mesh in group.meshes: mesh.material_override = group.faded if blocked else group.normal

func update_visibility(pos: Vector3, delta: float) -> void:
	visibility_timer -= delta
	if visibility_timer>0 and pos.distance_squared_to(visibility_player_position)<.09: return
	visibility_timer = .10
	visibility_player_position = pos
	visibility_image.fill(Color.BLACK)
	for cell in layout.cells:
		var at = layout.to_world(cell)
		var offset = at-pos
		if offset.length_squared()>VISION_RANGE*VISION_RANGE: continue
		if not clear_line(pos,at): continue
		var pixel = cell-VISIBILITY_GRID_ORIGIN
		if pixel.x>=0 and pixel.y>=0 and pixel.x<visibility_grid_size.x and pixel.y<visibility_grid_size.y:
			visibility_image.set_pixel(pixel.x,pixel.y,Color.WHITE)
	visibility_texture.update(visibility_image)
	for batch in visibility_floor_batches:
		var seen = false
		for cell in batch.cells:
			if cell_is_visible(cell): seen = true; break
		batch.node.visible = seen
	for node in visibility_nodes:
		if is_instance_valid(node): node.visible = can_see(node.position)

func cell_is_visible(cell: Vector2i) -> bool:
	var pixel = cell-VISIBILITY_GRID_ORIGIN
	return pixel.x>=0 and pixel.y>=0 and pixel.x<visibility_grid_size.x and pixel.y<visibility_grid_size.y and visibility_image.get_pixel(pixel.x,pixel.y).r>.5

func can_see(at: Vector3) -> bool:
	return cell_is_visible(layout.to_cell(at))
