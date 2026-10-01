"""Batch the imported character's stone surfaces into one skinned draw surface."""
from pathlib import Path
import bpy
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
# The clips are baked at 30 fps (tools/import_combat.py); exporting at
# Blender's default 24 would resample and shift them.
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(root/'assets/models/character/warrior.glb'))
# The hero's boots are the hero's own; statues stay barefoot stone.
# So are the class kits' helm, hoods, robe and robed body.
for o in [o for o in bpy.data.objects if o.name.startswith(('HeroBoots','HeroHelmet','HeroArmor','RangerHood','RangerCloak','RangerBody','WizardHood','WizardRobe','WizardCape','WizardBody'))]:bpy.data.objects.remove(o,do_unlink=True)
# The ranger's cloak and the wizard's cape bones are the hero's own too.
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for bone in [b for b in rig.data.edit_bones if b.name.startswith(('cloak_','cape_'))]:rig.data.edit_bones.remove(bone)
bpy.ops.object.mode_set(mode='OBJECT')
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
