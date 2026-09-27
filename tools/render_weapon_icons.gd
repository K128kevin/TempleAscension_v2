extends SceneTree
## Bake transparent HUD icons from the actual imported weapon meshes.
func _initialize(): call_deferred("render_icons")
func render_icons():
	var viewport = SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	viewport.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30,-25,0)
	light.light_energy = 1.6
	viewport.add_child(light)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.position = Vector3(0,1.1,5)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,1.1,0))
	DirAccess.make_dir_recursive_absolute("res://assets/ui")
	for weapon in ["spear","sword","bow","axe"]:
		var pivot = Node3D.new()
		viewport.add_child(pivot)
		pivot.position = Vector3(0,1.1,0)
		pivot.rotation.z = -.55
		var model = preload("res://scripts/assets.gd").model(weapon,Vector3(.65,2.35,.22) if weapon=="axe" else (Vector3(.65,2.1,.25) if weapon=="bow" else Vector3(.35,2.45,.18)))
		pivot.add_child(model)
		model.position.y = -1.15
		var bounds = AABB()
		var first = true
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var box: AABB = mesh.global_transform*mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var center = bounds.get_center()
		camera.size = maxf(bounds.size.x,bounds.size.y)*1.2
		camera.position = center+Vector3(0,0,5)
		camera.look_at(center)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/ui/weapon-%s.png" % weapon)
		pivot.queue_free()
		await process_frame
	print("WEAPON_ICONS_READY")
	quit()
