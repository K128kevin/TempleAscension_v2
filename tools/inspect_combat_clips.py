from pathlib import Path
import bpy
p=Path('/Users/ktabb/Documents/3dAssets/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(p))
r=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for t in list(r.animation_data.nla_tracks):r.animation_data.nla_tracks.remove(t)
for name in ['Sword_Regular_A_Rec','Sword_Regular_B_Rec','Sword_Regular_C','TreeChopping_Loop','Sword_Dash']:
 a=bpy.data.actions[name];r.animation_data.action=a
 print('CLIP',name,a.frame_range[:])
 for t in [0,.2,.4,.6,.8,1]:
  bpy.context.scene.frame_set(int(a.frame_range.y*t));bpy.context.view_layer.update()
  print(t,[(b,tuple(round(v,2) for v in r.pose.bones[b].matrix.translation)) for b in ['hand_r','hand_l','pelvis']])
 print('BONES',[(b.name,tuple(round(v,2) for v in b.head_local)) for b in r.data.bones if b.name in ['upperarm_l','upperarm_r','lowerarm_l','lowerarm_r','hand_l','hand_r','Head']])
