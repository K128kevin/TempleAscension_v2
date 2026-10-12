extends SceneTree
## Measures how the warrior's kilt (scripts/kilt_strips.gd) lies on his legs:
## the body and the kilt are skinned on the CPU, as drawn, and every point of
## the strips is tested against the body's own surface near it (its nearest
## point and that point's normal). Prints, over the frames sampled:
##   inside  the furthest any point of a strip goes in under the skin (m),
##           below its top quarter (hidden under the tabs) and anywhere, and
##           the share of those points more than 5 mm in
##   gap     over the legs (the worst strip, the mean and the median of the
##           strips: those between the legs hang clear of both), how far the strips' inner faces stand off the
##           thigh they hang over (the median of each strip's lower half,
##           the worst strip), only where a thigh is within 6 cm of it
##
##   Godot --headless --path . --script tools/kilt_check.gd -- --clip=SwordRun
##     [--seconds=2] [--every=4] (frames between samples) [--then=Idle]
##     [--then_seconds=1.5]  then that clip, measured too (standing after a run)
const Visual = preload("res://scripts/visual.gd")
func _initialize(): call_deferred("go")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback

class Skinned:
	var mesh: MeshInstance3D
	var verts: PackedVector3Array
	var normals: PackedVector3Array
	var bones: PackedInt32Array
	var weights: PackedFloat32Array
	var per = 4
	var bind_bone: Array = []
	func _init(m: MeshInstance3D, skeleton: Skeleton3D) -> void:
		mesh = m
		var arrays = m.mesh.surface_get_arrays(0)
		verts = arrays[Mesh.ARRAY_VERTEX]
		normals = arrays[Mesh.ARRAY_NORMAL]
		bones = PackedInt32Array(arrays[Mesh.ARRAY_BONES])
		weights = PackedFloat32Array(arrays[Mesh.ARRAY_WEIGHTS])
		per = bones.size()/verts.size()
		for i in m.skin.get_bind_count():
			var b: int = m.skin.get_bind_bone(i)
			if b < 0: b = skeleton.find_bone(m.skin.get_bind_name(i))
			bind_bone.append(b)
	# Positions and normals in the skeleton's space, for the vertices `which`,
	# the bones posed as `poses` has them (as drawn: after the modifiers).
	func pose(poses: Array, which: PackedInt32Array) -> Array:
		var mats: Array = []
		for i in bind_bone.size(): mats.append(poses[bind_bone[i]]*mesh.skin.get_bind_pose(i))
		var p = PackedVector3Array(); var n = PackedVector3Array()
		p.resize(which.size()); n.resize(which.size())
		for k in which.size():
			var v: int = which[k]
			var at = Vector3.ZERO; var nn = Vector3.ZERO
			for j in per:
				var w: float = weights[v*per+j]
				if w <= 0.0: continue
				var t: Transform3D = mats[bones[v*per+j]]
				at += (t*verts[v])*w
				nn += (t.basis*normals[v])*w
			p[k] = at; n[k] = nn.normalized()
		return [p,n]

func go():
	var stand = Node3D.new()
	root.add_child(stand)
	var actor = Visual.new()
	stand.add_child(actor)
	actor.setup(false,Color.WHITE,"",1.0,"","warrior")
	var skeleton: Skeleton3D = actor.skeleton
	var body := Skinned.new(actor.parts["SuperHero_Male"],skeleton)
	var kilt := Skinned.new(actor.parts["HeroKilt"],skeleton)
	# The body near the kilt: below the belt, above the knees.
	var near_kilt = PackedInt32Array()
	var thighish = {}
	# (What carries each: a leg's bone, the hips, a hand...)
	var part_of: Array = []
	var rests: Array = []
	for b in skeleton.get_bone_count(): rests.append(skeleton.get_bone_global_rest(b))
	var rest_pose: Array = body.pose(rests,PackedInt32Array(range(body.verts.size())))
	# The pose as drawn, taken once the modifiers (the kilt among them) are done.
	var drawn: Array = []
	skeleton.skeleton_updated.connect(func():
		drawn.clear()
		for b in skeleton.get_bone_count(): drawn.append(skeleton.get_bone_global_pose(b)))
	var thigh_bones = [skeleton.find_bone("thigh_l"),skeleton.find_bone("thigh_r")]
	for v in body.verts.size():
		var y: float = rest_pose[0][v].y
		if y < .35 or y > 1.02: continue
		var best = -1; var bw = 0.0
		for j in body.per:
			if body.weights[v*body.per+j] > bw: bw = body.weights[v*body.per+j]; best = body.bind_bone[body.bones[v*body.per+j]]
		near_kilt.append(v)
		if best in thigh_bones: thighish[near_kilt.size()-1] = true
		part_of.append(skeleton.get_bone_name(best).trim_suffix("_l").trim_suffix("_r") if best >= 0 else "?")
	# The strips' faces: the long strips only (the tabs lie on them), front and
	# inner faces both (U under 250 the outer face, else the inner and edges).
	var karr = kilt.mesh.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = karr[Mesh.ARRAY_TEX_UV]
	var strip_points = PackedInt32Array()
	var strip_of = PackedInt32Array()
	var down_share = PackedFloat32Array()
	var across_share = PackedFloat32Array()
	var inner = []
	for v in kilt.verts.size():
		var code: float = uv[v].x-(500.0 if uv[v].x > 250.0 else 0.0)
		var strip = int(floor(code+.0001))
		if strip >= 18: continue
		strip_points.append(v); strip_of.append(strip); down_share.append(1.0-uv[v].y); across_share.append(code-strip)
		inner.append(uv[v].x > 250.0)
	var clip = arg("clip","Idle")
	var seconds = float(arg("seconds","2"))
	var every = int(arg("every","4"))
	var plan = [[clip,seconds]]
	if arg("then","") != "": plan.append([arg("then",""),float(arg("then_seconds","1.5"))])
	var worst_in = 0.0; var worst_in_at = ""
	var worst_seen = 0.0; var worst_seen_at = ""
	var seen = 0; var sunk = 0
	var gaps: Dictionary = {}
	var frames = 0
	for step in plan:
		if not actor.clips.has(step[0]): print("NO CLIP ",step[0]); continue
		actor.state = step[0]
		actor.animator.play(actor.clips[step[0]],.15)
		for f in int(step[1]*60):
			# (Carried along at a run's pace, so the air pushes as in the game.)
			if step[0].contains("Run"): stand.position.z += 6.0/60.0
			actor.advance(1.0/60.0)
			await process_frame
			if f % every != 0 or f < 20: continue
			frames += 1
			if drawn.is_empty(): continue
			var b: Array = body.pose(drawn,near_kilt)
			var k: Array = kilt.pose(drawn,strip_points)
			# A grid of the body's points, 3 cm cells.
			var grid = {}
			for i in near_kilt.size():
				var c = Vector3i((b[0][i]/.03).floor())
				if not grid.has(c): grid[c] = []
				grid[c].append(i)
			var per_strip = {}
			for i in strip_points.size():
				var p: Vector3 = k[0][i]
				var c = Vector3i((p/.03).floor())
				var best = -1; var bd = 1e9
				for dx in [-3,-2,-1,0,1,2,3]:
					for dy in [-3,-2,-1,0,1,2,3]:
						for dz in [-3,-2,-1,0,1,2,3]:
							for j in grid.get(c+Vector3i(dx,dy,dz),[]):
								var d = p.distance_squared_to(b[0][j])
								if d < bd: bd = d; best = j
				if best < 0: continue
				var depth: float = (p-b[0][best]).dot(b[1][best])
				# (Under the tabs, the top quarter of a strip is not seen.)
				if down_share[i] > .25:
					seen += 1
					if depth < -.005: sunk += 1
					if -depth > worst_seen:
						worst_seen = -depth
						worst_seen_at = "%s t=%.2f strip %d down %.2f across %.2f %s, under %s" % [step[0],f/60.0,strip_of[i],down_share[i],across_share[i],"inner" if inner[i] else "outer",part_of[best]]
				if -depth > worst_in:
					worst_in = -depth
					worst_in_at = "%s t=%.2f strip %d down %.2f near %.3f %s" % [step[0],f/60.0,strip_of[i],down_share[i],sqrt(bd),"thigh" if thighish.has(best) else "hips"]
				if inner[i] and down_share[i] > .5 and thighish.has(best) and sqrt(bd) < .06:
					if not per_strip.has(strip_of[i]): per_strip[strip_of[i]] = []
					per_strip[strip_of[i]].append(depth)
			for s in per_strip:
				var d: Array = per_strip[s]
				d.sort()
				var median: float = d[d.size()/2]
				if not gaps.has(s): gaps[s] = []
				gaps[s].append(median)
	var worst_gap = 0.0; var mean_gap = 0.0; var n = 0
	var line = ""
	var means: Array = []
	for s in gaps:
		var g: Array = gaps[s]
		var m = 0.0
		for x in g: m += x
		m /= g.size()
		line += "%d:%.3f " % [s,m]
		worst_gap = maxf(worst_gap,m); mean_gap += m; n += 1
		means.append(m)
	print("KILT_CHECK %s frames %d | seen: inside max %.4f (%s), %.2f%% of points >5mm in | gap over thighs worst %.4f mean %.4f median strip %.4f | top quarter too: inside max %.4f (%s)" % [clip+("+"+arg("then","") if arg("then","") != "" else ""),frames,worst_seen,worst_seen_at,100.0*sunk/maxf(1,seen),worst_gap,mean_gap/maxf(1,n),median_of(means),worst_in,worst_in_at])
	print("KILT_GAPS ",line)
	quit()

static func median_of(values: Array) -> float:
	if values.is_empty(): return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size()/2]
