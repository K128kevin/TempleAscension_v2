// Photographed material detail for the figures, their kit and their weapons
// (tools/prepare_materials.py): three texture arrays, global to every shader
// (project.godot [shader_globals]), one material to a layer (MAT_*):
// detail_col (colour, its mean brightness middle grey), detail_nrm (normals)
// and detail_dat (red roughness, green cavity, blue height).
//
// Each map is laid on a piece from three sides at once in the piece's own
// space (its rest pose, for a skinned figure: Art.rest_pose_mesh), so its
// grain keeps one size in the world, runs on unbroken across the model's UV
// seams, and stays fixed to the piece however it moves. Its relief is then
// carried onto the posed piece as the view sees it (detail_normal), by how
// the piece's own space and the view change together across the screen.
//
// A shader includes this and calls, with p (metres, divided by the tile's
// size) and n the point and normal in the piece's own space:
//   vec3 w = tri_weights(n);
//   vec3 c = mat_colour(p, n, w, MAT_LEATHER_WORN);    (linear, mean 1)
//   vec4 d = mat_data(p, n, w, MAT_LEATHER_WORN);      (rough, cavity, height)
//   vec3 bent = mat_normal(p, n, w, MAT_LEATHER_WORN, strength);
//   NORMAL = detail_normal(bent, n, rest_p, VERTEX, NORMAL);
// and, for skin and anything lit through it, light() { lit(...); }.

global uniform sampler2DArray detail_col;
global uniform sampler2DArray detail_nrm;
global uniform sampler2DArray detail_dat;

const float MAT_STEEL_BRUSHED = 0.0;
const float MAT_STEEL_WORN = 1.0;
const float MAT_IRON_RUSTED = 2.0;
const float MAT_BRONZE = 3.0;
const float MAT_GOLD = 4.0;
const float MAT_LEATHER_SMOOTH = 5.0;
const float MAT_LEATHER_WORN = 6.0;
const float MAT_LEATHER_ROUGH = 7.0;
const float MAT_WOOL = 8.0;
const float MAT_CLOTH_COARSE = 9.0;
const float MAT_VELVET = 10.0;
const float MAT_SILK = 11.0;
const float MAT_LINEN = 12.0;
const float MAT_HESSIAN = 13.0;
const float MAT_WOOD_ASH = 14.0;
const float MAT_WOOD_WALNUT = 15.0;
const float MAT_SKIN = 16.0;

// How much each of the three sides shows, by how squarely the surface faces it.
vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 1e-5);
}

// Which way each side's picture runs: mirrored on the far sides, so a map's
// relief never turns inside out there.
vec3 tri_signs(vec3 n) {
	return vec3(n.x < 0.0 ? -1.0 : 1.0, n.y < 0.0 ? -1.0 : 1.0, n.z < 0.0 ? -1.0 : 1.0);
}

vec4 tri_layer(sampler2DArray map, vec3 p, vec3 n, vec3 w, float layer) {
	vec3 s = tri_signs(n);
	return texture(map, vec3(p.z * s.x, p.y, layer)) * w.x
		+ texture(map, vec3(p.x * s.y, p.z, layer)) * w.y
		+ texture(map, vec3(-p.x * s.z, p.y, layer)) * w.z;
}

// The same with the pictures on the sides turned a quarter, so that a grain
// or brushing that runs across the photograph runs up the piece's length
// (+Y) instead: along a haft, a blade, a bow's limb.
vec4 tri_layer_up(sampler2DArray map, vec3 p, vec3 n, vec3 w, float layer) {
	vec3 s = tri_signs(n);
	return texture(map, vec3(p.y, p.z * s.x, layer)) * w.x
		+ texture(map, vec3(p.x * s.y, p.z, layer)) * w.y
		+ texture(map, vec3(p.y, -p.x * s.z, layer)) * w.z;
}

// A material's colour here, in linear light, about 1 on average: the
// photograph's own variation, to multiply a colour by.
vec3 mat_colour(vec3 p, vec3 n, vec3 w, float layer) {
	vec3 c = tri_layer(detail_col, p, n, w, layer).rgb;
	return (c * c * (c * 0.305 + 0.682) + c * 0.0125) / 0.214;
}

// The same as a shade alone, without the photograph's own colour: for
// painting over a colour already chosen.
float mat_shade(vec3 p, vec3 n, vec3 w, float layer) {
	return dot(mat_colour(p, n, w, layer), vec3(0.2126, 0.7152, 0.0722));
}

// Its roughness, cavity (1 open, less in its hollows) and height.
vec4 mat_data(vec3 p, vec3 n, vec3 w, float layer) {
	return tri_layer(detail_dat, p, n, w, layer);
}

// (The same three, its grain running up the piece: tri_layer_up.)
vec3 mat_colour_up(vec3 p, vec3 n, vec3 w, float layer) {
	vec3 c = tri_layer_up(detail_col, p, n, w, layer).rgb;
	return (c * c * (c * 0.305 + 0.682) + c * 0.0125) / 0.214;
}

float mat_shade_up(vec3 p, vec3 n, vec3 w, float layer) {
	return dot(mat_colour_up(p, n, w, layer), vec3(0.2126, 0.7152, 0.0722));
}

vec4 mat_data_up(vec3 p, vec3 n, vec3 w, float layer) {
	return tri_layer_up(detail_dat, p, n, w, layer);
}

// A normal map's texel as a normal (the maps are stored two-channel: the
// third is made up again).
vec3 unpack_normal(vec2 rg) {
	vec2 xy = rg * 2.0 - 1.0;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

// The surface's normal in the piece's own space, bent by a normal map
// (OpenGL, green up) laid from three sides; `strength` 1 is the scan's own
// relief. (Ben Golus' whiteout blend.)
vec3 mat_normal(vec3 p, vec3 n, vec3 w, float layer, float strength) {
	vec3 s = tri_signs(n);
	vec3 tx = unpack_normal(texture(detail_nrm, vec3(p.z * s.x, p.y, layer)).xy);
	vec3 ty = unpack_normal(texture(detail_nrm, vec3(p.x * s.y, p.z, layer)).xy);
	vec3 tz = unpack_normal(texture(detail_nrm, vec3(-p.x * s.z, p.y, layer)).xy);
	tx.xy *= strength;
	ty.xy *= strength;
	tz.xy *= strength;
	tx.x *= s.x;
	ty.x *= s.y;
	tz.x *= -s.z;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

vec3 mat_normal_up(vec3 p, vec3 n, vec3 w, float layer, float strength) {
	vec3 s = tri_signs(n);
	vec3 tx = unpack_normal(texture(detail_nrm, vec3(p.y, p.z * s.x, layer)).xy).yxz;
	vec3 ty = unpack_normal(texture(detail_nrm, vec3(p.x * s.y, p.z, layer)).xy);
	vec3 tz = unpack_normal(texture(detail_nrm, vec3(p.y, -p.x * s.z, layer)).xy).yxz;
	tx.xy *= strength;
	ty.xy *= strength;
	tz.xy *= strength;
	tx.x *= s.x;
	ty.x *= s.y;
	tz.x *= -s.z;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

// --- Through a mesh's own UVs ----------------------------------------------
// For meshes unwrapped in metres (the townspeople's and bandits' clothes) or
// with a body's own layout: a material read straight through the UVs, its
// normals as a tangent-space map (NORMAL_MAP).
vec4 mat_data_uv(vec2 uv, float layer) {
	return texture(detail_dat, vec3(uv, layer));
}

float mat_shade_uv(vec2 uv, float layer) {
	vec3 c = texture(detail_col, vec3(uv, layer)).rgb;
	c = (c * c * (c * 0.305 + 0.682) + c * 0.0125) / 0.214;
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 mat_normal_uv(vec2 uv, float layer, float strength) {
	vec3 t = unpack_normal(texture(detail_nrm, vec3(uv, layer)).xy);
	return normalize(vec3(t.xy * strength, t.z));
}

// Two tangent-space normals (as unpacked, z out of the surface) laid one
// over the other (whiteout blend), packed again for NORMAL_MAP.
vec3 normal_map_over(vec3 under, vec3 over) {
	return normalize(vec3(under.xy + over.xy, under.z * over.z)) * 0.5 + 0.5;
}

// Two normals of the piece's own space bent together: `a` and then `b`'s
// departure from the plain surface `n` added to it.
vec3 bend_more(vec3 a, vec3 b, vec3 n) {
	return normalize(a + (b - n * dot(b, n)));
}

// `bent`, a normal of the piece's own space (around its plain normal
// `rest_n` at `rest_p`), as the view sees it on the posed piece at `view_p`
// with the plain normal `view_n` (VERTEX and NORMAL in fragment()). The
// surface's own frame is found twice, from the same step across the screen:
// once in the piece's space and once in the view's; the relief's lean is
// carried from the one to the other.
vec3 detail_normal(vec3 bent, vec3 rest_n, vec3 rest_p, vec3 view_p, vec3 view_n) {
	vec3 rx = dFdx(rest_p);
	vec3 ry = dFdy(rest_p);
	vec3 vx = dFdx(view_p);
	vec3 vy = dFdy(view_p);
	vec3 rt = rx - rest_n * dot(rx, rest_n);
	vec3 vt = vx - view_n * dot(vx, view_n);
	float rl = dot(rt, rt);
	float vl = dot(vt, vt);
	if (rl < 1e-16 || vl < 1e-16) return view_n;
	rt *= inversesqrt(rl);
	vt *= inversesqrt(vl);
	// (A mirrored piece turns its frame the other way.)
	float hand = sign(dot(cross(rx, ry), rest_n)) * sign(dot(cross(vx, vy), view_n));
	vec3 rb = cross(rest_n, rt);
	vec3 vb = cross(view_n, vt) * hand;
	return normalize(view_n * dot(bent, rest_n) + vt * dot(bent, rt) + vb * dot(bent, rb));
}

// How sharply the surface turns here, about 0 on the flat and 1 on a crisp
// edge (an edge wears bright on metal, scuffs pale on leather). From the
// change of the plain normal against the distance travelled across a pixel.
float edge_wear(vec3 view_n, vec3 view_p, float radius) {
	float turn = length(fwidth(view_n));
	float span = length(fwidth(view_p));
	return clamp(turn / max(span, 1e-6) * radius, 0.0, 1.0);
}

// A smooth value noise for broad wear and grime, in three dimensions.
float detail_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float detail_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(detail_hash(i), detail_hash(i + vec3(1, 0, 0)), f.x),
				mix(detail_hash(i + vec3(0, 1, 0)), detail_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(detail_hash(i + vec3(0, 0, 1)), detail_hash(i + vec3(1, 0, 1)), f.x),
				mix(detail_hash(i + vec3(0, 1, 1)), detail_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float detail_fbm(vec3 p) {
	return detail_noise(p) * 0.55 + detail_noise(p * 2.13 + 7.1) * 0.3 + detail_noise(p * 4.37 + 3.3) * 0.15;
}

// --- Light -------------------------------------------------------------------
// A light() for figures with skin: the engine's own GGX highlight for every
// material, and for skin (`skin` 1) light that passes a little way into the
// flesh: the shadow's edge softened and warmed toward red (light scattered
// under the skin comes out redder), a second, broad sheen over the tight one
// (skin's oily film and its fine relief), and a little light through thin
// parts held against it (ears, fingers). `specular` as the material's
// SPECULAR (0.5: 4% reflected head on).
void lit(vec3 n, vec3 l, vec3 v, vec3 colour, float attenuation, vec3 albedo, float roughness, float metallic, float specular, float skin, float amount, inout vec3 diffuse, inout vec3 shine) {
	float ndl = dot(n, l);
	float ndv = max(dot(n, v), 1e-4);
	vec3 h = normalize(l + v);
	float ndh = clamp(dot(n, h), 0.0, 1.0);
	float ldh = clamp(dot(l, h), 0.0, 1.0);
	// Diffuse: Lambert, or for skin the light wrapped round the terminator in
	// red more than in green and blue.
	vec3 wrap = vec3(0.42, 0.2, 0.14) * skin;
	vec3 through = max(vec3(0.0), (vec3(ndl) + wrap) / ((1.0 + wrap) * (1.0 + wrap)));
	// (A soft glow of light through the thinnest parts, from behind.)
	vec3 back = skin * vec3(0.12, 0.035, 0.02) * pow(clamp(dot(-l, v), 0.0, 1.0), 3.0) * clamp(0.6 - ndl, 0.0, 1.0);
	diffuse += colour * (through + back) * attenuation / PI;
	// The highlight (GGX, Schlick, as the engine draws it).
	float f0_dielectric = 0.16 * specular * specular;
	vec3 f0 = mix(vec3(f0_dielectric), albedo, metallic);
	float cndl = clamp(ndl, 0.0, 1.0);
	float f = pow(1.0 - ldh, 5.0);
	vec3 fresnel = f0 + (clamp(50.0 * f0.g, 0.0, 1.0) - f0) * f;
	float a = max(roughness * roughness, 0.002);
	float a2 = a * a;
	float d = ndh * ndh * (a2 - 1.0) + 1.0;
	float ggx = a2 / (PI * d * d);
	float vis = 0.5 / max(cndl * sqrt(ndv * ndv * (1.0 - a2) + a2) + ndv * sqrt(cndl * cndl * (1.0 - a2) + a2), 1e-5);
	vec3 spec = fresnel * ggx * vis;
	if (skin > 0.0) {
		// Skin's second, broader sheen.
		float a_wide = clamp(roughness * 1.45, 0.05, 1.0);
		a_wide *= a_wide;
		float a2w = a_wide * a_wide;
		float dw = ndh * ndh * (a2w - 1.0) + 1.0;
		float ggx_wide = a2w / (PI * dw * dw);
		spec = mix(spec, fresnel * (ggx * 0.55 + ggx_wide * 0.45) * vis, skin);
	}
	shine += spec * cndl * colour * attenuation * amount;
}
