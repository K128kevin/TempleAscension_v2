// The outdoor world's ground, drawn on one flat slab: photographed sand,
// fine where the wind lays it and gravelly in patches, on the track and under
// the rocks, shaded into low dunes and wind ripples; and, where the control
// map says so, town paving, the worn track and water: the oasis, the palace's
// pools. Water is clear: its bed shows through it, dimmed and tinted the deeper
// it lies (red lost first), with the sun's light netted over it in the
// shallows; its surface is ruffled by wind-driven ripples that catch the sun,
// reflects the sky more as it is seen more slantwise (Fresnel), and laps at
// its edge.
shader_type spatial;
render_mode cull_back;
// One texel per metre. R: paving. G: the track. B: shade at the foot of walls
// and rocks. A: water.
uniform sampler2D control : filter_linear, repeat_disable;
uniform vec2 map_origin;
uniform vec2 map_size;
uniform sampler2D stone : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_fine : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_fine_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_gravel_normal : filter_linear_mipmap_anisotropic, repeat_enable;
// Smooth tiling noise, one lattice cell every eight texels: far cheaper to
// read than to compute for every pixel of the screen.
uniform sampler2D noise_map : filter_linear_mipmap, repeat_enable;
// Set on the hill's own mesh: its slope then tilts the shading. (The slab's
// carved paving is shaded flat.)
uniform float sloped = 0.0;
// The photographs are of paler, greyer sand: these bring them to the basin's.
uniform vec3 sand_light = vec3(1.33,1.24,1.12);
uniform vec3 sand_dark = vec3(1.0,.88,.76);
uniform vec3 gravel_gain = vec3(1.1,1.05,1.0);
uniform vec3 paving_tint : source_color = vec3(.74,.68,.60);
// Water: the colour it scatters back where deep, and how strongly it takes
// out each of red, green and blue from the light through it, a metre's worth.
uniform vec3 water_deep : source_color = vec3(.14,.33,.34);
uniform vec3 absorption = vec3(.95,.42,.40);
// The sky the water reflects (scripts/overworld.gd set_time).
uniform vec3 sky_colour = vec3(.62,.70,.82);
varying vec3 world;
varying vec3 mesh_normal;

float hash(vec2 p) {
	p = fract(p*vec2(.1031,.1030));
	p += dot(p,p.yx+33.33);
	return fract((p.x+p.y)*p.x);
}

float value_noise(vec2 p) {
	return texture(noise_map,p/64.0).r;
}

float fbm(vec2 p) {
	return value_noise(p)*.55+value_noise(p*2.03+vec2(17.1,9.7))*.3+value_noise(p*4.1+vec2(3.3,41.0))*.15;
}

// Dune relief in metres: long ridges running across the prevailing wind,
// with sharp crests, over broad swells.
float dunes(vec2 p) {
	vec2 q = vec2(p.x*.6+p.y*.8,p.y*.6-p.x*.8);
	float ridge = 1.0-abs(2.0*value_noise(q*vec2(.045,.018)+fbm(q*.012)*2.0)-1.0);
	float swell = value_noise(p*.011);
	return ridge*ridge*1.5+swell*2.4;
}

// Wind ripples, a hand's width apart, bent by the dunes they run over.
float ripple_phase(vec2 p) {
	return (p.x*.6+p.y*.8)*17.0+(fbm(p*.11)*6.0+value_noise(p*.7)*1.1)*6.0;
}

// The water's surface, as heights: two trains of wind ripples crossing, and
// a fine chop over them.
float ripples(vec2 q) {
	vec2 wind = vec2(.8,.6);
	return value_noise(q*1.15+wind*TIME*.42)*.55
		+value_noise(vec2(q.x*.6-q.y*.8,q.x*.8+q.y*.6)*2.3-wind.yx*TIME*.63)*.3
		+value_noise(q*6.1+vec2(TIME*.9,-TIME*.7))*.15;
}

void vertex() {
	world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	mesh_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec2 p = world.xz;
	// The map's hard cell edges are broken up with noise.
	vec2 wobble = vec2(value_noise(p*.9),value_noise(p.yx*.9+31.7))-.5;
	vec4 map = texture(control,(p+wobble*1.1-map_origin+.5)/map_size);
	float paved = smoothstep(.42,.6,map.r+(value_noise(p*1.1)-.5)*.5);
	float track = smoothstep(.2,.75,map.g+(value_noise(p*.8+9.0)-.5)*.45);
	float water = smoothstep(.45,.6,map.a);
	float shore = smoothstep(.08,.5,map.a);

	// Dune relief and ripples.
	float e = .6;
	float h = dunes(p);
	vec2 slope = vec2(dunes(p+vec2(e,0.0))-h,dunes(p+vec2(0.0,e))-h)/e;
	float phase = ripple_phase(p);
	float ripple = sin(phase)*.5+.5;
	// Ripples lie in drifts, with smooth sand between them.
	float ripple_strength = (1.0-track*.8)*(1.0-paved)*smoothstep(.3,.62,value_noise(p*.19+5.0));

	// Sand: fine where it lies deep; gravel and grit where it is thin, in
	// patches, along the track and at the foot of the rocks.
	float patches = value_noise(p*.043+3.0)+value_noise(p*.23)*.4;
	float gritty = clamp(smoothstep(.62,.86,patches)+track*.75+map.b*.8,0.0,1.0);
	// Two layings of the same photograph, turned against each other and mixed
	// in patches, so its marks never line up in a grid.
	vec2 turned = vec2(p.x*.8-p.y*.6,p.x*.6+p.y*.8)*.21+vec2(.31,.67);
	float lay = smoothstep(.35,.65,value_noise(p*.37+11.0));
	vec3 fine = mix(texture(sand_fine,p*.29).rgb,texture(sand_fine,turned).rgb,lay);
	// The same photograph at a far larger size hides its repetition.
	float broad = dot(texture(sand_fine,p*.037+vec2(.37,.11)).rgb,vec3(.68));
	vec3 gravel = texture(sand_gravel,p*.23).rgb;
	float tone = clamp(.25+h*.26+(ripple-.5)*.1*ripple_strength+(fbm(p*.25)-.5)*.5,0.0,1.0);
	vec3 sand = mix(fine*mix(sand_dark,sand_light,tone)*(.72+broad*.28),gravel*gravel_gain*(.8+tone*.3),gritty*.85);
	// The track is trodden a little darker.
	sand *= 1.0-track*.14;

	// Paving: limestone flags, worn and dirty, sand drifted into their joints.
	vec3 flags = texture(stone,p*.21).rgb*paving_tint*(.45+dot(fine,vec3(.37)));
	float drift = smoothstep(.5,.78,fbm(p*.33+4.0)+(1.0-map.r)*.5);
	vec3 ground = mix(sand,mix(flags,sand,drift*.75),paved);

	// Wet sand darkens toward the water.
	ground = mix(ground,ground*vec3(.5,.46,.42),shore*(1.0-water));
	// Shade gathered at the foot of whatever stands on the ground.
	ground *= 1.0-map.b*.4;
	vec3 surface = vec3(0.0,1.0,0.0);
	vec3 reflected = vec3(0.0);
	if (shore > 0.0) {
		// How deep it lies: nothing at the edge, a metre and a half in the middle.
		float depth = smoothstep(.45,1.0,map.a)*1.5;
		// The surface, tilted by how its ripples rise across it; rougher in
		// the gusts that cross it.
		float d = .07;
		float h0 = ripples(p);
		vec2 rise = vec2(ripples(p+vec2(d,0.0))-h0,ripples(p+vec2(0.0,d))-h0)/d;
		float rough_water = .35+.65*smoothstep(.2,.8,value_noise(p*.21+vec2(TIME*.05,0.0)));
		surface = normalize(vec3(-rise.x*.09*rough_water,1.0,-rise.y*.09*rough_water));
		// The bed through the water, shifted a little by the ripples
		// (refraction), with the sun's light netted over it by them (caustics).
		float a = value_noise(p*2.1+surface.xz*1.5+vec2(TIME*.31,TIME*.19));
		float b = value_noise(vec2(p.x*.8+p.y*.6,p.y*.8-p.x*.6)*2.6-vec2(TIME*.23,TIME*.29));
		float caustic = smoothstep(.82,1.0,1.0-abs(a-b)*3.2);
		// Silt and weed darken the bed where it lies deep.
		vec3 bed = ground*mix(vec3(1.0),vec3(.55,.6,.5),smoothstep(.4,1.4,depth))*(1.0+caustic*1.3*exp(-depth*1.6));
		vec3 through = exp(-absorption*(depth*1.3+.08));
		vec3 body = bed*through+water_deep*(1.0-through.g);
		// The sky in the water, the more of it the more slantwise it is seen.
		vec3 eye = normalize((INV_VIEW_MATRIX*vec4(VIEW,0.0)).xyz);
		float fresnel = .02+.98*pow(1.0-clamp(dot(surface,eye),0.0,1.0),5.0);
		// Lapping at the edge: a bright wet line that runs up and back, and
		// flecks of foam.
		float lap = map.a-.5+.035*sin(TIME*1.4+value_noise(p*.5)*9.0);
		float edge = 1.0-smoothstep(0.0,.05,abs(lap));
		float foam = edge*smoothstep(.45,.75,value_noise(p*7.0+vec2(TIME*.2,-TIME*.15)));
		body = mix(body,vec3(.86,.88,.84),foam*.55);
		ground = mix(ground,body*(1.0-fresnel),water);
		reflected = sky_colour*fresnel*water;
	}
	ALBEDO = ground;
	EMISSION = reflected;
	// Still water is glassy: the sun glints off each ripple turned to it.
	ROUGHNESS = mix(.96,.05,water);
	SPECULAR = mix(.1,.5,water);
	float relief = (1.0-paved)*(1.0-water)*(1.0-track*.6);
	vec3 n = normalize(vec3(-slope.x*1.7*relief,1.0,-slope.y*1.7*relief));
	// Ripples tilt the surface across their own crests.
	n = normalize(n+vec3(.6,0.0,.8)*cos(phase)*.13*ripple_strength*(.6+.8*value_noise(p*.31))*(1.0-water));
	// The grain of the sand itself, and the stones in the gravel.
	vec2 grain = mix(mix(texture(sand_fine_normal,p*.29).xy,texture(sand_fine_normal,turned).xy,lay),texture(sand_gravel_normal,p*.23).xy,gritty*.85)*2.0-1.0;
	n = normalize(n+vec3(grain.x,0.0,-grain.y)*mix(.55,.3,paved)*(1.0-water));
	n = normalize(mix(n,surface,water));
	n = normalize(n/max(n.y,.2)+vec3(mesh_normal.x,0.0,mesh_normal.z)/max(mesh_normal.y,.2)*sloped);
	NORMAL = normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
}
