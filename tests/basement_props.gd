extends SceneTree
## The arena basement's dressing (scripts/basement_props.gd): broken statues,
## the dead, webs, the iron gate and its key, each built whole and to size.
const Props = preload("res://scripts/basement_props.gd")
const Actor = preload("res://scripts/actor.gd")
var passed = 0
var failures: Array = []

func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed += 1
	else:
		failures.append(message)
		push_error(message)

# The bounds of every mesh under `node`, in its parent's space.
func bounds(node: Node3D) -> AABB:
	var box = AABB()
	var first = true
	for mesh in node.find_children("*","MeshInstance3D",true,false) + ([node] if node is MeshInstance3D else []):
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var local: AABB = (node.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return node.transform*box

func actors(node: Node) -> int:
	return node.find_children("*","",true,false).filter(func(n): return n.get_script() == Actor).size()

func test():
	var world = Node3D.new()
	root.add_child(world)
	var rng = RandomNumberGenerator.new()
	rng.seed = 11

	# Broken statues: each a frozen figure on its plinth, damaged, no enemy.
	var seen: Dictionary = {}
	for i in 8:
		var statue: Node3D = Props.damaged_statue(rng)
		world.add_child(statue)
		var figure = statue.find_child("Figure",true,false)
		var damage: Array = statue.get_meta("damage")
		for d in damage: seen[d] = true
		check(figure != null and figure.skeleton != null and not figure.animator.is_playing(),"A statue's figure is posed and still")
		check(actors(statue) == 0,"A statue is no enemy")
		check(not damage.is_empty(),"Every statue is damaged")
		# (A skinned figure's bounds are its bind pose's, arms out: the plinth
		# and what lies about it are measured, and the figure's height.)
		figure.visible = false
		var box = bounds(statue)
		figure.visible = true
		var tall = bounds(statue).size.y
		check(box.size.x <= 1.6 and box.size.z <= 1.6,"A statue keeps to its plinth's footprint and the rubble round it: %s" % box)
		check(tall > 2.0 and tall < 2.7,"A statue stands about two and a half metres, plinth and all: %f" % tall)
		if "head" in damage:
			var broken = figure.find_children("*","MeshInstance3D",true,false).filter(func(m): return m.material_override is ShaderMaterial and float(m.material_override.get_shader_parameter("shatter_band")) > 0.0)
			check(not broken.is_empty(),"A headless statue's stone is broken off above the neck")
		if "arm" in damage: check(not figure.equipment.visible,"An armless statue has lost its blade with its forearm")
		statue.queue_free()
	check(seen.has("head") and seen.has("arm"),"Statues are broken in different ways: %s" % [seen.keys()])

	# The dead.
	for slumped in [false,true]:
		var remains: Node3D = Props.skeleton(rng,slumped)
		world.add_child(remains)
		var box = bounds(remains)
		check(remains is MeshInstance3D and remains.mesh.get_faces().size() > 3000,"The remains are one detailed mesh")
		check(actors(remains) == 0,"The remains are no enemy")
		if slumped: check(box.position.z >= -.18 and box.size.y > .5 and box.size.y < .9,"Slumped against the wall, he sits up off it, not through it: %s" % box)
		else: check(box.size.x > 1.4 and box.size.x < 2.1 and box.size.z < .95 and box.size.y < .35,"Sprawled, he lies along the floor: %s" % box)
		check(box.position.y > -.01,"The remains lie on the floor, not in it")
		remains.queue_free()
	var pile: Node3D = Props.bones(rng)
	world.add_child(pile)
	var heap = bounds(pile)
	check(heap.size.x < 1.0 and heap.size.z < 1.0 and heap.size.y < .25,"A few scattered bones: %s" % heap)

	# Webs: pale threads drawn by their shader, hung from y = 0 down.
	var web: MeshInstance3D = Props.web(1.1)
	world.add_child(web)
	var spread = bounds(web)
	check(web.material_override is ShaderMaterial and web.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"A web is drawn by its shader, casting no shadow")
	check(spread.position.x > -.01 and spread.position.z > -.01 and spread.end.y < .01 and spread.size.x <= 1.15 and spread.size.z <= 1.15,"A corner web stays in the room's angle: %s" % spread)
	var draped: MeshInstance3D = Props.wall_web(1.2)
	world.add_child(draped)
	spread = bounds(draped)
	check(spread.position.z > -.01 and spread.end.y < .01 and spread.size.x <= 1.35,"A wall web lies over the wall's face: %s" % spread)

	# The gate: two leaves, shut in the doorway, swinging open toward +Z.
	var gate: Node3D = Props.gate(1.4,2.3,3.2)
	world.add_child(gate)
	var left: Node3D = gate.get_node("LeafL")
	var right: Node3D = gate.get_node("LeafR")
	var shut = bounds(gate)
	check(absf(shut.size.x-(1.4+Props.JAMB.x*2.0)) < .05 and absf(shut.end.y-3.2) < .05,"The gate fills its doorway, jambs and lintel: %s" % shut)
	var tip = func(leaf: Node3D) -> Vector3: return leaf.transform*(leaf.get_node("Grille").position*2.0)
	check(absf(tip.call(left).z) < .01 and absf(tip.call(right).z) < .01,"Shut, both leaves lie across the doorway")
	Props.open_gate(gate,1.0)
	var swung_l: Vector3 = tip.call(left)-left.position
	var swung_r: Vector3 = tip.call(right)-right.position
	check(swung_l.z > .6 and swung_r.z > .6,"Opened, both leaves swing toward +Z")
	check(absf(rad_to_deg(absf(left.rotation.y))-95.0) < 1.0 and absf(rad_to_deg(absf(right.rotation.y))-95.0) < 1.0,"Fully open is about 95 degrees")
	Props.open_gate(gate,.5)
	check(absf(rad_to_deg(absf(left.rotation.y))-47.5) < 1.0,"Half open is half way")

	# The key.
	var key: Node3D = Props.key_model()
	world.add_child(key)
	var size = bounds(key).size
	check(absf(size.x-Props.KEY_LENGTH) < .02 and size.y < .03,"The key is about 0.2 metres long, lying flat: %s" % size)

	print("BASEMENT_PROPS ",passed," passed; ",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
