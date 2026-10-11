"""Builds the greatsword: assets/models/props/sword_long.glb.

It replaces the adventurers pack's toy two-handed sword (four hundred
faces). A long sword for both hands, a metre and a half: a pear-shaped
pommel; a long grip bound in a spiralled cord between two ferrules; a
crossguard whose arms curve a little toward the blade and swell to rounded
ends; a blunt ricasso, then the blade, ground from a thick spine to thin
edges, with a fuller down each face from the ricasso to two thirds of the
way along, narrowing to a point.

Every part is turned or lofted here; nothing is imported. The model is
written as the game's other arms are: in a unit box, its butt at the origin
and its length up +Y, to be given its true size (scripts/items.gd: .44 wide,
1.5 long, .13 deep) and its finish by the game (steel from `metal_from` of
its length up and below `pommel`, the grip below: assets/shaders/arms.gdshader).
Its parts stand where the item's numbers say: the grip from .06 to .405 m
(the hand at .27), the guard from .405 to .445 m.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_greatsword.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/sword_long.glb'
LENGTH, WIDTH, DEPTH = 1.5, .44, .13
POMMEL_TOP, GRIP_TOP, GUARD_TOP = .06, .405, .445
RICASSO_TOP, FULLER_TOP, TIP_START = .5, 1.24, 1.32
SEGMENTS = 24


def lathe(bm, profile, segments=SEGMENTS, ridge=None):
    """A solid turned round the length (Z): (z, radius) from end to end;
    `ridge(z, angle)` adds to the radius (a cord wound round)."""
    rings = []
    for z, r in profile:
        if r <= 0:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        ring = []
        for i in range(segments):
            a = 2*math.pi*i/segments
            rr = r+(ridge(z, a) if ridge else 0.0)
            ring.append(bm.verts.new((rr*math.cos(a), rr*math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1: continue
        for i in range(segments):
            j = (i+1) % segments
            if len(a) == 1: bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1: bm.faces.new((a[i], a[j], b[0]))
            else: bm.faces.new((a[i], a[j], b[j], b[i]))


def loft(bm, rings, cap_ends=True):
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_ends:
        bm.faces.new(vs[0][::-1])
        bm.faces.new(vs[-1])


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()

# --- The pommel: a pear of steel, a neck into the grip's lower ferrule.
lathe(bm, [(0, 0), (.002, .012), (.008, .022), (.018, .029), (.03, .03), (.042, .026), (.052, .018), (.058, .013), (.062, 0)])

# --- The grip: a ferrule at each end, the cord wound round between.
def cord(z, a):
    if z < POMMEL_TOP+.012 or z > GRIP_TOP-.012: return 0.0
    turn = (z-POMMEL_TOP)/.0105*2*math.pi+a
    return .0014*max(0.0, math.sin(turn))**.6
grip = [(POMMEL_TOP-.004, 0), (POMMEL_TOP-.004, .0175), (POMMEL_TOP+.008, .019), (POMMEL_TOP+.012, .0165)]
z = POMMEL_TOP+.012
while z < GRIP_TOP-.012:
    swell = .0165+.0015*math.sin(math.pi*(z-POMMEL_TOP)/(GRIP_TOP-POMMEL_TOP))
    grip.append((z, swell))
    z += .0018
grip += [(GRIP_TOP-.012, .0165), (GRIP_TOP-.008, .019), (GRIP_TOP+.002, .0185), (GRIP_TOP+.002, 0)]
lathe(bm, grip, segments=28, ridge=cord)

# --- The crossguard: lofted out from the middle each way, its arms curving
# toward the blade and swelling into rounded ends.
def guard_section(x):
    t = abs(x)/(WIDTH/2)
    height = .036*(1-t)+.02*t+.012*math.exp(-((t-.93)/.06)**2)
    thick = .028*(1-t)+.019*t+.008*math.exp(-((t-.93)/.06)**2)
    centre = (GRIP_TOP+GUARD_TOP)/2+.018*t*t
    pts = []
    for k in range(12):
        a = 2*math.pi*k/12
        # A rounded rectangle: a superellipse, flat faces with round edges.
        c, s = math.cos(a), math.sin(a)
        e = .35
        cy = math.copysign(abs(c)**e, c)*thick/2
        cz = math.copysign(abs(s)**e, s)*height/2
        pts.append(Vector((x, cy, centre+cz)))
    return pts
xs = [WIDTH/2*(i/20.0)**1.0 for i in range(21)]
end = WIDTH/2
rings = [guard_section(-x) for x in reversed(xs)]+[guard_section(x) for x in xs[1:]]
# Each end closed in a dome: two smaller rings beyond the last.
def dome(sign):
    base = guard_section(sign*end)
    middle = sum(p.z for p in base)/len(base)
    return [[Vector((sign*(end+dx), p.y*f, middle+(p.z-middle)*f)) for p in base] for f, dx in ((.72, .006), (.3, .0105))]
loft(bm, dome(-1)[::-1]+rings+dome(1))

# --- The blade: rows across it up its length, each a section from edge to
# edge over the front and back faces: thin edges, a thick spine, a fuller.
def half_width(z):
    if z < RICASSO_TOP: return .03
    if z < TIP_START: return .034-.007*(z-RICASSO_TOP)/(TIP_START-RICASSO_TOP)
    t = (z-TIP_START)/(LENGTH-TIP_START)
    return max(.027*(1-t)**.85, .0006)

def section(z):
    w = half_width(z)
    # (Toward the point the spine thins with the width, and the fuller's
    # lines stay inside the narrowing blade, so it comes to one true point
    # rather than flaring or forking at the tip.)
    spine = .0048 if z < TIP_START else max(.0048*(1-.93*(z-TIP_START)/(LENGTH-TIP_START)), .0004)
    edge = .0012 if z < RICASSO_TOP else .0004
    fuller = 1.0 if RICASSO_TOP+.02 < z < FULLER_TOP else (0.0 if z < RICASSO_TOP or z > FULLER_TOP+.06 else (max(0.0, 1-(z-FULLER_TOP)/.06) if z > FULLER_TOP else (z-RICASSO_TOP)/.02))
    fw = min(.0095, w*.5)
    across = [-w, -w*.6, -fw-.002, -fw, -fw*.5, 0, fw*.5, fw, fw+.002, w*.6, w]
    front = []
    for x in across:
        u = abs(x)/w if w > 0 else 0
        # Ground from the spine to the edge, flatter on the faces.
        t = edge+(spine-edge)*(1-u**1.6)
        if abs(x) <= fw:
            t -= .0016*fuller*math.sqrt(max(0.0, 1-(abs(x)/fw)**2))
        front.append(Vector((x, t, z)))
    back = [Vector((p.x, -p.y, p.z)) for p in reversed(front[1:-1])]
    return front+back

zs = [GUARD_TOP-.004]
z = GUARD_TOP
while z < LENGTH-.004:
    zs.append(z)
    z += .012 if z < TIP_START else .006
zs.append(LENGTH-.002)
loft(bm, [section(z) for z in zs])

bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
mesh = bpy.data.meshes.new('Greatsword')
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new('Greatsword', mesh)
bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
mesh.shade_smooth()
# Round where it turns, crisp at the blade's edges and the guard's faces.
bpy.ops.object.modifier_add(type='EDGE_SPLIT')
obj.modifiers[-1].split_angle = math.radians(50)
bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)

# --- Into the unit box: X across over WIDTH, the length up over LENGTH, the
# depth over DEPTH (centred), written so the exporter's Z-up to Y-up turn
# brings the length up +Y.
for v in mesh.vertices:
    p = v.co
    v.co = Vector((p.x/WIDTH, p.y/DEPTH, p.z/LENGTH))
mesh.materials.append(bpy.data.materials.new('Steel'))
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, use_selection=True)
print('GREATSWORD_READY faces=%d' % len(mesh.polygons))
