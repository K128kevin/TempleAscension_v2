"""Add a draw morph to the existing authored bowstring; preserve original mesh."""
from pathlib import Path
import bpy
root=Path(__file__).resolve().parents[1]
path=root/'assets/models/props/bow.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
for o in bpy.data.objects:
 if o.type!='MESH':continue
 if o.data.shape_keys:o.shape_key_clear()
 o.shape_key_add(name='Basis')
 draw=o.shape_key_add(name='Draw')
 count=0
 for i,v in enumerate(o.data.vertices):
  # The string lies on +X; Blender's Z is the bow's vertical axis.
  if v.co.x>.46 and abs(v.co.y)<.08:
   # Runtime width is .25m: 1.44 model units gives a .36m string pull.
   weight=max(0,1-abs(v.co.z-.5)*2)
   draw.data[i].co.x+=1.44*weight
   draw.data[i].co.z+=(.06/1.3)*weight
   count+=1
 print('STRING_VERTICES',count)
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_animations=False,export_morph=True)
