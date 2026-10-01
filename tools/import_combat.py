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
outputs=['OracleCast','ShieldHit','ShieldHitHead','ShieldHitStagger','ShieldHitKnockdown','ArcherShot','ScutumRun','ScutumSwordIdle','SwordRun','SpearShieldIdle','SpearLunge','ShieldStab','SwordIdle','HitKnockdown','HitStagger','SwordSwing','SwordSlash','AxeChop','AxeWhirl','SpearStab','SpearJab','BowShot','BowRapid','BowIdle','BowRun','BowCrouch','SpearIdle','RangerIdle','RangerRun','RangerCrouch','WizardIdle','WizardRun','WizardCrouch']
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

# The draw hand's last solve (draw_to), cleared for each new clip.
last_draw=[None]
def action(name):
 last_draw[0]=None
 a=bpy.data.actions.new(name);rig.animation_data.action=a
 return a

def keys(f):
 for b in rig.pose.bones:
  b.keyframe_insert('location',frame=f)
  b.keyframe_insert('rotation_quaternion',frame=f)
  b.keyframe_insert('scale',frame=f)

def finish(name,a,length,exact=False):
 rig.animation_data.action=None
 t=rig.animation_data.nla_tracks.new();t.name=name
 strip=t.strips.new(name,0,a);strip.action_frame_end=length*30
 # The glTF export samples one frame past a strip's end; `exact` clips drop
 # it, so in the game a phase lands on the same pose as in the bake.
 if exact: strip.action_frame_end=length*30-1
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
 # The elbow is a hinge: the forearm bends about the normal of the arm's
 # plane. Its shortest swing from the upper arm's line is ambiguous when the
 # elbow folds nearly shut (a draw hand past the ear), and flipped its twist.
 hinge=direction.cross(elbow_plane).normalized()
 for bone,head,end in [(upper,s,elbow),(lower,elbow,target)]:
  q=bone.matrix.to_quaternion();y=q @ Vector((0,1,0));new=(end-head).normalized()
  if bone==lower and hinge.length>.5:
   q=Quaternion(hinge,math.atan2(y.cross(new).dot(hinge),y.dot(new))) @ q
   y=q @ Vector((0,1,0))
  rotation=y.rotation_difference(new) @ q
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

def bow_fist():
 # The left fingers close as the right hand's supplied grip does, mirrored.
 mirror=Matrix.Diagonal(Vector((-1,1,1)))
 for finger in rig.pose.bones:
  if finger.name.endswith('_l') and any(finger.name.startswith(prefix) for prefix in ['thumb','index','middle','ring','pinky']):
   other=finger.name[:-1]+'r'
   if other in base:
    finger.rotation_quaternion=(mirror @ base[other].to_3x3() @ mirror).to_quaternion()
 bpy.context.view_layer.update()

def bow_carry_grip(pitch=0.0,cant=0.0):
 # Carrying the bow low: the wrist turns the bow up along the body.
 hand=rig.pose.bones['hand_l'];origin=hand.matrix.translation.copy()
 rotation=Quaternion(Vector((1,0,0)),pitch) @ Quaternion(Vector((0,1,0)),cant) @ Quaternion(Vector((0,0,1)),math.pi)
 hand.matrix=Matrix.Translation(origin) @ rotation.to_matrix().to_4x4()
 bow_fist()

def bow_grip():
 # Holding the bow out: the wrist straight in line with the forearm, turned
 # about it until the fist's knuckles (pinky to index) stand upright, so the
 # fingers wrap round the upright grip (placed there in scripts/visual.gd).
 hand=rig.pose.bones['hand_l'];lower=rig.pose.bones['lowerarm_l']
 origin=hand.matrix.translation.copy();turn=lower.matrix.to_quaternion()
 hand.matrix=Matrix.Translation(origin) @ turn.to_matrix().to_4x4()
 bow_fist()
 axis=(turn @ Vector((0,1,0))).normalized()
 knuckles=rig.pose.bones['index_01_l'].head-rig.pose.bones['pinky_01_l'].head
 knuckles=(knuckles-axis*knuckles.dot(axis)).normalized()
 up=Vector((0,0,1));up=(up-axis*up.dot(axis)).normalized()
 roll=math.atan2(axis.dot(knuckles.cross(up)),knuckles.dot(up))
 hand.matrix=Matrix.Translation(origin) @ (Quaternion(axis,roll) @ turn).to_matrix().to_4x4()
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
 # Blend rotations only; each bone hangs rigidly from its blended parent so no
 # limb stretches mid-blend. Only the root and hips blend their position.
 target={b.name:rig.pose.bones[b.name].matrix.copy() for b in bones}
 for b in bones:
  p=rig.pose.bones[b.name];m=target[b.name];r0=rest[b.name]
  q=r0.to_quaternion().slerp(m.to_quaternion(),w)
  if b.parent and b.name not in ('root','pelvis'):
   head=rig.pose.bones[b.parent.name].matrix @ b.parent.matrix_local.inverted() @ b.head_local
  else:head=r0.translation.lerp(m.translation,w)
  p.matrix=Matrix.Translation(head) @ q.to_matrix().to_4x4()
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
  bow_carry_grip(-.14+.035*math.sin(f/60*math.tau),.85 if crouched else .18)
  keys(length*30*f/60)
 finish(name,a,length)

# The ranger's own idle, run and crouch: the supplied clips (the warrior's
# stance and stride) with the left hand closed round the bow he carries in it,
# the hand he shoots from, so it never changes hands.
# The wizard's own idle, run and crouch: the supplied clips with his right
# hand raised before his chest, gripping his staff near its top like a
# walking stick (scripts/visual.gd stands the staff upright beneath it).
for name,source_name in [('WizardIdle','Idle'),('WizardRun','Run'),('WizardCrouch','Crouch')]:
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
  shoulder=rig.pose.bones['upperarm_r'].matrix.translation.copy()
  bob=.02*math.sin(f/60*math.tau*2) if name=='WizardRun' else 0.0
  arm('r',shoulder+Vector((-.2,-.2,-.2+bob)),shoulder+Vector((-.45,.15,-.15)))
  keys(length*30*f/60)
 finish(name,a,length)

# The idle's wrist and forearm, which the run's bow arm follows so the
# carried bow swings with the arm and never across the body.
rig.animation_data.action=bpy.data.actions['Idle']; frame(0)
idle_hand=rig.pose.bones['hand_l'].matrix.to_quaternion()
idle_forearm=(rig.pose.bones['hand_l'].head-rig.pose.bones['lowerarm_l'].head).normalized()
for name,source_name in [('RangerIdle','Idle'),('RangerRun','Run'),('RangerCrouch','Crouch')]:
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
  if name=='RangerRun':
   # Running, the bow arm swings low beside the hip, forward and back with
   # the stride, rather than pumping the bow up across the chest.
   shoulder=rig.pose.bones['upperarm_l'].matrix.translation.copy()
   swing=math.sin(f/60*math.tau)
   arm('l',shoulder+Vector((.17,-.05-.13*swing,-.43)),shoulder+Vector((.45,.15,-.12)))
   hand=rig.pose.bones['hand_l']
   # The idle's wrist, swung only as far as the forearm swings (never turned
   # about it), so the bow keeps lying forward and back beside the leg.
   forearm=(hand.head-rig.pose.bones['lowerarm_l'].head).normalized()
   hand.matrix=Matrix.Translation(hand.matrix.translation) @ (idle_forearm.rotation_difference(forearm) @ idle_hand).to_matrix().to_4x4()
   bpy.context.view_layer.update()
  bow_fist()
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

# Hit reactions for shield bearers: the same reactions with the left forearm
# kept turned 60° outward, as in the shield stances, so a hit does not flip the
# strapped shield round and back.
for source_name in ['Hit','HitHead','HitStagger','HitKnockdown']:
 original=bpy.data.actions[source_name]
 length=original.frame_range.y/30
 rig.animation_data.action=original
 poses=[]
 for f in range(61):
  frame(length*f/60)
  poses.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
 a=action('Shield'+source_name)
 for f,pose in enumerate(poses):
  for b in rig.pose.bones:b.matrix_basis=pose[b.name]
  forearm=rig.pose.bones['lowerarm_l']
  forearm.rotation_quaternion=forearm.rotation_quaternion @ twist
  bpy.context.view_layer.update()
  keys(length*30*f/60)
 finish('Shield'+source_name,a,length)

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

# Shield bearers (gladiator, centurion): the left arm holds the scutum exactly
# as in SpearShieldIdle, so the shield stays upright. The gladiator's idle
# takes SwordIdle's sword arm; their run keeps the sprint's legs and body with
# the shield arm held and the right arm eased toward the low sword carry.
def arm_side(name):
 if name.startswith(('clavicle','upperarm','lowerarm','hand','thumb','index','middle','ring','pinky')):return name[-1]
 return ''
def clip_poses(name,count=61):
 act=bpy.data.actions[name];span=act.frame_range.y/30;rig.animation_data.action=act;out=[]
 for f in range(count):
  frame(span*f/(count-1));out.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
 return out,span
def blend(m1,m2,w):
 l1,r1,s1=m1.decompose();l2,r2,s2=m2.decompose()
 return Matrix.LocRotScale(l1.lerp(l2,w),r1.slerp(r2,w),s1)
shield_pose,_=clip_poses('SpearShieldIdle')
sword_pose,length=clip_poses('SwordIdle')
a=action('ScutumSwordIdle')
for f in range(61):
 for b in rig.pose.bones:
  b.matrix_basis=shield_pose[f][b.name] if arm_side(b.name)=='l' else sword_pose[f][b.name]
 bpy.context.view_layer.update()
 keys(length*30*f/60)
finish('ScutumSwordIdle',a,length)
run_pose,length=clip_poses('Run')
a=action('ScutumRun')
for f in range(61):
 for b in rig.pose.bones:
  side=arm_side(b.name);m=run_pose[f][b.name]
  if side=='r':m=blend(m,sword_pose[0][b.name],.75)
  b.matrix_basis=m
 bpy.context.view_layer.update()
 # Reach the shield arm to its stance position after the run's lean, so the
 # shield stays upright rather than tipping with the torso.
 shield_arm()
 keys(length*30*f/60)
finish('ScutumRun',a,length)

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
 # The torso turns about the spine: coiling, the right side and spear rotate
 # back as the left shoulder and shield swing forward; striking, the right
 # side drives forward and the left side pulls back with the shield arm.
 # Positive turn brings the right shoulder forward.
 turn=.52*thrust if thrust>0 else 1.1*thrust
 for spine,share in [('spine_01',.35),('spine_02',.35),('spine_03',.3)]:
  rotate_body(spine,(0,0,1),turn*share)
 rotate_body('spine_01',(1,0,0),.2*max(0,thrust)-.05*max(0,-thrust))
 arm('r',(-.24,.14-thrust*.95+shift.y,1.04+max(0,thrust)*.14),(-.7,.2,.85))
 # The shield arm follows the turn, and draws back further on the strike.
 shield_arm(shift.y+.1*max(0,thrust),turn*.9)
 keys(f)
finish('ShieldStab',a,2.0)

# The statue archer's shot, modeled on Quaternius's Bow_Notch then Bow_Shoot
# (UAL2 Source edition, studied in the online viewer; authored here, not
# copied): from a relaxed stance the draw hand reaches over the right shoulder
# to the quiver, brings the arrow down to nock it at the bow in front of the
# chest as the body turns side-on, then the bow arm extends at shoulder height,
# the string is drawn to the cheek, held, and released with the draw hand
# flicking back, before easing back to the stance. Release is at 0.78.
def vsample(points,t):
 for i in range(len(points)-1):
  if t<=points[i+1][0]:
   a,v=points[i];b,w=points[i+1];u=max(0,min(1,(t-a)/(b-a)));u=u*u*(3-2*u)
   return Vector(v).lerp(Vector(w),u)
 return Vector(points[-1][1])
BOW_OUT=(-.24,-.315,1.28)
# Firing, as in the reference: the chest turns side-on to the target
# (AIM_TURN), the bow arm is locked straight out toward it at shoulder height
# and the string is drawn to the jaw, BOW_FULL_DRAW times the bow's own .36m
# draw (scripts/visual.gd shows the string that deep).
AIM_TURN=-1.0
# Angled a little to the right, so the string line runs beside the right
# cheek rather than through the face.
AIM_DIRECTION=Vector((-.3,-1,.1)).normalized()
BOW_FULL_DRAW=1.2
def aim_bow(ready,raised,shift=Vector()):
 # The bow arm from its ready place to straight out at the target.
 shoulder=rig.pose.bones['upperarm_l'].head.copy()
 out=shoulder+AIM_DIRECTION*.9
 arm('l',Vector(ready).lerp(out,raised)+shift*(1-raised),shoulder+Vector((.35,-.2,-.35)))
 bow_grip()
def string_point(draw):
 # Where the string's nocking point is, drawn `draw` of the way, with the bow
 # placed in the left fist exactly as the game places it (scripts/visual.gd:
 # the grip in the fist, the stave along the knuckles, the front facing the
 # way the archer faces).
 b=rig.pose.bones
 ring=[b[n+'_l'].head for n in ('middle_01','middle_02','middle_03','index_02','ring_02')]
 fist=sum(ring,Vector())/len(ring)
 up=(b['index_01_l'].head-b['pinky_01_l'].head).normalized()
 facing=Vector((0,-1,0));front=(facing-up*facing.dot(up)).normalized()
 return fist-front*(.23+.36*draw)+up*(-.013+.06*draw)
def draw_pole_for(raised,ready_pole):
 # The drawing elbow is aimed up, back and out behind the shoulder.
 shoulder=rig.pose.bones['upperarm_r'].head
 return Vector(ready_pole).lerp(shoulder+Vector((-.3,.35,.3)),raised)
def draw_fingers():
 b=rig.pose.bones
 return (b['index_02_r'].head+b['middle_02_r'].head)/2
def draw_to(point,pole):
 # Folded tight, the forearm swings a lot for a small move of the wrist, so
 # the correction takes small steps and the closest result is kept. Each
 # solve starts from the last frame's, keeping the arm on one smooth branch.
 point=Vector(point)
 starts=[point.copy()]
 if last_draw[0] is not None: starts.insert(0,last_draw[0][0]+(point-last_draw[0][1]))
 best=(9.0,point)
 for start in starts:
  target=start.copy()
  for _ in range(40):
   arm('r',target,pole)
   miss=point-draw_fingers()
   if miss.length<best[0]: best=(miss.length,target.copy())
   if miss.length<.002: break
   target=target+miss*.35
  if best[0]<.005: break
 arm('r',best[1],pole)
 last_draw[0]=(best[1].copy(),point.copy())
 return best[1]
# Wrist targets near the string, for the archer's path to and from it.
NOCK=(-.426,.012,1.365)
CHEEK=(-.341,.24,1.515)
# After the release the hands return to the archer's idle, bow up and ready
# (BowIdle's own targets), not to the rest pose.
bow_hand=[(0,(.12,-.26,.96)),(.3,(.1,-.28,1.0)),(.42,(-.04,-.34,1.18)),(.52,BOW_OUT),(1,BOW_OUT)]
draw_hand=[(0,(-.2,-.1,.95)),(.14,(-.26,.05,1.45)),(.26,(-.2,.16,1.62)),(.32,(-.18,.12,1.6)),(.43,(-.06,-.3,1.2)),(.52,NOCK),(.56,NOCK),(.74,CHEEK),(.78,CHEEK),(.82,(-.5,.33,1.55)),(.9,(-.54,.12,1.44)),(1,NOCK)]
# While the draw hand is folded in by the shoulder (nock, draw, release and
# return) the elbow is aimed up and back, above the arrow; the ready pose's
# pole beside the shoulder lay almost along the hand's direction there, so
# the arm's plane swung wildly and the forearm flipped down and back.
DRAW_POLE=(-.49,.42,1.8)
READY_POLE=(-.65,.3,1.38)
draw_pole=[(0,(-.7,.2,.85)),(.2,(-.6,.3,1.9)),(.34,(-.6,.2,1.7)),(.45,(-.62,.36,1.5)),(.52,DRAW_POLE),(.9,DRAW_POLE),(1,READY_POLE)]
side_on=[(0,0),(.3,-.12),(.46,-.45),(1,-.45)]
# The Oracle's fireball cast: the right hand holds the staff at its side while
# the left hand weaves slow circles before the chest (the flame forms in the
# staff's crown); then the staff is drawn up and back and swung out in front
# as the fireball leaves it, at 0.8. The staff's own angle is set in the game
# (scripts/visual.gd), following the hand.
staff_hand=[(0,(-.3,-.12,1.02)),(.1,(-.3,-.14,1.06)),(.66,(-.3,-.14,1.1)),(.76,(-.26,.06,1.42)),(.8,(-.18,-.46,1.3)),(.86,(-.2,-.4,1.18)),(1,(-.3,-.12,1.02))]
staff_pole=[(0,(-.7,.2,.85)),(.66,(-.7,.2,.85)),(.76,(-.7,.3,1.2)),(.8,(-.7,-.1,1.0)),(1,(-.7,.2,.85))]
a=action('OracleCast')
for f in range(61):
 t=f/60;reset_pose()
 weave=sample([(0,0),(.12,1),(.64,1),(.72,0),(1,0)],t)
 angle=t/.66*3.0*math.pi
 circle=Vector((math.cos(angle)*.17,-.36+math.sin(angle)*.05,1.28+math.sin(angle)*.15))
 rest=Vector((.26,-.06,.98))
 left=rest.lerp(circle,weave)
 arm('l',left,(.6,.1,.95))
 sway=math.sin(t/.66*2*math.pi)*.05*weave
 swing=sample([(0,0),(.66,0),(.76,-.35),(.8,.4),(.88,.2),(1,0)],t)
 rotate_body('spine_01',(0,0,1),sway+swing*.5)
 rotate_body('spine_01',(1,0,0),.12*max(0,swing)-.06*max(0,-swing))
 bob=Vector((0,-.05*max(0,swing),0))
 arm('r',vsample(staff_hand,t)+bob,vsample(staff_pole,t))
 keys(f)
finish('OracleCast',a,2.0)


# The shots move the draw hand fast, so they are sampled twice as finely (a
# four-second clip, always played over the shot's own duration); between
# coarser keys the blended fingers drifted off the string.
SHOT_SAMPLES=120
for name in ['BowIdle','BowShot','BowRapid','SpearIdle','SpearStab','SpearJab']:
 a=action(name)
 samples=SHOT_SAMPLES if name in ('BowShot','BowRapid') else 60
 for f in range(samples+1):
  t=f/samples;frame(f/30 if samples==60 else 0);reset_pose()
  if name.startswith('Bow'):
   # Ready (BowIdle), the bow is presented before the chest; shooting, the
   # archer turns side-on and holds it straight out at the target.
   # Straight out, the resting string is beyond the drawing hand's reach, so
   # each arrow is nocked with the bow brought in a little and the bow arm
   # locks out as the string comes back.
   if name=='BowShot':raised=sample([(0,0),(.14,.3),(.42,1),(.86,1),(1,0)],t)
   elif name=='BowRapid':raised=sample([(0,0),(.08,.3),(.2,1),(.36,1),(.44,.3),(.47,.3),(.52,1),(.6,1),(.68,.3),(.71,.3),(.76,1),(.9,1),(1,0)],t)
   else:raised=0
   turn=-.45+(AIM_TURN+.45)*raised
   rotate_body('spine_01',(0,0,1),turn)
   rotate_body('neck_01',(0,0,1),-turn*.55)
   rotate_body('Head',(0,0,1),-turn*.45)
   aim_bow(BOW_OUT,raised)
   # How far back the drawing hand is. After each release the string snaps
   # forward (scripts/visual.gd) but the hand stays back by the jaw, following
   # through, until the bow comes in for the next arrow.
   if name=='BowIdle': draw=0
   elif name=='BowShot':draw=sample([(0,0),(.14,0),(.5,1),(.62,1),(.68,1.08),(.86,1.08),(1,0)],t)
   else:draw=sample([(0,0),(.08,0),(.23,1),(.30,1),(.34,1.08),(.38,1.08),(.46,0),(.54,1),(.58,1.08),(.62,1.08),(.7,0),(.78,1),(.82,1.08),(.88,1.08),(1,0)],t)
   # The drawing fingers stay on the string: from the nock back to the jaw.
   draw_to(string_point(draw*BOW_FULL_DRAW),draw_pole_for(raised,READY_POLE))
  else:
   special=name=='SpearJab'
   thrust=0 if name=='SpearIdle' else sample([(0,0),(.2,-.18),(.46 if not special else .52,1),(.57 if not special else .64,1),(.88,0),(1,0)],t)
   rotate_body('spine_01',(1,0,0),max(0,thrust)*(.18 if special else .08))
   arm('r',(-.28,.12-thrust*(.82 if special else .66),1.04),(-.7,.05,.85))
   arm('l',(.15,-.36+max(0,thrust)*.14,1.1),(.65,-.10,.95))
  keys(f)
 finish(name,a,samples/30,exact=samples==SHOT_SAMPLES)
# The whole body shoots, as in the reference: the archer steps into a
# staggered stance (left foot forward toward the target, right foot back) and
# sinks into soft knees; the hips carry half of the side-on turn; the weight
# rises a touch on the quiver reach, settles back onto the rear leg through
# the draw and rocks forward on the release, before stepping back to idle.
# Leg IK keeps both feet planted while the hips move.
side_on=[(0,0),(.3,-.12),(.46,-.45),(.56,AIM_TURN),(.84,AIM_TURN),(.95,-.45),(1,-.45)]
bow_ready=clip_poses('BowIdle',2)[0][0]
a=action('ArcherShot')
reset_pose()
planted={side:rig.pose.bones['foot_'+side].matrix.translation.copy() for side in 'lr'}
stance_keys=[(0,0),(.16,1),(.9,1),(1,0)]
settle_keys=[(0,0),(.5,0),(.74,.035),(.78,.035),(.84,-.02),(.95,0),(1,0)]
FRONT=Vector((.02,-.16,0));BACK=Vector((-.03,.14,0))
for f in range(SHOT_SAMPLES+1):
 t=f/SHOT_SAMPLES;reset_pose()
 stance=sample(stance_keys,t)
 turn=sample(side_on,t)
 reach=max(0,1-abs(t-.26)/.14)
 # Hips: sink into the stance, lift on the reach, shift back and forward.
 hips=Vector((0,sample(settle_keys,t),-.045*stance+.015*reach))
 pelvis=rig.pose.bones['pelvis'];m=pelvis.matrix.copy()
 pelvis.matrix=Matrix.Translation(m.translation+hips) @ m.to_quaternion().to_matrix().to_4x4()
 bpy.context.view_layer.update()
 rotate_body('pelvis',(0,0,1),turn*.5)
 # Feet: each lifts a little as it steps into and out of the stance.
 step=0.0
 for a0,a1 in [(0,.16),(.9,1)]:
  if a0<t<a1:u=(t-a0)/(a1-a0);step=.05*4*u*(1-u)
 leg('l',planted['l']+FRONT*stance+Vector((0,0,step)),planted['l']+Vector((.1,-.9,.5)))
 leg('r',planted['r']+BACK*stance+Vector((0,0,step*.6)),planted['r']+Vector((-.1,-.9,.5)))
 rotate_body('spine_01',(0,0,1),turn*.5)
 rotate_body('neck_01',(0,0,1),-turn*.55)
 rotate_body('Head',(0,0,1),-turn*.45)
 # The quiver reach lifts the chest a little and tips the head away.
 rotate_body('spine_02',(1,0,0),-.12*reach)
 # The bow comes up from the quiver reach and is held straight out at the
 # target through the nock, draw and release.
 raised=sample([(0,0),(.46,0),(.58,.15),(.76,1),(.84,1),(.94,0),(1,0)],t)
 aim_bow(vsample(bow_hand,t)+hips,raised)
 # On the string from the nock to the release, by the fingers; to and from
 # it (the quiver reach, the follow-through) along the wrist path.
 on_string=sample([(0,0),(.46,0),(.52,1),(.78,1),(.8,0),(1,0)],t)
 pole=draw_pole_for(raised,vsample(draw_pole,t))
 path=vsample(draw_hand,t)+hips
 if on_string>0:
  pull=sample([(0,0),(.56,0),(.74,1),(1,1)],t)
  path=path.lerp(draw_to(string_point(pull*BOW_FULL_DRAW),pole),on_string)
 arm('r',path,pole)
 bow_grip()
 # The archer's idle holds the bow up, ready: the shot starts from it and
 # settles back into it, so the arms do not snap between the two.
 settle=sample([(0,1),(.1,0),(.9,0),(1,1)],t)
 if settle>0:
  for b in rig.pose.bones: b.matrix_basis=blend(b.matrix_basis,bow_ready[b.name],settle)
  bpy.context.view_layer.update()
 keys(f)
finish('ArcherShot',a,SHOT_SAMPLES/30,exact=True)
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
