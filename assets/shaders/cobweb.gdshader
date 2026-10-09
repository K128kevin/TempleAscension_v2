shader_type spatial;
// A spider web (scripts/basement_props.gd web, wall_web), drawn over a sheet
// laid round its hub: UV.x the angle round it (0 to 1), UV.y the distance out
// (0 at the hub, 1 at the rim), UV2.x the web's size in metres. Straight
// radial threads from the hub to a frame thread at the rim; a spiral of
// catching thread wound out over them, sagging between each pair of radials;
// a tangle at the hub. Old and grey: torn through in places, a radial or two
// snapped, and furred with dust, which shows whitest where the threads are
// thickest. Each thread keeps its own width at any size and distance,
// fading where it is finer than a pixel rather than breaking up.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert, specular_disabled;
uniform vec3 silk : source_color = vec3(0.86, 0.85, 0.82);
uniform float opacity = 0.85;
// Thread widths (metres): the radials and frame, the spiral.
uniform float radial_width = 0.03;
uniform float spiral_width = 0.022;
const float RADIALS = 17.0;
const float SPIRALS = 15.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// How much of this pixel a thread covers: `d`, how far off its centre line
// (in its own units), `half_width` its half width (the same units).
float thread(float d, float half_width) {
	float pixel = max(fwidth(d), 1e-5);
	float cover = clamp(half_width / pixel, 0.0, 1.0);
	return clamp((max(half_width, pixel * 0.5) - d) / pixel + 0.5, 0.0, 1.0) * cover;
}

void fragment() {
	float size = UV2.x;
	float r = UV.y;
	// Each radial a little off even.
	float a = UV.x * RADIALS;
	float which = floor(a + 0.5);
	float wobble = (hash(vec2(which, 3.0)) - 0.5) * 0.25 * smoothstep(0.0, 0.4, r);
	float da = abs(fract(a + 0.5 + wobble) - 0.5);
	// Metres along the arc between radials, here.
	float arc = 6.2832 * r * size * 0.45 / RADIALS;
	float radial = thread(da * arc, radial_width * 0.5) * step(0.03, r);
	// A snapped radial, hanging only part way out.
	if (hash(vec2(which, 9.0)) < 0.18 && r > 0.25 + 0.5 * hash(vec2(which, 1.0))) radial = 0.0;
	// The spiral, wound out from the hub, each turn sagging toward the hub
	// between radials.
	float between = fract(a + 0.5 + wobble);
	float q = r * SPIRALS - UV.x + 0.12 * sin(between * 3.1416);
	float dq = abs(fract(q + 0.5) - 0.5);
	float spiral = thread(dq * size * 0.45 / SPIRALS, spiral_width * 0.5) * smoothstep(0.1, 0.16, r) * (1.0 - smoothstep(0.93, 0.95, r));
	// Torn through in patches.
	float tear = noise(vec2(UV.x * 7.0, r * 5.0) + 4.7);
	spiral *= smoothstep(0.24, 0.32, tear);
	radial *= smoothstep(0.12, 0.2, tear + 0.1);
	// The frame thread round the rim, and the tangle at the hub.
	float frame = thread(abs(r - 0.965) * size * 0.45, radial_width * 0.6);
	float hub = smoothstep(0.1, 0.0, r) * (0.35 + 0.65 * noise(UV * vec2(60.0, 40.0)));
	float strands = max(max(radial, spiral), max(frame, hub));
	// Dust: a fine fur over the threads, and a faint film where it is thick.
	float dust = noise(vec2(UV.x * 140.0, r * 90.0));
	float film = noise(vec2(UV.x * 9.0, r * 6.0) + 1.3) * smoothstep(0.35, 0.0, r);
	ALBEDO = silk * (0.82 + 0.3 * dust);
	EMISSION = silk * 0.22;
	ALPHA = clamp(strands * (0.7 + 0.3 * dust) + film * 0.35, 0.0, 1.0) * opacity;
}
