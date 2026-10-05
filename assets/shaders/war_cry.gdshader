shader_type spatial;
// War Cry's ring (scripts/war_cry.gd): the red glow that leaves the hero's
// blade racing out over the ground as a ring of light, a hazy band at its
// front a little brighter than the dim red wash left behind it over the area the cry
// covers, flickering like heat; and a low wall of red haze standing on the
// front (`wall`). Drawn on a disc laid on the ground, UV.x how far out a
// point is (0 at the hero, 1 at the cry's reach; up the wall, its height) and
// UV.y how far round.
// (Blended over the floor rather than added to it, its colour kept within
// white: in the Compatibility renderer a red that brightens past white, or is
// added on a lit floor, is clipped and runs on into a pale green-yellow.)
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;
uniform bool wall = false;
// Where the front is (a share of the reach), and how much of it is left.
uniform float front = 0.0;
uniform float strength = 1.0;
// How wide the front's band is, as a share of the reach.
uniform float band = .08;
uniform vec3 glow : source_color = vec3(1.0,.06,.02);
uniform vec3 hot : source_color = vec3(1.0,.42,.22);
varying vec3 at;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void vertex() {
	at = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	// Flickering, as heat does, the same pattern on the ground and the wall.
	vec2 swirl = at.xz*1.6+vec2(TIME*1.7,-TIME*1.3);
	float flicker = .65+.7*noise(swirl)*noise(swirl*2.3+3.1);
	vec3 light;
	float cover;
	if (wall) {
		// Brightest at its foot, gone at its top.
		float up = UV.x;
		float fade = pow(1.0-up,2.2)*smoothstep(0.0,.08,up+.02);
		light = mix(glow,hot,.2*(1.0-up));
		cover = fade*.22*flicker;
	} else {
		float out_ = UV.x;
		// The band at the front: a soft leading edge and a softer trailing one,
		// as hazy as the wash behind it, only a little brighter.
		float d = out_-front;
		float lead = exp(-pow(max(d,0.0)/(band*.7),2.0));
		float trail = exp(-pow(max(-d,0.0)/band,2.0));
		float ring = d >= 0.0 ? lead : trail;
		// The wash it leaves on the ground behind it, and none past the reach.
		float wash = step(out_,front)*.16*(.5+.5*out_/max(front,.001));
		float inside = 1.0-smoothstep(.985,1.0,out_);
		light = mix(glow,hot,ring*ring*.2);
		cover = clamp(ring*.34+wash*.9,0.0,1.0)*flicker*inside;
	}
	ALBEDO = light;
	ALPHA = clamp(cover*strength,0.0,1.0);
}
