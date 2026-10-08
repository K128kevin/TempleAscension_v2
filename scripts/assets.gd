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

# One part of a wizard's staff (assets/shaders/staff.gdshader), in the colours
# the item's look gives it (`tint`: its metal; `crystal`).
const STAFF_PARTS = {"Metal":0,"Crystal":1,"Leather":2,"Wood":3,"Bronze":4}
static func staff_part(part_name: String, look: Dictionary) -> ShaderMaterial:
	var part: int = STAFF_PARTS.get(part_name.get_slice(".",0).get_slice("_",0),0)
	var key = "staffpart%d%s%s" % [part,look.get("tint",Color.WHITE).to_html(),look.get("crystal",Color.WHITE).to_html()]
	if materials.has(key): return materials[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/staff.gdshader")
	m.set_shader_parameter("part",part)
	if look.has("tint"): m.set_shader_parameter("metal",look.tint)
	if look.has("crystal"): m.set_shader_parameter("crystal",look.crystal)
	materials[key] = m
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

# --- Items (scripts/items.gd) -----------------------------------------------------

const Items = preload("res://scripts/items.gd")
# Where a hero's kit divides between the equipment slots, by class, at rest
# (assets/shaders/hero_body.gdshader): how high what is on his feet reaches,
# where what is on his legs ends (the skirts of the ranger's tunic, below
# his belt, go with his trousers), and how far out along the arm what is on
# his hands begins.
# (`only_from`: how far down what is on his legs comes, pictured by itself:
# the warrior's kilt ends above his knees.)
const BODY_PARTS = {"warrior":{"feet_top":.17,"waist":1.035,"arm_from":.47,"only_from":.62},"ranger":{"feet_top":.5,"waist":1.0,"arm_from":.47,"only_from":0.0},"wizard":{"feet_top":.36,"waist":1.0,"arm_from":.5,"only_from":0.0}}
const BODY_SLOTS = ["chest","legs","feet","hands"]
# The pieces of each class's kit that are meshes of their own, by slot (the
# rest is painted on the body).
const PIECES = {
	"warrior":{"head":["HeroHelmet"],"chest":["HeroArmor"],"legs":["HeroKilt","HeroBelt"],"feet":[],"hands":["HeroBracers"]},
	"ranger":{"head":["RangerCloak","RangerBrooch"],"chest":["RangerBelt","RangerPouch"],"legs":[],"feet":["RangerBoots","RangerBootsFeet"],"hands":["RangerBracers"]},
	"wizard":{"head":["WizardHood"],"chest":["WizardRobe","WizardRobeSkirt","WizardSash","WizardSashEnd0","WizardSashEnd1"],"legs":[],"feet":["WizardBoots","WizardBootsFeet"],"hands":["WizardBracers"]}}
# The class that wears each weight of armor.
const WEARER = {"heavy":"warrior","medium":"ranger","light":"wizard"}

# A hero's body drawn part by part, kit or skin (a new material each time:
# the caller sets which parts are bare and how each is coloured). `shell`:
# for a raised piece painted with the body.
static func hero_body(hero_class: String, shell: bool = false) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/hero_body.gdshader")
	var key = "hero_kit_"+hero_class
	m.set_shader_parameter("kit",load("res://assets/textures/%s.png" % key))
	m.set_shader_parameter("kit_normal",load("res://assets/textures/%s_normal.png" % key))
	m.set_shader_parameter("kit_rough",load("res://assets/textures/%s_rough.png" % key))
	m.set_shader_parameter("skin",load("res://assets/models/character/warrior_T_Superhero_Male_Dark.png"))
	m.set_shader_parameter("skin_normal",load("res://assets/models/character/warrior_T_Superhero_Male_Normal.png"))
	m.set_shader_parameter("skin_rough",load("res://assets/models/character/warrior_T_Superhero_Male_Roughness.png"))
	m.set_shader_parameter("shell",shell)
	m.set_shader_parameter("rest_pose",not shell)
	if hero_class in ["ranger","wizard"]: m.set_shader_parameter("specular",.25)
	for key_name in BODY_PARTS[hero_class]: m.set_shader_parameter(key_name,BODY_PARTS[hero_class][key_name])
	return m

# A raised piece of a class's kit in another make's colour.
static func kit_shell(hero_class: String, tint: Color) -> ShaderMaterial:
	var key = "kit_shell_%s%s" % [hero_class,tint.to_html()]
	if materials.has(key): return materials[key]
	var m = hero_body(hero_class,true)
	m.set_shader_parameter("tint_chest",tint)
	m.set_shader_parameter("recolor",Vector4(1,0,0,0))
	materials[key] = m
	return m

# One of the game's shader materials in another make's colour.
static func recolored(source: ShaderMaterial, tint: Color) -> ShaderMaterial:
	var key = "recolored%d%s" % [source.get_instance_id(),tint.to_html()]
	if materials.has(key): return materials[key]
	var m: ShaderMaterial = source.duplicate()
	m.set_shader_parameter("tint",tint)
	m.set_shader_parameter("recolor",1.0)
	materials[key] = m
	return m

# The finish of a weapon or shield as an item has it (its `look`); null leaves
# the model its own.
static func finish(look: Dictionary) -> Material:
	var made: Material = null
	match look.get("finish","own"):
		"sword": made = sword_material()
		"sica": made = sica_material()
		"dagger": made = dagger_material()
		"bow": made = bow_wood()
		"lion": made = gladiator_shield()
		"arms": made = arms_material(look.get("metal_from",.5))
		"staff":
			made = wizard_staff()
			if look.has("tint") or look.has("crystal"):
				var key = "staff%s%s" % [look.get("tint",Color.WHITE).to_html(),look.get("crystal",Color.WHITE).to_html()]
				if not materials.has(key):
					var m: ShaderMaterial = made.duplicate()
					if look.has("tint"): m.set_shader_parameter("silver",look.tint)
					if look.has("crystal"): m.set_shader_parameter("crystal",look.crystal)
					materials[key] = m
				return materials[key]
	if made is ShaderMaterial and look.has("tint") and look.finish != "arms": return recolored(made,look.tint)
	return made

# A weapon's or shield's model as an item has it, standing along +Y from its
# butt, at its true size.
static func weapon_model(look: Dictionary) -> Node3D:
	var node: Node3D = model(look.model,look.size,finish(look))
	if look.get("finish","") == "parts":
		# A wizard's staff: metal, crystal, leather, wood and bronze by its
		# parts (tools/make_staffs.py).
		for mesh in node.find_children("*","MeshInstance3D",true,false): mesh.material_override = staff_part(String(mesh.name),look)
	if look.get("finish","") == "hasta":
		# The legionary's spear: iron, ash and hide by its parts (scripts/town_guard.gd).
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var part = ShaderMaterial.new()
			part.shader = load("res://assets/shaders/spear.gdshader")
			part.set_shader_parameter("part",{"Head":0,"Socket":0,"Rivet":0,"Butt":0,"Shaft":1,"Grip":2}.get(String(mesh.name),1))
			part.set_shader_parameter("blade",mesh.name == "Head")
			mesh.material_override = part
	return node

# A weapon as it is held: its haft in the fist and its edge leading the cut.
# A model's haft is taken to run up its middle, its edge to either side (its
# X), as a sword's does, and the one-handed swings lead with the model's -Z.
# A look whose model is otherwise says so: "haft", where across the model
# (its X, in the model's own units) the haft stands, and "turn", the angle
# about the haft that brings its edge round to lead. The node is sized as the
# look is (its scale), like weapon_model's.
static func held_model(look: Dictionary) -> Node3D:
	var made: Node3D = weapon_model(look)
	if not look.has("haft") and not look.has("turn"): return made
	var node = Node3D.new()
	node.scale = look.size
	made.scale = Vector3.ONE
	node.add_child(made)
	# (Turned as it is sized, not as the unit model is: the node's scale is
	# undone about the turn.)
	var sized := Basis.from_scale(look.size)
	var turned: Basis = sized.inverse()*Basis(Vector3.UP,look.get("turn",0.0))*sized
	made.transform = Transform3D(turned,turned*Vector3(-look.get("haft",0.0),0,0))
	return node

# The hero model's meshes by name, kept to make loose pieces from.
static var hero_meshes: Dictionary = {}
static func hero_mesh(mesh_name: String) -> Mesh:
	if hero_meshes.is_empty():
		var rig: Node = load("res://assets/models/character/warrior.glb").instantiate()
		for mesh in rig.find_children("*","MeshInstance3D",true,false): hero_meshes[String(mesh.name)] = mesh.mesh
		rig.free()
	return hero_meshes.get(mesh_name)

# The material of one mesh of a class's kit, as Visual dresses it: `tint` (or
# null) is another make's colour.
static func piece_material(mesh_name: String, hero_class: String, tint = null) -> Material:
	if "Helmet" in mesh_name or "Kilt" in mesh_name:
		var key = "piece%s" % mesh_name
		if not materials.has(key):
			var m = ShaderMaterial.new()
			m.shader = load("res://assets/shaders/%s.gdshader" % ("gladiator_helm" if "Helmet" in mesh_name else "kilt"))
			m.set_shader_parameter("rest_pose",true)
			if "Kilt" in mesh_name: m.set_shader_parameter("fold_from",.03)
			materials[key] = m
		return materials[key] if tint == null else recolored(materials[key],tint)
	if "Cloak" in mesh_name or "Hood" in mesh_name or "Robe" in mesh_name:
		var colour: Color = tint if tint != null else (Color(.1,.19,.1) if "Cloak" in mesh_name else Color(.13,.16,.27))
		var key = "piece%s%s" % [mesh_name,colour.to_html()]
		if not materials.has(key):
			var m = ShaderMaterial.new()
			m.shader = load("res://assets/shaders/cloak.gdshader")
			m.set_shader_parameter("cloth_color",colour)
			m.set_shader_parameter("rest_pose",true)
			m.set_shader_parameter("tatter",1.0 if "Cloak" in mesh_name else .35)
			m.set_shader_parameter("hem_height",.3 if "Cloak" in mesh_name else (.14 if "Robe" in mesh_name else -1.0))
			materials[key] = m
		return materials[key]
	if mesh_name.begins_with("WizardSash"): return two_sided(leather(),Color(.62,.55,.5))
	if "Pouch" in mesh_name: return leather()
	if "Brooch" in mesh_name: return bronze()
	return hero_kit(hero_class) if tint == null else kit_shell(hero_class,tint)

# An item as a thing by itself (lying where it fell, or pictured in the
# inventory): a weapon's or shield's model, or the pieces of the kit an
# armor item is (and, where it is only painted on the body, that part of the
# body's surface). It stands as it is worn or held, its foot at the origin;
# `bounds` (metadata) is the box it fills.
static func item_model(id: String) -> Node3D:
	var item: Dictionary = Items.get_item(id)
	var look: Dictionary = item.get("look",{})
	if item.slot in ["weapon","shield"]:
		var held: Node3D = weapon_model(look)
		var tall: float = Items.length(look)
		held.set_meta("bounds",AABB(Vector3(-look.size.x*.5,0,-look.size.z*.5) if look.size != Vector3.ONE else Vector3(-.05,0,-.05),Vector3(look.size.x,tall,look.size.z) if look.size != Vector3.ONE else Vector3(.1,tall,.1)))
		return held
	var hero_class: String = WEARER[item.weight]
	var tint = look.get("tint")
	var root = Node3D.new()
	var box = AABB()
	var first = true
	var names: Array = PIECES[hero_class][item.slot].duplicate()
	# (The cloak's brooch and the tunic's pouch are too small to stand for it.)
	names = names.filter(func(n): return not ("Brooch" in n or "Pouch" in n))
	for mesh_name in names:
		var mesh: Mesh = hero_mesh(mesh_name)
		if mesh == null: continue
		var piece = MeshInstance3D.new()
		piece.mesh = rest_pose_mesh(mesh) if mesh is ArrayMesh else mesh
		piece.material_override = piece_material(mesh_name,hero_class,tint)
		if item.slot == "hands":
			# One of the pair (they are made on arms held wide apart).
			var one: ShaderMaterial = hero_body(hero_class,true)
			one.set_shader_parameter("rest_pose",true)
			one.set_shader_parameter("keep_side",1.0)
			if tint != null:
				one.set_shader_parameter("tint_chest",tint)
				one.set_shader_parameter("recolor",Vector4(1,0,0,0))
			piece.material_override = one
		root.add_child(piece)
		box = piece.get_aabb() if first else box.merge(piece.get_aabb())
		first = false
	if item.slot in BODY_SLOTS and (first or item.slot in ["chest","legs"]):
		# Painted on the body: that part of the body's own surface.
		var body = MeshInstance3D.new()
		var mesh: Mesh = hero_mesh("SuperHero_Male")
		body.mesh = rest_pose_mesh(mesh)
		var skin: ShaderMaterial = hero_body(hero_class)
		var slot_index: int = BODY_SLOTS.find(item.slot)
		skin.set_shader_parameter("only",slot_index)
		if tint != null:
			skin.set_shader_parameter("tint_"+item.slot,tint)
			var which = Vector4.ZERO
			which[slot_index] = 1.0
			skin.set_shader_parameter("recolor",which)
		body.material_override = skin
		root.add_child(body)
		var parts: Dictionary = BODY_PARTS[hero_class]
		var region: AABB = {"chest":AABB(Vector3(-parts.arm_from,parts.waist,-.2),Vector3(parts.arm_from*2,1.5-parts.waist,.4)),"legs":AABB(Vector3(-.25,parts.feet_top,-.2),Vector3(.5,parts.waist-parts.feet_top,.4)),
			"feet":AABB(Vector3(-.2,0,-.15),Vector3(.4,parts.feet_top,.32)),"hands":AABB(Vector3(-.93,1.3,-.1),Vector3(1.86,.2,.2))}[item.slot]
		box = region if first else box.merge(region)
	if item.slot == "hands": box = AABB(Vector3(BODY_PARTS[hero_class].arm_from-.04,1.34,-.1),Vector3(.3,.16,.2))
	root.set_meta("bounds",box)
	return root

# An item as it lies on the ground: weapons, shields, and what is worn on the
# body flat on their backs; a helm, boots and a bracer standing. Its middle
# is over the origin and its underside on the ground.
static func laid(id: String) -> Node3D:
	var item: Dictionary = Items.get_item(id)
	var thing: Node3D = item_model(id)
	var box: AABB = thing.get_meta("bounds")
	var flat: bool = item.slot in ["weapon","shield","chest","legs"] or (item.slot == "head" and item.weight != "heavy")
	var turn: Basis = Basis(Vector3.RIGHT,-PI/2) if flat else Basis.IDENTITY
	var lying: AABB = Transform3D(turn,Vector3.ZERO)*box
	var holder = Node3D.new()
	holder.add_child(thing)
	thing.transform = Transform3D(turn*thing.basis,-Vector3(lying.get_center().x,lying.position.y-.01,lying.get_center().z))
	return holder
