extends RefCounted
## The bandits: men and women of the desert in a raider's kit, after their
## concept art (tools/make_bandits.py builds the two figures and their
## clothes). Each bandit's look is drawn from its seed, so the same bandit
## always looks the same:
##   who        "man" or "woman" (which figure)
##   skin       "light" or "dark", `tone` a sun-browned tint over it; `dirt`
##   hair       one of that figure's hairstyles; `hair_colour`; `beard`
##   tunic      the long linen tunic's colour, `red` the dye of its woven
##              bands and of the shawl, cape and brow wrap
##   apron      the ragged cloth over the skirt; `leather` the vest's and
##              straps' hide
##   shawl, cape, headwrap   which of them are worn
const Wardrobe = preload("res://scripts/bandit_wardrobe.gd")
const People = preload("res://scripts/townsperson.gd")

# Madder reds, wine, rust and the odd ochre.
const REDS = [Color(.44,.07,.06),Color(.52,.12,.08),Color(.36,.07,.1),Color(.5,.2,.1),Color(.3,.06,.06),Color(.55,.34,.14)]
const LINENS = [Color(.8,.74,.62),Color(.74,.68,.55),Color(.84,.8,.7),Color(.7,.62,.5)]
const APRONS = [Color(.26,.16,.1),Color(.3,.11,.08),Color(.22,.17,.12),Color(.34,.22,.13)]
const HIDES = [Color(.6,.4,.24),Color(.52,.34,.2),Color(.66,.44,.27)]
const HAIR = {"man":["Hair_SimpleParted","Hair_Buzzed"],"woman":["Hair_Long","Hair_Buns"]}

static func look(seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	var who = "woman" if rng.randf() < .4 else "man"
	var red: Color = REDS[rng.randi() % REDS.size()]
	var shade = rng.randf_range(.04,.16)
	return {
		"who":who,
		"seed":rng.randf_range(0.0,10.0),
		"skin":"dark" if rng.randf() < .75 else "light",
		"tone":Color(rng.randf_range(.86,1.0),rng.randf_range(.76,.9),rng.randf_range(.64,.8)),
		"dirt":rng.randf_range(.35,.75),
		"hair":HAIR[who][rng.randi() % 2],
		"hair_colour":Color(shade,shade*.75,shade*.55),
		"beard":who == "man" and rng.randf() < .75,
		"tunic":LINENS[rng.randi() % LINENS.size()],
		"tunic_wear":rng.randf_range(.55,.7),
		"red":red,
		"apron":APRONS[rng.randi() % APRONS.size()],
		"leather":HIDES[rng.randi() % HIDES.size()],
		"shawl":rng.randf() < .85,
		"cape":rng.randf() < .7,
		"headwrap":rng.randf() < .85,
	}

# The material for one part of a bandit's figure, or null when this bandit
# does not wear it.
static func material(part: String, look: Dictionary) -> Material:
	var cover: Dictionary = Wardrobe.COVER[look.who]
	if part == "Body": return flesh(look,cover)
	if part == "Eyes": return People.shared("eyes")
	if part == "Eyebrows": return hair(look,1 if look.who == "man" else 2)
	if part.begins_with("Hair_"):
		if part != look.hair and not (part == "Hair_Beard" and look.beard): return null
		return hair(look,2 if part in ["Hair_Long","Hair_Buns"] else 1)
	match part:
		"Tunic": return cloth(look,look.tunic,look.tunic_wear,"linen",{"bands":look.red})
		"Apron": return cloth(look,look.apron,.9,"hessian")
		"Sash": return cloth(look,look.red*.85,.4,"hessian")
		"Shawl": return cloth(look,look.red,.5,"linen",{"lattice":look.red*.45}) if look.shawl else null
		"Cape": return cloth(look,look.red*.9,.82,"hessian",{"lattice":look.tunic*.7}) if look.cape else null
		"Headwrap": return cloth(look,look.red,.35,"linen",{"lattice":look.tunic*.8}) if look.headwrap else null
		"Vest": return leather(look,look.leather,{"studs":1.0})
		"Belt": return leather(look,look.leather*.7,{})
		"Strap": return leather(look,look.leather*1.25,{"studs":1.0})
	if part.begins_with("Bracer") or part.begins_with("Bindings"): return leather(look,look.leather*1.1,{"wound":1.0})
	return null

static func flesh(look: Dictionary, cover: Dictionary) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/townsfolk_skin.gdshader")
	m.set_shader_parameter("skin",load("res://assets/textures/skin_%s_%s.jpg" % [look.who,look.skin]))
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("tone",Vector3(look.tone.r,look.tone.g,look.tone.b))
	m.set_shader_parameter("dirt",look.dirt)
	# Under the tunic and vest nothing of the body is drawn.
	var tunic: Array = cover.Tunic
	m.set_shader_parameter("cover",Vector2(tunic[1]+.06,tunic[0]-.03))
	m.set_shader_parameter("sleeve",maxf(0.0,tunic[2]-.05))
	# Sandals: a sole and a strap about the ankle, the toes bare, under the
	# bindings wound up the shin.
	var sandals = ShaderMaterial.new()
	sandals.shader = load("res://assets/shaders/shoes.gdshader")
	sandals.set_shader_parameter("leather",look.leather*.55)
	sandals.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	sandals.set_shader_parameter("top",.06)
	sandals.set_shader_parameter("sandal",1.0)
	m.next_pass = sandals
	return m

static func cloth(look: Dictionary, colour: Color, wear: float, weave: String, woven: Dictionary = {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/cloth.gdshader")
	m.set_shader_parameter("weave",load("res://assets/textures/cloth_%s.jpg" % weave))
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("weave_scale",{"linen":4.0,"hessian":5.0}[weave])
	m.set_shader_parameter("dye",Vector3(colour.r,colour.g,colour.b))
	m.set_shader_parameter("wear",wear)
	m.set_shader_parameter("seed",look.seed)
	for pattern in woven:
		var dye: Color = woven[pattern]
		m.set_shader_parameter(pattern,1.0)
		m.set_shader_parameter("band_dye",Vector3(dye.r,dye.g,dye.b))
	var inside: ShaderMaterial = m.duplicate()
	inside.shader = load("res://assets/shaders/cloth_inside.gdshader")
	m.next_pass = inside
	return m

static func leather(look: Dictionary, colour: Color, options: Dictionary) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/bandit_leather.gdshader")
	m.set_shader_parameter("leather",colour)
	m.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	m.set_shader_parameter("linen",look.tunic*.85)
	m.set_shader_parameter("seed",look.seed)
	for option in options: m.set_shader_parameter(option,options[option])
	return m

static func hair(look: Dictionary, sheet: int) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	if sheet > 0: m.albedo_texture = load("res://assets/textures/hair_%d.jpg" % sheet)
	m.albedo_color = look.hair_colour*2.2
	m.roughness = .6
	m.metallic_specular = .3
	return m
