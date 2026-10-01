extends RefCounted
## Every visible solid is an imported mesh. Collision volumes are invisible.
static var scenes: Dictionary = {}
static var materials: Dictionary = {}
static var target_ring_texture: GradientTexture2D

# Stone for statues and their gear. `skinned` is for animated statue bodies
# prepared with rest_pose_mesh(), whose stone stays fixed to the body.
static func statue_material(skinned: bool = false) -> ShaderMaterial:
	var key = "statue_skinned" if skinned else "statue"
	if materials.has(key): return materials[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/statue_stone.gdshader")
	m.set_shader_parameter("stone_texture",load("res://assets/textures/statue_marble.png"))
	m.set_shader_parameter("scale_texture",load("res://assets/textures/hero_kit.png"))
	m.set_shader_parameter("rest_pose",skinned)
	materials[key] = m
	return m

static var rest_meshes: Dictionary = {}

# A copy of a skinned mesh carrying its rest-pose positions in CUSTOM0 and
# normals in CUSTOM1, for the stone shader. Made once per mesh.
static func rest_pose_mesh(mesh: ArrayMesh) -> ArrayMesh:
	if rest_meshes.has(mesh): return rest_meshes[mesh]
	var out = ArrayMesh.new()
	out.blend_shape_mode = mesh.blend_shape_mode
	for i in mesh.get_blend_shape_count(): out.add_blend_shape(mesh.get_blend_shape_name(i))
	for s in mesh.get_surface_count():
		var arrays = mesh.surface_get_arrays(s)
		var custom: Array = []
		for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL]:
			var values: PackedVector3Array = arrays[channel]
			var packed = PackedFloat32Array()
			packed.resize(values.size()*4)
			for i in values.size():
				packed[i*4] = values[i].x; packed[i*4+1] = values[i].y; packed[i*4+2] = values[i].z
			custom.append(packed)
		arrays[Mesh.ARRAY_CUSTOM0] = custom[0]
		arrays[Mesh.ARRAY_CUSTOM1] = custom[1]
		var flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		flags |= mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s),arrays,mesh.surface_get_blend_shape_arrays(s),{},flags)
		out.surface_set_material(s,mesh.surface_get_material(s))
	rest_meshes[mesh] = out
	return out

static func quartz_material(tint: Color = Color(.70,.70,.72)) -> ShaderMaterial:
	var key = "quartz" + tint.to_html()
	if materials.has(key): return materials[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/quartz_floor.gdshader")
	m.set_shader_parameter("quartz_color",tint)
	materials[key] = m
	return m

static func material(kind: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key = kind + tint.to_html()
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = .85
	var texture_name = {"stone":"limestone", "marble":"statue_marble", "armor":"bronze_scales", "wood":"wood_planks"}.get(kind, "statue_marble")
	m.albedo_texture = load("res://assets/textures/%s.png" % texture_name)
	m.uv1_triplanar = true
	# Wood is projected in the prop's own unit space: about six planks over its height.
	m.uv1_scale = Vector3.ONE * {"armor":1.1,"wood":1.0}.get(kind,.35)
	if kind in ["armor","gold"]:
		m.metallic = .65
		m.roughness = .4
	if kind == "gold": m.albedo_color = Color(.93,.62,.19)
	materials[key] = m
	return m

# The hero's sword: brass fittings, a dark leather grip and a fullered silver blade.
static func sword_material() -> ShaderMaterial:
	if materials.has("sword"): return materials.sword
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/sword.gdshader")
	materials.sword = m
	return m

# Brown leather for the warrior's boots.
static func leather() -> StandardMaterial3D:
	if materials.has("leather"): return materials.leather
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(.34,.2,.1)
	m.roughness = .72
	materials.leather = m
	return m

# Polished bronze for the warrior's helm, matching his scale armor.
static func bronze() -> StandardMaterial3D:
	if materials.has("bronze"): return materials.bronze
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(.6,.4,.19)
	m.metallic = .8
	m.roughness = .36
	materials.bronze = m
	return m

# Matte woven cloth for hoods and robes, seen from inside as well.
static func cloth(tint: Color) -> StandardMaterial3D:
	var key = "cloth" + tint.to_html()
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = .92
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = m
	return m

# The hero's painted body kit (tools/paint_hero.py); the ranger's has a
# wool tunic in place of the scales.
static func hero_kit(hero_class: String) -> StandardMaterial3D:
	var key = "hero_kit_ranger" if hero_class == "ranger" else "hero_kit"
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s.png" % key)
	m.roughness = .65
	materials[key] = m
	return m

# Worn grey steel for the warrior's round shield.
static func metal() -> StandardMaterial3D:
	if materials.has("metal"): return materials.metal
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(.5,.52,.55)
	m.metallic = .85
	m.roughness = .38
	materials.metal = m
	return m

# A .66m arrow from the KayKit model, slimmed from its chunky .118m width to
# a real arrow's profile. The prepared model lies along its local Z, centred,
# its head toward -Z and its nock and fletching toward +Z.
const ARROW_SIZE = Vector3(.05,.045,.66)

static func model(id: String, dimensions: Vector3, mat: Material = null) -> Node3D:
	var path = "res://assets/models/props/%s.glb" % id
	if not scenes.has(path): scenes[path] = load(path)
	var node: Node3D = scenes[path].instantiate()
	node.scale = dimensions
	if mat:
		for mesh in node.find_children("*", "MeshInstance3D", true, false): mesh.material_override = mat
	return node

static func seal(diameter: float, color: Color) -> Sprite3D:
	var s = Sprite3D.new()
	s.texture = load("res://assets/textures/seal.png")
	s.pixel_size = diameter / s.texture.get_width()
	s.rotation.x = -PI / 2
	s.modulate = color
	s.no_depth_test = false
	s.shaded = false
	return s

static func target_ring() -> Sprite3D:
	if target_ring_texture == null:
		target_ring_texture = GradientTexture2D.new()
		target_ring_texture.width = 128; target_ring_texture.height = 128
		target_ring_texture.fill = GradientTexture2D.FILL_RADIAL
		target_ring_texture.fill_from = Vector2(.5,.5); target_ring_texture.fill_to = Vector2(1,.5)
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0,.89,.93,.97,1])
		gradient.colors = PackedColorArray([Color(.95,.035,.035,0),Color(.95,.035,.035,0),Color(.95,.035,.035,.92),Color(.95,.035,.035,.92),Color(.95,.035,.035,0)])
		target_ring_texture.gradient = gradient
	var ring = Sprite3D.new()
	ring.texture = target_ring_texture
	ring.pixel_size = 1.8/128
	ring.rotation.x = -PI/2
	ring.shaded = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	return ring
