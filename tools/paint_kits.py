"""Paint the heroes' detailed kits, after their concept art.

Run with Blender --background --python tools/paint_kits.py after
outfit_hero.py has written warrior.glb. The hero body's rest-pose position
and limb are baked into its own UVs, and every texel is then painted from its
place on the body, so patterns run continuously across UV seams:

  - knee-high boots of dark reddish-brown leather: grain, scuffed and paler
    wear, creases at the ankle, a dark sole and welt, a turned-down cuff, two
    wrapped straps with steel buckles, and stitched seams;
  - leather knee guards over dark wool trousers;
  - a tattered tunic of dark green wool, worked in a fine diamond pattern,
    hanging to mid-thigh over the trousers;
  - a broad belt with a buckle and holes, and two crossed straps over the
    chest and back, each with stitched edges;
  - long leather bracers laced across the top, over linen sleeves;
  - fingerless leather gloves;
  - the face and skin from the character's own texture, with stubble.

That is the ranger. The warrior: a steel scale cuirass with lion medallions,
a baldric, a broad studded belt with a lion boss and a key-pattern band,
leather pteruges at the shoulders, a cloth wrap on the upper arm, a steel
manica on the sword arm and leather wraps on the other, a tattered red-grey
underskirt, and strapped
sandals over the bare feet (his shins bare). The wizard: wrapped leather bracers, dark
trousers, worn leather boots with ankle straps and buckles, and a creased
leather sash knotted at the front.

Three maps are written to assets/textures per hero: hero_kit_<hero>.png
(colour), hero_kit_<hero>_normal.png (tangent-space, from the painted relief)
and hero_kit_<hero>_rough.png. No geometry is changed. (hero_kit.png, from
tools/paint_hero.py, stays: the gladiator statue's scales are cut from it.)
"""
from pathlib import Path
import math
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SKIN = ROOT/'source_art/universal_stage/T_Superhero_Male_Dark.png'
# The character's own relief (muscle, knuckles, the face's features) and the
# sheen of its skin, kept wherever the kit leaves the skin bare.
SKIN_NORMAL = ROOT/'source_art/universal_stage/T_Superhero_Male_Normal.png'
SKIN_ROUGH = ROOT/'source_art/universal_stage/T_Superhero_Male_Roughness.png'
OUT = ROOT/'assets/textures'
SIZE = 2048
RIGHT_SIGN = 1.0
import sys
# `--only warrior` (etc.) paints just that hero's kit.
ONLY = [sys.argv[sys.argv.index('--only')+1]] if '--only' in sys.argv else None

# Limb classes, from each face's bones.
HEAD, HAND, KNUCKLE, FINGER, FOREARM, UPPERARM, TORSO, THIGH, CALF, FOOT = range(1,11)
def limb(bone):
    if bone.startswith(('Head','neck')): return HEAD
    if bone.startswith('hand'): return HAND
    if bone.startswith(('thumb','index','middle','ring','pinky')):
        return KNUCKLE if '_01' in bone else FINGER
    if bone.startswith('lowerarm'): return FOREARM
    if bone.startswith(('upperarm','clavicle')): return UPPERARM
    if bone.startswith('thigh'): return THIGH
    if bone.startswith('calf'): return CALF
    if bone.startswith(('foot','ball')): return FOOT
    return TORSO


# --- Baking the body's place into its UVs ------------------------------------

def bake_maps(body):
    names = {g.index:g.name for g in body.vertex_groups}
    def dominant(v):
        best = max(v.groups,key=lambda g:g.weight,default=None)
        return names[best.group] if best else ''
    classes = [limb(dominant(v)) for v in body.data.vertices]
    attribute = body.data.color_attributes.new('Limb','FLOAT_COLOR','CORNER')
    for poly in body.data.polygons:
        votes = [classes[i] for i in poly.vertices]
        c = max(set(votes),key=votes.count)
        for loop in poly.loop_indices: attribute.data[loop].color = (c/16,0,0,1)
    mat = bpy.data.materials.new('RangerBake'); mat.use_nodes = True
    nodes = mat.node_tree.nodes; links = mat.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    emit = nodes.new('ShaderNodeEmission')
    links.new(emit.outputs[0],out.inputs['Surface'])
    coords = nodes.new('ShaderNodeTexCoord')
    region = nodes.new('ShaderNodeVertexColor'); region.layer_name = 'Limb'
    body.data.materials.clear(); body.data.materials.append(mat)
    target = nodes.new('ShaderNodeTexImage'); nodes.active = target
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'; scene.cycles.samples = 1; scene.cycles.device = 'CPU'
    scene.render.bake.margin = 12
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True); bpy.context.view_layer.objects.active = body
    maps = {}
    for name,socket in [('position',coords.outputs['Object']),('limb',region.outputs['Color'])]:
        image = bpy.data.images.new('ranger_'+name,SIZE,SIZE,alpha=True,float_buffer=True)
        image.generated_color = (0,0,0,0)
        target.image = image
        links.new(socket,emit.inputs['Color'])
        bpy.ops.object.bake(type='EMIT')
        pixels = np.empty(SIZE*SIZE*4,dtype=np.float32); image.pixels.foreach_get(pixels)
        maps[name] = pixels.reshape(SIZE,SIZE,4)
    return maps


# --- Noise ---------------------------------------------------------------------

def hash3(i):
    h = (i[...,0]*73856093) ^ (i[...,1]*19349663) ^ (i[...,2]*83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xffff).astype(np.float32)/65535.0

def vnoise(p, freq):
    q = p*freq
    i = np.floor(q).astype(np.int64); f = q-i
    f = f*f*(3-2*f)
    total = 0.0
    for dx in (0,1):
        for dy in (0,1):
            for dz in (0,1):
                w = (f[...,0] if dx else 1-f[...,0])*(f[...,1] if dy else 1-f[...,1])*(f[...,2] if dz else 1-f[...,2])
                total = total+w*hash3(i+np.array([dx,dy,dz]))
    return total

def fbm(p, freq, octaves=4):
    total = 0.0; amp = .5; norm = 0.0
    for o in range(octaves):
        total = total+vnoise(p+o*17.3,freq*(2.03**o))*amp
        norm += amp; amp *= .5
    return total/norm

def band(x, lo, hi, soft=.002):
    return np.clip((x-lo)/soft+.5,0,1)*np.clip((hi-x)/soft+.5,0,1)


# --- Painting ------------------------------------------------------------------

def paint(maps, skin, recipe):
    pos = maps['position'][...,:3]
    cls = np.rint(maps['limb'][...,0]*16).astype(np.int32)
    # Texels off the body (and its bake margin) carry no limb.
    baked = cls > 0
    P = pos[baked]; C = cls[baked]
    x,y,z = P[:,0],P[:,1],P[:,2]
    n = len(P)
    side = np.sign(x+1e-6)
    print('KIT_TEXELS',recipe,n)

    albedo = np.zeros((n,3),np.float32)
    height = np.zeros(n,np.float32)
    rough = np.full(n,.8,np.float32)
    # Texels the kit covers (all others are bare skin).
    dressed = np.zeros(n,bool)
    def put(mask, color, h=None, r=None):
        dressed[mask] = True
        albedo[mask] = color[mask] if isinstance(color,np.ndarray) and color.ndim==2 else color
        if h is not None: height[mask] = h[mask] if isinstance(h,np.ndarray) else h
        if r is not None: rough[mask] = r

    grain = fbm(P,180.0,3)
    mottle = fbm(P,9.0,4)
    wear = fbm(P,26.0,4)

    def leather(base, darkness=1.0):
        # Reddish-brown hide: mottled, grained, paler where it is worn.
        tone = (.82+mottle[:,None]*.36)*darkness
        c = np.array(base,np.float32)[None,:]*tone
        scuff = np.clip((wear-.66)*4,0,1)[:,None]
        c = c*(1-scuff)+c*1.25*scuff
        return c*(.92+grain[:,None]*.16)
    def wool(base, scale=380.0):
        weave = (np.sin(x*scale)*np.sin(z*scale)+np.sin(y*scale)*np.sin(z*scale*1.03))*.5
        c = np.array(base,np.float32)[None,:]*(.84+mottle[:,None]*.3)*(.95+weave[:,None]*.05)
        return c, weave*.0004
    leather_h = grain*.0009+wear*.0006

    # Distances round each limb, for straps and seams that wrap it.
    def around(cx, cy):
        return np.arctan2(x-cx, y-cy)

    # --- skin and face
    # The character's skin, a little less saturated and warm than its own
    # texture, which reads orange under the game's warm light.
    sk = skin[baked]
    grey = sk.mean(1,keepdims=True)
    sk = (grey+(sk-grey)*.72)*.94
    put(np.ones(n,bool), sk, 0.0, .6)
    dressed[:] = False
    face = (C==HEAD)&(z<1.64)&(z>1.52)&(y<.0)
    stubble = np.clip((vnoise(P,900.0)-.35)*2.5,0,1)*face
    albedo[:] = albedo*(1-.22*stubble[:,None])

    def ranger():
        # --- upper arms: linen sleeves
        sleeve,wv = wool([.24,.21,.17],520.0)
        m = C==UPPERARM; put(m, sleeve, wv, .9)

        # --- forearms: long bracers laced over the top
        m = C==FOREARM
        br = leather([.30,.17,.10],.92)
        put(m, br, leather_h+.0012, .62)
        # Lacing: a cord criss-crossing over the top of each bracer, an X every
        # 4cm along the arm, and stitched seams round both ends.
        along = np.abs(x)
        if m.any():
            mid = z[m].mean()
            phase = (along*25.0)%1.0
            offset = z-mid
            lace = m & (offset>-.03) & (np.abs(np.abs(phase-.5)*.06-np.abs(offset-.012)) < .0035)
            put(lace, np.array([.16,.11,.07])*(.9+grain[:,None]*.2), leather_h+.0028, .7)
            lo,hi = np.percentile(along[m],4),np.percentile(along[m],80)
            for end in (lo,hi):
                seam = m & (np.abs(along-end)<.004)
                albedo[seam] *= .55; height[seam] -= .0008
                dots = m & (np.abs(along-(end+(.009 if end==lo else -.009)))<.0016) & (((np.arctan2(y,z-mid)*40.0)%1.0)<.5)
                albedo[dots] = np.array([.52,.42,.30]); height[dots] += .0004
            # The upper end of the arm past the bracer is sleeve.
            bare = m & (along>hi)
            put(bare, sleeve, wv, .9)

        # --- hands: fingerless gloves
        m = (C==HAND)|(C==KNUCKLE)
        put(m, leather([.26,.15,.09],.9), leather_h+.0008, .6)

        # --- torso: tunic, belt, crossed straps
        m_t = C==TORSO
        tunic,wv = wool([.16,.19,.14],300.0)
        # A fine diamond quilting over the tunic.
        d1 = np.abs((((x+z)*48.0)%1.0)-.5); d2 = np.abs((((z-x)*48.0)%1.0)-.5)
        quilt = np.minimum(d1,d2)
        tunic = tunic*(1-.09*(quilt<.05)[:,None])
        put(m_t, tunic, wv-.0004*(quilt<.05), .92)
        # The tunic's skirt over the thighs, to a ragged hem.
        hem = .70+(fbm(P*np.array([1,1,0.0],np.float32)+3,14.0,3)-.5)*.08
        skirt = (C==THIGH)&(z>hem)
        put(skirt, tunic, wv, .92)
        edge = (C==THIGH)&(z>hem)&(z<hem+.012)
        albedo[edge] *= .6
        # Trousers: dark wool below the hem down into the boots.
        trous,wv2 = wool([.17,.13,.10],420.0)
        put(((C==THIGH)&(z<=hem))|(C==CALF), trous, wv2, .9)
        # Two straps round the outside of the left thigh, holding the dagger's
        # sheath (tools/outfit_hero.py), each with a small steel buckle.
        left_thigh = (C==THIGH)&(np.sign(x)==-RIGHT_SIGN)
        for zs in (.86,.72):
            st = left_thigh & (np.abs(z-zs)<.011)
            put(st, leather([.24,.13,.07],.9), leather_h+.0028, .6)
            albedo[st & (np.abs(np.abs(z-zs)-.011)<.0022)] *= .55
            buck = st & (y<-.04) & (np.abs(np.abs(x)-.13)<.012)
            put(buck, np.array([.5,.49,.46])*(.85+grain[:,None]*.3), .004, .32)
        # Leather knee guards.
        knee = ((C==THIGH)|(C==CALF))&(np.abs(z-.5)<.085)&(y<-.02)
        kg = leather([.29,.16,.10],.95)
        put(knee, kg, leather_h+.0022, .62)
        knee_rim = knee & (np.abs(np.abs(z-.5)-.075)<.006)
        albedo[knee_rim] *= .55; height[knee_rim] -= .0006

        # Belt.
        belt = m_t & (z>.975) & (z<1.055)
        bl = leather([.28,.15,.08],.85)
        put(belt, bl, leather_h+.0035, .58)
        stitch = belt & ((np.abs(z-.981)<.0018)|(np.abs(z-1.049)<.0018)) & (((np.arctan2(x,y)*90.0)%1.0)<.5)
        albedo[stitch] = np.array([.55,.45,.32]); height[stitch] += .0004
        holes = belt & (np.abs(z-1.015)<.006) & (x<-.02) & (y<0) & (((x*55.0)%1.0)<.22)
        albedo[holes] *= .25; height[holes] -= .0012
        buckle = m_t & (y<0) & (np.abs(x-.0)<.045) & (z>.968) & (z<1.062)
        frame = buckle & ((np.abs(x)>.033)|(z<.98)|(z>1.05))
        put(frame, np.array([.52,.50,.46])*(.85+grain[:,None]*.3), .0045, .32)

        # Crossed straps: left shoulder to right hip, right shoulder to left hip.
        def strap(x0,z0,x1,z1,width):
            dx,dz = x1-x0,z1-z0; L = math.hypot(dx,dz)
            d = np.abs((x-x0)*dz-(z-z0)*dx)/L
            return d, width
        for (x0,z0,x1,z1,w) in [(.16,1.48,-.17,1.0,.026),(-.16,1.48,.17,1.04,.018)]:
            d,w = strap(x0,z0,x1,z1,w)
            s = m_t & (d<w) & (z>.99)
            put(s, leather([.31,.17,.09],.9), leather_h+.003, .6)
            st = s & (np.abs(d-(w-.005))<.0018) & (((z*160.0)%1.0)<.5)
            albedo[st] = np.array([.55,.45,.32]); height[st] += .0004
            rim = s & (d>w-.002)
            albedo[rim] *= .6

        # --- boots
        top = .44+(np.cos(around(np.where(x>0,.12,-.12),.0)*1.0)*.015)
        boot = ((C==CALF)|(C==FOOT)) & (z<top)
        bt = leather([.27,.14,.08])
        put(boot, bt, leather_h+.0015, .55)
        # A turned-down cuff, darker, with a stitched lower edge.
        cuff = boot & (z>top-.045)
        albedo[cuff] *= .78; height[cuff] += .0018
        cuff_st = boot & (np.abs(z-(top-.045))<.0018) & (((around(np.sign(x)*.12,0)*24.0)%1.0)<.5)
        albedo[cuff_st] = np.array([.5,.4,.28])
        # Creases over the ankle.
        ankle = boot & (z>.06) & (z<.2)
        crease = np.sin(z*190.0+fbm(P,30.0,2)*6.0)
        height[ankle] += (crease[ankle]*.0011)
        albedo[ankle] *= (1-.09*(crease[ankle]>.7))[:,None]
        # Two wrapped straps round the shin, each with a buckle on the outside.
        phi = around(np.sign(x)*.11,.0)
        for zc,tilt,w in [(.32,.035,.017),(.215,-.03,.015)]:
            zs = zc+np.sin(phi)*tilt
            s = boot & (np.abs(z-zs)<w)
            put(s, leather([.24,.12,.07],.9), leather_h+.0032, .58)
            rim = s & (np.abs(np.abs(z-zs)-w)<.0025)
            albedo[rim] *= .55
            out = s & (np.abs(x)>.15) & (np.abs(y-.0)<.03)
            put(out, np.array([.55,.53,.48])*(.85+grain[:,None]*.3), .005, .3)
        # A strap with a buckle across the instep, rising to the back of the
        # ankle, and a darker stacked heel.
        instep = boot & (np.abs(z-(.115+.55*y)) < .014) & (z<.2)
        put(instep, leather([.24,.12,.07],.9), leather_h+.0032, .58)
        rim = instep & (np.abs(np.abs(z-(.115+.55*y))-.014)<.0025)
        albedo[rim] *= .55
        ibuckle = instep & (np.abs(x)>.13) & (np.abs(y+.01)<.025)
        put(ibuckle, np.array([.55,.53,.48])*(.85+grain[:,None]*.3), .005, .3)
        heel = boot & (y>.05) & (z<.055)
        albedo[heel] *= .62; height[heel] -= .0004
        heel_line = boot & (y>.05) & (np.abs(z-.055)<.0025)
        albedo[heel_line] *= .5
        # Sole and welt.
        sole = boot & (z<.028)
        put(sole, np.array([.07,.05,.04])*(.8+grain[:,None]*.4), -.0005, .8)
        welt = boot & (np.abs(z-.032)<.003)
        albedo[welt] = np.array([.42,.32,.22]); height[welt] += .0006


    def steel(dark=1.0):
        # Worn steel: mottled, grimed in the recesses, a little rust.
        c = np.array([.54,.55,.57],np.float32)[None,:]*(.78+mottle[:,None]*.34)*dark
        c = c*(1-.32*np.clip((wear-.55)*3,0,1))[:,None]
        rust = np.clip((fbm(P,38.0,3)-.68)*5,0,1)[:,None]
        return c*(1-rust)+np.array([.36,.21,.12],np.float32)[None,:]*rust*dark
    def studs(mask, u, spacing, row_z, size=.0045, metal=None):
        # A row of round studs along `u` (metres round the body) at height row_z.
        cu = (u/spacing)%1.0-.5
        d = np.hypot(cu*spacing, z-row_z)
        s_ = mask & (d<size)
        put(s_, metal if metal is not None else steel(1.15), .0025*np.clip(1-d/size,0,1), .35)
    def medallion(mask, cu, cv, radius):
        # A round boss with a raised rim and a lion's head worked in relief:
        # a domed muzzle and brow ringed by a ruffled mane.
        d = np.hypot(cu, cv)
        m_ = mask & (d<radius)
        if not m_.any(): return
        ang = np.arctan2(cv, cu)
        r = d/radius
        mane = (np.sin(ang*14+fbm(P,60.0,2)*4)*.5+.5)*(r>.45)*(r<.86)
        face = np.clip(1-(r/.48)**2,0,1)
        h = .0012+mane*.0016+face*.0034
        rim = (r>.86)
        h = np.where(rim,.0032,h)
        eyes = (np.abs(np.abs(cu)-radius*.17)<radius*.07)&(np.abs(cv-radius*.12)<radius*.05)&(r<.48)
        h = np.where(eyes,h-.0012,h)
        c = steel(1.2)*(.8+.35*(h/.004))[:,None]
        put(m_, c, None, .32)
        height[m_] = h[m_]

    def warrior():
        rx = RIGHT_SIGN
        right = np.sign(x)==rx
        around_body = np.arctan2(x, y)
        u = around_body*.16
        # --- the steel scale cuirass (chest, back, and over the collarbones)
        sx = 0.0
        if (C==UPPERARM).any(): sx = np.percentile(np.abs(x[C==UPPERARM]),12)
        cuirass = ((C==TORSO)&(z>1.045))|((C==UPPERARM)&(np.abs(x)<sx))
        # Large overlapping scales, as in the concept: each a rounded plate
        # lapping over the row below, bright along its raised middle, darker
        # toward its edge, with a rivet at its top and a dark shadow under its
        # lower rim on the scale beneath.
        sw,sh = .036,.027
        row = np.floor(z/sh)
        off = (row%2)*.5
        fu = (u/sw+off)%1.0
        fv = z/sh-row
        t = np.hypot(fu-.5,(1-fv)*sh/sw*.92)
        inside = t<.6
        dome = np.where(inside,np.clip(1-t/.6,0,1),0)
        plate_seed = hash3(np.stack([np.floor(u/sw+off),row,row*0],-1).astype(np.int64))
        sc = steel()*(.55+.6*dome**.6)[:,None]*(.9+.2*plate_seed)[:,None]
        rim = inside&(t>.5)
        sc[rim] *= .6
        under = ~inside
        sc[under] *= .32
        rivet = inside&(np.hypot(fu-.5,(fv-.88)*sh/sw)<.07)
        sc[rivet] = steel(1.3)[rivet]
        put(cuirass, sc, dome*.0026-under*.0012+rivet*.0012, .3)
        rough[cuirass & under] = .7
        # Leather edging round the neck and the cuirass's lower edge.
        neck = cuirass & (z>1.5)
        put(neck, leather([.26,.14,.08],.85), leather_h+.0022, .62)
        hem_band = (C==TORSO)&(z>1.045)&(z<1.075)
        put(hem_band, leather([.26,.14,.08],.85), leather_h+.0024, .62)
        studs(hem_band, u, .035, 1.06)
        # Lion medallions on the chest.
        front = cuirass & (y<-.04)
        for cx in (.088,-.088):
            medallion(front, x-cx, z-1.395, .036)
        # A baldric from the right shoulder across to the left hip.
        x0,z0,x1,z1,w = rx*.17,1.49,-rx*.17,1.0,.024
        dxs,dzs = x1-x0,z1-z0; L = math.hypot(dxs,dzs)
        d = np.abs((x-x0)*dzs-(z-z0)*dxs)/L
        strap = (C==TORSO)&(d<w)&(z>1.0)
        put(strap, leather([.29,.15,.08],.9), leather_h+.003, .6)
        rivet = strap & (np.abs(d)<.005) & (((z*30.0)%1.0)<.18)
        put(rivet, steel(1.2), .004, .35)
        rim = strap & (d>w-.0025)
        albedo[rim] *= .55
        # --- the broad belt with its lion boss
        belt = (C==TORSO)&(z>.955)&(z<1.045)
        put(belt, leather([.27,.14,.08],.85), leather_h+.0034, .58)
        studs(belt, u, .034, .972)
        studs(belt, u, .034, 1.028)
        meander = belt & (np.abs(z-1.0)<.012)
        mk = ((u*90.0)%1.0)
        key = meander & (((mk<.5)&(np.abs(z-1.0)>.006))|((mk>.45)&(mk<.55)))
        albedo[key] *= 1.5; height[key] += .0005
        medallion(belt & (y<-.04), x, z-1.0, .045)
        # --- shoulders: hanging leather strips (pteruges) over the shoulder caps
        cap = (C==UPPERARM)&(np.abs(x)>=sx)&(np.abs(x)<sx+.09)
        arm_ang = np.arctan2(y, z-1.42)
        strip = ((arm_ang*4.5/math.pi)%1.0)
        pt = leather([.25,.13,.07],.85)*(1-.4*(strip>.86))[:,None]
        put(cap, pt, leather_h+.0028-.0012*(strip>.86), .62)
        # --- bare arms; a cloth wrap round the left upper arm
        wrap = (C==UPPERARM)&(~right)&(np.abs(np.abs(x)-(sx+.2))<.03)
        tw = np.sin((np.abs(x)*120.0+np.arctan2(y,z-1.41)*2.0))
        put(wrap, np.array([.24,.22,.21])*(.8+tw[:,None]*.15)*(.85+mottle[:,None]*.3), .002+tw*.0006, .9)
        # --- forearms: a steel manica on the sword arm, leather wraps on the shield arm
        fa = C==FOREARM
        along = np.abs(x)
        lames = (along*34.0)%1.0
        man = fa & right
        put(man, steel()*(.8+.3*(lames>.12))[:,None], .002+.0008*(lames>.12), .38)
        if man.any():
            mid = along[man].mean()
            # A small lion boss on the top of the forearm.
            medallion(man, along-mid, z-np.percentile(z[man],92), .026)
        lw = fa & ~right
        diag = ((along*30.0+np.arctan2(y,z-1.41)*1.4)%1.0)
        put(lw, leather([.25,.14,.08],.9)*(1-.35*(diag<.12))[:,None], leather_h+.0018-.0008*(diag<.12), .62)
        # Leather wraps over the hands' knuckles.
        hand = C==HAND
        hw = ((along*40.0+np.arctan2(y,z-1.41))%1.0)
        put(hand, leather([.24,.13,.08],.85)*(1-.3*(hw<.15))[:,None], leather_h+.001, .62)
        # --- the tattered red-grey underskirt below the kilt
        under_hem = .655+(fbm(P*np.array([1,1,0],np.float32)+7,16.0,3)-.5)*.06
        under = (C==THIGH)&(z>under_hem)&(z<.86)
        uc,uv = wool([.30,.18,.18],360.0)
        uc = uc*(1-.5*np.clip((wear-.5)*2,0,1))[:,None]+np.array([.14,.13,.13])*np.clip((wear-.5)*2,0,1)[:,None]
        put(under, uc, uv, .9)
        albedo[under & (z<under_hem+.01)] *= .55
        # (Bare shins: no greaves.)
        # --- sandals: a thick sole and straps over the bare foot and ankle
        foot = (C==FOOT)|((C==CALF)&(z<.1))
        sole = foot & (z<.02)
        put(sole, leather([.2,.11,.06],.8), leather_h+.003, .7)
        ankle = foot & (z>.05)&(z<.1)&(((z*95.0)%1.0)<.55)
        put(ankle, leather([.27,.14,.08],.9), leather_h+.0028, .6)
        top = foot & (z>.025)&(z<.07)&((((y*24.0)%1.0)<.4))
        put(top, leather([.27,.14,.08],.9), leather_h+.0028, .6)
        buckle_s = foot & (np.abs(z-.075)<.008)&(np.abs(np.abs(x)-.15)<.012)
        put(buckle_s, steel(1.2), .004, .35)

    def wizard():
        along = np.abs(x)
        # --- leather bracers wrapped in overlapping scales of hide
        fa = C==FOREARM
        diag1 = (((along+z)*36.0)%1.0); diag2 = (((along-z)*36.0)%1.0)
        cell = np.minimum(np.minimum(diag1,1-diag1),np.minimum(diag2,1-diag2))
        br = leather([.17,.12,.09],.85)*(.75+.45*np.clip(cell*4,0,1))[:,None]
        put(fa, br, leather_h+.0016*np.clip(cell*4,0,1), .6)
        wraps = fa & (((along*14.0)%1.0)<.1)
        albedo[wraps] *= .6; height[wraps] -= .0008
        # --- leather wraps over the hands' backs
        put(C==HAND, leather([.18,.12,.09],.85), leather_h+.0008, .62)
        # --- dark trousers under the robe
        trous,wv = wool([.12,.11,.11],420.0)
        put((C==THIGH)|(C==CALF), trous, wv, .9)
        # --- boots of dark, worn leather, with a strap and buckle at the ankle
        boot = ((C==CALF)|(C==FOOT))&(z<.34)
        put(boot, leather([.17,.12,.09],.85), leather_h+.0016, .55)
        crease = boot & (z>.06)&(z<.2)
        cr = np.sin(z*170.0+fbm(P,30.0,2)*6.0)
        height[crease] += cr[crease]*.0011
        albedo[crease] *= (1-.1*(cr[crease]>.7))[:,None]
        top = boot & (z>.3)
        albedo[top] *= .75; height[top] += .0015
        phi = np.arctan2(x-np.sign(x)*.11, y)
        for zc,tilt,w in [(.13,.025,.015),(.24,-.02,.013)]:
            zs = zc+np.sin(phi)*tilt
            st = boot & (np.abs(z-zs)<w)
            put(st, leather([.15,.1,.07],.8), leather_h+.003, .58)
            albedo[st & (np.abs(np.abs(z-zs)-w)<.0025)] *= .55
            put(st & (np.abs(x)>.15)&(np.abs(y)<.03), steel(1.0), .004, .35)
        put(boot & (z<.026), np.array([.06,.05,.04])*(.8+grain[:,None]*.4), -.0005, .8)
        # --- the sash: dark leather, creased, knotted at the front
        sash = (C==TORSO)&(z>.975)&(z<1.06)
        creases = np.sin(z*260.0+fbm(P,20.0,2)*5.0)
        put(sash, leather([.22,.15,.1],.8)*(.9+.12*creases[:,None]), leather_h+.0012*creases, .62)
        kn = sash & (y<-.05)&(np.hypot(x-RIGHT_SIGN*.06, z-1.017)<.03)
        kd = np.hypot(x-RIGHT_SIGN*.06, z-1.017)
        put(kn, leather([.2,.13,.09],.8)*(.75+.5*np.clip(1-kd/.03,0,1))[:,None], .002+.004*np.clip(1-kd/.03,0,1), .6)

    RECIPES = {'ranger':ranger,'warrior':warrior,'wizard':wizard}
    RECIPES[recipe]()
    return albedo, height, rough, baked, dressed


def normal_map(height, baked, pos):
    H = np.zeros((SIZE,SIZE),np.float32); H[baked] = height
    P = pos
    # Height per metre along U and V, from the texel spacing on the body.
    du = np.linalg.norm(np.roll(P,-1,1)-np.roll(P,1,1),axis=2)*.5
    dv = np.linalg.norm(np.roll(P,-1,0)-np.roll(P,1,0),axis=2)*.5
    du = np.maximum(du,1e-4); dv = np.maximum(dv,1e-4)
    gx = (np.roll(H,-1,1)-np.roll(H,1,1))*.5/du
    gy = (np.roll(H,-1,0)-np.roll(H,1,0))*.5/dv
    # Ignore jumps across UV island edges.
    gx = np.clip(gx,-1.5,1.5); gy = np.clip(gy,-1.5,1.5)
    nrm = np.stack([-gx,-gy,np.ones_like(gx)],-1)
    nrm /= np.linalg.norm(nrm,axis=2,keepdims=True)
    nrm[~baked] = (0,0,1)
    return nrm*.5+.5


def save(name, rgb):
    image = bpy.data.images.new(name,SIZE,SIZE,alpha=True)
    flat = np.ones((SIZE,SIZE,4),np.float32); flat[...,:3] = rgb
    image.pixels.foreach_set(flat.ravel())
    image.filepath_raw = str(OUT/(name+'.png')); image.file_format = 'PNG'
    image.save()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/character/warrior.glb'))
    rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks: track.mute = True
    rig.animation_data.action = None
    rig.data.pose_position = 'REST'
    body = next(o for o in bpy.data.objects if o.type=='MESH' and 'SuperHero' in o.name)
    for o in list(bpy.data.objects):
        if o.type=='MESH' and o!=body: o.hide_render = True
    maps = bake_maps(body)
    skin_image = bpy.data.images.load(str(SKIN))
    skin_image.scale(SIZE,SIZE)
    sp = np.empty(SIZE*SIZE*4,np.float32); skin_image.pixels.foreach_get(sp)
    skin = sp.reshape(SIZE,SIZE,4)[...,:3]
    def raw(path):
        image = bpy.data.images.load(str(path))
        image.colorspace_settings.name = 'Non-Color'
        image.scale(SIZE,SIZE)
        px = np.empty(SIZE*SIZE*4,np.float32); image.pixels.foreach_get(px)
        return px.reshape(SIZE,SIZE,4)
    skin_normal = raw(SKIN_NORMAL)[...,:3]*2-1
    # The roughness is the green channel (glTF's packing).
    skin_rough = raw(SKIN_ROUGH)[...,1]
    global RIGHT_SIGN
    RIGHT_SIGN = 1.0 if (rig.matrix_world @ rig.data.bones['upperarm_r'].head_local).x>0 else -1.0
    pos = maps['position'][...,:3]
    for recipe in ONLY or ['ranger','warrior','wizard']:
        albedo,height,rough,baked,dressed = paint(maps,skin,recipe)
        colour = np.zeros((SIZE,SIZE,3),np.float32)
        colour[baked] = np.clip(albedo,0,1)
        save('hero_kit_'+recipe,colour)
        # Bare skin keeps the character's own relief, laid under the kit's
        # (whiteout blend: the slopes add, the heights multiply).
        nrm = normal_map(height,baked,pos)*2-1
        bare = np.zeros((SIZE,SIZE),bool); bare[baked] = ~dressed
        mixed = np.concatenate([nrm[...,:2]+skin_normal[...,:2],nrm[...,2:]*skin_normal[...,2:]],-1)
        mixed /= np.linalg.norm(mixed,axis=2,keepdims=True)
        nrm[bare] = mixed[bare]
        save('hero_kit_'+recipe+'_normal',nrm*.5+.5)
        r = np.full((SIZE,SIZE),.8,np.float32); r[baked] = rough
        # Red: roughness. Green: metal, where the paint is steel (the only
        # surfaces painted this glossy); never the skin.
        metal = np.clip((.5-r)/.12,0,1)
        if recipe in ('ranger','wizard'):
            # A traveller's worn kit: wool, linen and leather all dulled to a
            # matte, dusty finish.
            r = np.where(baked & ~bare & (metal<.5),np.maximum(r,.88),r)
        r[bare] = np.clip(skin_rough[bare],.35,.9)
        metal[bare] = 0
        save('hero_kit_'+recipe+'_rough',np.stack([r,metal,np.zeros_like(r)],-1))
        # The relief as a height map (0.5 the bare surface, 1/255 = 0.04mm),
        # for the statues, which carve it into stone (statue_stone.gdshader).
        hm = np.full((SIZE,SIZE),.5,np.float32); hm[baked] = np.clip(.5+height*100.0,0,1)
        save('hero_kit_'+recipe+'_height',np.repeat(hm[...,None],3,2))
        print('KIT_READY',recipe)

main()
