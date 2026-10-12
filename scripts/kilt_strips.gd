extends SkeletonModifier3D
## The warrior's war kilt (tools/warrior_kit.py): pteruges, strips of stiff
## leather hung from the lower edge of his belt, and a row of short tabs over
## their tops.
##
## Each long strip is three rigid pieces, one bone each (kilt_<i>, kilt_<i>_1,
## kilt_<i>_2; its end kilt_<i>_tip), bending only at two creases as stiff
## leather does, so it can lie over the bulge of a thigh and down its front
## without ever stretching: every piece keeps its length. Each piece swings
## toward hanging (partly with the hips' lean, partly straight down), damped,
## carried on by its own momentum as the hips sway and bob and pushed back by
## the air as he runs (`external_force`, set by the unit's Visual).
##
## His body holds the strips off it. It is fitted at setup from his own
## skinned mesh (fit_body): each thigh, the crease of each hip and the top
## of each calf is a tube round the bone that carries it, its
## outline every STATION metres along it and every 1/ANGLES of a turn round
## it the outermost of his flesh there (his surface, sampled across its
## faces).
## Every frame each piece, from the belt down, is laid where it swung, then
## turned out of the flesh about its crease (the deepest of its middle and
## end, and its edges near the flesh, pushed out along the flesh's normal)
## and, where a leg lies close under its face, laid down onto it, so the
## strips rest on his thighs instead of standing off them or passing through.
## A thigh raised up through a strip's hinge carries the hinge up onto it (it
## rides up off the belt, under the tab), so a strip in front of a rising
## knee is lifted and lies along the top of the thigh.
##
## The tabs (kilt_<18+i>, one piece each) lie over the tops of the two strips
## they hang between, lifted and turned as those are.
##
## Runs on the unit's clock, after the pose and the other modifiers
## (scripts/visual.gd setup_kilt). Its data is kept in flat packed arrays and
## nothing is allocated per frame: it is a cosmetic modifier on the hero.

# How hard a piece swings back toward hanging (per second squared, for each
# metre it is out), how quickly its swing dies away (per second), and how
# much it hangs straight down rather than with the hips' lean.
const SPRING = 55.0
const DAMPING = 8.0
const HANG = .6
# How much of its cut flare each piece keeps as it hangs.
const FLARE_KEPT = [1.0,.45,.2]
# The furthest the top piece may swing from hanging, how far a crease may
# bend, and how far in past hanging a piece may go (radians toward the body).
const MAX_SWING = 1.75
const MAX_BEND = .9
const INWARD = .25
# How far the strip's inner face lies behind its bone and how much clear of
# the skin it is kept. (Its width and curl are its own: piece_half,
# piece_sag.)
const THICKNESS = .0055
const CLEAR = .004
# A leg within this far under a piece's face draws it down onto it, this
# share of the way each frame, and turns it (twisting along its length, at
# most TWIST) to lie flat on it.
const SETTLE_REACH = .05
const SETTLE = .5
const TWIST = .6
const CREASE_TWIST = .25
# The furthest a hinge rides up off the belt.
const RIDE_MOST = .09
# The tubes' outlines: this far apart along them, this many round them.
const STATION = .015
const ANGLES = 32

# The air on the strips as he moves (an acceleration, in the world), set by
# the unit's Visual.
var external_force = Vector3.ZERO

var pelvis = -1
var settled = false
# The long strips, s: their hinges and outward ways in the hips' frame at
# rest, their cut flare; their pieces, s*3+k: bone, length, the way it hangs
# in the hips' frame at rest, its rest frame against the strip's; where its
# points are (s*4+k: the hinge, then each piece's end) and how fast they move.
var strip_count = 0
var hinge_rest := PackedVector3Array()
var out_rest := PackedVector3Array()
var flare := PackedFloat32Array()
var flare_cos := PackedFloat32Array()
var flare_sin := PackedFloat32Array()
var piece_bone := PackedInt32Array()
var piece_length := PackedFloat32Array()
var strip_length := PackedFloat32Array()
var piece_down := PackedVector3Array()
var piece_offset: Array[Basis] = []
# Each piece's half width at its end, and how far its edges there curl in
# behind its middle (the strips are cut curved round the hips).
var piece_half := PackedFloat32Array()
var piece_sag := PackedFloat32Array()
var points := PackedVector3Array()
var velocity := PackedVector3Array()
# The way each piece's face looks (s*3+k): out from the hips, or turned
# to lie flat on a leg under it.
var faces := PackedVector3Array()
# The tubes each strip may meet (s*TUBES_MOST+m; -1: none). (A leg steps
# across under the strips of the other side, so: every tube.)
var candidates := PackedInt32Array()
const TUBES_MOST = 6
# How clear of the flesh each piece was when last tested, and where its end
# was then: one well clear that has hardly moved is not tested again (but
# for every few frames).
var clearance := PackedFloat32Array()
var tested_at := PackedVector3Array()
var frame_number = 0
const RETEST = 4
# How far each strip's hinge has ridden up off the belt (the skeleton's space).
var ride := PackedVector3Array()
# The tabs, t: bone, the way it hangs and its rest frame in the hips' frame,
# where it hangs from, and the two strips (t*2, t*2+1) it lies over.
var tab_count = 0
var tab_bone := PackedInt32Array()
var tab_down := PackedVector3Array()
var tab_frame: Array[Basis] = []
var tab_hinge := PackedVector3Array()
var tab_under := PackedInt32Array()
# His body as tubes, n: the bone that carries it (and the one it is posed
# halfway toward, or -1), its frame at rest, its axis (start, way, length) and
# section axes in that frame, which can hold the flesh (thigh and hip: a hinge
# rides up on it), and where its outlines start in `sections` (ANGLES to each:
# how far out the flesh lies at each angle; 0: none there) and how many.
var tube_bone := PackedInt32Array()
var tube_with := PackedInt32Array()
var tube_rest: Array[Transform3D] = []
var tube_a := PackedVector3Array()
var tube_dir := PackedVector3Array()
var tube_e1 := PackedVector3Array()
var tube_e2 := PackedVector3Array()
var tube_length := PackedFloat32Array()
var tube_rides := PackedByteArray()
var tube_first := PackedInt32Array()
var tube_count := PackedInt32Array()
var sections := PackedFloat32Array()
# This frame: each tube's way into its frame and out of it, and a sphere
# round it.
var tube_in: Array[Transform3D] = []
var tube_out: Array[Basis] = []
var tube_start := PackedVector3Array()
var tube_end := PackedVector3Array()
var tube_axis := PackedVector3Array()
# The widest of each tube's flesh at each station (indexed as its outlines).
var station_widest := PackedFloat32Array()
var tube_widest := PackedFloat32Array()
# Of the last point tested: the way out of the flesh.
var normal = Vector3.ZERO
# (And the tube it was nearest, -1: none.)
var nearest_tube = -1
var one := PackedInt32Array([0])

static var fitted: Dictionary = {}

func setup(skeleton: Skeleton3D, body: MeshInstance3D = null) -> void:
	pelvis = skeleton.find_bone("pelvis")
	if pelvis < 0: return
	var pelvis_rest: Transform3D = skeleton.get_bone_global_rest(pelvis)
	var to_pelvis: Transform3D = pelvis_rest.affine_inverse()
	var i = 0
	var tabs: Array = []
	while skeleton.find_bone("kilt_%d" % i) >= 0:
		var chain: Array = [skeleton.find_bone("kilt_%d" % i)]
		for k in [1,2]:
			var b: int = skeleton.find_bone("kilt_%d_%d" % [i,k])
			if b >= 0: chain.append(b)
		var tip: int = skeleton.find_bone("kilt_%d_tip" % i)
		if tip < 0:
			i += 1
			continue
		var ends: Array = chain.duplicate()
		ends.append(tip)
		var hinge: Vector3 = to_pelvis*skeleton.get_bone_global_rest(chain[0]).origin
		var out: Vector3 = hinge-to_pelvis*pelvis_rest.origin
		if chain.size() == 1:
			tabs.append([chain[0],hinge,(to_pelvis*skeleton.get_bone_global_rest(tip).origin-hinge).normalized(),(to_pelvis*skeleton.get_bone_global_rest(chain[0])).basis])
			i += 1
			continue
		hinge_rest.append(hinge)
		out_rest.append(out.normalized())
		var level: Vector3 = pelvis_rest.basis*out
		level.y = 0
		var first: Vector3 = (to_pelvis*skeleton.get_bone_global_rest(ends[1]).origin-hinge).normalized()
		flare.append(asin(clampf((pelvis_rest.basis*first).normalized().dot(level.normalized()),-1.0,1.0)))
		for k in 3:
			var start: Vector3 = to_pelvis*skeleton.get_bone_global_rest(ends[k]).origin
			var finish: Vector3 = to_pelvis*skeleton.get_bone_global_rest(ends[k+1]).origin
			var down: Vector3 = (finish-start).normalized()
			piece_bone.append(ends[k])
			piece_length.append(start.distance_to(finish))
			piece_down.append(down)
			flare_cos.append(cos(flare[flare.size()-1]*FLARE_KEPT[k]))
			flare_sin.append(sin(flare[flare.size()-1]*FLARE_KEPT[k]))
			var across: Vector3 = down.cross(out.normalized()).normalized()
			piece_offset.append(Basis(across,down,across.cross(down).normalized()).inverse()*(to_pelvis*skeleton.get_bone_global_rest(ends[k])).basis)
		# (As tools/warrior_kit.py cuts them: 0.9 of the hips' girth over 18
		# strips at the top, a fifth wider at the hem, curled round the
		# hinge's distance from the hips' middle.)
		var round_hips: float = Vector2(hinge.x,hinge.z).length()
		var top_half: float = TAU*round_hips/18.0*.9*.5
		var so_far = 0.0
		var whole = 0.0
		for k in 3: whole += piece_length[piece_length.size()-3+k]
		for k in 3:
			so_far += piece_length[piece_length.size()-3+k]
			var half: float = top_half*(1.0+.22*so_far/whole)
			piece_half.append(half)
			piece_sag.append(half*half/(2.0*round_hips))
		strip_length.append(whole)
		for k in 4: points.append(Vector3.ZERO)
		for k in 3: velocity.append(Vector3.ZERO)
		for k in 3:
			faces.append(Vector3.ZERO)
			clearance.append(0.0)
			tested_at.append(Vector3.ZERO)
		ride.append(Vector3.ZERO)
		strip_count += 1
		i += 1
	# Each tab hangs between the middles of two strips (the next in order).
	for t in tabs.size():
		tab_bone.append(tabs[t][0]); tab_hinge.append(tabs[t][1]); tab_down.append(tabs[t][2]); tab_frame.append(tabs[t][3])
		tab_under.append(t % strip_count); tab_under.append((t+1) % strip_count)
	tab_count = tabs.size()
	if body != null: fit_body(skeleton,body)
	var pelvis_at: Transform3D = skeleton.get_bone_global_rest(pelvis)
	for s in strip_count:
		var m = 0
		for n in tube_bone.size():
			if true:
				candidates.append(n)
				m += 1
		for r in TUBES_MOST-m: candidates.append(-1)
	for n in tube_bone.size():
		tube_in.append(Transform3D()); tube_out.append(Basis()); tube_start.append(Vector3.ZERO); tube_end.append(Vector3.ZERO); tube_axis.append(Vector3.ZERO)
		var widest = 0.0
		for k in tube_count[n]*ANGLES: widest = maxf(widest,sections[tube_first[n]*ANGLES+k])
		tube_widest.append(widest)
	station_widest.resize(sections.size()/ANGLES)
	for k in station_widest.size():
		for j in ANGLES: station_widest[k] = maxf(station_widest[k],sections[k*ANGLES+j])
	# (Each station's the widest of it and its neighbours.)
	var widest_each := station_widest.duplicate()
	for n in tube_bone.size():
		for k in tube_count[n]:
			var at: int = tube_first[n]+k
			if k > 0: widest_each[at] = maxf(widest_each[at],station_widest[at-1])
			if k < tube_count[n]-1: widest_each[at] = maxf(widest_each[at],station_widest[at+1])
	station_widest = widest_each

# --- Fitting his body ---------------------------------------------------------

func fit_body(skeleton: Skeleton3D, body: MeshInstance3D) -> void:
	var below = 1e9
	for s in strip_count: below = minf(below,(skeleton.get_bone_global_rest(pelvis)*hinge_rest[s]).y-.012)
	var key = [body.mesh.get_rid(),below]
	if not fitted.has(key): fitted[key] = fit(skeleton,body,below)
	var made: Dictionary = fitted[key]
	for field in made: set(field,made[field])

# The tubes, from the body mesh at rest: each takes the vertices whose share
# carried by its bone(s) lies between `least` and `most`.
func fit(skeleton: Skeleton3D, body: MeshInstance3D, below: float) -> Dictionary:
	var arrays = body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size()/verts.size()
	var bind: Array = []
	for b in body.skin.get_bind_count():
		var bone: int = body.skin.get_bind_bone(b)
		if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(b))
		bind.append([bone,skeleton.get_bone_global_rest(bone)*body.skin.get_bind_pose(b)])
	var at = PackedVector3Array()
	var share: Array = []
	at.resize(verts.size())
	for v in verts.size():
		var p = Vector3.ZERO
		var carried = {}
		for j in per:
			var w: float = weights[v*per+j]
			if w <= 0.0: continue
			var b: Array = bind[int(bones[v*per+j])]
			p += (b[1]*verts[v])*w
			carried[b[0]] = carried.get(b[0],0.0)+w
		at[v] = p
		share.append(carried)
	# His surface, sampled across each face (its corners, the middles of its
	# edges, and points toward its middle), each sample carried as its face's
	# corners are on average.
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var samples = PackedVector3Array()
	var sample_share: Array = []
	var weights_at = [[1,0,0],[0,1,0],[0,0,1],[.5,.5,0],[0,.5,.5],[.5,0,.5],[.34,.33,.33],[.6,.2,.2],[.2,.6,.2],[.2,.2,.6]]
	for f in range(0,index.size(),3):
		var corner = [index[f],index[f+1],index[f+2]]
		if at[corner[0]].y < .3 and at[corner[1]].y < .3: continue
		var carried = {}
		for c in corner:
			for bone in share[c]: carried[bone] = carried.get(bone,0.0)+share[c][bone]/3.0
		for w in weights_at:
			samples.append(at[corner[0]]*w[0]+at[corner[1]]*w[1]+at[corner[2]]*w[2])
			sample_share.append(carried)
	at = samples
	share = sample_share
	var made = {"tube_bone":PackedInt32Array(),"tube_with":PackedInt32Array(),"tube_rest":[] as Array[Transform3D],"tube_a":PackedVector3Array(),
		"tube_dir":PackedVector3Array(),"tube_e1":PackedVector3Array(),"tube_e2":PackedVector3Array(),"tube_length":PackedFloat32Array(),
		"tube_rides":PackedByteArray(),"tube_first":PackedInt32Array(),"tube_count":PackedInt32Array(),"sections":PackedFloat32Array()}
	for side in ["l","r"]:
		var thigh: int = skeleton.find_bone("thigh_"+side)
		var calf: int = skeleton.find_bone("calf_"+side)
		var foot: int = skeleton.find_bone("foot_"+side)
		var hip: Vector3 = skeleton.get_bone_global_rest(thigh).origin
		var knee: Vector3 = skeleton.get_bone_global_rest(calf).origin
		var ankle: Vector3 = skeleton.get_bone_global_rest(foot).origin
		var along: Vector3 = (knee-hip).normalized()
		var shin: Vector3 = (ankle-knee).normalized()
		tube(made,skeleton,thigh,-1,hip,knee+along*.06,at,share,[thigh],.6,1.01,1e9,true)
		# The crease of the hip: the flesh carried partly by each, posed
		# halfway between them.
		tube(made,skeleton,thigh,pelvis,hip-along*.1,hip+along*.18,at,share,[thigh],.15,.6,1e9,true)
		tube(made,skeleton,calf,-1,knee-shin*.03,knee+shin*.2,at,share,[calf],.6,1.01,1e9,false)
	# (The hips' own flesh needs no tube: it moves with the hips the strips
	# hang from, and they are cut to clear it.)
	return made

func tube(made: Dictionary, skeleton: Skeleton3D, bone: int, with: int, from: Vector3, to: Vector3, at: PackedVector3Array, share: Array, carriers: Array, least: float, most: float, below: float, rides: bool) -> void:
	var rest: Transform3D = skeleton.get_bone_global_rest(bone)
	if with >= 0: rest = skeleton.get_bone_global_rest(with).interpolate_with(rest,.5)
	var frame: Transform3D = rest.affine_inverse()
	var a: Vector3 = frame*from
	var dir: Vector3 = frame*to-a
	var length: float = dir.length()
	dir /= length
	var e1: Vector3 = dir.cross(Vector3.FORWARD if absf(dir.z) < .9 else Vector3.RIGHT).normalized()
	var e2: Vector3 = dir.cross(e1)
	var count: int = int(length/STATION)+2
	var table := PackedFloat32Array()
	table.resize(count*ANGLES)
	for v in at.size():
		var carried = 0.0
		for c in carriers: carried += share[v].get(c,0.0)
		if carried < least or carried > most or at[v].y > below: continue
		var q: Vector3 = frame*at[v]-a
		var h: float = q.dot(dir)
		if h < -STATION or h > length+STATION: continue
		var x: float = q.dot(e1)
		var y: float = q.dot(e2)
		var r: float = sqrt(x*x+y*y)
		var j: int = posmod(int(round((atan2(y,x)+PI)/TAU*ANGLES)),ANGLES)
		var k: int = int(round(h/STATION))
		for kk in range(maxi(0,k-1),mini(count-1,k+1)+1):
			if r > table[kk*ANGLES+j]: table[kk*ANGLES+j] = r
	# Gaps of a few directions with no flesh are filled from either side;
	# wider ones are left open (between the legs, nothing).
	for k in count:
		var row := PackedFloat32Array()
		row.resize(ANGLES)
		for j in ANGLES: row[j] = table[k*ANGLES+j]
		for j in ANGLES:
			if row[j] > 0.0: continue
			var left = 1; var right = 1
			while left < 5 and row[posmod(j-left,ANGLES)] <= 0.0: left += 1
			while right < 5 and row[posmod(j+right,ANGLES)] <= 0.0: right += 1
			if left < 5 and right < 5:
				table[k*ANGLES+j] = (row[posmod(j-left,ANGLES)]*right+row[posmod(j+right,ANGLES)]*left)/(left+right)
	made.tube_bone.append(bone); made.tube_with.append(with); made.tube_rest.append(rest)
	made.tube_a.append(a); made.tube_dir.append(dir); made.tube_e1.append(e1); made.tube_e2.append(e2)
	made.tube_length.append((count-1)*STATION); made.tube_rides.append(1 if rides else 0)
	made.tube_first.append(made.sections.size()/ANGLES); made.tube_count.append(count)
	made.sections.append_array(table)

# How far `p` (the skeleton's space) lies out of tube `n`'s flesh (below 0:
# in it; 1e9: not beside it), and (in `normal`) the way out: square to its
# outline there.
func gap_at(p: Vector3, n: int) -> float:
	var q: Vector3 = tube_in[n]*p-tube_a[n]
	var h: float = q.dot(tube_dir[n])
	if h < 0.0 or h > tube_length[n]: return 1e9
	var e1: Vector3 = tube_e1[n]
	var e2: Vector3 = tube_e2[n]
	var x: float = q.dot(e1)
	var y: float = q.dot(e2)
	var f: float = h/STATION
	var k: int = mini(int(f),tube_count[n]-2)
	var u: float = f-k
	var g: float = fposmod((atan2(y,x)+PI)/TAU*ANGLES,ANGLES)
	var j: int = int(g)
	var w: float = g-j
	var j2: int = (j+1) % ANGLES
	var i0: int = (tube_first[n]+k)*ANGLES
	var i1: int = i0+ANGLES
	var r0: float = sections[i0+j]
	var r1: float = sections[i0+j2]
	var r2: float = sections[i1+j]
	var r3: float = sections[i1+j2]
	# (Toward an open direction: no flesh there; beside one, the flesh there is.)
	var nearest: float = (r3 if u > .5 else r1) if w > .5 else (r2 if u > .5 else r0)
	if nearest <= 0.0: return 1e9
	var most: float = maxf(maxf(r0,r1),maxf(r2,r3))
	if r0 <= 0.0: r0 = most
	if r1 <= 0.0: r1 = most
	if r2 <= 0.0: r2 = most
	if r3 <= 0.0: r3 = most
	var ra: float = lerpf(r0,r2,u)
	var rb: float = lerpf(r1,r3,u)
	var flesh: float = lerpf(ra,rb,w)
	var r: float = sqrt(x*x+y*y)
	if r < 1e-5:
		normal = tube_out[n]*e2
		return -flesh
	# Out square to the outline: radially, less its slope round the tube.
	var radial: Vector3 = (e1*x+e2*y)/r
	var round_way: Vector3 = (e2*x-e1*y)/r
	var slope: float = (rb-ra)*ANGLES/TAU
	normal = (tube_out[n]*(radial*flesh-round_way*slope)).normalized()
	return r-flesh

# The least gap of `p` to the tubes in `near` (its normal in `normal`): as
# gap_at, each tube's nearest outline only, written out for speed.
func least_gap(p: Vector3, near: PackedInt32Array, count: int) -> float:
	var best = 1e9
	nearest_tube = -1
	var bx = 0.0; var by = 0.0; var bflesh = 0.0; var bslope = 0.0
	for m in count:
		var n: int = near[m]
		var q: Vector3 = tube_in[n]*p-tube_a[n]
		var h: float = q.dot(tube_dir[n])
		if h < 0.0 or h > tube_length[n]: continue
		var x: float = q.dot(tube_e1[n])
		var y: float = q.dot(tube_e2[n])
		var g: float = (atan2(y,x)+PI)*ANGLES/TAU
		var j: int = int(g)
		var w: float = g-j
		var i0: int = (tube_first[n]+int(h/STATION+.5))*ANGLES
		var r0: float = sections[i0+j % ANGLES]
		var r1: float = sections[i0+(j+1) % ANGLES]
		if r0 <= 0.0 or r1 <= 0.0:
			if (r0 if w < .5 else r1) <= 0.0: continue
			r0 = maxf(r0,r1); r1 = r0
		var flesh: float = r0+(r1-r0)*w
		var gap: float = sqrt(x*x+y*y)-flesh
		if gap >= best: continue
		best = gap
		nearest_tube = n
		bx = x; by = y; bflesh = flesh; bslope = r1-r0
	if nearest_tube >= 0:
		# (Out square to the outline: radially, less its slope round the
		# tube.)
		var n: int = nearest_tube
		var r: float = maxf(sqrt(bx*bx+by*by),1e-5)
		var e1: Vector3 = tube_e1[n]
		var e2: Vector3 = tube_e2[n]
		normal = (tube_out[n]*((e1*bx+e2*by)*(bflesh/r)-(e2*bx-e1*by)*(bslope*ANGLES/TAU/r))).normalized()
	return best

# --- Every frame ---------------------------------------------------------------

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or pelvis < 0 or strip_count == 0: return
	var hips: Transform3D = skeleton.get_bone_global_pose(pelvis)
	hips.basis = hips.basis.orthonormalized()
	var hips_in: Transform3D = hips.affine_inverse()
	var turn: Basis = skeleton.global_basis.orthonormalized().inverse()
	var down: Vector3 = turn*Vector3.DOWN
	var air: Vector3 = turn*external_force
	var tubes: int = tube_bone.size()
	for n in tubes:
		var pose: Transform3D = skeleton.get_bone_global_pose(tube_bone[n])
		if tube_with[n] >= 0: pose = skeleton.get_bone_global_pose(tube_with[n]).interpolate_with(pose,.5)
		pose = Transform3D(pose.basis.orthonormalized(),pose.origin)
		tube_in[n] = pose.affine_inverse()
		tube_out[n] = pose.basis
		tube_start[n] = pose*tube_a[n]
		tube_end[n] = pose*(tube_a[n]+tube_dir[n]*tube_length[n])
		tube_axis[n] = (tube_end[n]-tube_start[n])/tube_length[n]
	var dt: float = clampf(delta,0.0,.05)
	frame_number += 1
	var count_here = 0
	var near := PackedInt32Array()
	near.resize(tubes)
	var close := PackedInt32Array()
	close.resize(tubes)
	for s in strip_count:
		var hinge: Vector3 = hips*hinge_rest[s]
		var out: Vector3 = (hips.basis*out_rest[s]).normalized()
		var level: Vector3 = out-down*out.dot(down)
		level = level.normalized()
		var length: float = strip_length[s]
		# The tubes it may touch.
		# (Between where it hangs now, from the hinge to its hem, and each
		# tube's axis.)
		var count = 0
		var hem: Vector3 = points[s*4+3]
		for c in TUBES_MOST:
			var n: int = candidates[s*TUBES_MOST+c]
			if n < 0: break
			var closest: PackedVector3Array = Geometry3D.get_closest_points_between_segments(hinge,hem,tube_start[n],tube_end[n])
			if closest[0].distance_to(closest[1]) < tube_widest[n]+SETTLE_REACH+.06:
				near[count] = n
				count += 1
		if not settled or points[s*4].distance_to(hinge+ride[s]) > .2:
			points[s*4] = hinge
			for k in 3:
				points[s*4+k+1] = points[s*4+k]+hang(s,k,hips,down,level)*piece_length[s*3+k]
				velocity[s*3+k] = Vector3.ZERO
			ride[s] = Vector3.ZERO
		# A thigh raised up through the hinge carries it up onto it.
		var lift = Vector3.ZERO
		var inner: Vector3 = hinge-out*THICKNESS
		var riders = 0
		for m in count:
			var n: int = near[m]
			if tube_rides[n] == 0: continue
			var d: Vector3 = inner-tube_start[n]
			var h: float = d.dot(tube_axis[n])
			if h < 0.0 or h > tube_length[n]: continue
			if (d-tube_axis[n]*h).length() > station_widest[tube_first[n]+mini(int(h/STATION+.5),tube_count[n]-1)]+CLEAR: continue
			close[riders] = n
			riders += 1
		if riders > 0:
			var g: float = least_gap(inner,close,riders)
			if g < CLEAR: lift = (normal*(CLEAR-g)).limit_length(RIDE_MOST)
		ride[s] = ride[s].lerp(lift,.6) if lift.length_squared() < ride[s].length_squared() else lift
		var start: Vector3 = hinge+ride[s]
		points[s*4] = start
		var before = Vector3.ZERO
		var face_above = Vector3.ZERO
		for k in 3:
			var i: int = s*3+k
			var piece: float = piece_length[i]
			var aim: Vector3 = (hips.basis*piece_down[i]).lerp(down*flare_cos[i]+level*flare_sin[i],HANG).normalized()
			if k == 0: before = aim
			var end: Vector3 = points[s*4+k+1]
			var was: Vector3 = end
			if dt > 0.0:
				var v: Vector3 = velocity[i]
				v += ((start+aim*piece-end)*SPRING+air-v*DAMPING)*dt
				end += v*dt
			var along: Vector3 = (end-start).normalized()
			# Not in past the way it hangs, toward his hips; not swung, nor
			# bent at its crease, further than it can go.
			var least: float = aim.dot(level)-INWARD
			if along.dot(level) < least: along = (along+level*(least-along.dot(level))).normalized()
			var limit: float = MAX_SWING if k == 0 else MAX_BEND
			var bent: float = along.angle_to(before)
			if bent > limit: along = before.slerp(along,limit/bent).normalized()
			# The flesh it may touch, then out of it, then down onto it.
			var middle: Vector3 = start+along*piece*.5
			var reach: float = piece*.5+SETTLE_REACH+.02
			var closer = 0
			var tip_now: Vector3 = start+along*piece
			var skip: bool = settled and (frame_number+s) % RETEST != 0 and clearance[i]-tip_now.distance_to(tested_at[i]) > SETTLE_REACH+.03
			if skip: count_here = 0
			else: count_here = count
			closer = count_here
			# (The edges' gaps from the tip's: off its tangent plane, the
			# flesh rising toward one edge as its normal leans across.)
			var face_now = Vector3.ZERO if not skip else faces[i]
			var pushed_from = -1
			if not skip: clearance[i] = 1e9
			for pass_ in 2:
				if closer == 0: break
				var across: Vector3 = along.cross(level)
				if across.length_squared() < 1e-6: across = level.cross(Vector3.UP)
				across = across.normalized()
				var face: Vector3 = across.cross(along)
				if face.dot(level) < 0.0: face = -face
				# (Checked again after a push: against the flesh it was
				# pushed out of.)
				var tip_gap: float
				if pass_ == 0 or pushed_from < 0:
					tip_gap = least_gap(start+along*piece-face*THICKNESS,near,closer)
				else:
					one[0] = pushed_from
					tip_gap = least_gap(start+along*piece-face*THICKNESS,one,1)
				var tip_normal: Vector3 = normal
				var tip_tube: int = nearest_tube
				if tip_gap < SETTLE_REACH and tip_normal.dot(face) > .3:
					# Turned to lie flat on the leg under it.
					var flat: Vector3 = tip_normal-along*tip_normal.dot(along)
					if flat.length_squared() > 1e-6:
						flat = flat.normalized()
						var turn_by: float = face.angle_to(flat)
						if turn_by > TWIST: flat = face.slerp(flat,TWIST/turn_by).normalized()
						# (Nor much more than the piece above it: a strip
						# twists gradually, its creases do not shear.)
						if k > 0 and face_above != Vector3.ZERO:
							var above: Vector3 = face_above-along*face_above.dot(along)
							if above.length_squared() > 1e-6:
								above = above.normalized()
								var off: float = above.angle_to(flat)
								if off > CREASE_TWIST: flat = above.slerp(flat,CREASE_TWIST/off).normalized()
						face = flat
						across = along.cross(face).normalized()
						face_now = face
				var worst: float = CLEAR-(tip_gap-piece_half[i]*absf(tip_normal.dot(across))-piece_sag[i])
				var push: Vector3 = tip_normal*worst
				# (Its middle, which may lie over a bulge between its ends.)
				var mid_gap = 1e9
				if k == 0 and pass_ == 0:
					mid_gap = least_gap(start+along*piece*.5-face*THICKNESS,near,closer)
				elif tip_tube >= 0 and (k == 0 or tip_gap < SETTLE_REACH):
					# (Below, the flesh under its tip is the flesh under it.)
					one[0] = tip_tube
					mid_gap = least_gap(start+along*piece*.5-face*THICKNESS,one,1)
				if mid_gap < 1e8: mid_gap -= piece_half[i]*absf(normal.dot(across))+piece_sag[i]
				clearance[i] = minf(tip_gap,mid_gap)
				tested_at[i] = start+along*piece
				if (CLEAR-mid_gap)*2.0 > worst:
					worst = (CLEAR-mid_gap)*2.0
					push = normal*worst
				if worst > 0.0:
					pushed_from = nearest_tube if (CLEAR-mid_gap)*2.0 >= worst-1e-9 and mid_gap < 1e8 else tip_tube
					# (Turned out about its crease: the end moved the depth
					# along the flesh's normal, a little over, as the turn
					# carries it round.)
					along = (along*piece+push*1.15).normalized()
					continue
				# Down onto a leg close under its face.
				var edge_gap: float = tip_gap-piece_half[i]*absf(tip_normal.dot(across))-piece_sag[i]
				if edge_gap < SETTLE_REACH and tip_normal.dot(face) > .3:
					along = (along*piece-tip_normal*(edge_gap-CLEAR)*SETTLE).normalized()
				break
			end = start+along*piece
			faces[i] = face_now
			face_above = face_now
			if dt > 0.0: velocity[i] = (end-was)/dt
			points[s*4+k+1] = end
			before = along
			start = end
		# The bones: each piece laid along where it lies, its face kept
		# turned outward (so a strip never twists from one piece to the next).
		var parent: Basis = hips.basis
		skeleton.set_bone_pose_position(piece_bone[s*3],hips_in*points[s*4])
		var across_was: Vector3 = out.cross(Vector3.UP)
		for k in 3:
			var now: Vector3 = (points[s*4+k+1]-points[s*4+k]).normalized()
			var looks: Vector3 = faces[s*3+k]
			if looks == Vector3.ZERO: looks = out
			var across: Vector3 = now.cross(looks)
			if across.length_squared() < 1e-4: across = across_was
			across = across.normalized()
			across_was = across
			var global: Basis = Basis(across,now,across.cross(now).normalized())*piece_offset[s*3+k]
			skeleton.set_bone_pose_rotation(piece_bone[s*3+k],(parent.inverse()*global).get_rotation_quaternion())
			parent = global
	# The tabs, over the tops of the strips they hang between, ridden up and
	# turned with them.
	for t in tab_count:
		var a: int = tab_under[t*2]
		var b: int = tab_under[t*2+1]
		var lifted: Vector3 = ((points[a*4+1]-points[a*4]).normalized()+(points[b*4+1]-points[b*4]).normalized()).normalized()
		var rest_way: Vector3 = (hips.basis*(piece_down[a*3]+piece_down[b*3])).normalized()
		var rest_dir: Vector3 = (hips.basis*tab_down[t]).normalized()
		var now: Vector3 = Quaternion(rest_way,lifted)*rest_dir
		var global: Basis = Basis(Quaternion(rest_dir,now))*(hips.basis*tab_frame[t])
		skeleton.set_bone_pose_position(tab_bone[t],hips_in*(hips*tab_hinge[t]+(ride[a]+ride[b])*.5))
		skeleton.set_bone_pose_rotation(tab_bone[t],(hips.basis.inverse()*global).get_rotation_quaternion())
	settled = true

# The way piece `k` of strip `s` hangs: partly with the hips' lean, partly
# straight down, flared out as it was cut.
func hang(s: int, k: int, hips: Transform3D, down: Vector3, level: Vector3) -> Vector3:
	var i: int = s*3+k
	return (hips.basis*piece_down[i]).lerp(down*flare_cos[i]+level*flare_sin[i],HANG).normalized()
