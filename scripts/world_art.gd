extends RefCounted
## Models and materials of the outdoor world (scripts/overworld.gd). Like the
## temple, it is assembled from imported meshes; this adds their real sizes
## and the materials they share.
const Art = preload("res://scripts/assets.gd")
static var cache: Dictionary = {}

# Each model's own size in metres (width, height, depth) before
# tools/prepare_models.py normalised it to a unit box.
const SIZE = {
	"wall":Vector3(4,4,1),"wall_arched":Vector3(4,4,1),"wall_window":Vector3(4,4,1),"wall_archwindow":Vector3(4,4,1),
	"wall_door":Vector3(4,4,1),"wall_broken":Vector3(4,4,1),"wall_half":Vector3(2,4,1),"arch":Vector3(4,4,1),
	"pillar":Vector3(1.5,4,1.5),"pillar_decorated":Vector3(2.23,4,1.71),"stairs":Vector3(5,5.1,4),"floor":Vector3(4,.2,4),
	"barrel":Vector3(.7,.9,.7),"barrel_rack":Vector3(1.36,1.26,.74),"crate":Vector3(.84,.93,.91),
	"farm_crate":Vector3(.71,.24,.41),"stall":Vector3(1.84,2.63,.93),"cart":Vector3(3.02,2.63,1.06),
	"bench":Vector3(2.78,.53,.53),"table":Vector3(2.85,.81,1.1),"stool":Vector3(.47,.59,.47),
	"urn":Vector3(.36,.49,.36),"bag":Vector3(.66,.8,.54),"bucket":Vector3(.43,.29,.38),"cloth_red":Vector3(.81,2.25,.057),
	"cloth_blue":Vector3(.81,1.93,.057),"weapon_stand":Vector3(1.39,1.11,.98),"dummy":Vector3(.81,1.86,.58),
	"anvil":Vector3(1.08,.56,.4),"chair":Vector3(.58,1.12,.55),"urn_broken":Vector3(.8,.17,.6),"lantern":Vector3(.36,1.34,1.3),"rock":Vector3(3.4,2.3,3.5),
	"boulder_a":Vector3(2.4,1.48,3.09),"boulder_b":Vector3(2.52,1.88,2.49),"boulder_c":Vector3(1.36,.53,.74),
	"boulder_d":Vector3(.67,.65,1.2),"crag":Vector3(20.2,7.19,6.61),"stone_a":Vector3(.077,.035,.063),
	"stone_b":Vector3(.147,.083,.079),"stone_c":Vector3(.113,.037,.083),"shrub_a":Vector3(1.08,1.23,1.1),
	"shrub_b":Vector3(1.11,1.51,1.28),"scrub":Vector3(.43,.45,.47),
	"tree":Vector3(6.1,9.5,5.7),"dead_tree":Vector3(6.39,13.28,6.43),
	"olive_a":Vector3(13.5,16.7,11.5),"olive_b":Vector3(11.4,16.1,11.5),
	"dry_grass":Vector3(1.54,1.67,1.59),"agave":Vector3(1.81,2.35,1.95),
	"palm_a":Vector3(5.98,9.14,6.36),"palm_b":Vector3(6.28,10.49,6.88),
	"palm_c":Vector3(6.13,8.23,6.04),"well":Vector3(.67,1.25,1.0),"column":Vector3(.7,3.8,.7),"rubble":Vector3(8.1,3.5,3.2),
	"vase":Vector3(.7,.5,.7),"fire_bowl":Vector3(.5,.42,.48),
	# The furniture of the inn and the smithy (scripts/world_interiors.gd).
	"bed":Vector3(1.88,.81,2.41),"cabinet":Vector3(1.36,1.0,.36),"shelf":Vector3(1.18,.31,.29),"shelf_bottles":Vector3(1.14,.65,.28),
	"shelf_arch":Vector3(1.25,1.59,.31),"mug":Vector3(.19,.18,.15),"bottle":Vector3(.11,.36,.11),"bottles":Vector3(.22,.15,.06),
	"plate":Vector3(.33,.02,.34),"chandelier":Vector3(1.3,1.46,1.3),"candlestick":Vector3(.44,.46,.14),"chest":Vector3(1.9,2.0,2.0),
	"workbench":Vector3(2.02,.89,1.02),"workbench_drawers":Vector3(.42,.24,.3),"whetstone":Vector3(1.14,1.17,.9),
	"anvil_log":Vector3(.93,1.07,.82),"peg_rack":Vector3(1.18,.35,.1),"chain":Vector3(1.07,.09,.91),"bucket_metal":Vector3(.49,.37,.45),
	"axe_bronze":Vector3(.29,.83,.05),"pickaxe":Vector3(.81,1.2,.14),"nightstand":Vector3(.69,1.22,.39),"crate_metal":Vector3(.86,.87,.87),
	"pot":Vector3(.54,.22,.49),
	# The produce stalls' wares.
	"carrot_crate":Vector3(.71,.41,.57),
	# The street sleepers' bedding (the props kit's bed, without its frame).
	"bedroll":Vector3(1.34,.42,2.14),"apple_barrel":Vector3(.7,.9,.7),"crate_empty":Vector3(.71,.24,.41)}

# The model's dimensions at its own proportions, `height` metres tall.
static func sized(id: String, height: float) -> Vector3:
	var native: Vector3 = SIZE[id]
	return native*(height/native.y)

# A plain colour broken up by photographed grit, at one size in the world:
# for cloth, fired clay and anything else a kit left flat.
static func gritty(tint: Color, scale: float = 1.3, two_sided: bool = false) -> StandardMaterial3D:
	var key = "gritty%s%f%s" % [tint.to_html(),scale,two_sided]
	if cache.has(key): return cache[key]
	# (The grit photograph averages .41.)
	var m = textured("res://assets/textures/rock_detail.jpg",Color(tint.r*2.3,tint.g*2.3,tint.b*2.3),.92)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*scale
	if two_sided: m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cache[key] = m
	return m

static func textured(path: String, tint: Color, roughness: float = .9) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.roughness = roughness
	m.metallic_specular = .2
	return m

# The material shared by every surface whose imported material has this name
# (the kits' models are exported without their own copies of these textures).
static func shared(name: String) -> Material:
	if cache.has(name): return cache[name]
	var m: StandardMaterial3D = null
	match name:
		# The date palm (tools/make_palm.py): photographed bark, painted fronds.
		"PalmBark":
			m = textured("res://assets/textures/palm_bark.jpg",Color(.86,.80,.74),.95)
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/palm_bark_normal.jpg")
			m.normal_scale = 1.4
		"PalmFrond","PalmFrondDry":
			m = textured("res://assets/textures/palm_frond.png" if name=="PalmFrond" else "res://assets/textures/palm_frond_dry.png",Color(.92,.92,.86),.8)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = .3
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			# Sun through the leaflets: the shaded side of a frond is never black.
			m.emission_enabled = true
			m.emission = Color(.07,.09,.04) if name=="PalmFrond" else Color(.08,.06,.04)
		# Poly Haven's scanned shrubs keep their own colour.
		"shrub_02","wild_rooibos_bush","wild_rooibos_bush_twigs","wild_rooibos_bush_leaves":
			m = textured("res://assets/textures/scan_shrub_02.png" if name=="shrub_02" else "res://assets/textures/scan_wild_rooibos_bush.png",Color(1.2,1.12,1.0),.9)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = .4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"Bark_DeadTree": m = textured("res://assets/models/props/tree_Bark_DeadTree.png",Color(1.0,.92,.80),.95)
		"Bark_TwistedTree": m = textured("res://assets/textures/olive_bark.png",Color(.82,.78,.72),.95)
		"Leaves_TwistedTree","Leaves":
			m = textured("res://assets/textures/olive_leaves.png" if name=="Leaves_TwistedTree" else "res://assets/textures/desert_leaves.png",Color(.80,.86,.66) if name=="Leaves_TwistedTree" else Color(.40,.47,.36),.85)
			# Leaf cards turned from the sun still glow with the light through them.
			m.emission_enabled = true
			m.emission = Color(.10,.12,.06) if name=="Leaves_TwistedTree" else Color(.04,.05,.03)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = .5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"Grass":
			m = textured("res://assets/models/props/grass_Grass.png",Color(.86,.70,.42),.95)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"MI_Trim_Furniture": m = textured("res://assets/textures/trim_furniture.png",Color(.9,.84,.76),.85)
		"MI_Trim_Metal","MI_Trim_Metal_Vertex":
			m = textured("res://assets/textures/trim_metal.png",Color(.8,.78,.74),.5)
			m.metallic = .5
		# The kit dyes its cloth and glazes its pots through a second texture
		# layer; here they are plain woven cloth and fired clay.
		"MI_Trim_Cloth": m = gritty(Color(.56,.47,.34),2.2,true)
		"MI_Banner": m = gritty(Color(.46,.12,.09),2.2,true)
		"MI_Trim_Props_Vertex","MI_Trim_Props": m = gritty(Color(.33,.25,.19),2.6)
		# The well (its model comes in flat colours): stone, timber, clay tiles.
		"Stone_Dark": m = gritty(Color(.50,.45,.38),.9)
		"Stone_Light": m = gritty(Color(.62,.56,.47),.9)
		"RoofTiles_Red": m = gritty(Color(.52,.26,.16),1.6)
		"Bag": m = gritty(Color(.50,.42,.30),2.2)
		"Wood":
			m = Art.material("wood",Color(.62,.50,.38)).duplicate()
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE*.8
	if m != null and name in ["MI_Trim_Furniture","MI_Trim_Metal","MI_Trim_Metal_Vertex"]: m.vertex_color_use_as_albedo = true
	cache[name] = m
	return m

# Sawn timber, its grain at one size everywhere: floors, stairs, a bar.
static func planks(tint: Color, scale: float = .8) -> StandardMaterial3D:
	var key = "planks%s%f" % [tint.to_html(),scale]
	if cache.has(key): return cache[key]
	var m: StandardMaterial3D = Art.material("wood",tint).duplicate()
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*scale
	cache[key] = m
	return m

# Forged iron, dull and a little pitted.
static func iron() -> StandardMaterial3D:
	if cache.has("iron"): return cache["iron"]
	var m: StandardMaterial3D = gritty(Color(.34,.33,.32),3.0).duplicate()
	m.metallic = .7
	m.roughness = .5
	cache["iron"] = m
	return m

# A bed of coals: burnt stone that glows.
static func embers() -> StandardMaterial3D:
	if cache.has("embers"): return cache["embers"]
	var m: StandardMaterial3D = gritty(Color(.20,.07,.03),3.0).duplicate()
	m.emission_enabled = true
	m.emission = Color(1.0,.30,.05)
	m.emission_energy_multiplier = .75
	m.emission_texture = m.albedo_texture
	cache["embers"] = m
	return m

# Gives each surface of a kit model its shared material.
static func dress(node: Node3D) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for s in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(s)
			if source == null: continue
			var m = shared(source.resource_name)
			if m != null: mesh.set_surface_override_material(s,m)

# A kit model at its own proportions, `height` metres tall.
static func prop(id: String, height: float) -> Node3D:
	var node = Art.model(id,sized(id,height))
	dress(node)
	return node

# The scans the basin's rocks are cut from (tools/prepare_scans.py), by model.
const SCANS = {"boulder_a":"namaqualand_boulder_03","boulder_b":"namaqualand_boulder_04","boulder_c":"namaqualand_boulder_05",
	"boulder_d":"namaqualand_boulder_06","crag":"namaqualand_cliff_02","stone_a":"namaqualand_stones_01",
	"stone_b":"namaqualand_stones_01","stone_c":"namaqualand_stones_01"}

# Rock for one of the scanned models (assets/shaders/desert_rock.gdshaderinc):
# its own colour multiplied by `tint`; `dust` is how much sand lies on it.
static func rock(id: String, tint: Color = Color.WHITE, dust: float = 1.0) -> ShaderMaterial:
	var key = "rock%s%s%f" % [id,tint.to_html(),dust]
	if cache.has(key): return cache[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/desert_rock.gdshader")
	m.set_shader_parameter("albedo_map",load("res://assets/textures/scan_%s_diff.jpg" % SCANS[id]))
	m.set_shader_parameter("normal_map",load("res://assets/textures/scan_%s_nor_gl.jpg" % SCANS[id]))
	m.set_shader_parameter("detail_map",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
	m.set_shader_parameter("dust",dust)
	cache[key] = m
	return m

# Limestone masonry for the wall kit (assets/shaders/masonry.gdshaderinc):
# stone in `tint`, the kit's timber in `wood`.
# `wear` runs from kept-up dressed stone (0) to walls left to rot (1);
# `ground` is the height of the ground the walls stand on.
static func masonry(tint: Color, wood: Color = Color(.30,.19,.11), scale: float = .16, wear: float = .5, ground: float = 0.0) -> ShaderMaterial:
	var key = "masonry%s%s%f:%f:%f" % [tint.to_html(),wood.to_html(),scale,wear,ground]
	if cache.has(key): return cache[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/masonry.gdshader")
	m.set_shader_parameter("atlas",load("res://assets/models/props/wall_dungeon_texture.png"))
	m.set_shader_parameter("stone",load("res://assets/textures/limestone.png"))
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("tint",tint)
	m.set_shader_parameter("wood",wood)
	m.set_shader_parameter("stone_scale",scale)
	m.set_shader_parameter("wear",wear)
	m.set_shader_parameter("ground",ground)
	cache[key] = m
	return m

# Gold leaf, for the trappings of the arena's royal box and the palace.
static func gold() -> StandardMaterial3D:
	if cache.has("gold_leaf"): return cache.gold_leaf
	# (The grit photograph is brown: the tint leans green to come out gold.)
	var m = gritty(Color(.66,.62,.26),1.1)
	m = m.duplicate()
	m.metallic = .3
	m.roughness = .3
	m.metallic_specular = .9
	# The outdoor scene has no sky to reflect: the gold carries its own glow.
	m.emission_enabled = true
	m.emission = Color(.09,.065,.01)
	cache.gold_leaf = m
	return m

# Pale veined marble, for sculpture and the palace's finest stonework.
static func marble() -> StandardMaterial3D:
	if cache.has("white_marble"): return cache.white_marble
	var m = textured("res://assets/textures/statue_marble.png",Color(.80,.79,.77),.42)
	# Laid at one size in the world, so its veins keep their shape on blocks
	# of any proportion.
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*.27
	m.metallic_specular = .5
	cache.white_marble = m
	return m

# The see-through twin of a material, for whatever stands between the camera
# and the hero. Null when the material has none.
static func faded(source: Material) -> Material:
	if source == null: return null
	var key = "faded%d" % source.get_instance_id()
	if cache.has(key): return cache[key]
	var m: Material = null
	if source is ShaderMaterial:
		for kind in ["masonry","desert_rock"]:
			if source.shader == load("res://assets/shaders/%s.gdshader" % kind):
				m = source.duplicate()
				m.shader = load("res://assets/shaders/%s_faded.gdshader" % kind)
				m.set_shader_parameter("alpha",.34)
	elif source is BaseMaterial3D:
		m = source.duplicate()
		# Cut-out leaves (a palm's fronds, a shrub's) are blended too: left
		# cut out, their alpha scaled down fell under the cut and nearly every
		# leaf vanished instead of fading.
		if m.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = .34
	cache[key] = m
	return m

# Gives a model's hanging cloth (a stall's awning, a banner) its dye.
static func dye(node: Node3D, color: Color) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for s in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(s)
			if source != null and source.resource_name=="MI_Banner": mesh.set_surface_override_material(s,gritty(color,2.2,true))

# The fruit or vegetables in a kit model (its vertex-painted surface) drawn
# as produce (assets/shaders/produce.gdshader): as the kit coloured them, or
# with its apples turned to `fruit` when that is given.
static func produce(node: Node3D, fruit: Color = Color(0,0,0,0)) -> void:
	var key = "produce%s" % fruit.to_html()
	if not cache.has(key):
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/produce.gdshader")
		m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
		if fruit.a > 0.0:
			m.set_shader_parameter("fruit",fruit)
			m.set_shader_parameter("recolour",1.0)
		cache[key] = m
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for s in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(s)
			if source != null and source.resource_name == "MI_Trim_Props_Vertex": mesh.set_surface_override_material(s,cache[key])

# The mesh inside a kit model, for drawing many copies in one batch.
static func mesh_of(id: String) -> Mesh:
	var key = "mesh"+id
	if cache.has(key): return cache[key]
	var node = Art.model(id,Vector3.ONE)
	var found: Mesh = null
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		found = mesh.mesh
		break
	node.free()
	cache[key] = found
	return found
