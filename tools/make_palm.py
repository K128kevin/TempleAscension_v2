"""Builds the outdoor world's date palms.

No kit offered a palm that was not a toy, so these are modelled here: a
ringed, leaning trunk that swells at its foot and under its crown, and a crown
of arching feather fronds (green above, dry ones hanging below), each a pair
of leaf cards carrying the frond painted by tools/paint_flora.py. Exported
like every other prop: unit bounds, no images, materials named for
scripts/world_art.gd (PalmBark, PalmFrond, PalmFrondDry).

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_palm.py
"""
import math, random
from pathlib import Path
import bpy, bmesh
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props'
# name: (height of the trunk, how far its top leans, seed)
PALMS = {'palm_a': (6.2, 1.1, 11), 'palm_b': (7.4, 1.9, 23), 'palm_c': (5.0, .6, 37)}
AROUND = 14

def material(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = False
    return m

def build(name, height, lean, seed):
    rng = random.Random(seed)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for m in ('PalmBark', 'PalmFrond', 'PalmFrondDry'): mesh.materials.append(material(m))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new('UVMap')
    heading = rng.uniform(0, math.tau)
    sway = rng.uniform(-.25, .25)

    def spine(t):
        # The trunk leans, most of it in the upper half, with a slight S.
        out = lean*t**1.7+math.sin(t*math.pi*1.3)*sway*.6
        return Vector((math.cos(heading)*out, math.sin(heading)*out, t*height))

    # Trunk: a ring every hand's breadth, each old leaf scar a small step.
    rings = int(height/.16)
    previous = None
    for r in range(rings+1):
        t = r/rings
        centre = spine(t)
        ahead = (spine(min(1.0, t+.01))-spine(max(0.0, t-.01))).normalized()
        side = ahead.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > .001 else Vector((1, 0, 0))
        front = side.cross(ahead).normalized()
        radius = .27*(1-.22*t)+.16*math.exp(-t*height/.5)+.11*max(0.0, (t-.84)/.16)**1.5
        radius *= 1.0+(.05 if r % 2 else -.03)+rng.uniform(-.02, .02)
        ring = []
        for a in range(AROUND):
            angle = a/AROUND*math.tau
            wobble = 1.0+rng.uniform(-.045, .045)
            ring.append(bm.verts.new(centre+(side*math.cos(angle)+front*math.sin(angle))*radius*wobble))
        if previous:
            for a in range(AROUND):
                b = (a+1) % AROUND
                face = bm.faces.new((previous[a], previous[b], ring[b], ring[a]))
                face.material_index = 0
                # Bark wraps twice round the trunk and repeats every 1.3 m up it.
                us = [a/AROUND*2, (a+1)/AROUND*2, (a+1)/AROUND*2, a/AROUND*2]
                vs = [(r-1)*height/rings/1.3, (r-1)*height/rings/1.3, r*height/rings/1.3, r*height/rings/1.3]
                for loop, u, v in zip(face.loops, us, vs): loop[uv].uv = (u, v)
        previous = ring
    top = bm.verts.new(spine(1.0)+Vector((0, 0, .25)))
    for a in range(AROUND):
        face = bm.faces.new((previous[a], previous[(a+1) % AROUND], top))
        for loop in face.loops: loop[uv].uv = (.5, height/1.3)

    # Crown: fronds leave the top in tiers, the youngest nearly upright, the
    # oldest hanging dry against the trunk.
    crown = spine(1.0)+Vector((0, 0, .1))
    tiers = [(7, 52, 78, 30, 55, False), (10, 14, 46, 55, 80, False), (8, -22, 8, 50, 75, False), (5, -68, -42, 18, 30, True)]
    index = 0
    for count, low, high, droop_low, droop_high, dry in tiers:
        for f in range(count):
            azimuth = index*2.39996+rng.uniform(-.2, .2)
            index += 1
            pitch = math.radians(rng.uniform(low, high))
            droop = math.radians(rng.uniform(droop_low, droop_high))
            length = rng.uniform(2.7, 3.5)*(.8 if dry else 1.0)*(.9+.03*height)
            half = rng.uniform(.5, .62)
            segments = 9
            point = crown.copy()
            rows = []
            for s in range(segments+1):
                u = s/segments
                angle = pitch-droop*u**1.5
                along = Vector((math.cos(angle)*math.cos(azimuth), math.cos(angle)*math.sin(azimuth), math.sin(angle)))
                across = Vector((-math.sin(azimuth), math.cos(azimuth), 0))
                up = across.cross(along).normalized()
                # The two rows of leaflets rise from the stalk in a shallow V.
                lift = math.radians(24 if not dry else -8)
                left = point+(-across*math.cos(lift)+up*math.sin(lift))*half
                right = point+(across*math.cos(lift)+up*math.sin(lift))*half
                rows.append((bm.verts.new(left), bm.verts.new(point), bm.verts.new(point), bm.verts.new(right), u))
                point = point+along*length/segments
            for s in range(segments):
                a, b = rows[s], rows[s+1]
                for quad, us in (((a[0], a[1], b[1], b[0]), (0.0, .5, .5, 0.0)), ((a[2], a[3], b[3], b[2]), (.5, 1.0, 1.0, .5))):
                    face = bm.faces.new(quad)
                    face.material_index = 2 if dry else 1
                    for loop, u, v in zip(face.loops, us, (a[4], a[4], b[4], b[4])): loop[uv].uv = (u, .01+v*.98)

    # Unit bounds, the foot at the origin, as tools/prepare_models.py leaves a prop.
    lo = Vector(tuple(min(v.co[i] for v in bm.verts) for i in range(3)))
    hi = Vector(tuple(max(v.co[i] for v in bm.verts) for i in range(3)))
    size = hi-lo
    foot = spine(0.0)
    for v in bm.verts:
        v.co = Vector(((v.co.x-foot.x)/size.x, (v.co.y-foot.y)/size.y, (v.co.z-lo.z)/size.z))
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons: p.use_smooth = True
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB', export_animations=False)
    print('PALM_READY', name, tuple(round(s, 2) for s in size), len(mesh.polygons))

for name, (height, lean, seed) in PALMS.items(): build(name, height, lean, seed)
