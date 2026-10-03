"""Adds the hero's walk to assets/models/character/warrior.glb.

Walk is the Universal Animation Library's Walk_Loop, retargeted onto the hero
exactly as tools/import_character.py retargets its clips (rotations in the
armature's space, the hero's own limb lengths kept). The game derives the
weapon-carrying walks from it (scripts/visual.gd). Run after the other
character tools; safe to rerun.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_walk.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Matrix
ROOT = Path(__file__).resolve().parents[1]
ANIMS = Path('/Users/ktabb/Documents/3dAssets')/'Universal Animation Library[Standard]'
OUT = ROOT/'assets/models/character'
CLIPS = {'Walk': 'Walk_Loop'}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(OUT/'warrior.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
original = set(bpy.data.objects)
for track in list(rig.animation_data.nla_tracks):
    if track.name in CLIPS: rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action.name in CLIPS: bpy.data.actions.remove(action)
for track in rig.animation_data.nla_tracks: track.mute = True
rig.animation_data.action = None
bpy.ops.import_scene.gltf(filepath=str(ANIMS/'Unreal-Godot/UAL1_Standard.glb'))
source = next(o for o in bpy.data.objects if o.type == 'ARMATURE' and o != rig)
source_objects = set(bpy.data.objects)-original
for track in list(source.animation_data.nla_tracks): source.animation_data.nla_tracks.remove(track)
bones = sorted(rig.data.bones, key=lambda b: len(b.parent_recursive))
for output_name, source_name in CLIPS.items():
    source_action = bpy.data.actions[source_name]
    source.animation_data.action = source_action
    end = source_action.frame_range[1]
    action = bpy.data.actions.new(output_name)
    rig.animation_data.action = action
    for frame in range(math.ceil(end)+1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for bone in bones:
            pose = rig.pose.bones[bone.name]
            sb = source.data.bones.get(bone.name)
            if sb is not None:
                sp = source.pose.bones[bone.name]
                rotation = sp.matrix.to_quaternion() @ sb.matrix_local.to_quaternion().inverted() @ bone.matrix_local.to_quaternion()
                if bone.parent:
                    parent_pose = rig.pose.bones[bone.parent.name]
                    head = parent_pose.matrix @ bone.parent.matrix_local.inverted() @ bone.head_local
                else:
                    head = bone.head_local.copy()
                if bone.name in ('root', 'pelvis'):
                    # Retain animated vertical/horizontal offsets relative to rest.
                    rest_basis = bone.matrix_local.to_3x3()
                    if bone.parent:
                        rest_basis = parent_pose.matrix.to_3x3() @ bone.parent.matrix_local.to_3x3().inverted() @ rest_basis
                    head += rest_basis @ sp.location
                pose.matrix = Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
            # (Bones the library lacks, the cloth chains, are keyed at rest.)
            pose.keyframe_insert('location', frame=frame)
            pose.keyframe_insert('rotation_quaternion', frame=frame)
            pose.keyframe_insert('scale', frame=frame)
            bpy.context.view_layer.update()
    rig.animation_data.action = None
    track = rig.animation_data.nla_tracks.new()
    track.name = output_name
    strip = track.strips.new(output_name, 0, action)
    strip.action_frame_end = end
    track.mute = True
    print('WALK_CLIP', output_name, end)
for bone in rig.pose.bones: bone.matrix_basis = Matrix.Identity(4)
for track in rig.animation_data.nla_tracks: track.mute = False
for obj in source_objects:
    if obj.name in bpy.data.objects: bpy.data.objects.remove(obj, do_unlink=True)
used = {s.action for t in rig.animation_data.nla_tracks for s in t.strips}
for action in list(bpy.data.actions):
    if action not in used: bpy.data.actions.remove(action)
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUT/'warrior.glb'), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print('WALK_READY', len(rig.animation_data.nla_tracks))
