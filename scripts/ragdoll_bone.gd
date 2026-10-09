extends PhysicalBone3D
## One limb of a fallen man (scripts/ragdoll.gd): every physics step, held to
## Ragdoll.FASTEST and Ragdoll.SPIN at most, so a limb caught between his
## weight and the floor or a wall is never flung out by its joint, nor the
## body torn apart by it.
const Ragdoll = preload("res://scripts/ragdoll.gd")

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.linear_velocity.length_squared() > Ragdoll.FASTEST*Ragdoll.FASTEST:
		state.linear_velocity = state.linear_velocity.limit_length(Ragdoll.FASTEST)
	if state.angular_velocity.length_squared() > Ragdoll.SPIN*Ragdoll.SPIN:
		state.angular_velocity = state.angular_velocity.limit_length(Ragdoll.SPIN)
