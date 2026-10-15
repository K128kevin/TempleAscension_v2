extends RefCounted
## The desert floor seen from the temple's terraces and summit (scripts/
## temple.gd setup_desert): the same photographed sand as outside (the
## overworld's ground shader, with nothing painted on it), far below at the
## building's foot, strewn as the desert outside is (scripts/world_desert.gd)
## with dry grass, loose stones, shrubs, agaves, a few boulders and dead
## trees, by moonlight.
const Kit = preload("res://scripts/world_art.gd")
const Art = preload("res://scripts/assets.gd")
const ROCKS = ["boulder_a","boulder_b","boulder_c","boulder_d"]
const STONES = ["stone_a","stone_b","stone_c"]
const ROCK_TINTS = [Color(1.06,.98,.9),Color(.9,.84,.78)]
# How far the ground reaches each way from the building's middle: past
# everything the camera sees from any terrace at any zoom.
const REACH = 240.0

# The ground, `depth` metres below the floor, round `middle` (the building's
# middle), with what lies on it; every surface on `layers`. `keep` is the
# building's footprint, where nothing is strewn.
static func build(middle: Vector3, depth: float, keep: Rect2, layers: int) -> Node3D:
	var root = Node3D.new()
	root.name = "DesertBelowTerrace"
	root.position = Vector3(middle.x,-depth,middle.z)
	var sheet = MeshInstance3D.new()
	sheet.name = "Sand"
	var plane = PlaneMesh.new()
	plane.size = Vector2.ONE*REACH*2.0
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	sheet.mesh = plane
	sheet.material_override = sand()
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.layers = layers
	root.add_child(sheet)
	strew(root,middle,keep,layers)
	return root

static func sand() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/desert_ground.gdshader")
	# Nothing painted: no paving, track, shade or water.
	var blank = Image.create(1,1,false,Image.FORMAT_RGBA8)
	blank.fill(Color(0,0,0,0))
	material.set_shader_parameter("control",ImageTexture.create_from_image(blank))
	var still = Image.create(1,1,false,Image.FORMAT_RG8)
	still.fill(Color(.5,.5,0))
	material.set_shader_parameter("flow_map",ImageTexture.create_from_image(still))
	material.set_shader_parameter("map_origin",Vector2(-1.0e6,-1.0e6))
	material.set_shader_parameter("map_size",Vector2.ONE)
	material.set_shader_parameter("stone",load("res://assets/textures/limestone.png"))
	for sheet in ["sand_fine","sand_fine_normal","sand_gravel","sand_gravel_normal"]:
		material.set_shader_parameter(sheet,load("res://assets/textures/%s.jpg" % sheet))
	var grain = FastNoiseLite.new()
	grain.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	grain.frequency = .125
	grain.fractal_type = FastNoiseLite.FRACTAL_NONE
	grain.seed = 11
	var image_noise = grain.get_seamless_image(512,512)
	image_noise.generate_mipmaps()
	material.set_shader_parameter("noise_map",ImageTexture.create_from_image(image_noise))
	return material

# Growth and stones in patches, as on the open desert outside.
static func strew(root: Node3D, middle: Vector3, keep: Rect2, layers: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 6113
	var noise = FastNoiseLite.new()
	noise.seed = 20
	noise.frequency = .01
	var batches: Dictionary = {}
	var grass: StandardMaterial3D = Kit.shared("Grass").duplicate()
	grass.albedo_color = Color(.86,.70,.42)
	var trees: Array = []
	for i in 20000:
		var at = Vector3(rng.randf_range(-REACH,REACH),0,rng.randf_range(-REACH,REACH))*.92
		if keep.grow(2.0).has_point(Vector2(middle.x+at.x,middle.z+at.z)): continue
		var patch = noise.get_noise_2d(at.x*4.0,at.z*4.0)
		var roll = rng.randf()
		if roll < .5:
			if patch > -.05: add(batches,"dry_grass",grass,Kit.sized("dry_grass",rng.randf_range(.45,.95)),at,rng)
		elif roll < .84:
			var id: String = STONES[rng.randi_range(0,2)]
			add(batches,id,Kit.rock(id,ROCK_TINTS[rng.randi_range(0,1)],.3),Kit.SIZE[id]*rng.randf_range(1.6,4.2),at+Vector3.DOWN*.03,rng)
		elif roll < .9:
			if patch > .05:
				if rng.randf() < .45:
					var id = "shrub_a" if rng.randf() < .5 else "shrub_b"
					add(batches,id,Kit.shared("shrub_02"),Kit.sized(id,rng.randf_range(.7,1.25)),at,rng)
				else: add(batches,"scrub",Kit.shared("wild_rooibos_bush"),Kit.sized("scrub",rng.randf_range(.35,.6)),at,rng)
		elif roll < .97:
			if patch > -.1: add(batches,"agave",Kit.shared("Leaves"),Kit.sized("agave",rng.randf_range(.6,1.2)),at,rng)
		elif roll < .988:
			var id: String = ROCKS[rng.randi_range(0,3)]
			var width = rng.randf_range(1.6,4.6)
			add(batches,id,Kit.rock(id,ROCK_TINTS[rng.randi_range(0,1)]),Vector3(width,width*rng.randf_range(.45,.8),width*rng.randf_range(.8,1.2)),at+Vector3.DOWN*width*.08,rng)
		elif roll < .9935:
			trees.append(at)
	for group in batches.values():
		var copies = MultiMesh.new()
		copies.transform_format = MultiMesh.TRANSFORM_3D
		copies.mesh = Kit.mesh_of(group.id)
		copies.instance_count = group.transforms.size()
		for i in group.transforms.size(): copies.set_instance_transform(i,group.transforms[i])
		var node = MultiMeshInstance3D.new()
		node.multimesh = copies
		node.material_override = group.material
		node.layers = layers
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	for at in trees:
		var id = "dead_tree" if rng.randf() < .7 else "tree"
		var tree = Art.model(id,Kit.sized(id,rng.randf_range(3.2,5.2)))
		Kit.dress(tree)
		tree.position = at
		tree.rotation.y = rng.randf_range(0,TAU)
		for mesh in tree.find_children("*","MeshInstance3D",true,false):
			mesh.layers = layers
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tree)

static func add(batches: Dictionary, id: String, material: Material, size: Vector3, at: Vector3, rng: RandomNumberGenerator) -> void:
	var key = "%s:%d" % [id,material.get_instance_id()]
	if not batches.has(key): batches[key] = {"id":id,"material":material,"transforms":[]}
	var basis = Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis.from_scale(size)
	batches[key].transforms.append(Transform3D(basis,at))
