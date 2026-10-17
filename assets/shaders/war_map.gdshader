shader_type spatial;
// The bandits' maps and battle plans, laid out on the war table in the
// arena basement's last room (scripts/temple.gd war_table): old parchment,
// stained and foxed, its edge ragged and scorched, drawn on in brown ink.
// `kind` 0 is a map: a coast and its hills hatched in, rivers, a grid, a
// route marked in red with an arrow, and X marks where they mean to strike.
// `kind` 1 is a page of plans: rows of a cramped hand, and a sketch of a
// walled place with arrows closing on it. `seed` makes each sheet its own.
render_mode cull_disabled;
uniform float kind = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * weight;
		p *= 2.03;
		weight *= 0.5;
	}
	return total;
}
// Ink along a line of thickness `w` at distance `d`.
float stroke(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w, d);
}
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 uv = UV;
	vec2 s = vec2(seed * 3.7, seed * 1.9);
	// The ragged, scorched edge: torn away beyond it.
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rag = edge + (fbm(uv * 9.0 + s) - 0.5) * 0.06;
	if (rag < 0.012) discard;
	vec3 parchment = mix(vec3(0.74, 0.63, 0.44), vec3(0.83, 0.74, 0.55), fbm(uv * 4.0 + s));
	// Foxing and old stains, a ring where a cup once stood.
	parchment *= 1.0 - 0.22 * smoothstep(0.55, 0.8, fbm(uv * 2.3 + s + 4.0));
	parchment *= 1.0 - 0.12 * smoothstep(0.7, 0.85, noise(uv * 30.0 + s));
	float cup = abs(length(uv - vec2(0.78, 0.26) - s * 0.01) - 0.09);
	parchment *= 1.0 - 0.18 * stroke(cup, 0.012) * step(0.5, fract(seed * 0.37 + 0.2));
	// Darkened toward the edge, scorched at it.
	parchment *= mix(0.55, 1.0, smoothstep(0.012, 0.09, rag));
	parchment = mix(vec3(0.12, 0.07, 0.03), parchment, smoothstep(0.012, 0.03, rag));
	vec3 ink = vec3(0.17, 0.1, 0.05);
	vec3 red = vec3(0.5, 0.07, 0.04);
	float dark = 0.0;
	float redness = 0.0;
	if (kind < 0.5) {
		// Land and sea: the coast, and contour of the hills hatched across.
		float land = fbm(uv * 2.6 + s);
		dark = max(dark, stroke(abs(land - 0.5), 0.012));
		float hills = smoothstep(0.62, 0.66, land) * stroke(abs(fract((uv.x + uv.y) * 70.0) - 0.5), 0.25) * 0.6;
		dark = max(dark, hills);
		// The sea shaded by close strokes along its shore.
		float shore = smoothstep(0.5, 0.46, land) * smoothstep(0.38, 0.46, land);
		dark = max(dark, shore * stroke(abs(fract(uv.y * 90.0) - 0.5), 0.2) * 0.4);
		// A river or two winding down to it.
		float river = abs(fbm(uv * vec2(1.5, 5.0) + s + 9.0) - 0.5);
		dark = max(dark, stroke(river, 0.006) * smoothstep(0.48, 0.55, land) * 0.8);
		// A faint grid.
		vec2 cell = abs(fract(uv * 6.0) - 0.5);
		dark = max(dark, stroke(0.5 - max(cell.x, cell.y), 0.012) * 0.25);
		// The route, dashed in red, and its arrowhead.
		float y = 0.5 + 0.18 * sin(uv.x * 5.0 + seed * 2.0) + 0.06 * sin(uv.x * 13.0 + seed);
		float dashed = step(0.4, fract(uv.x * 22.0));
		redness = stroke(abs(uv.y - y), 0.012) * dashed * step(0.12, uv.x) * step(uv.x, 0.82);
		float tip_y = 0.5 + 0.18 * sin(0.82 * 5.0 + seed * 2.0) + 0.06 * sin(0.82 * 13.0 + seed);
		vec2 tip = vec2(0.86, tip_y);
		redness = max(redness, stroke(segment(uv, tip, tip + vec2(-0.06, 0.05)), 0.014));
		redness = max(redness, stroke(segment(uv, tip, tip + vec2(-0.06, -0.05)), 0.014));
		redness = max(redness, stroke(segment(uv, tip + vec2(-0.04, 0.0), tip), 0.014));
		// X marks: where they mean to strike.
		for (int i = 0; i < 3; i++) {
			vec2 at = vec2(0.2 + 0.25 * float(i), 0.25 + 0.45 * hash(vec2(seed, float(i))));
			float x = min(segment(uv, at - 0.03, at + 0.03), segment(uv, at + vec2(-0.03, 0.03), at + vec2(0.03, -0.03)));
			if (i == 2) redness = max(redness, stroke(x, 0.012));
			else dark = max(dark, stroke(x, 0.01));
		}
	} else {
		// Rows of a cramped hand, down the left of the page.
		float row = fract(uv.y * 16.0);
		float line_no = floor(uv.y * 16.0);
		float words = step(0.35, noise(vec2(uv.x * 28.0, line_no * 3.1) + s)) * step(0.3, noise(vec2(uv.x * 6.0, line_no) + s));
		float scrawl = stroke(abs(row - 0.5 - 0.15 * sin(uv.x * 220.0 + line_no)), 0.12);
		float length_of = 0.45 + 0.1 * hash(vec2(line_no, seed));
		dark = scrawl * words * step(0.08, uv.x) * step(uv.x, length_of) * step(0.08, uv.y) * step(uv.y, 0.92);
		// The sketch: a walled place, and arrows closing on it.
		vec2 c = vec2(0.73, 0.5);
		vec2 q = abs(uv - c) - vec2(0.11, 0.14);
		float wall = abs(max(q.x, q.y));
		dark = max(dark, stroke(wall, 0.01));
		dark = max(dark, stroke(abs(length(uv - c - vec2(0.11, 0.14)) - 0.03), 0.01));
		for (int i = 0; i < 3; i++) {
			float a = 2.4 + float(i) * 1.1;
			vec2 from = c + vec2(cos(a), sin(a)) * 0.3;
			vec2 to = c + vec2(cos(a), sin(a)) * 0.19;
			vec2 back = normalize(from - to);
			vec2 side = vec2(-back.y, back.x);
			float arrow = min(segment(uv, from, to), min(segment(uv, to, to + (back + side) * 0.035), segment(uv, to, to + (back - side) * 0.035)));
			redness = max(redness, stroke(arrow, 0.012));
		}
	}
	// Ink soaked into the grain, unevenly.
	float soak = 0.75 + 0.25 * noise(uv * 60.0 + s);
	vec3 colour = mix(parchment, ink, clamp(dark, 0.0, 1.0) * 0.85 * soak);
	colour = mix(colour, red, clamp(redness, 0.0, 1.0) * 0.85 * soak);
	ALBEDO = colour;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
