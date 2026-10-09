shader_type spatial;
// Drawn over the arena basement's walls (scripts/temple.gd grime_walls): the
// filth of an old cellar on its dressed stone. Damp has risen from the floor
// to a ragged tide line, stained dark and greenish below it; water and soot
// have run down from the top in streaks; and the whole is mottled with grime.
// Where the wall is damaged (`spots`: up to SPOTS of them, each a point on
// its face and a radius), the dressed face has broken away to the rougher,
// paler stone behind, ragged at its edge and shadowed under its upper lip,
// with cracks running out across the face round it.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_disabled;
const int SPOTS = 3;
uniform vec4 spots[SPOTS];
uniform int spot_count = 0;
uniform vec3 grime : source_color = vec3(0.08, 0.065, 0.05);
uniform vec3 mould : source_color = vec3(0.09, 0.1, 0.06);
uniform vec3 broken : source_color = vec3(0.5, 0.44, 0.36);
varying vec3 world;

// (No sine: it loses its precision this far out in the world.)
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
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
	for (int i = 0; i < 4; i++) {
		total += noise(p) * weight;
		p *= 2.07;
		weight *= 0.5;
	}
	return total;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Along the wall (they all run along X or Z), and up it.
	float s = world.x + world.z;
	float h = world.y;
	vec2 face = vec2(s, h);
	// Rising damp, to a ragged tide line.
	float tide = 0.55 + 0.6 * fbm(vec2(s * 0.7, 3.0));
	float damp = 1.0 - smoothstep(tide - 0.25, tide + 0.05, h);
	// Streaks run down from the top, stronger high up.
	float run = noise(vec2(s * 4.5, h * 0.35 + 7.0 * noise(vec2(s * 1.3, 1.0))));
	float streak = smoothstep(0.55, 0.85, run) * smoothstep(0.4, 2.8, h);
	// Mottled grime all over.
	float mottle = smoothstep(0.42, 0.8, fbm(face * 1.4 + 5.0));
	vec3 colour = mix(grime, mould, damp * 0.7);
	float amount = damp * 0.62 + streak * 0.4 + mottle * 0.32;
	// Damage: broken away to the rough stone behind, cracks about it.
	for (int i = 0; i < SPOTS; i++) {
		if (i >= spot_count) break;
		vec3 c = spots[i].xyz;
		float r = spots[i].w;
		vec2 off = vec2(s - (c.x + c.z), h - c.y);
		float d = length(off);
		if (d > r * 2.6) continue;
		float edge = r * (0.75 + 0.45 * fbm(normalize(off + 1e-4) * 3.0 + vec2(float(i) * 7.1)));
		if (d < edge) {
			// The rough stone behind, gritty, sunk into the face: darkest deep in under the upper lip, the
			// lower lip catching the light.)
			float rough = fbm(face * 9.0 + float(i));
			float up = off.y / max(d, 1e-4);
			vec3 inner = broken * (0.45 + 0.5 * rough) * (0.55 + 0.45 * smoothstep(0.0, edge, d));
			inner *= 1.0 - 0.55 * smoothstep(-0.2, 0.9, up) * smoothstep(edge * 0.3, edge, d);
			float lower = smoothstep(edge - 0.06, edge, d) * smoothstep(0.2, 0.8, -up);
			float upper = smoothstep(edge - 0.08, edge, d) * smoothstep(0.0, 0.4, up);
			colour = mix(mix(inner, broken * 1.25, lower * 0.8), vec3(0.02), upper * 0.9);
			amount = 0.97;
		} else {
			// Cracks running out from it, finer and fewer further off.
			float angle = atan(off.y, off.x);
			float wander = noise(vec2(d * 6.0, float(i) * 3.3)) * 0.8;
			float line = abs(fract(angle * 7.0 / 6.2832 + wander + float(i) * 0.37) - 0.5);
			float width = 0.03 * (1.0 - smoothstep(edge, r * 2.6, d));
			float crack = (1.0 - smoothstep(width * 0.5, width, line)) * step(0.35, hash(vec2(floor(angle * 7.0 / 6.2832 + wander + float(i) * 0.37), float(i))));
			colour = mix(colour, vec3(0.02), crack);
			amount = max(amount, crack * 0.9);
			// A dusty rim of grime about the break.
			amount = max(amount, (1.0 - smoothstep(edge, edge + 0.15, d)) * 0.5);
		}
	}
	ALBEDO = colour;
	ALPHA = clamp(amount, 0.0, 0.95);
}
