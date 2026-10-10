shader_type spatial;
// A straw hat (scripts/bread_cart.gd straw_hat): plaited straw wound round
// and round from the crown's top to the brim's edge (UV.y), each plait a band
// of short strands laid slantwise in alternate rows (UV.x round the hat),
// sun-bleached unevenly, a dark seam where one plait is sewn to the next.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec3 straw : source_color = vec3(0.78, 0.64, 0.38);
uniform float plaits = 22.0;
uniform float strands = 140.0;

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

void fragment() {
	float row = UV.y * plaits;
	float band = fract(row);
	float slant = (mod(floor(row), 2.0) < 1.0) ? 1.0 : -1.0;
	float strand = abs(fract(UV.x * strands + band * slant * 1.5) - 0.5) * 2.0;
	float seam = smoothstep(0.0, 0.12, band) * smoothstep(1.0, 0.86, band);
	float bleach = noise(vec2(UV.x * 18.0, UV.y * 6.0));
	vec3 colour = straw * (0.7 + 0.3 * strand) * (0.62 + 0.38 * seam);
	colour *= 0.86 + 0.28 * bleach;
	colour *= 0.92 + 0.12 * noise(UV * vec2(420.0, 90.0));
	ALBEDO = colour;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
}
