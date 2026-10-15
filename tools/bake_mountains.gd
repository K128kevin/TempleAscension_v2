extends SceneTree
## Bakes the outdoor world's mountains (scripts/world_mountains.gd) into
## assets/models/mountains.scn, so the world need not build them each time
## it is loaded. Rerun whenever their shape or the ground's edges change.
##   Godot --headless --path . --script tools/bake_mountains.gd
const Mountains = preload("res://scripts/world_mountains.gd")
func _initialize():
	var world = preload("res://scripts/overworld.gd").new()
	world.seed_noise()
	var range: Node3D = Mountains.generate(world)
	var scene = PackedScene.new()
	scene.pack(range)
	var error = ResourceSaver.save(scene,Mountains.BAKED,ResourceSaver.FLAG_COMPRESS)
	print("BAKED %d tiles: %s" % [range.get_child_count(),error_string(error)])
	world.free()
	range.free()
	quit()
