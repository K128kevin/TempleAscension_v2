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
outputs=['ShieldHit','ShieldHitHead','ShieldHitStagger','ShieldHitKnockdown','ArcherShot','ScutumRun','ScutumSwordIdle','SwordRun','SpearShieldIdle','SpearLunge','ShieldStab','SwordIdle','HitKnockdown','HitStagger','SwordSwing','SwordSlash','AxeChop','AxeWhirl','SpearStab','SpearJab','BowShot','BowRapid','BowIdle','BowRun','BowCrouch','SpearIdle']
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
NOCK=(-.24,-.15,1.28)
CHEEK=(-.24,.21,1.34)
bow_hand=[(0,(.12,-.26,.96)),(.3,(.1,-.28,1.0)),(.42,(-.04,-.34,1.18)),(.52,BOW_OUT),(.9,BOW_OUT),(1,(.12,-.26,.96))]
draw_hand=[(0,(-.2,-.1,.95)),(.14,(-.26,.05,1.45)),(.26,(-.2,.16,1.62)),(.32,(-.18,.12,1.6)),(.43,(-.06,-.3,1.2)),(.52,NOCK),(.56,NOCK),(.74,CHEEK),(.78,CHEEK),(.82,(-.3,.34,1.4)),(.9,(-.3,.3,1.3)),(1,(-.2,-.1,.95))]
draw_pole=[(0,(-.7,.2,.85)),(.2,(-.6,.3,1.9)),(.34,(-.6,.2,1.7)),(.45,(-.7,.3,1.2)),(.52,(-.65,.3,1.38)),(1,(-.7,.2,.85))]
side_on=[(0,0),(.3,-.12),(.46,-.45),(.86,-.45),(1,0)]
# The whole body shoots, as in the reference: the archer steps into a
# staggered stance (left foot forward toward the target, right foot back) and
# sinks into soft knees; the hips carry half of the side-on turn; the weight
# rises a touch on the quiver reach, settles back onto the rear leg through
# the draw and rocks forward on the release, before stepping back to idle.
# Leg IK keeps both feet planted while the hips move.
a=action('ArcherShot')
reset_pose()
planted={side:rig.pose.bones['foot_'+side].matrix.translation.copy() for side in 'lr'}
stance_keys=[(0,0),(.16,1),(.9,1),(1,0)]
settle_keys=[(0,0),(.5,0),(.74,.035),(.78,.035),(.84,-.02),(.95,0),(1,0)]
FRONT=Vector((.02,-.16,0));BACK=Vector((-.03,.14,0))
for f in range(61):
 t=f/60;reset_pose()
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
 arm('l',vsample(bow_hand,t)+hips,(.45,-.25,1.08))
 arm('r',vsample(draw_hand,t)+hips,vsample(draw_pole,t))
 bow_grip()
 keys(f)
finish('ArcherShot',a,2.0)

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
