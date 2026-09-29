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
outputs=['SwordRun','SpearShieldIdle','SpearLunge','ShieldStab','SwordIdle','HitKnockdown','HitStagger','SwordSwing','SwordSlash','AxeChop','AxeWhirl','SpearStab','SpearJab','BowShot','BowRapid','BowIdle','BowRun','BowCrouch','SpearIdle']
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
 'AxeWhirl':[('Sword_Regular_C',0,1)],
 'HitKnockdown':[('Hit_Knockback',0,1),('LayToIdle',0,1)]}
timing={
 'SwordSwing':[(0,0),(.32,.14),(.52,.18),(.68,.22),(1,1)],
 'SwordSlash':[(0,0),(.30,.12),(.52,.16),(.72,.20),(1,1)],
 'AxeChop':[(0,0),(.28,.10/.75),(.55,.14/.75),(.72,.20/.75),(1,1)],
 'AxeWhirl':[(0,0),(.30,.24),(.40,.30),(.62,.35),(.74,.42),(1,1)],
 'HitKnockdown':[(0,0),(1,1)]}
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

# The knockback's opening crumple, held briefly and blended back to the idle
# stance, gives heavy hits a stagger that stays on its feet.
knockback=source_actions['Hit_Knockback'];source.animation_data.action=knockback
a=action('HitStagger')
for f in range(61):
 t=f/60;frame(knockback.frame_range.y/30*.08*min(1,t/.3))
 reset_pose();bpy.context.view_layer.update();rest={b.name:b.matrix.copy() for b in rig.pose.bones}
 retarget()
 w=1-max(0,min(1,(t-.35)/.65));w=w*w*(3-2*w)
 for b in bones:
  p=rig.pose.bones[b.name];m=p.matrix;r0=rest[b.name]
  q=r0.to_quaternion().slerp(m.to_quaternion(),w)
  p.matrix=Matrix.Translation(r0.translation.lerp(m.translation,w)) @ q.to_matrix().to_4x4()
  bpy.context.view_layer.update()
 keys(f)
finish('HitStagger',a,2.0)

# Preserve the supplied locomotion below the shoulders, but carry the bow in a
# relaxed left-hand grip beside the body rather than swinging it through the legs.
for name,source_name in [('BowRun','Run'),('BowCrouch','Crouch')]:
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

# Sword-and-shield stance: the relaxed idle with the left forearm turned so its
# outer face, where the shield is strapped, faces out to the side rather than
# backward.
original=bpy.data.actions['Idle']
length=original.frame_range.y/30
rig.animation_data.action=original
poses=[]
for f in range(61):
 frame(length*f/60)
 poses.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
a=action('SwordIdle')
twist=Quaternion(Vector((0,1,0)),math.radians(60))
for f,pose in enumerate(poses):
 for b in rig.pose.bones:b.matrix_basis=pose[b.name]
 forearm=rig.pose.bones['lowerarm_l']
 forearm.rotation_quaternion=forearm.rotation_quaternion @ twist
 bpy.context.view_layer.update()
 keys(length*30*f/60)
finish('SwordIdle',a,length)

# Sword-and-shield run: the sprint's legs and body, with each arm eased most of
# the way toward the SwordIdle carry, so the sword stays low and forward instead
# of swinging back through the head, and the shield stays at his side.
idle_arms={}
rig.animation_data.action=bpy.data.actions['SwordIdle'];frame(0)
for b in rig.pose.bones:idle_arms[b.name]=b.matrix_basis.copy()
ARM_CARRY={'_r':.75,'_l':.8}
def carried(name):
 if not name.startswith(('clavicle','upperarm','lowerarm','hand')):return 0.0
 return ARM_CARRY.get(name[-2:],0.0)
run=bpy.data.actions['Run']
length=run.frame_range.y/30
rig.animation_data.action=run
poses=[]
for f in range(61):
 frame(length*f/60)
 poses.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
a=action('SwordRun')
for f,pose in enumerate(poses):
 for b in rig.pose.bones:
  m=pose[b.name];w=carried(b.name)
  if w>0:
   l1,r1,s1=m.decompose();l2,r2,s2=idle_arms[b.name].decompose()
   m=Matrix.LocRotScale(l1.lerp(l2,w),r1.slerp(r2,w),s1)
  b.matrix_basis=m
 bpy.context.view_layer.update()
 keys(length*30*f/60)
finish('SwordRun',a,length)

# Two-bone leg IK; the foot keeps its planted orientation.
def leg(side,target,pole):
 thigh=rig.pose.bones['thigh_'+side];calf=rig.pose.bones['calf_'+side];foot=rig.pose.bones['foot_'+side]
 keep=foot.matrix.to_quaternion()
 s=thigh.matrix.translation.copy();target=Vector(target);pole=Vector(pole)
 l1=(calf.matrix.translation-s).length;l2=(foot.matrix.translation-calf.matrix.translation).length
 d=target-s;length=min(d.length,l1+l2-.001);direction=d.normalized();target=s+direction*length
 bend=pole-s;bend=(bend-direction*bend.dot(direction)).normalized()
 along=(l1*l1-l2*l2+length*length)/(2*length)
 knee=s+direction*along+bend*math.sqrt(max(0,l1*l1-along*along))
 for bone,head,end in [(thigh,s,knee),(calf,knee,target)]:
  q=bone.matrix.to_quaternion();y=q @ Vector((0,1,0))
  bone.matrix=Matrix.Translation(head) @ (y.rotation_difference((end-head).normalized()) @ q).to_matrix().to_4x4()
  bpy.context.view_layer.update()
 foot.matrix=Matrix.Translation(foot.matrix.translation) @ keep.to_matrix().to_4x4()
 bpy.context.view_layer.update()

def twist(name,angle):
 # Turn a bone about its own length, e.g. to face a forearm-mounted shield.
 b=rig.pose.bones[name];m=b.matrix.copy();axis=(m.to_quaternion() @ Vector((0,1,0))).normalized()
 b.matrix=Matrix.Translation(m.translation) @ (Quaternion(axis,angle) @ m.to_quaternion()).to_matrix().to_4x4()
 bpy.context.view_layer.update()

SHIELD_TWIST=math.radians(60)
def shield_arm(forward=0.0,turn=0.0):
 # Left forearm raised across the front, carrying the gladiator's scutum;
 # `turn` swings it with the upper body.
 spin=Matrix.Rotation(turn,3,'Z')
 arm('l',spin @ Vector((.24,-.32+forward,1.06)),spin @ Vector((.62,.12,.8)))
 twist('lowerarm_l',SHIELD_TWIST)

# Gladiator stance: the relaxed idle with the spear held level at the hip and
# the shield carried in front.
original=bpy.data.actions['Idle']
length=original.frame_range.y/30
rig.animation_data.action=original
poses=[]
for f in range(61):
 frame(length*f/60)
 poses.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
a=action('SpearShieldIdle')
for f,pose in enumerate(poses):
 for b in rig.pose.bones:b.matrix_basis=pose[b.name]
 bpy.context.view_layer.update()
 arm('r',(-.30,-.06,1.0),(-.7,.2,.85))
 shield_arm()
 keys(length*30*f/60)
finish('SpearShieldIdle',a,length)

# One firm spear thrust: draw back, then drive forward while the left foot
# steps ahead and the hips drop into the lunge; the right foot stays planted.
a=action('SpearLunge')
reset_pose()
planted={side:rig.pose.bones['foot_'+side].matrix.translation.copy() for side in 'lr'}
for f in range(61):
 t=f/60;reset_pose()
 thrust=sample([(0,0),(.14,-.3),(.34,-.45),(.52,1),(.66,1),(.9,0),(1,0)],t)
 step=sample([(0,0),(.34,0),(.5,1),(.7,1),(.92,0),(1,0)],t)
 lift=0.0
 for a0,a1 in [(.34,.5),(.7,.92)]:
  if a0<t<a1:u=(t-a0)/(a1-a0);lift=.09*4*u*(1-u)
 shift=Vector((0,-.24*step,-.07*step))
 pelvis=rig.pose.bones['pelvis'];m=pelvis.matrix.copy()
 pelvis.matrix=Matrix.Translation(m.translation+shift) @ m.to_quaternion().to_matrix().to_4x4()
 bpy.context.view_layer.update()
 leg('l',planted['l']+Vector((0,-.46*step,lift)),planted['l']+Vector((0,-.9,.5)))
 leg('r',planted['r'],planted['r']+Vector((0,-.9,.5)))
 # The upper body winds back, then turns into the thrust: the spear shoulder
 # drives forward (+Z turn) as he leans in.
 turn=.22*thrust
 rotate_body('spine_01',(0,0,1),turn)
 rotate_body('spine_02',(0,0,1),turn)
 rotate_body('spine_01',(1,0,0),.14*max(0,thrust))
 arm('r',(-.26,.10-thrust*.72+shift.y,1.02+max(0,thrust)*.12),(-.7,.2,.85))
 shield_arm(shift.y,turn*1.4)
 keys(f)
finish('SpearLunge',a,2.0)

# The centurion's driving thrust: a deep coil, then a long step with the left
# foot as the hips drive forward and the whole upper body turns and leans into
# the spear, the tower shield kept up in front. The right foot stays planted.
a=action('ShieldStab')
reset_pose()
planted={side:rig.pose.bones['foot_'+side].matrix.translation.copy() for side in 'lr'}
for f in range(61):
 t=f/60;reset_pose()
 thrust=sample([(0,0),(.22,-.4),(.36,-.5),(.5,1),(.62,1),(.9,0),(1,0)],t)
 step=sample([(0,0),(.36,0),(.5,1),(.68,1),(.92,0),(1,0)],t)
 lift=0.0
 for a0,a1 in [(.36,.5),(.68,.92)]:
  if a0<t<a1:u=(t-a0)/(a1-a0);lift=.1*4*u*(1-u)
 shift=Vector((0,-.34*step,-.1*step))
 pelvis=rig.pose.bones['pelvis'];m=pelvis.matrix.copy()
 pelvis.matrix=Matrix.Translation(m.translation+shift) @ m.to_quaternion().to_matrix().to_4x4()
 bpy.context.view_layer.update()
 leg('l',planted['l']+Vector((0,-.62*step,lift)),planted['l']+Vector((0,-.9,.5)))
 leg('r',planted['r'],planted['r']+Vector((0,-.9,.5)))
 turn=.26*thrust
 rotate_body('spine_01',(0,0,1),turn)
 rotate_body('spine_02',(0,0,1),turn)
 rotate_body('spine_01',(1,0,0),.2*max(0,thrust)-.05*max(0,-thrust))
 arm('r',(-.24,.14-thrust*.95+shift.y,1.04+max(0,thrust)*.14),(-.7,.2,.85))
 shield_arm(shift.y,turn*1.3)
 keys(f)
finish('ShieldStab',a,2.0)

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
