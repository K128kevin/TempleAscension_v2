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
for old in [o for o in bpy.data.objects if o.name.startswith(('HeroBoots','HeroHelmet','HeroArmor','RangerHood','RangerCloak','RangerBody','WizardHood','WizardRobe','WizardBody'))]:
    bpy.data.objects.remove(old,do_unlink=True)
rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
# The ranger's cloak bones are rebuilt below.
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for bone in [b for b in rig.data.edit_bones if b.name.startswith('cloak_')]: rig.data.edit_bones.remove(bone)
bpy.ops.object.mode_set(mode='OBJECT')
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
CLOAK_TOP = 1.13
CLOAK_HEM = .3
CLOAK_FLARE = .38
CLOAK_REACH = math.radians(108)
SHEET_COLUMNS = 56
SHEET_ROWS = 22
def cloak_bearing(co): return math.atan2(co.x,co.y-outfits.KILT_CENTER_Y)
def hanging_sheet(cloak):
    from mathutils import kdtree
    cy = outfits.KILT_CENTER_Y
    outfits.remove_faces(cloak,lambda f: f.calc_center_median().z<CLOAK_SEAM)
    mesh = bmesh.new(); mesh.from_mesh(cloak.data)
    bmesh.ops.delete(mesh,geom=[v for v in mesh.verts if not v.link_faces],context='VERTS')
    mesh.to_mesh(cloak.data); mesh.free()
    # The waist the sheet hangs from: the robe's own girth just above the cut,
    # by bearing, so its top sits just inside the mantle's lower edge.
    ring = [v for v in cloak.data.vertices if CLOAK_SEAM<=v.co.z<CLOAK_SEAM+.12]
    def sampled(b):
        near = [math.hypot(v.co.x,v.co.y-cy) for v in ring if abs(math.remainder(cloak_bearing(v.co)-b,2*math.pi))<.3]
        return (max(near) if near else .2)-.012
    # Smoothed round the waist, so the cloth hangs in soft folds, not ridges.
    columns = [sampled(-CLOAK_REACH+2*CLOAK_REACH*i/SHEET_COLUMNS) for i in range(SHEET_COLUMNS+1)]
    for _ in range(8):
        columns = [sum(columns[max(0,min(SHEET_COLUMNS,i+d))] for d in (-2,-1,0,1,2))/5 for i in range(SHEET_COLUMNS+1)]
    def girth_at(i): return columns[i]
    tree = kdtree.KDTree(len(ring))
    for i,v in enumerate(ring): tree.insert(v.co,i)
    tree.balance()
    names = {g.index:g.name for g in cloak.vertex_groups}
    mesh = bmesh.new(); mesh.from_mesh(cloak.data)
    deform = mesh.verts.layers.deform.verify()
    grid = []
    for j in range(SHEET_ROWS+1):
        t = j/SHEET_ROWS
        z = CLOAK_TOP+(CLOAK_HEM-CLOAK_TOP)*t
        row = []
        for i in range(SHEET_COLUMNS+1):
            b = -CLOAK_REACH+2*CLOAK_REACH*i/SHEET_COLUMNS
            r = girth_at(i)*(1+CLOAK_FLARE*t*t*(3-2*t))
            v = mesh.verts.new(Vector((math.sin(b)*r,cy+math.cos(b)*r,z)))
            # The top rows move with the body, as the mantle does; the chains
            # take over below (cloak_bones).
            _,k,_ = tree.find(v.co)
            for g in ring[k].groups: v[deform][g.group] = g.weight
            row.append(v)
        grid.append(row)
    for j in range(SHEET_ROWS):
        for i in range(SHEET_COLUMNS):
            mesh.faces.new((grid[j][i],grid[j+1][i],grid[j+1][i+1],grid[j][i+1]))
    mesh.to_mesh(cloak.data); mesh.free()
    for face in cloak.data.polygons: face.use_smooth = True
    print('CLOAK_SHEET',len(cloak.data.vertices))
hanging_sheet(cloak)

# The cloak below the waist hangs from chains of bones that the game swings
# with a spring simulation (scripts/visual.gd): each chain runs from the
# pelvis down the inside of the cloak to its hem, spread from one front edge
# round the back to the other. The hanging cloth is skinned to the two
# nearest chains, blending into the body's own weights at the waist.
CLOAK_CHAINS = 13
CLOAK_SEGMENTS = 8
CLOAK_ROOT = 1.12
CLOAK_BLEND = (1.06, 1.2)
def cloak_bones(cloak):
    hanging = [v.co.copy() for v in cloak.data.vertices if v.co.z<CLOAK_ROOT-.1]
    bearings = sorted(cloak_bearing(co) for co in hanging)
    low, high = bearings[int(len(bearings)*.02)], bearings[int(len(bearings)*.98)]
    chains = []
    for i in range(CLOAK_CHAINS):
        b = low+(high-low)*i/(CLOAK_CHAINS-1)
        # The cloth near this bearing; the window widens where the mesh is sparse.
        for window in (.15,.25,.4,.6):
            near = [co for co in (v.co for v in cloak.data.vertices) if abs(cloak_bearing(co)-b)<window and co.z<CLOAK_ROOT+.05]
            if len(near)>=6: break
        hem = min(co.z for co in near)
        def radius_at(z):
            ring = [co for co in near if abs(co.z-z)<.06] or near
            return sum(math.hypot(co.x,co.y-outfits.KILT_CENTER_Y) for co in ring)/len(ring)-.015
        points = []
        for j in range(CLOAK_SEGMENTS+1):
            z = CLOAK_ROOT+(hem+.02-CLOAK_ROOT)*j/CLOAK_SEGMENTS
            r = radius_at(z)
            points.append(Vector((math.sin(b)*r,outfits.KILT_CENTER_Y+math.cos(b)*r,z)))
        chains.append((b,points))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    bones = rig.data.edit_bones
    to_rig = rig.matrix_world.inverted()
    for i,(b,points) in enumerate(chains):
        parent = bones['pelvis']
        for j in range(CLOAK_SEGMENTS):
            bone = bones.new('cloak_%d_%d' % (i,j))
            bone.head = to_rig @ points[j]; bone.tail = to_rig @ points[j+1]
            bone.parent = parent; bone.use_connect = j>0
            parent = bone
    bpy.ops.object.mode_set(mode='OBJECT')
    for i in range(CLOAK_CHAINS):
        for j in range(CLOAK_SEGMENTS): cloak.vertex_groups.new(name='cloak_%d_%d' % (i,j))
    for v in cloak.data.vertices:
        z = v.co.z
        if z>=CLOAK_BLEND[1]: continue
        body_share = max(0.0,min(1.0,(z-CLOAK_BLEND[0])/(CLOAK_BLEND[1]-CLOAK_BLEND[0])))
        for g in list(v.groups):
            cloak.vertex_groups[g.group].add([v.index],g.weight*body_share,'REPLACE')
        b = max(low,min(high,cloak_bearing(v.co)))
        span = (b-low)/(high-low)*(CLOAK_CHAINS-1)
        i = min(CLOAK_CHAINS-2,int(span)); a = span-i
        for chain,share in [(i,1-a),(i+1,a)]:
            points = chains[chain][1]
            t = max(0.0,min(.999,(CLOAK_ROOT-z)/(CLOAK_ROOT-points[-1].z)))
            cloak.vertex_groups['cloak_%d_%d' % (chain,int(t*CLOAK_SEGMENTS))].add([v.index],(1-body_share)*share,'ADD')
    return len(chains)
cloak_bones(cloak)

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

# The wizard's robe, with its sleeves and cape.
robe_object = mage_robe(('Mage_Body','Mage_ArmLeft','Mage_ArmRight','Mage_Cape'),'WizardRobe')
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
