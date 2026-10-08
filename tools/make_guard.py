"""Builds the town's gate guards: assets/models/character/town_guard.glb.

A guard is armored as the centurion statues are (tools/prepare_enemy_outfits.py,
'legion'): the KayKit Knight's cuirass, arm and leg plates and helm,
close-fitted over the hero's body at the centurion's heavy build. But he is a
man, at life size, not stone: the pieces are kept apart, each with its own
material, for the game to dress in earnest (scripts/town_guard.gd): the body in
the warrior's painted skin and kit, the armor in worn steel, bronze, leather and
red wool over the knight's own palette. He keeps only the clip a man standing
watch needs.

Run after outfit_hero.py and paint_kits.py have written warrior.glb:

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_guard.py
"""
from pathlib import Path
import importlib.util
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT/'assets/models/character'
spec = importlib.util.spec_from_file_location('outfits', ROOT/'tools/prepare_enemy_outfits.py')
outfits = importlib.util.module_from_spec(spec); spec.loader.exec_module(outfits)
CLIPS = ['Idle']

bpy.ops.wm.read_factory_settings(use_empty=True)
# The clips are baked at 30 fps (tools/import_combat.py); exporting at
# Blender's default 24 would resample and shift them.
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(OUTPUT/'warrior.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.name = 'GuardRig'
# The heroes' kits are their own, and the helm covers the hair.
for o in [o for o in bpy.data.objects if o.type == 'MESH' and (o.name.startswith(('Hero', 'Ranger', 'Wizard', 'Hair')) or o.parent is None)]:
    bpy.data.objects.remove(o, do_unlink=True)
outfits.remove_bones(rig, ('cloak_', 'cape_', 'kilt_', 'robe_'))
body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'SuperHero' in o.name)
body.name = 'Body'
for track in list(rig.animation_data.nla_tracks):
    if track.name not in CLIPS: rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action.name not in CLIPS: bpy.data.actions.remove(action)

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(outfits.SOURCE/'Knight.glb'))
imported = set(bpy.data.objects)-before
source = next(o for o in imported if o.type == 'ARMATURE')
chosen = [(o, 'plate') for o in imported if o.type == 'MESH' and o.name.startswith('Knight_') and any(t in o.name for t in ['_Body', '_Arm', '_Leg'])]
chosen += [(o, 'legion') for o in imported if o.type == 'MESH' and o.name == 'Knight_Helmet']
fitted = [outfits.fit(o, source, rig, style) for o, style in chosen]
# The centurion's heavy build first, then the armor close-fitted over it.
outfits.reproportion(body, rig, shoulder=.045, thigh_cut=0, calf_cut=0, muscle=outfits.LEGION_MUSCLE)
for piece in fitted:
    suffix = next((k for k in outfits.ARMOR_REGION if piece.name.endswith(k)), None)
    if suffix: outfits.armor_up(piece, body, rig, suffix)
for o in imported:
    if o not in fitted and o.name in bpy.data.objects: bpy.data.objects.remove(o, do_unlink=True)
# The game gives each part its material by name (scripts/town_guard.gd).
for piece in fitted:
    piece.name = 'Armor'+piece.name.removeprefix('Knight_').split('.')[0]
    piece.data.materials.clear()
    piece.data.materials.append(bpy.data.materials.get('Armor') or bpy.data.materials.new('Armor'))

bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type == 'MESH' or o == rig: o.select_set(True)
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT/'town_guard.glb'), export_format='GLB', use_selection=True, export_animations=True,
    export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_image_format='NONE')
print('GUARD_READY', {o.name: len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'})
