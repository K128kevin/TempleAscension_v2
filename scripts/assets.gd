extends RefCounted
## Every visible solid is an imported mesh. Collision volumes are invisible.
static var scenes: Dictionary = {}
static var materials: Dictionary = {}
static var target_ring_texture: GradientTexture2D

# Stone for statues and their gear. `skinned` is for animated statue bodies
# prepared with rest_pose_mesh(), whose stone stays fixed to the body.
# `kit` (a hero class) carves a statue in that hero's likeness: the body's
# own relief and the hero's kit, on the surfaces that carry the body's UVs.
static func statue_material(skinned: bool = false, kit: String = "") -> ShaderMaterial:
	var key = ("statue_skinned" if skinned else "statue") + kit
	if materials.has(key): return materials[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/statue_stone.gdshader")
	m.set_shader_parameter("stone_texture",load("res://assets/textures/statue_marble.png"))
	m.set_shader_parameter("scale_texture",load("res://assets/textures/hero_kit.png"))
	m.set_shader_parameter("rest_pose",skinned)
	if kit == "lion":
		# The lion's face is a sculpted mask (tools/make_lion.py): its own
		# normal map carries the finest work, and it wears no kit.
		m.set_shader_parameter("body_detail",1.0)
		m.set_shader_parameter("body_normal",load("res://assets/textures/lion_normal.png"))
		m.set_shader_parameter("kit_height",load("res://assets/textures/flat_height.png"))
	elif kit != "":
		m.set_shader_parameter("body_detail",1.0)
		m.set_shader_parameter("body_normal",load("res://assets/models/character/warrior_T_Superhero_Male_Normal.png"))
		m.set_shader_parameter("kit_height",load("res://assets/textures/hero_kit_%s_height.png" % kit))
	materials[key] = m
	return m

# The ranger's dagger: the sword's finish, on a blade with a short grip and a
# heavy guard.
static func dagger_material() -> ShaderMaterial:
	if materials.has("dagger"): return materials.dagger
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/sword.gdshader")
	m.set_shader_parameter("POMMEL_TOP",.1)
	m.set_shader_parameter("GRIP_TOP",.3)
	m.set_shader_parameter("GUARD_TOP",.42)
	materials.dagger = m
	return m

# Arms hung in the smithy: steel from `metal_from` of their length up, wood below.
static func arms_material(metal_from: float) -> ShaderMaterial:
	var key = "arms%.2f" % metal_from
	if materials.has(key): return materials[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/arms.gdshader")
	m.set_shader_parameter("metal_from",metal_from)
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

# Grey split-face sandstone in the French Versailles pattern, for the open-air terraces.
static func slate_material() -> ShaderMaterial:
	if materials.has("slate"): return materials.slate
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/slate_paving.gdshader")
	materials.slate = m
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

# A stone material projected at a fixed size in the world rather than per
# model, for walls of very different proportions: as dense as on a full-height
# wall (where one 0.35 tile spans its 3.2m).
static func world_stone(source: StandardMaterial3D) -> StandardMaterial3D:
	var key = "world" + str(source.get_instance_id())
	if materials.has(key): return materials[key]
	var m: StandardMaterial3D = source.duplicate()
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*(.35/3.2)
	materials[key] = m
	return m

# The hero's sword: brass fittings, a dark leather grip and a fullered silver blade.
# The bandits' sica: the sword's finish, its fuller following the curve.
static func sica_material() -> ShaderMaterial:
	if materials.has("sica"): return materials.sica
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/sword.gdshader")
	m.set_shader_parameter("SWEEP",1.1)
	materials.sica = m
	return m

static func sword_material() -> ShaderMaterial:
	if materials.has("sword"): return materials.sword
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/sword.gdshader")
	materials.sword = m
	return m

# The ranger's yew longbow (assets/shaders/bow_wood.gdshader), over the
# bow model's own palette.
static func bow_wood() -> ShaderMaterial:
	if materials.has("bow_wood"): return materials.bow_wood
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/bow_wood.gdshader")
	m.set_shader_parameter("palette",load("res://assets/models/props/bow_Diffuse_palette_2.jpg"))
	materials.bow_wood = m
	return m

# Brown leather for the warrior's boots.
static func leather() -> StandardMaterial3D:
	if materials.has("leather"): return materials.leather
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(.34,.2,.1)
	# Worn, matte leather.
	m.roughness = .88
	m.metallic_specular = .3
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
	var key = "hero_kit_" + hero_class
	if not ResourceLoader.exists("res://assets/textures/%s.png" % key): key = "hero_kit"
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s.png" % key)
	m.roughness = .65
	# Each hero's kit is painted in full (tools/paint_kits.py): with its relief
	# in a normal map, and leather, cloth and steel each their own sheen.
	if key != "hero_kit":
		m.normal_enabled = true
		m.normal_texture = load("res://assets/textures/%s_normal.png" % key)
		m.normal_scale = 1.0
		m.roughness = 1.0
		m.roughness_texture = load("res://assets/textures/%s_rough.png" % key)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		# Steel shines as metal (the painter marks it in the roughness map's
		# green channel).
		# Half metal: the scenes have no reflections for full metal to show,
		# which leaves it near black.
		m.metallic = .45
		m.metallic_texture = load("res://assets/textures/%s_rough.png" % key)
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		# The ranger's and the wizard's worn cloth and leather catch little light.
		if hero_class in ["ranger","wizard"]: m.metallic_specular = .25
	materials[key] = m
	return m

# The warrior's round shield, worked in steel (assets/shaders/gladiator_shield.gdshader).
static func gladiator_shield() -> ShaderMaterial:
	if materials.has("gladiator_shield"): return materials.gladiator_shield
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/gladiator_shield.gdshader")
	materials.gladiator_shield = m
	return m

# The wizard's twisted silver staff and crystal (assets/shaders/wizard_staff.gdshader).
static func wizard_staff() -> ShaderMaterial:
	if materials.has("wizard_staff"): return materials.wizard_staff
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/wizard_staff.gdshader")
	materials.wizard_staff = m
	return m

# The ranger's quiver (assets/shaders/quiver.gdshader).
static func quiver() -> ShaderMaterial:
	if materials.has("quiver"): return materials.quiver
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/quiver.gdshader")
	materials.quiver = m
	return m

# A bladed prop in its sheath (assets/shaders/sheathed.gdshader).
static func sheathed(source: Material) -> Material:
	if not source is BaseMaterial3D or source.albedo_texture == null: return source
	var key = "sheathed%d" % source.get_instance_id()
	if materials.has(key): return materials[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/sheathed.gdshader")
	m.set_shader_parameter("albedo_texture",source.albedo_texture)
	materials[key] = m
	return m

# An imported prop's own material, darkened and roughened by `shade`.
static func weathered(source: Material, shade: float) -> Material:
	if not source is BaseMaterial3D: return source
	var key = "weathered%d:%f" % [source.get_instance_id(),shade]
	if materials.has(key): return materials[key]
	var m: BaseMaterial3D = source.duplicate()
	m.albedo_color = m.albedo_color*Color(shade,shade,shade,1)
	m.roughness = maxf(m.roughness,.75)
	materials[key] = m
	return m

# A material drawn from both sides, for single sheets (sashes, straps), its
# colour multiplied by `tint`.
static func two_sided(source: StandardMaterial3D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key = "two_sided%d%s" % [source.get_instance_id(),tint.to_html()]
	if materials.has(key): return materials[key]
	var m: StandardMaterial3D = source.duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = m.albedo_color*tint
	materials[key] = m
	return m

# Hair and beards: a dark matte colour with a soft sheen.
static func hair(tint: Color) -> StandardMaterial3D:
	var key = "hair" + tint.to_html()
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = .7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
