"""Builds the war hammer: assets/models/props/war_hammer.glb.

A two-handed maul, a metre and thirty-five long: an ash haft, thickened
where the hands take it and bound in leather there, with an iron cap at its
foot and an iron collar under the head; the head an iron block set across
the haft, a broad square striking face on one side (chamfered, its face
dished a little by use) and a four-sided spike tapering out of the other,
a short spike standing out of its top, and two iron straps binding the
block to the haft.

Every part is turned or cut here, as the mace is (tools/make_mace.py);
nothing is imported. The model is written as the game's other arms are: in
a unit box, its butt at the origin and its length up +Y, to be given its
true size and its finish by the game (iron from `metal_from` of its length
up, wood below: assets/shaders/arms.gdshader). The face stands out along
+X, the spike along -X: the heavy swings lead with the hand's X
(tools/import_heavy.py), so the face meets what is struck.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_warhammer.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/war_hammer.glb'
LENGTH = 1.35
# The haft's profile: (height, radius), turned round its axis. The foot's
# iron cap, the haft swelling under the grip, the leather binding (a raised
# band of it where the hands go, .2 to .55 up), and the collar under the head.
PROFILE = [(0, 0), (.004, .02), (.03, .024), (.045, .02), (.05, .017), (.19, .018), (.2, .021), (.21, .023),
    (.54, .023), (.55, .021), (.56, .018), (1.0, .019), (1.04, .021), (1.06, .025), (1.09, .025), (1.1, .02), (1.3, .018), (1.3, 0)]
# The head block: its height along the haft, and its half-widths.
HEAD_LOW, HEAD_HIGH = 1.1, 1.3
HALF_Y = .055
# The face side: how far out it stands and the face's half-size.
FACE_OUT = .14
FACE_HALF = .07
# The spike side: how far out its point stands.
SPIKE_OUT = .2
# The top spike.
TOP_SPIKE = 1.35


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
    """An axis-aligned block from corner `lo` to corner `hi`."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    v = [bm.verts.new(p) for p in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
    for face in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        bm.faces.new([v[i] for i in face])


def loft(bm, rings):
    """Rings of the same count joined in turn, capped at both ends."""
    made = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(made, made[1:]):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(made[0])))
    bm.faces.new(made[-1])


def spike(bm, base_centre, axis, length, half):
    """A four-sided spike: a square base tapering to a point along `axis`."""
    axis = Vector(axis).normalized()
    up = Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((1, 0, 0))
    side = axis.cross(up).normalized()
    up = side.cross(axis).normalized()
    c = Vector(base_centre)
    base = [c+side*half+up*half, c-side*half+up*half, c-side*half-up*half, c+side*half-up*half]
    # (A little way out the spike is still square, then it draws to its point.)
    mid = [c+axis*length*.35+(p-c)*.7 for p in base]
    tip = [c+axis*length+(p-c)*.02 for p in base]
    loft(bm, [base, mid, tip])


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
lathe(bm, PROFILE)
# The head block round the haft, from behind the face to the spike's root.
mid = (HEAD_LOW+HEAD_HIGH)/2
box(bm, (-.06, -HALF_Y, HEAD_LOW), (FACE_OUT-.03, HALF_Y, HEAD_HIGH))
# The face: a broader square plate, chamfered back to the block.
face_rings = [
    [(FACE_OUT-.03, -HALF_Y, HEAD_LOW+.01), (FACE_OUT-.03, HALF_Y, HEAD_LOW+.01), (FACE_OUT-.03, HALF_Y, HEAD_HIGH-.01), (FACE_OUT-.03, -HALF_Y, HEAD_HIGH-.01)],
    [(FACE_OUT-.012, -FACE_HALF, mid-FACE_HALF*1.3), (FACE_OUT-.012, FACE_HALF, mid-FACE_HALF*1.3), (FACE_OUT-.012, FACE_HALF, mid+FACE_HALF*1.3), (FACE_OUT-.012, -FACE_HALF, mid+FACE_HALF*1.3)],
    [(FACE_OUT, -FACE_HALF*.85, mid-FACE_HALF*1.1), (FACE_OUT, FACE_HALF*.85, mid-FACE_HALF*1.1), (FACE_OUT, FACE_HALF*.85, mid+FACE_HALF*1.1), (FACE_OUT, -FACE_HALF*.85, mid+FACE_HALF*1.1)]]
loft(bm, face_rings)
# The spike out of the other side, and the short one from the top.
spike(bm, (-.06, 0, mid), (-1, 0, 0), SPIKE_OUT-.06, HALF_Y*.9)
spike(bm, (0, 0, HEAD_HIGH), (0, 0, 1), TOP_SPIKE-HEAD_HIGH, .022)
# Two straps binding the head to the haft, above and below the block.
for z in (HEAD_LOW-.02, HEAD_HIGH):
    box(bm, (-.07, -HALF_Y-.006, z), (FACE_OUT-.02, HALF_Y+.006, z+.02))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
# Into the unit box the game sizes its arms from.
lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), 0))
hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), LENGTH))
for v in bm.verts:
    v.co = Vector(((v.co.x-(lo.x+hi.x)/2)/(hi.x-lo.x), (v.co.y-(lo.y+hi.y)/2)/(hi.y-lo.y), v.co.z/LENGTH))
mesh = bpy.data.meshes.new('WarHammer')
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new('WarHammer', mesh)
bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
# The haft turns smoothly; the head keeps its flat faces (by angle).
bpy.ops.object.shade_smooth()
try:
    bpy.ops.object.modifier_add(type='EDGE_SPLIT')
    obj.modifiers[-1].split_angle = math.radians(40)
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
except Exception as e:
    print('no edge split', e)
mesh.materials.append(bpy.data.materials.new('Iron'))
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False)
print('WARHAMMER_READY', tuple(hi-lo))
