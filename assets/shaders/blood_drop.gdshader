shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

// A drop of blood in flight (scripts/vfx.gd blood): a hard-edged bead drawn
// out into a tail along the way it flies (the particle's own Y, turned to its
// velocity), facing the camera; seen end on it is round. Wet: a glint near
// its head.
uniform float width = .5;
uniform float stretch = 1.7;

void vertex() {
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 centre = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	vec2 along = (VIEW_MATRIX * vec4(normalize(MODEL_MATRIX[1].xyz), 0.0)).xy;
	float seen = length(along);
	vec2 way = seen > .001 ? along / seen : vec2(0.0, 1.0);
	vec2 side = vec2(way.y, -way.x);
	VERTEX = centre + vec3((side * VERTEX.x * width + way * VERTEX.y * mix(width, stretch, seen)) * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	// (+1 at the head, which leads; -1 at the tip of the tail.)
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float head = (p.y - .15) / .85;
	float half_width = p.y > .15 ? sqrt(max(0.0, 1.0 - head * head)) : pow(clamp((p.y + 1.0) / 1.15, 0.0, 1.0), .6);
	float inside = 1.0 - smoothstep(.72, .98, abs(p.x) / max(half_width, .001));
	float glint = 1.0 - smoothstep(.0, .3, length(p - vec2(-.3, .4)));
	ALBEDO = COLOR.rgb * (.75 + .25 * inside) + vec3(.5, .32, .3) * glint * .5;
	ALPHA = inside * COLOR.a;
}
