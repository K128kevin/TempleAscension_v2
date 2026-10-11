"""Builds the warrior's hatchet, a bearded axe: assets/models/props/bearded_axe.glb.

After a forged bearded axe: a long sweeping cutting edge drawn out above
into a horn and below into a beard, hollowed under toward the haft, the
cheek flat and thick at the eye and ground thin to the edge (a polished
bevel the width of a thumb along it); a short square poll behind the eye;
steel langets running down the haft from the eye on the blade's side and
the poll's; a dark hardwood haft, swelled at its foot under a steel cap,
with two engraved steel bands part way down.

Every part is its own mesh, named for its finish ("Head", "Haft",
"Fittings"), coloured by the game (Art.weapon_model, finish "axe"). The
blade carries UVs the head's shader reads (assets/shaders/axe.gdshader):
U is 0 at the eye and 1 at the cutting edge, V runs along the edge from the
horn to the beard. The model is written as the game's other arms are: in a
unit box, its butt at the origin and its length up +Y (tools/make_warhammer.py),
the blade standing out along +X (held, the look's `turn` brings it round to
lead the swing; its `haft` says where across the box the haft stands).

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_axe.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/bearded_axe.glb'
LENGTH = .72
# The haft (height, radius), turned round its axis: a swelled foot under the
# cap, a slim shaft, a little fuller under the eye, and up through it.
HAFT = [(.0, 0), (.0, .012), (.025, .013), (.045, .0165), (.07, .0145), (.4, .0135), (.5, .0145), (.555, .0145), (.655, .013), (.655, 0)]
EYE_LOW, EYE_HIGH = .555, .645
EYE_HALF = .017


def lathe(bm, profile, segments=20):
    rings = []
    for z, r in profile:
        if r <= 0:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        rings.append([bm.verts.new((r*math.cos(2*math.pi*i/segments), r*math.sin(2*math.pi*i/segments), z)) for i in range(segments)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1: continue
        for i in range(segments):
            j = (i+1) % segments
            if len(a) == 1: bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1: bm.faces.new((a[i], a[j], b[0]))
            else: bm.faces.new((a[i], a[j], b[j], b[i]))


def box(bm, lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    v = [bm.verts.new(p) for p in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
    for face in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        bm.faces.new([v[i] for i in face])


def loft(bm, rings, cap=True):
    made = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(made, made[1:]):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(list(reversed(made[0])))
        bm.faces.new(made[-1])


def bezier(p0, p1, p2, t):
    return p0*(1-t)**2+p1*2*(1-t)*t+p2*t*t


def piece(name, bm, smooth=True, split=None):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if smooth: bpy.ops.object.shade_smooth()
    if split is not None:
        bpy.ops.object.modifier_add(type='EDGE_SPLIT')
        obj.modifiers[-1].split_angle = math.radians(split)
        bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    obj.select_set(False)
    mesh.materials.append(bpy.data.materials.new(name))
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- The haft.
bm = bmesh.new()
lathe(bm, HAFT)
piece('Haft', bm)

# --- The fittings: the foot's cap, two bands, the langets, and the poll.
bm = bmesh.new()
lathe(bm, [(.0, 0), (.0, .0135), (.022, .0145), (.03, .0135), (.03, 0)])
for low, high in [(.18, .215), (.33, .365)]:
    lathe(bm, [(low, .0132), (low+.004, .0152), (high-.004, .0152), (high, .0132)])
for x0, x1 in [(.012, .019), (-.019, -.012)]:
    box(bm, (x0, -.0075, .45), (x1, .0075, EYE_LOW+.005))
    # (Each langet ends in a point.)
    loft(bm, [[(x0, -.0075, .45), (x1, -.0075, .45), (x1, .0075, .45), (x0, .0075, .45)],
        [((x0+x1)/2-.002, -.001, .415), ((x0+x1)/2+.002, -.001, .415), ((x0+x1)/2+.002, .001, .415), ((x0+x1)/2-.002, .001, .415)]], cap=True)
# The poll: a short square lug behind the eye, drawn to a blunt point.
loft(bm, [[(-.03, -EYE_HALF, .57), (-.03, EYE_HALF, .57), (-.03, EYE_HALF, .632), (-.03, -EYE_HALF, .632)],
    [(-.062, -.011, .585), (-.062, .011, .585), (-.062, .011, .62), (-.062, -.011, .62)],
    [(-.078, -.004, .596), (-.078, .004, .596), (-.078, .004, .608), (-.078, -.004, .608)]])
piece('Fittings', bm, split=40)

# --- The head: the eye round the haft, and the bearded blade.
bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new('UVMap')
box(bm, (-.034, -EYE_HALF, EYE_LOW), (.042, EYE_HALF, EYE_HIGH))
# The blade: a sheet between its root at the eye and its cutting edge,
# ground from the eye's thickness to the edge, both faces and the rims.
ROOT_LINE = [Vector((.042, .645)), Vector((.042, .60)), Vector((.042, .555)), Vector((.07, .548)), Vector((.1, .536)), Vector((.125, .512))]
def root(u):
    # (Piecewise along the root line.)
    s = u*(len(ROOT_LINE)-1)
    i = min(int(s), len(ROOT_LINE)-2)
    return ROOT_LINE[i].lerp(ROOT_LINE[i+1], s-i)
def edge(u):
    return bezier(Vector((.142, .722)), Vector((.195, .615)), Vector((.14, .498)), u)
V_ROWS = [0.0, .3, .55, .75, .88, .96, 1.0]
U_ROWS = 22
def thick(v):
    return .0085*(1-v)**.55+.0009
grid = {}
for ui in range(U_ROWS+1):
    u = ui/U_ROWS
    r = root(u); e = edge(u)
    for vi, v in enumerate(V_ROWS):
        p = r.lerp(e, v)
        # (The flat of the cheek is hollowed a little toward the edge, as
        # ground steel is: the sheet thins faster than its line.)
        t = thick(v)
        grid[(ui, vi, 1)] = bm.verts.new((p.x, t, p.y))
        grid[(ui, vi, -1)] = bm.verts.new((p.x, -t, p.y))
def quad(a, b, c, d, uvs):
    f = bm.faces.new((a, b, c, d))
    for loop, uv in zip(f.loops, uvs): loop[uv_layer].uv = uv
    return f
for ui in range(U_ROWS):
    for vi in range(len(V_ROWS)-1):
        u0, u1 = ui/U_ROWS, (ui+1)/U_ROWS
        v0, v1 = V_ROWS[vi], V_ROWS[vi+1]
        quad(grid[(ui, vi, 1)], grid[(ui+1, vi, 1)], grid[(ui+1, vi+1, 1)], grid[(ui, vi+1, 1)], [(v0, u0), (v0, u1), (v1, u1), (v1, u0)])
        quad(grid[(ui, vi+1, -1)], grid[(ui+1, vi+1, -1)], grid[(ui+1, vi, -1)], grid[(ui, vi, -1)], [(v1, u0), (v1, u1), (v0, u1), (v0, u0)])
# The rims: the spine from the eye to the horn, the beard's underside, and
# the edge itself.
last = len(V_ROWS)-1
for vi in range(last):
    v0, v1 = V_ROWS[vi], V_ROWS[vi+1]
    quad(grid[(0, vi, -1)], grid[(0, vi+1, -1)], grid[(0, vi+1, 1)], grid[(0, vi, 1)], [(v0, 0), (v1, 0), (v1, 0), (v0, 0)])
    quad(grid[(U_ROWS, vi, 1)], grid[(U_ROWS, vi+1, 1)], grid[(U_ROWS, vi+1, -1)], grid[(U_ROWS, vi, -1)], [(v0, 1), (v1, 1), (v1, 1), (v0, 1)])
for ui in range(U_ROWS):
    u0, u1 = ui/U_ROWS, (ui+1)/U_ROWS
    quad(grid[(ui, last, 1)], grid[(ui+1, last, 1)], grid[(ui+1, last, -1)], grid[(ui, last, -1)], [(1, u0), (1, u1), (1, u1), (1, u0)])
    quad(grid[(ui, 0, -1)], grid[(ui+1, 0, -1)], grid[(ui+1, 0, 1)], grid[(ui, 0, 1)], [(0, u0), (0, u1), (0, u1), (0, u0)])
piece('Head', bm, split=50)

# --- Into the unit box the game sizes its arms from (all parts alike).
verts = [v for o in bpy.data.objects for v in o.data.vertices]
lo = Vector((min(v.co.x for v in verts), min(v.co.y for v in verts), 0))
hi = Vector((max(v.co.x for v in verts), max(v.co.y for v in verts), LENGTH))
for o in bpy.data.objects:
    for v in o.data.vertices:
        v.co = Vector(((v.co.x-(lo.x+hi.x)/2)/(hi.x-lo.x), (v.co.y-(lo.y+hi.y)/2)/(hi.y-lo.y), v.co.z/LENGTH))
for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, use_selection=True)
print('AXE_READY size=(%.3f, %.3f, %.3f) haft=%.3f edge=(%.3f, %.3f)' % (hi.x-lo.x, LENGTH, hi.y-lo.y, -(lo.x+hi.x)/2/(hi.x-lo.x), .498/LENGTH, .722/LENGTH))
