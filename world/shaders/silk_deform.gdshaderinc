// Shared by silk.gdshader and dew.gdshader: how an orb web's sheet moves, in
// the web's own space (the sheet is the XY plane, its normal +Z, the hub at
// the origin). The frame and anchor lines (beyond `web_radius`) stay put.
//   poke    something pressing into the sheet (Amodu caught in it): a dent of
//           `poke_depth` metres round `poke_pos`, `poke_radius` wide
//   wobble  after a release or a blow the sheet rings like a drum, decaying
//   breeze  it breathes in the wind all the time
//   holes   where it's torn, the threads (and their dew) are gone

uniform float web_radius = 10.0;
uniform vec3 poke_pos = vec3(0.0);
uniform float poke_depth = 0.0;
uniform float poke_radius = 4.0;
uniform float wobble_amp = 0.0;
uniform float wobble_age = 10.0;
uniform float breeze = 0.18;
// torn: holes (web space xy, radius in z) where a blade or a struggle broke it
uniform vec3 holes[8];

// 1 where `p` (web space) lies in a torn hole
float web_torn(vec2 p) {
	float torn = 0.0;
	for (int i = 0; i < 8; i++) {
		if (holes[i].z > 0.0 && length(p - holes[i].xy) < holes[i].z) {
			torn = 1.0;
		}
	}
	return torn;
}

vec3 web_deform(vec3 p, float time) {
	float r = length(p.xy);
	// 1 over the sheet, fading to 0 at the frame: anchored threads don't move
	float free = 1.0 - smoothstep(web_radius * 0.55, web_radius * 1.02, r);
	float d = length(p.xy - poke_pos.xy);
	float dent = poke_depth * exp(-d * d / (poke_radius * poke_radius));
	float ring = wobble_amp * exp(-wobble_age * 2.2) * sin(wobble_age * 17.0 - d * 0.9)
		* exp(-d * 0.12);
	float air = breeze * (sin(time * 1.1 + p.x * 0.21) * 0.6 + sin(time * 2.3 + p.y * 0.34) * 0.4);
	p.z += (dent + ring + air) * free;
	return p;
}
