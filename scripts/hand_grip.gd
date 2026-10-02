extends SkeletonModifier3D
## Keeps the hands that hold something closed round it, through every clip.
##
## The library's clips open the hands as they please (a flinch spreads the
## fingers, a cast opens the palm), which left a held sword or staff floating
## in an open hand. The weapon hand (the bow hand for an archer) and a shield
## bearer's shield hand are held in the fist they close round their grip in
## the stance clips; the other hand moves as animated (a caster's open palm,
## an archer's string fingers).
##
## Runs after the foot planter, on the unit's clock (scripts/visual.gd).

const FINGERS = ["thumb_01","thumb_02","thumb_03","index_01","index_02","index_03","middle_01","middle_02","middle_03","ring_01","ring_02","ring_03","pinky_01","pinky_02","pinky_03"]

# Which hands grip ("l", "r"), set by the unit's Visual as it equips.
var hands: Array = []
# Per hand: [[bone, fist rotation], ...].
var fists: Dictionary = {}

# Records the fingers' local rotations as the skeleton holds them now: a fist
# closed round a grip, for `side`.
func capture(skeleton: Skeleton3D, side: String) -> void:
	var fist = []
	for finger in FINGERS:
		var bone = skeleton.find_bone(finger+"_"+side)
		if bone >= 0: fist.append([bone,skeleton.get_bone_pose_rotation(bone)])
	fists[side] = fist

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null: return
	for side in hands:
		for pair in fists.get(side,[]):
			skeleton.set_bone_pose_rotation(pair[0],pair[1])
