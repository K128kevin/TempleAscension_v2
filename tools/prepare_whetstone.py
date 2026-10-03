"""Takes the grindstone's wheel off its frame, so the game can turn it.

assets/models/props/whetstone.glb (tools/prepare_models.py) is one mesh. The
stone, its hubs and the crank are separated from the frame here (they are the
mesh's own loose parts about the axle) and written as whetstone_wheel.glb, in
the same unit space but about the axle, which scripts/world_interiors.gd
WHEEL_AXLE places. The frame is written back without them. Safe to rerun
(prepare_models.py --only whetstone restores the whole model first).

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/prepare_whetstone.py
"""
from pathlib import Path
import bpy, bmesh
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props'
# The axle, in the unit model (Blender's axes: it runs along Y).
AXLE = Vector((0.0, 0.0, .70))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'whetstone.glb'))
frame = next(o for o in bpy.data.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = frame
frame.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='DESELECT')
bm = bmesh.from_edit_mesh(frame.data)
seen = set()
turning = 0
for start in bm.verts:
    if start.index in seen: continue
    part = [start]
    stack = [start]
    seen.add(start.index)
    while stack:
        v = stack.pop()
        for e in v.link_edges:
            w = e.other_vert(v)
            if w.index not in seen:
                seen.add(w.index)
                part.append(w)
                stack.append(w)
    lo = Vector([min(v.co[i] for v in part) for i in range(3)])
    hi = Vector([max(v.co[i] for v in part) for i in range(3)])
    centre = (lo+hi)/2
    off = Vector((centre.x-AXLE.x, 0, centre.z-AXLE.z)).length
    reach = max(hi.x-lo.x, hi.z-lo.z)/2
    # About the axle: the stone and its faces, the hubs; and the crank, which
    # hangs off the axle's end (narrow: not the boards lying under the frame).
    crank = lo.y < -.3 and hi.y < 0 and abs(centre.x) < .1 and hi.z < .8 and hi.x-lo.x < .1
    if (off < .04 and reach < .34) or crank:
        for v in part:
            v.select = True
            for f in v.link_faces: f.select = True
        turning += len(part)
bm.select_flush(True)
bmesh.update_edit_mesh(frame.data)
bpy.ops.mesh.separate(type='SELECTED')
bpy.ops.object.mode_set(mode='OBJECT')
wheel = next(o for o in bpy.data.objects if o.type == 'MESH' and o != frame)
for v in wheel.data.vertices: v.co -= AXLE
print('WHETSTONE', turning, 'vertices turn;', len(frame.data.vertices), 'stay')
for obj, name in [(wheel, 'whetstone_wheel'), (frame, 'whetstone')]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB', export_animations=False, use_selection=True)
