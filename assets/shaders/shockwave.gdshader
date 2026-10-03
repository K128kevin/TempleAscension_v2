shader_type spatial;
// The shockwave of a blow on the ground (scripts/shockwave.gd): a single
// front of pressed air racing out over the floor like a sonic boom, a hard
// bright edge with a thin haze drawn after it, and, where the blow landed,
// the ground itself cracked, the cracks glowing with what was driven into
// it and dying away. Drawn on a disc (or the slice of one the blow reaches)
// laid on the ground, and on a low wall standing on the front (`wall`).
// UV.x is how far out a point is (0 at the blow, 1 at the blow's reach; up
// the wall, its height), UV.y how far round the slice.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform bool wall = false;
// Where the front is (a share of the reach), and how much of it is left.
uniform float front = 0.0;
uniform float strength = 1.0;
uniform vec4 tint : source_color = vec4(.95,.93,.88,.8);
// The cracks: how far out they run (a share of the reach), how strong they
// still are, their glow, and how many metres across a cell of them is.
uniform float crack_reach = .3;
uniform float crack_strength = 0.0;
uniform vec3 crack_glow : source_color = vec3(.45,.72,1.0);
uniform float crack_size = .55;
varying vec3 at;

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
	q += dot(q,q.yzx+33.33);
	return fract((q.xx+q.yz)*q.zy);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float a = hash22(i).x; float b = hash22(i+vec2(1,0)).x; float c = hash22(i+vec2(0,1)).x; float d = hash22(i+vec2(1,1)).x;
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
// How near the border between two cells of a scattered pattern a point is.
float border(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++) {
		vec2 o = vec2(float(x),float(y));
		vec2 r = o+hash22(cell+o)-f;
		float d = dot(r,r);
		if (d < d1) { d2 = d1; d1 = d; }
		else if (d < d2) { d2 = d; }
	}
	return sqrt(d2)-sqrt(d1);
}

void vertex() {
	at = VERTEX;
}

void fragment() {
	// Soft at the sides of a slice, so its ends are not cut off square.
	float sides = smoothstep(0.0,.06,UV.y)*smoothstep(0.0,.06,1.0-UV.y);
	if (wall) {
		// The front standing up off the ground: densest at its foot, torn
		// along its top, thinning as it runs out.
		float up = UV.x;
		float torn = noise(vec2(UV.y*70.0,up*3.0));
		float body = pow(1.0-up,2.2)*(0.55+0.45*torn);
		ALBEDO = tint.rgb;
		ALPHA = tint.a*.8*body*strength*sides;
	} else {
		float out_from = UV.x-front;
		// The edge itself; the haze behind it, streaked along its run; and a
		// breath of it ahead.
		float edge = exp(-pow(out_from/.02,2.0));
		// (And a fainter one after it: the boom's second report.)
		float echo = exp(-pow((out_from+.13)/.016,2.0))*.45;
		float streaks = noise(vec2(UV.y*90.0,UV.x*5.0-front*3.0));
		float behind = out_from < 0.0 ? exp(out_from*5.0)*(0.4+0.45*streaks) : exp(-out_from*70.0)*.35;
		float wave = clamp(edge+echo+behind*.8,0.0,1.0)*strength*sides;
		// The ground broken where the blow fell: cracks out from it, thinning
		// with distance, shown once the front has passed over them.
		// (Each a dark split in the stone, lit along its lips.)
		float near = border(at.xz/crack_size);
		float thin = 1.0-smoothstep(crack_reach*.3,crack_reach,UV.x);
		float shown = step(UV.x,front+.02)*crack_strength*thin;
		float split = (1.0-smoothstep(0.012,0.035,near))*shown;
		float lips = (1.0-smoothstep(0.03,0.16,near))*shown;
		vec3 colour = mix(tint.rgb,vec3(1.0),edge*.6);
		colour = mix(colour,crack_glow*1.5,clamp(lips*1.4,0.0,1.0));
		colour = mix(colour,vec3(0.03,0.035,0.05),clamp(split*1.6,0.0,1.0));
		ALBEDO = colour;
		ALPHA = clamp(tint.a*wave+lips*.85+split,0.0,1.0);
	}
}
