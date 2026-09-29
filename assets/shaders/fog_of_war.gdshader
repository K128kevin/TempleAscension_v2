shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Full-screen pass drawn after the scene. Each pixel's real world position is
// rebuilt from depth, so walls, columns and statues are judged by where they
// stand rather than by the floor point their pixel would cover if projected
// down to the ground.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D visibility_mask : filter_linear;
// 1 on the temple's floor cells; 0 off them (void, and outdoor stonework).
uniform sampler2D walkable_mask : filter_nearest;
uniform vec2 map_world_origin;
uniform vec2 map_dimensions;
// On a terrace or the summit the desert, the foundation and the storeys below
// are open-air scenery, not temple interior, and are never fogged.
uniform bool outdoors = false;
// Wall cells are not walkable and never marked seen. A raised face borrows the
// cell in front of it; a raised top borrows the brightest neighbouring cell.
const float FACE_REACH = 0.9;

float walkable_at(vec2 xz) {
	vec2 uv = (xz - map_world_origin + vec2(0.5)) / map_dimensions;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	return texture(walkable_mask, uv).r;
}

float mask_at(vec2 xz) {
	vec2 uv = (xz - map_world_origin + vec2(0.5)) / map_dimensions;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	return texture(visibility_mask, uv).r;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	vec3 forward = -INV_VIEW_MATRIX[2].xyz;
	float seen;
	if (world.y < -0.3) {
		// Below floor level: outdoors it is all visible scenery; indoors keep the
		// original ground-plane projection of the pixel's view ray.
		seen = outdoors ? 1.0 : mask_at((world - forward * (world.y / forward.y)).xz);
	} else if (outdoors && world.y <= 0.08 && walkable_at(world.xz) < 0.5) {
		// Outdoors, floor-height surfaces off the temple floor are the tops of
		// the storeys below: open-air scenery, never fogged.
		seen = 1.0;
	} else {
		seen = mask_at(world.xz);
		if (world.y > 0.08) {
			vec3 normal = normalize(cross(dFdx(world), dFdy(world)));
			if (dot(normal, forward) > 0.0) normal = -normal;
			vec2 across = normal.xz;
			if (length(across) > 0.5) {
				seen = max(seen, mask_at(world.xz + normalize(across) * FACE_REACH));
			} else {
				seen = max(seen, max(
					max(mask_at(world.xz + vec2(FACE_REACH, 0.0)), mask_at(world.xz - vec2(FACE_REACH, 0.0))),
					max(mask_at(world.xz + vec2(0.0, FACE_REACH)), mask_at(world.xz - vec2(0.0, FACE_REACH)))));
			}
		}
	}
	ALBEDO = vec3(0.008, 0.011, 0.018);
	ALPHA = 1.0 - smoothstep(0.15, 0.85, seen);
}
