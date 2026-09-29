"""Fit authored KayKit clothing to the existing Quaternius statue rig.
No primitive geometry is generated. Each outfit is merged into one skinned
surface and retains the guardian's authored animation clips.
"""
from pathlib import Path
import bpy
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
    for v,original,a in zip(piece.data.vertices,authored,amount): v.co=v.co.lerp(original,1-a*(1-relief))
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


# Per style and piece: thickness over the body, share of authored shape kept,
# and how much of the piece is pulled in.
LEATHER={'thickness':.018,'relief':.3}
CLOSE_FIT={
    'legion':{},
    'light':{'_Body':{'thickness':.028,'relief':.3},'_ArmLeft':LEATHER,'_ArmRight':LEATHER,'_LegLeft':LEATHER,'_LegRight':LEATHER},
    # The gladiator's belt keeps more of its studs and fringe; the plated arm fits.
    'murmillo':{'_Body':{'thickness':.03,'relief':.45},'_ArmRight':{'thickness':.025,'relief':.35}},
    # The robe fits over the chest and sleeves; the lengthened skirt stays loose.
    'robes':{'_Body':{'thickness':.028,'relief':.3,'reach':lambda co: max(0.0,min(1.0,(co.z-.98)/.14))},'_ArmLeft':LEATHER,'_ArmRight':LEATHER},
}


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


# The murmillo gladiator: a bare statue torso with the barbarian's studded
# belt and fringe, a plated sword arm, bare legs and a crested, brimmed helm.
MURMILLO=[('Barbarian','Barbarian_Body','light',.66),('Knight','Knight_ArmRight','plate',None),
    ('Knight','Knight_Helmet','murmillo',None)]
def build_outfits():
    for output,pack,style in [('gladiator','Barbarian','murmillo'),('archer','Rogue','light'),('centurion','Knight','legion'),('wizard','Mage','robes')]:
        if '--only' in sys.argv and output != sys.argv[sys.argv.index('--only')+1]: continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
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
                if style=='murmillo':
                    piece=next((p for p in MURMILLO if p[0]==source_pack and obj.name==p[1]),None)
                    if piece:
                        if piece[3] is not None: trim_above(obj,piece[3])
                        chosen.append((obj,piece[2]))
                    continue
                if obj.name.startswith(pack+'_') and any(token in obj.name for token in (['_Body','_Arm'] if style=='robes' else ['_Body','_Arm','_Leg'])):chosen.append((obj,'plate' if style=='legion' else style))
                if style in ['plate','legion'] and obj.name==pack+'_Helmet':chosen.append((obj,style))
                if style=='robes' and obj.name==pack+'_Cape':chosen.append((obj,style))
            fitted+=[fit(obj,source,target,piece_style) for obj,piece_style in chosen]
        if style=='legion':
            # Reshape the body first, then close-fit the armor over the new build.
            reproportion(body,target,shoulder=.045,thigh_cut=0,calf_cut=0,muscle=LEGION_MUSCLE)
        # Every outfit is close-fitted over its wearer, so no unit keeps the
        # KayKit pieces' toy-proportioned tubes and barrels.
        for piece in fitted:
            suffix=next((k for k in ARMOR_REGION if piece.name.endswith(k)),None)
            if suffix: armor_up(piece,body,target,suffix,**CLOSE_FIT[style].get(suffix,{}))
        # The closed knight helm hides the head; the gladiator's visor shows the face.
        if style=='plate': remove_faces(body,lambda f: all(v.co.z>1.52 for v in f.verts))
        if style=='robes':
            # Covered legs are omitted so high running knees do not pierce the robe.
            covered={v.index for v in body.data.vertices if v.co.z>.18 and sum(g.weight for g in v.groups if body.vertex_groups[g.group].name.startswith(('thigh_','calf_')))> .2}
            remove_faces(body,lambda f: all(v.index in covered for v in f.verts))
        for obj in imported:
            if obj not in fitted and obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in [body]+fitted:obj.select_set(True)
        bpy.context.view_layer.objects.active=body
        bpy.ops.object.join()
        body.name='Stone'+output.capitalize()
        body.data.materials.clear()
        mat=bpy.data.materials.new('WeatheredStone'); mat.diffuse_color=(.62,.62,.62,1)
        body.data.materials.append(mat)
        for polygon in body.data.polygons:polygon.material_index=0
        bpy.ops.object.select_all(action='DESELECT')
        body.select_set(True); target.select_set(True)
        bpy.context.scene.frame_set(0)
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT/('guardian_'+output+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
        print('ENEMY_OUTFIT_READY',output,len(body.data.vertices))


# tools/outfit_hero.py imports the fitting helpers above without building outfits.
if __name__ == "__main__":
    build_outfits()
