shader_type sky;
// What the world's metal and polish reflect (scripts/reflections.gd): a
// photographed sky (a Poly Haven HDRI) tinted and dimmed to match the scene's
// own light, its sun clipped (the scene's sun lights the highlights), and, by
// night, the generated sky-only image, which is also the
// background the camera sees then. Without a sky to reflect, full metal is
// drawn near black.
uniform sampler2D panorama : filter_linear;
uniform sampler2D night_panorama : source_color, filter_linear, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform float energy = 1.0;
uniform float saturation = 1.0;
// (The HDRI's sun and brightest clouds are held to this.)
uniform float clip = 3.0;
uniform float night = 0.0;
uniform float night_energy = 1.0;
// A photographer's studio instead of a sky (`studio` 1: previews, item
// pictures and the inventory's figure, all seen straight on): bright
// overhead, a light grey all round the horizon, a darker floor, so a blade
// or plate turned to the camera shows as bright steel.
uniform float studio = 0.0;

void sky() {
	vec3 day = min(texture(panorama, SKY_COORDS).rgb, vec3(clip));
	vec3 soft = mix(vec3(0.32, 0.31, 0.3), mix(vec3(0.85, 0.85, 0.86), vec3(1.15, 1.15, 1.18), smoothstep(0.1, 0.8, EYEDIR.y)), smoothstep(-0.35, 0.05, EYEDIR.y));
	day = mix(day, soft, studio);
	float grey = dot(day, vec3(0.2126, 0.7152, 0.0722));
	day = mix(vec3(grey), day, saturation) * tint * energy;
	float azimuth = atan(EYEDIR.x, -EYEDIR.z);
	float elevation = asin(clamp(EYEDIR.y, -1.0, 1.0));
	// Concentrate the image's native detail into the opening's northern
	// 90 x 45 degree sector, rather than stretching it around all 360 degrees.
	// The texture contains only sky: the ground mesh creates the horizon.
	// The wider mapping's moon lies behind this sector, keeping one visible moon.
	vec2 night_uv = vec2(fract(0.62 + azimuth / TAU),
		clamp(0.55 - elevation / PI, 0.001, 0.999));
	vec2 opening_uv = vec2(0.5 + azimuth / (PI * 0.5),
		0.55 - elevation / (PI * 0.25));
	vec2 inside = smoothstep(vec2(0.0), vec2(0.035), opening_uv)
		* (1.0 - smoothstep(vec2(0.965), vec2(1.0), opening_uv));
	float opening = inside.x * inside.y;
	// Read the full-resolution image; bilinear sampling avoids pixel blocks
	// without choosing a coarser mip level for the visible sky.
	vec3 wide = textureLod(night_panorama, night_uv, 0.0).rgb;
	vec3 detail = textureLod(night_panorama, clamp(opening_uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
	vec3 dark = mix(wide, detail, opening) * night_energy;
	COLOR = mix(day, dark, night);
}
