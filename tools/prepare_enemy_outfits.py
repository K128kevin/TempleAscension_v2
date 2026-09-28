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
            v.co=Vector((t.x/(hi.x-lo.x)*.38-.19,t.y/(hi.y-lo.y)*.40-.21,t.z/(hi.z-lo.z)*.49+1.51))
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


for output,pack,style in [('gladiator','Barbarian','light'),('archer','Rogue','light'),('centurion','Knight','plate'),('wizard','Mage','robes')]:
    if '--only' in sys.argv and output != sys.argv[sys.argv.index('--only')+1]: continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUTPUT/'guardian.glb'))
    target=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    target.name='StatueRig'
    body=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='StoneGuardian')
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/(pack+'.glb')))
    imported=set(bpy.data.objects)-before
    source=next(o for o in imported if o.type=='ARMATURE')
    chosen=[]
    for obj in imported:
        if obj.type!='MESH':continue
        if obj.name.startswith(pack+'_') and any(token in obj.name for token in (['_Body','_Arm'] if style=='robes' else ['_Body','_Arm','_Leg'])):chosen.append(obj)
        if style=='plate' and obj.name==pack+'_Helmet':chosen.append(obj)
        if style=='robes' and obj.name==pack+'_Cape':chosen.append(obj)
    fitted=[fit(obj,source,target,style) for obj in chosen]
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
