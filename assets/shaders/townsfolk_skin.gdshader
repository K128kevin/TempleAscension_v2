shader_type spatial;
// The townspeople's and bandits' flesh (tools/make_townsfolk.py,
// make_bandits.py). The body's second UV set carries each point's height at
// rest and how far along the arm it is: what lies under a garment is not
// drawn, so it never shows through the cloth.
// The skin has the body's own relief (its normal map: muscle, knuckles, the
// face's features), the pores and fine creases of real skin over it
// (assets/shaders/detail.gdshaderinc), and is lit as skin is: light passing a
// little way into it, softening and warming the edge of its shadow (light()).
#include "res://assets/shaders/detail.gdshaderinc"
uniform sampler2D skin : source_color, filter_linear_mipmap;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tone = vec3(1.0);
// How dirty: 0 washed, 1 unwashed, the feet and shins worst.
uniform float dirt = 0.0;
// Covered from this height (x) up to this one (y), and this far down the arm.
uniform vec2 cover = vec2(0.0);
uniform float sleeve = 0.0;
// How many times the pores' tile is laid across the body's texture.
uniform float pores = 30.0;
#include "gaunt.gdshaderinc"
// (Handed to light(): how much of this point is clean skin.)
varying float skin_part;

void vertex() {
	VERTEX = gaunt_inset(VERTEX, NORMAL, BONE_INDICES, BONE_WEIGHTS);
}

void fragment() {
	// (The exporter turns a UV's second coordinate over.)
	float along_arm = 1.0 - UV2.y;
	bool on_arm = along_arm > 0.001;
	if (!on_arm && UV2.x > cover.x && UV2.x < cover.y) discard;
	if (on_arm && along_arm < sleeve) discard;
	vec3 colour = texture(skin, UV).rgb * tone;
	float blotch = texture(grit, UV * 5.0).r;
	float low = 1.0 - smoothstep(0.0, 0.55, UV2.x);
	float grime = clamp(dirt * (0.2 + 0.7 * low) * smoothstep(0.25, 0.6, blotch + low * 0.25), 0.0, 1.0);
	// The pores and creases: shade in their hollows, and their relief over the
	// body's own.
	vec4 fine = mat_data_uv(UV * pores, MAT_SKIN);
	colour *= 0.88 + 0.12 * fine.g;
	ALBEDO = mix(colour, colour * vec3(0.52, 0.44, 0.36), grime);
	vec3 body = unpack_normal(texture(skin_normal, UV).xy);
	NORMAL_MAP = normal_map_over(body, mat_normal_uv(UV * pores, MAT_SKIN, 0.6));
	ROUGHNESS = clamp(0.5 + (fine.r - 0.5) * 0.35 + grime * 0.3, 0.35, 0.9);
	SPECULAR = 0.35;
	skin_part = 1.0 - grime * 0.7;
}

void light() {
	lit(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, ALBEDO, ROUGHNESS, 0.0, 0.35, skin_part, SPECULAR_AMOUNT, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
