"""Give the hero brown leather boots, and each class its own kit.

Run with Blender --background --python tools/outfit_hero.py after
prepare_enemy_outfits.py (statues are built from warrior.glb and stay
barefoot; prepare_guardian.py also drops the boots). The KayKit Rogue's leg
pieces are trimmed to their boots, fitted to the hero's rig, then close-fitted
over each lower leg and skinned to the flesh beneath, exactly as the
centurion's armor is. They keep the Rogue's own brown leather material. Safe to
rerun: existing boots are replaced.

Every class's pieces are in the one model, and scripts/visual.gd shows the
set for the hero's class: the warrior's full helm, the ranger's hooded cloak
(the hood's brim drawn over the eyes, the mage's robe opened down the front),
and the wizard's robe and deep hood.
The wizard wears a copy of the body without the torso, arms and legs its robe
covers, so nothing pierces it as he moves. The hoods and the robe are the same authored
KayKit pieces the Oracle statue wears (tools/prepare_enemy_outfits.py).
"""
from pathlib import Path
import importlib.util
import bpy
import math
import bmesh
from mathutils import Vector

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

# The clips are baked at 30 fps (tools/import_combat.py); exporting at

# Blender's default 24 would resample and shift them.

bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUTPUT/'warrior.glb'))
for old in [o for o in bpy.data.objects if o.name.startswith(('HeroBoots','HeroHelmet','HeroArmor','RangerHood','RangerCloak','RangerBody','WizardHood','WizardRobe','WizardCape','WizardBody'))]:
    bpy.data.objects.remove(old,do_unlink=True)
rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
# The ranger's cloak bones are rebuilt below.
outfits.remove_bones(rig,'cloak_')
outfits.remove_bones(rig,'cape_')
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
# has bulk instead of being painted flat on the skin. The gladiator statue
# wears the same shell (tools/prepare_enemy_outfits.py).
armor = outfits.scale_cuirass(body,rig,'HeroArmor')
print('HERO_ARMOR_READY',len(armor.data.vertices))

# The KayKit mage's tunic drawn down into an ankle-length robe (with the named
# sleeves and cape), close-fitted over the chest and arms, as one object.
# `shoulder` cuts the sleeves down to shoulder caps.
def mage_robe(pieces, name, shoulder=None, fit=None):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(outfits.SOURCE/'Mage.glb'))
    imported = set(bpy.data.objects)-before
    source = next(o for o in imported if o.type=='ARMATURE')
    if shoulder:
        for o in imported:
            if o.name in pieces and '_Arm' in o.name: outfits.trim_outside_x(o,shoulder)
    robe = [outfits.fit(o,source,rig,'robes') for o in imported if o.name in pieces]
    for o in imported:
        if o not in robe and o.name in bpy.data.objects: bpy.data.objects.remove(o,do_unlink=True)
    for piece in robe:
        suffix = next((k for k in outfits.ARMOR_REGION if piece.name.endswith(k)),None)
        if suffix: outfits.armor_up(piece,body,rig,suffix,**(fit or outfits.CLOSE_FIT['robes']).get(suffix,{}))
    bpy.ops.object.select_all(action='DESELECT')
    for piece in robe: piece.select_set(True)
    bpy.context.view_layer.objects.active = robe[0]
    bpy.ops.object.join()
    bpy.context.object.name = name
    return bpy.context.object

# The ranger's hooded cloak, after a hooded ranger in a dark green cloak: a
# deep, rounded hood whose brim shades the face and whose cowl lies over the
# shoulders, and the robe (its sleeves cut to shoulder caps) opened down the
# front below the chest, so it wraps the shoulders like a mantle and hangs
# open over the tunic to mid-calf.
ranger_hood = outfits.add_hood(rig,shade=True)
# A cloak stands clear of the body, unlike the Oracle's close robe, so the
# tunic and shoulders do not show through it.
CLOAK_FIT = {'_Body':dict(outfits.CLOSE_FIT['robes']['_Body'],thickness=.045),'_ArmLeft':{'thickness':.04,'relief':.3},'_ArmRight':{'thickness':.04,'relief':.3}}
cloak = mage_robe(('Mage_Body','Mage_ArmLeft','Mage_ArmRight'),'RangerCloak',shoulder=.45,fit=CLOAK_FIT)
CLOAK_OPENING = 1.3
outfits.remove_faces(cloak,lambda f: (lambda c: c.z<CLOAK_OPENING and c.y<-.02)(f.calc_center_median()))
# Below the waist the cloak is one layer of cloth. The robe's lower part is
# thick (an outer skirt, a turned-up lining and the band joining them) and
# wrapped round the front of the opening, which caught the legs; it is cut
# away at CLOAK_SEAM and replaced by a single sheet hanging from just under
# the mantle, round the sides and back, open at the front, flaring to a
# mid-calf hem. Its even grid suits the swing simulation and the cloth
# shader that folds it over the legs (assets/shaders/cloak.gdshader).
CLOAK_SEAM = 1.08
CLOAK_ROOT = 1.12
CLOAK_BLEND = (1.06, 1.2)
outfits.remove_faces(cloak,lambda f: f.calc_center_median().z<CLOAK_SEAM)
mesh = bmesh.new(); mesh.from_mesh(cloak.data)
bmesh.ops.delete(mesh,geom=[v for v in mesh.verts if not v.link_faces],context='VERTS')
mesh.to_mesh(cloak.data); mesh.free()
# The waist the sheet hangs from: the robe's own girth just above the cut, so
# its top sits just inside the mantle's lower edge.
waist = [(cloak,v) for v in cloak.data.vertices if CLOAK_SEAM<=v.co.z<CLOAK_SEAM+.12]
outfits.cloth_sheet(cloak,waist,top=1.13,hem=.3,flare=.38,reach=math.radians(108))
print('CLOAK_SHEET',len(cloak.data.vertices))

# The cloak below the waist hangs from chains of bones from the pelvis that
# the game swings with a spring simulation (scripts/visual.gd), spread from
# one front edge round the back to the other.
outfits.cloth_chains(rig,cloak,'pelvis',CLOAK_ROOT,CLOAK_BLEND)

# The ranger wears a copy of the body without what the cloak's mantle and
# shoulder caps always cover (they move with the body there), so no skin
# shows through them as he draws; the head and neck, and everything under
# the swinging lower cloak, are kept.
def ranger_body(cloak):
    from mathutils import kdtree
    shell = [v.co.copy() for v in cloak.data.vertices if v.co.z>=CLOAK_BLEND[1]]
    tree = kdtree.KDTree(len(shell))
    for i,co in enumerate(shell): tree.insert(co,i)
    tree.balance()
    covered_body = body.copy(); covered_body.data = body.data.copy(); covered_body.name = 'RangerBody'
    bpy.context.scene.collection.objects.link(covered_body)
    names = {g.index:g.name for g in covered_body.vertex_groups}
    def dominant(v): return names[max(v.groups,key=lambda g:g.weight).group] if v.groups else ''
    # The elbows bend out of the shoulder caps, so the arm is kept from a
    # hand's breadth above the elbow down, whatever lies near it at rest.
    elbows = [rig.matrix_world @ rig.data.bones['lowerarm_'+side].head_local for side in 'lr']
    def near_elbow(v):
        return any((v.co-e).length<.12 for e in elbows) or any(names[g.group].startswith('lowerarm') and g.weight>.05 for g in v.groups)
    hidden = {v.index for v in covered_body.data.vertices if v.co.z>=CLOAK_BLEND[1] and not dominant(v).startswith(('Head','neck')) and not near_elbow(v) and tree.find(v.co)[2]<.075}
    outfits.remove_faces(covered_body,lambda f: all(v.index in hidden for v in f.verts))
    return covered_body
ranger_body(cloak)
bpy.ops.object.select_all(action='DESELECT')
ranger_hood.select_set(True); cloak.select_set(True)
bpy.context.view_layer.objects.active = cloak
bpy.ops.object.join()
cloak.name = 'RangerCloak'

wizard_hood = outfits.add_hood(rig,deep=True)
wizard_hood.name = 'WizardHood'
print('HERO_HOODS_READY',len(cloak.data.vertices),len(wizard_hood.data.vertices))

# The wizard's robe, with its sleeves, and over it a cape of cloth from the
# shoulders, swung on its own chains (cape_*) as the ranger's cloak is.
robe_object = mage_robe(('Mage_Body','Mage_ArmLeft','Mage_ArmRight'),'WizardRobe')
wizard_cape = outfits.shoulder_cape(rig,robe_object,'WizardCape',hem=.2,flare=.22,prefix='cape_')
print('WIZARD_CAPE',len(wizard_cape.data.vertices))
robed = body.copy(); robed.data = body.data.copy(); robed.name = 'WizardBody'
bpy.context.scene.collection.objects.link(robed)
groups = {g.index:g.name for g in robed.vertex_groups}
# Under the robe: the legs above the ankles, the torso and the arms to the wrists.
ROBED_BONES = ('spine_','pelvis','clavicle_','upperarm_','lowerarm_')
def dominant(v): return groups[max(v.groups,key=lambda g:g.weight).group] if v.groups else ''
covered = {v.index for v in robed.data.vertices if (v.co.z>.18 and sum(g.weight for g in v.groups if groups[g.group].startswith(('thigh_','calf_')))>.2) or dominant(v).startswith(ROBED_BONES)}
outfits.remove_faces(robed,lambda f: all(v.index in covered for v in f.verts))
print('HERO_ROBE_READY',len(robe_object.data.vertices),len(robed.data.vertices))

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT/'warrior.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('HERO_BOOTS_READY',len(boots_object.data.vertices))
