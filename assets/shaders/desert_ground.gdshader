// The outdoor world's ground, drawn on one flat slab: photographed sand,
// fine where the wind lays it and gravelly in patches, on the track and under
// the rocks, shaded into low dunes and wind ripples; and, where the control
// map says so, town paving, the worn track and the oasis pool.
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
uniform vec3 water_deep : source_color = vec3(.05,.17,.17);
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

	// Wet sand darkens toward the pool; the pool itself is still water.
	ground = mix(ground,ground*vec3(.5,.46,.42),shore*(1.0-water));
	float wave = value_noise(p*1.7+vec2(TIME*.18,TIME*.11))+value_noise(p*3.1-vec2(TIME*.13,TIME*.2));
	vec3 pool = mix(water_deep*2.4+sand*.25,water_deep,smoothstep(.55,.95,map.a))+vec3(.05,.07,.06)*(wave-1.0);
	ground = mix(ground,pool,water);

	// Shade gathered at the foot of whatever stands on the ground.
	ground *= 1.0-map.b*.4;
	ALBEDO = ground;
	ROUGHNESS = mix(.96,.1,water);
	SPECULAR = mix(.1,.6,water);
	float relief = (1.0-paved)*(1.0-water)*(1.0-track*.6);
	vec3 n = normalize(vec3(-slope.x*1.7*relief,1.0,-slope.y*1.7*relief));
	// Ripples tilt the surface across their own crests.
	n = normalize(n+vec3(.6,0.0,.8)*cos(phase)*.13*ripple_strength*(.6+.8*value_noise(p*.31))*(1.0-water));
	// The grain of the sand itself, and the stones in the gravel.
	vec2 grain = mix(mix(texture(sand_fine_normal,p*.29).xy,texture(sand_fine_normal,turned).xy,lay),texture(sand_gravel_normal,p*.23).xy,gritty*.85)*2.0-1.0;
	n = normalize(n+vec3(grain.x,0.0,-grain.y)*mix(.55,.3,paved)*(1.0-water));
	n = mix(n,normalize(vec3((wave-1.0)*.08,1.0,(wave-1.0)*.06)),water);
	n = normalize(n/max(n.y,.2)+vec3(mesh_normal.x,0.0,mesh_normal.z)/max(mesh_normal.y,.2)*sloped);
	NORMAL = normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
}
