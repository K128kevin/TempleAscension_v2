extends MeshInstance3D
## The wake of a hard sword cut: a translucent sweep of air trailing behind
## the blade for a moment, to show the force and speed of the cut. It is drawn
## only; nothing about the swing or its blow depends on it.
##
## The blade's place is taken each tick while the cut is on (scripts/visual.gd)
## and a ribbon is drawn through the places of the last LIFE seconds, curved
## smoothly through them, fading from the blade back
## (assets/shaders/sword_trail.gdshader).

# How long the air stays disturbed behind the blade (seconds).
const LIFE = .2
# Ribbon pieces between one tick's blade and the next.
const PIECES = 5
# [time, the blade's middle, its point, how full the wake is there], oldest
# first, in the world. (A wake starts thin: its first places fade in.)
var samples: Array = []
var taken = 0
var clock = 0.0

func _init() -> void:
	top_level = true
	mesh = ImmediateMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sword_trail.gdshader")
	material_override = material

# A tick: `cutting`, the blade (from `inner` to `point`) leaves its wake.
func step(dt: float, cutting: bool, inner: Vector3, point: Vector3) -> void:
	clock += dt
	if cutting:
		samples.append([clock,inner,point,minf(1.0,taken/3.0)])
		taken += 1
	else: taken = 0
	while not samples.is_empty() and clock-samples[0][0] > LIFE: samples.remove_at(0)
	# A wake is one unbroken sweep: what is left of the last is gone before
	# the next cut begins.
	if not cutting and samples.size() < 2: samples.clear()
	draw()

func clear() -> void:
	samples.clear()
	draw()

func draw() -> void:
	global_transform = Transform3D.IDENTITY
	mesh.clear_surfaces()
	if samples.size() < 2: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var last = samples.size()-1
	for i in last:
		var a = samples[maxi(i-1,0)]; var b = samples[i]; var c = samples[i+1]; var d = samples[mini(i+2,last)]
		for piece in (PIECES+1 if i == last-1 else PIECES):
			var u = float(piece)/PIECES
			var age = clampf((clock-lerpf(b[0],c[0],u))/LIFE,0.0,1.0)
			mesh.surface_set_color(Color(1,1,1,lerpf(b[3],c[3],u)))
			mesh.surface_set_uv(Vector2(age,0.0))
			mesh.surface_add_vertex(b[1].cubic_interpolate(c[1],a[1],d[1],u))
			mesh.surface_set_color(Color(1,1,1,lerpf(b[3],c[3],u)))
			mesh.surface_set_uv(Vector2(age,1.0))
			mesh.surface_add_vertex(b[2].cubic_interpolate(c[2],a[2],d[2],u))
	mesh.surface_end()
