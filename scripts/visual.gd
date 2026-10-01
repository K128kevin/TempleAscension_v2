extends Node3D
const Art = preload("res://scripts/assets.gd")
const Motion = preload("res://scripts/combat_animation.gd")
const Vfx = preload("res://scripts/vfx.gd")
# A slain statue crumbles, as in the original game: the body collapses into a
# rubble pile while stone chips burst out and fall around it.
const CRUMBLE_TIME = .7
const CHIPS = 12
var crumbling = -1.0
var crumble_size = 1.0
var rubble: Node3D
var chips: Array = []
var dust: CPUParticles3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var clips: Dictionary = {}
var state = ""
var dead = false
var equipment: Node3D
var skin_meshes: Array = []
var rig: Node3D
var weapon_item: Node3D
var weapon_kind = ""
var weapon_size = Vector3.ONE
var nocked_arrow: Node3D
var bow_strings: Array = []
var shield_attachment: BoneAttachment3D
var shield_item: Node3D
var is_stone = false
var animation_delay = 0.0
var pending_animation_time = 0.0
var locomotion_rate = 1.0
var enemy_kind = ""
# Remaining time of a hit reaction; locomotion waits for it to finish.
var reaction_time = 0.0
# The warrior's round grey metal shield, strapped flat to the outside of the
# left forearm so it follows every pose.
const SHIELD_SIZE = Vector3(.66,.66,.12)
const SHIELD_CENTER = Vector3(0,.14,-.135)
# The gladiator's tall curved scutum, strapped over the same forearm.
const SCUTUM_SIZE = Vector3(.58,.95,.2)
# Measured from the SpearShieldIdle stance: upright, facing forward and 20° out
# to the left, centred just in front of the forearm (forearm bone space).
const SCUTUM_CENTER = Vector3(-.072,.224,-.063)
const SCUTUM_ROTATION = Quaternion(.753,-.397,-.466,-.238)
# The centurion's tower shield: the same curved shield, taller and carried
# lower so it covers shin to chin.
const TOWER_SIZE = Vector3(.68,1.3,.24)
const TOWER_DROP = .12
const SHIELD_BEARERS = ["gladiator","centurion"]
const ORACLE_STAFF_SIZE = Vector3(.13,1.9,.13)
const BOSS_SWORD_SCALE = 1.35
# Where the hand holds the Oracle's staff, as a share of its length from the foot.
const ORACLE_GRIP = .45
# The staff's lean through OracleCast (phase, up, forward): upright while the
# flame forms, drawn back, swung out to point ahead at the release, upright again.
const ORACLE_STAFF_KEYS = [[0.0,1.0,.08],[.66,1.0,.1],[.76,.75,-.65],[.8,.3,1.0],[.86,.45,.9],[1.0,1.0,.08]]
var oracle_flame: Node3D
var oracle_flame_light: OmniLight3D
var oracle_flame_parts: Array = []
const BOW_GRIP = Vector3(-.42,.51,0)
# Shooting, the string is drawn to the jaw: this many times the bow model's own
# .36m draw (tools/import_combat.py BOW_FULL_DRAW).
const BOW_FULL_DRAW = 1.2

# `hero_class` picks the hero's kit: the warrior's scale armor and bronze
# helm, the ranger's leather jerkin and hood, or the wizard's robe and hood.
# Each statue is carved in the likeness of a hero of its class, with his kit
# (tools/paint_kits.py) cut into the stone; the lion stays plain.
const STATUE_KITS = {"gladiator":"warrior","centurion":"warrior","boss":"warrior","archer":"ranger","wizard":"wizard"}

func setup(stone: bool, _tint: Color, weapon: String, stature: float = 1.0, enemy_kind: String = "", hero_class: String = "warrior") -> void:
	is_stone = stone
	self.enemy_kind = enemy_kind
	var character = "guardian_%s" % enemy_kind if stone and enemy_kind in ["gladiator","archer","centurion","wizard","boss"] else ("guardian" if stone else "warrior")
	rig = load("res://assets/models/character/%s.glb" % character).instantiate()
	# The supplied Godot rig faces +Z, matching Actor.forward().
	rig.rotation.y = 0
	rig.scale = Vector3.ONE * stature
	add_child(rig)
	animator = rig.find_children("*", "AnimationPlayer", true, false)[0]
	# Actor.tick advances poses on the same clock as wind-up and recovery.
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		skin_meshes.append(mesh)
		if stone:
			if mesh.skin != null and mesh.mesh is ArrayMesh:
				mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
				mesh.material_override = Art.statue_material(true,STATUE_KITS.get(enemy_kind,""))
			else: mesh.material_override = Art.statue_material()
		elif "HeroBoots" in mesh.name:
			# Every hero now has his own: the ranger's and the wizard's boots,
			# the warrior's sandals (painted on his feet).
			mesh.visible = false
		elif mesh.name.begins_with("HeroGreaves") or mesh.name.begins_with("HeroBracers") or mesh.name.begins_with("HeroBelt"):
			# The warrior's raised shells, painted with him (tools/paint_kits.py).
			mesh.visible = hero_class == "warrior"
			mesh.material_override = Art.hero_kit("warrior")
		elif mesh.name.begins_with("HeroKilt"):
			# Hanging pteruges that swing and fold over his legs.
			mesh.visible = hero_class == "warrior"
			var kilt = ShaderMaterial.new()
			kilt.shader = load("res://assets/shaders/kilt.gdshader")
			if mesh.skin != null and mesh.mesh is ArrayMesh:
				mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
				kilt.set_shader_parameter("rest_pose",true)
			mesh.material_override = kilt
			if hero_class == "warrior": cloak_mesh = mesh
		elif mesh.name.begins_with("WizardSashEnd") or mesh.name == "WizardSash":
			# Single sheets of dark leather, seen from both sides.
			mesh.visible = hero_class == "wizard"
			mesh.material_override = Art.two_sided(Art.leather(),Color(.62,.55,.5))
		elif mesh.name.begins_with("WizardBoots") or mesh.name.begins_with("WizardBracers") or mesh.name.begins_with("WizardSash"):
			mesh.visible = hero_class == "wizard"
			mesh.material_override = Art.hero_kit("wizard")
		elif "RangerBoots" in mesh.name or "RangerBracers" in mesh.name or "RangerBelt" in mesh.name:
			# Raised shells of the body, painted with it (tools/paint_kits.py).
			mesh.visible = hero_class == "ranger"
			mesh.material_override = Art.hero_kit("ranger")
		elif mesh.name.begins_with("RangerBeard"):
			mesh.visible = hero_class == "ranger"
			mesh.material_override = Art.hair(Color(.13,.09,.06))
		elif mesh.name.begins_with("RangerPouch"):
			mesh.visible = hero_class == "ranger"
			mesh.material_override = Art.leather()
		elif mesh.name.begins_with("RangerBrooch"):
			mesh.visible = hero_class == "ranger"
			mesh.material_override = Art.bronze()
		elif mesh.name.begins_with("RangerQuiver"):
			# Tooled leather and bronze, full of fletched arrows
			# (assets/shaders/quiver.gdshader).
			mesh.visible = hero_class == "ranger"
			mesh.material_override = Art.quiver()
		elif mesh.name.begins_with("RangerDagger"):
			# Worn in its sheath on the outside of the left thigh, hilt up.
			mesh.visible = hero_class == "ranger"
			var sheath = Art.sheathed(mesh.get_active_material(0))
			if sheath is ShaderMaterial:
				sheath = sheath.duplicate()
				if mesh.skin != null and mesh.mesh is ArrayMesh: mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
				var length: AABB = mesh.mesh.get_aabb()
				sheath.set_shader_parameter("pommel_height",length.end.y)
				sheath.set_shader_parameter("point_height",length.position.y)
				sheath.set_shader_parameter("rest_pose",mesh.skin != null)
			mesh.material_override = sheath
		elif mesh.name.begins_with("Ranger") and not "RangerCloak" in mesh.name and not "RangerBody" in mesh.name:
			mesh.visible = hero_class == "ranger"
		elif "HeroHelmet" in mesh.name:
			# The warrior's gladiator helm, a steel face mask
			# (assets/shaders/gladiator_helm.gdshader).
			mesh.visible = hero_class == "warrior"
			var helm = ShaderMaterial.new()
			helm.shader = load("res://assets/shaders/gladiator_helm.gdshader")
			if mesh.skin != null and mesh.mesh is ArrayMesh:
				mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
				helm.set_shader_parameter("rest_pose",true)
			mesh.material_override = helm
		elif "RangerCloak" in mesh.name:
			# A dark green hooded cloak that folds over his legs rather than
			# letting them through (assets/shaders/cloak.gdshader).
			mesh.visible = hero_class == "ranger"
			var cloth = ShaderMaterial.new()
			cloth.shader = load("res://assets/shaders/cloak.gdshader")
			cloth.set_shader_parameter("cloth_color",Color(.1,.19,.1))
			# Weathered and tattered, its wool laid on the cloak's rest pose.
			if mesh.skin != null and mesh.mesh is ArrayMesh:
				mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
				cloth.set_shader_parameter("rest_pose",true)
			cloth.set_shader_parameter("tatter",1.0)
			cloth.set_shader_parameter("hem_height",.3)
			cloth.set_shader_parameter("fold_depth",.005)
			mesh.material_override = cloth
			if hero_class == "ranger": cloak_mesh = mesh
		elif "WizardCape" in mesh.name or "WizardHood" in mesh.name or "WizardRobe" in mesh.name:
			# Deep navy wool, worn and lightly frayed at the hems; the cape
			# swings and folds over his legs as the ranger's cloak does.
			mesh.visible = hero_class == "wizard"
			var wool = ShaderMaterial.new()
			wool.shader = load("res://assets/shaders/cloak.gdshader")
			# The slate navy of his concept art, a coarse wool that shows its folds.
			wool.set_shader_parameter("cloth_color",Color(.13,.16,.27))
			if mesh.skin != null and mesh.mesh is ArrayMesh:
				mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
				wool.set_shader_parameter("rest_pose",true)
			wool.set_shader_parameter("tatter",.35)
			wool.set_shader_parameter("hem_height",.2 if "WizardCape" in mesh.name else (.14 if "WizardRobe" in mesh.name else -1.0))
			if "WizardRobe" in mesh.name:
				wool.set_shader_parameter("robe",1.0)
				var box: AABB = mesh.get_aabb()
				wool.set_shader_parameter("sleeve_end",maxf(absf(box.position.x),absf(box.end.x)))
			if "WizardHood" in mesh.name: wool.set_shader_parameter("fold_depth",.0015)
			mesh.material_override = wool
			if hero_class == "wizard" and "WizardCape" in mesh.name: cloak_mesh = mesh
		elif "Hair" in mesh.name:
			# The helm or hood covers the hair.
			mesh.visible = false
		elif "SuperHero" in mesh.name or "HeroArmor" in mesh.name or "WizardBody" in mesh.name or "RangerBody" in mesh.name:
			# The wizard and ranger wear bodies without the parts their robe or
			# cloak covers; only the warrior wears the scale armor (the ranger
			# has a wool tunic).
			if "WizardBody" in mesh.name: mesh.visible = hero_class == "wizard"
			elif "RangerBody" in mesh.name: mesh.visible = hero_class == "ranger"
			elif hero_class in ["wizard","ranger"] and "SuperHero" in mesh.name: mesh.visible = false
			elif hero_class == "wizard": mesh.visible = false
			elif "HeroArmor" in mesh.name: mesh.visible = hero_class == "warrior"
			mesh.material_override = Art.hero_kit(hero_class)
	for clip in animator.get_animation_list():
		for expected in ["Idle","Run","Attack","Cleave","Evade","Death","Cast","Thrust","Crouch","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","SpearLunge","ShieldStab","ArcherShot","OracleCast","ShieldHit","ShieldHitHead","ShieldHitStagger","ShieldHitKnockdown","Hit","HitHead","HitStagger","HitKnockdown","SwordSwing","SwordSlash","AxeChop","AxeWhirl","SpearStab","SpearJab","BowShot","BowRapid","BowIdle","BowRun","BowCrouch","SpearIdle","RangerIdle","RangerRun","RangerCrouch","WizardIdle","WizardRun","WizardCrouch"]:
			if clip == expected or clip.ends_with("/" + expected):
				clips[expected] = clip
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if expected in ["Idle","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","Run","Crouch","BowIdle","BowRun","BowCrouch","SpearIdle","RangerIdle","RangerRun","RangerCrouch","WizardIdle","WizardRun","WizardCrouch"] else Animation.LOOP_NONE
	skeleton.skeleton_updated.connect(align_weapon)
	if not stone and hero_class == "ranger": setup_cloak()
	elif not stone and hero_class == "wizard": setup_cloak("cape_")
	elif not stone and hero_class == "warrior": setup_cloak("kilt_")
	elif stone and skeleton.find_bone("cloak_0_0") >= 0:
		# A statue's stone cloth (the Crowned Statue's cape) swings and folds
		# over the legs as the ranger's cloak does; its stone material is its
		# own, to carry this statue's legs.
		for mesh in skin_meshes:
			if mesh.skin != null and mesh.material_override is ShaderMaterial:
				mesh.material_override = mesh.material_override.duplicate()
				cloak_mesh = mesh
		setup_cloak()
	# Cloth over something thicker than the bare legs stands further off them:
	# the ranger's cloak over his boots, the warrior's kilt over the full
	# muscle of his thighs, a cape over a robe's skirt and sash.
	if cloak_mesh != null:
		var robed = (not stone and hero_class == "wizard") or (stone and enemy_kind == "wizard")
		cloth_clearance = .08 if robed else (.02 if not stone else 0.0)
		if robed:
			cloak_mesh.material_override.set_shader_parameter("min_reach",.24)
			cloak_mesh.material_override.set_shader_parameter("waist_reach",.2)
	equip(weapon)
	play(idle_action())

func equip(weapon: String) -> void:
	carry_in_hand = null
	if is_instance_valid(shield_attachment): shield_attachment.queue_free()
	shield_item = null
	bow_strings.clear()
	if is_instance_valid(nocked_arrow): nocked_arrow.queue_free()
	nocked_arrow = null
	weapon_kind = weapon
	weapon_item = null
	if is_instance_valid(equipment):
		equipment.queue_free()
		equipment = null
	if weapon.is_empty(): return
	var hand = BoneAttachment3D.new()
	hand.bone_name = "hand_l" if weapon == "bow" else "hand_r"
	skeleton.add_child(hand)
	equipment = hand
	var sizes = {"sword":Vector3(.19,1.3,.09),"spear":Vector3(.14,2.3,.09),"axe":Vector3(.55,1.25,.12),"bow":Vector3(.25,1.3,.10),"staff":Vector3(.32,1.9,.22)}
	weapon_size = sizes[weapon]
	var weapon_finish = Art.statue_material() if is_stone else (Art.sword_material() if weapon=="sword" else (Art.bow_wood() if weapon=="bow" else null))
	# The Oracle carries a slender staff crowned with a diamond (tools/prepare_staff.py).
	var oracle = weapon=="staff" and enemy_kind=="wizard"
	if oracle: weapon_size = ORACLE_STAFF_SIZE
	# The hero wizard's staff is the same slender staff, in twisted silver
	# with a crystal (after his concept art).
	var silver_staff = weapon=="staff" and not is_stone
	if silver_staff:
		weapon_size = ORACLE_STAFF_SIZE
		weapon_finish = Art.wizard_staff()
	# The Crowned Statue wields a great sword.
	if weapon=="sword" and enemy_kind=="boss": weapon_size *= BOSS_SWORD_SCALE
	var item = Art.model("oracle_staff" if oracle or silver_staff else weapon, weapon_size,weapon_finish)
	weapon_item = item
	hand.add_child(item)
	# Model +Y runs along the weapon; align to the hand's local +Z grip axis.
	item.rotation.x = PI / 2
	# The grip sits a fixed share up each hilt; the larger sword's hilt is longer.
	item.position = Vector3(0,.075,{"bow":-.55,"sword":-.22}.get(weapon,-.17))
	weapon_rest = item.transform
	if oracle or silver_staff:
		item.top_level = true
		if oracle: oracle_staff_flame()
	if weapon in ["spear","bow"]:
		item.top_level = true
		if weapon == "bow":
			for mesh in item.find_children("*","MeshInstance3D",true,false):
				for i in mesh.mesh.get_blend_shape_count():
					if mesh.mesh.get_blend_shape_name(i)=="Draw": bow_strings.append({"mesh":mesh,"index":i})
			nocked_arrow = Art.model("arrow",Art.ARROW_SIZE,Art.statue_material() if is_stone else null)
			add_child(nocked_arrow)
			nocked_arrow.top_level = true
			nocked_arrow.visible = false
		align_weapon()
	# The hero's sword comes with a shield; among statues only shield bearers carry one.
	if (weapon=="sword" and not is_stone) or enemy_kind in SHIELD_BEARERS:
		var scutum = enemy_kind in SHIELD_BEARERS
		var tower = enemy_kind=="centurion"
		shield_attachment = BoneAttachment3D.new()
		shield_attachment.bone_name = "lowerarm_l"
		skeleton.add_child(shield_attachment)
		var finish = Art.statue_material() if is_stone else (Art.metal() if scutum else Art.gladiator_shield())
		var shield = Art.model("scutum" if scutum else "shield",TOWER_SIZE if tower else (SCUTUM_SIZE if scutum else SHIELD_SIZE),finish)
		shield_item = shield
		shield_attachment.add_child(shield)
		# The imported shield pivots at its bottom edge. Center its back against
		# the outer forearm, keeping the wrist inside its face rather than at a rim.
		if scutum: shield.basis = Basis(SCUTUM_ROTATION.normalized())*Basis.from_scale(TOWER_SIZE if tower else SCUTUM_SIZE)
		else: shield.rotation.y = PI
		shield.position = (SCUTUM_CENTER if scutum else SHIELD_CENTER)-shield.basis*Vector3(0,.5+(TOWER_DROP if tower else 0.0),0)
		shield_rest = shield.position
		shield_box = AABB()
		# A scutum is laid along the forearm every frame (strap_scutum), in
		# the world's own space.
		strapped = scutum
		strap_size = TOWER_SIZE if tower else SCUTUM_SIZE
		# Crossed by the forearm a little above its middle, so its top
		# stays below the chin.
		strap_hold = .6+(TOWER_DROP if tower else 0.0)
		shield.top_level = scutum
	if state in ["Idle","SwordIdle","ScutumSwordIdle","SpearShieldIdle","BowIdle","SpearIdle"]: play(idle_action())

# Clips in which an archer holds the bow out in the left hand, ready or
# shooting. Otherwise the ranger carries it at his side in the same left hand,
# through his own idle, run and crouch (the warrior's, with the left hand
# closed on the bow), so it never changes hands.
const BOW_READY_STATES = ["BowIdle","BowShot","BowRapid","ArcherShot"]
# How long the ranger takes to lower his bow arm after a shot.
const BOW_LOWER_TIME = .45
var bow_lowering = 0.0

func carries_bow() -> bool:
	return ranger_carry() and not state in BOW_READY_STATES

# Archers who stand and move as the ranger does, the bow carried in the left
# fist at the side: the ranger, and the stone archer in his likeness.
func ranger_carry() -> bool:
	return weapon_kind == "bow" and (not is_stone or enemy_kind == "archer") and clips.has("RangerIdle")

func idle_action() -> String:
	if ranger_carry(): return "RangerIdle"
	if not is_stone and weapon_kind == "staff": return "WizardIdle" if clips.has("WizardIdle") else "Idle"
	var wanted = {"bow":"BowIdle","spear":"SpearIdle","sword":"SwordIdle"}.get(weapon_kind,"Idle")
	if enemy_kind in SHIELD_BEARERS: wanted = "ScutumSwordIdle" if weapon_kind=="sword" else "SpearShieldIdle"
	return wanted if clips.has(wanted) else "Idle"

func draw_amount(t: float, release: float, start: float) -> float:
	if t<start or t>release+.06: return 0
	if t>release: return lerpf(BOW_FULL_DRAW,0,(t-release)/.06)
	return smoothstep(start,release-.06,t)*BOW_FULL_DRAW

# The flame that forms in the crown of the Oracle's staff while it casts.
func oracle_staff_flame() -> void:
	oracle_flame = Node3D.new()
	oracle_flame.top_level = true
	add_child(oracle_flame)
	var core = Vfx.particles(oracle_flame,16,.45,false,true)
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = .03
	core.direction = Vector3.UP
	core.spread = 25
	core.initial_velocity_min = .15; core.initial_velocity_max = .4
	core.gravity = Vector3(0,.8,0)
	core.scale_amount_min = .16; core.scale_amount_max = .24
	core.scale_amount_curve = Vfx.curve(1,.2)
	core.color_ramp = Vfx.ramp([0,.2,.6,1],[Color(1,.95,.7,0),Color(1,.8,.4,.8),Color(1,.45,.1,.5),Color(.6,.12,.03,0)])
	var embers = Vfx.particles(oracle_flame,6,.9,false,true)
	embers.direction = Vector3.UP
	embers.spread = 60
	embers.initial_velocity_min = .3; embers.initial_velocity_max = .7
	embers.gravity = Vector3(0,.4,0)
	embers.scale_amount_min = .03; embers.scale_amount_max = .05
	embers.color_ramp = Vfx.ramp([0,1],[Color(1,.7,.3,1),Color(1,.3,.05,0)])
	oracle_flame_parts = [core,embers]
	oracle_flame_light = OmniLight3D.new()
	oracle_flame_light.light_color = Color(1,.55,.2)
	oracle_flame_light.omni_range = 3.5
	oracle_flame_light.omni_attenuation = 1.4
	oracle_flame.add_child(oracle_flame_light)
	oracle_flame.visible = false

# How far the flame has grown at this point of the cast (0 to 1).
func cast_glow(phase: float) -> float:
	if state != "OracleCast": return 0.0
	if phase >= Motion.ORACLE_CAST.contacts[0]: return 0.0
	return smoothstep(.06,.74,phase)

# The top of the Oracle's staff, where the flame sits and the fireball leaves.
func staff_tip() -> Vector3:
	if not is_instance_valid(weapon_item) or enemy_kind != "wizard": return global_position+Vector3.UP*1.5
	return weapon_item.global_transform*Vector3(0,.93,0)

func oracle_staff_direction(phase: float) -> Vector2:
	var keys: Array = ORACLE_STAFF_KEYS if state=="OracleCast" else [[0.0,1.0,.08],[1.0,1.0,.08]]
	for i in keys.size()-1:
		var a: Array = keys[i]; var b: Array = keys[i+1]
		if phase <= b[0]:
			var u = smoothstep(0.0,1.0,(phase-a[0])/maxf(.001,b[0]-a[0]))
			return Vector2(lerpf(a[1],b[1],u),lerpf(a[2],b[2],u))
	return Vector2(keys[-1][1],keys[-1][2])

func align_oracle_staff() -> void:
	var facing = global_basis.orthonormalized()
	var hand = (skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))).origin
	# The assigned clip, so a held (paused) pose keeps its staff angle and flame.
	var phase = 0.0
	if not animator.assigned_animation.is_empty():
		phase = animator.current_animation_position/maxf(.001,animator.get_animation(animator.assigned_animation).length)
	var lean = oracle_staff_direction(phase)
	var up = (Vector3.UP*lean.x+facing.z*lean.y).normalized()
	var side = facing.x.cross(up).normalized()
	var across = up.cross(side).normalized()
	var length = weapon_size.y*rig.scale.x
	weapon_item.global_basis = Basis(across,up,side)*Basis.from_scale(weapon_size*rig.scale.x)
	# Thrust out toward the target, the staff slides through the hand to near
	# its foot, so its lower end does not run back through the robe.
	var thrust = smoothstep(.3,.85,clampf(lean.y/maxf(.001,lean.length()),0.0,1.0))
	weapon_item.global_position = hand-up*length*lerpf(ORACLE_GRIP,.14,thrust)
	var glow = cast_glow(phase)
	oracle_flame.visible = glow>.01 and not dead
	if oracle_flame.visible:
		oracle_flame.global_position = staff_tip()
		oracle_flame.scale = Vector3.ONE*maxf(.05,glow)*rig.scale.x
		oracle_flame_light.light_energy = 2.2*glow

# The hero wizard's staff, held like a walking stick: upright, leaning a touch
# forward, gripped near its top (WIZARD_GRIP of its length up from the foot).
const WIZARD_GRIP = .76
const WIZARD_STAFF_LENGTH = 1.65
func align_walking_staff() -> void:
	var facing = global_basis.orthonormalized()
	# Through the middle of his closed fist, not the wrist.
	var hand: Vector3 = bow_hold("r")[0]
	var up = (Vector3.UP+facing.z*.12).normalized()
	var side = facing.x.cross(up).normalized()
	var across = up.cross(side).normalized()
	var size = Vector3(ORACLE_STAFF_SIZE.x,WIZARD_STAFF_LENGTH,ORACLE_STAFF_SIZE.z)*rig.scale.x
	weapon_item.global_basis = Basis(across,up,side)*Basis.from_scale(size)
	weapon_item.global_position = hand-up*size.y*WIZARD_GRIP

# The shield's place on the forearm, and its board in its own space.
var shield_rest = Vector3.ZERO
var shield_box = AABB()
# A strapped scutum: its size, and how far up the board the forearm crosses.
var strapped = false
var strap_size = Vector3.ONE
var strap_hold = .5

# The shield bearers' scutum is strapped flat along the left forearm, which
# they carry level across the front of the body: the board's back against
# the outside of the forearm, its middle over the middle of the forearm,
# upright, and facing out from the body as nearly the way they face as the
# forearm allows (out to the side when the forearm points ahead).
func strap_scutum() -> void:
	var k = rig.scale.x
	var elbow = bone_position("lowerarm_l")
	var wrist = bone_position("hand_l")
	var forearm: Vector3 = (wrist-elbow).normalized()
	var facing = global_basis.orthonormalized()
	var out: Vector3 = facing.z-forearm*facing.z.dot(forearm)
	if out.length() < .35: out = facing.x-forearm*facing.x.dot(forearm)
	out = out.normalized()
	var up: Vector3 = Vector3.UP-out*Vector3.UP.dot(out)
	if up.length() < .2: up = facing.y
	var side: Vector3 = up.normalized().cross(out).normalized()
	up = out.cross(side).normalized()
	var size: Vector3 = strap_size*k
	# The board's back bulges to half its depth behind its rim.
	var middle: Vector3 = elbow.lerp(wrist,.55)+out*(.045*k+size.z*.5)
	shield_item.global_transform = Transform3D(Basis(side*size.x,up*size.y,out*size.z),middle-up*size.y*strap_hold)
# What a shield is kept in front of, as capsules from bone to bone: the legs,
# the body and head (leaning into a run or a swing), and the shield arm's own
# forearm and fist behind the board.
const SHIELD_LEG_CLEARANCE = [["thigh_l","calf_l",.09],["thigh_r","calf_r",.09],["calf_l","foot_l",.065],["calf_r","foot_r",.065],["pelvis","spine_03",.13],["spine_03","neck_01",.14],["neck_01","Head",.1],["lowerarm_l","hand_l",.045],["hand_l","middle_02_l",.04]]

# A knee raised in a lunge or a stride would pass through a big shield held
# low, a head leaning into a run through its top, and a clenched fist through
# its middle; the shield stands off the forearm just far enough to keep them
# behind its board.
func keep_shield_off_legs() -> void:
	if not is_instance_valid(shield_item) or not shield_item.is_inside_tree(): return
	if strapped: strap_scutum()
	else: shield_item.position = shield_rest
	if shield_box.size == Vector3.ZERO:
		var first = true
		for mesh in shield_item.find_children("*","MeshInstance3D",true,false):
			var box: AABB = shield_item.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
			shield_box = box if first else shield_box.merge(box)
			first = false
		if first: return
	var t: Transform3D = shield_item.global_transform
	# The board's thickness runs along its thinnest side (in the world: the
	# model is scaled unevenly).
	var thin = 0
	for axis in 3: if shield_box.size[axis]*t.basis[axis].length() < shield_box.size[thin]*t.basis[thin].length(): thin = axis
	var across = [(thin+1)%3,(thin+2)%3]
	var centre: Vector3 = t*shield_box.get_center()
	var normal: Vector3 = t.basis[thin].normalized()
	# Outward: away from the body behind it.
	if normal.dot(centre-bone_position("spine_02")) < 0: normal = -normal
	var half_thick = shield_box.size[thin]*t.basis[thin].length()*.5
	var k = rig.scale.x
	var push = 0.0
	for limb in SHIELD_LEG_CLEARANCE:
		var a = bone_position(limb[0]); var b = bone_position(limb[1])
		var r = limb[2]*k
		for i in 7:
			var p: Vector3 = a.lerp(b,i/6.0)
			var inside = true
			for axis in across:
				var dir: Vector3 = t.basis[axis]
				var reach = (p-centre).dot(dir.normalized())
				if absf(reach) > shield_box.size[axis]*dir.length()*.5: inside = false
			if not inside: continue
			var depth = (p-centre).dot(normal)
			# A leg behind the board but reaching into it, or through it.
			if depth > -r-half_thick and depth < r: push = maxf(push,depth+r+half_thick)
	if push > 0: shield_item.global_position += normal*minf(push,.3*k)

# The sword's place in the hand, as equipped.
var weapon_rest = Transform3D()

# A sword carried low beside a strapped scutum would swing its blade through
# the board as the bearer runs: it turns about the fist, out to the bearer's
# right, just far enough to pass beside the board instead.
func keep_blade_off_shield() -> void:
	if not strapped or weapon_kind != "sword" or not is_instance_valid(weapon_item) or not is_instance_valid(shield_item): return
	weapon_item.transform = weapon_rest
	if not weapon_item.is_inside_tree(): return
	var grip: Vector3 = weapon_item.get_parent().global_position
	var right: Vector3 = -global_basis.x.normalized()
	for step in 8:
		if not blade_in_board(): return
		var t: Transform3D = weapon_item.global_transform
		var tip: Vector3 = t*Vector3(0,1,0)-grip
		var turn = Basis(Vector3.UP,signf(Vector3.UP.dot(tip.cross(right)))*.12)
		weapon_item.global_transform = Transform3D(turn*t.basis,grip+turn*(t.origin-grip))

# Whether the blade (past the hilt) passes through the scutum's board.
func blade_in_board() -> bool:
	var board: Transform3D = shield_item.global_transform
	var t: Transform3D = weapon_item.global_transform
	var centre: Vector3 = board*Vector3(0,.5,0)
	for i in 8:
		var offset: Vector3 = t*Vector3(0,.3+.7*i/7.0,0)-centre
		var inside = true
		for axis in 3:
			if absf(offset.dot(board.basis[axis].normalized())) > board.basis[axis].length()*.5: inside = false
		if inside: return true
	return false

func align_weapon() -> void:
	keep_shield_off_legs()
	keep_blade_off_shield()
	if enemy_kind == "wizard" and weapon_kind == "staff" and is_instance_valid(weapon_item) and is_instance_valid(oracle_flame):
		if is_inside_tree() and skeleton.is_inside_tree() and weapon_item.is_inside_tree(): align_oracle_staff()
		return
	if weapon_kind == "staff" and not is_stone and is_instance_valid(weapon_item):
		if is_inside_tree() and skeleton.is_inside_tree() and weapon_item.is_inside_tree(): align_walking_staff()
		return
	if weapon_kind not in ["spear","bow"] or not is_instance_valid(weapon_item): return
	if not is_inside_tree() or not skeleton.is_inside_tree() or not weapon_item.is_inside_tree(): return
	var facing = global_basis.orthonormalized()
	var hand_pose = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_l" if weapon_kind=="bow" else "hand_r"))
	if weapon_kind == "spear":
		weapon_item.global_basis = facing * Basis(Vector3.RIGHT,PI/2) * Basis.from_scale(weapon_size*rig.scale.x)
		weapon_item.global_position = hand_pose.origin-facing.z*.65*rig.scale.x
	else:
		# The wooden grip sits in the closed fist, through locomotion and
		# blends: the stave runs along the knuckles (pinky to index) and the
		# bow's curved front faces the way the archer faces.
		var carried = carries_bow()
		var hand_l: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))
		if carried and carry_in_hand != null:
			# Fixed in the fist: the same place and angle in the hand always.
			weapon_item.global_transform = hand_l*carry_in_hand
			if bow_lowering > 0:
				# Lowering after a shot: from held out to carried, turning in
				# the hand as the arm comes down.
				var w = 1.0-bow_lowering/BOW_LOWER_TIME
				w = w*w*(3-2*w)
				var hold = bow_hold("l")
				var up: Vector3 = hold[1]
				var front: Vector3 = (facing.z-up*facing.z.dot(up)).normalized()
				var held_basis = Basis(-front,up,(-front).cross(up)).orthonormalized()
				var held_position: Vector3 = hold[0]-(held_basis*Basis.from_scale(weapon_size*rig.scale.x))*BOW_GRIP
				var carried_basis: Basis = weapon_item.global_basis.orthonormalized()
				var turned = Basis(held_basis.get_rotation_quaternion().slerp(carried_basis.get_rotation_quaternion(),w))
				weapon_item.global_basis = turned*Basis.from_scale(weapon_size*rig.scale.x)
				weapon_item.global_position = held_position.lerp(weapon_item.global_position,w)
			for string in bow_strings: string.mesh.set_blend_shape_value(string.index,0.0)
			if is_instance_valid(nocked_arrow): nocked_arrow.visible = false
			return
		var hold = bow_hold("l")
		var up: Vector3 = hold[1]
		var front: Vector3
		if carried:
			# Carried, the bow is fixed in the fist and turns with the hand.
			var forearm: Vector3 = (bone_position("hand_l")-bone_position("lowerarm_l")).normalized()
			# The stave runs forward and back beside the leg, square to the
			# forearm, and the bow faces along the forearm, as it would shoot;
			# its back limb angled out from his side, clear of the cloak.
			up = (facing.z-forearm*facing.z.dot(forearm)).normalized()
			var outward: Vector3 = (facing.x-forearm*facing.x.dot(forearm)).normalized()
			up = (up*cos(BOW_CARRY_SPLAY)-outward*sin(BOW_CARRY_SPLAY)).normalized()
			front = forearm
		else:
			# Held out, the bow's curved front faces the way he faces.
			front = (facing.z-up*facing.z.dot(up)).normalized()
		weapon_item.global_basis = Basis(-front,up,(-front).cross(up)) * Basis.from_scale(weapon_size*rig.scale.x)
		weapon_item.global_position = hold[0]-weapon_item.global_basis*BOW_GRIP
		if not carried: keep_bow_off_legs()
		# The grip is taken once, in the idle stance, and kept from then on.
		if carried and state == "RangerIdle": carry_in_hand = hand_l.affine_inverse()*weapon_item.global_transform
		var phase = 1.0
		if not animator.current_animation.is_empty():
			phase = animator.current_animation_position / maxf(.001,animator.current_animation_length)
		var draw = 0.0
		var arrow_visible = false
		if state=="BowShot":
			draw = draw_amount(phase,.62,.12)
			arrow_visible = phase<.62
		elif state=="ArcherShot":
			# The arrow appears once the draw hand brings it from the quiver to the bow.
			draw = draw_amount(phase,Motion.ARCHER_SHOT.contacts[0],.56)
			arrow_visible = phase>=.44 and phase<Motion.ARCHER_SHOT.contacts[0]
		elif state=="BowRapid":
			for pair in [Vector2(0,.30),Vector2(.40,.54),Vector2(.64,.78)]:
				draw = maxf(draw,draw_amount(phase,pair.y,pair.x))
				arrow_visible = arrow_visible or (phase>=pair.x and phase<pair.y)
		# The draw hand's fingers, hooked on the string.
		var fingers = draw_fingers()
		if arrow_visible:
			# Match the actual baked hand during the pull, including animation blends.
			var nock = weapon_item.global_transform * Vector3(.5,.5,0)
			draw = clampf((nock-fingers).dot(facing.z)/(.36*rig.scale.x),0.0,BOW_FULL_DRAW)
		for string in bow_strings: string.mesh.set_blend_shape_value(string.index,draw)
		if is_instance_valid(nocked_arrow):
			nocked_arrow.visible = arrow_visible and not dead
			# Its head (local -Z) toward the target, its nock on the string.
			nocked_arrow.global_basis = facing * Basis(Vector3.UP,PI) * Basis.from_scale(Art.ARROW_SIZE*rig.scale.x)
			# Nocked on the string, wherever the pull has drawn it.
			var string = weapon_item.global_transform * Vector3(.5+draw*1.44,.5+draw*.06/1.3,0)
			nocked_arrow.global_position = string+facing.z*Art.ARROW_SIZE.z*.5*rig.scale.x

# The carried bow's place in the left hand, taken from the idle stance.
var carry_in_hand = null

# How far the carried bow's back limb is angled out from his side (radians),
# so it passes outside his cloak rather than through it.
const BOW_CARRY_SPLAY = .32

# The legs a held bow keeps outside of, as capsules from bone to bone.
const BOW_LEG_CLEARANCE = [["thigh_l","calf_l",.1],["thigh_r","calf_r",.1],["calf_l","foot_l",.075],["calf_r","foot_r",.075]]

# A held bow swung low (raised to shoot from the side, or a statue's as it
# staggers) turns about the grip just enough to keep its limbs and string
# outside the legs, rather than through them: a few small turns are tried
# each way, keeping whichever clears the legs best, until they are clear. Its
# curved front stays within 10 degrees of where it faced while the archer
# stands or moves (53 as he staggers or raises it).
func keep_bow_off_legs() -> void:
	var legs = []
	for limb in BOW_LEG_CLEARANCE: legs.append([bone_position(limb[0]),bone_position(limb[1]),limb[2]*rig.scale.x])
	var t: Transform3D = weapon_item.global_transform
	var gap = bow_leg_gap(t,legs)
	if gap >= 0: return
	var grip: Vector3 = t*BOW_GRIP
	var facing = global_basis.orthonormalized()
	var front: Vector3 = -t.basis.x.normalized()
	var keep_front = .985 if state in ["BowIdle","BowRun","BowCrouch"] else .6
	var step = .15
	for attempt in 24:
		var best = t
		var best_gap = gap
		for axis in [front,facing.x,facing.y]:
			for turn_by in [-step,step]:
				var turn = Basis(axis.normalized(),turn_by)
				var turned = Transform3D(turn*t.basis,grip+turn*(t.origin-grip))
				if (-turned.basis.x.normalized()).dot(front) < keep_front: continue
				var turned_gap = bow_leg_gap(turned,legs)
				if turned_gap > best_gap:
					best = turned
					best_gap = turned_gap
		if best_gap <= gap: step *= .5
		else:
			t = best
			gap = best_gap
		if gap >= 0: break
	weapon_item.global_transform = t

# How far a bow placed at `t` stands clear of the legs (negative: into them),
# along its limbs (from just past the fist toward each tip) and its string.
# The fist itself may rest against a thigh.
func bow_leg_gap(t: Transform3D, legs: Array) -> float:
	var grip: Vector3 = t*BOW_GRIP
	var gap = INF
	var low: Vector3 = t*Vector3(.25,0,0)
	var high: Vector3 = t*Vector3(.25,1,0)
	for line in [[grip.lerp(low,.2),low],[grip.lerp(high,.2),high],[t*Vector3(.5,0,0),t*Vector3(.5,1,0)]]:
		for leg in legs:
			var closest = Geometry3D.get_closest_points_between_segments(line[0],line[1],leg[0],leg[1])
			gap = minf(gap,closest[0].distance_to(closest[1])-leg[2])
	return gap


func bone_position(bone: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin

func draw_fingers() -> Vector3:
	var at = func(bone: String) -> Vector3: return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return (at.call("index_02_r")+at.call("middle_02_r"))*.5

# A fist holding the bow ("l" or "r"): the centre of the hole its curled
# fingers close round, and the knuckle line from pinky to index, which the
# bow's stave follows.
func bow_hold(side: String = "l") -> Array:
	var at = func(bone: String) -> Vector3: return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone+"_"+side)).origin
	var knuckles: Vector3 = at.call("index_01")-at.call("pinky_01")
	var ring = [at.call("middle_01"),at.call("middle_02"),at.call("middle_03"),at.call("index_02"),at.call("ring_02")]
	var centre = Vector3.ZERO
	for p in ring: centre += p
	return [centre/ring.size(),knuckles.normalized()]

func crown() -> void:
	var attachment = BoneAttachment3D.new()
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)
	# Sized to the statue's head (about 18cm across) and seated on its crown.
	var c = Art.model("crown", Vector3(.22,.12,.22), Art.statue_material() if is_stone else Art.material("gold"))
	attachment.add_child(c)
	c.position = Vector3(0,.17,0)

func petrify() -> void:
	is_stone = true
	for mesh in find_children("*","MeshInstance3D",true,false): mesh.material_override = Art.statue_material()
	animator.pause()

func play(action: String, duration: float = 0.0, speed_scale: float = 1.0) -> void:
	if dead or not clips.has(action): return
	var previous = state
	state = action
	reaction_time = 0
	animation_delay = 0
	pending_animation_time = 0
	var speed = animator.get_animation(clips[action]).length / duration if duration > 0 else speed_scale
	if action in ["BowRun","SwordRun","ScutumRun","RangerRun","WizardRun"]: locomotion_rate = speed_scale
	var blend = minf(.08,duration*.1) if duration>0 else .08
	# After a shot the ranger lowers his bow arm gradually, back to his side.
	if ranger_carry() and previous in BOW_READY_STATES and not action in BOW_READY_STATES:
		blend = BOW_LOWER_TIME
		bow_lowering = BOW_LOWER_TIME
	var replay = animator.assigned_animation == clips[action]
	animator.play(clips[action], blend, speed)
	# play() resumes an already assigned clip. Repeated attacks must each
	# start a fresh wind-up, even when the last recovery is still playing. A
	# new clip starts from its beginning anyway, and seeking it would cut the
	# crossfade from the last one short.
	if replay: animator.seek(0,true)
	animator.advance(0)
	if action == "Death": dead = true

# Flinch without interrupting anything: attacks, skills, evades and death
# replace a reaction through play(); locomotion resumes once it finishes.
func react(action: String, duration: float) -> void:
	if dead or not clips.has(action): return
	# Shield bearers keep the forearm turned so the strapped shield stays put.
	if is_instance_valid(shield_item) and clips.has("Shield"+action): action = "Shield"+action
	play(action,duration)
	reaction_time = duration

# `settled` shows the finished pile at once (a statue already slain on load).
func crumble(settled: bool = false) -> void:
	if crumbling >= 0.0: return
	dead = true
	state = "Crumble"
	animator.pause()
	crumbling = 0.0
	crumble_size = rig.scale.x
	var size = crumble_size
	rubble = Art.model("rubble",Vector3(1.0,.5,1.0)*size,Art.statue_material())
	add_child(rubble)
	rubble.rotation.y = fposmod(global_position.x*7.1+global_position.z*3.3,TAU)
	if not settled:
		var seed = global_position.x*12.9898+global_position.z*78.233
		for i in CHIPS:
			var angle = TAU*i/CHIPS+sin(seed+i)*.4
			var chip = Art.model("rock",Vector3.ONE*(.14+.1*fposmod(seed*.37+i*.61,1.0))*size,Art.statue_material())
			add_child(chip)
			var reach = (.5+.6*fposmod(seed*.13+i*.29,1.0))*size
			chip.position = Vector3(0,(.4+1.1*fposmod(i*.47,1.0))*size,0)
			chips.append({"node":chip,"velocity":Vector3(sin(angle)*reach*2.2,1.6*size,cos(angle)*reach*2.2),"spin":Vector3(3,5,2)*(1+i%3)})
		dust = Vfx.particles(self,18,1.2,true,false)
		dust.explosiveness = .9
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = .35*size
		dust.direction = Vector3.UP
		dust.spread = 80
		dust.initial_velocity_min = .3; dust.initial_velocity_max = .9
		dust.gravity = Vector3(0,.25,0)
		dust.scale_amount_min = .5*size; dust.scale_amount_max = .9*size
		dust.scale_amount_curve = Vfx.curve(.5,1.5)
		dust.color_ramp = Vfx.ramp([0,.2,1],[Color(.42,.42,.4,0),Color(.4,.4,.38,.55),Color(.36,.36,.34,0)])
		dust.position.y = .3*size
		dust.emitting = true
	crumble_step(CRUMBLE_TIME if settled else 0.0)

func crumble_step(dt: float) -> void:
	crumbling += dt
	var u = clampf(crumbling/CRUMBLE_TIME,0.0,1.0)
	var eased = u*u
	var size = crumble_size
	# The body sinks and spreads into the pile, then is gone.
	rig.scale = Vector3(size*(1.0+.25*eased),size*maxf(.02,1.0-eased),size*(1.0+.25*eased))
	rig.visible = u<1.0
	if is_instance_valid(weapon_item): weapon_item.visible = u<.4
	if is_instance_valid(nocked_arrow): nocked_arrow.visible = false
	rubble.scale = Vector3(1.0,.5,1.0)*size*clampf(u*1.3,0.0,1.0)
	for chip in chips:
		var node: Node3D = chip.node
		if node.position.y <= 0.0 and chip.velocity.y < 0.0: continue
		chip.velocity.y -= 9.8*dt
		node.position += chip.velocity*dt
		node.rotation += chip.spin*dt
		if node.position.y <= 0.0:
			node.position.y = 0.0
			chip.velocity = Vector3(0,-1,0)
	if is_instance_valid(dust): dust.speed_scale = 1.0 if dt>0 else dust.speed_scale

# The ranger's cloak below the waist hangs from chains of bones
# (tools/outfit_hero.py) swung by a spring simulation: gravity, inertia, a push
# opposite the ranger's motion so it flows back as he moves, and a collider
# on the hips and one down between the legs. The chains have no leg colliders: pushed round a leg they split
# the cloth to either side of it. The cloth itself is kept outside the legs
# by the cloak's shader, which folds it over them (assets/shaders/cloak.gdshader).
const CLOAK_STIFFNESS = 1.2
const CLOAK_DRAG = .45
const CLOAK_GRAVITY = 1.2
# The air pushes the cloth back in proportion to his (smoothed) speed; when he
# sets off it lags, and when he slows its momentum swings it on forward.
const CLOAK_FLOW = .14
const CLOAK_MOMENTUM = .05
const CLOAK_SETTLE_TIME = .25
# Running, the cloth ripples: each chain's weight wavers out of step with its
# neighbours, more the faster he goes.
const CLOAK_FLUTTER = .35
# How a garment's cloth moves: a light cloak at the hips (the ranger's), and
# heavy long cloth hung from the shoulders (a cape, a robe), which swings less
# and settles sooner.
const CLOTH_LIGHT = {"stiffness":CLOAK_STIFFNESS,"drag":CLOAK_DRAG,"gravity":CLOAK_GRAVITY,"flow":CLOAK_FLOW,"momentum":CLOAK_MOMENTUM,"flutter":CLOAK_FLUTTER}
const CLOTH_HEAVY = {"stiffness":1.6,"drag":.75,"gravity":2.0,"flow":.3,"momentum":.004,"flutter":.12}
# A short kilt of leather strips: stiff, swaying with the stride, barely
# trailing.
const CLOTH_KILT = {"stiffness":2.4,"drag":.6,"gravity":1.6,"flow":.04,"momentum":.01,"flutter":.06}
var cloth_feel: Dictionary = CLOTH_LIGHT
const CLOAK_RUN_SPEED = 5.0
var cloak: SpringBoneSimulator3D
var cloak_mesh: MeshInstance3D
# The limbs the cloak's cloth may never pass through, as capsules from bone to
# bone with a radius a little over the limb's own (boots included).
const CLOAK_BODY_CAPSULES = [["thigh_l","calf_l",.105],["thigh_r","calf_r",.105],["calf_l","foot_l",.085],["calf_r","foot_r",.085],["foot_l","ball_l",.075],["foot_r","ball_r",.075]]
# The arms, which push only the cloth behind the body when they swing back
# into it.
const CLOAK_ARM_CAPSULES = [["upperarm_l","lowerarm_l",.07],["upperarm_r","lowerarm_r",.07],["lowerarm_l","hand_l",.065],["lowerarm_r","hand_r",.065]]
# How much more the cloth stands off the legs than the bare limbs: boots, a
# robe's skirt under a cape.
var cloth_clearance = 0.0
var cloak_last_position = null
var cloak_clock = 0.0
var cloak_velocity = Vector3.ZERO

# `prefix` names the chains: cloak_ (the ranger's cloak, a statue's cape) or
# cape_ (the wizard's cape, on the same hero skeleton as the ranger's).
func setup_cloak(prefix: String = "cloak_") -> void:
	if skeleton.find_bone(prefix+"0_0") < 0: return
	if cloak_mesh != null: skeleton.skeleton_updated.connect(cloak_capsules)
	var chains = 0
	while skeleton.find_bone(prefix+"%d_0" % chains) >= 0: chains += 1
	var segments = 0
	while skeleton.find_bone(prefix+"0_%d" % segments) >= 0: segments += 1
	var hangs_from: int = skeleton.get_bone_parent(skeleton.find_bone(prefix+"0_0"))
	if hangs_from != skeleton.find_bone("pelvis"): cloth_feel = CLOTH_HEAVY
	if prefix == "kilt_": cloth_feel = CLOTH_KILT
	cloak = SpringBoneSimulator3D.new()
	cloak.name = "CloakPhysics"
	skeleton.add_child(cloak)
	cloak.setting_count = chains
	for i in chains:
		var last: String = prefix+"%d_%d" % [i,segments-1]
		cloak.set_root_bone_name(i,prefix+"%d_0" % i)
		cloak.set_end_bone_name(i,last)
		cloak.set_extend_end_bone(i,true)
		cloak.set_end_bone_direction(i,SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
		cloak.set_end_bone_length(i,bone_length(last))
		cloak.set_radius(i,.03)
		cloak.set_stiffness(i,cloth_feel.stiffness)
		cloak.set_drag(i,cloth_feel.drag)
		cloak.set_gravity(i,cloth_feel.gravity)
		# Simulated in the character's frame, so the leg colliders keep hold of
		# the cloth; the air and the character's motion act through the forces
		# set in cloak_tick.
		cloak.set_center_from(i,SpringBoneSimulator3D.CENTER_FROM_NODE)
		cloak.set_center_node(i,cloak.get_path_to(self))
	var hips = SpringBoneCollisionCapsule3D.new()
	hips.bone_name = "pelvis"
	hips.radius = .15
	hips.height = .5
	cloak.add_child(hips)
	# Down the centre line between the legs, to the floor, so the cloak's
	# free front edges never swing in between them.
	var between = SpringBoneCollisionCapsule3D.new()
	between.bone_name = "pelvis"
	between.radius = .12
	between.height = 1.0
	between.position_offset = Vector3(0,-.5,0)
	cloak.add_child(between)
	# Cloth hanging from the upper back (a cape) is kept off the back too.
	if hangs_from == skeleton.find_bone("spine_03"):
		var back = SpringBoneCollisionCapsule3D.new()
		back.bone_name = "spine_02"
		back.radius = .17
		back.height = .6
		back.position_offset = Vector3(0,.1,0)
		cloak.add_child(back)
	var colliders = cloak.get_children()
	for i in chains:
		cloak.set_enable_all_child_collisions(i,false)
		cloak.set_collision_count(i,colliders.size())
		for k in colliders.size(): cloak.set_collision_path(i,k,cloak.get_path_to(colliders[k]))

# The legs as capsules in the cloak mesh's own space, for its shader, set
# after every pose so the cloth is tested against where the legs are now.
func cloak_capsules() -> void:
	if not is_instance_valid(cloak_mesh) or not cloak_mesh.is_inside_tree(): return
	var to_mesh: Transform3D = cloak_mesh.global_transform.affine_inverse()*skeleton.global_transform
	var a = PackedVector3Array(); var b = PackedVector3Array(); var r = PackedFloat32Array()
	for capsule in CLOAK_BODY_CAPSULES+CLOAK_ARM_CAPSULES:
		a.append(to_mesh*skeleton.get_bone_global_pose(skeleton.find_bone(capsule[0])).origin)
		b.append(to_mesh*skeleton.get_bone_global_pose(skeleton.find_bone(capsule[1])).origin)
		# The mesh's own space is the rig's, before the rig's scale.
		r.append(capsule[2]+(cloth_clearance if capsule in CLOAK_BODY_CAPSULES else 0.0))
	var m: ShaderMaterial = cloak_mesh.material_override
	m.set_shader_parameter("leg_capsules",CLOAK_BODY_CAPSULES.size())
	# The rig faces +Z.
	m.set_shader_parameter("body_forward",(to_mesh.basis*Vector3.BACK).normalized())
	m.set_shader_parameter("capsule_a",a)
	m.set_shader_parameter("capsule_b",b)
	m.set_shader_parameter("capsule_radius",r)
	m.set_shader_parameter("capsule_count",a.size())
	m.set_shader_parameter("body_center",to_mesh*skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin)

# Rest length of a bone: the distance to its first child.
func bone_length(bone: String) -> float:
	var index = skeleton.find_bone(bone)
	var children = skeleton.get_bone_children(index)
	if children.is_empty(): return (skeleton.get_bone_rest(index).origin).length()
	return skeleton.get_bone_rest(children[0]).origin.length()

func cloak_tick(dt: float) -> void:
	if cloak == null or dt <= 0: return
	cloak_clock += dt
	var at: Vector3 = global_position
	var velocity = Vector3.ZERO
	if cloak_last_position != null:
		velocity = (at-cloak_last_position)/dt
		velocity.y = 0
	cloak_last_position = at
	var previous: Vector3 = cloak_velocity
	cloak_velocity = cloak_velocity.lerp(velocity.limit_length(8.0),1.0-exp(-dt/CLOAK_SETTLE_TIME))
	var acceleration: Vector3 = (cloak_velocity-previous)/dt
	# Speeds are measured in the world; the simulation runs in the rig's
	# (scaled) units, so a larger statue's cloth gets the same lift.
	var push: Vector3 = (-cloak_velocity*cloth_feel.flow-acceleration*cloth_feel.momentum)/rig.scale.x
	cloak.external_force = global_basis.orthonormalized().inverse()*push
	var pace = clampf(cloak_velocity.length()/CLOAK_RUN_SPEED,0.0,1.0)
	# In the character's frame, which faces +Z.
	var side = Vector3(1,0,0)
	var back = Vector3(0,0,-1)
	for i in cloak.setting_count:
		var ripple = sin(cloak_clock*9.0+i*.9)*.7+sin(cloak_clock*5.3-i*1.7)*.3
		# Billows only ever lift it back, never swing it forward into the legs.
		var lift = sin(cloak_clock*6.1+i*1.3)*.5+.5
		cloak.set_gravity_direction(i,(Vector3.DOWN+(side*ripple*.6+back*lift*.4)*cloth_feel.flutter*pace).normalized())

func advance(dt: float) -> void:
	cloak_tick(dt)
	bow_lowering = maxf(0.0,bow_lowering-dt)
	if crumbling >= 0.0:
		if crumbling < CRUMBLE_TIME+1.5: crumble_step(dt)
		return
	reaction_time = maxf(0,reaction_time-dt)
	var held = minf(dt,animation_delay)
	animation_delay -= held
	if not animator.is_playing(): return
	pending_animation_time += dt-held
	# Keep the clock while culled; update the pose when visible again.
	if animator.active:
		animator.advance(pending_animation_time)
		pending_animation_time = 0

func locomotion(moving: bool, busy: bool, crouch: bool = false, speed_scale: float = 1.0) -> void:
	if dead or busy or reaction_time>0: return
	var wanted = ("Crouch" if crouch else "Run") if moving else idle_action()
	if moving and ranger_carry(): wanted = "RangerCrouch" if crouch else "RangerRun"
	elif moving and weapon_kind=="staff" and not is_stone: wanted = "WizardCrouch" if crouch else "WizardRun"
	elif moving and weapon_kind=="bow": wanted = "BowCrouch" if crouch else "BowRun"
	# Carry the sword low while running so the blade never swings through the head.
	# Shield bearers keep the tall shield held upright while they run.
	elif moving and not crouch and enemy_kind in SHIELD_BEARERS and clips.has("ScutumRun"): wanted = "ScutumRun"
	elif moving and not crouch and weapon_kind=="sword" and clips.has("SwordRun"): wanted = "SwordRun"
	var rate = clampf(speed_scale, .1, 4.0)
	if wanted != state or (wanted in ["BowRun","SwordRun","ScutumRun","RangerRun","WizardRun"] and not is_equal_approx(rate,locomotion_rate)):
		play(wanted,0.0,rate)
