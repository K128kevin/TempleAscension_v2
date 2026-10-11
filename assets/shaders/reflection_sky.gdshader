shader_type sky;
// What the world's metal and polish reflect (scripts/reflections.gd): a
// photographed sky (a Poly Haven HDRI) tinted and dimmed to match the scene's
// own light, its sun clipped (the scene's sun lights the highlights), and, by
// night, the painted night sky (tools/make_night_sky.py), which is also the
// background the camera sees then. Without a sky to reflect, full metal is
// drawn near black.
uniform sampler2D panorama : filter_linear;
uniform sampler2D night_panorama : source_color, filter_linear;
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
	vec3 dark = texture(night_panorama, SKY_COORDS).rgb * night_energy;
	COLOR = mix(day, dark, night);
}
