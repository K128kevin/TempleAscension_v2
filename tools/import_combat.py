"""Retarget library swings and bake bespoke archery/spear clips onto the supplied rig.
No geometry is generated. Run after import_character.py; safe to rerun.
"""
from pathlib import Path
import bpy, math, shutil
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(__file__).resolve().parents[1]
LIB=Path('/Users/ktabb/Documents/3dAssets/Universal Animation Library 2[Standard]')
OUT=ROOT/'assets/models/character'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'warrior.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
original_objects=set(bpy.data.objects)
outputs=['SwordSwing','SwordSlash','AxeChop','AxeWhirl','SpearStab','SpearJab','BowShot','BowRapid','BowIdle','BowRun','BowCrouch','SpearIdle']
for t in list(rig.animation_data.nla_tracks):
 if t.name in outputs: rig.animation_data.nla_tracks.remove(t)
for a in list(bpy.data.actions):
 if a.name in outputs:bpy.data.actions.remove(a)
for t in rig.animation_data.nla_tracks:t.mute=True
idle=bpy.data.actions['Idle']
rig.animation_data.action=idle
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
base={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
bpy.ops.import_scene.gltf(filepath=str(LIB/'Unreal-Godot/UAL2_Standard.glb'))
source=next(o for o in bpy.data.objects if o.type=='ARMATURE' and o!=rig)
source_objects=set(bpy.data.objects)-original_objects
for t in list(source.animation_data.nla_tracks):source.animation_data.nla_tracks.remove(t)
source_actions={a.name:a for a in bpy.data.actions}
bones=sorted(rig.data.bones,key=lambda b:len(b.parent_recursive))

def frame(time):
 value=time*30
 bpy.context.scene.frame_set(math.floor(value),subframe=value%1)
 bpy.context.view_layer.update()

def action(name):
 a=bpy.data.actions.new(name);rig.animation_data.action=a
 return a

def keys(f):
 for b in rig.pose.bones:
  b.keyframe_insert('location',frame=f)
  b.keyframe_insert('rotation_quaternion',frame=f)
  b.keyframe_insert('scale',frame=f)

def finish(name,a,length):
 rig.animation_data.action=None
 t=rig.animation_data.nla_tracks.new();t.name=name
 strip=t.strips.new(name,0,a);strip.action_frame_end=length*30
 t.mute=True
 print('COMBAT_CLIP',name,length)

def retarget():
 for b in bones:
  sb=source.data.bones.get(b.name)
  if sb is None:continue
  sp=source.pose.bones[b.name];p=rig.pose.bones[b.name]
  rotation=sp.matrix.to_quaternion() @ sb.matrix_local.to_quaternion().inverted() @ b.matrix_local.to_quaternion()
  if b.parent:
   parent=rig.pose.bones[b.parent.name]
   head=parent.matrix @ b.parent.matrix_local.inverted() @ b.head_local
  else:head=b.head_local.copy()
  if b.name in ('root','pelvis'):
   basis=b.matrix_local.to_3x3()
   if b.parent:basis=parent.matrix.to_3x3() @ b.parent.matrix_local.to_3x3().inverted() @ basis
   head+=basis @ sp.location
  p.matrix=Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
  bpy.context.view_layer.update()

# Preserve each attack plus its recovery, then retime the fast cut separately
# from the wind-up and recovery so the visible swing lasts several frames.
# C supplies a spinning slash followed by an overhead strike; the latter is
# also isolated for the normal axe chop.
sequences={'SwordSwing':[('Sword_Regular_A',0,1),('Sword_Regular_A_Rec',0,1)],
 'SwordSlash':[('Sword_Regular_B',0,1),('Sword_Regular_B_Rec',0,1)],
 'AxeChop':[('Sword_Regular_C',.20,.95)],
 'AxeWhirl':[('Sword_Regular_C',0,1)]}
timing={
 'SwordSwing':[(0,0),(.32,.14),(.52,.18),(.68,.22),(1,1)],
 'SwordSlash':[(0,0),(.30,.12),(.52,.16),(.72,.20),(1,1)],
 'AxeChop':[(0,0),(.28,.10/.75),(.55,.14/.75),(.72,.20/.75),(1,1)],
 'AxeWhirl':[(0,0),(.30,.24),(.40,.30),(.62,.35),(.74,.42),(1,1)]}
def retimed(points,t):
 for (a,v),(b,w) in zip(points,points[1:]):
  if t<=b:return v+(w-v)*(t-a)/(b-a)
 return 1
for name,parts in sequences.items():
 a=action(name);segments=[];length=0
 for clip,start,end in parts:
  src=source_actions[clip];duration=src.frame_range.y/30
  span=duration*(end-start)
  segments.append((length,length+span,src,duration*start))
  length+=span
 for f in range(61):
  time=retimed(timing[name],f/60)*length
  seg=next((v for v in segments if time<=v[1]+1e-6),segments[-1])
  source.animation_data.action=seg[2]
  frame(seg[3]+time-seg[0]);retarget();keys(f)
 finish(name,a,2.0)

# Analytic two-bone IK, baked into ordinary skeleton keyframes. The pole sets
# the elbow plane; target distances are clamped to the actual imported arms.
def arm(side,target,pole):
 upper=rig.pose.bones['upperarm_'+side];lower=rig.pose.bones['lowerarm_'+side];hand=rig.pose.bones['hand_'+side]
 s=upper.matrix.translation.copy();target=Vector(target);pole=Vector(pole)
 l1=(lower.matrix.translation-s).length;l2=(hand.matrix.translation-lower.matrix.translation).length
 d=target-s;length=min(d.length,l1+l2-.001);direction=d.normalized();target=s+direction*length
 elbow_plane=pole-s;elbow_plane=(elbow_plane-direction*elbow_plane.dot(direction)).normalized()
 along=(l1*l1-l2*l2+length*length)/(2*length)
 elbow=s+direction*along+elbow_plane*math.sqrt(max(0,l1*l1-along*along))
 for bone,head,end in [(upper,s,elbow),(lower,elbow,target)]:
  q=bone.matrix.to_quaternion();y=q @ Vector((0,1,0))
  rotation=y.rotation_difference((end-head).normalized()) @ q
  bone.matrix=Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
  bpy.context.view_layer.update()
 # Keep the closed grip from the supplied sword pose, relative to the forearm.
 bpy.context.view_layer.update()

def sample(points,t):
 for i in range(len(points)-1):
  if t<=points[i+1][0]:
   a,v=points[i];b,w=points[i+1];u=max(0,min(1,(t-a)/(b-a)));u=u*u*(3-2*u)
   return v+(w-v)*u
 return points[-1][1]

def reset_pose():
 for b in rig.pose.bones:b.matrix_basis=base[b.name]
 bpy.context.view_layer.update()

def rotate_body(name,axis,angle):
 b=rig.pose.bones[name];m=b.matrix.copy();q=Quaternion(Vector(axis),angle) @ m.to_quaternion()
 b.matrix=Matrix.Translation(m.translation) @ q.to_matrix().to_4x4();bpy.context.view_layer.update()

def bow_grip(pitch=0.0,cant=0.0):
 hand=rig.pose.bones['hand_l'];origin=hand.matrix.translation.copy()
 rotation=Quaternion(Vector((1,0,0)),pitch) @ Quaternion(Vector((0,1,0)),cant) @ Quaternion(Vector((0,0,1)),math.pi)
 hand.matrix=Matrix.Translation(origin) @ rotation.to_matrix().to_4x4()
 mirror=Matrix.Diagonal(Vector((-1,1,1)))
 for finger in rig.pose.bones:
  if finger.name.endswith('_l') and any(finger.name.startswith(prefix) for prefix in ['thumb','index','middle','ring','pinky']):
   other=finger.name[:-1]+'r'
   if other in base:
    finger.rotation_quaternion=(mirror @ base[other].to_3x3() @ mirror).to_quaternion()
 bpy.context.view_layer.update()

# Preserve the supplied locomotion below the shoulders, but carry the bow in a
# relaxed left-hand grip beside the body rather than swinging it through the legs.
for name,source_name in [('BowRun','Walk'),('BowCrouch','Crouch')]:
 original=bpy.data.actions[source_name]
 length=original.frame_range.y/30
 poses=[]
 rig.animation_data.action=original
 for f in range(61):
  frame(length*f/60)
  poses.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
 a=action(name)
 for f,pose in enumerate(poses):
  frame(length*f/60)
  for b in rig.pose.bones:b.matrix_basis=pose[b.name]
  bpy.context.view_layer.update()
  shoulder=rig.pose.bones['upperarm_l'].matrix.translation.copy()
  crouched=name=='BowCrouch'
  arm('l',shoulder+Vector((.20,-.10,-.22 if crouched else -.34)),shoulder+Vector((.45,.08,-.12)))
  bow_grip(-.14+.035*math.sin(f/60*math.tau),.85 if crouched else .18)
  keys(length*30*f/60)
 finish(name,a,length)

for name in ['BowIdle','BowShot','BowRapid','SpearIdle','SpearStab','SpearJab']:
 a=action(name)
 for f in range(61):
  t=f/60;frame(f/30);reset_pose()
  if name.startswith('Bow'):
   rotate_body('spine_01',(0,0,1),-.45)
   rotate_body('neck_01',(0,0,1),.25)
   rotate_body('Head',(0,0,1),.2)
   # Left arm presents the bow; right hand nocks, draws to the cheek, releases.
   arm('l',(-.24,-.315,1.28),(.45,-.25,1.08))
   if name=='BowIdle': draw=0
   elif name=='BowShot':draw=sample([(0,0),(.12,0),(.5,1),(.62,1),(.68,1.12),(.85,0),(1,0)],t)
   else:draw=sample([(0,0),(.23,1),(.30,1),(.34,1.12),(.40,0),(.48,1),(.54,1),(.58,1.12),(.64,0),(.72,1),(.78,1),(.82,1.12),(.94,0),(1,0)],t)
   # Keep wrist and forearm on the right side of the face. The old +X target
   # crossed the neck; this .36m draw reaches the cheek with the elbow outside.
   arm('r',(-.24,-.15+draw*.36,1.28+draw*.06),(-.65,.30,1.38))
   bow_grip()
  else:
   special=name=='SpearJab'
   thrust=0 if name=='SpearIdle' else sample([(0,0),(.2,-.18),(.46 if not special else .52,1),(.57 if not special else .64,1),(.88,0),(1,0)],t)
   rotate_body('spine_01',(1,0,0),max(0,thrust)*(.18 if special else .08))
   arm('r',(-.28,.12-thrust*(.82 if special else .66),1.04),(-.7,.05,.85))
   arm('l',(.15,-.36+max(0,thrust)*.14,1.1),(.65,-.10,.95))
  keys(f)
 finish(name,a,2.0)
rig.animation_data.action=None
for t in rig.animation_data.nla_tracks:t.mute=False
for o in source_objects:
 if o.name in bpy.data.objects:bpy.data.objects.remove(o,do_unlink=True)
# Export only actions referenced by the character's NLA tracks.
used={s.action for t in rig.animation_data.nla_tracks for s in t.strips}
for a in list(bpy.data.actions):
 if a not in used:bpy.data.actions.remove(a)
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUT/'warrior.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
shutil.copy2(LIB/'License.txt',OUT/'Animation-Library-2-License.txt')
print('COMBAT_ANIMATIONS_READY')
