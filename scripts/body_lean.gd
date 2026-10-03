extends SkeletonModifier3D
## A townsperson bending forward from the waist over his work (Orion, at his
## anvil: scripts/smith.gd): the spine is turned `lean` radians forward, half
## at each of its lower joints, before his arms reach (scripts/arm_reach.gd,
## which follow this in the skeleton), so the legs stay upright under him.
var lean = 0.0

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or absf(lean) < 1e-4: return
	for bone_name in ["spine_01","spine_02"]:
		var bone = skeleton.find_bone(bone_name)
		if bone < 0: continue
		var pose: Transform3D = skeleton.get_bone_global_pose(bone)
		# (The figure faces +Z: forward is a turn about +X.)
		skeleton.set_bone_global_pose(bone,Transform3D(Basis(Vector3.RIGHT,lean*.5)*pose.basis,pose.origin))
