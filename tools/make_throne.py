"""Builds the elders' thrones: assets/models/props/throne.glb (the great throne
in the palace's throne room) and throne_elder.glb (the five in the arena's
elders' box).

A throne, not a chair: a solid seat block of white marble on a stepped marble
plinth, framed and panelled in gilt; solid arms, each a marble side panel
with a gilt rail ending in a scroll at the front; a tall solid back raked a
little, its inner face upholstered in crimson velvet inside a gilt frame,
gilt-capped posts at its corners with finials, and a gilt sunburst crest over
it; a deep velvet cushion on the seat; gilt lion's feet at the front. The
elders' box chairs are the same throne at a man's size without the plinth.

Each is at its real size in metres (origin under the middle of its base, its
seat facing +Z in the game, -Y here), in three surfaces the game dresses by
name (scripts/world_art.gd shared): ThroneMarble, ThroneGold, ThroneVelvet.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_throne.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT/'assets/models/props'
MATERIALS = ('ThroneMarble', 'ThroneGold', 'ThroneVelvet')


def material(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def finish(obj, mat, bevel=0.0, segments=2, smooth=True):
    obj.data.materials.clear()
    obj.data.materials.append(material(mat))
    bpy.context.view_layer.objects.active = obj
    if bevel > 0:
        mod = obj.modifiers.new('bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(35)
        mod.harden_normals = False
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    return obj


def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def box(name, size, centre, mat, bevel=.008, segments=2, panels=(), raked=0.0, taper=0.0):
    """A box `size` (x, y, z) centred on `centre`. `panels`: faces to sink a
    recessed panel into, as (axis, sign, border, depth). `taper` narrows its
    top in x by that share; `raked` leans it back (about x at its base)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x*size[0], v.co.y*size[1], v.co.z*size[2]))
        if taper and v.co.z > 0: v.co.x *= 1-taper
    for axis, sign, border, depth in panels:
        bm.faces.ensure_lookup_table()
        face = max(bm.faces, key=lambda f: f.normal[axis]*sign)
        result = bmesh.ops.inset_region(bm, faces=[face], thickness=border, depth=0)
        bmesh.ops.inset_region(bm, faces=[face], thickness=.012, depth=-depth)
    if raked:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, -size[2]*.5)), matrix=Matrix.Rotation(raked, 3, 'X'))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return finish(new_object(name, bm), mat, bevel, segments)


def cylinder(name, radius, depth, centre, axis, mat, segments=20, bevel=.004, radius2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius if radius2 is None else radius2, depth=depth)
    turn = {'X': Matrix.Rotation(math.pi/2, 3, 'Y'), 'Y': Matrix.Rotation(math.pi/2, 3, 'X'), 'Z': Matrix.Identity(3)}[axis]
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=turn)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return finish(new_object(name, bm), mat, bevel, 1)


def sphere(name, radius, centre, mat, squash=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius)
    for v in bm.verts: v.co = Vector((v.co.x*squash[0], v.co.y*squash[1], v.co.z*squash[2]))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return finish(new_object(name, bm), mat)


def frame(name, centre, width, height, bar, proud, mat, raked=0.0, pivot=None):
    """A gilt moulding round a rectangle on a face looking toward -Y: four
    bars `bar` wide standing `proud` off it."""
    parts = []
    cx, cy, cz = centre
    for dx, dz, w, h in [(0, height*.5, width+bar, bar), (0, -height*.5, width+bar, bar), (width*.5, 0, bar, height-bar), (-width*.5, 0, bar, height-bar)]:
        parts.append(box(name, (w, proud, h), (cx+dx, cy, cz+dz), mat, bevel=bar*.3))
    if raked:
        for p in parts: p.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(raked, 4, 'X') @ Matrix.Translation(-Vector(pivot)))
    return parts


def cushion(name, size, centre, mat, puff=.035):
    """A stuffed cushion: a subdivided box, its faces bulged and its edges
    rounded, the top sagging a little in the middle."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=6, use_grid_fill=True)
    sx, sy, sz = size
    for v in bm.verts:
        p = v.co.copy()
        # Bulge: points away from the edges swell outward.
        u = Vector((1-abs(p.x*2)**4, 1-abs(p.y*2)**4, 1-abs(p.z*2)**4))
        p.x *= sx; p.y *= sy; p.z *= sz
        if v.co.z > 0: p.z += puff*u.x*u.y - .012*u.x*u.y
        if v.co.z < 0: p.z -= puff*.3*u.x*u.y
        p.x += math.copysign(puff*.5*u.y*u.z, v.co.x) if abs(v.co.x) > .49 else 0
        p.y += math.copysign(puff*.5*u.x*u.z, v.co.y) if abs(v.co.y) > .49 else 0
        v.co = p
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    obj = new_object(name, bm)
    finish(obj, mat, bevel=0, smooth=False)
    mod = obj.modifiers.new('round', 'SUBSURF')
    mod.levels = 1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    return obj


def crest(name, radius, thickness, centre, mat, rays=11):
    """A gilt sunburst: a half-disc standing on the back's top, rays raised
    on its face, a boss at their root."""
    parts = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=40, radius1=radius, radius2=radius, depth=thickness)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=Matrix.Rotation(math.pi/2, 3, 'X'))
    geom = bm.verts[:]+bm.edges[:]+bm.faces[:]
    cut = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, 0, 0)), plane_no=Vector((0, 0, 1)), clear_inner=True)
    edges = [e for e in cut['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=0)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    parts.append(finish(new_object(name, bm), mat, .006, 2))
    cx, cy, cz = centre
    for i in range(rays):
        a = math.pi*(i+.5)/rays
        length = radius*.78
        ray = box(name, (.022, .03, length), (0, 0, 0), mat, bevel=.008)
        ray.data.transform(Matrix.Translation((cx+math.cos(a)*radius*.5, cy-thickness*.5-.008, cz+math.sin(a)*radius*.5)) @ Matrix.Rotation(-(a-math.pi/2), 4, 'Y'))
        parts.append(ray)
    parts.append(sphere(name, radius*.2, (cx, cy-thickness*.5, cz+.02), mat, squash=(1, .55, 1)))
    return parts


def throne(scale, plinth, back_height, crest_radius):
    """Builds one throne. `scale` sizes its seat, arms and back together (1
    a large man's throne); `plinth` is the height of its stepped base (0 for
    none); `back_height` how far its back rises over the seat."""
    s = scale
    parts = []
    W, D = 1.10*s, .80*s
    base = plinth
    if plinth > 0:
        # The plinth: two marble steps with a gilt fillet between, reaching
        # out before the seat as a footrest.
        step = plinth*.55
        parts.append(box('plinth', (W+.52, D+.62, step), (0, -.12, step*.5), 'ThroneMarble', bevel=.012))
        parts.append(box('fillet', (W+.40, D+.50, .03), (0, -.12, step+.015), 'ThroneGold', bevel=.008))
        parts.append(box('plinth2', (W+.34, D+.44, plinth-step-.03), (0, -.10, step+.03+(plinth-step-.03)*.5), 'ThroneMarble', bevel=.012))
    seat = .44*s
    top = base+seat
    # The seat block: solid marble, a recessed panel on its front and sides,
    # a gilt moulding round its foot and its top.
    parts.append(box('seat', (W, D, seat-.07*s), (0, 0, base+.04*s+(seat-.07*s)*.5), 'ThroneMarble', bevel=.01,
                     panels=[(1, -1, .07*s, .022*s), (0, 1, .07*s, .022*s), (0, -1, .07*s, .022*s)]))
    parts.append(box('foot_moulding', (W+.05*s, D+.05*s, .045*s), (0, 0, base+.0225*s), 'ThroneGold', bevel=.012))
    parts.append(box('seat_moulding', (W+.04*s, D+.04*s, .04*s), (0, 0, top-.02*s), 'ThroneGold', bevel=.012))
    parts += frame('seat_frame', (0, -D*.5-.006, base+.04*s+(seat-.07*s)*.5), W-.12*s, seat-.17*s, .022*s, .014*s, 'ThroneGold')
    # Lion's feet at the front corners, gilt, under the foot moulding.
    for side in (-1, 1):
        parts.append(sphere('paw', .07*s, (side*(W*.5-.04*s), -D*.5+.03*s, base+.035*s), 'ThroneGold', squash=(1, 1.25, .55)))
        for toe in (-1, 0, 1):
            parts.append(sphere('toe', .026*s, (side*(W*.5-.04*s)+toe*.035*s, -D*.5-.045*s, base+.022*s), 'ThroneGold', squash=(1, 1.2, .8)))
    # The arms: solid marble side panels on the seat, their tops gilt rails
    # that end at the front in a scroll.
    arm = .29*s
    side_w = .13*s
    for side in (-1, 1):
        x = side*(W*.5-side_w*.5)
        parts.append(box('arm', (side_w, D-.02*s, arm), (x, .01*s, top+arm*.5), 'ThroneMarble', bevel=.01,
                         panels=[(0, side, .05*s, .018*s)]))
        parts.append(box('arm_rail', (side_w+.05*s, D+.02*s, .05*s), (x, 0, top+arm+.025*s), 'ThroneGold', bevel=.016))
        parts.append(cylinder('scroll', .085*s, side_w+.07*s, (x, -D*.5-.01*s, top+arm-.03*s), 'X', 'ThroneGold', segments=24))
        for face in (-1, 1):
            parts.append(cylinder('rosette', .05*s, .02*s, (x+face*(side_w*.5+.045*s), -D*.5-.01*s, top+arm-.03*s), 'X', 'ThroneGold', segments=16, radius2=.03*s))
        # A gilt fillet down the arm's front, under the scroll.
        parts.append(box('arm_front', (side_w+.01*s, .03*s, arm-.11*s), (x, -D*.5+.005*s, top+(arm-.11*s)*.5), 'ThroneGold', bevel=.008))
    # The back: a solid marble slab raked back, its inner face a velvet
    # panel in a gilt frame; posts at its corners, a sunburst over it.
    rake = math.radians(7)
    thick = .15*s
    back_y = D*.5-thick*.5
    pivot = Vector((0, back_y, top))
    back = box('back', (W-.02*s, thick, back_height), (0, back_y, top+back_height*.5), 'ThroneMarble', bevel=.012,
               panels=[(1, 1, .09*s, .02*s)])
    back.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(rake, 4, 'X') @ Matrix.Translation(-pivot))
    parts.append(back)
    pad_w = W-2*side_w-.12*s
    pad_h = back_height-.30*s
    # (Made lying down, its stuffing swelling up, then stood up against the
    # back: the swell faces the seat.)
    pad = cushion('back_pad', (pad_w, pad_h, .07*s), (0, 0, 0), 'ThroneVelvet', puff=.02*s)
    pad.data.transform(Matrix.Rotation(math.pi/2, 4, 'X'))
    pad.data.transform(Matrix.Translation((0, back_y-thick*.5-.02*s, top+.10*s+pad_h*.5)))
    pad.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(rake, 4, 'X') @ Matrix.Translation(-pivot))
    parts.append(pad)
    parts += frame('back_frame', (0, back_y-thick*.5-.012*s, top+.10*s+pad_h*.5), pad_w+.03*s, pad_h+.03*s, .028*s, .03*s, 'ThroneGold', raked=rake, pivot=pivot)
    cap = box('back_cap', (W+.03*s, thick+.05*s, .05*s), (0, back_y, top+back_height+.025*s), 'ThroneGold', bevel=.014)
    cap.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(rake, 4, 'X') @ Matrix.Translation(-pivot))
    parts.append(cap)
    for side in (-1, 1):
        x = side*(W*.5+.01*s)
        post_h = back_height+.13*s
        post = box('post', (.12*s, .13*s, post_h), (x, back_y+.005*s, top+post_h*.5), 'ThroneMarble', bevel=.01)
        neck = cylinder('neck', .035*s, .05*s, (x, back_y+.005*s, top+post_h+.025*s), 'Z', 'ThroneGold', segments=14)
        ball = sphere('finial', .06*s, (x, back_y+.005*s, top+post_h+.09*s), 'ThroneGold', squash=(1, 1, 1.25))
        band = box('post_band', (.14*s, .15*s, .035*s), (x, back_y+.005*s, top+post_h-.03*s), 'ThroneGold', bevel=.008)
        for p in (post, neck, ball, band):
            p.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(rake, 4, 'X') @ Matrix.Translation(-pivot))
        parts += [post, neck, ball, band]
    if crest_radius > 0:
        rays = crest('crest', crest_radius*s, .06*s, (0, back_y, top+back_height+.05*s), 'ThroneGold')
        for p in rays: p.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(rake, 4, 'X') @ Matrix.Translation(-pivot))
        parts += rays
    # The seat's cushion, deep and soft, between the arms.
    parts.append(cushion('seat_cushion', (W-2*side_w-.02*s, D-thick-.03*s, .10*s), (0, -thick*.5+.0*s, top+.05*s), 'ThroneVelvet', puff=.03*s))
    return parts


def export(parts, path):
    # One mesh per surface, its origin under the middle of the base.
    joined = []
    groups = {mat: [p for p in parts if p.data.materials[0].name == mat] for mat in MATERIALS}
    for mat, group in groups.items():
        if not group: continue
        bpy.ops.object.select_all(action='DESELECT')
        for p in group: p.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        group[0].name = mat
        group[0].data.name = mat
        joined.append(group[0])
    bpy.ops.object.select_all(action='DESELECT')
    for o in joined: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', export_animations=False, export_yup=True,
                              export_image_format='NONE', use_selection=True, export_normals=True)
    low = [min((o.matrix_world @ v.co)[i] for o in joined for v in o.data.vertices) for i in range(3)]
    high = [max((o.matrix_world @ v.co)[i] for o in joined for v in o.data.vertices) for i in range(3)]
    print('THRONE_READY', path.name, {o.name: len(o.data.polygons) for o in joined}, 'size', [round(high[i]-low[i], 3) for i in range(3)])
    for o in joined: bpy.data.objects.remove(o, do_unlink=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
# The great throne: a big man's seat, on a two-step plinth, its back rising
# 1.3 m over the seat and its crest above that.
export(throne(1.0, .26, 1.30, .36), OUTPUT/'throne.glb')
# The elders' chairs in the arena's box: the same throne, smaller, on no
# plinth, a man's height with its crest.
export(throne(.78, 0.0, .62, .22), OUTPUT/'throne_elder.glb')
