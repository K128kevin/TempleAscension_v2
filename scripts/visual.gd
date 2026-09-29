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
const BOW_GRIP = Vector3(-.42,.51,0)
const BOW_PALM = Vector3(0,.065,0)
# Imported left-hand axes to the bow's grip: +Y along the stave, -X forward.
const BOW_HAND_BASIS = Basis(Vector3(0,-1,0),Vector3(0,0,1),Vector3(-1,0,0))

func setup(stone: bool, _tint: Color, weapon: String, stature: float = 1.0, enemy_kind: String = "") -> void:
	is_stone = stone
	self.enemy_kind = enemy_kind
	var character = "guardian_%s" % enemy_kind if stone and enemy_kind in ["gladiator","archer","centurion","wizard"] else ("guardian" if stone else "warrior")
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
			mesh.material_override = Art.statue_material()
		elif "HeroBoots" in mesh.name:
			mesh.material_override = Art.leather()
		elif "HeroHelmet" in mesh.name:
			# Steel full helm, matching the shield.
			mesh.material_override = Art.metal()
		elif "Hair" in mesh.name:
			# The closed helm covers the hair.
			mesh.visible = false
		elif "SuperHero" in mesh.name or "HeroArmor" in mesh.name:
			# Keep supplied head/skin surfaces; armor only on the torso/limb mesh.
			var skin = StandardMaterial3D.new()
			skin.albedo_texture = load("res://assets/textures/hero_kit.png")
			skin.roughness = .65
			mesh.material_override = skin
	for clip in animator.get_animation_list():
		for expected in ["Idle","Run","Attack","Cleave","Evade","Death","Cast","Thrust","Crouch","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","SpearLunge","ShieldStab","ArcherShot","ShieldHit","ShieldHitHead","ShieldHitStagger","ShieldHitKnockdown","Hit","HitHead","HitStagger","HitKnockdown","SwordSwing","SwordSlash","AxeChop","AxeWhirl","SpearStab","SpearJab","BowShot","BowRapid","BowIdle","BowRun","BowCrouch","SpearIdle"]:
			if clip == expected or clip.ends_with("/" + expected):
				clips[expected] = clip
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if expected in ["Idle","SwordIdle","SwordRun","ScutumRun","ScutumSwordIdle","SpearShieldIdle","Run","Crouch","BowIdle","BowRun","BowCrouch","SpearIdle"] else Animation.LOOP_NONE
	skeleton.skeleton_updated.connect(align_weapon)
	equip(weapon)
	play(idle_action())

func equip(weapon: String) -> void:
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
	var item = Art.model(weapon, weapon_size,weapon_finish)
	weapon_item = item
	hand.add_child(item)
	# Model +Y runs along the weapon; align to the hand's local +Z grip axis.
	item.rotation.x = PI / 2
	# The grip sits a fixed share up each hilt; the larger sword's hilt is longer.
	item.position = Vector3(0,.075,{"bow":-.55,"sword":-.22}.get(weapon,-.17))
	if weapon in ["spear","bow"]:
		item.top_level = true
		if weapon == "bow":
			for mesh in item.find_children("*","MeshInstance3D",true,false):
				for i in mesh.mesh.get_blend_shape_count():
					if mesh.mesh.get_blend_shape_name(i)=="Draw": bow_strings.append({"mesh":mesh,"index":i})
			nocked_arrow = Art.model("arrow",Vector3(.035,.85,.035),Art.statue_material() if is_stone else null)
			add_child(nocked_arrow)
			nocked_arrow.top_level = true
			nocked_arrow.visible = false
		align_weapon()
	if weapon=="sword" or enemy_kind in SHIELD_BEARERS:
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

func idle_action() -> String:
	var wanted = {"bow":"BowIdle","spear":"SpearIdle","sword":"SwordIdle"}.get(weapon_kind,"Idle")
	if enemy_kind in SHIELD_BEARERS: wanted = "ScutumSwordIdle" if weapon_kind=="sword" else "SpearShieldIdle"
	return wanted if clips.has(wanted) else "Idle"

func draw_amount(t: float, release: float, start: float) -> float:
	if t<start or t>release+.06: return 0
	if t>release: return lerpf(1,0,(t-release)/.06)
	return smoothstep(start,release-.06,t)

func align_weapon() -> void:
	if weapon_kind not in ["spear","bow"] or not is_instance_valid(weapon_item): return
	if not is_inside_tree() or not skeleton.is_inside_tree() or not weapon_item.is_inside_tree(): return
	var facing = global_basis.orthonormalized()
	var hand_pose = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_l" if weapon_kind=="bow" else "hand_r"))
	if weapon_kind == "spear":
		weapon_item.global_basis = facing * Basis(Vector3.RIGHT,PI/2) * Basis.from_scale(weapon_size*rig.scale.x)
		weapon_item.global_position = hand_pose.origin-facing.z*.65*rig.scale.x
	else:
		# The wooden grip stays locked to the palm through locomotion and blends.
		# Dedicated bow poses orient the wrist, rather than overriding it here.
		weapon_item.global_basis = hand_pose.basis.orthonormalized() * BOW_HAND_BASIS * Basis.from_scale(weapon_size*rig.scale.x)
		weapon_item.global_position = hand_pose*BOW_PALM-weapon_item.global_basis*BOW_GRIP
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
		var right = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))
		if arrow_visible:
			# Match the actual baked hand during the pull, including animation blends.
			var nock = weapon_item.global_transform * Vector3(.5,.5,0)
			draw = clampf((nock-right.origin).dot(facing.z)/(.36*rig.scale.x),0.0,1.0)
		for string in bow_strings: string.mesh.set_blend_shape_value(string.index,draw)
		if is_instance_valid(nocked_arrow):
			nocked_arrow.visible = arrow_visible and not dead
			nocked_arrow.global_basis = facing * Basis(Vector3.RIGHT,-PI/2) * Basis.from_scale(Vector3(.035,.85,.035)*rig.scale.x)
			nocked_arrow.global_position = right.origin+facing.z*.85*rig.scale.x

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

func advance(dt: float) -> void:
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
	if moving and weapon_kind=="bow": wanted = "BowCrouch" if crouch else "BowRun"
	# Carry the sword low while running so the blade never swings through the head.
	# Shield bearers keep the tall shield held upright while they run.
	elif moving and not crouch and enemy_kind in SHIELD_BEARERS and clips.has("ScutumRun"): wanted = "ScutumRun"
	elif moving and not crouch and weapon_kind=="sword" and clips.has("SwordRun"): wanted = "SwordRun"
	var rate = clampf(speed_scale, .1, 4.0)
	if wanted != state or (wanted in ["BowRun","SwordRun","ScutumRun"] and not is_equal_approx(rate,locomotion_rate)):
		play(wanted,0.0,rate)
