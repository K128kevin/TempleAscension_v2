// Shared by the townsfolk's skin and their clothes (townsfolk_skin.gdshader,
// cloth.gdshaderinc): a body worn thin by hunger (scripts/townsperson.gd
// gaunt). Each vertex is drawn in along its normal by `gaunt` times as many
// metres as the bones it follows say (`thin`, by the mesh's skin binds: most
// at the trunk and thighs, less down the arms and shins, a little at the neck
// and face, none at the hands and feet), so the limbs go stick-thin and the
// trunk narrow, and a garment cut close over it follows it in.
const int THIN_BINDS = 72;
uniform float gaunt = 0.0;
uniform float thin[THIN_BINDS];

vec3 gaunt_inset(vec3 vertex, vec3 normal, uvec4 bones, vec4 weights) {
	if (gaunt <= 0.0) return vertex;
	float t = 0.0;
	for (int k = 0; k < 4; k++) {
		int b = int(bones[k]);
		if (b < THIN_BINDS) t += weights[k] * thin[b];
	}
	return vertex - normal * t * gaunt;
}
