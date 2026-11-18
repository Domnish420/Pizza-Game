shader_type spatial;
// The pizza (Pizza3D). The mesh carries the dough: its colour (browned crust) in the vertex colour, in sRGB.
// What is on it comes from a small map of the pizza's sauce and cheese grid (one pixel per cell: R sauce, G cheese)
// and is drawn here per pixel: sauce that is glossy and darker where it is thick, cheese that is shreds when raw and
// melted pools with golden blisters once baked, and leopard-spot char on the crust when the oven has pushed it.
// UV is where a point falls on the layer map; UV2.x is 1 on the flat middle and 0 on the crust; UV2.y is how much
// the crust there has baked (0 raw, 1 done, more is darker).

uniform sampler2D layers : filter_linear, repeat_disable;
uniform vec3 sauce_col : source_color = vec3(0.8, 0.2, 0.1);
uniform vec3 cheese_col : source_color = vec3(0.97, 0.94, 0.85);
uniform float melt = 0.0;       // 0 raw cheese .. 1 fully melted
uniform float mid_b = 0.0;      // how browned the middle is
uniform float seed = 0.0;
uniform float max_amt = 2.5;

varying vec2 pp;

void vertex() {
	pp = VERTEX.xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float inner = clamp(UV2.x, 0.0, 1.0);
	float crust_b = UV2.y;
	vec4 L = texture(layers, UV);
	float sa = L.r * max_amt * smoothstep(0.55, 0.95, inner);
	float ca = L.g * max_amt * smoothstep(0.55, 0.95, inner);
	float gloss = 0.0;
	// sauce: a smooth layer, ragged at its edge, darker and redder where it is laid thick
	float edge = (vnoise(pp * 0.18) - 0.5) * 0.35;
	float sm = smoothstep(0.08, 0.45, sa + edge);
	vec3 sc = mix(sauce_col, sauce_col * vec3(0.78, 0.7, 0.68), smoothstep(1.1, 2.2, sa));
	sc *= 1.0 - 0.18 * clamp(mid_b, 0.0, 1.0);
	col = mix(col, sc, sm);
	gloss = max(gloss, sm * 0.8 * (1.0 - 0.45 * clamp(mid_b, 0.0, 1.0)));
	// cheese: raw shreds, or melted pools with golden blisters
	vec2 q = pp;
	// shreds: thin strands at two crossing angles, more of them where more cheese went on
	vec2 r1 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q;
	vec2 r2 = mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * q;
	float s1 = vnoise(vec2(r1.x * 0.9, r1.y * 0.16));
	float s2 = vnoise(vec2(r2.x * 0.9, r2.y * 0.16) + 5.0);
	float dens = clamp(ca, 0.0, 1.6);
	float th = 0.78 - dens * 0.2;
	float shred = max(smoothstep(th, th + 0.04, s1), smoothstep(th + 0.02, th + 0.06, s2));
	shred *= smoothstep(0.05, 0.25, ca);
	// melted: pools that run together where it is thick, with soft golden variation
	float pool = smoothstep(0.32, 0.55, ca * 0.75 + (vnoise(q * 0.08) - 0.5) * 0.6 + (vnoise(q * 0.25) - 0.5) * 0.15);
	float cm = mix(shred, pool, melt);
	vec3 cc = cheese_col * mix(1.05, 0.98, melt);
	cc = mix(cc, cc * vec3(1.0, 0.9, 0.72), melt * smoothstep(0.4, 0.9, vnoise(q * 0.06 + 9.0)) * 0.5);
	float blister = smoothstep(0.68, 0.74, vnoise(q * 0.2 + 3.0)) * smoothstep(0.6, 0.95, mid_b) * melt;
	cc = mix(cc, vec3(0.78, 0.5, 0.2), blister * 0.75);
	col = mix(col, cc, cm);
	gloss = max(gloss, cm * mix(0.15, 0.85, melt));
	// leopard spots on the crust once it is well baked
	float lc = smoothstep(0.85, 1.25, crust_b) * (1.0 - inner);
	float spot = smoothstep(0.76, 0.8, vnoise(pp * 0.3 + 11.0)) * lc;
	col = mix(col, vec3(0.03, 0.02, 0.015), spot * 0.9);
	ALBEDO = col;
	ROUGHNESS = mix(0.86, 0.24, gloss);
	SPECULAR = mix(0.25, 0.7, gloss);
}
