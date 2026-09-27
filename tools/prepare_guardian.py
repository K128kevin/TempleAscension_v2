"""Batch the imported character's stone surfaces into one skinned draw surface."""
from pathlib import Path
import bpy
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'assets/models/character/warrior.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in meshes if 'SuperHero' in o.name)
bpy.ops.object.join()
body=bpy.context.object
body.name='StoneGuardian'
body.data.materials.clear()
mat=bpy.data.materials.new('Stone');mat.diffuse_color=(.65,.65,.65,1)
body.data.materials.append(mat)
for p in body.data.polygons:p.material_index=0
# Preserve the supplied shape and skinning, with a moderate mesh reduction for crowds.
mod=body.modifiers.new('Crowd optimization','DECIMATE');mod.ratio=.55
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/character/guardian.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('GUARDIAN_READY',len(body.data.vertices))
