extends SceneTree
## Check the continuous town-to-horizon terrain, shared material, welded
## topology and outer-edge occlusion from the opening camera.
const Horizon = preload("res://scripts/world_horizon.gd")
const Overworld = preload("res://scripts/overworld.gd")
const Data = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var passed: Array[String] = []
var failed: Array[String] = []

func _initialize() -> void: call_deferred("test")
func check(ok: bool, message: String) -> void:
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func test() -> void:
	Save.directory = ProjectSettings.globalize_path("res://test-results/desert-horizon-save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	game.start_intro()
	var world = game.world
	var terrain: MeshInstance3D = world.get_node("DesertGround")
	var arrays = terrain.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check(vertices.size()>10000 and indices.size()>60000,"The horizon is a tessellated 3D ground surface")
	check(terrain==world.ground and terrain.material_override==world.ground_material and terrain.layers==world.GROUND_LAYER,"Town and distant hills share the exact same ground mesh, material and lighting layer")
	var paint: Texture2D = terrain.material_override.get_shader_parameter("control")
	check(paint.get_width()==Overworld.WIDTH and paint.get_height()==Overworld.DEPTH and world.get_node_or_null("DistantDesertGround")==null,"One shared paint map replaces the separate extension's blank texture")
	check(world.reflection_sky.get_shader_parameter("night_panorama").resource_path=="res://assets/textures/desert_sky_only.png","The outdoor background and reflections use the sky-only image")
	# The palace centre can include a building's raised floor; sample the
	# exposed ground at the plateau edge instead.
	check(world.lift(Overworld.START)==Overworld.DUNE_HEIGHT and world.height_at(Overworld.HILL.x-Overworld.HILL_HALF.x,Overworld.HILL.z)==Overworld.HILL_HEIGHT,"The camp dune and palace ground retain their heights")
	var centre = Vector2((Overworld.WEST+Overworld.EAST)*.5,(Overworld.NORTH+Overworld.SOUTH)*.5)
	check(centre==Horizon.CENTRE and Horizon.INNER_HALF==Vector2(Overworld.WIDTH,Overworld.DEPTH)*.5+Vector2.ONE*Horizon.FLAT_MARGIN,"The flat interior extends beyond the map's rock rim")
	var flat = true
	for i in Horizon.SEGMENTS:
		var p = Vector2(vertices[i].x,vertices[i].z)
		var outside = (p-centre).abs()-Vector2(Overworld.WIDTH,Overworld.DEPTH)*.5
		# ArrayMesh packs normals; compare against the same packed normal at
		# the centre rather than requiring an unquantized Vector3.UP.
		flat = flat and maxf(outside.x,outside.y)>Overworld.RIM and vertices[i].y==0.0 and normals[i]==normals[-1] and normals[i].y>.9999
	check(flat and vertices[-1]==Vector3(centre.x,0,centre.y),"The map and its perimeter remain exactly flat, with identical upward shading normals")
	var clockwise = true
	var edges: Dictionary = {}
	for i in range(0,indices.size(),3):
		var a = vertices[indices[i]]
		clockwise = clockwise and (vertices[indices[i+1]]-a).cross(vertices[indices[i+2]]-a).y<0.0
		for side in 3:
			var start = indices[i+side]
			var end = indices[i+(side+1)%3]
			var key = Vector2i(mini(start,end),maxi(start,end))
			edges[key] = edges.get(key,0)+1
	var outer_start = Horizon.RINGS*Horizon.SEGMENTS
	var outer_end = outer_start+Horizon.SEGMENTS
	var boundaries = 0
	var welded = true
	for edge in edges:
		if edges[edge]==1:
			boundaries += 1
			welded = welded and edge.x>=outer_start and edge.y<outer_end
		else: welded = welded and edges[edge]==2
	check(welded and boundaries==Horizon.SEGMENTS,"Every interior edge is welded; only the hidden outer skirt has a mesh boundary")
	var shallow = normals.size()==vertices.size()
	for normal in normals: shallow = shallow and normal.y>.9
	check(clockwise and shallow,"Terrain faces and normals point upward, with shallow slopes")
	var foothills = 0.0
	var distant = 0.0
	for ring in Horizon.RINGS+1:
		for i in Horizon.SEGMENTS:
			var height = vertices[ring*Horizon.SEGMENTS+i].y
			if float(ring)/Horizon.RINGS<.12: foothills = maxf(foothills,height)
			distant = maxf(distant,height)
	check(foothills<3.0 and distant>28.0 and distant<50.0,"Hills grow gently from the flat map into larger distant crests (%.1f m near, %.1f m far)" % [foothills,distant])
	var eye: Vector3 = world.camera.position
	var forward: Vector3 = -world.camera.global_basis.z
	var heading = atan2(forward.x,-forward.z)
	var skyline: Array[float] = []; skyline.resize(41); skyline.fill(-INF)
	var skirt: Array[float] = []; skirt.resize(41); skirt.fill(-INF)
	var furthest = 0.0
	for i in vertices.size():
		var ray = vertices[i]-eye
		furthest = maxf(furthest,ray.length())
		var azimuth = rad_to_deg(wrapf(atan2(ray.x,-ray.z)-heading,-PI,PI))
		if absf(azimuth)>41.0: continue
		var bin = clampi(roundi((azimuth+40.0)/2.0),0,40)
		var elevation = rad_to_deg(atan2(ray.y,Vector2(ray.x,ray.z).length()))
		skyline[bin] = maxf(skyline[bin],elevation)
		if i>=outer_start and i<outer_end: skirt[bin] = maxf(skirt[bin],elevation)
	var hidden = true
	for i in skyline.size(): hidden = hidden and is_finite(skyline[i]) and is_finite(skirt[i]) and skyline[i]>skirt[i]+.4
	var low: float = skyline.min()
	var high: float = skyline.max()
	check(hidden,"Dune crests hide the outer mesh edge across the opening view")
	check(high<.75 and low> -5.0 and high-low>.35 and high-low<2.5,"The skyline has broad rolling hills (%.2f to %.2f degrees)" % [low,high])
	check(furthest<world.camera.far*.9,"The far plane lies beyond all distant terrain")
	for path in ["res://assets/shaders/reflection_sky.gdshader","res://assets/shaders/desert_ground.gdshader"]:
		var shader: Shader = load(path)
		check(not shader.get_shader_uniform_list().is_empty(),"Shader parses: "+path.get_file())
	FileAccess.open("res://test-results/desert-horizon.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed,"skyline_degrees":[low,high],"furthest_vertex":furthest},"  "))
	print("DESERT_HORIZON ",passed.size()," passed; ",failed)
	game.free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
