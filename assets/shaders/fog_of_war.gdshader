shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D visibility_mask : filter_linear;
uniform vec3 camera_position;
uniform vec3 camera_right;
uniform vec3 camera_up;
uniform vec3 camera_forward;
uniform float camera_size;
uniform float viewport_aspect;
uniform vec2 map_world_origin;
uniform vec2 map_dimensions;

void fragment() {
	vec3 ray_origin = camera_position
		+ camera_right * ((SCREEN_UV.x - 0.5) * camera_size * viewport_aspect)
		+ camera_up * ((0.5 - SCREEN_UV.y) * camera_size);
	float ray_length = -ray_origin.y / camera_forward.y;
	vec3 ground = ray_origin + camera_forward * ray_length;
	vec2 mask_uv = (ground.xz - map_world_origin + vec2(0.5)) / map_dimensions;
	float seen = 0.0;
	if (all(greaterThanEqual(mask_uv, vec2(0.0))) && all(lessThanEqual(mask_uv, vec2(1.0)))) {
		seen = smoothstep(0.15, 0.85, texture(visibility_mask, mask_uv).r);
	}
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(mix(vec3(0.008, 0.011, 0.018), scene, seen), 1.0);
}
