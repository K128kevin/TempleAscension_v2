"""Builds the Marathon Boots: assets/models/props/marathon_boots.glb, the
left boot (the game mirrors it for the right: scripts/visual.gd).

A pair of riding boots of gilded leather, high in the ankle: a closed foot
on a heeled sole of dark leather, a shaft rising to mid-calf with a rolled
cuff, three straps of brown leather with bronze buckles round the ankle and
the shaft, and on the outer side, at the ankle, a feathered wing swept back
and up: five long primaries and four secondaries under a row of coverts,
their quills held in a small gilt bracket riveted to the shaft.

The boot is one smooth body (the foot lofted along its length, the shaft
round the leg, fused by a voxel remesh) cut in two at the ankle so it bends
there: what is named ...Calf (the shaft, its straps, the wing) hangs from
the shin bone, the rest (the foot and its sole) from the foot bone, the
shaft a hair wider where it laps over the foot, and the ankle strap over
the cut. Each part is named for its finish ("Gold" gilded leather, "Sole"
dark leather, "Band" leather straps, "Buckle" bronze, "Wing" feathers:
Art.worn_model). Feathers carry UVs across (u) and along (v) them for
assets/shaders/feather.gdshader.

Built in metres about the left foot bone's head (the ankle), in the hero's
rest pose: X out to the figure's left, +Y up, +Z the way the foot points.
Written in Blender's axes (Z up, -Y the front), which the glTF exporter
turns back.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_shoes.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/marathon_boots.glb'
# The foot about the ankle (the foot bone's head, near the heel, .087 over
# the ground): the sole under it, the heel .075 behind and the toes .25
# ahead, its middle .017 out from the bone.
SOLE = -.1
HEEL = -.075
TOE = .25
MID_X = .017
# Where the boot is cut to bend at the ankle: the foot below CUT_TOP, the
# shaft above CUT_LOW (the two lap between).
CUT_LOW = .004
CUT_TOP = .034
# How far the foot is sunk under the shaft where they lap.
SINK = .03
# The shaft's top, a little under mid-calf.
TOP = .27
SEGS = 40


def emit(p):
    return Vector((p.x, -p.z, p.y))


def back(v):
    """A point in Blender's axes, in the boot's own."""
    return Vector((v.x, v.z, -v.y))


def foot_section(z):
    """The foot's outline across it at `z`: its half-width, the height of
    its top."""
    span = (z-HEEL)/(TOE-HEEL)
    half = .062*math.sin(math.pi*min(1.0, max(0.0, (z-HEEL+.02)/(TOE-HEEL+.04))))**.5+.007
    # A real last: the toe box low and rounded, the vamp rising over the
    # instep into the ankle.
    if z < .0: top = .07
    elif z < .1: top = .07-.075*(z/.1)**.9
    else: top = -.005-.058*((z-.1)/(TOE-.1))**1.25
    # (The toe and the heel rounded off, not cut square.)
    nose = max(0.0, (z-(TOE-.028))/.028)
    top = top-(top-(SOLE+.012))*(1.0-math.sqrt(max(0.0, 1.0-nose*nose)))
    return half, max(top, SOLE+.012)


def foot_ring(z, n=SEGS):
    half, top = foot_section(z)
    out = []
    for i in range(n):
        a = 2*math.pi*i/n
        c, s = math.cos(a), math.sin(a)
        x = half*math.copysign(abs(c)**(.9 if s > 0 else .6), c)
        y = (top-SOLE)*.5*math.copysign(abs(s)**(.85 if s > 0 else .25), s)+(top+SOLE)*.5
        out.append(Vector((MID_X+x, y, z)))
    return out


# The shaft round the leg, by height: its middle (x, z) and half-widths.
SHAFT = [  # y, cx, cz, hx, hz
    (.015, .014, -.006, .052, .066),
    (.07, .013, -.001, .053, .067),
    (.13, .013, .001, .057, .069),
    (.19, .014, .002, .064, .074),
    (.235, .013, .003, .071, .081),
    (TOP-.012, .013, .003, .076, .086),
]


def shaft_at(y):
    for a, b in zip(SHAFT, SHAFT[1:]):
        if a[0] <= y <= b[0]:
            t = (y-a[0])/(b[0]-a[0])
            t = t*t*(3-2*t)
            return [a[k]+(b[k]-a[k])*t for k in range(1, 5)]
    return list(SHAFT[0][1:] if y < SHAFT[0][0] else SHAFT[-1][1:])


def shaft_ring(y, grow=0.0, n=SEGS):
    cx, cz, hx, hz = shaft_at(y)
    return [Vector((cx+(hx+grow)*math.cos(2*math.pi*i/n), y, cz+(hz+grow)*math.sin(2*math.pi*i/n))) for i in range(n)]


def loft(bm, rings, cap_start=True, cap_end=True):
    made = [[bm.verts.new(emit(p)) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(made, made[1:]):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start: bm.faces.new(list(reversed(made[0])))
    if cap_end: bm.faces.new(made[-1])
    return made


def obj_from(bm, name, smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons: poly.use_smooth = smooth
    return obj


def apply(obj, kind, **settings):
    mod = obj.modifiers.new(kind.lower(), kind)
    for k, v in settings.items(): setattr(mod, k, v)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def finish(obj, name):
    obj.name = name
    obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(bpy.data.materials.new(name))
    return obj


def cut(obj, keep_below, height):
    """Cuts a solid level at `height`, keeping what is below (or above) and
    closing the cut."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:]+bm.edges[:]+bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, 0, height)), plane_no=Vector((0, 0, 1)),
                                 clear_inner=not keep_below, clear_outer=keep_below)
    edges = [e for e in res['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
    if edges: bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(obj.data)
    bm.free()


def outline_at(obj, height, n=72):
    """The boot's outline level at `height` (boot axes), as `n` points round
    its middle, each the farthest of the surface that way."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:]+bm.edges[:]+bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, 0, height)), plane_no=Vector((0, 0, 1)))
    pts = [back(v.co) for v in res['geom_cut'] if isinstance(v, bmesh.types.BMVert)]
    bm.free()
    cx = sum(p.x for p in pts)/len(pts)
    cz = sum(p.z for p in pts)/len(pts)
    best = [None]*n
    for p in pts:
        a = math.atan2(p.z-cz, p.x-cx)
        k = int(round((a % (2*math.pi))/(2*math.pi)*n)) % n
        r = math.hypot(p.x-cx, p.z-cz)
        if best[k] is None or r > best[k][0]: best[k] = (r, p)
    # (Gaps filled from the neighbours.)
    for k in range(n):
        if best[k] is None:
            j = 1
            while best[(k-j) % n] is None and best[(k+j) % n] is None: j += 1
            best[k] = best[(k-j) % n] or best[(k+j) % n]
    return [Vector((cx+(b[0])*math.cos(2*math.pi*k/n), height, cz+(b[0])*math.sin(2*math.pi*k/n))) for k, b in enumerate(best)], (cx, cz)


def band(name, source, y0, y1, out=.0028, thick=.0022, tilt=0.0, slope_z=0.0):
    """A strap round the boot between heights `y0` and `y1` (sloping by
    `slope_z` a metre forward), standing `out` off it, `thick` thick."""
    bm = bmesh.new()
    mid = (y0+y1)*.5
    ring, (cx, cz) = outline_at(source, mid)
    rows = []
    for (y, grow) in ((y0, out), (y1, out), (y1, out+thick), (y0, out+thick)):
        row = []
        for p in ring:
            d = Vector((p.x-cx, 0, p.z-cz))
            r = d.length
            d.normalize()
            row.append(Vector((cx, y+slope_z*(p.z-cz), cz))+d*(r+grow))
        rows.append(row)
    made = [[bm.verts.new(emit(p)) for p in r] for r in rows]
    n = len(ring)
    for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((made[a][i], made[a][j], made[b][j], made[b][i]))
    obj = obj_from(bm, name)
    apply(obj, 'BEVEL', width=.0007, segments=2)
    finish(obj, name)
    # Where its buckle goes: on the outer side.
    k = 0
    p = ring[k]
    d = Vector((p.x-cx, 0, p.z-cz)).normalized()
    return Vector((cx, mid+slope_z*(p.z-cz), cz))+d*(Vector((p.x-cx, 0, p.z-cz)).length+out+thick)


def buckle(name, at, height, width=.018):
    """A bronze buckle on a strap's outer face: a rounded frame and its
    tongue, facing out (+X)."""
    bm = bmesh.new()
    h, w, t = height*1.35, width, .0022
    bars = [((0, h*.5-t*.5, 0), (t, t, w)), ((0, -h*.5+t*.5, 0), (t, t, w)),
            ((0, 0, w*.5-t*.5), (t, h, t)), ((0, 0, -w*.5+t*.5), (t, h, t)), ((0, 0, 0), (t, h, t*.8))]
    for (cx, cy, cz), (sx, sy, sz) in bars:
        m = Matrix.Translation(emit(at+Vector((t*.5+cx, cy, cz))))@Matrix.Diagonal((sx, sz, sy, 1))
        bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    obj = obj_from(bm, name, smooth=False)
    apply(obj, 'BEVEL', width=.0005, segments=1)
    return finish(obj, name)


def feather(bm, root, direction, side, length, width, curl, twist, out_tilt, seed):
    """One feather: a curved blade from `root` along `direction` (unit, in
    the boot's axes), `side` the way its trailing vane lies; UVs across it
    (u: 0 leading edge, .5 the quill, 1 trailing) and along it (v: 0 root,
    1 tip), and its `seed` in the second UVs. Two-sided."""
    uv = bm.loops.layers.uv.get('UVMap') or bm.loops.layers.uv.new('UVMap')
    seeds = bm.loops.layers.uv.get('Seed') or bm.loops.layers.uv.new('Seed')
    n_along = 30
    n_across = 4
    direction = direction.normalized()
    side = (side-direction*side.dot(direction)).normalized()
    normal = direction.cross(side).normalized()
    rows = []
    for i in range(n_along+1):
        # (Closer together toward the tip, to round it.)
        v = 1.0-(1.0-i/n_along)**1.5
        # Its outline: swelling from the quill's bare root to its broadest a
        # third along, then tapering all the way to a narrow, rounded tip;
        # the leading vane narrower than the trailing.
        if v < .3: broad = (v/.3)**.55
        else: broad = 1.0-.72*((v-.3)/.7)**1.35
        if v > .93: broad *= math.sqrt(max(0.0, 1.0-((v-.93)/.07)**2))
        lead, trail = width*.3*broad, width*.7*broad
        # The quill bows back along its length and the blade twists a little.
        bend = curl*v*v*length
        spine = root+direction*(v*length)+side*bend+normal*out_tilt*v*length
        ang = twist*v
        s_t = (side*math.cos(ang)+normal*math.sin(ang))
        n_t = normal*math.cos(ang)-side*math.sin(ang)
        row = []
        for k in range(n_across+1):
            u = k/n_across
            off = (u-.5)*2.0
            reach = (lead if off < 0 else trail)*abs(off)
            # Cupped a little across, the vane curving down from the quill.
            row.append((spine+s_t*(reach*(1 if off >= 0 else -1))-n_t*.06*reach*abs(off)+n_t*.0005*(1-abs(off)), u, v))
        rows.append(row)
    verts = [[bm.verts.new(emit(p)) for p, _, _ in row] for row in rows]
    for i in range(n_along):
        for j in range(n_across):
            f = bm.faces.new((verts[i][j], verts[i][j+1], verts[i+1][j+1], verts[i+1][j]))
            for loop in f.loops:
                for r, row in ((i, rows[i]), (i+1, rows[i+1])):
                    for c in range(n_across+1):
                        if loop.vert == verts[r][c]:
                            loop[uv].uv = (row[c][1], row[c][2])
                            loop[seeds].uv = (seed, 0.0)


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- The boot's body: the foot and the shaft, fused into one.
bm = bmesh.new()
stations = [HEEL+.003, HEEL+.01, HEEL+.024]+[HEEL+.045+k*.019 for k in range(14)]+[TOE-.022, TOE-.01, TOE-.003]
loft(bm, [foot_ring(z) for z in stations])
ys = [SHAFT[0][0]+k*(TOP-SHAFT[0][0])/16 for k in range(17)]
loft(bm, [shaft_ring(y) for y in ys])
# The cuff: a rolled lip round the top.
loft(bm, [shaft_ring(TOP-.02, .0), shaft_ring(TOP-.014, .004), shaft_ring(TOP-.006, .0055), shaft_ring(TOP, .004), shaft_ring(TOP+.002, .0)])
whole = obj_from(bm, 'Boot')
apply(whole, 'REMESH', mode='VOXEL', voxel_size=.0022, adaptivity=0.0)
apply(whole, 'SMOOTH', factor=.6, iterations=6)
apply(whole, 'DECIMATE', ratio=.13)
for poly in whole.data.polygons: poly.use_smooth = True

# The foot, below the cut, sunk a little where the shaft lies over it (so
# no step shows where the shaft ends and the two never fight).
foot = whole.copy()
foot.data = whole.data.copy()
bpy.context.scene.collection.objects.link(foot)
cut(foot, True, CUT_TOP)
for v in foot.data.vertices:
    p = back(v.co)
    t = max(0.0, min(1.0, (p.y-(CUT_LOW-.006))/.01))
    sink = 1.0-SINK*t*t*(3-2*t)
    cx, cz, _, _ = shaft_at(max(p.y, SHAFT[0][0]))
    v.co = emit(Vector((cx+(p.x-cx)*sink, p.y, cz+(p.z-cz)*sink)))
finish(foot, 'GoldFoot')
# The shaft, above it.
shaft = whole.copy()
shaft.data = whole.data.copy()
bpy.context.scene.collection.objects.link(shaft)
cut(shaft, False, CUT_LOW)
finish(shaft, 'GoldCalf')

# --- The sole: dark leather under the foot, a stacked heel at the back.
bm = bmesh.new()
outline, (scx, scz) = outline_at(foot, SOLE+.012)
rows = []
for y, grow in ((SOLE+.012, .0), (SOLE+.004, .0035), (SOLE-.006, .0035), (SOLE-.007, .002)):
    rows.append([Vector((scx, y, scz))+Vector((p.x-scx, 0, p.z-scz)).normalized()*(Vector((p.x-scx, 0, p.z-scz)).length+grow) for p in outline])
made = [[bm.verts.new(emit(p)) for p in r] for r in rows]
n = len(outline)
for a, b in zip(made, made[1:]):
    for i in range(n):
        j = (i+1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
bm.faces.new(list(made[-1]))
bm.faces.new(list(reversed(made[0])))
sole = obj_from(bm, 'Sole')
apply(sole, 'BEVEL', width=.0012, segments=2)
finish(sole, 'Sole')
# The heel: a block of stacked leather under the back of the foot.
bm = bmesh.new()
heel_rows = []
HEEL_FRONT = HEEL+.07
for y, shrink in ((SOLE-.006, 0.0), (SOLE-.024, .003)):
    row = []
    for p in outline:
        d = Vector((p.x-scx, 0, p.z-scz))
        q = Vector((scx, y, scz))+d.normalized()*max(.0, d.length+.002-shrink)
        # (Its front a straight edge across the waist of the sole.)
        q.z = min(q.z, HEEL_FRONT-shrink*.5)
        row.append(q)
    heel_rows.append(row)
made = [[bm.verts.new(emit(p)) for p in r] for r in heel_rows]
for i in range(n):
    j = (i+1) % n
    bm.faces.new((made[0][i], made[0][j], made[1][j], made[1][i]))
bm.faces.new(list(made[1]))
bm.faces.new(list(reversed(made[0])))
heel = obj_from(bm, 'SoleHeel')
apply(heel, 'BEVEL', width=.001, segments=1)
finish(heel, 'SoleHeel')

# --- The straps: round the ankle over the cut, and twice round the shaft.
for name, y0, y1, slope in (('BandCalfAnkle', CUT_LOW-.002, CUT_LOW+.016, -.12), ('BandCalfLow', .1, .116, 0.0), ('BandCalfHigh', .19, .206, 0.0)):
    at = band(name, shaft, y0, y1, slope_z=slope)
    buckle(name.replace('Band', 'Buckle'), at+Vector((-.001, 0, -.012)), y1-y0)

# --- The wing, at the ankle on the outer side: laid out as a bird's, its
# arm running back and up from the mount to the wrist; five long primaries
# fanned from the wrist, up and back, their tips clear of each other; four
# secondaries along the arm, swept back; a row of coverts over their roots.
bm = bmesh.new()
cx, cz, hx, hz = shaft_at(.06)
root = Vector((cx+hx+.004, .055, cz-.03))
out = Vector((1, 0, 0))
wrist = root+Vector((0, .055, -.05))


def arm(t):
    """A point along the wing's arm, bowed up a little."""
    return root+(wrist-root)*t+Vector((0, .01*math.sin(math.pi*t), .0))


count = [0]


def fan(at, angle, length, width, lift, curl=.06, twist=.12, tilt=.05):
    """A feather from `at`, `angle` degrees up from straight back."""
    a = math.radians(angle)
    d = Vector((0, math.sin(a), -math.cos(a)))
    count[0] += 1
    feather(bm, at+out*lift, d, Vector((0, -math.cos(a), -math.sin(a))), length, width, curl, twist, tilt, (count[0]*.6180339) % 1.0)


# Secondaries along the arm, the lowest first (each over the one before).
for k in range(4):
    t = .12+k*.24
    fan(arm(t), -12+k*8, .08+.008*k, .05, .0012*k)
# Primaries from the wrist: the longest in the middle of the fan.
for k, (angle, length) in enumerate(((24, .13), (38, .148), (52, .155), (66, .146), (80, .125))):
    fan(arm(.95)+Vector((0, .004*k, .002*k)), angle, length, .05, .006+.0012*k, .08, .14)
# Coverts over the roots of both.
for k in range(5):
    t = .1+k*.2
    fan(arm(min(t, 1.0))+Vector((0, .003, .002)), 2+k*15, .04, .03, .0105+.0006*k, .03, .0, tilt=.008)
wing = obj_from(bm, 'WingCalf')
finish(wing, 'WingCalf')
# The mount: a small gilt bracket on the shaft's side, the feathers' quills
# held in its lip; a plate riveted to the leather.
bm = bmesh.new()
plate_at = root+Vector((.0015, .006, .006))
bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=1.0, radius2=.86, depth=1.0,
                      matrix=Matrix.Translation(emit(plate_at))@Matrix.Rotation(math.pi/2, 4, 'Y')@Matrix.Diagonal((.012, .016, .0035, 1)))
for k, (dy, dz) in enumerate(((.011, .012), (-.01, .014), (.0, -.016))):
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=.0022,
                              matrix=Matrix.Translation(emit(plate_at+Vector((.002, dy, dz)))))
mount = obj_from(bm, 'MetalCalfMount')
apply(mount, 'BEVEL', width=.0006, segments=2)
finish(mount, 'MetalCalfMount')

bpy.data.objects.remove(whole)
for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, use_selection=True)
print('SHOES_READY', {o.name: len(o.data.polygons) for o in bpy.data.objects})
