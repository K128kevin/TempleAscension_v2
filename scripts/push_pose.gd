extends RefCounted
## The hero set against a boulder (scripts/basement_puzzle.gd), after the
## pushing figure in the 2D game Boulders: bent forward from the waist into
## it (or leaning back from it, pulling), both arms out and his hands laid
## flat on the stone either side of its crown, his legs walking under him (the
## walk, played by Visual.locomotion). His weapon and shield are put away
## meanwhile. Built of the modifiers the townsfolk use (scripts/body_lean.gd,
## arm_reach.gd, flat_hand.gd), added to his skeleton after his clips.
const Lean = preload("res://scripts/body_lean.gd")
const Reach = preload("res://scripts/arm_reach.gd")
const Flat = preload("res://scripts/flat_hand.gd")
# How far he leans in pushing and back pulling (radians); how high up the
# stone his hands go (radians above its middle, round from him), and how far
# apart (radians either side of the line to him); how fast he settles into
# the pose and out of it (a second's share).
const PUSH_LEAN = .42
const PULL_LEAN = -.12
const HANDS_UP = .3
const HANDS_APART = .5
const EASE = 4.0
var visual
var lean
var arms: Array = []
var flats: Array = []
var weight = 0.0
var stowed = false

func _init(owner_visual) -> void:
	visual = owner_visual
	var skeleton: Skeleton3D = visual.skeleton
	lean = Lean.new()
	lean.name = "PushLean"
	skeleton.add_child(lean)
	for side in ["l","r"]:
		var arm = Reach.new()
		arm.name = "PushReach_"+side
		arm.side = side
		skeleton.add_child(arm)
		arms.append(arm)
	for side in ["l","r"]:
		var flat = Flat.new()
		flat.name = "PushFlat_"+side
		flat.side = side
		skeleton.add_child(flat)
		flats.append(flat)

# Each frame: set against the stone whose middle is at `middle` (radius
# `radius`) if `on`, pulling it if `pull`; eased in and out.
func update(dt: float, on: bool, middle: Vector3, radius: float, pull: bool) -> void:
	weight = move_toward(weight,1.0 if on else 0.0,dt*EASE)
	stow(weight > .05)
	lean.lean = (PULL_LEAN if pull else PUSH_LEAN)*smoothstep(0.0,1.0,weight)
	var skeleton: Skeleton3D = visual.skeleton
	var body: Node3D = visual.get_parent()
	var to_him: Vector3 = body.global_position-middle
	to_him.y = 0.0
	if to_him.length() < .01: to_him = -body.global_basis.z
	to_him = to_him.normalized()
	var across: Vector3 = Vector3.UP.cross(to_him).normalized()
	var to_skeleton: Basis = skeleton.global_basis.orthonormalized().inverse()
	for i in 2:
		var arm = arms[i]
		var flat = flats[i]
		arm.weight = smoothstep(0.0,1.0,weight)
		flat.weight = arm.weight
		if arm.weight <= 0.0: continue
		var hand: int = skeleton.find_bone("hand_"+arm.side)
		if hand < 0: continue
		if not arm.measured: arm.measure(skeleton,hand)
		# His left hand on his left of the stone, the right on his right (he
		# faces it, so his right is `across`), thumbs toward each other.
		var out: Vector3 = -across if arm.side == "l" else across
		var normal: Vector3 = (to_him*cos(HANDS_UP)+Vector3.UP*sin(HANDS_UP)).normalized()
		normal = (normal*cos(HANDS_APART)+out*sin(HANDS_APART)).normalized()
		arm.target = middle+normal*(radius+.03)
		# Palm to the stone, fingers up its curve.
		var up_curve: Vector3 = (Vector3.UP-normal*Vector3.UP.dot(normal)).normalized()
		var inward: Vector3 = -out
		arm.grip = skeleton.global_basis.orthonormalized()*arm.turned(to_skeleton*up_curve,to_skeleton*inward)

# His weapon and shield put away while his hands are on the stone.
func stow(away: bool) -> void:
	if away == stowed: return
	stowed = away
	for item in [visual.weapon_item,visual.shield_item,visual.off_item]:
		if is_instance_valid(item): item.visible = not away
	if is_instance_valid(visual.nocked_arrow) and away: visual.nocked_arrow.visible = false

func release() -> void:
	weight = 0.0
	lean.lean = 0.0
	for i in 2:
		arms[i].weight = 0.0
		flats[i].weight = 0.0
	stow(false)
