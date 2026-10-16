extends RefCounted
## One continuous ground surface: flat under the playable map, then broad
## rolling dunes beyond its rock rim. There is no separate extension to join.
const SEGMENTS = 384
const RINGS = 64
const OUTER_RADIUS = 1750.0
const FLAT_MARGIN = 72.0
# Match Overworld's fixed map; the horizon test checks these bounds.
const CENTRE = Vector2(-152.0,118.0)
const INNER_HALF = Vector2(300.0,362.0)+Vector2.ONE*FLAT_MARGIN
static var mesh_cache: ArrayMesh

static func inner_radius(direction: Vector2) -> float:
	return minf(INNER_HALF.x/maxf(absf(direction.x),.00001),INNER_HALF.y/maxf(absf(direction.y),.00001))

static func height_at(p: Vector2) -> float:
	var offset = p-CENTRE
	var direction = offset.normalized()
	var angle = atan2(direction.y,direction.x)
	var inner = inner_radius(direction)
	var t = clampf((offset.length()-inner)/(OUTER_RADIUS-inner),0.0,1.0)
	if t<=.000001: return 0.0
	# Low foothills lead into taller rolling crests farther from town. The
	# broad height envelope starts with zero height and slope at the flat map.
	var crest = .39+.035*sin(angle*4.0+.8)
	var height = 27.0+6.0*sin(angle*3.0+.7)+4.0*sin(angle*7.0+1.2)+2.0*sin(angle*11.0-.4)
	var main = height*exp(-pow((t-crest)/.20,2.0))
	var foothills = (4.0+3.0*sin(angle*5.0-.6))*exp(-pow((t-.19-.025*sin(angle*3.0))/.09,2.0))
	var rolling = 2.5*sin(p.x*.012+sin(p.y*.004)*1.7)*sin(p.y*.009-.7)
	rolling *= smoothstep(.08,.23,t)*(1.0-smoothstep(.55,.7,t))
	var dune = (main+foothills+rolling)*smoothstep(0.0,.30,t)
	# The far skirt falls behind the crests, hiding the mesh's outer edge.
	return dune-55.0*smoothstep(.65,1.0,t)

static func terrain_mesh() -> ArrayMesh:
	if mesh_cache != null: return mesh_cache
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in RINGS+1:
		var t = float(ring)/RINGS
		for segment in SEGMENTS:
			var angle = float(segment)*TAU/SEGMENTS
			var direction = Vector2(cos(angle),sin(angle))
			var p = CENTRE+direction*lerpf(inner_radius(direction),OUTER_RADIUS,t)
			var normal = Vector3(height_at(p-Vector2.RIGHT)-height_at(p+Vector2.RIGHT),2.0,height_at(p-Vector2.DOWN)-height_at(p+Vector2.DOWN)).normalized()
			if ring==0: normal = Vector3.UP
			tool.set_normal(normal)
			tool.set_uv(p)
			tool.add_vertex(Vector3(p.x,height_at(p),p.y))
	var stride = SEGMENTS
	for ring in RINGS:
		for segment in SEGMENTS:
			var a = ring*stride+segment
			var b = ring*stride+(segment+1)%SEGMENTS
			# Godot's clockwise front faces, viewed from above.
			for corner in [a,a+stride,b+stride,a,b+stride,b]: tool.add_index(corner)
	# Fill the flat interior using the very same perimeter vertices and
	# material. No overlapping slab, doubled depth or material boundary.
	var centre_index = (RINGS+1)*SEGMENTS
	tool.set_normal(Vector3.UP)
	tool.set_uv(CENTRE)
	tool.add_vertex(Vector3(CENTRE.x,0.0,CENTRE.y))
	for segment in SEGMENTS:
		for corner in [centre_index,segment,(segment+1)%SEGMENTS]: tool.add_index(corner)
	mesh_cache = tool.commit()
	return mesh_cache

static func build(world, ground_material: ShaderMaterial) -> MeshInstance3D:
	ground_material.set_shader_parameter("sloped",1.0)
	var terrain = MeshInstance3D.new()
	terrain.name = "DesertGround"
	terrain.mesh = terrain_mesh()
	terrain.material_override = ground_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.layers = world.GROUND_LAYER
	world.add_child(terrain)
	return terrain
