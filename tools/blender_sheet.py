"""A contact sheet of a clip as it is authored, rendered in Blender itself
(the Workbench engine), for judging a swing without exporting the model
and reimporting it into the game: the figure at a row of moments, seen from
his right, from the front and from the front right quarter, with a stand-in
for the weapon hung on the right fist.

Used by tools/import_skills.py and tools/import_heavy.py when SHEET_DIR is
set: each clip they author is written there as <clip>-<view>-<n>.png, and
tools/sheet_compose.py lays them out.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Matrix

# (The 'game' and 'rear' views look down at the game's own angle, 43 degrees
# (scripts/overworld.gd VIEW), from his front right and from behind his left.)
VIEWS = {'side': ((-6.0, 0.25, 1.0), (0.0, 0.25, 1.0)), 'front': ((0.0, -6.0, 1.0), (0.0, 0.0, 1.0)), 'game': ((-3.6, -3.6, 5.6), (0.0, 0.0, 0.9)), 'rear': ((3.6, 3.6, 5.6), (0.0, 0.0, 0.9)), 'quarter': ((-4.2, -4.2, 2.6), (0.0, 0.0, 0.95)), 'top': ((0.0, 0.3, 8.0), (0.0, 0.3, 0.0))}

def prop(rig, bone, seat, parts, name='WeaponStandIn'):
    """A stand-in weapon hung on `bone`: `parts` are (z0, z1, radius) runs
    of a cylinder along the bone's own Z through `seat` (x, y in the
    bone's space)."""
    bpy.ops.object.select_all(action='DESELECT')
    made = []
    for z0, z1, r in parts:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1-z0, location=(0, 0, 0), vertices=12)
        o = bpy.context.active_object
        o.name = name
        for v in o.data.vertices: v.co = Vector((v.co.x+seat[0], v.co.y+seat[1], v.co.z+(z0+z1)/2))
        o.parent = rig
        o.parent_type = 'BONE'
        o.parent_bone = bone
        o.matrix_parent_inverse = Matrix.Translation((0, -rig.pose.bones[bone].bone.length, 0))
        o.matrix_basis = Matrix.Identity(4)
        m = bpy.data.materials.new(name)
        m.diffuse_color = (.85, .1, .1, 1)
        o.data.materials.append(m)
        made.append(o)
    return made

def setup(rig):
    sc = bpy.context.scene
    # (Only the warrior's own shells are shown: the other classes' bodies and
    # clothes, which share the model, would hide him.)
    for o in bpy.data.objects:
        if o.type == 'MESH' and (o.name.startswith(('Ranger', 'Wizard', 'Icosphere'))): o.hide_render = True
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True
    sc.display.shading.show_cavity = False
    sc.render.resolution_x = 360
    sc.render.resolution_y = 400
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.film_transparent = False
    bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.name = 'SheetFloor'
    m = bpy.data.materials.new('SheetFloor')
    m.diffuse_color = (.35, .35, .38, 1)
    floor.data.materials.append(m)
    cam_data = bpy.data.cameras.new('SheetCam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 2.9
    cam = bpy.data.objects.new('SheetCam', cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam

def aim(cam, at, target):
    cam.location = Vector(at)
    d = Vector(target)-Vector(at)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()

def render(rig, name, phases, out_dir, pose, views=('side', 'front', 'game', 'rear')):
    """`pose(t)` sets the figure at `t` of the clip; each phase is rendered
    from each view."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    cam = bpy.data.objects.get('SheetCam') or setup(rig)
    sc = bpy.context.scene
    for i, t in enumerate(phases):
        pose(t)
        for view in views:
            aim(cam, *VIEWS[view])
            sc.render.filepath = str(out/('%s-%s-%02d.png' % (name, view, i)))
            bpy.ops.render.render(write_still=True)
    (out/(name+'.phases')).write_text(' '.join('%.3f' % t for t in phases))
    print('SHEET_RENDERED', name, out)
