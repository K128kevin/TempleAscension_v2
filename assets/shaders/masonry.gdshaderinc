// Limestone masonry over the wall kit's own palette. The kit's grey stone
// becomes limestone projected at one size in the world, so modules of any
// proportion share the same courses; its orange timber (doors, shutters)
// keeps its place, repainted in `wood`. Weather does the rest, as far as
// `wear` says: from dressed stone kept clean (0) to walls left to rot (1),
// stained, streaked, cracked, their limewash gone in sheets over mud brick,
// dirt climbing two metres up them.
uniform sampler2D atlas : source_color, filter_linear;
uniform sampler2D stone : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 wood : source_color = vec3(.30,.19,.11);
uniform vec3 dirt : source_color = vec3(.74,.61,.44);
uniform float stone_scale = .16;
uniform float wear = .5;
// The height of the ground the wall stands on.
uniform float ground = 0.0;
uniform float alpha = 1.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec3 palette = texture(atlas,UV).rgb;
	float high = max(palette.r,max(palette.g,palette.b));
	float low = min(palette.r,min(palette.g,palette.b));
	float timber = smoothstep(.34,.5,(high-low)/max(high,.001))*step(palette.b,palette.r);
	vec3 weight = pow(abs(world_normal),vec3(6.0));
	weight /= weight.x+weight.y+weight.z;
	vec3 p = world_position*stone_scale;
	vec3 rock = texture(stone,vec2(p.z,-p.y)).rgb*weight.x+texture(stone,p.xz).rgb*weight.y+texture(stone,vec2(p.x,-p.y)).rgb*weight.z;
	// Photographed grit, across the wall's face, at two sizes: fine pitting,
	// and broad stains.
	vec2 face = vec2(world_position.x+world_position.z,world_position.y);
	vec2 flat_top = world_position.xz;
	float pit = mix(dot(texture(grit,face*.37).rgb,vec3(.333)),dot(texture(grit,flat_top*.37).rgb,vec3(.333)),weight.y);
	float stain = mix(dot(texture(grit,face*.043+vec2(.2,.6)).rgb,vec3(.333)),dot(texture(grit,flat_top*.043+vec2(.2,.6)).rgb,vec3(.333)),weight.y);
	// Streaks: stretched far taller than wide, strongest under the top.
	float streak = dot(texture(grit,vec2((world_position.x+world_position.z)*.55,world_position.y*.035)).rgb,vec3(.333));
	// The palette's own light and dark stones still read, faintly.
	float shade = mix(.82,1.06,smoothstep(.12,.6,dot(palette,vec3(.333))));
	// (The grit photograph averages .41.)
	vec3 masonry = rock*tint*shade*mix(.98,.8,wear)*(1.0+clamp((pit-.41)*mix(1.0,3.6,wear),-.5,.45))*(1.0+clamp((stain-.41)*mix(.6,3.6,wear),-.5,.3));
	// Old limewash has gone in patches, baring darker stone; on the worst
	// walls, in sheets, down to mud brick.
	float bare = smoothstep(mix(.62,.40,wear),mix(.7,.48,wear),stain+pit*.25)*smoothstep(.15,.5,wear);
	masonry = mix(masonry,mix(masonry*vec3(.74,.64,.54),vec3(.36,.26,.17)*(.6+pit*1.3),smoothstep(.6,1.0,wear)*.8),bare*.75);
	masonry *= 1.0-smoothstep(.44,.3,streak)*mix(.0,.62,wear)*(1.0-weight.y);
	// Cracks wander across the faces of walls nobody mends.
	float vein = textureLod(grit,face*.027+vec2(.63,.17)+(pit-.41)*.012,3.0).r;
	float crack = (1.0-smoothstep(0.0,1.5,abs(vein-.42)/max(fwidth(vein),.00001)))*smoothstep(.36,.46,stain)*smoothstep(.45,.75,wear)*(1.0-weight.y);
	masonry *= 1.0-crack*.72;
	// Dust and splashed sand climb up from the ground; it lies thick on every
	// ledge and roof.
	float height = world_position.y-ground;
	float splash = (1.0-smoothstep(.0,mix(.5,2.3,wear),height+pit*.9-.25))*mix(.2,.85,wear);
	float settled = smoothstep(.7,.95,world_normal.y)*mix(.15,.7,wear);
	masonry = mix(masonry,dirt*(.6+pit*1.0)*mix(1.0,.8,wear),clamp(max(splash,settled),0.0,1.0));
	vec3 paint = wood*(.5+1.2*dot(palette,vec3(.333)))*(1.0+clamp((pit-.41)*3.0,-.5,.4));
	// Paint flakes from the timber where the grit shows through.
	paint = mix(paint,vec3(.12,.08,.05)*(.6+pit*1.0),smoothstep(.34,.2,stain)*mix(.1,.85,wear));
	ALBEDO = mix(masonry,paint,timber);
	ROUGHNESS = mix(.94,.78,timber);
	SPECULAR = .12;
#ifdef FADED
	ALPHA = alpha;
#endif
}
