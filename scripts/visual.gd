extends Node3D
const Art = preload("res://scripts/assets.gd")
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
const BOW_GRIP = Vector3(-.42,.51,0)
const BOW_PALM = Vector3(0,.065,0)
# Imported left-hand axes to the bow's grip: +Y along the stave, -X forward.
const BOW_HAND_BASIS = Basis(Vector3(0,-1,0),Vector3(0,0,1),Vector3(-1,0,0))

func setup(stone: bool, tint: Color, weapon: String, stature: float = 1.0) -> void:
	rig = load("res://assets/models/character/guardian.glb" if stone else "res://assets/models/character/warrior.glb").instantiate()
	# The supplied Godot rig faces +Z, matching Actor.forward().
	rig.rotation.y = 0
	rig.scale = Vector3.ONE * stature
	add_child(rig)
	animator = rig.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		skin_meshes.append(mesh)
		if stone:
			mesh.material_override = Art.material("marble", tint)
		elif "SuperHero" in mesh.name:
			# Keep supplied head/skin surfaces; armor only on the torso/limb mesh.
			var skin = StandardMaterial3D.new()
			skin.albedo_texture = load("res://assets/textures/hero_skin.png")
			skin.roughness = .65
			mesh.material_override = skin
	for clip in animator.get_animation_list():
		for expected in ["Idle","Run","Attack","Cleave","Evade","Death","Cast","Thrust","Crouch","Hit","SwordSwing","SwordSlash","AxeChop","AxeWhirl","SpearStab","SpearJab","BowShot","BowRapid","BowIdle","BowRun","BowCrouch","SpearIdle"]:
			if clip == expected or clip.ends_with("/" + expected):
				clips[expected] = clip
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if expected in ["Idle","Run","Crouch","BowIdle","BowRun","BowCrouch","SpearIdle"] else Animation.LOOP_NONE
	skeleton.skeleton_updated.connect(align_weapon)
	equip(weapon)
	play(idle_action())

func equip(weapon: String) -> void:
	if is_instance_valid(shield_attachment): shield_attachment.queue_free()
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
	var sizes = {"sword":Vector3(.15,1.0,.07),"spear":Vector3(.14,2.3,.09),"axe":Vector3(.55,1.25,.12),"bow":Vector3(.25,1.3,.10),"staff":Vector3(.32,1.9,.22)}
	weapon_size = sizes[weapon]
	var item = Art.model(weapon, weapon_size)
	weapon_item = item
	hand.add_child(item)
	# Model +Y runs along the weapon; align to the hand's local +Z grip axis.
	item.rotation.x = PI / 2
	item.position = Vector3(0,.075,-.17 if weapon != "bow" else -.55)
	if weapon in ["spear","bow"]:
		item.top_level = true
		if weapon == "bow":
			for mesh in item.find_children("*","MeshInstance3D",true,false):
				for i in mesh.mesh.get_blend_shape_count():
					if mesh.mesh.get_blend_shape_name(i)=="Draw": bow_strings.append({"mesh":mesh,"index":i})
			nocked_arrow = Art.model("arrow",Vector3(.035,.85,.035))
			add_child(nocked_arrow)
			nocked_arrow.top_level = true
			nocked_arrow.visible = false
		align_weapon()
	if weapon=="sword":
		shield_attachment = BoneAttachment3D.new()
		shield_attachment.bone_name = "hand_l"
		skeleton.add_child(shield_attachment)
		var shield = Art.model("shield",Vector3(.48,.62,.12))
		shield_attachment.add_child(shield)
		shield.position = Vector3(0,.05,0)
	if state in ["Idle","BowIdle","SpearIdle"]: play(idle_action())

func idle_action() -> String:
	var wanted = {"bow":"BowIdle","spear":"SpearIdle"}.get(weapon_kind,"Idle")
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
	var c = Art.model("crown", Vector3(.47,.24,.47), Art.material("gold"))
	attachment.add_child(c)
	c.position = Vector3(0,.16,0)

func petrify() -> void:
	for mesh in skin_meshes: mesh.material_override = Art.material("marble")
	animator.pause()

func play(action: String, duration: float = 0.0) -> void:
	if dead or not clips.has(action): return
	state = action
	var speed = animator.get_animation(clips[action]).length / duration if duration > 0 else 1.0
	animator.play(clips[action], .08, speed)
	animator.advance(0)
	if action == "Death": dead = true

func locomotion(moving: bool, busy: bool, crouch: bool = false) -> void:
	if dead or busy: return
	var wanted = ("Crouch" if crouch else "Run") if moving else idle_action()
	if moving and weapon_kind=="bow": wanted = "BowCrouch" if crouch else "BowRun"
	if wanted != state: play(wanted)
