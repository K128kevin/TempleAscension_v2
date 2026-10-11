"""Builds the Marathon Boots: assets/models/props/marathon_boots.glb, the
left shoe (the game mirrors it for the right: scripts/visual.gd).

A low golden shoe that closes over the whole foot and shows nothing of its
shape: a thick sole, a smooth rounded vamp over the toes, a collar rising
just over the ankle, a short heel; on its outer side, at the ankle, a small
white wing of three feathers swept back. Each part is its own mesh, named
for its finish ("Gold", "Wing": Art.worn_model).

Built in metres about the left foot bone's head (the ankle), in the hero's
rest pose: X out to the figure's left, +Y up, +Z the way the foot points.
The game hangs it from the foot bone turned into the bone's own frame.
Written in Blender's axes (Z up, -Y the front), which the glTF exporter
turns back.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_shoes.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/marathon_boots.glb'
# The foot about the ankle (the foot bone's head, near the heel, .096 over
# the ground): the sole under it, the heel .054 behind and the toes .215
# ahead, .11 wide, its middle .017 out from the bone.
SOLE = -.1
HEEL = -.075
TOE = .238
MID_X = .017
COLLAR = .048
SEGS = 20


def emit(p):
    return Vector((p.x, -p.z, p.y))


def section(z):
    """The shoe's outline across the foot at `z`: its half-width, the height
    of its top and how round its top is (1: a full dome)."""
    along = (z-HEEL)/(TOE-HEEL)
    # Wide through the middle, drawn in at heel and toe.
    half = .064*math.sin(math.pi*min(1.0, max(0.0, (z-HEEL+.02)/(TOE-HEEL+.05))))**.45+.006
    # The collar over the ankle, dropping a little behind it, the vamp
    # falling away over the instep to the toes.
    if z < .0: top = COLLAR-.03*((-z)/(-HEEL))**2
    elif z < .05: top = COLLAR-.04*(z/.05)
    else: top = .008-.062*((z-.05)/(TOE-.05))**1.25
    top = max(top, SOLE+.03)
    return half, top


def ring(z, n=SEGS):
    """Points round the shoe's section at `z`: a flat sole, rounded sides
    and a domed top."""
    half, top = section(z)
    out = []
    for i in range(n):
        a = 2*math.pi*i/n
        c, s = math.cos(a), math.sin(a)
        # A superellipse, flatter underneath.
        x = half*math.copysign(abs(c)**.7, c)
        y = (top-SOLE)*.5*math.copysign(abs(s)**(.55 if s > 0 else .3), s)+(top+SOLE)*.5
        out.append(Vector((MID_X+x, y, z)))
    return out


def loft(bm, rings, cap_start=True, cap_end=True):
    made = [[bm.verts.new(emit(p)) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(made, made[1:]):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start: bm.faces.new(list(reversed(made[0])))
    if cap_end: bm.faces.new(made[-1])


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


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- The shoe: lofted along its length, the ends drawn to rounded caps.
bm = bmesh.new()
rings = []
stations = [HEEL+.004, HEEL+.012, HEEL+.03]+[HEEL+.05+k*.02 for k in range(13)]+[TOE-.025, TOE-.012, TOE-.004]
for z in stations:
    rings.append(ring(z))
loft(bm, rings)
# The sole, a shade proud under the shoe, with a raised heel block.
sole = []
for z in [HEEL+.006, HEEL+.02, HEEL+.05, HEEL+.1, HEEL+.16, HEEL+.22, TOE-.03, TOE-.008]:
    half, _ = section(z)
    lift = .012 if z < HEEL+.08 else .006
    sole.append([Vector((MID_X+half*1.03, SOLE+lift, z)), Vector((MID_X+half*1.03, SOLE-.006, z)), Vector((MID_X-half*1.03, SOLE-.006, z)), Vector((MID_X-half*1.03, SOLE+lift, z))])
loft(bm, sole)
piece('Gold', bm)

# --- The wing: three feathers swept back from the ankle, on the outer side.
bm = bmesh.new()
half, top = section(-.01)
root = Vector((MID_X+half+.004, top-.03, -.01))
for k, (length, lift, sweep) in enumerate([(.075, .06, -.085), (.07, .035, -.095), (.06, .012, -.09)]):
    base = root+Vector((0, -.012*k, .004*k))
    tip = base+Vector((.012, lift, sweep))
    mid = base+(tip-base)*.5+Vector((.006, .01, 0))
    width = .011
    quill = (tip-base).normalized()
    up = Vector((0, 1, 0))
    across = quill.cross(up).normalized()*width
    outline = [base-across*.4, mid-across, tip, mid+across, base+across*.4]
    front = [bm.verts.new(emit(p+Vector((.003, 0, 0)))) for p in outline]
    back = [bm.verts.new(emit(p)) for p in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(outline)):
        j = (i+1) % len(outline)
        bm.faces.new((front[i], front[j], back[j], back[i]))
    length += 0  # (the feather's reach is set by its tip)
piece('Wing', bm, smooth=False)

for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, use_selection=True)
print('SHOES_READY')
