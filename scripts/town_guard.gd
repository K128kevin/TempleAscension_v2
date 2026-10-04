extends Node3D
## A guard at one of the town's gates (scripts/world_town.gd): a man armored as
## the centurion statues are (tools/make_guard.py), at life size and in real
## steel, leather and wool. He stands his watch day and night, his spear
## grounded upright in his right fist and his shield stood on its foot at his
## left, his hand resting on its rim (scripts/arm_reach.gd holds each hand to
## its grip). He is no part of the town's round (scripts/townsfolk.gd): he
## never leaves his post.
const Art = preload("res://scripts/assets.gd")
const ArmReach = preload("res://scripts/arm_reach.gd")
# Measured from him (he faces +Z, his right toward -X): where his right fist
# closes on the spear, and where his shield stands, turned out to his left.
const SPEAR_FIST = Vector3(-.3,1.0,.24)
const SPEAR_SIZE = Vector3(.14,2.3,.09)
const SHIELD_AT = Vector3(.44,0,.2)
const SHIELD_SIZE = Vector3(.6,1.0,.2)
const SHIELD_TURN = .5
static var materials: Dictionary = {}

var figure: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var hands: Dictionary = {}
var spear: Node3D
var shield: Node3D

# `variant` (0…1) sets him apart from the next man: his armor's wear and where
# his breathing is when he is first seen.
func setup(variant: float) -> void:
	figure = load("res://assets/models/character/town_guard.glb").instantiate()
	add_child(figure)
	skeleton = figure.find_children("*","Skeleton3D",true,false)[0]
	animator = figure.find_children("*","AnimationPlayer",true,false)[0]
	var armor = ShaderMaterial.new()
	armor.shader = load("res://assets/shaders/guard_armor.gdshader")
	armor.set_shader_parameter("palette",load("res://assets/models/character/warrior_knight_texture.png"))
	armor.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	armor.set_shader_parameter("rest_pose",true)
	armor.set_shader_parameter("seed",variant)
	for mesh in skeleton.find_children("*","MeshInstance3D",true,false):
		var part: String = mesh.name
		if part == "Body": mesh.material_override = Art.hero_kit("warrior")
		elif part == "Eyes": mesh.material_override = shared("eyes")
		elif part == "Eyebrows": mesh.material_override = shared("brows")
		elif part.begins_with("Armor"):
			if mesh.mesh is ArrayMesh: mesh.mesh = Art.rest_pose_mesh(mesh.mesh)
			mesh.material_override = armor
		mesh.extra_cull_margin = 1.0
	# His spear, its butt on the ground below his fist.
	spear = Art.model("spear",SPEAR_SIZE,Art.arms_material(.84))
	add_child(spear)
	spear.position = Vector3(SPEAR_FIST.x,0,SPEAR_FIST.z)
	# His shield, stood on its foot, its face turned out to his left.
	shield = Art.model("scutum",SHIELD_SIZE)
	var board = ShaderMaterial.new()
	board.shader = load("res://assets/shaders/guard_shield.gdshader")
	board.set_shader_parameter("grit",load("res://assets/textures/rock_detail.jpg"))
	board.set_shader_parameter("size",SHIELD_SIZE)
	board.set_shader_parameter("seed",variant)
	for mesh in shield.find_children("*","MeshInstance3D",true,false): mesh.material_override = board
	add_child(shield)
	shield.basis = Basis(Vector3.UP,SHIELD_TURN)*Basis.from_scale(SHIELD_SIZE)
	shield.position = SHIELD_AT
	for side in ["l","r"]:
		var arm = ArmReach.new()
		arm.side = side
		arm.tool = true
		arm.curl = 1.0
		arm.weight = 1.0
		skeleton.add_child(arm)
		hands[side] = arm
	var clip = "Idle"
	animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.play(clip)
	animator.seek(variant*animator.get_animation(clip).length,true)

# The hands go to their grips wherever he stands (they are found in the
# world, so he must be placed first).
func _process(_delta: float) -> void:
	var frame: Transform3D = global_transform
	hands.r.target = frame*SPEAR_FIST
	hands.r.axis = frame.basis*Vector3.UP
	# On the middle of the shield's top rim, the fist round it.
	var rim: Basis = Basis(Vector3.UP,SHIELD_TURN)
	hands.l.target = frame*(SHIELD_AT+Vector3(0,SHIELD_SIZE.y+.02,0))
	hands.l.axis = frame.basis*(rim*Vector3.LEFT)

static func shared(kind: String) -> StandardMaterial3D:
	if materials.has(kind): return materials[kind]
	var m = StandardMaterial3D.new()
	if kind == "eyes":
		m.albedo_texture = load("res://assets/models/character/warrior_T_Eye_Brown.png")
		m.roughness = .3
	else:
		m.albedo_texture = load("res://assets/textures/hair_1.jpg")
		m.albedo_color = Color(.2,.14,.1)*2.2
		m.roughness = .6
	materials[kind] = m
	return m
