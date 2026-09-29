"""Give the hero brown leather boots.

Run with Blender --background --python tools/outfit_hero.py after
prepare_enemy_outfits.py (statues are built from warrior.glb and stay
barefoot; prepare_guardian.py also drops the boots). The KayKit Rogue's leg
pieces are trimmed to their boots, fitted to the hero's rig, then close-fitted
over each lower leg and skinned to the flesh beneath, exactly as the
centurion's armor is. They keep the Rogue's own brown leather material. Safe to
rerun: existing boots are replaced.
"""
from pathlib import Path
import importlib.util
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT/'assets/models/character'
spec = importlib.util.spec_from_file_location('outfits',ROOT/'tools/prepare_enemy_outfits.py')
outfits = importlib.util.module_from_spec(spec); spec.loader.exec_module(outfits)
# The Rogue's boot, cuff included, ends here in its own model space.
BOOT_TOP = .22
# Supple leather: snug over the calf, keeping a little of the boot's shape.
outfits.ARMOR_THICKNESS.update({'_LegLeft':.015,'_LegRight':.015})
outfits.ARMOR_RELIEF = .2

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUTPUT/'warrior.glb'))
for old in [o for o in bpy.data.objects if o.name.startswith(('HeroBoots','HeroHelmet','HeroArmor'))]:
    bpy.data.objects.remove(old,do_unlink=True)
rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
body = next(o for o in bpy.data.objects if o.type=='MESH' and 'SuperHero' in o.name)
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(outfits.SOURCE/'Rogue.glb'))
imported = set(bpy.data.objects)-before
source = next(o for o in imported if o.type=='ARMATURE')
boots = []
for side in ['Left','Right']:
    leg = next(o for o in imported if o.name=='Rogue_Leg'+side)
    outfits.trim_above(leg,BOOT_TOP)
    boot = outfits.fit(leg,source,rig,'light')
    outfits.armor_up(boot,body,rig,'_Leg'+side)
    boots.append(boot)
for o in imported:
    if o not in boots and o.name in bpy.data.objects: bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for boot in boots: boot.select_set(True)
bpy.context.view_layer.objects.active = boots[0]
bpy.ops.object.join()
bpy.context.object.name = 'HeroBoots'
boots_object = bpy.context.object

# A steel full helm from the KayKit knight's helm, sized close to the hero's head.
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(outfits.SOURCE/'Knight.glb'))
imported = set(bpy.data.objects)-before
source = next(o for o in imported if o.type=='ARMATURE')
helm = outfits.fit(next(o for o in imported if o.name=='Knight_Helmet'),source,rig,'fullhelm')
for o in imported:
    if o!=helm and o.name in bpy.data.objects: bpy.data.objects.remove(o,do_unlink=True)
helm.name = 'HeroHelmet'
# The knight helm is open-faced. Its closed back half, mirrored front to back,
# becomes a face plate; the seam that circles the back at eye height lands on
# the front as the visor slit.
import bmesh
mesh = bmesh.new(); mesh.from_mesh(helm.data)
# Only the face area: the dome and crest in front are already closed.
back = [f for f in mesh.faces if all(v.co.y>.0 and v.co.z<1.84 for v in f.verts)]
copy = bmesh.ops.duplicate(mesh,geom=back)
new_verts = [g for g in copy['geom'] if isinstance(g,bmesh.types.BMVert)]
for v in new_verts: v.co.y = -v.co.y
new_faces = [g for g in copy['geom'] if isinstance(g,bmesh.types.BMFace)]
bmesh.ops.reverse_faces(mesh,faces=new_faces)
mesh.to_mesh(helm.data); mesh.free()
helm.data.materials.clear()
helm.data.materials.append(bpy.data.materials.new('HelmSteel'))
for face in helm.data.polygons: face.material_index = 0
print('HERO_HELMET_READY',len(helm.data.vertices))

# The scale armor as a real shell: the armored part of the body (chest, back,
# shoulders and upper arms, as painted by tools/paint_hero.py) is copied and
# thickened outward, keeping its UVs, texture and skin weights, so the cuirass
# has bulk instead of being painted flat on the skin.
ARMOR_BONES = ('upperarm','clavicle','spine_02','spine_03')
CUIRASS_BOTTOM = 1.05
ARMOR_OFFSET = .025
SHOULDER_OFFSET = .035
armor = body.copy(); armor.data = body.data.copy(); armor.name = 'HeroArmor'
bpy.context.scene.collection.objects.link(armor)
names = {g.index:g.name for g in armor.vertex_groups}
def armored(v):
    best = max(v.groups,key=lambda g:g.weight,default=None)
    bone = names[best.group] if best else ''
    if bone.startswith(ARMOR_BONES): return True
    return bone.startswith(('spine_01','pelvis','root')) and v.co.z>=CUIRASS_BOTTOM
mesh = bmesh.new(); mesh.from_mesh(armor.data)
mesh.verts.ensure_lookup_table()
keep = {v.index for v in armor.data.vertices if armored(v)}
bmesh.ops.delete(mesh,geom=[f for f in mesh.faces if not all(v.index in keep for v in f.verts)],context='FACES')
bmesh.ops.delete(mesh,geom=[v for v in mesh.verts if not v.link_faces],context='VERTS')
mesh.to_mesh(armor.data); mesh.free()
shoulder = {v.index for v in armor.data.vertices if names[max(v.groups,key=lambda g:g.weight).group].startswith(('clavicle','upperarm'))}
for v in armor.data.vertices:
    v.co += v.normal*(SHOULDER_OFFSET if v.index in shoulder else ARMOR_OFFSET)
# Thicken the rest-pose shell with skinning off, then skin it again.
for modifier in list(armor.modifiers): armor.modifiers.remove(modifier)
solid = armor.modifiers.new('Plate thickness','SOLIDIFY')
solid.thickness = .02; solid.offset = -1.0; solid.use_rim = True
bpy.context.view_layer.objects.active = armor
bpy.ops.object.modifier_apply(modifier=solid.name)
armor.modifiers.new('Armature','ARMATURE').object = rig
print('HERO_ARMOR_READY',len(armor.data.vertices))

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT/'warrior.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('HERO_BOOTS_READY',len(boots_object.data.vertices))
