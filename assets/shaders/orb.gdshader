shader_type canvas_item;
uniform float fill : hint_range(0.0,1.0) = 1.0;
uniform vec4 liquid : source_color = vec4(.65,.03,.05,1.0);
void fragment() {
	vec2 p = (UV-vec2(.5))*2.0;
	float r = length(p);
	float edge = 1.0-smoothstep(.975,1.0,r);
	float light = clamp(.5-dot(p,vec2(.35,.45)),0.0,1.0);
	vec3 bronze = mix(vec3(.13,.09,.055),vec3(.69,.53,.29),light);
	float ring = smoothstep(.83,.86,r);
	vec3 glass = vec3(.025,.025,.032);
	float height = (p.y+.84)/1.68;
	float wet = step(1.0-fill,height)*step(.001,fill);
	float depth = .36+.64*sqrt(max(0.0,1.0-r*r));
	vec3 fluid = liquid.rgb*depth;
	float surface = (1.0-smoothstep(.0,.018,abs(height-(1.0-fill))))*wet;
	fluid += liquid.rgb*surface*.65;
	vec3 bowl = mix(glass,fluid,wet);
	float glint = exp(-length((p-vec2(-.30,-.38))*vec2(2.1,4.5))*5.0);
	bowl += vec3(.50,.55,.60)*glint;
	float rimlight = (1.0-smoothstep(.0,.017,abs(r-.90)))*.22;
	vec3 color = mix(bowl,bronze+rimlight,ring);
	COLOR = vec4(color,edge);
}
