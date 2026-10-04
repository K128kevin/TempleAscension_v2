extends Node3D
## The original 28 x 15 court, 1.5-tile pool inset and solid 2 x 2 centerpiece.
const Art = preload("res://scripts/assets.gd")
var room_bounds: Rect2
var pool_bounds: Rect2
var center = Vector3.ZERO
var ambience: AudioStreamPlayer
var water_materials: Array[ShaderMaterial] = []
var water_time = 0.0
var wakes = PackedVector4Array()
var wake_index = 0
var wake_cooldown = 0.0
var last_wader = Vector3.INF
var fountain_gain = 0.0

func setup(layout) -> void:
	name = "FountainCourt"
	var corner: Vector3 = layout.to_world(layout.court.position)-Vector3(.5,0,.5)
	room_bounds = Rect2(Vector2(corner.x,corner.z),Vector2(layout.court.size))
	pool_bounds = room_bounds.grow(-1.5)
	center = layout.to_world(layout.court_obstacle.position)+Vector3(.5,0,.5)
	wakes.resize(8)
	var trim = Art.material("stone",Color(.72,.76,.69))
	var inlay = Art.material("marble",Color(.20,.43,.39))
	for z in [pool_bounds.position.y-.18,pool_bounds.end.y+.18]:
		model("floor",Vector3(pool_bounds.get_center().x,-.01,z),Vector3(pool_bounds.size.x+.72,.13,.36),trim)
		model("floor",Vector3(pool_bounds.get_center().x,.115,z),Vector3(pool_bounds.size.x+.72,.008,.07),inlay)
	for x in [pool_bounds.position.x-.18,pool_bounds.end.x+.18]:
		model("floor",Vector3(x,-.01,pool_bounds.get_center().y),Vector3(.36,.13,pool_bounds.size.y),trim)
		model("floor",Vector3(x,.115,pool_bounds.get_center().y),Vector3(.07,.008,pool_bounds.size.y),inlay)
	# The lowest bowl's spill lands in the pool about a metre from the axis.
	water(Vector3(pool_bounds.get_center().x,.10,pool_bounds.get_center().y),pool_bounds.size,0.0,1.0)
	var stone = Art.material("marble",Color(.65,.70,.68)).duplicate()
	stone.emission_enabled = true
	stone.emission = Color(.055,.06,.058)
	model("column",center,Vector3(1.95,.18,1.95),stone)
	# Three decreasing stone bowls reuse the authored chalice mesh, including
	# its hollow bowl and stem, to match the original fountain silhouette.
	# (Each bowl's water takes the spill of the bowl above it, a little out
	# from where it leaves that bowl's rim.)
	for tier in [[1.85,.18,.85,.7],[1.28,.90,.68,.45],[.74,1.48,.52,0.0]]:
		var width: float = tier[0]
		var bottom: float = tier[1]
		var height: float = tier[2]
		model("chalice",center+Vector3.UP*bottom,Vector3(width,height,width),stone)
		water(center+Vector3.UP*(bottom+height-.055),Vector2.ONE*width*.82,width*.41,tier[3])
		spill(center+Vector3.UP*(bottom+height-.04),width*.43)
	# A restricted fill makes the stone tiers readable without introducing
	# light-selection seams across the compatibility renderer's floor batches.
	var light = OmniLight3D.new()
	light.position = center+Vector3.UP*3.2
	light.light_color = Color(.65,.78,.78)
	light.light_energy = 1.0
	light.omni_range = 5
	light.light_cull_mask = 4
	add_child(light)
	ambience = AudioStreamPlayer.new()
	ambience.name = "OriginalFountainTrickle"
	var stream: AudioStreamWAV = preload("res://assets/audio/fountain-trickle.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	ambience.stream = stream
	ambience.volume_linear = 0
	add_child(ambience)
	ambience.play()

func model(id: String, at: Vector3, size: Vector3, material: Material) -> Node3D:
	var node = Art.model(id,size,material)
	if id in ["column","chalice"]:
		for mesh in node.find_children("*","MeshInstance3D",true,false): mesh.layers = 4
	node.position = at
	add_child(node)
	return node

# A water surface (assets/shaders/pool_water.gdshader): `radius` cuts a bowl's
# to a disc; `splash` is how far from the axis the spill above lands on it.
func water(at: Vector3, size: Vector2, radius: float = 0.0, splash: float = 0.0) -> void:
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/pool_water.gdshader")
	material.set_shader_parameter("center",Vector2(center.x,center.z))
	material.set_shader_parameter("radius",radius)
	material.set_shader_parameter("splash",splash)
	material.set_shader_parameter("wakes",wakes)
	water_materials.append(material)
	var surface = model("floor",at,Vector3(size.x,.008,size.y),material)
	for mesh in surface.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func spill(at: Vector3, radius: float) -> void:
	var particles = CPUParticles3D.new()
	particles.position = at
	particles.amount = 72
	particles.lifetime = .65
	particles.preprocess = .65
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	var points = PackedVector3Array()
	var normals = PackedVector3Array()
	for i in 8:
		var direction = Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
		points.append(direction*radius)
		normals.append((direction+Vector3.UP*.15).normalized())
	particles.emission_points = points
	particles.emission_normals = normals
	particles.spread = 4
	particles.initial_velocity_min = .18
	particles.initial_velocity_max = .35
	particles.gravity = Vector3(0,-3.5,0)
	particles.scale_amount_min = .025
	particles.scale_amount_max = .045
	var imported = Art.model("gem",Vector3.ONE)
	particles.mesh = imported.find_children("*","MeshInstance3D",true,false)[0].mesh
	imported.free()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(.70,.90,.90,.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(.12,.22,.23)
	material.roughness = .2
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)

func gain_at(player_position: Vector3) -> float:
	var p = Vector2(player_position.x,player_position.z)
	if not room_bounds.has_point(p): return 0.0
	var distance = p.distance_to(Vector2(center.x,center.z))
	return clampf(1.0-distance/(room_bounds.size.length()*.5),0,1)

func tick(dt: float, player_position: Vector3, playing: bool) -> void:
	# Use player-to-fountain distance, never camera distance or zoom. One
	# continuous loop changes gain without restarting, exactly as in LevelScene.
	fountain_gain = gain_at(player_position) if playing else 0.0
	ambience.volume_linear = fountain_gain
	if not playing: return
	water_time += dt
	wake_cooldown -= dt
	if pool_bounds.has_point(Vector2(player_position.x,player_position.z)) and last_wader.is_finite() and player_position.distance_to(last_wader)>.015 and wake_cooldown<=0:
		wakes[wake_index] = Vector4(player_position.x,player_position.z,water_time,1)
		wake_index = (wake_index+1)%8
		wake_cooldown = .16
	last_wader = player_position
	for material in water_materials:
		material.set_shader_parameter("water_time",water_time)
		material.set_shader_parameter("wakes",wakes)

func _exit_tree() -> void:
	if is_instance_valid(ambience): ambience.stop()
