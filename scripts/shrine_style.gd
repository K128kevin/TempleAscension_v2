extends StyleBox
## Full-resolution stone, fixed-width corners and repeating edge tiles. The
## top edge/corner are reflected around the frame so every side is identical.
const SOURCE_BORDER_RATIO = 28.0/192.0
var texture: Texture2D
var modulate_color = Color.WHITE
var region_rect = Rect2()
var draw_center = true
var texture_margin_left = 16.0
var texture_margin_top = 16.0
var texture_margin_right = 16.0
var texture_margin_bottom = 16.0

func set_texture_margin(side: Side, width: float) -> void:
	match side:
		SIDE_LEFT: texture_margin_left = width
		SIDE_TOP: texture_margin_top = width
		SIDE_RIGHT: texture_margin_right = width
		SIDE_BOTTOM: texture_margin_bottom = width

func set_texture_margin_all(width: float) -> void:
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: set_texture_margin(side,width)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	for part in patches(rect):
		var at: Rect2 = part.destination
		var points = PackedVector2Array([at.position,Vector2(at.end.x,at.position.y),at.end,Vector2(at.position.x,at.end.y)])
		var uv = PackedVector2Array()
		for corner in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			var sample: Vector2 = Vector2(corner.y,corner.x) if part.transpose else corner
			if part.flip_x: sample.x = 1-sample.x
			if part.flip_y: sample.y = 1-sample.y
			uv.append((part.source.position+sample*part.source.size)/texture.get_size())
		RenderingServer.canvas_item_add_polygon(to_canvas_item,points,PackedColorArray([modulate_color]),uv,texture.get_rid())

# Keeping the render patches available also allows layout checks without a GPU.
func patches(rect: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if texture == null or not rect.has_area(): return result
	var source: Rect2 = region_rect if region_rect.has_area() else Rect2(Vector2.ZERO,texture.get_size())
	var source_border: float = minf(source.size.x,source.size.y)*SOURCE_BORDER_RATIO
	# One scale in both axes, including when a very small button is drawn.
	var border = minf(minf(texture_margin_left,texture_margin_top),minf(rect.size.x,rect.size.y)*.5)
	if border<=0: return result
	var centre = rect.grow(-border)
	var body = source.grow(-source_border)
	if draw_center and centre.has_area():
		# Native-sized grain: crop/repeat rather than magnifying a small bitmap.
		var y = centre.position.y
		while y<centre.end.y:
			var height = minf(body.size.y,centre.end.y-y)
			var x = centre.position.x
			while x<centre.end.x:
				var width = minf(body.size.x,centre.end.x-x)
				result.append(patch(Rect2(x,y,width,height),Rect2(body.position,Vector2(width,height))))
				x += width
			y += height
	var corner = Rect2(source.position,Vector2.ONE*source_border)
	for bottom in [false,true]:
		for right in [false,true]:
			result.append(patch(Rect2(Vector2(rect.end.x-border if right else rect.position.x,rect.end.y-border if bottom else rect.position.y),Vector2.ONE*border),corner,false,right,bottom))
	var edge = Rect2(source.position+Vector2(source_border,0),Vector2(source.size.x-source_border*2,source_border))
	var scale = border/source_border
	var tile_length = edge.size.x*scale
	for vertical in [false,true]:
		var start = centre.position.y if vertical else centre.position.x
		var end = centre.end.y if vertical else centre.end.x
		while start<end:
			var length = minf(tile_length,end-start)
			var sample = Rect2(edge.position,Vector2(length/scale,source_border))
			for opposite in [false,true]:
				var at = Rect2(Vector2(rect.end.x-border if opposite else rect.position.x,start),Vector2(border,length)) if vertical else Rect2(Vector2(start,rect.end.y-border if opposite else rect.position.y),Vector2(length,border))
				result.append(patch(at,sample,vertical,false,opposite))
			start += length
	return result

func patch(destination: Rect2, source: Rect2, transpose: bool = false, flip_x: bool = false, flip_y: bool = false) -> Dictionary:
	return {"destination":destination,"source":source,"transpose":transpose,"flip_x":flip_x,"flip_y":flip_y}
