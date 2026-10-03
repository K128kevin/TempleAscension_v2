extends Node3D
const Art = preload("res://scripts/assets.gd")
const Motion = preload("res://scripts/combat_animation.gd")
const Vfx = preload("res://scripts/vfx.gd")
const FootPlanter = preload("res://scripts/foot_planter.gd")
const HandGrip = preload("res://scripts/hand_grip.gd")
const ShieldArm = preload("res://scripts/shield_arm.gd")
const StoneFragment = preload("res://scripts/stone_fragment.gd")
const SwordTrail = preload("res://scripts/sword_trail.gd")
const BladeCharge = preload("res://scripts/blade_charge.gd")
# A slain statue breaks apart into individual physics-driven stone fragments:
# a front sweeps down the body, the stone above it cracking loose (the statue
# shader's shatter) and each fragment let go as the front reaches it. A blast
# shatters it faster than a blow.
const CRUMBLE_TIME = .5
const BLAST_CRUMBLE_TIME = .3
const CHIPS = 36
# (Past the temple's budget of loose stone: scripts/stone_fragment.gd BUDGET.)
const CROWDED_CHIPS = 10
const SPARSE_CHIPS = 5
# Metres (at life size) over which the chunks at one height break off.
const SHATTER_BAND = .35
var crumbling = -1.0
var crumble_size = 1.0
var crumble_time = CRUMBLE_TIME
var crumble_base = 0.0
# The statue's meshes that break up in the shader, and the rest, which go
# when the front passes their middle.
var shattering: Array = []
var shattered_whole: Array = []
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
# Keeps the feet planted while the unit isn't travelling (scripts/foot_planter.gd).
var planter
# Keeps the hands that hold something closed on it (scripts/hand_grip.gd).
var grip
# Locomotion clips: the feet follow the animation, played at the ground speed.
const LOCOMOTION = ["Run","Crouch","SwordRun","ScutumRun","BowRun","BowCrouch","RangerRun","RangerCrouch","WizardRun","WizardCrouch","Walk","SwordWalk","RangerWalk","WizardWalk"]
# The hero walks rather than runs (the R key; scripts/game.gd).
var walking = false
# The walks that carry a weapon are made from the plain walk as the hero is
# set up: its stride, with each arm held most of the way to where the matching
# stance holds it (the share given here, left and right), so the sword stays
# low, the shield in its guard, the bow at his side and the staff in his hand.
const WALKS = {"SwordWalk":["SwordIdle",{"l":.85,"r":.7}],"RangerWalk":["RangerIdle",{"l":.85,"r":.4}],"WizardWalk":["WizardIdle",{"l":.35,"r":.85}]}
# The body turns smoothly to the unit's facing (which the game sets at once),
# at most TURN_RATE radians a second, easing in over TURN_EASE seconds.
const TURN_RATE = 11.0
const TURN_EASE = .06
var shown_yaw = null
# Set while the unit is carried over the ground by a blow (shoved back, or
# following one in): the feet stay planted and step as it goes.
var carried = false
# Set while it is being driven back (shoved), not following one in; and the
# travel it still has to make (FootPlanter.owed).
var shoved = false
var owed = Vector3.ZERO
# The feet stay planted a moment after a carry ends (settling).
var carry_hold = 0.0
var last_position = null
var ground_speed = 0.0
# Clips that carry their unit forward as it steps (metres at life size, by
# clip fraction; tools/import_combat.py ADVANCE bakes the same keys, keeping
# the planted feet still in the world): the warrior's lunge and cleave, the
# centurion's stepping thrust. Visual.advance() measures the travel; the unit moves it
# (Actor.tick).
# (The sword chain's swings each walk him a stride on over the swing's share
# of the clip, Motion.SWORD_SWING_SHARE; its recovery stands still.)
const ROOT_ADVANCE = {"SwordSwing":[[0.0,0.0],[.10,0.0],[.42,.24],[.62,.24],[.90,.5],[1.0,.5]],"SwordOpen":[[0.0,0.0],[.12,0.0],[.3733,.42],[.5333,.5],[1.0,.5]],"SwordCut1R":[[0.0,0.0],[.12,0.0],[.3733,.42],[.5333,.5],[1.0,.5]],"SwordCut1L":[[0.0,0.0],[.12,0.0],[.3733,.42],[.5333,.5],[1.0,.5]],"SwordCut2R":[[0.0,0.0],[.12,0.0],[.3733,.42],[.5333,.5],[1.0,.5]],"SwordCut2L":[[0.0,0.0],[.12,0.0],[.3733,.42],[.5333,.5],[1.0,.5]],"SwordThrustR":[[0.0,0.0],[.12,0.0],[.3733,.42],[.5333,.5],[1.0,.5]],"SwordThrustL":[[0.0,0.0],[.12,0.0],[.3733,.42],[.5333,.5],[1.0,.5]],"SwordSlash":[[0.0,0.0],[.12,0.0],[.40,.2],[.66,.2],[.90,.4],[1.0,.4]],"ScutumSwordSwing":[[0.0,0.0],[.10,0.0],[.42,.24],[.62,.24],[.90,.5],[1.0,.5]],"ShieldStab":[[0.0,0.0],[.26,0.0],[.48,.2],[.64,.2],[.90,.45],[1.0,.45]]}
var travelled = 0.0
var pending_travel = 0.0

# Each locomotion clip's own ground speed at life size (metres a second, at
# normal playback): how fast its planted foot sweeps back under the body
# (measured by tools/anim_audit.gd --strides).
const STRIDE_SPEED = {"Run":6.35,"SwordRun":6.64,"ScutumRun":6.64,"BowRun":6.64,"RangerRun":6.64,"WizardRun":6.64,"Walk":1.0,"SwordWalk":1.0,"RangerWalk":1.0,"WizardWalk":1.0}
# The Lion Guardian goes on four legs (tools/make_lion.py): its own rig and
# clips, with none of a man's hands, feet or gear. Its gallop, played at its
# own pace, covers this many metres a second.
const LION_STRIDE_SPEED = 4.52
var quadruped = false
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
# (tools/paint_kits.py) cut into the stone; the lion has its own carved face.
const STATUE_KITS = {"gladiator":"warrior","centurion":"warrior","boss":"warrior","archer":"ranger","wizard":"wizard","lion":"lion"}

func setup(stone: bool, _tint: Color, weapon: String, stature: float = 1.0, enemy_kind: String = "", hero_class: String = "warrior") -> void:
	is_stone = stone
	self.enemy_kind = enemy_kind
	quadruped = stone and enemy_kind == "lion"
	var character = "guardian_%s" % enemy_kind if stone and enemy_kind in ["gladiator","archer","centurion","wizard","boss"] else ("guardian" if stone else "warrior")
	if quadruped: character = "lion"
	rig = load("res://assets/models/character/%s.glb" % character).instantiate()
	# The supplied Godot rig faces +Z, matching Actor.forward().
	rig.rotation.y = 0
	rig.scale = Vector3.ONE * stature
	add_child(rig)
	animator = rig.find_children("*", "AnimationPlayer", true, false)[0]
	# Actor.tick advances poses on the same clock as wind-up and recovery.
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	# Modifiers (the foot planter, cloth) run on the unit's own clock, after
	# each pose (advance()).
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	# (The lion's four paws are planted by its own planter.)
	planter = preload("res://scripts/paw_planter.gd").new() if quadruped else FootPlanter.new()
	planter.name = "FootPlanter"
	skeleton.add_child(planter)
	skeleton.move_child(planter,0)
	planter.setup(skeleton)
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
			# Its waistband sits close on his waist; only below it does the
			# cloth fold out over his thighs.
			kilt.set_shader_parameter("fold_from",.03)
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
		for expected in ["SwordOpen","SwordCut1R","SwordCut1L","SwordCut2R","SwordCut2L","SwordThrustR","SwordThrustL","SkillCleave","SkillStrike","SkillStab","SkillBash","SkillExecute","SkillSlam","SkillShockwave","SkillCry","SkillCharge","SkillLeap","Walk","Sit","ScutumSwordSwing","ScutumHit","ScutumHitHead","ScutumHitStagger","ScutumHitKnockdown","Idle","Run","Attack","Cleave","Evade","Death","Cast","Thrust","Crouch","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","SpearLunge","ShieldStab","ArcherShot","OracleCast","ShieldHit","ShieldHitHead","ShieldHitStagger","ShieldHitKnockdown","Hit","HitHead","HitStagger","HitKnockdown","SwordSwing","SwordSlash","AxeChop","AxeWhirl","SpearStab","SpearJab","BowShot","BowRapid","BowIdle","BowRun","BowCrouch","SpearIdle","RangerIdle","RangerRun","RangerCrouch","WizardIdle","WizardRun","WizardCrouch"]:
			if clip == expected or clip.ends_with("/" + expected):
				clips[expected] = clip
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if expected in ["Walk","Sit","Idle","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","Run","Crouch","BowIdle","BowRun","BowCrouch","SpearIdle","RangerIdle","RangerRun","RangerCrouch","WizardIdle","WizardRun","WizardCrouch"] else Animation.LOOP_NONE
	if quadruped:
		play(idle_action())
		return
	derive_walks()
	# The fists that close on a grip, from the stance clips that hold one: the
	# sword hand's, and the hand the ranger carries his bow in.
	grip = HandGrip.new()
	grip.name = "HandGrip"
	skeleton.add_child(grip)
	skeleton.move_child(grip,1)
	shield_arm = ShieldArm.new()
	shield_arm.name = "ShieldArm"
	skeleton.add_child(shield_arm)
	skeleton.move_child(shield_arm,2)
	shield_arm.setup(skeleton)
	for pair in [["r","SwordIdle"],["l","RangerIdle"]]:
		if not clips.has(pair[1]): continue
		animator.play(clips[pair[1]],0)
		animator.seek(0,true)
		animator.advance(0)
		grip.capture(skeleton,pair[0])
	skeleton.skeleton_updated.connect(shown_pose_updated)
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

func derive_walks() -> void:
	if not clips.has("Walk"): return
	var prefix: String = clips.Walk.trim_suffix("Walk")
	var library: AnimationLibrary = animator.get_animation_library(prefix.trim_suffix("/"))
	var walk: Animation = animator.get_animation(clips.Walk)
	walk.loop_mode = Animation.LOOP_LINEAR
	for name in WALKS:
		if not clips.has(WALKS[name][0]): continue
		if not library.has_animation(name):
			var stance: Animation = animator.get_animation(clips[WALKS[name][0]])
			var made: Animation = walk.duplicate(true)
			for track in made.get_track_count():
				if made.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
				var bone: String = String(made.track_get_path(track)).get_slice(":",1)
				if not (bone.begins_with("clavicle") or bone.begins_with("upperarm") or bone.begins_with("lowerarm") or bone.begins_with("hand")): continue
				var source = stance.find_track(made.track_get_path(track),Animation.TYPE_ROTATION_3D)
				if source < 0: continue
				var held: Quaternion = stance.rotation_track_interpolate(source,0.0)
				var share: float = WALKS[name][1][bone.right(1)]
				for key in made.track_get_key_count(track):
					made.track_set_key_value(track,key,made.track_get_key_value(track,key).slerp(held,share))
			library.add_animation(name,made)
		clips[name] = prefix+name

func equip(weapon: String) -> void:
	carry_in_hand = null
	if is_instance_valid(shield_attachment): shield_attachment.queue_free()
	shield_item = null
	bow_strings.clear()
	if is_instance_valid(nocked_arrow): nocked_arrow.queue_free()
	nocked_arrow = null
	weapon_kind = weapon
	weapon_item = null
	if is_instance_valid(sword_trail): sword_trail.queue_free()
	sword_trail = null
	if is_instance_valid(blade_charge): blade_charge.queue_free()
	blade_charge = null
	# The hero's hard cuts leave a wake behind the blade, and Ground Slam
	# charges it.
	if weapon == "sword" and not is_stone:
		sword_trail = SwordTrail.new()
		add_child(sword_trail)
		# (Carried on the blade once there is one.)
		blade_charge = BladeCharge.new()
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
	# The weapon hand (the bow hand for an archer) and a shield hand stay
	# closed on their grips.
	if grip != null:
		grip.hands = []
		if weapon in ["sword","axe","spear","staff"]: grip.hands.append("r")
		if weapon == "bow" or is_instance_valid(shield_item): grip.hands.append("l")
	if state in ["Idle","SwordIdle","ScutumSwordIdle","SpearShieldIdle","BowIdle","SpearIdle"]: play(idle_action())

# Clips in which an archer holds the bow out in the left hand, ready or
# shooting. Otherwise the ranger carries it at his side in the same left hand,
# through his own idle, run and crouch (the warrior's, with the left hand
# closed on the bow), so it never changes hands.
const BOW_READY_STATES = ["BowIdle","BowShot","BowRapid","ArcherShot"]
# How long the ranger takes to lower his bow arm after a shot, and to raise
# it from the carry when he shoots.
const BOW_LOWER_TIME = .45
var bow_lowering = 0.0
const BOW_RAISE_TIME = .16
var bow_raising = 0.0
# The bow's place in the left hand as the raise began.
var raise_from = null

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
	# (The Oracle's staff, or the hero wizard's, the same staff in silver.)
	if not is_instance_valid(weapon_item) or weapon_kind != "staff": return global_position+Vector3.UP*1.5
	return weapon_item.global_transform*Vector3(0,.93,0)

func oracle_staff_direction(phase: float) -> Vector2:
	var keys: Array = ORACLE_STAFF_KEYS if state=="OracleCast" else [[0.0,1.0,.08],[1.0,1.0,.08]]
	for i in keys.size()-1:
		var a: Array = keys[i]; var b: Array = keys[i+1]
		if phase <= b[0]:
			var u = smoothstep(0.0,1.0,(phase-a[0])/maxf(.001,b[0]-a[0]))
			return Vector2(lerpf(a[1],b[1],u),lerpf(a[2],b[2],u))
	return Vector2(keys[-1][1],keys[-1][2])

const STAFF_EASE = .05
var staff_lean = null
var staff_clock = 0.0
func align_oracle_staff() -> void:
	var facing = global_basis.orthonormalized()
	# Through the closed fist, not the wrist.
	var hand: Vector3 = bow_hold("r")[0]
	# The assigned clip, so a held (paused) pose keeps its staff angle and flame.
	var phase = 0.0
	if not animator.assigned_animation.is_empty():
		phase = animator.current_animation_position/maxf(.001,animator.get_animation(animator.assigned_animation).length)
	# The staff's lean follows the clip's, eased (STAFF_EASE seconds) so it
	# never leaps when the clip does (the nova starts at its swing).
	var wanted_lean = oracle_staff_direction(phase)
	var elapsed = anim_clock-staff_clock
	staff_clock = anim_clock
	if staff_lean == null or anim_clock <= 0.0: staff_lean = wanted_lean
	elif elapsed <= 0.0: pass
	else: staff_lean = staff_lean.lerp(wanted_lean,1.0-exp(-elapsed/STAFF_EASE))
	var lean: Vector2 = staff_lean
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
# Which way a strapped board faces out from the arm (set as it is strapped).
var strap_out = Vector3.ZERO
# Which way the shield arm reaches: out along the board, but eased toward
# it rather than following it frame by frame, as the board is turned by the
# arm, and reaching along it as it was turned it back and forth (a share of
# the way a second).
var reach_dir = Vector3.ZERO
const REACH_TURN = 10.0
# For a shield held in the hand: which way along the board's thin axis its
# face is, out from the body (+1 or -1; 0 until judged).
var shield_face_sign = 0.0
var strap_hold = .5

# The shield bearers' scutum is strapped flat along the left forearm, which
# they carry level across the front of the body: the board's back against
# the outside of the forearm, its middle over the middle of the forearm,
# upright, and facing out from the body as nearly the way they face as the
# forearm allows (out to the side when the forearm points ahead). Running,
# it tips forward with the body as it leans into the run (part of the way):
# held bolt upright, its top stood under the leaning chest and was pushed out
# far before the forearm.
const SHIELD_RUN_LEAN = .55
# How fast it takes up and gives up that lean (a share of it a second).
const SHIELD_LEAN_RATE = 4.0
var shield_lean = 0.0
var shield_lean_clock = 0.0
# The chest's own frame in the world: its forward (+Z), up (+Y) and side (+X)
# as the body faces at rest, turned with the upper spine.
func chest_basis() -> Basis:
	var bone = skeleton.find_bone("spine_03")
	var rest: Basis = skeleton.get_bone_global_rest(bone).basis.orthonormalized()
	var now: Basis = (skeleton.global_basis*skeleton.get_bone_global_pose(bone).basis).orthonormalized()
	return (now*rest.inverse()).orthonormalized()

func strap_scutum() -> void:
	var k = rig.scale.x
	var elbow = bone_position("lowerarm_l")
	var wrist = bone_position("hand_l")
	var forearm: Vector3 = (wrist-elbow).normalized()
	# It faces the way his chest turns (with his body as he twists), held
	# upright, as nearly as the forearm it is strapped along allows.
	var chest_front: Vector3 = chest_basis().z
	chest_front.y = 0.0
	var facing: Basis = global_basis.orthonormalized()
	if chest_front.length() > .2: facing = Basis(Vector3.UP.cross(chest_front.normalized()),Vector3.UP,chest_front.normalized())
	var lean_wanted = 1.0 if state in LOCOMOTION else 0.0
	if anim_clock <= 0.0: shield_lean = lean_wanted
	else: shield_lean = move_toward(shield_lean,lean_wanted,clampf(anim_clock-shield_lean_clock,0.0,.05)*SHIELD_LEAN_RATE)
	shield_lean_clock = anim_clock
	if shield_lean > 0.0:
		# The chest's lean forward (about the side axis).
		var chest_up: Vector3 = chest_basis().y
		chest_up -= facing.x*chest_up.dot(facing.x)
		if chest_up.length() > .2:
			var pitch = facing.y.signed_angle_to(chest_up.normalized(),facing.x)
			facing = Basis(facing.x,pitch*SHIELD_RUN_LEAN*smoothstep(0.0,1.0,shield_lean))*facing
	var out: Vector3 = facing.z-forearm*facing.z.dot(forearm)
	if out.length() < .35: out = facing.x-forearm*facing.x.dot(forearm)
	out = out.normalized()
	strap_out = out
	var up: Vector3 = facing.y-out*facing.y.dot(out)
	if up.length() < .2: up = facing.y
	var side: Vector3 = up.normalized().cross(out).normalized()
	up = out.cross(side).normalized()
	var size: Vector3 = strap_size*k
	# The board's back bulges to half its depth behind its rim.
	var middle: Vector3 = elbow.lerp(wrist,.55)+out*(.045*k+size.z*.5)
	shield_item.global_transform = Transform3D(Basis(side*size.x,up*size.y,out*size.z),middle-up*size.y*strap_hold)
# What a shield is kept in front of, as capsules from bone to bone: the legs,
# the body and head (leaning into a run or a swing), the shield arm's own
# forearm and fist behind the board, and the weapon arm crossing behind it.
const SHIELD_LEG_CLEARANCE = [["thigh_l","calf_l",.1],["thigh_r","calf_r",.1],["calf_l","foot_l",.07],["calf_r","foot_r",.07],["pelvis","spine_03",.17],["spine_03","neck_01",.18],["neck_01","Head",.12],["clavicle_l","upperarm_l",.08],["upperarm_l","lowerarm_l",.06],["lowerarm_l","hand_l",.05],["hand_l","middle_02_l",.045],["upperarm_r","lowerarm_r",.065],["lowerarm_r","hand_r",.055]]

# A knee raised in a lunge or a stride would pass through a big shield held
# low, a head leaning into a run through its top, and a clenched fist through
# its middle; the shield stands off the forearm just far enough to keep them
# behind its board.
# Running, a strapped shield is carried out before the body by its arm
# (ShieldArm), clear of the rising knees: how far out the arm holds it now
# (metres), and the most it will. (Standing, striking or struck, the stance
# clips hold the shield in its guard, the board standing off the arm where
# the body comes into it.)
var shield_arm = null
var arm_out = 0.0
var arm_out_clock = 0.0
const ARM_OUT_MAX = .32
# How quickly the arm reaches out when the body comes into the board, and
# how quickly it eases back in when there is room (a share of the gap a
# second).
const ARM_OUT_REACH = 16.0
const ARM_OUT_EASE = 3.0
# And never faster than this (metres a second), so it cannot snap.
const ARM_OUT_SPEED = 4.0
# Where the body still comes into the board (the arm holding its guard, or
# at full reach), the board itself stands off the forearm: eased in and out
# the same way, so a fist or knee touching it for a moment nudges it rather
# than knocking it away and back.
var board_off = 0.0
var board_off_clock = 0.0
# (Out quickly, so the body never sinks into it; back slowly.)
const BOARD_OFF_REACH = 60.0
const BOARD_OFF_SPEED = 3.0
# The shield arm's own parts (which move with the board).
const SHIELD_ARM_BONES = ["clavicle_l","upperarm_l","lowerarm_l","hand_l"]

# Once the skeleton has shown a pose, the shield is placed only from the
# shown pose: placed between updates (a unit turning to face its target,
# frame after frame as it runs at it), it went to the bare animation's
# forearm without the shield arm's reach, and was drawn there, jumping back
# and forth between the two from one frame to the next.
var shield_shown = false

func keep_shield_off_legs() -> void:
	if shield_shown and not in_shown_pose: return
	if in_shown_pose: shield_shown = true
	if shield_arm != null and not strapped: shield_arm.reach = Vector3.ZERO
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
	# Outward: away from the body behind it. A strapped board faces the way it
	# was strapped. A held one is judged by the body, but only while the body
	# is plainly behind it, and then kept: carried at the side, the spine is
	# nearly level with the board, and judged every frame the answer flipped
	# with each nudge, pushing the board off one face and then the other.
	if strapped and strap_out != Vector3.ZERO:
		if normal.dot(strap_out) < 0: normal = -normal
	else:
		var behind: float = normal.dot(centre-bone_position("spine_02"))
		if shield_face_sign == 0.0 or absf(behind) > .08*rig.scale.x: shield_face_sign = signf(behind) if behind != 0.0 else 1.0
		normal *= shield_face_sign
	var half_thick = shield_box.size[thin]*t.basis[thin].length()*.5
	var k = rig.scale.x
	var push = 0.0
	# The same for the body alone (not the shield arm, which moves with the
	# board), and how much room it leaves behind the board.
	var body_push = 0.0
	var room = INF
	for limb in SHIELD_LEG_CLEARANCE:
		var a = bone_position(limb[0]); var b = bone_position(limb[1])
		var r = limb[2]*k
		var own = limb[0] in SHIELD_ARM_BONES
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
			if depth > -r-half_thick and depth < r:
				push = maxf(push,depth+r+half_thick)
				if not own: body_push = maxf(body_push,depth+r+half_thick)
			elif depth <= -r-half_thick and not own: room = minf(room,-(depth+r+half_thick))
	# A strapped shield's arm carries it out as far as the body needs (and
	# back in as it leaves room), so the board stays on the forearm: judged
	# once a frame, from the body as shown with the arm's reach in it.
	if strapped and shield_arm != null and in_shown_pose:
		var wanted = clampf(arm_out+body_push if body_push > 0.0 else arm_out-room,0.0,ARM_OUT_MAX*k)
		if not state in LOCOMOTION: wanted = 0.0
		if anim_clock <= 0.0 or reach_dir == Vector3.ZERO:
			arm_out = wanted
			reach_dir = normal
		else:
			var elapsed = clampf(anim_clock-arm_out_clock,0.0,.05)
			var step = (wanted-arm_out)*(1.0-exp(-elapsed*(ARM_OUT_REACH if wanted > arm_out else ARM_OUT_EASE)))
			arm_out += clampf(step,-ARM_OUT_SPEED*k*elapsed,ARM_OUT_SPEED*k*elapsed)
			reach_dir = reach_dir.lerp(normal,1.0-exp(-elapsed*REACH_TURN)).normalized()
		arm_out_clock = anim_clock
		shield_arm.reach = reach_dir*arm_out if not dead else Vector3.ZERO
	var off = minf(push,.3*k)
	if in_shown_pose:
		if anim_clock <= 0.0: board_off = off
		else:
			var elapsed = clampf(anim_clock-board_off_clock,0.0,.05)
			var step = (off-board_off)*(1.0-exp(-elapsed*(BOARD_OFF_REACH if off > board_off else ARM_OUT_EASE*2.0)))
			board_off += clampf(step,-BOARD_OFF_SPEED*k*elapsed,BOARD_OFF_SPEED*k*elapsed)
		board_off_clock = anim_clock
	if board_off > 0.0: shield_item.global_position += normal*board_off

# The sword's place in the hand, as equipped.
var weapon_rest = Transform3D()

# A sword carried low beside a strapped scutum would swing its blade through
# the board as the bearer runs: it turns about the fist, out to the bearer's
# right, just far enough to pass beside the board instead.
#
# The turn is followed smoothly (BLADE_DODGE_RATE radians a second at most),
# so the blade never leaps aside or back.
const BLADE_DODGE_RATE = 6.0
var blade_dodge = Quaternion.IDENTITY
var blade_dodge_clock = 0.0
func keep_blade_off_shield() -> void:
	if not strapped or weapon_kind != "sword" or not is_instance_valid(weapon_item) or not is_instance_valid(shield_item): return
	weapon_item.transform = weapon_rest
	if not weapon_item.is_inside_tree(): return
	var grip: Vector3 = weapon_item.get_parent().global_position
	var right: Vector3 = -global_basis.x.normalized()
	var free: Transform3D = weapon_item.global_transform
	for step in 8:
		if not blade_in_board(): break
		var t: Transform3D = weapon_item.global_transform
		var tip: Vector3 = t*Vector3(0,1,0)-grip
		var turn = Basis(Vector3.UP,signf(Vector3.UP.dot(tip.cross(right)))*.12)
		weapon_item.global_transform = Transform3D(turn*t.basis,grip+turn*(t.origin-grip))
	var wanted: Quaternion = (weapon_item.global_basis.orthonormalized()*free.basis.orthonormalized().inverse()).get_rotation_quaternion()
	blade_dodge = follow(blade_dodge,wanted,minf(anim_clock-blade_dodge_clock,.05),BLADE_DODGE_RATE)
	blade_dodge_clock = anim_clock
	var shown_turn = Basis(blade_dodge)
	weapon_item.global_transform = Transform3D(shown_turn*free.basis,grip+shown_turn*(free.origin-grip))

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

# The skeleton has just posed the body as it is shown (its modifiers applied):
# the weapon and shield follow it, and the shield arm's reach is judged from
# it. (Called elsewhere, between updates, the bones read back as the bare
# animation, without the shield arm's reach.)
var in_shown_pose = false
func shown_pose_updated() -> void:
	in_shown_pose = true
	align_weapon()
	in_shown_pose = false
	# (Once the blade has followed the hand: its attachment moves after this.)
	if is_instance_valid(blade_charge) and (slam_u >= 0.0 or blade_charge.lit > 0.0): slam_strike_check.call_deferred()

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
		# Held level at the hip; raised overhand above the shoulder, it tips
		# down toward what it strikes.
		var fist: Vector3 = bow_hold("r")[0]
		var shoulder: Vector3 = bone_position("upperarm_r")
		var overhand = clampf((fist.y-shoulder.y)/(.3*rig.scale.x)+.5,0.0,1.0)
		weapon_item.global_basis = facing * Basis(Vector3.RIGHT,PI/2+SPEAR_DIP*overhand) * Basis.from_scale(weapon_size*rig.scale.x)
		# Through the closed fist, not the wrist.
		weapon_item.global_position = fist-weapon_item.global_basis.y.normalized()*.65*rig.scale.x
		keep_spear_clear(fist)
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
				# Turned about the grip, so it stays in the fist throughout.
				var carried_basis: Basis = weapon_item.global_basis.orthonormalized()
				var carried_grip: Vector3 = weapon_item.global_transform*BOW_GRIP
				var turned = Basis(held_basis.get_rotation_quaternion().slerp(carried_basis.get_rotation_quaternion(),w))*Basis.from_scale(weapon_size*rig.scale.x)
				weapon_item.global_basis = turned
				weapon_item.global_position = hold[0].lerp(carried_grip,w)-turned*BOW_GRIP
			for string in bow_strings: string.mesh.set_blend_shape_value(string.index,0.0)
			if is_instance_valid(nocked_arrow): nocked_arrow.visible = false
			# Carried, it needs no turn to clear the legs; raised again, any
			# turn eases in from none.
			bow_dodge = Quaternion.IDENTITY
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
		if not carried:
			keep_bow_off_legs()
			# Raising it from the carry: it turns from the carried angle to the
			# held one over the raise, rather than switching at once.
			if bow_raising > 0 and raise_from != null:
				var w = 1.0-bow_raising/BOW_RAISE_TIME
				w = w*w*(3-2*w)
				var held_now: Transform3D = weapon_item.global_transform
				var from: Transform3D = hand_l*raise_from
				var scale_now: Vector3 = held_now.basis.get_scale()
				var turned = Basis(from.basis.orthonormalized().get_rotation_quaternion().slerp(held_now.basis.orthonormalized().get_rotation_quaternion(),w)).scaled_local(scale_now)
				# Turned about the grip, so it stays in the fist throughout.
				var grip_at: Vector3 = (from*BOW_GRIP).lerp(held_now*BOW_GRIP,w)
				weapon_item.global_transform = Transform3D(turned,grip_at-turned*BOW_GRIP)
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

# How far a spear held overhand tips down (radians).
const SPEAR_DIP = .2
# The spear keeps clear of its bearer's shield and legs, turning about the
# fist as needed; the turn is eased (SPEAR_DODGE_RATE radians a second).
const SPEAR_DODGE_RATE = 5.0
var spear_dodge = Quaternion.IDENTITY
var spear_dodge_clock = 0.0
func keep_spear_clear(fist: Vector3) -> void:
	var free: Transform3D = weapon_item.global_transform
	var best: Transform3D = free
	var gap = spear_gap(free)
	if gap < 0.0:
		var facing = global_basis.orthonormalized()
		var step = .12
		for attempt in 20:
			var found = best
			var found_gap = gap
			for axis in [facing.y,facing.x]:
				for turn_by in [-step,step]:
					var turn = Basis(axis.normalized(),turn_by)
					var turned = Transform3D(turn*best.basis,fist+turn*(best.origin-fist))
					# Still pointing ahead.
					if turned.basis.y.normalized().dot(facing.z) < .6: continue
					var g = spear_gap(turned)
					if g > found_gap:
						found = turned
						found_gap = g
			if found_gap <= gap: step *= .5
			else:
				best = found
				gap = found_gap
			if gap >= 0.0: break
	var wanted: Quaternion = (best.basis.orthonormalized()*free.basis.orthonormalized().inverse()).get_rotation_quaternion()
	spear_dodge = follow(spear_dodge,wanted,minf(anim_clock-spear_dodge_clock,.05),SPEAR_DODGE_RATE)
	spear_dodge_clock = anim_clock
	var shown = Basis(spear_dodge)
	weapon_item.global_transform = Transform3D(shown*free.basis,fist+shown*(free.origin-fist))

# How far the spear at `t` stands clear of its bearer's shield board and legs
# (negative: into them), sampled along its shaft.
func spear_gap(t: Transform3D) -> float:
	var gap = INF
	var k = rig.scale.x
	var points = []
	for i in 13: points.append(t*Vector3(0,i/12.0,0))
	if is_instance_valid(shield_item) and strapped:
		var board: Transform3D = shield_item.global_transform
		var centre: Vector3 = board*Vector3(0,.5,0)
		for p in points:
			var depth = INF
			for axis in 3:
				var dir: Vector3 = board.basis[axis]
				var half = dir.length()*(.5 if axis != 2 else .3)+.02*k
				depth = minf(depth,half-absf((p-centre).dot(dir.normalized())))
			if depth > 0.0: gap = minf(gap,-depth)
	for limb in [["thigh_l","calf_l",.1],["thigh_r","calf_r",.1],["calf_l","foot_l",.07],["calf_r","foot_r",.07]]:
		var a = bone_position(limb[0]); var b = bone_position(limb[1])
		for i in 12:
			var closest = Geometry3D.get_closest_points_between_segments(points[i],points[i+1],a,b)
			gap = minf(gap,closest[0].distance_to(closest[1])-limb[2]*k)
	return gap if gap != INF else 1.0

# The legs a held bow keeps outside of, as capsules from bone to bone.
const BOW_LEG_CLEARANCE = [["thigh_l","calf_l",.1],["thigh_r","calf_r",.1],["calf_l","foot_l",.075],["calf_r","foot_r",.075]]

# A held bow swung low (raised to shoot from the side, or a statue's as it
# staggers) turns about the grip just enough to keep its limbs and string
# outside the legs, rather than through them: a few small turns are tried
# each way, keeping whichever clears the legs best, until they are clear. Its
# curved front stays within 10 degrees of where it faced while the archer
# stands or moves (53 as he staggers or raises it).
#
# The turn found is followed smoothly (BOW_DODGE_RATE radians a second at
# most), so the bow never leaps from one way of clearing the legs to another.
const BOW_DODGE_RATE = 7.0
var bow_dodge = Quaternion.IDENTITY
var bow_dodge_clock = 0.0
func keep_bow_off_legs() -> void:
	var free: Transform3D = weapon_item.global_transform
	var grip_free: Vector3 = free*BOW_GRIP
	var cleared: Transform3D = cleared_bow(free)
	var wanted: Quaternion = (cleared.basis.orthonormalized()*free.basis.orthonormalized().inverse()).get_rotation_quaternion()
	bow_dodge = follow(bow_dodge,wanted,minf(anim_clock-bow_dodge_clock,.05),BOW_DODGE_RATE)
	bow_dodge_clock = anim_clock
	var turn = Basis(bow_dodge)
	weapon_item.global_transform = Transform3D(turn*free.basis,grip_free+turn*(free.origin-grip_free))

# Turns `current` toward `wanted` by at most `rate` radians a second over
# `elapsed` seconds (none, if no time has passed since the last call). A unit
# posed without its clock running (a still picture) shows `wanted` at once.
func follow(current: Quaternion, wanted: Quaternion, elapsed: float, rate: float) -> Quaternion:
	if anim_clock <= 0.0: return wanted
	if elapsed <= 0.0: return current
	var angle = current.angle_to(wanted)
	if angle <= rate*elapsed: return wanted
	return current.slerp(wanted,rate*elapsed/angle)

# The held bow `t`, turned about its grip as needed to clear the legs.
func cleared_bow(t: Transform3D) -> Transform3D:
	var legs = []
	for limb in BOW_LEG_CLEARANCE: legs.append([bone_position(limb[0]),bone_position(limb[1]),limb[2]*rig.scale.x])
	var gap = bow_leg_gap(t,legs)
	if gap >= 0: return t
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
	return t

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
	if action in LOCOMOTION: locomotion_rate = speed_scale
	# Long enough that no part leaps into the new clip, short enough to stay
	# responsive; the feet stay planted through it (scripts/foot_planter.gd).
	var blend = clampf(duration*.15,.06,.14) if duration>0 else .14
	# Raising the carried bow to shoot: it turns from the carry to the hold.
	if ranger_carry() and not previous in BOW_READY_STATES and action in BOW_READY_STATES:
		bow_raising = BOW_RAISE_TIME
		blend = maxf(blend,BOW_RAISE_TIME)
		# From wherever it is in the hand now.
		if is_instance_valid(weapon_item) and weapon_item.is_inside_tree():
			var hand_now: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))
			raise_from = hand_now.affine_inverse()*weapon_item.global_transform
	# After a shot the ranger lowers his bow arm gradually, back to his side.
	if ranger_carry() and previous in BOW_READY_STATES and not action in BOW_READY_STATES:
		blend = BOW_LOWER_TIME
		bow_lowering = BOW_LOWER_TIME
	var replay = animator.assigned_animation == clips[action]
	travelled = 0.0
	animator.play(clips[action], blend, speed)
	# play() resumes an already assigned clip. Repeated attacks must each
	# start a fresh wind-up, even when the last recovery is still playing. A
	# new clip starts from its beginning anyway, and seeking it would cut the
	# crossfade from the last one short.
	if replay: animator.seek(0,true)
	animator.advance(0)
	if action == "Death": dead = true

# Carries straight on from the clip now playing into `action`, `start` (a
# fraction of it) in, without a crossfade: for a clip keyed to continue the
# last one's motion exactly (the sword chain's swings).
func play_on(action: String, duration: float, start: float) -> void:
	play(action,duration)
	if state != action: return
	animator.play(clips[action],0.0,animator.get_playing_speed())
	animator.seek(animator.current_animation_length*start,true)
	animator.advance(0)

# The wake behind the hero's blade as he cuts (scripts/sword_trail.gd).
var sword_trail: MeshInstance3D
# A skill's swing leaves the same wake where its blade cuts hard: moving
# faster than this (metres a second, at life size, its point measured against
# the body) in the stretch before the blow lands (SKILL_WAKE, shares of the
# clip before and after its contact). Wind-ups, a leap's spring and thrusts
# are slower or outside it, and leave none.
const SKILL_WAKE_SPEED = 15.0
const SKILL_WAKE = [.25,.05]
var blade_tip_was = null
# Ground Slam's charge on the blade (scripts/blade_charge.gd): how strong it
# is over the swing, as shares of the clip (forming as he raises the sword,
# surging as he drives it down, breaking off it as it meets the ground,
# fading after the blow).
var blade_charge: Node3D
var slam_struck = false
var slam_u = -1.0
# How near the ground (metres, at life size) the blade's point is when it
# strikes it.
const SLAM_POINT_DOWN = .3
# The blade's light is full above SLAM_LIGHT_HIGH (metres over the ground, at
# life size) and out by SLAM_LIGHT_LOW.
const SLAM_LIGHT_HIGH = 1.5
const SLAM_LIGHT_LOW = .5
const SLAM_RAISED = .36
const SLAM_GROUND = .40
const SLAM_BLOW = .52
const SLAM_FADED = .72

# Judged from the blade as it is shown (the skeleton just posed: the blade
# drops a metre in a frame as it is driven down, and judged a frame behind,
# its light lit the floor it had already reached): the charge breaks off where
# the blade's point comes down to the ground, and the blade's light fades as
# it comes down near the ground and is out once it strikes.
func slam_strike_check() -> void:
	if not is_instance_valid(blade_charge) or not blade_charge.is_inside_tree(): return
	var point_at: Vector3 = blade_charge.tip()
	if slam_u >= 0.0 and not slam_struck and slam_u >= SLAM_RAISED-.06 and slam_u <= SLAM_BLOW and point_at.y-global_position.y < SLAM_POINT_DOWN*rig.scale.x:
		slam_struck = true
		blade_charge.discharge(Vector3(point_at.x,global_position.y,point_at.z))
	var light_height: float = (blade_charge.light.global_position.y-global_position.y)/rig.scale.x
	blade_charge.shed_light(0.0 if slam_struck else slam_charge(slam_u)*clampf((light_height-SLAM_LIGHT_LOW)/(SLAM_LIGHT_HIGH-SLAM_LIGHT_LOW),0.0,1.0))

# How charged the blade is `u` of the way through Ground Slam's swing.
static func slam_charge(u: float) -> float:
	if u < 0.0: return 0.0
	if u < SLAM_RAISED: return .55*smoothstep(0.0,SLAM_RAISED,u)
	if u < SLAM_GROUND: return lerpf(.55,1.0,(u-SLAM_RAISED)/(SLAM_GROUND-SLAM_RAISED))
	if u < SLAM_BLOW: return 1.0
	return 1.0-smoothstep(SLAM_BLOW,SLAM_FADED,u)

# Where a skill's blow lands in its swing, as a share of its clip.
static var skill_contacts: Dictionary = {}
static func skill_contact(clip: String) -> float:
	if skill_contacts.is_empty():
		for swing in preload("res://scripts/skills.gd").WARRIOR_CLIPS.values(): skill_contacts[swing[0]] = swing[2]
	return skill_contacts.get(clip,-1.0)

# The sword chain (Motion.SWORD_CHAIN): whether one of its swings is still
# playing (its swing, or the recovery after it), and how far through the clip.
func swing_phase() -> float:
	if not (state.left(state.length()-1) in Motion.SWORD_CHAIN or state == Motion.SWORD_OPENER): return -1.0
	if not animator.is_playing() or animator.current_animation != clips.get(state,""): return -1.0
	return animator.current_animation_position/maxf(.001,animator.current_animation_length)

# Plays `action` from `start` (a fraction of it) on, crossfading into that
# moment of it rather than jumping there.
func play_from(action: String, duration: float, start: float) -> void:
	play(action,duration)
	if state == action: animator.seek(animator.current_animation_length*start,false)

# Flinch without interrupting anything: attacks, skills, evades and death
# replace a reaction through play(); locomotion resumes once it finishes.
func react(action: String, duration: float) -> void:
	if dead or not clips.has(action): return
	# With a shield the arm keeps it in place: the hero's round shield turned
	# outward as in his stance, a statue's strapped scutum held in its guard
	# against the chest.
	if strapped and clips.has("Scutum"+action): action = "Scutum"+action
	elif is_instance_valid(shield_item) and clips.has("Shield"+action): action = "Shield"+action
	play(action,duration)
	reaction_time = duration

# `settled` hides a statue already slain on load, without replaying its debris.
func crumble(settled: bool = false, impact: Vector3 = Vector3.ZERO) -> void:
	if crumbling >= 0.0: return
	dead = true
	state = "Crumble"
	animator.pause()
	crumbling = 0.0
	crumble_size = rig.scale.x
	var size = crumble_size
	crumble_base = global_position.y
	crumble_time = BLAST_CRUMBLE_TIME if impact.length()>4.0 else CRUMBLE_TIME
	if not settled:
		# The breaking stone is drawn by the statue's own copies of its
		# materials, which carry the break's front.
		var own: Dictionary = {}
		for mesh in find_children("*","MeshInstance3D",true,false):
			var finish = mesh.material_override
			if finish is ShaderMaterial and finish.shader == Art.statue_material().shader:
				if not own.has(finish):
					own[finish] = finish.duplicate()
					own[finish].set_shader_parameter("shatter_band",SHATTER_BAND*size)
					shattering.append(own[finish])
				mesh.material_override = own[finish]
			else: shattered_whole.append(mesh)
		var actor = get_parent()
		if actor.get("game") != null and actor.game.world.has_method("ensure_debris_collision"):
			actor.game.world.ensure_debris_collision()
		var seed = global_position.x*12.9898+global_position.z*78.233
		# With the temple already strewn with stone (many statues falling
		# together), it breaks into fewer, larger pieces.
		var crowded = StoneFragment.live+CHIPS > StoneFragment.BUDGET
		var count = CROWDED_CHIPS if crowded else CHIPS
		if StoneFragment.live+count > StoneFragment.LIMIT: count = SPARSE_CHIPS
		for piece in count:
			# Six staggered rings fill the body with stone. Spacing the chips
			# apart avoids an artificial explosion from overlapping colliders.
			var i = piece*(CHIPS/count+1)%CHIPS if crowded else piece
			var layer = floorf(i/6.0)
			var angle = TAU*(i%6)/6.0+layer*PI/6.0+fposmod(seed,TAU)
			var outward = Vector3(sin(angle),0,cos(angle))
			var diameter = (.18+.12*fposmod(seed*.37+i*.61,1.0))*size*(1.4 if crowded else 1.0)
			var start = global_position+(outward*.34+Vector3.UP*(.23+.29*layer))*size
			var scatter = outward*(.55+.45*fposmod(seed*.13+i*.29,1.0))*sqrt(size)
			var velocity = impact*(.85+.3*fposmod(i*.61,1.0))+scatter+Vector3.UP*.8*sqrt(size)
			var chip = StoneFragment.make(self,start,diameter,velocity,Vector3(cos(angle)*4,3,sin(angle)*4)*(1+i%3),crowded)
			chip.hold()
			chips.append(chip)
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
	crumble_step(crumble_time if settled else 0.0)

# The front's height: from the top ring of stone (whose fragments go at once)
# down past the feet, gathering speed as the statue gives way.
func shatter_front(u: float) -> float:
	var size = crumble_size
	var top = crumble_base+(1.68+SHATTER_BAND*.5)*size
	var bottom = crumble_base-SHATTER_BAND*size
	return lerpf(top,bottom,u*(.5+.5*u))

func crumble_step(dt: float) -> void:
	crumbling += dt
	var u = clampf(crumbling/crumble_time,0.0,1.0)
	var front = shatter_front(u)
	for finish in shattering: finish.set_shader_parameter("shatter_front",front)
	for mesh in shattered_whole:
		if is_instance_valid(mesh): mesh.visible = mesh.visible and mesh.global_position.y<front
	# Each fragment breaks loose as the front reaches the middle of the stone
	# that falls away around it.
	for chip in chips:
		if is_instance_valid(chip) and chip.held and chip.global_position.y+SHATTER_BAND*.5*crumble_size>=front: chip.release()
	rig.visible = u<1.0
	if is_instance_valid(nocked_arrow): nocked_arrow.visible = false
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
	# (A kilt hangs close round the hips; a cloak stands off them.)
	hips.radius = .1 if prefix == "kilt_" else .15
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

# The unit's own clock, for things smoothed over time between poses.
var anim_clock = 0.0

func advance(dt: float) -> void:
	anim_clock += dt
	turn_toward_facing(dt)
	cloak_tick(dt)
	bow_lowering = maxf(0.0,bow_lowering-dt)
	bow_raising = maxf(0.0,bow_raising-dt)
	if crumbling >= 0.0:
		if crumbling < crumble_time+1.5: crumble_step(dt)
		return
	reaction_time = maxf(0,reaction_time-dt)
	var held = minf(dt,animation_delay)
	animation_delay -= held
	if animator.is_playing():
		pending_animation_time += dt-held
		# Keep the clock while culled; update the pose when visible again.
		if animator.active:
			animator.advance(pending_animation_time)
			pending_animation_time = 0
	# Travel the clip carries the unit through since the last tick.
	if ROOT_ADVANCE.has(state) and animator.current_animation == clips.get(state,""):
		var u = animator.current_animation_position/maxf(.001,animator.current_animation_length)
		var now = sample_keys(ROOT_ADVANCE[state],u)*rig.scale.x
		pending_travel += maxf(0.0,now-travelled)
		travelled = now
	# How fast the body is carried over the ground (by the game or a dash).
	var at: Vector3 = global_position
	var moving = Vector3.ZERO
	if last_position != null and dt > 0:
		moving = Vector3(at.x-last_position.x,0,at.z-last_position.z)/dt
		ground_speed = moving.length()
	last_position = at
	if animator.active:
		# Feet stay planted unless the unit runs, dashes, leaps or falls.
		# (Knocked flat, it slides back along the ground instead.)
		var floored = state.ends_with("HitKnockdown")
		carry_hold = .25 if carried and not floored else maxf(0.0,carry_hold-dt)
		if planter != null:
			planter.enabled = not dead and not state in LOCOMOTION and (ground_speed < .6*rig.scale.x or ROOT_ADVANCE.has(state) or carry_hold > 0.0) and absf(position.y) < .01
			var parent = get_parent_node_3d()
			planter.ground = parent.global_position.y if parent != null else global_position.y
			planter.velocity = moving
			planter.carried = carried and not floored
			planter.owed = owed
			planter.shoved = shoved and not floored
		skeleton.advance(dt)
	if is_instance_valid(sword_trail) and is_instance_valid(weapon_item) and weapon_item.is_inside_tree():
		var swing = swing_phase()/Motion.SWORD_SWING_SHARE
		var cutting = not dead and Motion.sword_cuts(state) and swing >= Motion.SWORD_WAKE[0] and swing <= Motion.SWORD_WAKE[1]
		var blade: Transform3D = weapon_item.global_transform
		var tip: Vector3 = global_transform.affine_inverse()*(blade*Vector3(0,1.02,0))
		# A skill's swing: where its own clip is playing, how far through.
		var contact = skill_contact(state)
		var u = -1.0
		if contact >= 0.0 and animator.current_animation == clips.get(state,"") and animator.current_animation_length > 0.0:
			u = animator.current_animation_position/animator.current_animation_length
		if not cutting and u >= 0.0 and blade_tip_was != null and dt > 0.0:
			var speed: float = (tip-blade_tip_was).length()/dt/rig.scale.x
			cutting = not dead and speed > SKILL_WAKE_SPEED and u >= contact-SKILL_WAKE[0] and u <= contact+SKILL_WAKE[1]
		blade_tip_was = tip
		sword_trail.step(dt,cutting,blade*Vector3(0,.42,0),blade*Vector3(0,1.02,0))
		if is_instance_valid(blade_charge):
			if blade_charge.get_parent() != weapon_item: blade_charge.attach(weapon_item,.42,1.02)
			slam_u = u if state == "SkillSlam" and not dead else -1.0
			if slam_u < 0.0: slam_struck = false
			blade_charge.step(dt,slam_charge(slam_u))
			slam_strike_check()

# The forward travel to move the unit by since last asked (Actor.tick).
# How much further the current clip will carry the unit (not yet taken).
func travel_to_come() -> float:
	if not ROOT_ADVANCE.has(state): return 0.0
	var keys: Array = ROOT_ADVANCE[state]
	return maxf(0.0,keys[keys.size()-1][1]*rig.scale.x-travelled)+pending_travel

func take_travel() -> float:
	var d = pending_travel
	pending_travel = 0.0
	return d

# A curve through [fraction, value] keys, eased between them.
static func sample_keys(keys: Array, u: float) -> float:
	for i in keys.size()-1:
		if u <= keys[i+1][0]:
			var w = clampf((u-keys[i][0])/maxf(1e-4,keys[i+1][0]-keys[i][0]),0.0,1.0)
			return lerpf(keys[i][1],keys[i+1][1],w*w*(3.0-2.0*w))
	return keys[-1][1]

# The body turns toward the unit's facing (which the game sets at once):
# quickly, but never in a single frame.
func turn_toward_facing(dt: float) -> void:
	var parent = get_parent_node_3d()
	if parent == null: return
	var facing: float = parent.global_rotation.y
	if shown_yaw == null: shown_yaw = facing
	var gap = wrapf(facing-shown_yaw,-PI,PI)
	var step = clampf(gap*(1.0-exp(-dt/TURN_EASE)),-TURN_RATE*dt,TURN_RATE*dt)
	shown_yaw = wrapf(shown_yaw+step,-PI,PI)
	rotation.y = wrapf(shown_yaw-facing,-PI,PI)

# Called as the game turns the unit: the body keeps the way it faced until it
# turns there itself (turn_toward_facing).
func keep_facing() -> void:
	var parent = get_parent_node_3d()
	if parent == null or shown_yaw == null: return
	rotation.y = wrapf(shown_yaw-parent.global_rotation.y,-PI,PI)

# Faces the unit's facing at once (placed, revived, or set up for a picture).
func snap_facing() -> void:
	shown_yaw = null
	rotation.y = 0

# `travel_speed`, when given, is how fast the unit moves over the ground
# (metres a second): the stride is played at that pace, so the planted foot
# keeps still on the ground rather than skating.
func locomotion(moving: bool, busy: bool, crouch: bool = false, speed_scale: float = 1.0, travel_speed: float = 0.0) -> void:
	if dead or busy or reaction_time>0: return
	var wanted = ("Crouch" if crouch else "Run") if moving else idle_action()
	if quadruped and moving: wanted = "Run"
	elif moving and walking and not crouch and clips.has("Walk") and (weapon_kind != "bow" or ranger_carry()):
		wanted = "Walk"
		if ranger_carry(): wanted = "RangerWalk"
		elif weapon_kind == "staff" and not is_stone: wanted = "WizardWalk"
		elif weapon_kind == "sword": wanted = "SwordWalk"
		if not clips.has(wanted): wanted = "Walk"
	elif moving and ranger_carry(): wanted = "RangerCrouch" if crouch else "RangerRun"
	elif moving and weapon_kind=="staff" and not is_stone: wanted = "WizardCrouch" if crouch else "WizardRun"
	elif moving and weapon_kind=="bow": wanted = "BowCrouch" if crouch else "BowRun"
	# Carry the sword low while running so the blade never swings through the head.
	# Shield bearers keep the tall shield held upright while they run.
	elif moving and not crouch and enemy_kind in SHIELD_BEARERS and clips.has("ScutumRun"): wanted = "ScutumRun"
	elif moving and not crouch and weapon_kind=="sword" and clips.has("SwordRun"): wanted = "SwordRun"
	var rate = clampf(speed_scale, .1, 4.0)
	# (A negative speed walks backward: the stride plays in reverse.)
	if moving and travel_speed != 0.0 and STRIDE_SPEED.has(wanted):
		var pace = travel_speed/((LION_STRIDE_SPEED if quadruped else STRIDE_SPEED[wanted])*rig.scale.x)
		rate = signf(pace)*clampf(absf(pace),.3,2.5)
	if wanted != state:
		play(wanted,0.0,rate)
	elif wanted in LOCOMOTION and not is_equal_approx(rate,locomotion_rate):
		# Same stride at a new pace: the cycle carries on, faster or slower.
		animator.play(clips[wanted],-1,rate)
		locomotion_rate = rate
