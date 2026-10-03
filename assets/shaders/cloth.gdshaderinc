// The townspeople's clothes (tools/make_townsfolk.py): photographed weave,
// dyed one colour, and worn out as far as `wear` says. A garment's UVs are in
// metres over the cloth; its second UV set carries how near the hem or cuff a
// point is (x) and how far down the garment's length (y).
uniform sampler2D weave : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 dye = vec3(0.7, 0.65, 0.55);
uniform float weave_scale = 5.0;
// 0 kept and whole; about 0.5 faded, stained and patched; 1 rags: frayed
// hems, holes, filth.
uniform float wear = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

void fragment() {
	float edge = UV2.x;
	// (The exporter turns a UV's second coordinate over.)
	float length_down = 1.0 - UV2.y;
	vec2 at = UV + vec2(seed * 3.7, seed * 1.3);
	// Rags: the hem and cuffs are eaten away in tatters, and holes worn through.
	float streak = texture(grit, vec2(at.x * 3.1, at.y * 0.6)).r;
	float fray = smoothstep(0.35, 1.0, wear);
	if (edge > 1.0 - fray * (0.15 + streak * 1.5)) discard;
	float hole = texture(grit, at * 1.3).r * 0.7 + texture(grit, at * 4.1).r * 0.3;
	if (wear > 0.75 && hole > 1.02 - (wear - 0.75) * 0.9 && length_down > 0.18) discard;
	// The weave against its own average (its smallest mip), so the dye is the
	// cloth's colour.
	float weave_level = dot(textureLod(weave, vec2(0.5), 12.0).rgb, vec3(0.333));
	float thread = dot(texture(weave, UV * weave_scale).rgb, vec3(0.333)) / weave_level;
	vec3 colour = dye * mix(1.0, thread, 0.85);
	// Sun and washing take the dye out unevenly.
	float fade = texture(grit, at * 0.55).r;
	colour = mix(colour, vec3(dot(colour, vec3(0.333))) * 1.12, wear * 0.45 * smoothstep(0.3, 0.7, fade));
	// Patches: squares of other cloth, sewn on with dark thread.
	vec2 grid = at * vec2(4.6, 3.8);
	vec2 cell = floor(grid);
	vec2 within = fract(grid);
	float chance = hash(cell);
	if (chance < (wear - 0.35) * 0.55) {
		vec2 size = vec2(0.2 + hash(cell + 3.1) * 0.25, 0.2 + hash(cell + 7.7) * 0.25);
		vec2 from_middle = abs(within - 0.5);
		if (from_middle.x < size.x && from_middle.y < size.y) {
			float thread_across = dot(texture(weave, UV.yx * weave_scale * 1.2).rgb, vec3(0.333)) / weave_level;
			colour = dye * mix(vec3(0.72, 0.74, 0.8), vec3(1.2, 1.1, 0.95), hash(cell + 11.3)) * mix(1.0, thread_across, 0.85);
			float stitch = step(max(size.x - from_middle.x, 0.0), 0.035) + step(max(size.y - from_middle.y, 0.0), 0.035);
			if (stitch > 0.0 && fract((within.x + within.y) * 14.0) < 0.55) colour *= 0.45;
		}
	}
	// Dirt: ground in everywhere, heaviest toward the hem.
	float soil = texture(grit, at * 0.9).r * 0.6 + texture(grit, at * 2.9).r * 0.4;
	float grime = wear * (0.3 + 0.6 * smoothstep(0.4, 1.0, length_down)) * smoothstep(0.3, 0.62, soil + length_down * 0.15);
	colour = mix(colour, colour * vec3(0.4, 0.34, 0.27), clamp(grime, 0.0, 1.0));
#ifdef INSIDE
	// The cloth's inside, seen through a tear or up a sleeve: in its own shade.
	ALBEDO = colour * 0.3;
#else
	ALBEDO = colour;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
#endif
}
