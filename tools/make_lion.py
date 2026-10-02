"""Builds the lion: the temple's Lion Guardian, and the marble lions of the town.

The lion is sculpted here. Its body is laid up in clay, volume by volume, as a
lion is built: a deep ribcage, a tucked belly, shoulder blades and the
muscles under them, thick forelegs, the great thigh and hamstring of the hind
leg down to a high hock, broad paws with four toes and claws, a hanging tail
with its tuft, and a full mane of long locks falling back from the face over
the neck, the shoulders and the chest. The clay is fused into one surface
twice: finely, where the mane's strands, the ribs and the lines between the
muscles are then cut in; and coarsely, for the mesh the game draws, onto which
the fine one's detail is baked as a normal map. Its face is Poly Haven's
sculpted "Lion Head" (CC0), a mask of a lion's face and the mane round it,
with its own normal map; both maps share one image (the body's on the left
half, the face's on the right).

It has no skeleton but the one built here; the mesh is skinned to it and
animated: Idle, Run (a trot: the diagonal pairs of legs stepping in turn),
Attack (it rears back on its haunches, a forepaw cocked wide, and rakes it
across), the flinches Hit, HitHead and HitStagger, and Sit (the held pose of
the town's statues). Every pose is worked out here, the legs by two-bone IK,
and keyed frame by frame.

It exports assets/models/character/lion.glb, facing +Z in the game like the
other figures, without a material (the game carves it in statue stone or
marble, scripts/visual.gd), and assets/textures/lion_normal.png.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_lion.py
"""
import math, os, random
from pathlib import Path
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix, Quaternion, noise
from mathutils.kdtree import KDTree
ROOT = Path(__file__).resolve().parents[1]
FACE = ROOT/'source_art/polyhaven/lion_head/lion_head.gltf'
FACE_NORMALS = ROOT/'source_art/polyhaven/lion_head/textures/lion_head_nor_gl_1k.jpg'
OUT = ROOT/'assets/models/character/lion.glb'
NORMALS = ROOT/'assets/textures/lion_normal.png'
FPS = 30
# The grain the clay is fused at (metres): finely for the detail, coarsely
# for the game's mesh; that mesh's size; and the normal map's (each half).
FINE = .0055
COARSE = .011
BODY_TRIANGLES = 17000
FACE_TRIANGLES = 7000
MAP = 1024
# (LION_QUICK=1 skips the fine sculpt and the bake, to try a shape or a pose.)
QUICK = bool(os.environ.get('LION_QUICK'))
# The mask is a 32 cm ornament: this many times larger, its mane spans the
# body's; and where its nose goes.
FACE_SCALE = 2.3
NOSE = Vector((0, -1.25, .95))

def V(x, y, z):
    return Vector((x, y, z))

# The lion stands at the origin facing -Y, a real lion's size: 1.15 m at the
# shoulder, 2.1 m from nose to rump. Its left is +X.
TAIL = [V(0, .87, .97), V(0, .98, .86), V(0, 1.05, .66), V(0, 1.08, .46), V(0, 1.14, .30), V(0, 1.26, .26)]
# name: (head, tail, parent)
BONES = {
    'root': (V(0, 0, 0), V(0, 0, .2), None),
    'hips': (V(0, .70, .93), V(0, .38, .93), 'root'),
    'spine': (V(0, .38, .93), V(0, -.05, .92), 'hips'),
    'chest': (V(0, -.05, .92), V(0, -.52, .95), 'spine'),
    'neck': (V(0, -.52, .95), V(0, -.86, 1.06), 'chest'),
    'head': (V(0, -.86, 1.06), V(0, -1.22, .95), 'neck')}
for i in range(5):
    BONES['tail%d' % (i+1)] = (TAIL[i], TAIL[i+1], 'tail%d' % i if i else 'hips')
for side, s in (('l', 1), ('r', -1)):
    BONES['upperarm_'+side] = (V(.16*s, -.60, .88), V(.15*s, -.40, .60), 'chest')
    BONES['forearm_'+side] = (V(.15*s, -.40, .60), V(.135*s, -.47, .21), 'upperarm_'+side)
    BONES['forepaw_'+side] = (V(.135*s, -.47, .21), V(.135*s, -.50, .055), 'forearm_'+side)
    BONES['foretoes_'+side] = (V(.135*s, -.50, .055), V(.135*s, -.63, .02), 'forepaw_'+side)
    BONES['thigh_'+side] = (V(.14*s, .68, .90), V(.165*s, .43, .61), 'hips')
    BONES['shin_'+side] = (V(.165*s, .43, .61), V(.165*s, .80, .36), 'thigh_'+side)
    BONES['hindpaw_'+side] = (V(.165*s, .80, .36), V(.165*s, .73, .055), 'shin_'+side)
    BONES['hindtoes_'+side] = (V(.165*s, .73, .055), V(.165*s, .60, .02), 'hindpaw_'+side)
ORDER = list(BONES)

# ---- The clay ----

class Clay:
    """Pieces of the sculpt, gathered as plain vertices and faces (adding
    them to a mesh one at a time is slow), to be fused together later."""
    def __init__(self):
        self.verts = []
        self.faces = []
        # Where the locks of hair run: (point, direction, half-width, lock, part).
        self.strands = []
        around, rings = 14, 9
        self.sphere = [Vector((0, 0, 1))]
        for r in range(1, rings):
            polar = math.pi*r/rings
            for a in range(around):
                self.sphere.append(Vector((math.sin(polar)*math.cos(a*math.tau/around), math.sin(polar)*math.sin(a*math.tau/around), math.cos(polar))))
        self.sphere.append(Vector((0, 0, -1)))
        self.sphere_faces = []
        for a in range(around):
            b = (a+1) % around
            self.sphere_faces.append((0, 1+a, 1+b))
            for r in range(rings-2):
                top, low = 1+r*around, 1+(r+1)*around
                self.sphere_faces.append((top+a, low+a, low+b, top+b))
            last = 1+(rings-2)*around
            self.sphere_faces.append((last+b, last+a, len(self.sphere)-1))
        self.around = around

    def add(self, verts, faces):
        base = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend(tuple(base+i for i in face) for face in faces)

    def ball(self, centre, radii, basis=None):
        """An ellipsoid: `radii` along the axes of `basis` (the world's, if none)."""
        turn = basis if basis is not None else Matrix.Identity(3)
        self.add([centre+turn @ Vector((v.x*radii[0], v.y*radii[1], v.z*radii[2])) for v in self.sphere], self.sphere_faces)

    def limb(self, a, b, start, end):
        """A tapered length from `a` (radius `start`) to `b` (radius `end`), rounded at both ends."""
        turn = Vector((0, 0, 1)).rotation_difference((b-a).normalized()).to_matrix()
        n = self.around
        ring = [Vector((math.cos(i*math.tau/n), math.sin(i*math.tau/n), 0)) for i in range(n)]
        verts = [a+turn @ (v*start) for v in ring]+[b+turn @ (v*end) for v in ring]
        faces = [(i, (i+1) % n, n+(i+1) % n, n+i) for i in range(n)]+[tuple(reversed(range(n))), tuple(range(n, 2*n))]
        self.add(verts, faces)
        self.ball(a, (start, start, start))
        self.ball(b, (end, end, end))

    def lock(self, root, shell, flow, length, width, rng, part='mane'):
        """A lock of hair: a tongue lying on the `shell` (the centre and radii
        of an ellipsoid) from `root`, running the way `flow` gives at each
        point, waving a little, fullest near its root and drawn to a point."""
        centre, radii = shell
        index = rng.random()
        phase = rng.uniform(0, math.tau)
        bend = rng.uniform(-.5, .5)
        steps = 9
        points, normals = [], []
        at = root
        for k in range(steps+1):
            t = k/steps
            unit = at-centre
            unit = V(unit.x/radii.x, unit.y/radii.y, unit.z/radii.z)
            at = centre+V(unit.x*radii.x, unit.y*radii.y, unit.z*radii.z)/unit.length
            normal = V(unit.x/radii.x, unit.y/radii.y, unit.z/radii.z).normalized()
            points.append(at)
            normals.append(normal)
            way = flow(at)
            way = way-normal*way.dot(normal)
            if way.length < .05: way = V(0, 0, -1)-normal*V(0, 0, -1).dot(normal)
            way.normalize()
            side = normal.cross(way)
            at = at+(way+side*(bend*t+.45*math.sin(t*math.pi*1.7+phase))).normalized()*(length/steps)
        for k in range(steps+1):
            t = k/steps
            along = (points[min(steps, k+1)]-points[max(0, k-1)]).normalized()
            across = normals[k].cross(along).normalized()
            out = along.cross(across).normalized()
            radius = width*(.55+.6*math.sin(math.pi*min(1.0, t*1.6+.1)))*(1.0-t)**.6+.008
            # Each lies over the next: its tip stands a little off the surface.
            at = points[k]+normals[k]*(radius*.3+.03*t)
            self.ball(at, (radius, max(length/steps*1.3, radius*1.6), radius*.6), Matrix((across, along, out)).transposed())
            self.strands.append((at, along, radius, index, part))

    def strand(self, points, radius, rng, part):
        """Hair combed into the surface along `points`, with no clay of its own."""
        index = rng.random()
        for k, at in enumerate(points):
            along = (points[min(len(points)-1, k+1)]-points[max(0, k-1)]).normalized()
            self.strands.append((at, along, radius, index, part))

    def mesh(self):
        mesh = bpy.data.meshes.new('clay')
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        mesh.update()
        return mesh

def tilt(degrees):
    """A lean in the side view: the top of an upright mass goes back (+Y)."""
    return Matrix.Rotation(math.radians(-degrees), 3, 'X')

def paw(clay, ball, half):
    """A broad paw standing on its toes at `ball`: the pad behind, four toes
    in front (the middle two ahead of the outer), and their claws."""
    clay.ball(ball+V(0, .04, -.005), (half, .09, .055))
    for across in (-.68, -.24, .24, .68):
        ahead = -.10 if abs(across) < .4 else -.07
        toe = ball+V(across*half*.92, ahead, -.016)
        clay.ball(toe, (half*.29, .06, .042))
        clay.limb(toe+V(0, -.045, .004), toe+V(0, -.075, -.026), .011, .004)

def body(clay):
    # The trunk, section by section from the breast to the rump, as (y, top,
    # bottom, half-width): a deep ribcage, the belly tucked up behind it, the
    # loins and the croup.
    sections = [(-.68, 1.05, .66, .15), (-.52, 1.15, .55, .215), (-.32, 1.15, .52, .235), (-.06, 1.105, .55, .23), (.18, 1.085, .64, .21),
        (.40, 1.09, .73, .195), (.62, 1.105, .76, .20), (.80, 1.06, .80, .16), (.90, 1.01, .88, .09)]
    y = sections[0][0]
    while y <= sections[-1][0]:
        for a, b in zip(sections, sections[1:]):
            if a[0] <= y <= b[0]:
                t = (y-a[0])/(b[0]-a[0])
                top, bottom, half = (a[i]+(b[i]-a[i])*t for i in (1, 2, 3))
                clay.ball(V(0, y, (top+bottom)*.5), (half, .12, (top-bottom)*.5))
                break
        y += .02
    clay.limb(V(0, -.50, .98), V(0, -.88, 1.06), .20, .17)
    clay.ball(V(0, -.95, 1.05), (.14, .17, .15))
    for s in (1, -1):
        # The foreleg: shoulder blade and the muscle over it, the upper arm,
        # the point of the elbow, the forearm and its muscle, wrist and paw.
        clay.ball(V(.195*s, -.50, .93), (.08, .17, .25), tilt(20))
        clay.ball(V(.19*s, -.46, .74), (.085, .15, .17))
        clay.limb(V(.17*s, -.60, .84), V(.155*s, -.40, .60), .12, .105)
        clay.ball(V(.155*s, -.345, .60), (.07, .09, .085))
        clay.limb(V(.15*s, -.41, .60), V(.135*s, -.47, .23), .105, .078)
        clay.ball(V(.15*s, -.44, .48), (.092, .105, .15))
        clay.ball(V(.135*s, -.47, .215), (.08, .084, .072))
        clay.limb(V(.135*s, -.47, .21), V(.135*s, -.495, .08), .076, .078)
        paw(clay, V(.135*s, -.50, .055), .112)
        # The hind leg: the great muscle of the thigh from the hip down to
        # the stifle, the hamstring behind it, the rump, the fold of the
        # flank; the stifle; the shin running back and down to the hock, its
        # calf, the tendon behind it; the long foot down to the paw.
        clay.ball(V(.15*s, .575, .755), (.095, .21, .27), tilt(40))
        clay.ball(V(.15*s, .76, .74), (.08, .12, .24), tilt(4))
        clay.ball(V(.14*s, .66, .96), (.09, .19, .13))
        clay.ball(V(.14*s, .40, .71), (.055, .13, .11))
        clay.ball(V(.165*s, .43, .615), (.07, .08, .085))
        clay.limb(V(.165*s, .44, .61), V(.165*s, .62, .49), .098, .082)
        clay.limb(V(.165*s, .62, .49), V(.165*s, .795, .37), .082, .056)
        clay.ball(V(.165*s, .66, .52), (.07, .11, .10), tilt(-56))
        clay.limb(V(.162*s, .81, .62), V(.165*s, .835, .40), .034, .028)
        clay.ball(V(.165*s, .775, .47), (.03, .075, .10))
        clay.ball(V(.165*s, .815, .365), (.058, .07, .064))
        clay.limb(V(.165*s, .80, .36), V(.165*s, .74, .085), .062, .068)
        paw(clay, V(.165*s, .73, .055), .10)
    # The tail hangs in a curve and turns up at its tip.
    radii = (.058, .046, .038, .033, .03, .03)
    for i in range(5): clay.limb(TAIL[i], TAIL[i+1], radii[i], radii[i+1])

def mane(clay):
    rng = random.Random(4)
    # Its bulk: the ruff round the head, the bib down the breast to between
    # the forelegs, the cape over the withers and the shoulders.
    ruff = (V(0, -.82, 1.02), V(.34, .27, .37))
    bib = (V(0, -.72, .80), V(.23, .22, .30))
    cape = (V(0, -.56, 1.00), V(.285, .30, .31))
    for centre, radii in (ruff, bib, cape): clay.ball(centre, radii)
    clay.ball(V(0, -.69, 1.02), (.31, .26, .34))
    clay.ball(V(0, -.66, .62), (.15, .15, .14))
    # Long locks lie over each: back from the face and down the neck, down
    # the breast, and back over the shoulders.
    def swept(at):
        return V(at.x*.5, 1.0+max(0.0, at.z-1.0)*1.5, -.55-abs(at.x)*2.2-max(0.0, 1.0-at.z)*1.6)
    def hanging(at):
        return V(at.x*.6, .3, -1)
    for shell, count, lengths, widths, flow, keep in (
            (ruff, 150, (.3, .46), (.04, .06), swept, lambda u: u.y > -.35),
            (cape, 80, (.24, .36), (.04, .056), swept, lambda u: u.y > -.1 and u.z > -.7),
            (bib, 56, (.2, .32), (.038, .054), hanging, lambda u: u.y < .25 and u.z < .55)):
        centre, radii = shell
        for i in range(count):
            # Spread evenly over the shell (a golden-angle spiral).
            height = 1.0-2.0*(i+.5)/count
            ring = math.sqrt(1.0-height*height)
            unit = V(math.cos(i*2.39996)*ring, math.sin(i*2.39996)*ring, height)
            if not keep(unit): continue
            clay.lock(centre+V(unit.x*radii.x, unit.y*radii.y, unit.z*radii.z), shell, flow, rng.uniform(*lengths), rng.uniform(*widths), rng)
    # The tail's tuft: a leaf of long hair.
    tip = TAIL[5]
    out = (TAIL[5]-TAIL[4]).normalized()
    up = V(1, 0, 0).cross(out)
    clay.ball(tip+out*.10, (.052, .15, .066), Matrix((V(1, 0, 0), out, up)).transposed())
    for i in range(14):
        angle = i*math.tau/14
        around = V(1, 0, 0)*math.cos(angle)*.052+up*math.sin(angle)*.066
        clay.strand([tip+out*(.10+.15*(2*t-1))+around*math.sqrt(max(0.0, 1.0-(2*t-1)**2)) for t in (.1, .25, .4, .55, .7, .85, 1.0)], .03, rng, 'tail')

# Lines cut into the flanks, drawn in the side view (y, z): the edges of the
# muscles, as (points, half-width, depth); a negative depth raises a ridge.
def muscle_lines():
    lines = [
        ([(-.37, 1.07), (-.31, .92), (-.31, .74), (-.35, .63)], .04, .009),
        ([(.35, 1.05), (.40, .90), (.45, .73)], .065, .013),
        ([(.67, 1.00), (.635, .80), (.60, .62)], .028, .007),
        ([(.80, .93), (.795, .74), (.80, .56)], .022, .006),
        ([(.50, .98), (.72, 1.03)], .05, -.006),
        ([(-.50, .76), (-.46, .64)], .02, .005)]
    for i in range(6):
        y = -.19+i*.082
        lines.append(([(y, 1.01), (y+.05, .85), (y+.105, .70)], .022, .0022))
    return lines

def fuse(clay, voxel, name):
    """The clay as one surface, its joins melted."""
    obj = bpy.data.objects.new(name, clay.mesh())
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    remesh = obj.modifiers.new('fuse', 'REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier='fuse')
    melt = obj.modifiers.new('melt', 'SMOOTH')
    melt.factor = .5
    melt.iterations = 3
    bpy.ops.object.modifier_apply(modifier='melt')
    # The bare body is melted much further, so its masses run into one
    # another as muscle does; the hair and the toes keep their edges.
    tree = KDTree(len(clay.strands))
    for i, strand in enumerate(clay.strands): tree.insert(strand[0], i)
    tree.balance()
    bare = obj.vertex_groups.new(name='bare')
    for v in obj.data.vertices:
        at, index, distance = tree.find(v.co)
        hair = 1.0-min(1.0, max(0.0, distance/clay.strands[index][2]-1.4)/1.2)
        low = 1.0-min(1.0, max(0.0, v.co.z-.12)/.08)
        weight = 1.0-max(hair, low)
        if weight > 0.0: bare.add([v.index], weight, 'REPLACE')
    melt = obj.modifiers.new('blend', 'SMOOTH')
    melt.factor = .5
    melt.iterations = round(14*(COARSE/voxel)**2)
    melt.vertex_group = 'bare'
    bpy.ops.object.modifier_apply(modifier='blend')
    obj.vertex_groups.remove(obj.vertex_groups['bare'])
    for p in obj.data.polygons: p.use_smooth = True
    return obj

def carve(obj, clay):
    """The fine surface's detail: the lines of the muscles and the ribs, and
    the strands of every lock of the mane."""
    mesh = obj.data
    count = len(mesh.vertices)
    co = np.empty(count*3)
    mesh.vertices.foreach_get('co', co)
    co = co.reshape(count, 3)
    normal = np.empty(count*3)
    mesh.vertices.foreach_get('normal', normal)
    normal = normal.reshape(count, 3)
    push = np.zeros(count)
    flank = (np.abs(normal[:, 0]) > .3) & (np.abs(co[:, 0]) > .1)
    for points, width, depth in muscle_lines():
        nearest = np.full(count, 1e9)
        for a, b in zip(points, points[1:]):
            a = np.array(a)
            ab = np.array(b)-a
            t = np.clip(((co[:, 1:3]-a) @ ab)/(ab @ ab), 0.0, 1.0)
            nearest = np.minimum(nearest, np.linalg.norm(co[:, 1:3]-(a+np.outer(t, ab)), axis=1))
        push -= np.where(flank, depth*np.clip(1.0-(nearest/width)**2, 0.0, 1.0)**2, 0.0)
    # Strands: each lock is combed along its length into four or five.
    tree = KDTree(len(clay.strands))
    for i, strand in enumerate(clay.strands): tree.insert(strand[0], i)
    tree.balance()
    for i in range(count):
        p = Vector(co[i])
        at, index, distance = tree.find(p)
        point, along, radius, lock, part = clay.strands[index]
        if distance > radius*1.7: continue
        n = Vector(normal[i])
        across = along.cross(n)
        if across.length < .2: continue
        w = (p-point).dot(across.normalized())/radius
        comb = math.cos(w*math.pi*3.2+lock*40.0)*.5+.5
        fine = noise.noise(V(w*7.0, lock*90.0, (p-point).dot(along)*9.0))
        push[i] -= min(.013, radius*.22)*(1.0-comb+fine*.35)*min(1.0, (1.7-distance/radius)*2.0)
    co += normal*push[:, None]
    mesh.vertices.foreach_set('co', co.reshape(-1))
    mesh.update()

def bake(low, high):
    """The fine surface's relief, as the game mesh's normal map."""
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    low.data.uv_layers[0].name = 'UVMap'
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 1
    image = bpy.data.images.new('LionBake', MAP, MAP, alpha=False)
    image.colorspace_settings.name = 'Non-Color'
    material = bpy.data.materials.new('LionBake')
    material.use_nodes = True
    node = material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    material.node_tree.nodes.active = node
    low.data.materials.append(material)
    high.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type='NORMAL', use_selected_to_active=True, cage_extrusion=.03, max_ray_distance=.06, margin=8, normal_space='TANGENT')
    body = np.array(image.pixels[:]).reshape(MAP, MAP, 4)
    face = bpy.data.images.load(str(FACE_NORMALS))
    face.colorspace_settings.name = 'Non-Color'
    face.scale(MAP, MAP)
    sheet = np.concatenate((body, np.array(face.pixels[:]).reshape(MAP, MAP, 4)), axis=1)
    sheet[:, :, 3] = 1.0
    out = bpy.data.images.new('LionNormals', MAP*2, MAP, alpha=False)
    out.colorspace_settings.name = 'Non-Color'
    out.pixels = sheet.reshape(-1).tolist()
    out.filepath_raw = str(NORMALS)
    out.file_format = 'PNG'
    out.save()
    low.data.materials.clear()
    for layer in low.data.uv_layers:
        for item in layer.data: item.uv.x *= .5

def build_body():
    clay = Clay()
    body(clay)
    mane(clay)
    lion = fuse(clay, COARSE, 'Lion')
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = lion
    lion.select_set(True)
    cut = lion.modifiers.new('cut', 'DECIMATE')
    cut.ratio = min(1.0, BODY_TRIANGLES/sum(len(p.vertices)-2 for p in lion.data.polygons))
    bpy.ops.object.modifier_apply(modifier='cut')
    bm = bmesh.new()
    bm.from_mesh(lion.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(lion.data)
    bm.free()
    for p in lion.data.polygons: p.use_smooth = True
    fine = 0
    if not QUICK:
        high = fuse(clay, FINE, 'LionFine')
        carve(high, clay)
        bake(lion, high)
        fine = len(high.data.polygons)
        bpy.data.objects.remove(high, do_unlink=True)
    print('LION_SCULPT', fine, 'faces fine;', len(lion.data.polygons), 'in the game;', len(clay.strands), 'strand samples')
    return lion, clay

def build_face():
    """Poly Haven's sculpted lion mask, set over the front of the head."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(FACE))
    face = [o for o in bpy.data.objects if o not in before and o.type == 'MESH'][0]
    for o in list(bpy.data.objects):
        if o not in before and o != face: bpy.data.objects.remove(o, do_unlink=True)
    face.parent = None
    face.name = 'LionFace'
    mesh = face.data
    transform = face.matrix_world.copy()
    face.matrix_world = Matrix.Identity(4)
    for v in mesh.vertices: v.co = transform @ v.co
    # It stands on a plinth, which is left behind.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < .0745], context='VERTS')
    bm.to_mesh(mesh)
    bm.free()
    nose = min(mesh.vertices, key=lambda v: v.co.y).co.copy()
    for v in mesh.vertices: v.co = (v.co-nose)*FACE_SCALE+NOSE
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = face
    face.select_set(True)
    cut = face.modifiers.new('cut', 'DECIMATE')
    cut.ratio = min(1.0, FACE_TRIANGLES/sum(len(p.vertices)-2 for p in mesh.polygons))
    bpy.ops.object.modifier_apply(modifier='cut')
    mesh.materials.clear()
    mesh.uv_layers[0].name = 'UVMap'
    for item in mesh.uv_layers[0].data: item.uv.x = .5+item.uv.x*.5
    for p in mesh.polygons: p.use_smooth = True
    face.vertex_groups.new(name='head').add(range(len(mesh.vertices)), 1.0, 'REPLACE')
    return face

def build_rig():
    data = bpy.data.armatures.new('LionRig')
    rig = bpy.data.objects.new('LionRig', data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name in ORDER:
        head, tail, parent = BONES[name]
        bone = data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.roll = 0.0
        if parent: bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    data.bones['root'].use_deform = False
    for bone in rig.pose.bones: bone.rotation_mode = 'QUATERNION'
    return rig

# How far from each bone its hold on the surface reaches (metres).
HOLD = {'hips': .30, 'spine': .30, 'chest': .32, 'neck': .30, 'head': .30, 'tail': .06, 'upperarm': .16, 'forearm': .10, 'forepaw': .08,
    'foretoes': .07, 'thigh': .20, 'shin': .10, 'hindpaw': .075, 'hindtoes': .07}
TRUNK = ('hips', 'spine', 'chest', 'neck', 'head')

def distance_to_segment(p, a, b):
    ab = b-a
    t = max(0.0, min(1.0, (p-a).dot(ab)/ab.length_squared))
    return (p-(a+ab*t)).length

def skin(lion, rig, clay):
    """Each part of the surface follows the bones it lies nearest, each bone
    holding within its own reach; a leg moves only its own side of the body,
    and the mane goes with the head, the neck and the chest, never the legs.
    The holds are then eased across the surface so no joint creases."""
    mesh = lion.data
    names = [name for name in ORDER if name != 'root']
    tree = KDTree(len(clay.strands))
    for i, strand in enumerate(clay.strands): tree.insert(strand[0], i)
    tree.balance()
    weights = []
    tuft = set()
    for v in mesh.vertices:
        p = v.co
        at, index, distance = tree.find(p)
        in_mane = clay.strands[index][4] == 'mane' and distance < clay.strands[index][2]*1.6
        # (The tail's tuft goes with its last bone, whole.)
        if clay.strands[index][4] == 'tail' and distance < clay.strands[index][2]*2.5: tuft.add(v.index)
        row = {}
        for name in names:
            if name.endswith('_l') and p.x < -.02: continue
            if name.endswith('_r') and p.x > .02: continue
            if in_mane and name not in TRUNK: continue
            hold = HOLD[name.rstrip('12345').split('_')[0]]
            d = distance_to_segment(p, BONES[name][0], BONES[name][1])/hold
            row[name] = 1.0/(.05+d)**4
        weights.append(row)
    # Eased over the surface: each vertex takes on some of its neighbours'.
    links = [[] for v in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        links[a].append(b)
        links[b].append(a)
    for step in range(3):
        eased = []
        for i, row in enumerate(weights):
            total = dict(row)
            for j in links[i]:
                for name, w in weights[j].items():
                    if name in row or not (name.endswith(('_l', '_r'))): total[name] = total.get(name, 0.0)+w
            share = 1.0/(1+len(links[i]))
            eased.append({name: w*share for name, w in total.items()})
        weights = eased
    groups = {name: lion.vertex_groups.new(name=name) for name in names}
    for i in tuft: weights[i] = {'tail5': 1.0}
    for i, row in enumerate(weights):
        best = sorted(row.items(), key=lambda item: -item[1])[:4]
        total = sum(w for name, w in best)
        for name, w in best:
            if w/total > .01: groups[name].add([i], w/total, 'REPLACE')
    lion.parent = rig
    modifier = lion.modifiers.new('rig', 'ARMATURE')
    modifier.object = rig

# ---- Posing ----

def turn(pitch=0.0, yaw=0.0, roll=0.0):
    """A turn of the body, in degrees: nose up, to its left, and rolled to its right."""
    return (Matrix.Rotation(math.radians(yaw), 3, 'Z') @ Matrix.Rotation(math.radians(-pitch), 3, 'X') @ Matrix.Rotation(math.radians(-roll), 3, 'Y')).to_quaternion()

def swing(a, b):
    """The smallest turn carrying direction `a` to `b`."""
    return a.normalized().rotation_difference(b.normalized())

LEGS = {'fl': ('upperarm_l', 'forearm_l', 'forepaw_l', 'foretoes_l'), 'fr': ('upperarm_r', 'forearm_r', 'forepaw_r', 'foretoes_r'),
    'hl': ('thigh_l', 'shin_l', 'hindpaw_l', 'hindtoes_l'), 'hr': ('thigh_r', 'shin_r', 'hindpaw_r', 'hindtoes_r')}

class Pose:
    """One frame: the turn of each bone from rest, where the hips are, and
    how far each shoulder blade has slid over the ribs."""
    strain = 0.0

    def __init__(self, rest):
        self.rest = rest
        self.turns = {name: Quaternion() for name in ORDER}
        self.slides = {}
        self.shift = Vector((0, 0, 0))
        self.heads = {}

    def head(self, name):
        """Where a bone starts, the bones before it having turned."""
        if name in self.heads: return self.heads[name]
        parent = BONES[name][2]
        if parent is None: at = BONES[name][0].copy()
        else: at = self.head(parent)+self.turns[parent] @ (BONES[name][0]-BONES[parent][0]+self.slides.get(name, Vector((0, 0, 0))))
        if name == 'hips': at = at+self.shift
        self.heads[name] = at
        return at

    def body(self, hips=None, spine=None, chest=None, neck=None, head=None, shift=None):
        if shift is not None: self.shift = Vector(shift)
        for name, value in (('hips', hips), ('spine', spine), ('chest', chest), ('neck', neck), ('head', head)):
            if value is not None: self.turns[name] = value
        self.heads = {}

    def tail(self, lifts, sways):
        """The tail, bone by bone: raised `lifts` degrees from where it hangs,
        swung `sways` degrees to the left."""
        for i in range(5):
            self.turns['tail%d' % (i+1)] = self.turns['hips'] @ (Matrix.Rotation(math.radians(-sways[i]), 3, 'Z') @ Matrix.Rotation(math.radians(lifts[i]), 3, 'X')).to_quaternion()

    def leg(self, key, offset, pitch=0.0, curl=0.0, slide=0.0):
        """Stands a leg with the ball of its paw `offset` from where it rests,
        the paw rolled forward over its toes by `pitch` degrees and the toes
        curled under by `curl`; `slide` carries the shoulder forward. Two-bone
        IK bends the leg: the elbow back, the knee forward."""
        upper, lower, paw, toes = LEGS[key]
        front = key[0] == 'f'
        if slide: self.slides[upper] = Vector((0, -slide, 0))
        for name in (upper, lower, paw, toes): self.heads.pop(name, None)
        start = self.head(upper)
        ball = BONES[toes][0]+Vector(offset)
        paw_turn = Matrix.Rotation(math.radians(pitch), 3, 'X').to_quaternion()
        target = ball-paw_turn @ (BONES[toes][0]-BONES[paw][0])
        first = (BONES[upper][1]-BONES[upper][0]).length
        second = (BONES[lower][1]-BONES[lower][0]).length
        along = target-start
        Pose.strain = max(Pose.strain, along.length/(first+second))
        d = max(abs(first-second)+.01, min(first+second-.003, along.length))
        along.normalize()
        target = start+along*d
        a = (first*first-second*second+d*d)/(2*d)
        h = math.sqrt(max(0.0, first*first-a*a))
        pole = Vector((0, 1 if front else -1, 0))
        pole = (pole-along*pole.dot(along)).normalized()
        joint = start+along*a+pole*h
        self.turns[upper] = swing(BONES[upper][1]-BONES[upper][0], joint-start)
        self.turns[lower] = swing(BONES[lower][1]-BONES[lower][0], target-joint)
        self.turns[paw] = paw_turn
        self.turns[toes] = Matrix.Rotation(math.radians(curl), 3, 'X').to_quaternion()
        self.heads[lower] = joint
        self.heads[paw] = target
        self.heads[toes] = target+paw_turn @ (BONES[toes][0]-BONES[paw][0])

    def stand(self, *keys):
        for key in keys or LEGS: self.leg(key, (0, 0, 0))

    def key(self, rig, frame):
        poses = {}
        for name in ORDER:
            rest = self.rest[name]
            pose = Matrix.Translation(self.head(name)) @ (self.turns[name].to_matrix() @ rest.to_3x3()).to_4x4()
            poses[name] = pose
            parent = BONES[name][2]
            if parent is None: basis = rest.inverted() @ pose
            else: basis = (poses[parent] @ (self.rest[parent].inverted() @ rest)).inverted() @ pose
            bone = rig.pose.bones[name]
            bone.rotation_quaternion = basis.to_quaternion()
            bone.keyframe_insert('rotation_quaternion', frame=frame)
            if name in ('root', 'hips') or name.startswith(('upperarm', 'thigh')):
                bone.location = basis.to_translation()
                bone.keyframe_insert('location', frame=frame)

def ease(t):
    t = max(0.0, min(1.0, t))
    return t*t*(3.0-2.0*t)

def through(keys, u):
    """A value carried smoothly through [u, value] keys (numbers or vectors):
    it does not stop at a key, only at the first and the last."""
    count = len(keys)
    for i in range(count-1):
        if u <= keys[i+1][0] or i == count-2:
            u0, p0 = keys[i]
            u1, p1 = keys[i+1]
            m0 = (p1-keys[i-1][1])/(u1-keys[i-1][0]) if i > 0 else (p1-p0)*0.0
            m1 = (keys[i+2][1]-p0)/(keys[i+2][0]-u0) if i+2 < count else (p1-p0)*0.0
            h = u1-u0
            t = max(0.0, min(1.0, (u-u0)/h))
            return p0*(2*t**3-3*t*t+1)+m0*(h*(t**3-2*t*t+t))+p1*(-2*t**3+3*t*t)+m1*(h*(t**3-t*t))
    return keys[-1][1]

def wave(u, turns=1.0, lag=0.0):
    return math.sin((u*turns-lag)*math.tau)

def idle(pose, u):
    """Standing watch: it breathes, shifts its weight from side to side,
    looks slowly about, and its tail swings."""
    breath = wave(u, 2)
    sway = wave(u)
    pose.body(shift=(sway*.012, 0, breath*.005-.004), hips=turn(roll=sway*1.6, yaw=-sway*.8), spine=turn(pitch=breath*.5), chest=turn(pitch=breath*1.0, roll=-sway*.8),
        neck=turn(pitch=5+breath*.8, yaw=wave(u, 1, .1)*7), head=turn(pitch=2+wave(u, 2, .2)*1.5, yaw=wave(u, 1, .16)*13, roll=wave(u, 1, .2)*3))
    pose.tail([4+3*wave(u, 2, .1*i) for i in range(5)], [(5+5*i)*wave(u, 2, .12*i) for i in range(5)])
    pose.stand()

# The trot. Each diagonal pair of legs lands together, the two pairs half a
# stride apart; a paw is on the ground for DUTY of the stride and sweeps
# REACH either side of where it stands, so, as authored (STRIDE seconds a
# stride), the lion covers 2*REACH/(DUTY*STRIDE) metres a second
# (LION_STRIDE_SPEED in scripts/visual.gd).
LANDS = {'fl': 0.0, 'hr': .03, 'fr': .5, 'hl': .53}
DUTY = .42
REACH = .38
STRIDE = .4

def run(pose, u):
    # The body rises between the pairs' footfalls and sinks onto each; the
    # hips swing toward the hind leg coming forward, the shoulders the other
    # way, and the head is carried level.
    bounce = math.cos((u*2.0-.42)*math.tau)
    twist = wave(u, 1, .1)
    pose.body(shift=(0, 0, -.025-.03*bounce), hips=turn(pitch=1.2*bounce, yaw=7*twist, roll=2.5*twist), spine=turn(pitch=-1.0*bounce, yaw=2*twist),
        chest=turn(pitch=-1.5*bounce, yaw=-5*twist, roll=-2*twist), neck=turn(pitch=9+1.5*bounce, yaw=-2*twist), head=turn(pitch=1-2*bounce, yaw=1.5*twist))
    pose.tail([34+5*wave(u, 2, .1*i)-5*i for i in range(5)], [(4+4*i)*wave(u, 1, .14*i) for i in range(5)])
    for key, lands in LANDS.items():
        p = (u-lands) % 1.0
        front = key[0] == 'f'
        neutral = -.07 if front else .04
        if p < DUTY:
            # On the ground, sweeping back under the body; it rolls up onto
            # its toes as it leaves.
            s = p/DUTY
            forward = REACH*(1.0-2.0*s)
            roll = 34*ease((s-.55)/.45)
            pose.leg(key, (0, neutral-forward, 0), roll, 0.0, forward*.22 if front else 0.0)
        else:
            # In the air: folded up behind, carried forward, reached out to land.
            s = (p-DUTY)/(1.0-DUTY)
            forward = REACH*(2.0*ease(s)-1.0)
            lift = (.25 if front else .2)*math.sin(s**.85*math.pi)
            pitch = through([(0, 34.0), (.3, 78.0), (.72, -14.0), (1, 0.0)], s)
            curl = through([(0, 0.0), (.3, 40.0), (.75, -12.0), (1, 0.0)], s)
            pose.leg(key, (0, neutral-forward, lift), pitch, curl, forward*.22 if front else 0.0)

# The blow lands this far through the Attack clip (LION_SWIPE in
# scripts/combat_animation.gd).
CONTACT = .5

def attack(pose, u):
    """It sinks back onto its haunches and rears, the right forepaw drawn up
    and out wide beside its head; then the whole body uncoils behind the paw
    as it rakes forward and across at chest height, and it drops back onto
    its forefeet."""
    gather, reared, struck, down = .16, .38, CONTACT, .72
    def k(*values):
        return through(list(zip((0, gather, reared, struck, down, 1), values)), u)
    back = k(0, .07, .17, -.21, -.06, 0)
    low = k(0, -.07, -.17, -.09, -.02, 0)
    wind = k(0, -6, -24, 28, 12, 0)
    pose.body(shift=(k(0, .01, .04, -.05, -.01, 0), back, low),
        hips=turn(pitch=k(0, -3, 24, 9, 2, 0), yaw=wind*.2),
        spine=turn(pitch=k(0, -4, 36, 13, 3, 0), yaw=wind*.5, roll=-wind*.15),
        chest=turn(pitch=k(0, -8, 48, 14, 3, 0), yaw=wind, roll=-wind*.4),
        neck=turn(pitch=k(5, -10, 50, 6, 4, 5), yaw=wind*.55),
        head=turn(pitch=k(2, -6, 30, -14, 0, 2), yaw=wind*.4, roll=-wind*.3))
    pose.tail([k(4, 22, 44, 60, 30, 4)-6*i for i in range(5)], [-wind*(.5+.35*i) for i in range(5)])
    pose.stand('hl', 'hr')
    # The right forepaw: off the ground, up and out to the right; through the
    # blow, forward and across; down and home.
    right = through([(0, V(0, 0, 0)), (gather, V(-.04, .05, .12)), (reared, V(-.44, -.02, 1.62)), (struck, V(.30, -.86, .82)), (down-.08, V(.38, -.50, .26)), (down+.1, V(.10, -.12, .03)), (1, V(0, 0, 0))], u)
    pose.leg('fr', right, k(0, 30, 72, -38, 12, 0), k(0, 20, 50, -30, 0, 0), k(0, 0, -.06, .09, .03, 0))
    # The left comes up under the chest as it rears and lands first.
    left = through([(0, V(0, 0, 0)), (gather, V(0, 0, 0)), (reared, V(.10, -.02, .66)), (struck, V(.12, -.26, .34)), (down-.1, V(.04, -.14, 0)), (1, V(0, 0, 0))], u)
    pose.leg('fl', left, k(0, 0, 64, 26, 0, 0), k(0, 0, 40, 10, 0, 0))

def hit(pose, u):
    """A blow to the body: it flinches back and down, and gathers itself."""
    jolt = through([(0, 0.0), (.2, 1.0), (.55, -.18), (.8, .05), (1, 0.0)], u)
    lag = through([(0, 0.0), (.3, 1.0), (.65, -.2), (1, 0.0)], u)
    pose.body(shift=(0, jolt*.075, -jolt*.045), hips=turn(pitch=-3*jolt), spine=turn(pitch=-5*jolt), chest=turn(pitch=-9*jolt, roll=4*jolt),
        neck=turn(pitch=5+12*lag, yaw=-8*lag), head=turn(pitch=2+10*lag, yaw=-6*lag))
    pose.tail([4+34*lag-4*i*lag for i in range(5)], [12*lag*i for i in range(5)])
    pose.stand()

def hit_head(pose, u):
    """A blow to the head: it is knocked aside and shaken off."""
    jolt = through([(0, 0.0), (.18, 1.0), (.5, -.28), (.78, .1), (1, 0.0)], u)
    lag = through([(0, 0.0), (.28, 1.0), (.62, -.2), (1, 0.0)], u)
    pose.body(shift=(-jolt*.03, lag*.03, -lag*.02), hips=turn(yaw=-2*lag), chest=turn(yaw=8*lag, roll=5*lag),
        neck=turn(pitch=5-9*jolt, yaw=20*jolt), head=turn(pitch=2-8*jolt, yaw=34*jolt, roll=18*jolt))
    pose.tail([4+22*lag for i in range(5)], [-10*lag*i for i in range(5)])
    pose.stand()

def hit_stagger(pose, u):
    """A heavy blow: it is driven back onto its haunches, a forepaw thrown out
    to catch itself, and it heaves itself up."""
    jolt = through([(0, 0.0), (.18, 1.0), (.5, .72), (.82, .08), (1, 0.0)], u)
    lag = through([(0, 0.0), (.26, 1.0), (.6, .5), (1, 0.0)], u)
    pose.body(shift=(jolt*.05, jolt*.19, -jolt*.15), hips=turn(pitch=10*jolt, roll=-7*jolt, yaw=-5*jolt), spine=turn(pitch=5*jolt, roll=3*jolt),
        chest=turn(pitch=-7*jolt, roll=10*jolt, yaw=7*jolt), neck=turn(pitch=5-20*lag, yaw=-14*lag), head=turn(pitch=2-14*lag, yaw=-16*lag, roll=-9*lag))
    pose.tail([4+50*lag-7*i*lag for i in range(5)], [16*lag*i for i in range(5)])
    pose.stand('hl', 'hr', 'fr')
    catch = through([(0, V(0, 0, 0)), (.14, V(.05, .05, .12)), (.3, V(.11, .13, 0)), (.62, V(.11, .13, 0)), (.8, V(.05, .06, .08)), (1, V(0, 0, 0))], u)
    pose.leg('fl', catch, through([(0, 0.0), (.14, 45.0), (.3, 0.0), (.62, 0.0), (.8, 40.0), (1, 0.0)], u))

def sit(pose, u):
    """Sitting on its haunches, forelegs straight under the shoulders, head
    up: a statue's pose."""
    pose.body(shift=(0, -.20, -.56), hips=turn(pitch=44), spine=turn(pitch=36), chest=turn(pitch=20), neck=turn(pitch=14), head=turn(pitch=0))
    # The tail lies on the ground, curled round its left side.
    for i, way in enumerate((V(.3, 1, -.75), V(.8, .6, -.12), V(1, .1, 0), V(.85, -.5, 0), V(.5, -.85, .02))):
        pose.turns['tail%d' % (i+1)] = swing(TAIL[i+1]-TAIL[i], way)
    pose.heads = {}
    pose.stand('fl', 'fr')
    # The hind feet lie forward along the ground from the hocks, knees up and
    # out beside the belly.
    for key, s in (('hl', 1), ('hr', -1)): pose.leg(key, (.06*s, -.47, .008), -76.0, 0.0)

# name: (pose, frames)
CLIPS = {'Idle': (idle, 120), 'Run': (run, round(STRIDE*FPS)), 'Attack': (attack, 26), 'Hit': (hit, 12), 'HitHead': (hit_head, 12), 'HitStagger': (hit_stagger, 20), 'Sit': (sit, 2)}

def animate(rig):
    rest = {name: rig.data.bones[name].matrix_local.copy() for name in ORDER}
    rig.animation_data_create()
    for name, (maker, frames) in CLIPS.items():
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        Pose.strain = 0.0
        for frame in range(frames+1):
            pose = Pose(rest)
            maker(pose, frame/frames)
            pose.key(rig, frame)
        print('LION_CLIP', name, frames, 'frames; the furthest a leg reaches is %.0f%% of its length' % (Pose.strain*100))
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.action_frame_end = frames
    for bone in rig.pose.bones:
        bone.rotation_quaternion = Quaternion()
        bone.location = Vector((0, 0, 0))

if __name__ == '__main__':
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    lion, clay = build_body()
    rig = build_rig()
    skin(lion, rig, clay)
    face = build_face()
    face.parent = rig
    for obj in (lion, face):
        # (Blue 0 tells the statue shader to read the normal map by the UVs.)
        mask = obj.data.color_attributes.new('StoneMask', 'BYTE_COLOR', 'POINT')
        for item in mask.data: item.color = (1.0, 1.0, 0.0, 1.0)
    bpy.ops.object.select_all(action='DESELECT')
    face.select_set(True)
    lion.select_set(True)
    bpy.context.view_layer.objects.active = lion
    bpy.ops.object.join()
    lion.data.color_attributes.active_color = lion.data.color_attributes['StoneMask']
    lion.data.color_attributes.render_color_index = lion.data.color_attributes.active_color_index
    for m in list(bpy.data.materials): bpy.data.materials.remove(m)
    animate(rig)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
        export_nla_strips=True, export_force_sampling=True, export_skins=True, export_def_bones=False, export_yup=True, export_vertex_color='ACTIVE')
    print('LION_READY', len(lion.data.vertices), sum(len(p.vertices)-2 for p in lion.data.polygons), tuple(round(d, 2) for d in lion.dimensions))
