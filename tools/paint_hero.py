"""Paint the hero's kit into a new body texture, and cut a wood texture.

Run with Blender --background --python tools/paint_hero.py after
import_character.py. Every face of the supplied body is assigned a region from
its skin weights and rest-pose height: bronze scale armor (chest, back,
shoulders and upper arms), a leather belt, brown cloth shorts to mid-thigh,
leather forearm bracers, or bare skin. Scales are projected onto the body in 3D
from the existing bronze scale texture, so their size and direction stay
continuous across UV seams; skin comes from the character's original texture.
Cloth and leather are procedural. The result is baked through the body's own
UVs into assets/textures/hero_kit.png. No geometry is changed.

The tower shield's wood is the plank area of the Quaternius Fantasy Props
furniture trim sheet, cropped into assets/textures/wood_planks.png.
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
SKIN = ROOT/'source_art/universal_stage/T_Superhero_Male_Dark.png'
SCALES = ROOT/'assets/textures/bronze_scales.png'
TRIM = ROOT/'source_art/props/Textures/T_Trim_Furniture_BaseColor.png'
OUT = ROOT/'assets/textures'
SIZE = 2048
# Rest-pose heights (metres): cuirass above the belt, shorts to mid-thigh.
CUIRASS_BOTTOM = 1.05
BELT_BOTTOM = .97
SHORTS_BOTTOM = .66
# One tile of the scale texture spans this many metres on the body.
SCALE_TILE = .8

# Region colors written per face corner: R scales, G cloth, B leather;
# alpha below 1 darkens leather into the belt.
REGIONS = {'skin':(0,0,0,1),'scales':(1,0,0,1),'cloth':(0,1,0,1),'leather':(0,0,1,1),'belt':(0,0,1,.45)}


def region(bone: str, height: float) -> str:
    if bone.startswith(('Head','neck','hand','thumb','index','middle','ring','pinky')): return 'skin'
    if bone.startswith('lowerarm'): return 'leather'
    if bone.startswith(('upperarm','clavicle','spine_02','spine_03')): return 'scales'
    if bone.startswith(('spine_01','pelvis','root')):
        if height>=CUIRASS_BOTTOM: return 'scales'
        return 'belt' if height>=BELT_BOTTOM else 'cloth'
    if bone.startswith('thigh') and height>=SHORTS_BOTTOM: return 'cloth'
    return 'skin'


def paint_regions(body):
    # Per vertex, so region borders blend across a face instead of zigzagging
    # along triangle edges.
    names = {g.index:g.name for g in body.vertex_groups}
    attribute = body.data.color_attributes.new('Region','BYTE_COLOR','POINT')
    counts = {}
    for v in body.data.vertices:
        best = max(v.groups,key=lambda g:g.weight,default=None)
        name = region(names[best.group] if best else '',v.co.z)
        counts[name] = counts.get(name,0)+1
        attribute.data[v.index].color = REGIONS[name]
    print('HERO_REGIONS',counts)


def bake_material(body, target):
    mat = bpy.data.materials.new('HeroKitBake'); mat.use_nodes = True
    nodes = mat.node_tree.nodes; links = mat.node_tree.links
    nodes.clear()
    def node(kind, **settings):
        n = nodes.new(kind)
        for key,value in settings.items(): setattr(n,key,value)
        return n
    out = node('ShaderNodeOutputMaterial')
    emit = node('ShaderNodeEmission')
    links.new(emit.outputs[0],out.inputs['Surface'])
    skin = node('ShaderNodeTexImage'); skin.image = bpy.data.images.load(str(SKIN))
    coords = node('ShaderNodeTexCoord')
    mapping = node('ShaderNodeMapping')
    mapping.inputs['Scale'].default_value = (1/SCALE_TILE,)*3
    links.new(coords.outputs['Object'],mapping.inputs['Vector'])
    scales = node('ShaderNodeTexImage',projection='BOX',projection_blend=.25)
    scales.image = bpy.data.images.load(str(SCALES))
    links.new(mapping.outputs['Vector'],scales.inputs['Vector'])
    # Woven brown cloth: fine noise over faint horizontal and vertical threads.
    def material_color(scale, dark, light, weave):
        noise = node('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = scale; noise.inputs['Detail'].default_value = 8
        links.new(coords.outputs['Object'],noise.inputs['Vector'])
        ramp = node('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = dark; ramp.color_ramp.elements[1].color = light
        links.new(noise.outputs['Fac'],ramp.inputs['Fac'])
        if not weave: return ramp.outputs['Color']
        threads = node('ShaderNodeTexWave',wave_type='BANDS'); threads.inputs['Scale'].default_value = 140
        links.new(coords.outputs['Object'],threads.inputs['Vector'])
        mix = node('ShaderNodeMix',data_type='RGBA',blend_type='MULTIPLY')
        mix.inputs['Factor'].default_value = .18
        links.new(ramp.outputs['Color'],mix.inputs['A']); links.new(threads.outputs['Color'],mix.inputs['B'])
        return mix.outputs['Result']
    # Ramp colors are linear: a mid brown cloth and a dark leather on screen.
    cloth = material_color(160,(.045,.02,.007,1),(.11,.05,.02,1),True)
    leather = material_color(35,(.018,.009,.004,1),(.055,.026,.012,1),False)
    attribute = node('ShaderNodeVertexColor'); attribute.layer_name = 'Region'
    split = node('ShaderNodeSeparateColor')
    links.new(attribute.outputs['Color'],split.inputs['Color'])
    # The belt is the same leather, darkened.
    belt = node('ShaderNodeMix',data_type='RGBA',blend_type='MULTIPLY')
    links.new(leather,belt.inputs['A']); belt.inputs['B'].default_value = (.55,.55,.55,1)
    invert = node('ShaderNodeMath',operation='SUBTRACT'); invert.inputs[0].default_value = 1
    links.new(attribute.outputs['Alpha'],invert.inputs[1])
    darken = node('ShaderNodeMath',operation='MULTIPLY'); darken.inputs[1].default_value = 1.8
    links.new(invert.outputs[0],darken.inputs[0]); links.new(darken.outputs[0],belt.inputs['Factor'])
    color = skin.outputs['Color']
    for factor,layer in [(split.outputs['Blue'],belt.outputs['Result']),(split.outputs['Green'],cloth),(split.outputs['Red'],scales.outputs['Color'])]:
        mix = node('ShaderNodeMix',data_type='RGBA')
        links.new(factor,mix.inputs['Factor']); links.new(color,mix.inputs['A']); links.new(layer,mix.inputs['B'])
        color = mix.outputs['Result']
    links.new(color,emit.inputs['Color'])
    bake = node('ShaderNodeTexImage'); bake.image = target
    nodes.active = bake
    body.data.materials.clear(); body.data.materials.append(mat)


def paint_hero():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/character/warrior.glb'))
    rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks: track.mute = True
    rig.animation_data.action = None
    rig.data.pose_position = 'REST'
    body = next(o for o in bpy.data.objects if o.type=='MESH' and 'SuperHero' in o.name)
    paint_regions(body)
    target = bpy.data.images.new('hero_kit',SIZE,SIZE)
    bake_material(body,target)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'; scene.cycles.samples = 1; scene.cycles.device = 'CPU'
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True); bpy.context.view_layer.objects.active = body
    bpy.ops.object.bake(type='EMIT',margin=16)
    target.filepath_raw = str(OUT/'hero_kit.png'); target.file_format = 'PNG'; target.save()
    print('HERO_KIT_READY')


def cut_wood():
    # The trim sheet's upper band is plain planks; keep only that area.
    trim = bpy.data.images.load(str(TRIM))
    w,h = trim.size
    top = int(h*.42)
    pixels = list(trim.pixels)
    band = pixels[(h-top)*w*4:]
    wood = bpy.data.images.new('wood_planks',w,top)
    wood.pixels = band
    wood.filepath_raw = str(OUT/'wood_planks.png'); wood.file_format = 'PNG'; wood.save()
    print('WOOD_READY',w,top)


cut_wood()
paint_hero()
