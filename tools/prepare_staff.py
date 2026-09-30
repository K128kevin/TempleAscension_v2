"""Build the Oracle's staff from the Kenney Mini Dungeon spear.

Run with Blender --background --python tools/prepare_staff.py. The spear's own
vertices are reshaped, no geometry is generated: the shaft is drawn out into a
long, slender staff, the steel collar is kept, and the diamond head is enlarged
and swelled into a teardrop crown, after the reference staff the user shared.
Exports assets/models/props/oracle_staff.glb normalized like the other props:
centered, base at 0, unit bounds, +Y along the staff.
"""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SPEAR = ROOT/'source_art/mini/Models/GLB format/weapon-spear.glb'
OUT = ROOT/'assets/models/props/oracle_staff.glb'
SHAFT_TOP = .29       # the spear's wooden shaft ends here (model units)
HEAD_BASE = .47       # the diamond head starts here
SHAFT_STRETCH = 5.4
HEAD_WIDEN = 1.7
HEAD_LENGTHEN = 1.9

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SPEAR))
spear = next(o for o in bpy.data.objects if o.type=='MESH')
spear.data.transform(spear.matrix_world); spear.matrix_world.identity(); spear.parent = None
lift = SHAFT_TOP*(SHAFT_STRETCH-1)
for v in spear.data.vertices:
    z = v.co.z
    if z <= SHAFT_TOP:
        v.co.z = z*SHAFT_STRETCH
    elif z < HEAD_BASE:
        v.co.z = z+lift
    else:
        # Teardrop: widest a little above the collar, drawn to a point.
        u = (z-HEAD_BASE)/max(.001,.6-HEAD_BASE)
        swell = HEAD_WIDEN*(1.0+.35*max(0.0,1.0-abs(u-.35)/.35))
        # The spear's blade is flat; round it out so the crown is full from every side.
        v.co.x *= swell; v.co.y *= swell*2.1
        v.co.z = HEAD_BASE+lift+(z-HEAD_BASE)*HEAD_LENGTHEN
pts = [v.co.copy() for v in spear.data.vertices]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
size = hi-lo
for v in spear.data.vertices:
    p = v.co
    v.co = Vector(((p.x-(lo.x+hi.x)/2)/size.x,(p.y-(lo.y+hi.y)/2)/size.y,(p.z-lo.z)/size.z))
for o in list(bpy.data.objects):
    if o != spear: bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_animations=False)
print('STAFF_READY',tuple(round(x,3) for x in size))
