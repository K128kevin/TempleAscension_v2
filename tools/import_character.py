"""Prepare the user's Quaternius CC0 character and retarget ten gameplay clips.
Run with Blender --background --python tools/import_character.py.
Original downloads are read only; output is a self-contained game GLB.
"""
from pathlib import Path
import json
import math
import shutil
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
BASE = Path('/Users/ktabb/Documents/3dAssets') / 'Universal Base Characters[Standard]'
ANIMS = Path('/Users/ktabb/Documents/3dAssets') / 'Universal Animation Library[Standard]'
OUT = ROOT / 'assets/models/character'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ANIMS / 'Unreal-Godot/UAL1_Standard.glb'))
source = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
source.name = 'AnimationSource'
source_objects = set(bpy.data.objects)
for track in list(source.animation_data.nla_tracks): source.animation_data.nla_tracks.remove(track)
actions = {a.name: a for a in bpy.data.actions}
# Repair two broken texture references in the distributed glTF and use its
# supplied OpenGL normal maps. Stage only inside the workspace.
stage = ROOT / 'source_art/universal_stage'
stage.mkdir(parents=True, exist_ok=True)
directory = BASE / 'Base Characters/Godot - UE'
doc = json.loads((directory / 'Superhero_Male_FullBody.gltf').read_text())
for buffer in doc['buffers']:
    shutil.copy2(directory / buffer['uri'], stage / buffer['uri'])
for img in doc['images']:
    filename = img['uri'].replace('_Normal_png.png', '_Normal.png')
    normal = BASE / 'Base Characters/Textures/Normals Unity - Godot' / filename
    original = normal if normal.exists() else directory / filename
    shutil.copy2(original, stage / filename)
    img['uri'] = filename
(stage / 'character.gltf').write_text(json.dumps(doc))
bpy.ops.import_scene.gltf(filepath=str(stage / 'character.gltf'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE' and o != source)
rig.name = 'WarriorRig'
# Add short hair from the matching base-character pack.
before_hair = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_SimpleParted.gltf'))
for obj in set(bpy.data.objects) - before_hair:
    if obj.type == 'MESH':
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.matrix_world = world
        for mat in obj.data.materials:
            if not mat or not mat.use_nodes: continue
            bsdf = mat.node_tree.nodes.get('Principled BSDF')
            color = bsdf.inputs['Base Color']
            for link in list(color.links): mat.node_tree.links.remove(link)
            color.default_value = (.12, .055, .025, 1)
        for modifier in obj.modifiers:
            if modifier.type == 'ARMATURE': modifier.object = rig
    elif obj.type == 'ARMATURE':
        bpy.data.objects.remove(obj, do_unlink=True)

# Bake rotational motion in armature space, preserving target limb lengths.
# Root/hip translations keep the library's in-place movement and vertical roll.
rig.animation_data_create()
# Use the relaxed neutral idle and forward run from the universal library.
clips = {'Idle':'Idle_Loop', 'Run':'Sprint_Loop', 'Attack':'Sword_Attack',
         'Cleave':'Sword_Attack', 'Evade':'Roll', 'Death':'Death01', 'Cast':'Spell_Simple_Shoot', 'Thrust':'Punch_Cross', 'Crouch':'Crouch_Fwd_Loop', 'Hit':'Hit_Chest'}
bones = sorted(rig.data.bones, key=lambda b: len(b.parent_recursive))
for output_name, source_name in clips.items():
    source.animation_data.action = actions[source_name]
    start, end = actions[source_name].frame_range
    action = bpy.data.actions.new(output_name)
    rig.animation_data.action = action
    for frame in range(math.ceil(end) + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for bone in bones:
            pose = rig.pose.bones[bone.name]
            sb = source.data.bones.get(bone.name)
            if sb is None: continue
            sp = source.pose.bones[bone.name]
            rotation = sp.matrix.to_quaternion() @ sb.matrix_local.to_quaternion().inverted() @ bone.matrix_local.to_quaternion()
            if bone.parent:
                parent_pose = rig.pose.bones[bone.parent.name]
                head = parent_pose.matrix @ bone.parent.matrix_local.inverted() @ bone.head_local
            else:
                head = bone.head_local.copy()
            if bone.name in ('root', 'pelvis'):
                # Retain animated vertical/horizontal offsets relative to rest.
                delta = sp.location
                rest_basis = bone.matrix_local.to_3x3()
                if bone.parent:
                    rest_basis = parent_pose.matrix.to_3x3() @ bone.parent.matrix_local.to_3x3().inverted() @ rest_basis
                head += rest_basis @ delta
            pose.matrix = Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
            pose.keyframe_insert('location', frame=frame)
            pose.keyframe_insert('rotation_quaternion', frame=frame)
            pose.keyframe_insert('scale', frame=frame)
            bpy.context.view_layer.update()
    track = rig.animation_data.nla_tracks.new(); track.name = output_name
    strip = track.strips.new(output_name, 0, action); strip.action_frame_end = end
    track.mute = True
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
for obj in source_objects:
    if obj.name in bpy.data.objects: bpy.data.objects.remove(obj, do_unlink=True)
for action in list(bpy.data.actions):
    if action.name not in clips: bpy.data.actions.remove(action)
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'warrior.glb'), export_format='GLB',
    export_animations=True, export_animation_mode='NLA_TRACKS', export_nla_strips=True,
    export_force_sampling=True, export_yup=True)
shutil.copy2(BASE / 'License_Standard.txt', OUT / 'Character-License.txt')
shutil.copy2(ANIMS / 'License.txt', OUT / 'Animation-License.txt')
print('UNIVERSAL_WARRIOR_READY', OUT / 'warrior.glb')
