extends SceneTree
## Draws the outdoor world's cells from above (open, solid, low) with its
## ground paint, to test-results/map-cells.png: one pixel per metre, north up.
##   Godot --headless --path . --script tools/map_dump.gd
func _initialize():
	var world = preload("res://scripts/overworld.gd").new()
	root.add_child(world)
	world.setup()
	var image = Image.create(world.WIDTH,world.DEPTH,false,Image.FORMAT_RGB8)
	for z in range(world.NORTH,world.SOUTH):
		for x in range(world.WEST,world.EAST):
			var i = world.index(x,z)
			var c = Color(.85,.75,.55)
			if world.paint[i*4+world.PAVING]>100: c = Color(.7,.7,.7)
			if world.paint[i*4+world.TRACK]>100: c = Color(.65,.5,.35)
			if world.paint[i*4+world.WATER]>100: c = Color(.2,.4,.8)
			if world.cells[i]==world.SOLID: c = Color(.25,.2,.18) if world.margins[i]<1.0 else Color(.6,.1,.1)
			elif world.cells[i]==world.LOW: c = c.lerp(Color(.1,.3,.9),.5)
			image.set_pixel(x-world.WEST,z-world.NORTH,c)
	for rock in world.rim_rocks: 
		var p = Vector2i(int(rock.x)-world.WEST,int(rock.z)-world.NORTH)
		if p.x>=0 and p.y>=0 and p.x<world.WIDTH and p.y<world.DEPTH: image.set_pixel(p.x,p.y,Color(0,0,0))
	image.resize(world.WIDTH*2,world.DEPTH*2,Image.INTERPOLATE_NEAREST)
	image.save_png("res://test-results/map-cells.png")
	print("MAP_DUMP done")
	quit()
