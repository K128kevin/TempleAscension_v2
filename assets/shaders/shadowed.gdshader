shader_type spatial;
// The ranger hidden in the shadows (scripts/visual.gd set_shadowed): drawn
// over every part of him, a darkness with a faint cold rim, drifting like
// smoke, through which a little of him still shows.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 shade : source_color = vec4(.03,.03,.06,.86);
uniform vec3 rim : source_color = vec3(.3,.32,.5);

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	float edge = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	float drift = noise(SCREEN_UV*vec2(38.0,24.0)+vec2(0.0,-TIME*.6));
	ALBEDO = mix(shade.rgb,rim,edge*.8);
	ALPHA = shade.a*(.82+.18*drift);
}
