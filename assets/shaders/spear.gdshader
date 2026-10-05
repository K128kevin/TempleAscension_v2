shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The gate guards' spear (assets/models/props/hasta.glb, tools/make_spear.py),
// one material a part (`part`): 0 forged iron (the head, its socket and
// rivet, the butt-spike), 1 the ash shaft, 2 the leather thong bound round
// the grip. The model is unwrapped round each part (UV.x, once round) and
// along it (UV.y, metres from the butt), so grain runs along the shaft and the
// thong winds round it.
// Iron: dark and hammered, its blows' facets mottling it, a little rust in
// its hollows, and on the head (`blade`) its two edges honed bright, the
// honing running out along the point. Ash: pale wood darkened by oil and
// years of handling, long grain and pores. Leather: a dark thong in tight
// turns, each turn's edges worn darker.
uniform int part = 0;
uniform bool blade = false;
uniform vec3 iron : source_color = vec3(.30, .29, .28);
uniform vec3 honed : source_color = vec3(.74, .75, .76);
uniform vec3 rust : source_color = vec3(.36, .19, .09);
uniform vec3 ash : source_color = vec3(.47, .35, .23);
uniform vec3 hide : source_color = vec3(.24, .145, .085);
// The thong's turns a metre (tools/make_spear.py THONG_PITCH).
uniform float turns = 47.6;
// Each guard's spear a little different.
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float total = 0.0;
	float amount = .5;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amount;
		p = p * 2.03 + 7.1;
		amount *= .5;
	}
	return total;
}

void fragment() {
	float round_ = UV.x;
	// (glTF stores V flipped.)
	float along = 1.0 - UV.y;
	vec2 at = vec2(round_ * 6.0 + seed * 13.0, along * 40.0);
	if (part == 0) {
		// Hammered: soft facets of the smith's blows, and the dark of the forge
		// left in the dents.
		float blows = fbm(at * vec2(1.0, 1.2));
		float dents = smoothstep(.35, .75, noise(at * 2.7 + 3.0));
		vec3 metal = iron * (.78 + .38 * blows) * (1.0 - .18 * dents);
		float rough = .5 + .2 * blows;
		// A bloom of rust gathered in the hollows.
		float rusting = smoothstep(.62, .82, fbm(at * .8 + 11.0)) * .55;
		metal = mix(metal, rust * (.8 + .4 * noise(at * 5.0)), rusting);
		rough = mix(rough, .85, rusting);
		float metallic = mix(.75, .2, rusting);
		if (blade) {
			// The edges (where the section's round comes to its sides) honed
			// bright and smooth, scratched along their length.
			float edge = abs(cos(round_ * 6.2831853));
			float hone = smoothstep(.86, .97, edge);
			float scratches = .85 + .15 * noise(vec2(round_ * 400.0, along * 6.0));
			metal = mix(metal, honed * scratches, hone * (1.0 - rusting));
			rough = mix(rough, .22, hone);
			metallic = mix(metallic, .9, hone);
		}
		ALBEDO = metal;
		METALLIC = metallic;
		ROUGHNESS = rough;
	} else if (part == 1) {
		// Long grain, the growth lines wandering a little, and fine pores.
		float lines = fbm(vec2(round_ * 9.0 + seed * 5.0, along * 1.4));
		float grain = .5 + .5 * sin((round_ * 22.0 + lines * 6.0) * 6.2831853);
		float pores = step(.86, hash(floor(vec2(round_ * 160.0, along * 90.0))));
		vec3 wood = ash * (.82 + .14 * grain) * (1.0 - .25 * pores);
		// Oiled and handled darker toward the grip and the foot.
		float handled = exp(-pow((along - 1.0) / .35, 2.0)) * .3 + smoothstep(.45, .12, along) * .25;
		wood *= 1.0 - handled - .12 * fbm(at * .3);
		ALBEDO = wood;
		ROUGHNESS = .62 - handled * .2;
	} else {
		// The thong's turns: each a strip with darker, worn edges between.
		float turn = fract(along * turns + round_);
		float strip = smoothstep(0.0, .18, turn) * smoothstep(1.0, .82, turn);
		float worn = fbm(at * vec2(2.0, .7) + 21.0);
		vec3 leather = hide * (.55 + .45 * strip) * (.85 + .3 * worn);
		ALBEDO = leather;
		ROUGHNESS = .7 - .15 * strip * worn;
	}
}
