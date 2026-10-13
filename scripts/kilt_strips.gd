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
## and, where a leg lies close under its face, drawn down onto it as it
## swings (DRAPE) and turned to lie flat on it, so the strips rest on his
## thighs instead of standing off them or passing through.
## What the flesh does to a piece moves it but does not set it swinging: it
## keeps only the flesh's own motion, and is put out of the flesh at once only
## as far as the two came together (least_gap and the push: GIVE). So the
## strips of a man standing still lie still, moving only as his body does.
## (They did not: the flesh's outline, the way out of it and the gap at a
## strip's edges each jumped as a strip moved a hair, and every push out of
## the flesh, or draw onto it, was carried on as a swing; each kicked the
## strip, which swung back and was kicked again, and in an idle the strips
## flapped and shook, ten degrees and more a frame.)
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
# How fast a piece is put back out of flesh it has come into without
# either of them moving (metres a second): all the way out at once only as
# far as they came together.
const GIVE = .1
# A leg within this far under a piece's face draws it down onto it (per
# second squared, for each metre it is off it: its weight, laying it on the
# thigh), and turns it (twisting along its length, at most TWIST) to lie flat
# on it; the less, the further off it is (lies_on).
const SETTLE_REACH = .05
const DRAPE = 600.0
const DRAPE_DAMPING = 30.0
const TWIST = .6
const CREASE_TWIST = .25
# How fast a piece turns so (radians a second).
const TWIST_RATE = 4.0
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
# How each piece is drawn down onto the leg under it (an acceleration), and
# the way it is drawn (as long as how fully: its swing that way is damped).
var drape := PackedVector3Array()
var drape_way := PackedVector3Array()
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
# round it; and where its frame was the frame before (how fast its flesh
# moves).
var tube_in: Array[Transform3D] = []
var tube_was: Array[Transform3D] = []
var tube_pose: Array[Transform3D] = []
var tube_out: Array[Basis] = []
var tube_start := PackedVector3Array()
var tube_end := PackedVector3Array()
var tube_axis := PackedVector3Array()
# The widest of each tube's flesh at each station (indexed as its outlines).
var station_widest := PackedFloat32Array()
var tube_widest := PackedFloat32Array()
# Of the last point tested: the way out of the flesh.
var normal = Vector3.ZERO
# (And the tube it was nearest, -1: none, and the gap at the point itself.)
var nearest_tube = -1
var raw_gap = 1e9

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
			drape.append(Vector3.ZERO)
			drape_way.append(Vector3.ZERO)
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
		tube_gap.append(0.0); tube_normal.append(Vector3.ZERO)
		tube_in.append(Transform3D()); tube_was.append(Transform3D()); tube_pose.append(Transform3D()); tube_out.append(Basis()); tube_start.append(Vector3.ZERO); tube_end.append(Vector3.ZERO); tube_axis.append(Vector3.ZERO)
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
# gap_at, written out for speed, and so that the gap and the way out change
# smoothly as `p` moves (were either to jump, a strip lying still on a leg
# would be thrown out of it, or drawn into it, over and over):
# - each outline blended from the two either side along the tube as well as
#   round it (from the nearest alone, the flesh under a strip stepped by up
#   to a couple of centimetres as it moved a few millimetres along a leg);
# - beside a direction with no flesh (between the legs, past the end of the
#   flesh a tube holds) the flesh tapers away into it, across the 1/ANGLES of
#   a turn or the STATION between them (cut off square, it came and went
#   whole as a point crossed that line by a hair);
# - the slope round the tube blended from each direction's (from the stretch
#   between two directions alone, the way out turned by up to half a right
#   angle as a point crossed a ridge of the flesh);
# - the way out of tubes nearly as near (within BLEND) blended in, more the
#   nearer (a strip between both thighs' creases was pushed out of each in
#   turn as the nearest changed, toward the other).
const BLEND = .01
var tube_gap := PackedFloat32Array()
var tube_normal := PackedVector3Array()
func least_gap(p: Vector3, near: PackedInt32Array, count: int, across := Vector3.ZERO, half := 0.0, sag := 0.0) -> float:
	var best = 1e9
	nearest_tube = -1
	for m in count:
		var n: int = near[m]
		tube_gap[m] = 1e9
		var q: Vector3 = tube_in[n]*p-tube_a[n]
		var h: float = q.dot(tube_dir[n])
		if h < 0.0 or h > tube_length[n]: continue
		var x: float = q.dot(tube_e1[n])
		var y: float = q.dot(tube_e2[n])
		var f: float = h/STATION
		var k: int = mini(int(f),tube_count[n]-2)
		var r: float = maxf(sqrt(x*x+y*y),1e-5)
		# (A tube that cannot be the nearest, nor nearly: no more of it.)
		if r-station_widest[tube_first[n]+k]-half-sag >= best+BLEND: continue
		var g: float = (atan2(y,x)+PI)*ANGLES/TAU
		var j: int = int(g)
		var w: float = g-j
		var u: float = f-k
		var i0: int = (tube_first[n]+k)*ANGLES
		var j0: int = j % ANGLES
		var j1: int = (j+1) % ANGLES
		var a0: float = sections[i0+j0]
		var a1: float = sections[i0+j1]
		var r0: float = a0+(sections[i0+ANGLES+j0]-a0)*u
		var r1: float = a1+(sections[i0+ANGLES+j1]-a1)*u
		if r0 <= 0.0 and r1 <= 0.0: continue
		var flesh: float = r0+(r1-r0)*w
		var gap: float = r-flesh
		var raw: float = gap
		if gap-half-sag >= best+BLEND: continue
		# (Out square to the outline: radially, less its slope round the
		# tube.)
		var jb: int = (j+ANGLES-1) % ANGLES
		var ja: int = (j+2) % ANGLES
		var c0: float = sections[i0+jb]
		var c1: float = sections[i0+ja]
		var before: float = (r1-c0-(sections[i0+ANGLES+jb]-c0)*u)*.5
		var after: float = (c1+(sections[i0+ANGLES+ja]-c1)*u-r0)*.5
		var slope: float = before+(after-before)*w
		var e1: Vector3 = tube_e1[n]
		var e2: Vector3 = tube_e2[n]
		var way: Vector3 = (tube_out[n]*((e1*x+e2*y)*(flesh/r)-(e2*x-e1*y)*(slope*ANGLES/TAU/r))).normalized()
		tube_normal[m] = way
		# (The gap at the edges of a piece `half` wide across, curled `sag`
		# back: off its tangent plane, the flesh rising toward one edge as
		# its normal leans across. Each tube's own: from the nearest tube's
		# gap and a way out blended between tubes, it jumped as the blend
		# turned, between the facing creases of the two thighs.)
		if half > 0.0: gap -= half*absf(way.dot(across))+sag
		tube_gap[m] = gap
		if gap < best:
			best = gap
			raw_gap = raw
			nearest_tube = n
	if nearest_tube < 0: return best
	var way = Vector3.ZERO
	for m in count:
		if tube_gap[m] < best+BLEND: way += tube_normal[m]*(1.0-(tube_gap[m]-best)/BLEND)
	normal = way.normalized() if way.length_squared() > 1e-6 else tube_normal[near.find(nearest_tube)]
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
		tube_was[n] = tube_pose[n] if settled else pose
		tube_pose[n] = pose
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
		# (Hung afresh: put out of the flesh at once, wherever it is.)
		var fresh: bool = not settled or points[s*4].distance_to(hinge+ride[s]) > .2
		if fresh:
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
		# How far the flesh has moved the pieces above, beyond their swing;
		# and the way across the strip, carried down it from the belt.
		var shifted = Vector3.ZERO
		var side: Vector3 = down.cross(level).normalized()
		for k in 3:
			var i: int = s*3+k
			var piece: float = piece_length[i]
			var aim: Vector3 = (hips.basis*piece_down[i]).lerp(down*flare_cos[i]+level*flare_sin[i],HANG).normalized()
			if k == 0: before = aim
			var end: Vector3 = points[s*4+k+1]
			var was: Vector3 = end
			var v: Vector3 = velocity[i]
			if dt > 0.0:
				v += ((start+aim*piece-end)*SPRING+air+drape[i]-drape_way[i]*(v.dot(drape_way[i])*DRAPE_DAMPING)-v*DAMPING)*dt
				end += v*dt
			var along: Vector3 = (end-start).normalized()
			# Not in past the way it hangs, toward his hips; not swung, nor
			# bent at its crease, further than it can go.
			var least: float = aim.dot(level)-INWARD
			if along.dot(level) < least: along = (along+level*(least-along.dot(level))).normalized()
			var limit: float = MAX_SWING if k == 0 else MAX_BEND
			var bent: float = along.angle_to(before)
			if bent > limit: along = before.slerp(along,limit/bent).normalized()
			# Where its swing takes it: what the flesh does to it from here on
			# moves it but does not set it swinging.
			var swung: Vector3 = start+along*piece
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
			var face_was: Vector3 = faces[i]
			var face_now = Vector3.ZERO if not skip else faces[i]
			var pushed_from = -1
			var pushed_way = Vector3.ZERO
			var may_push = -1.0
			drape[i] = Vector3.ZERO
			drape_way[i] = Vector3.ZERO
			if not skip: clearance[i] = 1e9
			for pass_ in 2:
				if closer == 0: break
				# (Across it as across the piece above, square to it. Taken
				# square to it and to the hips' outward way, it swung round
				# wildly as a piece lifted out toward that way, and with it
				# the gap at its edges, by a centimetre and more a frame.)
				var plain_across: Vector3 = side-along*side.dot(along)
				if plain_across.length_squared() < 1e-6: plain_across = along.cross(level)
				plain_across = plain_across.normalized()
				var plain: Vector3 = plain_across.cross(along)
				if plain.dot(level) < 0.0:
					plain = -plain
					plain_across = -plain_across
				# (Tested as it lay last, turned on a leg or not.)
				var face: Vector3 = plain
				var across: Vector3 = plain_across
				var was_flat: Vector3 = face_was-along*face_was.dot(along)
				if was_flat.length_squared() > 1e-6:
					was_flat = was_flat.normalized()
					face = was_flat
					across = along.cross(face).normalized()
				else: was_flat = plain
				# (Checked again after a push as before it, against all the
				# flesh near: against the flesh it was pushed out of alone,
				# the way out of it, and the gap at its edges, differed from
				# the first test's, and it was pushed again, unchecked, by a
				# couple of centimetres.)
				var edge_gap: float = least_gap(start+along*piece-face*THICKNESS,near,closer,across,piece_half[i],piece_sag[i])
				var tip_gap: float = raw_gap
				var tip_normal: Vector3 = normal
				var tip_tube: int = nearest_tube
				var lying: float = lies_on(tip_gap,tip_normal.dot(face))
				var flat: Vector3 = plain
				if lying > 0.0:
					# Turned to lie flat on the leg under it.
					var on_leg: Vector3 = tip_normal-along*tip_normal.dot(along)
					if on_leg.length_squared() > 1e-6:
						on_leg = on_leg.normalized()
						var turn_by: float = plain.angle_to(on_leg)
						flat = plain.slerp(on_leg,TWIST*lying/turn_by).normalized() if turn_by > TWIST*lying else on_leg
						# (Nor much more than the piece above it: a strip
						# twists gradually, its creases do not shear.)
						if k > 0 and face_above != Vector3.ZERO:
							var above: Vector3 = face_above-along*face_above.dot(along)
							if above.length_squared() > 1e-6:
								above = above.normalized()
								var off: float = above.angle_to(flat)
								if off > CREASE_TWIST: flat = above.slerp(flat,CREASE_TWIST/off).normalized()
				# (Turned, or turned back, from the way it lay, at
				# TWIST_RATE: turned at once to whatever way the flesh
				# under it faced, a strip between the legs, under which
				# that way swings round, swung its edges into one thigh
				# then the other.)
				var turned: float = was_flat.angle_to(flat)
				if turned > TWIST_RATE*dt: flat = was_flat.slerp(flat,TWIST_RATE*dt/turned).normalized()
				face_now = Vector3.ZERO
				face = plain
				across = plain_across
				if flat.angle_to(plain) > 1e-3:
					face = flat
					across = along.cross(face).normalized()
					face_now = face
				var worst: float = CLEAR-edge_gap
				var push: Vector3 = tip_normal*worst
				# (Its middle, which may lie over a bulge between its ends.)
				# (Every piece's, whether or not its tip is near the flesh:
				# a lower piece's tip clear of the knee may lie with its
				# middle deep in it, found only when the tip came near, and
				# thrown out by several centimetres at once.)
				var mid_gap: float = least_gap(start+along*piece*.5-face*THICKNESS,near,closer,across,piece_half[i],piece_sag[i])
				clearance[i] = minf(edge_gap,mid_gap)
				tested_at[i] = start+along*piece
				if (CLEAR-mid_gap)*2.0 > worst:
					worst = (CLEAR-mid_gap)*2.0
					push = normal*worst
				if worst > 0.0:
					pushed_from = nearest_tube if (CLEAR-mid_gap)*2.0 >= worst-1e-9 and mid_gap < 1e8 else tip_tube
					# (Out of it at once as far as it and the flesh came
					# together this frame, and any deeper only at GIVE: where
					# the flesh it is held off turns steeply, between the
					# legs, a piece moving a few millimetres along it was
					# found centimetres deep, thrown well clear, swung back,
					# and thrown again, several times a second.)
					if may_push < 0.0:
						var tip: Vector3 = start+along*piece
						may_push = ((v-(tip-tube_was[pushed_from]*(tube_in[pushed_from]*tip))/dt).length()+GIVE)*dt if dt > 0.0 and not fresh else 1e9
					var by: float = minf(worst,may_push)
					may_push -= by
					if by <= 0.0: break
					push *= by/worst
					pushed_way += push
					# (Turned out about its crease: the end moved the depth
					# along the flesh's normal.)
					along = (along*piece+push).normalized()
					continue
				# Down onto a leg close under its face, as it swings on.
				# (It was laid half the way down onto it each frame: on into
				# the flesh, to be thrown out the next, or held there while
				# its swing back out gathered, to fly off when let go.)
				# (Nor drawn further about its crease once its middle lies on
				# the flesh: it rests there, not drawn in to be pushed out
				# again each frame.)
				var resting: float = clampf((mid_gap-CLEAR)/(SETTLE_REACH*.2),0.0,1.0)
				var drawn: float = lies_on(edge_gap,tip_normal.dot(face))*resting
				drape[i] = -tip_normal*(maxf(edge_gap-CLEAR,0.0)*DRAPE*drawn)
				drape_way[i] = tip_normal*sqrt(drawn)
				break
			end = start+along*piece
			faces[i] = face_now
			face_above = face_now
			var across_now: Vector3 = along.cross(face_now) if face_now != Vector3.ZERO else side-along*side.dot(along)
			if across_now.length_squared() > 1e-6: side = across_now.normalized()
			# (Its last test cut short by the push: tested again next frame.)
			if pushed_from >= 0: clearance[i] = 0.0
			# It swings on as it swung, less what of that went into the
			# flesh (unless the flesh itself moves that way as fast): neither
			# a push out of the flesh nor a draw down onto it, nor those of
			# the pieces above it, is carried on as a swing. (They were, and
			# so each kicked it: a strip drawn onto a leg came on into it, was
			# thrown out, and was drawn back, and the strips of a man standing
			# still flapped and shook.)
			if dt > 0.0:
				var going: Vector3 = (swung-shifted-was)/dt
				if pushed_way != Vector3.ZERO:
					var out_of: Vector3 = pushed_way.normalized()
					var flesh: float = (end-tube_was[pushed_from]*(tube_in[pushed_from]*end)).dot(out_of)/dt
					going += out_of*(maxf(v.dot(out_of),flesh)-going.dot(out_of))
				velocity[i] = going
			shifted += end-swung
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
			# (Turned flat on a leg, as it lies; else across as the piece
			# above, as in the swing.)
			var looks: Vector3 = faces[s*3+k]
			var across: Vector3 = now.cross(looks) if looks != Vector3.ZERO else across_was-now*across_was.dot(now)
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

# How fully a piece `gap` off the flesh under it, its face turned `facing`
# (the cosine) toward it, is laid down onto it: wholly within half
# SETTLE_REACH and turned well toward it, not at all at SETTLE_REACH or turned
# away, and smoothly between.
static func lies_on(gap: float, facing: float) -> float:
	return clampf((SETTLE_REACH-gap)/(SETTLE_REACH*.5),0.0,1.0)*clampf((facing-.3)/.2,0.0,1.0)

# The way piece `k` of strip `s` hangs: partly with the hips' lean, partly
# straight down, flared out as it was cut.
func hang(s: int, k: int, hips: Transform3D, down: Vector3, level: Vector3) -> Vector3:
	var i: int = s*3+k
	return (hips.basis*piece_down[i]).lerp(down*flare_cos[i]+level*flare_sin[i],HANG).normalized()
