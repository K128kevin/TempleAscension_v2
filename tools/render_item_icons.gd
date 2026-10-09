extends SceneTree
## Pictures every item for the inventory: assets/ui/items/<id>.png, its own
## model (Art.item_model: what lies on the ground when it drops) on a clear
## ground, lit from the upper left. Run in a window (it renders):
##
##   Godot --path . --script tools/render_item_icons.gd [-- --only=id,id]
const Art = preload("res://scripts/assets.gd")
const Items = preload("res://scripts/items.gd")
const SIZE = 128
func _initialize(): call_deferred("render_icons")
func render_icons():
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = Array(a.trim_prefix("--only=").split(","))
	var viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE,SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = Node3D.new()
	viewport.add_child(scene)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .75
	scene.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,140,0)
	sun.light_energy = 1.4
	scene.add_child(sun)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.add_child(camera)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/items"))
	for id in Items.ALL:
		if not only.is_empty() and not id in only: continue
		var item: Dictionary = Items.ALL[id]
		var thing: Node3D = Art.item_model(id)
		var holder = Node3D.new()
		scene.add_child(holder)
		holder.add_child(thing)
		var box: AABB = thing.get_meta("bounds")
		thing.position = -box.get_center()
		# Weapons lean across the picture, point up to the right; a shield
		# faces out; what is worn is seen from the front quarter.
		var span: float = maxf(box.size.x,maxf(box.size.y,box.size.z))
		if item.slot == "weapon":
			holder.rotation = Vector3(0,0,-PI/4)
			span = box.size.y*.74
		elif item.slot == "shield": holder.rotation = Vector3(0,PI,0)
		# (A key, stood up off the table and leaning across the picture.)
		elif item.slot == "key": holder.rotation = Vector3(PI/2,0,PI/4)
		else: holder.rotation = Vector3(0,.5,0)
		camera.size = span*1.12
		camera.look_at_from_position(Vector3(0,span*.15 if item.slot not in ["weapon","shield"] else 0.0,4),Vector3.ZERO)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/ui/items/%s.png" % id)
		holder.queue_free()
		await process_frame
		print("ITEM_ICON ",id)
	quit(0)
