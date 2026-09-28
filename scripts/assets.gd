extends RefCounted
## Every visible solid is an imported mesh. Collision volumes are invisible.
static var scenes: Dictionary = {}
static var materials: Dictionary = {}
static var target_ring_texture: GradientTexture2D

static func statue_material() -> ShaderMaterial:
	if materials.has("statue"): return materials.statue
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/statue_stone.gdshader")
	m.set_shader_parameter("stone_texture",load("res://assets/textures/statue_marble.png"))
	materials.statue = m
	return m

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
	var texture_name = {"stone":"limestone", "marble":"statue_marble", "armor":"bronze_scales"}.get(kind, "statue_marble")
	m.albedo_texture = load("res://assets/textures/%s.png" % texture_name)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * (1.1 if kind == "armor" else .35)
	if kind in ["armor","gold"]:
		m.metallic = .65
		m.roughness = .4
	if kind == "gold": m.albedo_color = Color(.93,.62,.19)
	materials[key] = m
	return m

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
