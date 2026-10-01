"""Fit authored KayKit clothing to the existing Quaternius statue rig.
No primitive geometry is generated. Each outfit is merged into one skinned
surface and retains the guardian's authored animation clips.
"""
from pathlib import Path
import bpy
import math
import sys
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = next((ROOT/'source_art/adventurers').glob('*/addons/*/Characters/gltf'))
OUTPUT = ROOT/'assets/models/character'
BONES = {'hips':'pelvis','spine':'spine_02','chest':'spine_03','head':'Head'}
for side in ['l','r']:
    for old,new in [('upperarm','upperarm'),('lowerarm','lowerarm'),('wrist','hand'),('hand','hand'),('upperleg','thigh'),('lowerleg','calf'),('foot','foot'),('toes','ball')]:
        BONES[f'{old}.{side}'] = f'{new}_{side}'


def bounds(obj):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return Vector([min(v[i] for v in points) for i in range(3)]),Vector([max(v[i] for v in points) for i in range(3)])


def trim_below(obj, height):
    # Keep only the part of an authored piece above `height` (source space).
    world=obj.matrix_world
    remove_faces(obj,lambda f: all((world@v.co).z<height for v in f.verts))
    import bmesh
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(obj.data); bm.free()


def trim_above(obj, height):
    # Keep only the part of an authored piece below `height` (source space).
    world=obj.matrix_world
    remove_faces(obj,lambda f: all((world@v.co).z>height for v in f.verts))
    import bmesh
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(obj.data); bm.free()


# The gladiator's build, applied to the fitted and joined statue: broader
# shoulders, heavier arms, chest and thighs over leaner calves, and slightly
# shorter legs. Bones only translate in the rest pose, so the baked animation
# rotations still apply; the hips drop by the leg shortening, keeping the feet
# on the ground.
MUSCLE={'upperarm':1.14,'lowerarm':1.10,'thigh':1.16,'calf':.96,'spine_01':1.06,'spine_02':1.08,'spine_03':1.08}
def reproportion(body, rig, shoulder=.035, thigh_cut=.04, calf_cut=.03, muscle=MUSCLE):
    import bpy
    bones=rig.data.bones
    calf_up=(bones['calf_l'].head_local-bones['calf_l'].tail_local).normalized()
    drop=thigh_cut+calf_cut*calf_up.z
    moved={}
    for bone in bones['pelvis'].children_recursive+[bones['pelvis']]:
        moved[bone.name]=Vector((0,0,-drop))
    for side in ['l','r']:
        sign=1 if bones['upperarm_'+side].head_local.x>0 else -1
        for bone in [bones['clavicle_'+side]]+list(bones['clavicle_'+side].children_recursive):
            moved[bone.name]=moved[bone.name]+Vector((sign*shoulder,0,0))
        for bone in [bones['calf_'+side]]+list(bones['calf_'+side].children_recursive):
            moved[bone.name]=moved[bone.name]+Vector((0,0,thigh_cut))
        for bone in [bones['foot_'+side]]+list(bones['foot_'+side].children_recursive):
            moved[bone.name]=moved[bone.name]+calf_up*calf_cut
    def along(bone,co):
        a=bone.head_local;b=bone.tail_local;axis=b-a
        t=max(0.0,min(1.0,(co-a).dot(axis)/max(axis.length_squared,1e-9)))
        return t,a+axis*t
    names={g.index:g.name for g in body.vertex_groups}
    for v in body.data.vertices:
        total=Vector();weight=0.0
        for g in v.groups:
            name=names[g.group]
            if name not in bones: continue
            bone=bones[name]
            t,closest=along(bone,v.co)
            key=next((k for k in muscle if name==k or name.startswith(k+'_')),None)
            change=(v.co-closest)*(muscle[key]-1) if key else Vector()
            shift=moved.get(name,Vector())
            # Shortened segments compress smoothly along their length.
            if name.startswith('thigh_'): shift=shift+Vector((0,0,thigh_cut))*t
            elif name.startswith('calf_'): shift=shift+calf_up*calf_cut*t
            total+=(change+shift)*g.weight;weight+=g.weight
        if weight>0: v.co+=total/weight
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in rig.data.edit_bones:
        if bone.name in moved:
            offset=moved[bone.name]
            end=moved.get(bone.children[0].name,offset) if bone.name.startswith(('thigh_','calf_')) and bone.children else offset
            bone.head+=offset;bone.tail+=end
    bpy.ops.object.mode_set(mode='OBJECT')


# The centurion's heavy build: broad and thick through the chest, arms and
# thighs, at full height.
LEGION_MUSCLE={'upperarm':1.16,'lowerarm':1.12,'thigh':1.14,'calf':1.04,'spine_01':1.10,'spine_02':1.12,'spine_03':1.12,'neck_01':1.12}
ARMOR_THICKNESS={'_Body':.045,'_ArmLeft':.03,'_ArmRight':.03,'_LegLeft':.032,'_LegRight':.032}
# Share of each plate's authored shape kept over the close fit: its edges,
# belt and pauldrons still read as armor, without the knight's barrel outline.
ARMOR_RELIEF=.35
ARMOR_REGION={'_Body':'torso','_ArmLeft':'arm_l','_ArmRight':'arm_r','_LegLeft':'leg_l','_LegRight':'leg_r'}

def dominant(vertex, names):
    best=max(vertex.groups,key=lambda g:g.weight,default=None)
    return names[best.group] if best else ''

def region_target(body, region):
    # A copy of the statue surface limited to one region, for shrinkwrapping.
    import bpy
    names={g.index:g.name for g in body.vertex_groups}
    target=body.copy(); target.data=body.data.copy(); target.name='Target_'+region
    for mod in list(target.modifiers): target.modifiers.remove(mod)
    bpy.context.scene.collection.objects.link(target)
    keep={v.index for v in target.data.vertices if region_of_bone(dominant(v,names))==region}
    remove_faces(target,lambda f: not all(v.index in keep for v in f.verts))
    return target

def region_of_bone(name):
    if name.startswith(('upperarm_','lowerarm_','hand_','thumb_','index_','middle_','ring_','pinky_')):
        return 'arm_'+name[-1]
    if name.startswith(('thigh_','calf_','foot_','ball_')): return 'leg_'+name[-1]
    if name.startswith(('pelvis','spine_','neck_','clavicle_')): return 'torso'
    return None

def armor_up(piece, body, rig, suffix, thickness=None, relief=None, reach=None):
    # Fit an authored armor piece closely over its body region at a plate's
    # thickness, then skin it with the weights of the flesh beneath it so it
    # moves exactly with the limb. `reach(co)` in [0, 1] limits the fit per
    # vertex; parts it leaves loose (a robe's skirt) keep their own weights.
    import bpy
    from mathutils import kdtree
    relief=ARMOR_RELIEF if relief is None else relief
    relief_at=relief if callable(relief) else (lambda co: relief)
    target=region_target(body,ARMOR_REGION[suffix])
    wrap=piece.modifiers.new('Close fit','SHRINKWRAP')
    wrap.target=target; wrap.wrap_method='NEAREST_SURFACEPOINT'; wrap.wrap_mode='ABOVE_SURFACE'
    wrap.offset=ARMOR_THICKNESS[suffix] if thickness is None else thickness
    bpy.context.view_layer.objects.active=piece
    for mod in list(piece.modifiers):
        if mod!=wrap: piece.modifiers.remove(mod)
    authored=[v.co.copy() for v in piece.data.vertices]
    amount=[1.0 if reach is None else reach(co) for co in authored]
    bpy.ops.object.modifier_apply(modifier=wrap.name)
    for v,original,a in zip(piece.data.vertices,authored,amount): v.co=v.co.lerp(original,1-a*(1-relief_at(original)))
    tree=kdtree.KDTree(len(target.data.vertices))
    for v in target.data.vertices: tree.insert(v.co,v.index)
    tree.balance()
    names={g.index:g.name for g in target.vertex_groups}
    loose={v.index:[(piece.vertex_groups[g.group].name,g.weight) for g in v.groups] for v,a in zip(piece.data.vertices,amount) if a<.5}
    for group in list(piece.vertex_groups): piece.vertex_groups.remove(group)
    for v in piece.data.vertices:
        if v.index in loose:
            for name,weight in loose[v.index]:
                group=piece.vertex_groups.get(name) or piece.vertex_groups.new(name=name)
                group.add([v.index],weight,'REPLACE')
            continue
        _,index,_=tree.find(v.co)
        for g in target.data.vertices[index].groups:
            group=piece.vertex_groups.get(names[g.group]) or piece.vertex_groups.new(name=names[g.group])
            group.add([v.index],g.weight,'REPLACE')
    arm=piece.modifiers.new('Statue outfit skin','ARMATURE'); arm.object=rig
    bpy.data.objects.remove(target,do_unlink=True)


def band(z, rise_from, full_from, full_to, fall_to):
    # 0 outside [rise_from, fall_to], 1 within [full_from, full_to], smooth between.
    if z<=rise_from or z>=fall_to: return 0.0
    if z<full_from: u=(z-rise_from)/(full_from-rise_from)
    elif z>full_to: u=(fall_to-z)/(fall_to-full_to)
    else: return 1.0
    return u*u*(3-2*u)

# Per style and piece: thickness over the body, share of authored shape kept,
# and how much of the piece is pulled in.
LEATHER={'thickness':.018,'relief':.3}
SNUG={'thickness':.01,'relief':.06}
CLOSE_FIT={
    'legion':{},
    # The cuirass fits the chest and is snug through its belt; below the waist
    # it flares into a skirt.
    'general':{'_Body':{'thickness':.035,'relief':lambda co: .35-.32*band(co.z,.98,1.04,1.2,1.3)},'_ArmLeft':{'thickness':.03,'relief':.4},'_ArmRight':{'thickness':.03,'relief':.4}},
    # The archer's leathers fit close over the body, keeping only a trace of
    # the KayKit pieces' rounded shapes.
    'light':{'_Body':{'thickness':.016,'relief':.08},'_ArmLeft':SNUG,'_ArmRight':SNUG,'_LegLeft':SNUG,'_LegRight':SNUG},
    'murmillo':{},
    # The robe fits over the chest and sleeves; the lengthened skirt stays loose.
    'robes':{'_Body':{'thickness':.028,'relief':.3,'reach':lambda co: max(0.0,min(1.0,(co.z-.98)/.14))},'_ArmLeft':LEATHER,'_ArmRight':LEATHER},
}


GENERAL_SHOULDER = .5
HAIRSTYLES = Path('/Users/ktabb/Documents/3dAssets/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)')

def trim_outside_x(obj, reach):
    # Keep only the part of a sleeve within `reach` of the body's centre line.
    world=obj.matrix_world
    remove_faces(obj,lambda f: all(abs((world@v.co).x)>reach for v in f.verts))
    import bmesh
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(obj.data); bm.free()

def add_general_head(body, rig):
    # A full beard from the base character's hairstyles, and the statue's short
    # hair worked into tight curls with a lumpy noise along the scalp.
    import bpy
    from mathutils import noise
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(HAIRSTYLES/'Hair_Beard.gltf'))
    for obj in set(bpy.data.objects)-before:
        # The file also carries a stray Icosphere; only the beard is kept.
        if obj.type=='MESH' and obj.name.startswith('Hair_Beard'):
            world=obj.matrix_world.copy(); obj.parent=rig; obj.matrix_world=world
            for mod in obj.modifiers:
                if mod.type=='ARMATURE': mod.object=rig
            obj.name='GeneralBeard'
            # The hairstyle beard sits inside this statue's jaw; bring it out
            # over the chin and cheeks.
            center=Vector((0,-.01,1.63))
            for v in obj.data.vertices:
                p=obj.matrix_world@v.co
                p=center+(p-center)*1.06+Vector((0,-.012,-.004))
                v.co=obj.matrix_world.inverted()@p
            obj.select_set(True)
            body['beard']=obj.name
        else: bpy.data.objects.remove(obj,do_unlink=True)
    names={g.index:g.name for g in body.vertex_groups}
    for v in body.data.vertices:
        best=max(v.groups,key=lambda g:g.weight,default=None)
        if not best or names[best.group]!='Head': continue
        scalp=v.co.z>1.775 or (v.co.z>1.62 and v.co.y>.03)
        if not scalp: continue
        curl=noise.noise(v.co*38.0)*.6+noise.noise(v.co*90.0)*.35
        v.co+=v.normal*(.007+.011*max(-.5,curl))


# The hood of the KayKit hooded rogue. Its head mesh carries the rogue's face
# as well: the pieces it shares with the plain rogue head, and the brows, are
# dropped, keeping the hood shell, its face rim, its inner collar and the
# peak. It is fitted around the statue's own head (0.18 x 0.22 x 0.26 m), its
# face opening at the brow and its rim under the chin, and the lower edge is
# drawn down and out over the neck and shoulders into a cowl. `deep` gives the
# Oracle a longer cowl and a taller peak; `shade` draws the brim forward and
# down over the eyes, so the face sits in its shadow.
def add_hood(rig, deep=False, shade=False):
    import bpy, bmesh
    from mathutils import kdtree
    def load(name):
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(SOURCE/name))
        return set(bpy.data.objects)-before
    plain_set=load('Rogue.glb')
    plain=next(o for o in plain_set if o.name.startswith('Rogue_Head'))
    face=kdtree.KDTree(len(plain.data.vertices))
    for v in plain.data.vertices: face.insert(plain.matrix_world@v.co,v.index)
    face.balance()
    for o in plain_set: bpy.data.objects.remove(o,do_unlink=True)
    hooded_set=load('Rogue_Hooded.glb')
    hood=next(o for o in hooded_set if o.name.startswith('Rogue_Head_Hooded'))
    for o in hooded_set:
        if o!=hood: bpy.data.objects.remove(o,do_unlink=True)
    hood.data.transform(hood.matrix_world); hood.parent=None; hood.matrix_world.identity()
    bm=bmesh.new(); bm.from_mesh(hood.data); bm.verts.ensure_lookup_table()
    seen=set(); drop=[]
    for start in bm.verts:
        if start in seen: continue
        part=[]; stack=[start]; seen.add(start)
        while stack:
            v=stack.pop(); part.append(v)
            for e in v.link_edges:
                o=e.other_vert(v)
                if o not in seen: seen.add(o); stack.append(o)
        shared=sum(1 for v in part if face.find(v.co)[2]<.005)
        xs=[v.co.x for v in part]
        spans=min(xs)<-.3 and max(xs)>.3
        peak=min(v.co.y for v in part)>.3
        if shared>1 or not (spans or peak): drop+=part
    bmesh.ops.delete(bm,geom=drop,context='VERTS')
    bm.to_mesh(hood.data); bm.free()
    lo,hi=bounds(hood)
    cowl=.15 if deep else .10
    for v in hood.data.vertices:
        u=v.co-lo; u=Vector((u.x/(hi.x-lo.x),u.y/(hi.y-lo.y),u.z/(hi.z-lo.z)))
        p=Vector(((u.x-.5)*.27,-.145+u.y*.315,1.53+u.z*.375))
        if deep and u.z>.75 and u.y>.6: p.z+=(u.z-.75)*(u.y-.6)*.35
        # A soft, rounded crown rather than the rogue hood's tall point.
        if shade and u.z>.6: p.z-=(u.z-.6)*.12
        if shade and u.y<.35:
            front=(.35-u.y)/.35
            p.y-=front*.055
            if u.z>.4: p.z-=front*.045*min(1.0,(u.z-.4)/.2)
        if u.z<.3:
            t=(.3-u.z)/.3
            p.z-=t*cowl
            p.x*=1+t*(.7 if deep else .55)
            p.y=(p.y-.01)*(1+t*.35)+.01
        v.co=p
    for group in list(hood.vertex_groups): hood.vertex_groups.remove(group)
    groups={name:hood.vertex_groups.new(name=name) for name in ['Head','neck_01','spine_03']}
    for v in hood.data.vertices:
        head=max(0.0,min(1.0,(v.co.z-1.54)/.1))
        neck=(1-head)*max(0.0,min(1.0,(v.co.z-1.42)/.1))
        for name,weight in [('Head',head),('neck_01',neck),('spine_03',1-head-neck)]:
            if weight>0: groups[name].add([v.index],weight,'REPLACE')
    for mod in list(hood.modifiers): hood.modifiers.remove(mod)
    hood.parent=rig
    hood.modifiers.new('Statue outfit skin','ARMATURE').object=rig
    hood.name='StatueHood'
    return hood


# The warrior's armor as a shell of the body (see tools/outfit_hero.py): the
# armored part of the body is copied and thickened outward, keeping its UVs
# and skin weights. `covered(bone, height)` picks the part.
def body_shell(body, rig, name, covered, offset, thickness, raised=(), raise_by=0.0):
    import bpy, bmesh
    shell=body.copy(); shell.data=body.data.copy(); shell.name=name
    bpy.context.scene.collection.objects.link(shell)
    names={g.index:g.name for g in shell.vertex_groups}
    def bone(v):
        best=max(v.groups,key=lambda g:g.weight,default=None)
        return names[best.group] if best else ''
    keep={v.index for v in shell.data.vertices if covered(bone(v),v.co.z)}
    mesh=bmesh.new(); mesh.from_mesh(shell.data)
    bmesh.ops.delete(mesh,geom=[f for f in mesh.faces if not all(v.index in keep for v in f.verts)],context='FACES')
    bmesh.ops.delete(mesh,geom=[v for v in mesh.verts if not v.link_faces],context='VERTS')
    mesh.to_mesh(shell.data); mesh.free()
    for v in shell.data.vertices:
        v.co+=v.normal*(raise_by if bone(v).startswith(raised) else offset)
    for modifier in list(shell.modifiers): shell.modifiers.remove(modifier)
    solid=shell.modifiers.new('Plate thickness','SOLIDIFY')
    solid.thickness=thickness; solid.offset=-1.0; solid.use_rim=True
    bpy.context.view_layer.objects.active=shell
    bpy.ops.object.modifier_apply(modifier=solid.name)
    shell.parent=rig
    shell.modifiers.new('Armature','ARMATURE').object=rig
    return shell

# The hero's scale cuirass: chest, back, shoulders and upper arms, down to the belt.
SCALE_ARMOR_BONES=('upperarm','clavicle','spine_02','spine_03')
CUIRASS_BOTTOM=1.05
def scale_cuirass(body, rig, name):
    def covered(bone, height):
        if bone.startswith(SCALE_ARMOR_BONES): return True
        return bone.startswith(('spine_01','pelvis','root')) and height>=CUIRASS_BOTTOM
    return body_shell(body,rig,name,covered,.025,.02,('clavicle','upperarm'),.035)

# The hero's forearm bracers, which are painted leather on the hero.
def bracers(body, rig, name):
    return body_shell(body,rig,name,lambda bone,height: bone.startswith('lowerarm'),.012,.012)


# The gladiator's armored kilt: the knight's belt and its short skirt of plates,
# drawn down to mid-thigh and flared clear of the legs. Its lower part follows
# the thighs a little, so running strides do not drive the legs through it.
KILT_TOP=.63
# Heights on the statue: the belt sits on the hips, the plates end mid-thigh.
KILT_BELT=1.06
KILT_HEM=.72
KILT_CENTER_Y=.025
# How far the belt's outer face stands off the waist.
BELT_CLEARANCE=.022
def open_kilt(body):
    # The knight's torso closes underneath in a cap painted dark grey; without
    # it, the ring of grey plates hangs open like a kilt. Faces are told apart
    # by the texture color at their UVs.
    image=next(n.image for n in body.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
    width,height=image.size
    pixels=image.pixels[:]
    uv=body.data.uv_layers.active.data
    dark=set()
    world=body.matrix_world
    for poly in body.data.polygons:
        if (world@poly.center).z>.46: continue
        u=sum(uv[i].uv.x for i in poly.loop_indices)/poly.loop_total
        v=sum(uv[i].uv.y for i in poly.loop_indices)/poly.loop_total
        x=min(width-1,max(0,int((u%1.0)*width))); y=min(height-1,max(0,int((v%1.0)*height)))
        r,g,b=pixels[(y*width+x)*4:(y*width+x)*4+3]
        if .2126*r+.7152*g+.0722*b<.28: dark.add(poly.index)
    remove_faces(body,lambda f: f.index in dark)

# Waists: positions around the body's vertical centre line, in sectors.
SECTORS=24
def bearing_of(co): return math.atan2(co.y-KILT_CENTER_Y,co.x)
def sector_of(co): return int((bearing_of(co)+math.pi)/(2*math.pi)*SECTORS)%SECTORS
def radius_of(co): return math.hypot(co.x,co.y-KILT_CENTER_Y)
def place(co, radius):
    bearing=bearing_of(co)
    co.x=math.cos(bearing)*radius
    co.y=KILT_CENTER_Y+math.sin(bearing)*radius

def waist_profile(body, low, high):
    # The body's outermost torso or thigh surface between two heights, in
    # each direction, smoothed over neighboring directions.
    names={g.index:g.name for g in body.vertex_groups}
    waist=[0.0]*SECTORS
    for v in body.data.vertices:
        if not low<=v.co.z<=high: continue
        best=max(v.groups,key=lambda g:g.weight,default=None)
        if not best or (region_of_bone(names[best.group]) or '').startswith('arm'): continue
        sector=sector_of(v.co)
        waist[sector]=max(waist[sector],radius_of(v.co))
    return [max(waist[(i+d)%SECTORS] for d in (-1,0,1)) for i in range(SECTORS)]

def outer_profile(piece, band):
    # A belt's own outer surface in each direction, its buckle aside.
    rings={}
    for v in piece.data.vertices:
        if band(v.co): rings.setdefault(sector_of(v.co),[]).append(radius_of(v.co))
    return {k:sorted(r)[int(len(r)*.75)] for k,r in rings.items()}

def lengthen_kilt(kilt, body):
    top=max(v.co.z for v in kilt.data.vertices)
    lowest=min(v.co.z for v in kilt.data.vertices)
    # The knight's belt fills the upper ~60% of the piece; it is kept whole,
    # at half its height, and only the plates below it are drawn down.
    belt=lowest+(top-lowest)*.38
    for group in ['thigh_l','thigh_r']:
        if not kilt.vertex_groups.get(group): kilt.vertex_groups.new(name=group)
    # The statue's waist where the belt sits, and the belt's own width.
    waist=waist_profile(body,KILT_BELT-.03,KILT_BELT+.08)
    belt_outer=outer_profile(kilt,lambda co: co.z>=belt)
    # The knight's plates hang lower in front than at the sides; each part of
    # the ring is drawn down from its own lowest point, so the hem is level.
    low={}
    for v in kilt.data.vertices:
        if v.co.z<belt:
            sector=sector_of(v.co)
            low[sector]=min(low.get(sector,belt),v.co.z)
    def local_lowest(co):
        sector=sector_of(co)
        return max(low.get((sector+d)%SECTORS,lowest) for d in (-1,0,1))
    for v in kilt.data.vertices:
        sector=sector_of(v.co)
        if v.co.z>=belt:
            # The belt is drawn in to sit snugly on the waist.
            place(v.co,radius_of(v.co)*(waist[sector]+BELT_CLEARANCE)/max(belt_outer.get(sector,waist[sector]),.001))
            v.co.z=KILT_BELT+(v.co.z-belt)*.5
            continue
        t=min(1.0,(belt-v.co.z)/max(belt-local_lowest(v.co),.001))
        v.co.z=KILT_BELT-t*(KILT_BELT-KILT_HEM)
        # The plates start just outside the belt and flare to an oval around
        # the thighs at the hem (0.48 x 0.37 m), each keeping its bearing.
        bearing=bearing_of(v.co)
        hem=1/math.sqrt((math.cos(bearing)/.24)**2+(math.sin(bearing)/.185)**2)
        place(v.co,(waist[sector]+BELT_CLEARANCE+.008)*(1-t)+hem*t)
        leg='thigh_l' if v.co.x>=0 else 'thigh_r'
        influence=.4*t
        for g in list(v.groups): kilt.vertex_groups[g.group].add([v.index],g.weight*(1-influence),'REPLACE')
        kilt.vertex_groups[leg].add([v.index],influence,'REPLACE')

# Hanging cloth (the ranger's cloak, the Crowned Statue's cape): one layer,
# an even grid, swung in the game by chains of bones on a spring simulation
# and folded over the legs by its shader (scripts/visual.gd). Bearings are
# measured round the body from straight behind.
def cloth_bearing(co): return math.atan2(co.x,co.y-KILT_CENTER_Y)

def cloth_sheet(cloth, ring, top, hem, flare, reach, columns=56, rows=22, offset=-.012):
    # Adds a sheet to `cloth` hanging from `top` to `hem`, round the back
    # from bearing -reach to reach, flaring by `flare` at the hem. Its top
    # follows the girth of `ring` (vertices of any mesh, with their skin
    # weights) plus `offset`, and takes the weights of the nearest of them.
    import bmesh
    from mathutils import kdtree
    cy = KILT_CENTER_Y
    points = [(ob.matrix_world @ v.co, [(ob.vertex_groups[g.group].name,g.weight) for g in v.groups]) for ob,v in ring]
    def sampled(b):
        near = [math.hypot(p.x,p.y-cy) for p,_ in points if abs(math.remainder(cloth_bearing(p)-b,2*math.pi))<.3]
        return (max(near) if near else .2)+offset
    # Smoothed round the body, so the cloth hangs in soft folds, not ridges.
    girth = [sampled(-reach+2*reach*i/columns) for i in range(columns+1)]
    for _ in range(8):
        girth = [sum(girth[max(0,min(columns,i+d))] for d in (-2,-1,0,1,2))/5 for i in range(columns+1)]
    tree = kdtree.KDTree(len(points))
    for i,(p,_) in enumerate(points): tree.insert(p,i)
    tree.balance()
    mesh = bmesh.new(); mesh.from_mesh(cloth.data)
    deform = mesh.verts.layers.deform.verify()
    groups = {}
    def group(name):
        if name not in groups:
            groups[name] = (cloth.vertex_groups.get(name) or cloth.vertex_groups.new(name=name)).index
        return groups[name]
    grid = []
    for j in range(rows+1):
        t = j/rows
        z = top+(hem-top)*t
        row = []
        for i in range(columns+1):
            b = -reach+2*reach*i/columns
            r = girth[i]*(1+flare*t*t*(3-2*t))
            v = mesh.verts.new(Vector((math.sin(b)*r,cy+math.cos(b)*r,z)))
            # The top rows move with the body; the chains take over below.
            _,k,_ = tree.find(v.co)
            for name,weight in points[k][1]: v[deform][group(name)] = weight
            row.append(v)
        grid.append(row)
    for j in range(rows):
        for i in range(columns):
            mesh.faces.new((grid[j][i],grid[j+1][i],grid[j+1][i+1],grid[j][i+1]))
    mesh.to_mesh(cloth.data); mesh.free()
    for face in cloth.data.polygons: face.use_smooth = True

def cloth_chains(rig, cloth, root_bone, root, blend, chains=13, segments=8, prefix='cloak_'):
    # Chains of bones from `root_bone` at height `root` down the inside of the
    # cloth to its hem, spread across it, named cloak_<chain>_<segment>. The
    # cloth below `blend` is skinned to the two nearest chains, blending into
    # its own (body) weights between blend[0] and blend[1]. A second cloth on
    # the same rig takes another `prefix`.
    import bpy
    cy = KILT_CENTER_Y
    hanging = [v.co.copy() for v in cloth.data.vertices if v.co.z<root-.1]
    bearings = sorted(cloth_bearing(co) for co in hanging)
    low, high = bearings[int(len(bearings)*.02)], bearings[int(len(bearings)*.98)]
    lines = []
    for i in range(chains):
        b = low+(high-low)*i/(chains-1)
        # The cloth near this bearing; the window widens where the mesh is sparse.
        for window in (.15,.25,.4,.6):
            near = [co for co in (v.co for v in cloth.data.vertices) if abs(cloth_bearing(co)-b)<window and co.z<root+.05]
            if len(near)>=6: break
        hem = min(co.z for co in near)
        def radius_at(z):
            ring = [co for co in near if abs(co.z-z)<.06] or near
            return sum(math.hypot(co.x,co.y-cy) for co in ring)/len(ring)-.015
        points = []
        for j in range(segments+1):
            z = root+(hem+.02-root)*j/segments
            r = radius_at(z)
            points.append(Vector((math.sin(b)*r,cy+math.cos(b)*r,z)))
        lines.append(points)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    bones = rig.data.edit_bones
    to_rig = rig.matrix_world.inverted()
    for i,points in enumerate(lines):
        parent = bones[root_bone]
        for j in range(segments):
            bone = bones.new(prefix+'%d_%d' % (i,j))
            bone.head = to_rig @ points[j]; bone.tail = to_rig @ points[j+1]
            bone.parent = parent; bone.use_connect = j>0
            parent = bone
    bpy.ops.object.mode_set(mode='OBJECT')
    for i in range(chains):
        for j in range(segments): cloth.vertex_groups.new(name=prefix+'%d_%d' % (i,j))
    for v in cloth.data.vertices:
        z = v.co.z
        if z>=blend[1]: continue
        body_share = max(0.0,min(1.0,(z-blend[0])/(blend[1]-blend[0])))
        for g in list(v.groups):
            cloth.vertex_groups[g.group].add([v.index],g.weight*body_share,'REPLACE')
        b = max(low,min(high,cloth_bearing(v.co)))
        span = (b-low)/(high-low)*(chains-1)
        i = min(chains-2,int(span)); a = span-i
        for chain,share in [(i,1-a),(i+1,a)]:
            points = lines[chain]
            t = max(0.0,min(.999,(root-z)/(root-points[-1].z)))
            cloth.vertex_groups[prefix+'%d_%d' % (chain,int(t*segments))].add([v.index],(1-body_share)*share,'ADD')

# A cape of cloth hanging from the shoulders, just outside `torso` (the fitted
# cuirass or robe), round the back to `hem`, swung by chains from the upper
# back. Returned unjoined, skinned to `rig`.
CAPE_ROOT = 1.36
CAPE_BLEND = (1.28, 1.4)
def shoulder_cape(rig, torso, name, hem=.34, flare=.32, prefix='cloak_'):
    import bpy
    # The torso's shoulders only, not sleeves joined to it.
    names={g.index:g.name for g in torso.vertex_groups}
    def on_arm(v):
        best=max(v.groups,key=lambda g:g.weight,default=None)
        return best is not None and names[best.group].startswith(('upperarm','lowerarm','hand'))
    shoulders=[(torso,v) for v in torso.data.vertices if 1.3<=(torso.matrix_world@v.co).z<1.45 and not on_arm(v)]
    cape=bpy.data.objects.new(name,bpy.data.meshes.new(name))
    bpy.context.scene.collection.objects.link(cape)
    cloth_sheet(cape,shoulders,top=1.42,hem=hem,flare=flare,reach=math.radians(78),rows=26,offset=.018)
    cloth_chains(rig,cape,'spine_03',CAPE_ROOT,CAPE_BLEND,prefix=prefix)
    cape.parent=rig
    cape.modifiers.new('Statue outfit skin','ARMATURE').object=rig
    return cape

def remove_bones(rig, prefix):
    import bpy
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in [b for b in rig.data.edit_bones if b.name.startswith(prefix)]: rig.data.edit_bones.remove(bone)
    bpy.ops.object.mode_set(mode='OBJECT')

def remove_faces(obj, predicate):
    import bmesh
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if predicate(f)],context='FACES')
    bm.to_mesh(obj.data); bm.free()


def fit(source, source_rig, target_rig, style):
    world = source.matrix_world.copy()
    weights = [[(source.vertex_groups[g.group].name,g.weight) for g in v.groups if source.vertex_groups[g.group].name in BONES] for v in source.data.vertices]
    old_bounds = bounds(source)
    name = source.name
    is_body = name.endswith('_Body')
    is_cape = name.endswith('_Cape')
    is_helmet = name.endswith('_Helmet')
    if is_helmet:
        lo,hi=old_bounds
        for v in source.data.vertices:
            t=(world@v.co-lo)
            u=Vector((t.x/(hi.x-lo.x),t.y/(hi.y-lo.y),t.z/(hi.z-lo.z)))
            v.co=Vector((u.x*.38-.19,u.y*.40-.21,u.z*.49+1.51))
            if style=='legion':
                # A closed helm sized to the statue's head, not the knight's box.
                v.co=Vector((u.x*.26-.13,u.y*.30-.155,u.z*.33+1.575))
            if style=='fullhelm':
                # The hero's full helm: close over the head, reaching below the
                # jaw, its ridge kept low rather than raised into a crest.
                v.co=Vector((u.x*.25-.125,u.y*.29-.15,u.z*.37+1.525))
            if style=='murmillo':
                # Sized to the statue's own head (0.18 x 0.22 x 0.26m) rather
                # than the knight helm's oversized box.
                v.co=Vector((u.x*.25-.125,u.y*.29-.15,u.z*.31+1.585))
                # Gladiator helm: the knight's ridge spikes rise into a tall
                # crest, and the lower rim flares into a broad brim.
                ridge=max(0,1-abs(u.x-.5)/.13)
                if u.z>.8: v.co.z+=(u.z-.8)*.75*ridge; v.co.y+=(u.z-.8)*.2*ridge
                flare=1+max(0,.32-u.z)*.45
                v.co.x*=flare; v.co.y=(v.co.y+.01)*flare-.01
        weights=[[('head',1)] for _ in weights]
    elif is_cape:
        for v in source.data.vertices:
            p=world@v.co
            v.co=Vector((p.x*.68,p.y*.58+.04,.13+(p.z-.04)/1.182*1.39))
        weights=[[('hips',max(0,min(1,(1.38-v.co.z)/.5))),('chest',max(0,min(1,(v.co.z-.88)/.5)))] for v in source.data.vertices]
    else:
        for v,groups in zip(source.data.vertices,weights):
            p=world@v.co; result=Vector(); total=0
            for bone,weight in groups:
                sb=source_rig.data.bones[bone]
                tb=target_rig.data.bones[BONES[bone]]
                sh=source_rig.matrix_world@sb.head_local
                th=target_rig.matrix_world@tb.head_local
                scale=Vector((.78,.59,.64)) if style=='plate' else Vector((.69,.50,.64))
                if 'arm.' in bone:
                    ratio=tb.length/max(sb.length,.001)
                    scale=Vector((ratio,.82 if style=='plate' else .70,.82 if style=='plate' else .70))
                elif bone.startswith(('wrist','hand')):
                    scale=Vector((.47,.55,.60))
                elif bone.startswith(('upperleg','lowerleg')):
                    scale=Vector((.82,.80,tb.length/max(sb.length,.001)))
                elif bone.startswith(('foot','toes')):
                    scale=Vector((.83,.80,.60))
                delta=p-sh
                result += (th+Vector((delta.x*scale.x,delta.y*scale.y,delta.z*scale.z)))*weight
                total+=weight
            v.co=result/max(total,.001)
            if style=='robes' and is_body:
                # Extend the authored tunic's lower skirt into an ankle-length robe.
                if p.z<.70:
                    v.co.z=.14+max(0,(p.z-.354)/.346)*.94
                    v.co.x=p.x*.80
                    v.co.y=p.y*.68
                elif p.z<.973:
                    v.co.z=1.08+(p.z-.70)/.273*.23
    source.parent=None
    source.matrix_world.identity()
    for modifier in list(source.modifiers):source.modifiers.remove(modifier)
    for group in list(source.vertex_groups):source.vertex_groups.remove(group)
    for vertex,groups in zip(source.data.vertices,weights):
        result={}
        for old,weight in groups:
            new=BONES[old]; result[new]=result.get(new,0)+weight
        if style=='robes' and is_body and vertex.co.z<.9:
            leg='thigh_l' if vertex.co.x>=0 else 'thigh_r'
            influence=.70*max(0,min(1,(.9-vertex.co.z)/.76))
            result={'pelvis':1-influence,leg:influence}
        total=sum(result.values())
        for group_name,value in result.items():
            group=source.vertex_groups.get(group_name) or source.vertex_groups.new(name=group_name)
            group.add([vertex.index],value/max(total,.001),'REPLACE')
    source.parent=target_rig
    arm=source.modifiers.new('Statue outfit skin','ARMATURE');arm.object=target_rig
    source.hide_set(False); source.hide_render=False
    # Keep the supplied human fingers free of the source character's mitten hands.
    if '_Arm' in name:
        hands={v.index for v in source.data.vertices if sum(g.weight for g in v.groups if source.vertex_groups[g.group].name in ['hand_l','hand_r'])>.8}
        remove_faces(source,lambda f: all(v.index in hands for v in f.verts))
    return source


# The murmillo gladiator: the warrior's armor in stone (a scale cuirass with
# shoulder guards and forearm bracers), an armored kilt, bare legs and a
# crested, brimmed helm.
MURMILLO=[('Knight','Knight_Body','plate',KILT_TOP),('Knight','Knight_Helmet','murmillo',None)]
def build_outfits():
    # The Crowned Statue ('general') is armored like a Roman general's statue:
    # a cuirass, the gladiator's armored kilt, shoulder guards, a cape, bare
    # legs, a full beard and curled hair under its crown.
    for output,pack,style in [('gladiator','Barbarian','murmillo'),('archer','Rogue','light'),('centurion','Knight','legion'),('wizard','Mage','robes'),('boss','Knight','general')]:
        if '--only' in sys.argv and output != sys.argv[sys.argv.index('--only')+1]: continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        # The clips are baked at 30 fps (tools/import_combat.py); exporting at
        # Blender's default 24 would resample and shift them.
        bpy.context.scene.render.fps=30
        bpy.ops.import_scene.gltf(filepath=str(OUTPUT/'guardian.glb'))
        target=next(o for o in bpy.data.objects if o.type=='ARMATURE')
        target.name='StatueRig'
        body=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='StoneGuardian')
        imported=set(); fitted=[]
        packs=sorted({piece[0] for piece in MURMILLO}) if style=='murmillo' else [pack]
        for source_pack in packs:
            before=set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(SOURCE/(source_pack+'.glb')))
            new=set(bpy.data.objects)-before
            imported|=new
            source=next(o for o in new if o.type=='ARMATURE')
            chosen=[]
            for obj in new:
                if obj.type!='MESH':continue
                if style=='general':
                    if obj.name==pack+'_Body':
                        # The same armored kilt as the gladiator's, from a copy
                        # of the knight's torso; the cuirass itself ends at its
                        # belt, where the kilt's belt takes over.
                        kilt=obj.copy(); kilt.data=obj.data.copy(); kilt.name='Knight_Kilt'
                        bpy.context.scene.collection.objects.link(kilt)
                        trim_above(kilt,KILT_TOP); open_kilt(kilt)
                        chosen.append((kilt,'plate'))
                        trim_below(obj,KILT_TOP-.01)
                    # The knight's cape is replaced by a hanging cloth cape (below).
                    if obj.name==pack+'_Body': chosen.append((obj,'plate'))
                    elif obj.name in (pack+'_ArmLeft',pack+'_ArmRight'):
                        # Only the shoulder guards: bare forearms, as on the statue.
                        trim_outside_x(obj,GENERAL_SHOULDER)
                        chosen.append((obj,'plate'))
                    continue
                if style=='murmillo':
                    piece=next((p for p in MURMILLO if p[0]==source_pack and obj.name==p[1]),None)
                    if piece:
                        if piece[3] is not None: trim_above(obj,piece[3])
                        if obj.name=='Knight_Body': open_kilt(obj)
                        chosen.append((obj,piece[2]))
                    continue
                if obj.name.startswith(pack+'_') and any(token in obj.name for token in (['_Body','_Arm'] if style=='robes' else ['_Body','_Arm','_Leg'])):chosen.append((obj,'plate' if style in ['legion','royal'] else style))
                if style in ['plate','legion'] and obj.name==pack+'_Helmet':chosen.append((obj,style))
                # The mage's rigid cape is replaced by a hanging cloth cape (below).
            fitted+=[fit(obj,source,target,piece_style) for obj,piece_style in chosen]
        if style=='legion':
            # Reshape the body first, then close-fit the armor over the new build.
            reproportion(body,target,shoulder=.045,thigh_cut=0,calf_cut=0,muscle=LEGION_MUSCLE)
        if style=='murmillo':
            kilt=next(p for p in fitted if p.name.startswith('Knight_Body'))
            kilt.name='ArmoredKilt'
            lengthen_kilt(kilt,body)
        if style=='general':
            add_general_head(body,target)
            kilt=next(p for p in fitted if p.name.startswith('Knight_Kilt'))
            kilt.name='ArmoredKilt'
            lengthen_kilt(kilt,body)
        # Every outfit is close-fitted over its wearer, so no unit keeps the
        # KayKit pieces' toy-proportioned tubes and barrels.
        for piece in fitted:
            suffix=next((k for k in ARMOR_REGION if piece.name.endswith(k)),None)
            if suffix: armor_up(piece,body,target,suffix,**CLOSE_FIT[style].get(suffix,{}))
        # Scale armor is marked for the stone shader, which cuts the warrior's
        # scale pattern into it: 0 in the mask's red channel is scales.
        scaled=[]
        if style=='murmillo':
            scaled.append(scale_cuirass(body,target,'ScaleCuirass'))
            fitted+=scaled+[bracers(body,target,'Bracers')]
        if style in ['light','robes']: fitted.append(add_hood(target,deep=style=='robes'))
        cloth=[]
        if style in ['general','robes']:
            # The Crowned Statue's and the Oracle's capes, as the ranger's
            # cloak: one layer of cloth hanging from the shoulders, just
            # outside the cuirass or robe, round the back (to mid-calf, or the
            # robe's hem), swung by chains of bones from the upper back and
            # folded over the legs in the game; in stone.
            torso=next(p for p in fitted if p.name.startswith(('Knight_Body','Mage_Body')))
            cape=shoulder_cape(target,torso,'StoneCape',hem=.34 if style=='general' else .2,flare=.32 if style=='general' else .22)
            cloth.append(cape); fitted.append(cape)
        # The closed knight helm hides the head; the gladiator's visor shows the face.
        if style=='plate': remove_faces(body,lambda f: all(v.co.z>1.52 for v in f.verts))
        if style=='robes':
            # Covered legs are omitted so high running knees do not pierce the robe.
            covered={v.index for v in body.data.vertices if v.co.z>.18 and sum(g.weight for g in v.groups if body.vertex_groups[g.group].name.startswith(('thigh_','calf_')))> .2}
            remove_faces(body,lambda f: all(v.index in covered for v in f.verts))
        for obj in imported:
            if obj not in fitted and obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
        if style=='general': fitted.append(bpy.data.objects[body['beard']])
        for obj in [body]+fitted:
            if obj.type!='MESH': continue
            mask=obj.data.color_attributes.new('StoneMask','BYTE_COLOR','POINT')
            # Hanging cloth is marked 0 in the green channel, for the shader
            # that folds it over the legs.
            shade=(0,0,0,1) if obj in scaled else ((1,0,1,1) if obj in cloth else (1,1,1,1))
            for item in mask.data: item.color=shade
        bpy.ops.object.select_all(action='DESELECT')
        for obj in [body]+fitted:obj.select_set(True)
        bpy.context.view_layer.objects.active=body
        bpy.ops.object.join()
        body.data.color_attributes.active_color=body.data.color_attributes['StoneMask']
        body.data.color_attributes.render_color_index=body.data.color_attributes.active_color_index
        body.name='Stone'+output.capitalize()
        body.data.materials.clear()
        mat=bpy.data.materials.new('WeatheredStone'); mat.diffuse_color=(.62,.62,.62,1)
        body.data.materials.append(mat)
        for polygon in body.data.polygons:polygon.material_index=0
        bpy.ops.object.select_all(action='DESELECT')
        body.select_set(True); target.select_set(True)
        bpy.context.scene.frame_set(0)
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT/('guardian_'+output+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_vertex_color='ACTIVE')
        print('ENEMY_OUTFIT_READY',output,len(body.data.vertices))


# tools/outfit_hero.py imports the fitting helpers above without building outfits.
if __name__ == "__main__":
    build_outfits()
