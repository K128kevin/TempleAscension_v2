"""Builds the flanged mace: assets/models/props/mace.glb.

A one-handed war mace, eighty centimetres long: an ash haft swelling a little
toward the hand, a round iron pommel, a leather-bound grip between two iron
collars, and above them a head of seven iron flanges standing out from a
socketed core (each a blade widest at its middle, tapering to the haft below
and to the finial above), under a short spike.

Every part is turned or cut here, as on a lathe; nothing is imported. The
model is written as the game's other arms are (tools/prepare_models.py): in
a unit box, its butt at the origin and its length up +Y, to be given its true
size and its finish by the game (iron above the haft, wood below:
assets/shaders/arms.gdshader, `metal_from` .62).

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_mace.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/mace.glb'
LENGTH = .8
FLANGES = 7
# The haft's profile: (height, radius), turned round its axis.
PROFILE = [(0, 0), (.004, .017), (.018, .023), (.034, .021), (.046, .0135), (.05, .016), (.06, .016), (.064, .0145), (.19, .0155), (.194, .017),
    (.204, .017), (.208, .0135), (.5, .0125), (.52, .017), (.53, .0235), (.69, .0235), (.7, .019), (.715, .014), (.745, .011), (.8, 0)]
# A flange: where it leaves the core, its widest point and where it ends
# (heights), and how far out it stands there.
FLANGE = [(.535, .024), (.565, .062), (.61, .085), (.655, .07), (.7, .024)]
THICK = .0075


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


def flange(bm, angle):
    """One blade of the head: a flat plate, thinned to an edge at its rim."""
    c, s = math.cos(angle), math.sin(angle)
    out = Vector((c, s, 0))
    side = Vector((-s, c, 0))
    inner = []
    rim = []
    for z, r in FLANGE:
        inner.append([bm.verts.new(out*.018+side*w+Vector((0, 0, z))) for w in (-THICK*.5, THICK*.5)])
        rim.append(bm.verts.new(out*r+Vector((0, 0, z))))
    for i in range(len(FLANGE)-1):
        for k in (0, 1):
            quad = (inner[i][k], inner[i+1][k], rim[i+1], rim[i])
            bm.faces.new(quad if k else tuple(reversed(quad)))
    bm.faces.new((inner[0][0], inner[0][1], rim[0]))
    bm.faces.new((inner[-1][1], inner[-1][0], rim[-1]))


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
lathe(bm, PROFILE)
for i in range(FLANGES): flange(bm, 2*math.pi*i/FLANGES)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
# Into the unit box the game sizes its arms from.
lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), 0))
hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), LENGTH))
for v in bm.verts:
    v.co = Vector(((v.co.x-(lo.x+hi.x)/2)/(hi.x-lo.x), (v.co.y-(lo.y+hi.y)/2)/(hi.y-lo.y), v.co.z/LENGTH))
mesh = bpy.data.meshes.new('Mace')
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new('Mace', mesh)
bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
# The haft and collars turn smoothly; the flanges keep their flat faces.
bpy.ops.object.shade_smooth()
mesh.materials.append(bpy.data.materials.new('Iron'))
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False)
print('MACE_READY', tuple(hi-lo))
