shader_type spatial;
// The wake of a hard sword cut (scripts/sword_trail.gd): a soft, translucent
// sweep of disturbed air behind the blade, streaked along the way it went,
// thinning as it ages. UV.x is the wake's age (0 at the blade, 1 as it
// fades out), UV.y runs across it from the blade's middle to its point.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 tint : source_color = vec4(.93,.95,1.0,.5);

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
	float age = UV.x;
	float across = UV.y;
	// Long streaks along the sweep, finer ones over them, drifting as it ages.
	float streaks = noise(vec2(age*2.5,across*7.0))*.6+noise(vec2(age*6.0+3.0,across*19.0))*.4;
	// Densest toward the point, where the blade moves fastest; soft at both edges.
	float body = smoothstep(0.0,.3,across)*(1.0-smoothstep(.86,1.0,across))*mix(.45,1.0,across);
	// Thickest just behind the blade, thinning to nothing.
	float life = smoothstep(0.0,.05,age)*pow(1.0-age,1.6);
	ALBEDO = tint.rgb;
	ALPHA = tint.a*COLOR.a*life*body*(.35+.65*streaks);
}
