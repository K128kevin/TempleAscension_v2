"""Builds the warrior's three helmets, assets/models/props/<item id>.glb:

  gladiators_helmet          his starting helm, after a Roman gladiator's: a
                             round steel bowl under a tall narrow crest, a
                             wide brim all round at the brow, and below it a
                             visor closed round the whole head, its face
                             pierced with rows of holes, riveted where it
                             meets the bowl and along its rim.
  ancient_gladiators_helmet  the unique: dark steel, a keel over the crown set
                             with a row of spikes and a row down each side, a
                             heavy rolled brow, and a mask of a nose bar and
                             two broad cheek plates that leave the eyes open
                             across and the mouth open down the middle.
  steel_full_helm            a tall rounded skull down over the ears and neck,
                             with a riveted face plate: an eye slot across it
                             and a field of holes over the mouth.

Each part is its own mesh, named for its finish ("Steel", "Bright", "Dark",
"Rivet"), so the game colours it (Art.worn_model). Built in the head bone's
space (metres: origin at the base of the skull, +Y up, +Z the face), and
emitted as the game hangs the wizard's hat from the head (scripts/visual.gd
HAT_ON_HEAD: .13 m up the bone, turned about to face +Z), in Blender's axes
(Z up, -Y the front), which the glTF exporter turns back.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_helms.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props'
SEG = 72
SIT = .13
# The head: its sides ±.09 and its face +.11 of the bone's axis (the nose to
# .13), its crown at +.21, its chin at -.02; the skull's middle sits forward.
HEAD_RX = .104
HEAD_RZ = .112
HEAD_SHIFT = .02
BROW = .12


def emit(p):
    """A head-bone-space point as the glTF model needs it (see above)."""
    return Vector((-p.x, p.z, p.y-SIT))


def emit_dir(d):
    return Vector((-d.x, d.z, d.y))


def dome_w(y, top, base=BROW):
    """How wide the skull is at `y` against its widest, 1 to the brow and
    rounding over to 0 at `top`."""
    if y <= base: return 1.0
    t = (y-base)/(top-base)
    return math.sqrt(max(1-t*t, 0.0))


def skull(y, a, pad, top):
    """The point `pad` out from the skull at height `y`, `a` round from the
    face (to the figure's left first)."""
    w = dome_w(y, top)
    if y < -.02: w *= 1-.12*min((-.02-y)/.06, 1.0)
    return Vector(((HEAD_RX+pad)*w*math.sin(a), y, (HEAD_RZ+pad)*w*math.cos(a)+HEAD_SHIFT))


def skull_normal(p, top):
    """Outward from the skull at `p`, near enough."""
    c = Vector((0, min(p.y, BROW), HEAD_SHIFT))
    n = p-c
    n.x /= HEAD_RX
    n.z /= HEAD_RZ
    return n.normalized()


def dome_y(z, pad, top):
    """The height of the dome's midline over `z` (the brow's height before
    and behind it)."""
    w = (z-HEAD_SHIFT)/(HEAD_RZ+pad)
    if abs(w) >= 1.0: return BROW
    return BROW+(top-BROW)*math.sqrt(1-w*w)


def ring(y, pad, top, segs=SEG, span=(0.0, 2*math.pi)):
    out = []
    for i in range(segs):
        a = span[0]+(span[1]-span[0])*i/segs if span[1]-span[0] < 2*math.pi-1e-6 else 2*math.pi*i/segs
        out.append(skull(y, a, pad, top))
    return out


def loft(bm, rings, closed=True, cap_start=False, cap_end=False, skip=None):
    """Faces between rings of points (emitted), `closed` round; `skip(i, j)`
    leaves out the cell between rings i and i+1 after point j."""
    made = [[bm.verts.new(emit(p)) for p in r] for r in rings]
    n = len(rings[0])
    for i, (a, b) in enumerate(zip(made, made[1:])):
        for j in range(n if closed else n-1):
            if skip and skip(i, j): continue
            k = (j+1) % n
            bm.faces.new((a[j], a[k], b[k], b[j]))
    if cap_start: bm.faces.new(list(reversed(made[0])))
    if cap_end: bm.faces.new(made[-1])
    return made


def piece(name, bm, smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if smooth: bpy.ops.object.shade_smooth()
    obj.select_set(False)
    mesh.materials.append(bpy.data.materials.new(name))
    return obj


def rivet(bm, p, r=.0035):
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r, matrix=Matrix.Translation(emit(p)))


def spike(bm, base, direction, height, radius):
    """A cone standing on `base` along `direction`."""
    d = emit_dir(direction).normalized()
    rot = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    m = Matrix.Translation(emit(base)+d*height*.5) @ rot
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10, radius1=radius, radius2=0.0, depth=height, matrix=m)


def slab(bm, stations):
    """A thin slab along the crown's midline: for each (z, bottom, top,
    thickness) a rectangle, lofted and capped."""
    rings = []
    for z, bottom, top, t in stations:
        rings.append([Vector((-t/2, bottom, z)), Vector((t/2, bottom, z)), Vector((t/2, top, z)), Vector((-t/2, top, z))])
    loft(bm, rings, closed=True, cap_start=True, cap_end=True)


def dome_rows(top, start, step=.012):
    """Heights up the skull from `start`, finer over the dome's turn."""
    rows = []
    y = start
    while y < BROW+.03:
        rows.append(y); y += step
    for k in range(1, 12):
        t = k/12
        rows.append(BROW+.03+(top-.012-(BROW+.03))*(1-(1-t)**1.6))
    return rows


def export(name):
    for o in bpy.data.objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'), export_format='GLB', export_animations=False, use_selection=True)
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)


bpy.ops.wm.read_factory_settings(use_empty=True)


# --- The Gladiator's Helmet.
def gladiators_helmet():
    top = .265
    pad = .012
    brim = .115
    # The bowl, from the brim up, capped at the crown.
    bm = bmesh.new()
    rows = dome_rows(top, brim)
    loft(bm, [ring(y, pad, top) for y in rows], cap_end=True)
    # The visor below it, closed round the head and drawn in toward the jaw,
    # its face pierced with small staggered holes (one cell in four of a
    # fine grid).
    fine = SEG*2
    rows = [brim-.006*k for k in range(30)]
    rings = [ring(y, pad*(1-(brim-y)/.22), top, segs=fine) for y in rows]
    def hole(i, j):
        y = (rows[i]+rows[i+1])/2
        a = 2*math.pi*(j+.5)/fine
        if a > math.pi: a -= 2*math.pi
        return abs(a) < math.radians(50) and -.05 < y < .1 and i % 2 == 0 and (j+i//2) % 2 == 0
    loft(bm, rings, skip=hole)
    # The band where the visor meets the bowl.
    loft(bm, [ring(brim-.008, pad+.004, top), ring(brim+.008, pad+.004, top)])
    # The brim: top and underside, wide, drooping toward its edge.
    steps = [(pad+.004, 0.0), (pad+.03, -.002), (pad+.06, -.008), (pad+.085, -.017)]
    tops = [[p+Vector((0, .005+h, 0)) for p in ring(brim, r, top)] for r, h in steps]
    unders = [[p+Vector((0, h, 0)) for p in ring(brim, r, top)] for r, h in steps]
    loft(bm, tops)
    loft(bm, list(reversed(unders)))
    loft(bm, [unders[-1], tops[-1]])
    # The crest: a tall thin fin along the crown, its front corner cut away.
    stations = []
    for k in range(19):
        z = .105-.012*k
        bottom = dome_y(z, pad, top)-.004
        crest_top = .355 if z < .045 else .355-.14*((z-.045)/.06)**1.5
        stations.append((z, bottom, max(crest_top, bottom+.03), .012))
    slab(bm, stations)
    piece('Steel', bm)
    # Rivets round the band and along the visor's rim.
    bm = bmesh.new()
    for k in range(24):
        a = 2*math.pi*(k+.5)/24
        rivet(bm, skull(brim, a, pad+.008, top))
    for k in range(20):
        a = 2*math.pi*(k+.5)/20
        rivet(bm, skull(-.048, a, .006, top)+Vector((0, 0, 0)))
    piece('Rivet', bm)
    export('gladiators_helmet')


# --- The Ancient Gladiator's Helmet.
def ancient_gladiators_helmet():
    top = .27
    pad = .012
    bm = bmesh.new()
    # The skull: down over the neck and ears, open at the face below the brow.
    rows = dome_rows(top, 0.0)
    def face(i, j):
        y = (rows[i]+rows[i+1])/2
        a = 2*math.pi*(j+.5)/SEG
        if a > math.pi: a -= 2*math.pi
        return y < .15 and abs(a) < math.radians(62)
    loft(bm, [ring(y, pad, top) for y in rows], cap_end=True, skip=face)
    # The keel over the crown, and the spikes along it.
    stations = []
    for k in range(18):
        z = .095-.0115*k
        y = dome_y(z, pad, top)
        stations.append((z, y-.006, y+.016, .022))
    slab(bm, stations)
    for z in [.07, .03, -.01, -.05, -.09]:
        base = Vector((0, dome_y(z, pad, top)+.014, z))
        spike(bm, base, skull_normal(base, top), .036, .0085)
    # A row of spikes down each side of the crown.
    for side in (1, -1):
        for deg in [50, 72, 96, 122]:
            a = side*math.radians(deg)
            base = skull(.185, a, pad-.002, top)
            spike(bm, base, skull_normal(base, top), .032, .008)
    # The heavy rolled brow across the front.
    rings = []
    for k in range(25):
        a = math.radians(-66+132*k/24)
        taper = min(1.0, (1-abs(a)/math.radians(66))*4)
        r = .013*(0.3+.7*taper)
        centre = skull(.146, a, pad+.014, top)
        n = skull_normal(centre, top)
        side = Vector((math.cos(a), 0, -math.sin(a)))
        rings.append([centre+n*r*math.cos(t)+Vector((0, 1, 0))*r*math.sin(t) for t in [2*math.pi*q/10 for q in range(10)]])
    loft(bm, rings, cap_start=True, cap_end=True)
    # The nose bar, down the middle of the face from under the brow to the chin.
    rings = []
    for k in range(13):
        y = .15-.185*k/12
        w = .024+.012*math.exp(-((y-.065)/.045)**2)-.004*max(0.0, (.0-y)/.04)
        front = skull(y, 0.0, .03, top).z
        rings.append([Vector((-w/2, y, front-.006)), Vector((w/2, y, front-.006)), Vector((w/2, y, front+.006)), Vector((-w/2, y, front+.006))])
    loft(bm, rings, closed=True, cap_start=True, cap_end=True)
    # The cheek plates: from the side of the head in to the eye's edge above,
    # and nearly to the nose bar below, leaving the mouth open between.
    for side in (1, -1):
        rings = []
        for k in range(17):
            y = .14-.185*k/16
            s = min(1.0, max(0.0, (y-.055)/.03))
            s = s*s*(3-2*s)
            inner = math.radians(18+24*s)
            outer = math.radians(90)
            rings.append([skull(y, side*(inner+(outer-inner)*q/10), .018, top) for q in range(11)])
        loft(bm, rings, closed=False)
    piece('Dark', bm)
    # Hinge bosses at the temples, and rivets along the cheek plates' tops.
    bm = bmesh.new()
    for side in (1, -1):
        rivet(bm, skull(.13, side*math.radians(88), .022, top), r=.009)
        for deg in [30, 48, 66, 84]:
            rivet(bm, skull(.135, side*math.radians(deg), .02, top))
    piece('Rivet', bm)
    export('ancient_gladiators_helmet')


# --- The Steel Full Helm.
def steel_full_helm():
    top = .285
    pad = .012
    bm = bmesh.new()
    # The skull, tall and rounded, down over the ears and the neck, open at
    # the face up to the brow (the face plate covers the opening's edge).
    rows = dome_rows(top, -.05)
    def face(i, j):
        y = (rows[i]+rows[i+1])/2
        a = 2*math.pi*(j+.5)/SEG
        if a > math.pi: a -= 2*math.pi
        wide = math.radians(50) if y < .13 else math.radians(50)*max(0.0, 1-(y-.13)/.035)
        return abs(a) < wide
    loft(bm, [ring(y, pad, top) for y in rows], cap_end=True, skip=face)
    piece('Bright', bm)
    # The face plate over the opening: an eye slot across it, a field of
    # holes below, and rivets round its edge.
    bm = bmesh.new()
    cols = 40
    rows = [-.07+.006*k for k in range(41)]
    rings = []
    for y in rows:
        rings.append([skull(y, math.radians(-56+112*q/cols), pad+.008, top) for q in range(cols+1)])
    def cut(i, j):
        y = (rows[i]+rows[i+1])/2
        a = math.radians(-56+112*(j+.5)/cols)
        if .099 < y < .123 and abs(a) < math.radians(44): return True
        return -.052 < y < .082 and abs(a) < math.radians(46) and i % 2 == 0 and (j+i//2) % 2 == 0
    loft(bm, rings, closed=False, skip=cut)
    piece('Bright', bm)
    bm = bmesh.new()
    for y in [-.062+.019*k for k in range(13)]:
        for a in (math.radians(-54), math.radians(54)):
            rivet(bm, skull(y, a, pad+.012, top))
    for q in range(11):
        rivet(bm, skull(.166, math.radians(-50+100*q/10), pad+.012, top))
    piece('Rivet', bm)
    export('steel_full_helm')


gladiators_helmet()
ancient_gladiators_helmet()
steel_full_helm()
print('HELMS_READY')
