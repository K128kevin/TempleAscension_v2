shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// The bandits' leather (tools/make_bandits.py, scripts/bandit.gd): oiled hide,
// scuffed pale and stained dark, sun-cracked. Its UVs are in metres over it
// (round the body, and down it); its second UV set says how near its hem a
// point is (x). `studs` sets rows of bronze studs along the hem and down the
// front; `wound` makes it strips wound diagonally round a limb, over linen
// that shows between them (bracers and shin bindings).
uniform vec3 leather : source_color = vec3(0.28, 0.16, 0.08);
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform float studs = 0.0;
uniform float wound = 0.0;
uniform vec3 linen : source_color = vec3(0.62, 0.55, 0.43);
uniform float wear = 0.5;
uniform float seed = 0.0;

void fragment() {
	vec2 at = UV + vec2(seed * 2.3, seed * 0.7);
	float grain = texture(grit, at * 6.0).r;
	float scuff = smoothstep(0.55, 0.85, texture(grit, at * 1.7).r) * wear;
	float stain = smoothstep(0.4, 0.75, texture(grit, at * 0.8 + 0.37).r);
	vec3 colour = leather * (0.72 + 0.5 * grain);
	colour = mix(colour, colour * vec3(1.55, 1.4, 1.25), scuff * 0.6);
	colour = mix(colour, colour * 0.6, stain * 0.5);
	float rough = 0.72 - 0.15 * grain;
	float metal = 0.0;
	if (wound > 0.0) {
		// Strips a hand wide wound round and up the limb, each laid half
		// over the last; the linen beneath shows in the gaps.
		float turn = fract((UV.y + UV.x * 0.42) / 0.045);
		float gap = smoothstep(0.0, 0.08, turn) * (1.0 - smoothstep(0.84, 0.92, turn));
		// Each strip's lower edge is shadowed by the one laid over it.
		float lip = smoothstep(0.55, 0.84, turn);
		vec3 under = linen * (0.6 + 0.4 * texture(grit, at * 9.0).r);
		colour = mix(under * 0.55, colour * mix(1.0, 0.6, lip), gap);
		// A thong crossing back over them.
		float cross_turn = fract((UV.y - UV.x * 0.42) / 0.11);
		if (cross_turn < 0.09) colour = leather * 0.45 * (0.8 + 0.4 * grain);
	}
	if (studs > 0.0) {
		// Bronze studs in a row a little above the hem, and in a line down
		// either side of the front.
		float hem_row = 1.0 - smoothstep(0.0, 0.02, abs(UV2.x - 0.55));
		vec2 cell = vec2(fract(UV.x / 0.035) - 0.5, 0.0);
		float stud = hem_row * (1.0 - smoothstep(0.18, 0.28, length(cell)));
		vec2 down = vec2(fract(UV.y / 0.04) - 0.5, (UV.x - 0.06) / 0.035);
		float column = 1.0 - smoothstep(0.18, 0.28, length(down));
		stud = max(stud, column);
		if (stud > 0.5) {
			colour = vec3(0.55, 0.38, 0.18) * (0.6 + 0.6 * grain);
			metal = 0.85;
			rough = 0.4;
		}
	}
	if (!FRONT_FACING) {
		colour *= 0.35;
		NORMAL = -NORMAL;
	}
	ALBEDO = colour;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
}
