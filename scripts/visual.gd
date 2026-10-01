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
				mesh.material_override = Art.statue_material(true)
			else: mesh.material_override = Art.statue_material()
		elif "HeroBoots" in mesh.name:
			mesh.material_override = Art.leather()
		elif "HeroHelmet" in mesh.name:
			# The warrior's full helm, in bronze to match his scale armor.
			mesh.visible = hero_class == "warrior"
			mesh.material_override = Art.bronze()
		elif "RangerCloak" in mesh.name:
			# A dark green hooded cloak that folds over his legs rather than
			# letting them through (assets/shaders/cloak.gdshader).
			mesh.visible = hero_class == "ranger"
			var cloth = ShaderMaterial.new()
			cloth.shader = load("res://assets/shaders/cloak.gdshader")
			cloth.set_shader_parameter("cloth_color",Color(.1,.19,.1))
			mesh.material_override = cloth
			if hero_class == "ranger": cloak_mesh = mesh
		elif "WizardCape" in mesh.name:
			# The wizard's cape, swung and folded over his legs as the
			# ranger's cloak is, in his robe's deep blue.
			mesh.visible = hero_class == "wizard"
			var cape = ShaderMaterial.new()
			cape.shader = load("res://assets/shaders/cloak.gdshader")
			cape.set_shader_parameter("cloth_color",Color(.035,.05,.16))
			mesh.material_override = cape
			if hero_class == "wizard": cloak_mesh = mesh
		elif "WizardHood" in mesh.name or "WizardRobe" in mesh.name:
			mesh.visible = hero_class == "wizard"
			mesh.material_override = Art.cloth(Color(.035,.05,.16))
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
		for expected in ["Idle","Run","Attack","Cleave","Evade","Death","Cast","Thrust","Crouch","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","SpearLunge","ShieldStab","ArcherShot","OracleCast","ShieldHit","ShieldHitHead","ShieldHitStagger","ShieldHitKnockdown","Hit","HitHead","HitStagger","HitKnockdown","SwordSwing","SwordSlash","AxeChop","AxeWhirl","SpearStab","SpearJab","BowShot","BowRapid","BowIdle","BowRun","BowCrouch","SpearIdle"]:
			if clip == expected or clip.ends_with("/" + expected):
				clips[expected] = clip
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if expected in ["Idle","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","Run","Crouch","BowIdle","BowRun","BowCrouch","SpearIdle"] else Animation.LOOP_NONE
	skeleton.skeleton_updated.connect(align_weapon)
	if not stone and hero_class == "ranger": setup_cloak()
	elif not stone and hero_class == "wizard": setup_cloak("cape_")
	elif stone and skeleton.find_bone("cloak_0_0") >= 0:
		# A statue's stone cloth (the Crowned Statue's cape) swings and folds
		# over the legs as the ranger's cloak does; its stone material is its
		# own, to carry this statue's legs.
		for mesh in skin_meshes:
			if mesh.skin != null and mesh.material_override is ShaderMaterial:
				mesh.material_override = mesh.material_override.duplicate()
				cloak_mesh = mesh
		setup_cloak()
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
	var weapon_finish = Art.statue_material() if is_stone else (Art.sword_material() if weapon=="sword" else null)
	# The Oracle carries a slender staff crowned with a diamond (tools/prepare_staff.py).
	var oracle = weapon=="staff" and enemy_kind=="wizard"
	if oracle: weapon_size = ORACLE_STAFF_SIZE
	# The Crowned Statue wields a great sword.
	if weapon=="sword" and enemy_kind=="boss": weapon_size *= BOSS_SWORD_SCALE
	var item = Art.model("oracle_staff" if oracle else weapon, weapon_size,weapon_finish)
	weapon_item = item
	hand.add_child(item)
	# Model +Y runs along the weapon; align to the hand's local +Z grip axis.
	item.rotation.x = PI / 2
	# The grip sits a fixed share up each hilt; the larger sword's hilt is longer.
	item.position = Vector3(0,.075,{"bow":-.55,"sword":-.22}.get(weapon,-.17))
	if oracle:
		item.top_level = true
		oracle_staff_flame()
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
		var finish = Art.statue_material() if is_stone else Art.metal()
		var shield = Art.model("scutum" if scutum else "shield",TOWER_SIZE if tower else (SCUTUM_SIZE if scutum else SHIELD_SIZE),finish)
		shield_item = shield
		shield_attachment.add_child(shield)
		# The imported shield pivots at its bottom edge. Center its back against
		# the outer forearm, keeping the wrist inside its face rather than at a rim.
		if scutum: shield.basis = Basis(SCUTUM_ROTATION.normalized())*Basis.from_scale(TOWER_SIZE if tower else SCUTUM_SIZE)
		else: shield.rotation.y = PI
		shield.position = (SCUTUM_CENTER if scutum else SHIELD_CENTER)-shield.basis*Vector3(0,.5+(TOWER_DROP if tower else 0.0),0)
	if state in ["Idle","SwordIdle","ScutumSwordIdle","SpearShieldIdle","BowIdle","SpearIdle"]: play(idle_action())

# Clips in which an archer holds the bow out in the left hand, ready or
# shooting. Otherwise a hero carries it in the right hand, as the warrior
# carries his sword, through the warrior's own idle, run and crouch.
const BOW_READY_STATES = ["BowIdle","BowShot","BowRapid","ArcherShot"]

func carries_bow() -> bool:
	return not is_stone and weapon_kind == "bow" and not state in BOW_READY_STATES

func idle_action() -> String:
	if not is_stone and weapon_kind == "bow": return "Idle"
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
	weapon_item.global_position = hand-up*length*ORACLE_GRIP
	var glow = cast_glow(phase)
	oracle_flame.visible = glow>.01 and not dead
	if oracle_flame.visible:
		oracle_flame.global_position = staff_tip()
		oracle_flame.scale = Vector3.ONE*maxf(.05,glow)*rig.scale.x
		oracle_flame_light.light_energy = 2.2*glow

func align_weapon() -> void:
	if enemy_kind == "wizard" and weapon_kind == "staff" and is_instance_valid(weapon_item) and is_instance_valid(oracle_flame):
		if is_inside_tree() and skeleton.is_inside_tree() and weapon_item.is_inside_tree(): align_oracle_staff()
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
		var hand_r: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))
		if carried and carry_in_hand != null:
			# Fixed in the fist: the same place and angle in the hand always.
			weapon_item.global_transform = hand_r*carry_in_hand
			for string in bow_strings: string.mesh.set_blend_shape_value(string.index,0.0)
			if is_instance_valid(nocked_arrow): nocked_arrow.visible = false
			return
		var hold = bow_hold("r" if carried else "l")
		var up: Vector3 = hold[1]
		var front: Vector3
		if carried:
			# Carried, the bow is fixed in the fist and turns with the hand:
			# the stave along the knuckles, square to the forearm, and facing
			# the way the forearm runs, from elbow to wrist, as it would shoot.
			var forearm: Vector3 = (bone_position("hand_r")-bone_position("lowerarm_r")).normalized()
			up = (up-forearm*up.dot(forearm)).normalized().rotated(forearm,CARRY_ROLL)
			front = forearm
		else:
			# Held out, the bow's curved front faces the way he faces.
			front = (facing.z-up*facing.z.dot(up)).normalized()
		weapon_item.global_basis = Basis(-front,up,(-front).cross(up)) * Basis.from_scale(weapon_size*rig.scale.x)
		weapon_item.global_position = hold[0]-weapon_item.global_basis*BOW_GRIP
		# The grip is taken once, in the idle stance, and kept from then on.
		if carried and state == "Idle": carry_in_hand = hand_r.affine_inverse()*weapon_item.global_transform
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

# The carried bow's place in the right hand, taken from the idle stance.
var carry_in_hand = null

# The carried bow's stave turned a little about the forearm from the knuckle
# line, so its string clears the thigh when he crouches.
const CARRY_ROLL = 0.2

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
	state = action
	reaction_time = 0
	animation_delay = 0
	pending_animation_time = 0
	var speed = animator.get_animation(clips[action]).length / duration if duration > 0 else speed_scale
	if action in ["BowRun","SwordRun","ScutumRun"]: locomotion_rate = speed_scale
	animator.play(clips[action], minf(.08,duration*.1) if duration>0 else .08, speed)
	# play() resumes an already assigned clip. Repeated attacks must each
	# start a fresh wind-up, even when the last recovery is still playing.
	animator.seek(0,true)
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
var cloth_feel: Dictionary = CLOTH_LIGHT
const CLOAK_RUN_SPEED = 5.0
var cloak: SpringBoneSimulator3D
var cloak_mesh: MeshInstance3D
# The limbs the cloak's cloth may never pass through, as capsules from bone to
# bone with a radius a little over the limb's own (boots included).
const CLOAK_BODY_CAPSULES = [["thigh_l","calf_l",.105],["thigh_r","calf_r",.105],["calf_l","foot_l",.085],["calf_r","foot_r",.085],["foot_l","ball_l",.075],["foot_r","ball_r",.075]]
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
	for capsule in CLOAK_BODY_CAPSULES:
		a.append(to_mesh*skeleton.get_bone_global_pose(skeleton.find_bone(capsule[0])).origin)
		b.append(to_mesh*skeleton.get_bone_global_pose(skeleton.find_bone(capsule[1])).origin)
		# The mesh's own space is the rig's, before the rig's scale.
		r.append(capsule[2])
	var m: ShaderMaterial = cloak_mesh.material_override
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
	if moving and weapon_kind=="bow" and not is_stone: wanted = "Crouch" if crouch else ("SwordRun" if clips.has("SwordRun") else "Run")
	elif moving and weapon_kind=="bow": wanted = "BowCrouch" if crouch else "BowRun"
	# Carry the sword low while running so the blade never swings through the head.
	# Shield bearers keep the tall shield held upright while they run.
	elif moving and not crouch and enemy_kind in SHIELD_BEARERS and clips.has("ScutumRun"): wanted = "ScutumRun"
	elif moving and not crouch and weapon_kind=="sword" and clips.has("SwordRun"): wanted = "SwordRun"
	var rate = clampf(speed_scale, .1, 4.0)
	if wanted != state or (wanted in ["BowRun","SwordRun","ScutumRun"] and not is_equal_approx(rate,locomotion_rate)):
		play(wanted,0.0,rate)
