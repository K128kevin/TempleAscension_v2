"""Builds the wizard's hat: assets/models/props/wizard_hat.glb.

A tall felt hat with a wide brim: the brim a broad ring, drooping a little
toward its edge and waved round it as old felt is; the crown a cone rising
from the band, creased and bent over toward its point, which falls back and
to one side; a leather band round its foot with a small bronze buckle at the
front. Each part is its own mesh, named for what it is made of ("Felt",
"Band", "Buckle"), so the game colours it (Art.worn_model).

The model is in metres, its crown up +Y and the hat facing -Z (the buckle
there); its origin is at the middle of the brim, where it sits on the head:
the game hangs it from the hero's head bone (scripts/visual.gd HAT_ON_HEAD).

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_hat.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/wizard_hat.glb'
SIDES = 28
BRIM_IN = .115
BRIM_OUT = .3
CROWN = .46
# Where the point ends up: back and to the right of the crown, and how far
# down it bends.
BEND = Vector((.1, -.14, .16))


def ring(radius, height, centre=(0, 0), wave=0.0, seed=0.0):
    out = []
    for i in range(SIDES):
        a = 2*math.pi*i/SIDES
        r = radius*(1+wave*math.sin(a*3+seed)*.5+wave*math.sin(a*5+seed*2)*.3)
        out.append(Vector((centre[0]+r*math.cos(a), height, centre[1]+r*math.sin(a))))
    return out


def loft(bm, rings, cap_start=False, cap_end=False):
    made = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(made, made[1:]):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start: bm.faces.new(list(reversed(made[0])))
    if cap_end: bm.faces.new(made[-1])


def piece(name, bm, smooth=True):
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


bpy.ops.wm.read_factory_settings(use_empty=True)
# Blender is Z up; the game reads +Y up from glTF, which the exporter turns.
# Everything here is built with Y up and swapped on export (glTF exporter:
# Y up by default from Blender Z up), so build in Blender's own axes: X
# across, Y forward (-Y the front), Z up.
def up(p):
    return Vector((p.x, -p.z, p.y))

# --- The brim: top and underside, waved round the edge and drooping outward.
bm = bmesh.new()
rings_top = []
rings_under = []
steps = [(BRIM_IN, 0.0), (BRIM_IN+.03, .004), (BRIM_OUT*.6, -.004), (BRIM_OUT*.85, -.018), (BRIM_OUT, -.034)]
for r, h in steps:
    rings_top.append([up(p+Vector((0, .008, 0))) for p in ring(r, h, wave=.05 if r > BRIM_IN+.05 else 0.0, seed=1.3)])
    rings_under.append([up(p) for p in ring(r, h, wave=.05 if r > BRIM_IN+.05 else 0.0, seed=1.3)])
loft(bm, rings_top)
loft(bm, list(reversed(rings_under)))
# The edge, joining top to underside.
loft(bm, [rings_under[-1], rings_top[-1]])
# --- The crown: a cone bent over, creased round it.
crown = []
for k in range(13):
    t = k/12
    h = t*CROWN
    r = BRIM_IN*(1-t)**1.15+.004*(1-t)
    bend = BEND*t*t
    crease = .07*math.sin(t*math.pi) if t > .15 else 0.0
    crown.append([up(p) for p in ring(max(r, .004), h+bend.y, centre=(bend.x, bend.z), wave=crease, seed=2.1+t*3)])
loft(bm, crown, cap_end=True)
brim_crown = piece('Felt', bm)
# --- The band round the crown's foot, and its buckle at the front.
bm = bmesh.new()
band = []
for h, r in [(.012, BRIM_IN+.006), (.055, BRIM_IN*.9+.006)]:
    band.append([up(p) for p in ring(r, h)])
loft(bm, band)
band_obj = piece('Band', bm)
bm = bmesh.new()
# (A small bronze rectangle set on the band's front, with a hole.)
w, hgt, d = .022, .03, .006
cx, cz = 0.0, -(BRIM_IN+.004)
front = [Vector((cx-w, cz, .018)), Vector((cx+w, cz, .018)), Vector((cx+w, cz, .018+hgt)), Vector((cx-w, cz, .018+hgt))]
back = [v+Vector((0, d, 0)) for v in front]
verts = [bm.verts.new(v) for v in front+back]
for face in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
    bm.faces.new([verts[i] for i in face])
buckle = piece('Buckle', bm, smooth=False)
for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, use_selection=True)
print('HAT_READY')
