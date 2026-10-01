shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Stone cloth (the Crowned Statue's cape, marked 0 in the vertex colour's
// green channel) folds over the legs as a cloak does.
#include "res://assets/shaders/cloth_fold.gdshaderinc"

uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
// The hero's painted kit, whose scale pattern is cut into a statue's scale armor.
uniform sampler2D scale_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
// Skinned statues carry their rest pose in CUSTOM0 (position) and CUSTOM1
// (normal), so the stone stays fixed to the body as it animates rather than
// the moving surface sliding through a still pattern.
uniform bool rest_pose = false;
// A statue of a hero's class is carved in that hero's likeness: the body's
// own relief (muscle, knuckles, the face's features) and the hero's kit
// (scales, straps, bracers, boots; a height map from tools/paint_kits.py),
// laid through the body's UVs where the mask's blue channel is 0.
uniform float body_detail = 0.0;
uniform sampler2D body_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D kit_height : filter_linear_mipmap, repeat_enable;
varying float body_uv;
// Stone cloth (a cape): carved in drapery folds, its marble finer grained.
varying float stone_cloth;
varying float stone_scale;
varying vec3 stone_position;
varying vec3 stone_normal;
varying float scale_mask;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float grain_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(cell), hash3(cell + vec3(1,0,0)), f.x),
		mix(hash3(cell + vec3(0,1,0)), hash3(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(cell + vec3(0,0,1)), hash3(cell + vec3(1,0,1)), f.x),
		mix(hash3(cell + vec3(0,1,1)), hash3(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

// Distance to the nearest border between cells of a 3D Voronoi pattern.
float cell_border(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + hash33(cell + o) - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; }
		else if (d < d2) { d2 = d; }
	}
	return sqrt(d2) - sqrt(d1);
}

void vertex() {
	// Preserve a consistent grain size on the body and differently scaled gear.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	if (COLOR.g < 0.5) VERTEX = fold_cloth(VERTEX);
	stone_cloth = 1.0 - step(0.5, COLOR.g);
	stone_scale = scale.y;
	stone_position = (rest_pose ? CUSTOM0.xyz : VERTEX) * scale;
	stone_normal = rest_pose ? CUSTOM1.xyz : NORMAL;
	// Meshes without vertex colors read white: no scales, nor the body's UVs.
	scale_mask = 1.0 - COLOR.r;
	body_uv = (1.0 - COLOR.b) * body_detail;
}

void fragment() {
	// Drawn from both sides for single-layer cloth; the inside faces light as
	// the inside.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 weights = pow(abs(normalize(stone_normal)), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	// On a cape's broad sweep the marble's large veins would read as smears:
	// it is sampled finer there.
	vec3 p = stone_position * mix(0.65, 1.7, stone_cloth);
	vec3 stone = texture(stone_texture, p.yz).rgb * weights.x
		+ texture(stone_texture, p.xz).rgb * weights.y
		+ texture(stone_texture, p.xy).rgb * weights.z;
	float gray = dot(stone, vec3(0.2126, 0.7152, 0.0722));
	float footprint = max(length(dFdx(stone_position)), length(dFdy(stone_position)));
	float fine_detail = 1.0 - smoothstep(0.006, 0.02, footprint);
	float grain = mix(grain_noise(stone_position * 45.0), grain_noise(stone_position * 110.0), fine_detail * 0.35);
	float wear = grain_noise(stone_position * 11.0);
	float pits = smoothstep(0.62, 0.76, grain_noise(stone_position * 28.0));
	// A few fine cracks: the borders of large, wandering cells, shown only
	// where a slow noise allows, so most of the surface stays whole. Lines
	// narrower than a pixel are widened and faded instead of flickering.
	vec3 warp = vec3(grain_noise(stone_position * 9.0), grain_noise(stone_position * 9.0 + 17.0), grain_noise(stone_position * 9.0 + 31.0)) - 0.5;
	float border = cell_border(stone_position * 5.0 + warp * 0.7);
	float width = max(0.03, footprint * 5.0 * 1.5);
	float crack = (1.0 - smoothstep(width * 0.35, width, border)) * (0.03 / width);
	crack *= smoothstep(0.55, 0.68, grain_noise(stone_position * 2.6 + 5.0));
	float shade = 0.17 + gray * 0.20 + (grain - 0.5) * 0.05 + (wear - 0.5) * 0.07 - pits * 0.025 - crack * 0.075;
	// Millimeter-scale grain and pits affect the light, not just the color.
	float height = (grain - 0.5) * 0.0007 + (wear - 0.5) * 0.006 - pits * 0.0012 - crack * 0.0025;
	if (stone_cloth > 0.5) {
		// Drapery: folds running down from the shoulders, deeper and broader
		// toward the hem, wandering a little, as a sculptor cuts a cape.
		vec3 q = stone_position / stone_scale;
		float around = atan(q.x, q.z + 0.03);
		float hang = clamp((1.42 - q.y) / 1.1, 0.0, 1.0);
		float wander = grain_noise(vec3(q.x, q.y * 0.35, q.z) * 3.0) * 4.0;
		float fold = sin(around * 8.0 + wander) * 0.65 + sin(around * 15.0 + wander * 1.7) * 0.35;
		height += fold * 0.006 * hang;
		shade *= 1.0 - (0.5 - 0.5 * fold) * 0.16 * hang;
	}
	if (body_uv > 0.5) {
		// The kit's relief: 0.5 is the bare surface, each 1/255 a rise of
		// 0.04mm, carved deeper in stone so it reads at a distance; recesses
		// darker, raised work a touch paler.
		float kit = (texture(kit_height, UV).r - 0.5) * 0.01;
		height += kit * 3.0;
		shade *= 1.0 + clamp(kit * 110.0, -0.4, 0.16);
		NORMAL_MAP = texture(body_normal, UV).rgb;
		NORMAL_MAP_DEPTH = 1.2;
	} else if (scale_mask > 0.01) {
		// Overlapping scales, from the hero's kit: raised centres, sunken rims.
		float scales = dot(texture(scale_texture, UV).rgb, vec3(0.2126, 0.7152, 0.0722));
		float relief = smoothstep(0.03, 0.3, scales);
		shade *= mix(1.0, 0.72 + 0.4 * relief, scale_mask);
		height += (relief - 0.5) * 0.004 * scale_mask;
	}
	ALBEDO = vec3(clamp(shade, 0.06, 0.42));
	vec3 surface_x = dFdx(VERTEX);
	vec3 surface_y = dFdy(VERTEX);
	vec3 r1 = cross(surface_y, NORMAL);
	vec3 r2 = cross(NORMAL, surface_x);
	float determinant = dot(surface_x, r1);
	vec3 gradient = (dFdx(height) * r1 + dFdy(height) * r2) * sign(determinant) / max(abs(determinant), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	ROUGHNESS = 0.98;
	SPECULAR = 0.08;
	METALLIC = 0.0;
}
