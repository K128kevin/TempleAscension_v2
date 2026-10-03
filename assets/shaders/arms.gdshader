shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Finished arms hung in the smithy (scripts/world_interiors.gd): bright
// steel from `metal_from` of the model's length up (an axe's head, a long
// sword's blade and guard), dark oiled wood below it (the haft, the grip).
uniform float metal_from = 0.5;
uniform vec3 steel : source_color = vec3(0.8, 0.82, 0.85);
uniform vec3 wood : source_color = vec3(0.2, 0.125, 0.07);
varying float along;
varying vec3 at;

void vertex() {
	along = VERTEX.y;
	at = VERTEX;
}

void fragment() {
	if (along >= metal_from) {
		// Partly metallic, so it reads as steel with little about it to
		// reflect (as the hero's blade: assets/shaders/sword.gdshader).
		float scuff = fract(sin(dot(floor(at.xy * vec2(40.0, 9.0)), vec2(12.9898, 78.233))) * 43758.5453);
		ALBEDO = steel * (0.9 + 0.1 * scuff);
		METALLIC = 0.6;
		ROUGHNESS = 0.3 + 0.08 * scuff;
	} else {
		float grain = 0.85 + 0.15 * step(0.5, fract(at.x * 31.0 + at.z * 17.0 + along * 3.0));
		ALBEDO = wood * grain;
		METALLIC = 0.0;
		ROUGHNESS = 0.75;
	}
}
