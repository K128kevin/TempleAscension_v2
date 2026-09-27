extends RefCounted
## Every visible solid is an imported mesh. Collision volumes are invisible.
static var scenes: Dictionary = {}
static var materials: Dictionary = {}

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
