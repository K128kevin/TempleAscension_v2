shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 stone_position;
varying vec3 stone_normal;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
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

void vertex() {
	// Preserve a consistent grain size on the body and differently scaled gear.
	stone_position = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	stone_normal = NORMAL;
}

void fragment() {
	vec3 weights = pow(abs(normalize(stone_normal)), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 p = stone_position * 0.65;
	vec3 stone = texture(stone_texture, p.yz).rgb * weights.x
		+ texture(stone_texture, p.xz).rgb * weights.y
		+ texture(stone_texture, p.xy).rgb * weights.z;
	float gray = dot(stone, vec3(0.2126, 0.7152, 0.0722));
	float footprint = max(length(dFdx(stone_position)), length(dFdy(stone_position)));
	float fine_detail = 1.0 - smoothstep(0.006, 0.02, footprint);
	float grain = mix(grain_noise(stone_position * 45.0), grain_noise(stone_position * 110.0), fine_detail * 0.35);
	float wear = grain_noise(stone_position * 11.0);
	float pits = smoothstep(0.56, 0.72, grain_noise(stone_position * 28.0));
	ALBEDO = vec3(clamp(0.17 + gray * 0.20 + (grain - 0.5) * 0.12 + (wear - 0.5) * 0.08 - pits * 0.055, 0.07, 0.42));
	// Millimeter-scale grain and pits affect the light, not just the color.
	float height = (grain - 0.5) * 0.0018 + (wear - 0.5) * 0.006 - pits * 0.003;
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
