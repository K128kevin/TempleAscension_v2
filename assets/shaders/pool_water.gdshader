shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, specular_schlick_ggx;
// The fountain court's water (scripts/fountain.gd): the pool round the
// fountain and the water in each of its bowls. Clear, pale water: the stone
// beneath shows through it, netted with the light its ripples gather
// (caustics) and tinted green-blue; its surface is ruffled by small ripples
// that catch the torches, reflects more as it is seen more slantwise
// (Fresnel), churns white where the spill from the bowl above lands and sends
// rings out from there, and rings round the hero as he wades.
uniform vec2 center = vec2(0.0);
// A bowl's water is cut to a disc this wide; the pool's is the whole slab.
uniform float radius = 0.0;
uniform vec4 wakes[8];
uniform float water_time = 0.0;
// How far from the fountain's axis the spill from above lands on this water
// (0: none lands on it).
uniform float splash = 0.0;
uniform vec3 water_colour : source_color = vec3(0.36, 0.66, 0.62);
varying vec3 world_position;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The surface's heights at `p`: small crossing ripples and a fine chop, the
// rings running out from where the spill lands, and the hero's wakes.
float heights(vec2 p) {
	float t = water_time;
	float h = noise(p * 3.1 + vec2(t * 0.55, t * 0.32)) * 0.5
		+ noise(vec2(p.x * 0.6 - p.y * 0.8, p.x * 0.8 + p.y * 0.6) * 5.3 - vec2(t * 0.4, t * 0.7)) * 0.3
		+ noise(p * 12.0 + vec2(t * 1.3, -t * 1.1)) * 0.12;
	float from_axis = length(p - center);
	if (splash > 0.0) {
		float beyond = max(0.0, from_axis - splash);
		h += sin(beyond * 18.0 - t * 5.0) * exp(-beyond * 2.2) * 0.35 * step(splash, from_axis);
	}
	for (int i = 0; i < 8; i++) {
		float age = t - wakes[i].z;
		float d = length(p - wakes[i].xy);
		h += sin((d - age * 1.3) * 22.0) * exp(-pow((d - age * 1.3) * 7.0, 2.0)) * max(0.0, 1.0 - age / 1.8) * wakes[i].w * 0.6;
	}
	return h;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float from_axis = length(p - center);
	if (radius > 0.0 && from_axis > radius) { discard; }
	float e = 0.03;
	float h0 = heights(p);
	vec2 rise = vec2(heights(p + vec2(e, 0.0)) - h0, heights(p + vec2(0.0, e)) - h0) / e;
	vec3 surface = normalize(vec3(-rise.x * 0.035, 1.0, -rise.y * 0.035));
	// The light netted on the stone beneath, moving with the ripples above it.
	float a = noise(p * 4.2 + surface.xz * 2.0 + vec2(water_time * 0.5, water_time * 0.31));
	float b = noise(vec2(p.x * 0.8 + p.y * 0.6, p.y * 0.8 - p.x * 0.6) * 5.1 - vec2(water_time * 0.37, water_time * 0.45));
	float caustic = smoothstep(0.86, 1.0, 1.0 - abs(a - b) * 3.4);
	// White water where the spill lands.
	float churn = 0.0;
	if (splash > 0.0) {
		float band = exp(-pow((from_axis - splash) / 0.07, 2.0));
		churn = band * smoothstep(0.35, 0.8, noise(p * 22.0 + vec2(water_time * 3.0, -water_time * 2.3)));
	}
	vec3 eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(abs(dot(surface, eye)), 0.0, 1.0), 5.0);
	vec3 colour = water_colour * (0.85 + 0.3 * h0) + vec3(0.55, 0.62, 0.55) * caustic * 0.3;
	ALBEDO = mix(colour, vec3(0.88, 0.92, 0.9), churn * 0.8);
	// Clear: the stone shows through, the more slantwise it is seen the less.
	ALPHA = clamp(0.3 + caustic * 0.12 + fresnel * 0.5 + churn * 0.5, 0.0, 0.92);
	// A little scattered light keeps it readable between the torches, and
	// the court's dim air is reflected in it.
	EMISSION = vec3(0.05, 0.11, 0.10) + vec3(0.10, 0.15, 0.14) * (caustic * 0.6 + churn) + vec3(0.08, 0.1, 0.11) * fresnel;
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	NORMAL = normalize((VIEW_MATRIX * vec4(surface, 0.0)).xyz);
}
