extends Node3D
## Turns about its up axis at `rate` radians a second, carrying with it
## whatever it holds: particles in its own space (local_coords) are swept round
## with it, as Ice Storm's snow whirls about the wizard (scripts/wizard_fx.gd).
var rate = 1.0

func _process(dt: float) -> void:
	rotate_y(rate*dt)
