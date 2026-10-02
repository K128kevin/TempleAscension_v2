"""Builds the ground of the palace hill in the outdoor world.

The world's ground is one flat slab; the hill is this mesh laid over it: a
two-metre grid raised to the hill's height, carrying the slab's own ground
shader. The height here must match Overworld.height_at (scripts/overworld.gd);
tests/overworld.gd compares the two.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_hill.py
"""
import math
from pathlib import Path
import bpy, bmesh
ROOT = Path(__file__).resolve().parents[1]
# As in scripts/overworld.gd: half the plateau's size (east-west, north-south),
# the width of the slope round it, and its height.
HILL_HALF = (40.0, 22.0)
HILL_SLOPE = 12.0
HILL_HEIGHT = 5.5
STEP = 1.0

def height(x, z):
    """Height at a point `x` east and `z` south of the plateau's centre."""
    qx = max(abs(x)-HILL_HALF[0], 0.0)
    qz = max(abs(z)-HILL_HALF[1], 0.0)
    t = min(1.0, max(0.0, 1.0-math.hypot(qx, qz)/HILL_SLOPE))
    return HILL_HEIGHT*t*t*(3.0-2.0*t)

bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new('hill')
obj = bpy.data.objects.new('hill', mesh)
bpy.context.scene.collection.objects.link(obj)
bm = bmesh.new()
reach_x = int((HILL_HALF[0]+HILL_SLOPE)/STEP)+1
reach_z = int((HILL_HALF[1]+HILL_SLOPE)/STEP)+1
verts = {}
for j in range(-reach_z, reach_z+1):
    for i in range(-reach_x, reach_x+1):
        x, z = i*STEP, j*STEP
        # Blender's Y runs north; the game's Z runs south.
        verts[(i, j)] = bm.verts.new((x, -z, height(x, z)))
for j in range(-reach_z, reach_z):
    for i in range(-reach_x, reach_x):
        corners = [(i, j), (i+1, j), (i+1, j+1), (i, j+1)]
        # Only where the ground rises: the slab shows everywhere else.
        if all(verts[c].co.z <= 0.0 for c in corners): continue
        bm.faces.new([verts[c] for c in reversed(corners)])
for v in [v for v in bm.verts if not v.link_faces]: bm.verts.remove(v)
bm.normal_update()
bm.to_mesh(mesh)
bm.free()
for p in mesh.polygons: p.use_smooth = True
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/props/hill.glb'), export_format='GLB', export_animations=False)
print('HILL_READY', len(mesh.vertices), len(mesh.polygons))
