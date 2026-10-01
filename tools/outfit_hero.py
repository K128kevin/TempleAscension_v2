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
for old in [o for o in bpy.data.objects if o.name.startswith(('Hero','Ranger','Wizard'))]:
    bpy.data.objects.remove(old,do_unlink=True)
rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
# The ranger's cloak bones are rebuilt below.
outfits.remove_bones(rig,'cloak_')
outfits.remove_bones(rig,'cape_')
outfits.remove_bones(rig,'kilt_')
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
# The knight helm's ridge of spikes is smoothed into the dome of the
# concept's helm without its crest (the shader works a low riveted ridge
# over it): above the brow, anything standing out of a smooth egg over the
# head is drawn back onto it.
for v in mesh.verts:
    if v.co.z < 1.76: continue
    d = math.sqrt((v.co.x/.122)**2+(v.co.y/.142)**2+((v.co.z-1.7)/.18)**2)
    if d > 1.0:
        centre = Vector((0,0,1.7))
        v.co = centre+(v.co-centre)/d
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
# After his concept art the warrior's arms are bare below the shoulder caps.
shoulder_x = abs((rig.matrix_world @ rig.data.bones['upperarm_l'].head_local).x)
def warrior_cuirass(bone, z, co):
    if bone.startswith(('upperarm','clavicle')): return abs(co.x) < shoulder_x+.1
    if bone.startswith(('spine_02','spine_03')): return True
    return bone.startswith(('spine_01','pelvis','root')) and z >= outfits.CUIRASS_BOTTOM
armor = outfits.body_shell(body,rig,'HeroArmor',warrior_cuirass,.025,.02,('clavicle','upperarm'),.035)
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
# Which of `mesh`'s vertices lie truly under `covers` (objects): a ray from
# the vertex straight out along its normal, and four more tilted 35 degrees
# round it, must all strike a cover within `reach(co)` metres. A body face is
# hidden only where all its corners are covered, so wherever the skin could
# be seen past a garment's edge, it stays.
def covered_vertices(mesh, covers, reach, keep=lambda v: False):
    from mathutils.bvhtree import BVHTree
    joined = bmesh.new()
    for obj in covers:
        part = bmesh.new(); part.from_mesh(obj.data); part.transform(obj.matrix_world)
        temp = bpy.data.meshes.new('cover'); part.to_mesh(temp); part.free()
        joined.from_mesh(temp); bpy.data.meshes.remove(temp)
    tree = BVHTree.FromBMesh(joined); joined.free()
    world = mesh.matrix_world; turn = world.to_3x3()
    out = set()
    for v in mesh.data.vertices:
        if keep(v): continue
        co = world @ v.co; n = (turn @ v.normal).normalized()
        side = n.orthogonal().normalized(); other = n.cross(side)
        directions = [n]+[(n*math.cos(.61)+d*math.sin(.61)).normalized() for d in (side,-side,other,-other)]
        limit = reach(co)
        if all(tree.ray_cast(co+d*.001,d,limit)[0] is not None for d in directions): out.add(v.index)
    return out

# The ranger's quiver, built here: a tube of tooled leather, a little
# flattened against his back and flaring toward its mouth, with a rolled rim,
# a lining showing inside the mouth and a hard cap at the foot, holding nine
# arrows whose fletched ends stand out of it. Its UVs mark each part for
# assets/shaders/quiver.gdshader: U in [0,1) the tube (round, from the seam at
# the back), [1,2) the lining, [2,3) the rim, [3,4) the cap, [4,5) a shaft,
# [5,6) a fletching vane, [6,7) a nock; V runs along each part, plus ten times
# the arrow's number. Rigid on the upper back, centred at `at`, turned by
# `turn` (its length along Z before turning).
def quiver(at, turn):
    L,r0,r1,flat,seg = .56,.05,.066,.78,20
    mesh = bmesh.new(); uv = mesh.loops.layers.uv.new('UVMap')
    def tube(rings, part):
        # rings: [(z, radius, v)]; one row of quads between each pair.
        rows = []
        for z,r,v in rings:
            rows.append([(mesh.verts.new((math.sin(2*math.pi*i/seg)*r,math.cos(2*math.pi*i/seg)*r*flat,z)),i/seg,v) for i in range(seg+1)])
        for a,b in zip(rows,rows[1:]):
            for i in range(seg):
                quad = [a[i],a[i+1],b[i+1],b[i]]
                face = mesh.faces.new([q[0] for q in quad])
                for loop,q in zip(face.loops,quad): loop[uv].uv = (part+q[1],q[2])
        return rows
    radius = lambda t: r0+(r1-r0)*t
    outside = tube([(L*j/12,radius(j/12),j/12) for j in range(13)],0)
    tube([(L,r1,0.0),(L+.006,r1+.005,.35),(L+.012,r1-.001,.7),(L+.004,r1-.007,1.0)],2)
    tube([(L+.004,r1-.007,0.0),(L-.12,radius(1-.12/L)-.007,1.0)],1)
    # The cap: a shallow dome over the foot.
    bottom = outside[0]
    centre = mesh.verts.new((0,0,-.012))
    for i in range(seg):
        face = mesh.faces.new([bottom[i+1][0],bottom[i][0],centre])
        for loop,(x,y) in zip(face.loops,[((i+1)/seg,1.0),(i/seg,1.0),(.5,0.0)]): loop[uv].uv = (3+x,y)
    import random
    rng = random.Random(7)
    for n in range(9):
        a = 2*math.pi*n/9+rng.uniform(-.2,.2); rad = .02+.022*rng.random()
        base = Vector((math.sin(a)*rad,math.cos(a)*rad*flat,L*.3))
        top = Vector((math.sin(a)*rad*1.5,math.cos(a)*rad*flat*1.5,L+.15+rng.uniform(0,.05)))
        axis = (top-base).normalized()
        u = axis.orthogonal().normalized(); w = axis.cross(u)
        def ring(c, r, sides=6): return [c+(u*math.cos(2*math.pi*k/sides)+w*math.sin(2*math.pi*k/sides))*r for k in range(sides+1)]
        def strip(c0, c1, r, part, v0, v1):
            a0 = ring(c0,r); a1 = ring(c1,r)
            vs0 = [mesh.verts.new(p) for p in a0]; vs1 = [mesh.verts.new(p) for p in a1]
            for k in range(6):
                face = mesh.faces.new([vs0[k],vs0[k+1],vs1[k+1],vs1[k]])
                for loop,(x,y) in zip(face.loops,[(k/6,v0),((k+1)/6,v0),((k+1)/6,v1),(k/6,v1)]): loop[uv].uv = (part+x,y+10*n)
        strip(base,top-axis*.016,.0035,4,0.0,1.0)
        strip(top-axis*.016,top+axis*.006,.0046,6,0.0,1.0)
        # Three vanes, a long tapering feather profile each.
        for k in range(3):
            out = u*math.cos(2*math.pi*k/3+.3)+w*math.sin(2*math.pi*k/3+.3)
            steps = 6
            inner = []; outer = []
            for q in range(steps+1):
                sq = q/steps
                c = top-axis*(.02+.1*(1-sq))
                height = .004+.012*min(1.0,sq/.55)-.004*max(0.0,sq-.85)/.15
                inner.append(mesh.verts.new(c+out*.0035)); outer.append(mesh.verts.new(c+out*(.0035+height)))
            for q in range(steps):
                face = mesh.faces.new([inner[q],inner[q+1],outer[q+1],outer[q]])
                for loop,(x,y) in zip(face.loops,[(q/steps,0.0),((q+1)/steps,0.0),((q+1)/steps,1.0),(q/steps,1.0)]): loop[uv].uv = (5+x,y+10*n)
    obj = bpy.data.objects.new('RangerQuiver',bpy.data.meshes.new('RangerQuiver'))
    mesh.to_mesh(obj.data); mesh.free()
    bpy.context.scene.collection.objects.link(obj)
    for poly in obj.data.polygons: poly.use_smooth = True
    middle = Vector((0,0,(L+.2)/2))
    for v in obj.data.vertices: v.co = at+turn @ (v.co-middle)
    obj.vertex_groups.new(name='spine_03').add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
    obj.parent = rig
    obj.modifiers.new('Armature','ARMATURE').object = rig
    obj.data.materials.append(bpy.data.materials.new('QuiverLeather'))
    return obj

def ranger_body(cloak):
    covered_body = body.copy(); covered_body.data = body.data.copy(); covered_body.name = 'RangerBody'
    bpy.context.scene.collection.objects.link(covered_body)
    names = {g.index:g.name for g in covered_body.vertex_groups}
    def dominant(v): return names[max(v.groups,key=lambda g:g.weight).group] if v.groups else ''
    # The elbows bend out of the shoulder caps, so the arm is kept from a
    # hand's breadth above the elbow down, whatever lies near it at rest.
    elbows = [rig.matrix_world @ rig.data.bones['lowerarm_'+side].head_local for side in 'lr']
    def near_elbow(v):
        return any((v.co-e).length<.12 for e in elbows) or any(names[g.group].startswith('lowerarm') and g.weight>.05 for g in v.groups)
    # Under the mantle (the cloak above its swinging part), never the head,
    # neck, hands or elbows.
    mantle = cloak.copy(); mantle.data = cloak.data.copy()
    outfits.remove_faces(mantle,lambda f: f.calc_center_median().z<CLOAK_BLEND[1])
    hidden = covered_vertices(covered_body,[mantle],lambda co: .09,keep=lambda v: dominant(v).startswith(('Head','neck','hand','thumb','index','middle','ring','pinky')) or near_elbow(v) or v.co.z<CLOAK_BLEND[1])
    bpy.data.meshes.remove(mantle.data)
    # The feet are inside the boots.
    hidden |= {v.index for v in covered_body.data.vertices if dominant(v).startswith(('foot','ball'))}
    outfits.remove_faces(covered_body,lambda f: all(v.index in hidden for v in f.verts))
    return covered_body
ranger_body(cloak)

# The ranger's kit, after the concept art (painted by tools/paint_kits.py
# through the body's own UVs): knee-high boots, long bracers and a broad belt
# as raised shells of the body, so they stand out from it; a quiver of arrows
# across his back, a dagger and a pouch at his belt, a brooch pinning the
# cloak, and a beard.
# The ranger's boots: their top, below the knee, and the heights between
# which they change from the authored boot's shape to the calf's.
BOOT_TOP = .48
BOOT_FIT_LOW = .1
BOOT_FIT_HIGH = .2
# The shaft reaches down over the boot's upper to here.
BOOT_SHAFT_LOW = .07
BOOT_FIT_REACH = .03
# The authored foot is kept up to here (above it, its turned-down cuff flaps).
BOOT_FEET_TOP = .13
def leg_axis(co):
    # The ankle-to-knee line of the leg nearest `co`, at `co`'s height.
    best = None
    for side in 'lr':
        a = rig.matrix_world @ rig.data.bones['foot_'+side].head_local
        b = rig.matrix_world @ rig.data.bones['calf_'+side].head_local
        t = (co.z-a.z)/(b.z-a.z)
        p = a.lerp(b,t)
        d = (Vector((co.x,co.y,0))-Vector((p.x,p.y,0))).length
        if best is None or d<best[0]: best = (d,p)
    return best[1]

def flare_boots(boots):
    # The shaft flares a little toward its top, as in the concept art.
    for v in boots.data.vertices:
        flare = max(0.0,(v.co.z-(BOOT_TOP-.08))/.08)
        if flare > 0:
            axis = leg_axis(v.co)
            v.co.x = axis.x+(v.co.x-axis.x)*(1+.12*flare); v.co.y = axis.y+(v.co.y-axis.y)*(1+.12*flare)
    for poly in boots.data.polygons: poly.use_smooth = True

def tuck_feet(feet):
    # The authored foot's upper is drawn in round the ankle to sit just inside
    # the shaft, which overlaps it: the two meet with no gap to see through.
    import bmesh
    from mathutils.bvhtree import BVHTree
    mesh = bmesh.new(); mesh.from_mesh(body.data); mesh.normal_update()
    skin = BVHTree.FromBMesh(mesh)
    for v in feet.data.vertices:
        co = feet.matrix_world @ v.co
        w = max(0.0,min(1.0,(co.z-BOOT_SHAFT_LOW+.02)/.03))
        if w <= 0: continue
        axis = leg_axis(co); axis.z = co.z
        out = Vector((co.x-axis.x,co.y-axis.y,0))
        if out.length < 1e-4: continue
        hit,_,_,_ = skin.ray_cast(axis,out.normalized(),.3)
        if hit is None: continue
        limit = (Vector((hit.x-axis.x,hit.y-axis.y,0))).length+.008
        r = out.length
        if r > limit:
            r = r+(limit-r)*w
            co = axis+out.normalized()*r
            v.co = feet.matrix_world.inverted() @ co
    mesh.free()

def ranger_kit():
    from mathutils import Matrix
    kit = []
    def shell(name, covered, offset, thickness):
        piece = outfits.body_shell(body,rig,name,covered,offset,thickness)
        kit.append(piece)
    # Knee-high boots, one piece each, as in the concept art: a shell of the
    # leg from just below the knee down over the foot, flaring a little at
    # the top. Over the foot the shell is fitted onto the plain boots'
    # authored shape (a closed, rounded toe box, a heel and a sole) so it
    # forms a boot, not a painted foot with toes; above the ankle it follows
    # the calf.
    shell('RangerBoots',lambda bone,z: (bone.startswith('calf') or (bone.startswith('foot') and z>BOOT_SHAFT_LOW)) and z<BOOT_TOP,.014,.012)
    flare_boots(kit[-1])
    # The foot of the boot: the plain boots' authored shape, painted with the
    # same leather through UVs taken from the body beneath. The shaft's lower
    # edge is fitted down onto it, so the two meet with no gap.
    feet = bpy.data.objects['HeroBoots'].copy(); feet.data = bpy.data.objects['HeroBoots'].data.copy()
    feet.name = 'RangerBootsFeet'
    bpy.context.scene.collection.objects.link(feet)
    outfits.remove_faces(feet,lambda f: f.calc_center_median().z>BOOT_FEET_TOP)
    tuck_feet(feet)
    rig.data.pose_position = 'REST'
    for mod in list(feet.modifiers): feet.modifiers.remove(mod)
    transfer = feet.modifiers.new('Body UVs','DATA_TRANSFER')
    transfer.object = body
    transfer.use_loop_data = True
    transfer.data_types_loops = {'UV'}
    transfer.loop_mapping = 'POLYINTERP_NEAREST'
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = feet
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    rig.data.pose_position = 'POSE'
    feet.modifiers.new('Armature','ARMATURE').object = rig
    for poly in feet.data.polygons: poly.use_smooth = True
    kit.append(feet)
    shell('RangerBracers',lambda bone,z: bone.startswith('lowerarm'),.011,.009)
    shell('RangerBelt',lambda bone,z: bone.startswith(('spine_01','pelvis','root','spine_02')) and .972<z<1.058,.02,.012)
    def bone_head(name): return rig.matrix_world @ rig.data.bones[name].head_local
    def prop(name, path, at, length, turn, bone, axis=2):
        # An authored prop, scaled so its longest side (`axis`) is `length`,
        # turned by `turn` (a rotation matrix) and moved to `at`, rigidly on
        # `bone`.
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        new = [o for o in set(bpy.data.objects)-before]
        meshes = [o for o in new if o.type=='MESH']
        for o in meshes:
            o.data.transform(o.matrix_world); o.parent = None; o.matrix_world.identity()
        if len(meshes)>1:
            bpy.ops.object.select_all(action='DESELECT')
            for o in meshes: o.select_set(True)
            bpy.context.view_layer.objects.active = meshes[0]
            bpy.ops.object.join()
        piece = meshes[0]
        for o in new:
            if o not in meshes and o.name in bpy.data.objects: bpy.data.objects.remove(o,do_unlink=True)
        pts = [v.co.copy() for v in piece.data.vertices]
        lo = Vector([min(q[i] for q in pts) for i in range(3)]); hi = Vector([max(q[i] for q in pts) for i in range(3)])
        k = length/(hi-lo)[axis]
        centre = (lo+hi)/2
        for v in piece.data.vertices: v.co = at + turn @ ((v.co-centre)*k)
        for g in list(piece.vertex_groups): piece.vertex_groups.remove(g)
        piece.vertex_groups.new(name=bone).add(list(range(len(piece.data.vertices))),1.0,'REPLACE')
        for mod in list(piece.modifiers): piece.modifiers.remove(mod)
        piece.parent = rig
        piece.modifiers.new('Armature','ARMATURE').object = rig
        piece.name = name
        kit.append(piece)
        return piece
    adv = next((ROOT/'source_art/adventurers').glob('*/addons/*/Assets/gltf'))
    props = ROOT/'source_art/props/Exports/glTF'
    right = bone_head('upperarm_r'); left = bone_head('upperarm_l')
    # Which way is the character's right, in model space (+X or -X).
    rx = 1.0 if right.x>0 else -1.0
    # The quiver across the back: its mouth behind the right shoulder.
    tilt = Matrix.Rotation(math.radians(-24*rx),3,'Y')
    kit.append(quiver(Vector((rx*.07,.22,1.22)),tilt))
    # A dagger in a sheath strapped to the outside of the left thigh, hilt up
    # and leaning a little forward, blade down: it moves with the thigh, so
    # the stride never drives it through the leg. Its flat lies against the
    # thigh.
    names = {g.index:g.name for g in body.vertex_groups}
    left_thigh = 'thigh_'+('l' if bone_head('thigh_l').x*rx < 0 else 'r')
    side = [v.co for v in body.data.vertices if v.groups and names[max(v.groups,key=lambda g:g.weight).group]==left_thigh and .74<v.co.z<.86]
    outer = max(abs(c.x) for c in side)
    depth = sum(c.y for c in side)/len(side)
    sheathe = Matrix.Rotation(math.radians(10),3,'X') @ Matrix.Rotation(math.radians(90),3,'Z') @ Matrix.Rotation(math.radians(180),3,'Y')
    prop('RangerDagger',adv/'dagger.gltf',Vector((-rx*(outer+.022),depth,.79)),.3,sheathe,left_thigh)
    # A leather pouch on the belt at the right front hip.
    face = Matrix.Rotation(math.radians(20*rx),3,'Z')
    prop('RangerPouch',props/'Pouch_Large.gltf',Vector((rx*.15,-.11,.93)),.12,face,'pelvis',axis=0)
    # A round brooch pinning the cloak below the left collarbone.
    stand = Matrix.Rotation(math.radians(90),3,'X')
    prop('RangerBrooch',props/'Coin.gltf',Vector((-rx*.1,-.165,1.43)),.07,stand,'spine_03',axis=0)
    # A short dark beard from the base character's hairstyles, brought out
    # over the chin and cheeks as on the Crowned Statue.
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(outfits.HAIRSTYLES/'Hair_Beard.gltf'))
    for obj in set(bpy.data.objects)-before:
        if obj.type=='MESH' and obj.name.startswith('Hair_Beard'):
            world = obj.matrix_world.copy(); obj.parent = rig; obj.matrix_world = world
            for mod in obj.modifiers:
                if mod.type=='ARMATURE': mod.object = rig
            obj.name = 'RangerBeard'
            centre = Vector((0,-.01,1.63))
            for v in obj.data.vertices:
                q = obj.matrix_world @ v.co
                q = centre+(q-centre)*1.03+Vector((0,-.006,0))
                v.co = obj.matrix_world.inverted() @ q
            kit.append(obj)
        elif obj.name in bpy.data.objects: bpy.data.objects.remove(obj,do_unlink=True)
    print('RANGER_KIT',[o.name for o in kit])
ranger_kit()

# The warrior's kit, after his concept art (painted by tools/paint_kits.py
# through the body's UVs): steel greaves with knee guards and bracers, a broad
# belt, as raised shells of the body, and an armoured kilt of plates (the
# KayKit knight's, as the gladiator statue wears) over a tattered underskirt.
# The warrior's kilt: its top (tucked under the belt), hem and flare.
KILT_TOP = .995
KILT_HEM = .64
KILT_FLARE = .38
def warrior_kit():
    shells = []
    shells.append(outfits.body_shell(body,rig,'HeroGreaves',lambda bone,z: bone.startswith(('calf','thigh')) and .1<z<.57,.012,.01))
    shells.append(outfits.body_shell(body,rig,'HeroBracers',lambda bone,z: bone.startswith('lowerarm'),.011,.009))
    shells.append(outfits.body_shell(body,rig,'HeroBelt',lambda bone,z: bone.startswith(('spine_01','pelvis','root','spine_02')) and .953<z<1.047,.03,.012))
    # The kilt: a ring of hanging cloth from under the belt to mid-thigh,
    # swung by chains of bones on the spring simulation and folded over the
    # legs by its shader, as the ranger's cloak is; the shader draws it as the
    # concept's pteruges (scripts/visual.gd, assets/shaders/kilt.gdshader).
    names = {g.index:g.name for g in body.vertex_groups}
    waist = [(body,v) for v in body.data.vertices if KILT_TOP-.04<v.co.z<KILT_TOP+.01 and v.groups and not (outfits.region_of_bone(names[max(v.groups,key=lambda g:g.weight).group]) or '').startswith('arm')]
    kilt = bpy.data.objects.new('HeroKilt',bpy.data.meshes.new('HeroKilt'))
    bpy.context.scene.collection.objects.link(kilt)
    outfits.cloth_sheet(kilt,waist,top=KILT_TOP,hem=KILT_HEM,flare=KILT_FLARE,reach=math.pi,columns=72,rows=16,offset=.024)
    outfits.cloth_chains(rig,kilt,'pelvis',KILT_TOP+.01,(KILT_TOP-.07,KILT_TOP),chains=16,segments=5,prefix='kilt_')
    kilt.parent = rig
    kilt.modifiers.new('Armature','ARMATURE').object = rig
    print('WARRIOR_KIT',[o.name for o in shells+[kilt]])
warrior_kit()

# The wizard's kit, after his concept art (painted by tools/paint_kits.py):
# boots as the ranger's but lower, bracers showing below his sleeves, and a
# leather sash round the robe, knotted, its two ends hanging at the front.
def wizard_kit():
    pieces = []
    boots = outfits.body_shell(body,rig,'WizardBoots',lambda bone,z: (bone.startswith('calf') or (bone.startswith('foot') and z>BOOT_SHAFT_LOW)) and z<WIZARD_BOOT_TOP,.014,.012)
    pieces.append(boots)
    feet = bpy.data.objects['RangerBootsFeet'].copy(); feet.data = bpy.data.objects['RangerBootsFeet'].data.copy()
    feet.name = 'WizardBootsFeet'
    bpy.context.scene.collection.objects.link(feet)
    pieces.append(feet)
    wrist = {side:rig.matrix_world @ rig.data.bones['hand_'+side].head_local for side in 'lr'}
    pieces.append(outfits.body_shell(body,rig,'WizardBracers',lambda bone,z,co: bone.startswith('lowerarm') and min((co-w).length for w in wrist.values())<.15,.03,.009))
    # The sash: a band of leather round the outside of the robe at the waist,
    # knotted at the front, its two ends hanging from the knot.
    robe = bpy.data.objects['WizardRobe']
    # The sash cinches the robe: drawn in round his waist, just outside his
    # body, easing back out above and below.
    waist = outfits.waist_profile(body,SASH_LOW,SASH_HIGH)
    # The robe's long panels span the waist; cut them finer there first.
    mesh = bmesh.new(); mesh.from_mesh(robe.data)
    for _ in range(3):
        cross = [e for e in mesh.edges if min(v.co.z for v in e.verts)<SASH_HIGH+.15 and max(v.co.z for v in e.verts)>SASH_LOW-.15 and e.calc_length()>.04]
        if not cross: break
        bmesh.ops.subdivide_edges(mesh,edges=cross,cuts=1,use_grid_fill=True)
        bmesh.ops.triangulate(mesh,faces=[f for f in mesh.faces if len(f.verts)>4])
    mesh.to_mesh(robe.data); mesh.free()
    for poly in robe.data.polygons: poly.use_smooth = True
    for v in robe.data.vertices:
        co = robe.matrix_world @ v.co
        lift = min(max((co.z-(SASH_LOW-.14))/.14,0.0),1.0)*min(max(((SASH_HIGH+.12)-co.z)/.12,0.0),1.0)
        if lift <= 0: continue
        lift = lift*lift*(3-2*lift)
        sector = outfits.sector_of(co)
        r = outfits.radius_of(co); target = waist[sector]+ROBE_AT_WAIST
        if r > target:
            outfits.place(co,r+(target-r)*lift)
            v.co = robe.matrix_world.inverted() @ co
    # The sash itself, round his waist just outside the cinched robe.
    ring = [(body,v) for v in body.data.vertices if SASH_LOW<v.co.z<SASH_HIGH and not (outfits.region_of_bone(body.vertex_groups[max(v.groups,key=lambda g:g.weight).group].name) or '').startswith('arm')]
    sash = bpy.data.objects.new('WizardSash',bpy.data.meshes.new('WizardSash'))
    bpy.context.scene.collection.objects.link(sash)
    outfits.cloth_sheet(sash,ring,top=SASH_HIGH,hem=SASH_LOW,flare=0,reach=math.pi,columns=48,rows=3,offset=ROBE_AT_WAIST+.022)
    sash.parent = rig
    sash.modifiers.new('Armature','ARMATURE').object = rig
    pieces.append(sash)
    from mathutils import Matrix as _M
    from mathutils.bvhtree import BVHTree
    cy = outfits.KILT_CENTER_Y
    surface = bmesh.new(); surface.from_mesh(robe.data); surface.transform(robe.matrix_world)
    robe_surface = BVHTree.FromBMesh(surface); surface.free()
    for i,(turn,length) in enumerate([(.0,.34),(.09,.28)]):
        end = bpy.data.objects.new('WizardSashEnd%d' % i,bpy.data.meshes.new('WizardSashEnd%d' % i))
        bpy.context.scene.collection.objects.link(end)
        outfits.cloth_sheet(end,ring,top=1.0,hem=1.0-length,flare=.05,reach=.07,columns=4,rows=8,offset=ROBE_AT_WAIST+.022)
        # Round from the back (where sheets hang) to the knot at the front.
        spin = _M.Translation((0,cy,0)) @ _M.Rotation(math.pi+(turn+.25)*RIGHT_X,4,'Z') @ _M.Translation((0,-cy,0))
        end.data.transform(spin)
        # The ends hang over the robe's skirt, which flares out beneath the
        # sash: each point is laid just outside the robe's surface.
        for v in end.data.vertices:
            out = Vector((v.co.x,v.co.y-cy,0))
            if out.length < 1e-4: continue
            hit,_,_,_ = robe_surface.ray_cast(Vector((0,cy,v.co.z))+out.normalized()*.4,-out.normalized(),.4)
            if hit is None: continue
            need = Vector((hit.x,hit.y-cy,0)).length+.012
            if out.length < need:
                v.co.x = out.normalized().x*need; v.co.y = cy+out.normalized().y*need
        end.parent = rig
        end.modifiers.new('Armature','ARMATURE').object = rig
        pieces.append(end)
    print('WIZARD_KIT',[o.name for o in pieces])
RIGHT_X = 1.0 if (rig.matrix_world @ rig.data.bones['upperarm_r'].head_local).x>0 else -1.0
WIZARD_BOOT_TOP = .34
# The sash's band, and how far the cinched robe stands off his waist.
SASH_LOW = .985
SASH_HIGH = 1.06
ROBE_AT_WAIST = .03
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
# Wide sleeves, as in the concept: cut off halfway down the forearm and
# flared open, hanging a little, so his bracers show below them instead of
# pressing through them.
def cut_sleeves(robe, flare=.045, droop=.02):
    elbow = rig.matrix_world @ rig.data.bones['lowerarm_l'].head_local
    wrist = rig.matrix_world @ rig.data.bones['hand_l'].head_local
    end = abs(wrist.x)-.15
    mesh = bmesh.new(); mesh.from_mesh(robe.data)
    for sign in (1,-1):
        bmesh.ops.bisect_plane(mesh,geom=mesh.verts[:]+mesh.edges[:]+mesh.faces[:],plane_co=(sign*end,0,0),plane_no=(sign,0,0),clear_outer=True)
    mesh.to_mesh(robe.data); mesh.free()
    start = abs(elbow.x)-.06
    for v in robe.data.vertices:
        co = robe.matrix_world @ v.co
        t = min(max((abs(co.x)-start)/(end-start),0.0),1.0)
        if t <= 0 or abs(co.z-elbow.z) > .2: continue
        out = Vector((0,co.y-elbow.y,co.z-elbow.z))
        if out.length < 1e-4: continue
        co += out.normalized()*flare*t*t+Vector((0,0,-droop*t*t))
        v.co = robe.matrix_world.inverted() @ co
    print('WIZARD_SLEEVES_CUT',round(end,3))
cut_sleeves(robe_object)
# Its top follows his own shoulders, outside the robe's thickness: the
# robe's boxy KayKit shoulders would spread it out like wings.
# Its top lies close on the robe across his upper back, between the
# shoulder blades, rather than out over the shoulders, which drop away from
# it as his arms come down from the rest pose.
robe_names = {g.index:g.name for g in robe_object.vertex_groups}
def robe_on_arm(v):
    best = max(v.groups,key=lambda g:g.weight,default=None)
    return best is not None and (outfits.region_of_bone(robe_names[best.group]) or '').startswith('arm')
robe_surface = [(robe_object,v) for v in robe_object.data.vertices if not robe_on_arm(v)]
# (It hangs outside the robe's own flaring skirt, so flares little itself.)
wizard_cape = outfits.shoulder_cape(rig,body,'WizardCape',hem=.2,flare=.08,prefix='cape_',offset=.05,top_ring=robe_surface,top_offset=.014,top_reach=math.radians(44),corner_drop=.09)
print('WIZARD_CAPE',len(wizard_cape.data.vertices))
robed = body.copy(); robed.data = body.data.copy(); robed.name = 'WizardBody'
bpy.context.scene.collection.objects.link(robed)
groups = {g.index:g.name for g in robed.vertex_groups}
# Under the robe (the torso, the arms in its sleeves, the legs in its skirt),
# never the head, neck or hands. The skirt hangs well clear of the legs.
def dominant(v): return groups[max(v.groups,key=lambda g:g.weight).group] if v.groups else ''
covered = covered_vertices(robed,[robe_object],lambda co: .1 if co.z>1.0 else .4,keep=lambda v: dominant(v).startswith(('Head','neck','hand','thumb','index','middle','ring','pinky')))
# The legs inside the skirt are hidden whole, so a running knee never pushes
# skin through the cloth.
covered |= {v.index for v in robed.data.vertices if .18<v.co.z<.95 and sum(g.weight for g in v.groups if groups[g.group].startswith(('thigh_','calf_')))>.2}
# So are the torso, shoulders and arms inside the sleeves: the close robe is
# thinner than a flexed shoulder, which would otherwise show through it.
sleeve_end = max(abs((robe_object.matrix_world @ v.co).x) for v in robe_object.data.vertices)
covered |= {v.index for v in robed.data.vertices if dominant(v).startswith(('spine_','pelvis','clavicle_','upperarm_')) or (dominant(v).startswith('lowerarm_') and abs(v.co.x)<sleeve_end-.03)}
outfits.remove_faces(robed,lambda f: all(v.index in covered for v in f.verts))
print('HERO_ROBE_READY',len(robe_object.data.vertices),len(robed.data.vertices))
wizard_kit()

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT/'warrior.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('HERO_BOOTS_READY',len(boots_object.data.vertices))
